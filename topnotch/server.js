#!/usr/bin/env node
/*
 * TopNotch Rentals — customer identity, privacy & signature-services backend.
 *
 * Zero-dependency Node server (node >= 20). Run: node server.js
 *
 * Design constraints (business rules, do not weaken):
 *  - TopNotch is a brokerage. A request is never confirmed until the provider
 *    confirms the exact vehicle and dates. Payment cannot confirm an
 *    unapproved booking.
 *  - AI never makes final decisions. The autopilot gate below checks consent
 *    BEFORE any prompt is constructed, and human-only requests are blocked
 *    from every customer-data-to-OpenAI path in deterministic code.
 *  - Verification / reset tokens are random, single-use, short-lived, stored
 *    as hashes, rate-limited, and delivered only through the email outbox —
 *    never in API responses.
 *  - customer_id is always derived from the authenticated session, never
 *    from a request payload.
 */
"use strict";

const http = require("node:http");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

/* ------------------------------------------------------------------ config */

const PORT = Number(process.env.PORT || 4305);
const PROD = process.env.NODE_ENV === "production";
const DATA_PATH = process.env.TN_DATA || path.join(__dirname, "data.json");
const OUTBOX_PATH = process.env.TN_OUTBOX || path.join(__dirname, "outbox.log");
const OPS_PATH = process.env.TN_OPS || path.join(__dirname, "ops.log");
const POLICY_VERSION = "privacy-2026-07-16.v1";
const SESSION_TTL_MS = 1000 * 60 * 60 * 12;      // 12h
const TOKEN_TTL_MS = Number(process.env.TN_TOKEN_TTL_MS || 1000 * 60 * 30); // 30 min — short-lived (env override exists for tests only)
const PROVIDER_EMAIL = "provider@topnotch.demo";
const PROVIDER_PASSWORD = process.env.TN_PROVIDER_PASSWORD || "demo-provider-pass";

// The OpenAI model is configurable only. We never invent an identifier: if
// OPENAI_MODEL is unset, AI-assisted tasks are paused and management is
// notified, while every deterministic flow continues.
const OPENAI_MODEL = process.env.OPENAI_MODEL || "";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";

/* ------------------------------------------------------------------ fleet  */
/* Server-authoritative copy of the fleet: rates used for deterministic quote
 * math. Provider rates/profit splits are NEVER exposed on public APIs. */
const FLEET = {
  hur:  { name: "Lamborghini Huracán EVO",  rate: 899,  deposit: 1000, city: "Miami" },
  urus: { name: "Lamborghini Urus",         rate: 749,  deposit: 1000, city: "Miami" },
  f8:   { name: "Ferrari F8 Tributo",       rate: 999,  deposit: 1500, city: "Miami" },
  mcl:  { name: "McLaren 570S Spider",      rate: 799,  deposit: 1000, city: "Fort Lauderdale" },
  cul:  { name: "Rolls-Royce Cullinan",     rate: 1150, deposit: 2000, city: "Miami" },
  g63:  { name: "Mercedes-AMG G 63",        rate: 549,  deposit: 1000, city: "Fort Lauderdale" },
  p911: { name: "Porsche 911 Carrera 4S",   rate: 449,  deposit: 750,  city: "Palm Beach" },
  c8:   { name: "Chevrolet Corvette C8",    rate: 299,  deposit: 500,  city: "Palm Beach" },
};

const SIGNATURE_SERVICES = new Set([
  "arrival-reset", "welcome-basket", "golden-hour", "surprise-drop",
  "hotel-valet", "fbo-keys", "content-run", "night-chauffeur",
  "family-arrival", "rain-kit",
]);

/* ------------------------------------------------------------------ state  */

let state = {
  customers: [],      // {id, name, mobile, email, pass:{salt,hash}, verified, aiPref, createdAt, deletedAt}
  tombstones: [],     // emails of deleted accounts — deleted credentials can never sign in again
  sessions: {},       // sid -> {kind:'customer'|'guest', customerId?, csrf, createdAt, expiresAt}
  providerSessions: {}, // sid -> {kind:'provider', csrf, ...}
  tokens: [],         // {hash, customerId, kind:'verify'|'reset', expiresAt, usedAt}
  requests: [],       // rental requests
};

function loadState() {
  if (DATA_PATH === ":memory:") return;
  try { state = JSON.parse(fs.readFileSync(DATA_PATH, "utf8")); } catch { /* fresh */ }
}
let saveTimer = null;
function saveState() {
  if (DATA_PATH === ":memory:") return;
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    try { fs.writeFileSync(DATA_PATH, JSON.stringify(state)); } catch (e) { opsLog("persist_error", { error: String(e) }); }
  }, 150);
}
loadState();

/* --------------------------------------------------------------- utilities */

const uuid = () => crypto.randomUUID();
const now = () => Date.now();
const sha256 = (s) => crypto.createHash("sha256").update(s).digest("hex");

function hashPassword(pw) {
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = crypto.scryptSync(pw, salt, 64).toString("hex");
  return { salt, hash };
}
function verifyPassword(pw, rec) {
  if (!rec) return false;
  const hash = crypto.scryptSync(pw, rec.salt, 64);
  const stored = Buffer.from(rec.hash, "hex");
  return hash.length === stored.length && crypto.timingSafeEqual(hash, stored);
}

function opsLog(event, detail) {
  const line = JSON.stringify({ at: new Date().toISOString(), event, ...detail }) + "\n";
  try { fs.appendFileSync(OPS_PATH, line); } catch { /* best effort */ }
}

/* Email delivery. No SMTP service is configured in this environment, so
 * messages go to a server-side outbox file. Raw tokens appear ONLY here —
 * never in an API response, client-side code, or public notification. */
function sendEmail(to, subject, body) {
  const line = JSON.stringify({ at: new Date().toISOString(), to, subject, body }) + "\n";
  try { fs.appendFileSync(OUTBOX_PATH, line); } catch { /* best effort */ }
  if (process.env.SMTP_URL) {
    // Real delivery would happen here; SMTP integration is a documented
    // remaining integration, not silently faked.
    opsLog("smtp_delivery_not_implemented", { to, subject });
  }
}

function notifyManagement(reason, detail) {
  opsLog("management_notice", { reason, ...detail });
}

/* --------------------------------------------------------------- rate limit
 * Sliding-window, in-memory. Pluggable store interface so a shared store
 * (e.g. Redis) can replace it in a multi-instance deployment — the in-memory
 * store alone is NOT sufficient for production and is flagged as a blocker. */
class RateLimiter {
  constructor(store = new Map()) { this.store = store; }
  hit(key, limit, windowMs) {
    const t = now();
    const arr = (this.store.get(key) || []).filter((x) => t - x < windowMs);
    if (arr.length >= limit) { this.store.set(key, arr); return false; }
    arr.push(t);
    this.store.set(key, arr);
    return true;
  }
  clear(key) { this.store.delete(key); }
}
const limiter = new RateLimiter();

/* ----------------------------------------------------------------- tokens  */

function issueToken(customerId, kind) {
  const raw = crypto.randomBytes(32).toString("base64url"); // random
  state.tokens.push({
    hash: sha256(raw),                 // stored as hash
    customerId, kind,
    expiresAt: now() + TOKEN_TTL_MS,   // short-lived
    usedAt: null,                      // single-use
  });
  saveState();
  return raw;
}
function consumeToken(raw, kind) {
  const rec = state.tokens.find((t) => t.hash === sha256(String(raw)) && t.kind === kind);
  if (!rec) return { error: "invalid" };
  if (rec.usedAt) return { error: "used" };
  if (rec.expiresAt < now()) return { error: "expired" };
  rec.usedAt = now();
  saveState();
  return { customerId: rec.customerId };
}

/* ---------------------------------------------------------------- sessions */

function parseCookies(req) {
  const out = {};
  (req.headers.cookie || "").split(";").forEach((p) => {
    const i = p.indexOf("=");
    if (i > 0) out[p.slice(0, i).trim()] = decodeURIComponent(p.slice(i + 1).trim());
  });
  return out;
}
function cookieHeader(name, value, maxAgeSec) {
  const parts = [`${name}=${value}`, "Path=/", "HttpOnly", "SameSite=Strict"];
  if (PROD) parts.push("Secure");
  if (maxAgeSec !== undefined) parts.push(`Max-Age=${maxAgeSec}`);
  return parts.join("; ");
}
function createSession(map, data) {
  const sid = crypto.randomBytes(32).toString("base64url");
  map[sid] = { ...data, csrf: crypto.randomBytes(24).toString("base64url"), createdAt: now(), expiresAt: now() + SESSION_TTL_MS };
  saveState();
  return sid;
}
function getSession(map, sid) {
  const s = sid && map[sid];
  if (!s) return null;
  if (s.expiresAt < now()) { delete map[sid]; saveState(); return null; }
  return s;
}
/* Customer sessions live in state.sessions; provider sessions in
 * state.providerSessions with a different cookie. They are completely
 * separate: a customer session can never satisfy provider or admin auth. */
function customerSession(req) {
  const s = getSession(state.sessions, parseCookies(req).tn_session);
  return s && (s.kind === "customer" || s.kind === "guest") ? { sid: parseCookies(req).tn_session, ...s } : null;
}
function providerSession(req) {
  const s = getSession(state.providerSessions, parseCookies(req).tn_provider);
  return s && s.kind === "provider" ? { sid: parseCookies(req).tn_provider, ...s } : null;
}
function requireCsrf(req, sess) {
  return req.headers["x-tn-csrf"] === sess.csrf;
}

/* ------------------------------------------------------------- autopilot
 * Deterministic AI gate. Consent is checked BEFORE any prompt is built.
 * Human-only requests exit here — there is no other code path that sends
 * customer data toward OpenAI. */
const aiMetrics = { blockedHumanOnly: 0, paused: 0, promptsBuilt: 0 };

function autopilotProcess(request) {
  // 1. Consent gate — first, always.
  if (!request.aiConsent || request.aiConsent.choice !== "ai") {
    aiMetrics.blockedHumanOnly++;
    opsLog("ai_blocked_human_only", { requestId: request.id });
    return "human_only";
  }
  // 2. Availability gate — never invent a model identifier.
  if (!OPENAI_MODEL || !OPENAI_API_KEY) {
    aiMetrics.paused++;
    notifyManagement("ai_paused", {
      requestId: request.id,
      cause: !OPENAI_MODEL ? "OPENAI_MODEL not configured" : "OPENAI_API_KEY not configured",
      note: "Deterministic flows (availability checks, payment verification, booking safety, notifications, reminders) continue.",
    });
    return "paused";
  }
  // 3. Only past both gates would a prompt ever be constructed.
  aiMetrics.promptsBuilt++;
  opsLog("ai_prompt_built", { requestId: request.id, model: OPENAI_MODEL });
  return "queued";
}

/* -------------------------------------------------------------- validation */

const emailOk = (e) => typeof e === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) && e.length <= 254;
const nameOk = (n) => typeof n === "string" && n.trim().length >= 2 && n.length <= 120;
const mobileOk = (m) => typeof m === "string" && m.replace(/\D/g, "").length >= 7 && m.length <= 32;
const passwordOk = (p) => typeof p === "string" && p.length >= 10 && p.length <= 256;

function findCustomerByEmail(email) {
  return state.customers.find((c) => !c.deletedAt && c.email.toLowerCase() === String(email).toLowerCase());
}

/* Public view of a customer — never leaks hashes, tokens, or internal notes. */
function customerView(c) {
  return {
    id: c.id, name: c.name, mobile: c.mobile, email: c.email,
    verified: !!c.verified, aiPref: c.aiPref, createdAt: c.createdAt,
  };
}
/* Public view of a request — no provider rates, profit, or internal notes. */
function requestView(r) {
  return {
    id: r.id, carId: r.carId, carName: FLEET[r.carId]?.name, city: FLEET[r.carId]?.city,
    start: r.start, days: r.days, delivery: r.delivery,
    services: r.services, status: r.status, quote: r.quote || null,
    aiConsent: r.aiConsent ? { choice: r.aiConsent.choice, policyVersion: r.aiConsent.policyVersion, at: r.aiConsent.at } : null,
    autopilot: r.autopilot, events: r.events, createdAt: r.createdAt, paidAt: r.paidAt || null,
  };
}

/* ------------------------------------------------------------------ router */

function json(res, code, obj, headers = {}) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...headers });
  res.end(body);
}
function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (c) => {
      data += c;
      if (data.length > 100_000) { reject(new Error("payload too large")); req.destroy(); }
    });
    req.on("end", () => {
      if (!data) return resolve({});
      try { resolve(JSON.parse(data)); } catch { reject(new Error("invalid JSON")); }
    });
    req.on("error", reject);
  });
}
const clientIp = (req) => req.socket.remoteAddress || "unknown";

const routes = [];
function route(method, pattern, handler) { routes.push({ method, pattern, handler }); }

/* ---------- health ---------- */
route("GET", /^\/api\/health$/, (req, res) => json(res, 200, { ok: true, service: "topnotch", policyVersion: POLICY_VERSION }));

/* ---------- registration ---------- */
route("POST", /^\/api\/customer\/register$/, async (req, res) => {
  if (!limiter.hit("register:" + clientIp(req), 20, 60 * 60 * 1000)) {
    return json(res, 429, { error: "Too many sign-up attempts. Try again later." }, { "retry-after": "3600" });
  }
  const b = await readBody(req);
  if (!nameOk(b.name)) return json(res, 400, { error: "Full name is required (2+ characters)." });
  if (!mobileOk(b.mobile)) return json(res, 400, { error: "A valid mobile number is required." });
  if (!emailOk(b.email)) return json(res, 400, { error: "A valid email is required." });
  if (!passwordOk(b.password)) return json(res, 400, { error: "Password must be at least 10 characters." });
  if (findCustomerByEmail(b.email)) return json(res, 409, { error: "An account with this email already exists. Sign in instead." });

  const customer = {
    id: uuid(), name: b.name.trim(), mobile: b.mobile.trim(), email: b.email.trim(),
    pass: hashPassword(b.password), verified: false,
    aiPref: { choice: "human", policyVersion: POLICY_VERSION, at: new Date().toISOString() }, // default: Human-only
    createdAt: new Date().toISOString(), deletedAt: null,
  };
  state.customers.push(customer);

  const raw = issueToken(customer.id, "verify");
  sendEmail(customer.email, "Verify your TopNotch account",
    `Hi ${customer.name}, confirm your email with this code (expires in 30 minutes, single use): ${raw}`);

  const sid = createSession(state.sessions, { kind: "customer", customerId: customer.id });
  saveState();
  json(res, 201, { customer: customerView(customer), csrf: state.sessions[sid].csrf },
    { "set-cookie": cookieHeader("tn_session", sid, SESSION_TTL_MS / 1000) });
});

/* ---------- login ---------- */
route("POST", /^\/api\/customer\/login$/, async (req, res) => {
  const b = await readBody(req);
  const key = "login:" + clientIp(req) + ":" + String(b.email || "").toLowerCase();
  if (!limiter.hit(key, 5, 10 * 60 * 1000)) {
    return json(res, 429, { error: "Too many sign-in attempts. Wait 10 minutes and try again." }, { "retry-after": "600" });
  }
  const c = findCustomerByEmail(b.email);
  // Deleted credentials can never sign in again (tombstoned or removed).
  if (!c || !verifyPassword(String(b.password || ""), c.pass)) {
    return json(res, 401, { error: "Email or password is incorrect." });
  }
  limiter.clear(key); // successful sign-in resets the failed-attempt counter
  const sid = createSession(state.sessions, { kind: "customer", customerId: c.id });
  json(res, 200, { customer: customerView(c), csrf: state.sessions[sid].csrf },
    { "set-cookie": cookieHeader("tn_session", sid, SESSION_TTL_MS / 1000) });
});

/* ---------- logout / logout-all ---------- */
route("POST", /^\/api\/customer\/logout$/, (req, res) => {
  const sess = customerSession(req);
  if (sess) { delete state.sessions[sess.sid]; saveState(); }
  json(res, 200, { ok: true }, { "set-cookie": cookieHeader("tn_session", "", 0) });
});
route("POST", /^\/api\/customer\/logout-all$/, (req, res) => {
  const sess = customerSession(req);
  if (!sess || sess.kind !== "customer") return json(res, 401, { error: "Sign in first." });
  if (!requireCsrf(req, sess)) return json(res, 403, { error: "CSRF check failed." });
  let n = 0;
  for (const [sid, s] of Object.entries(state.sessions)) {
    if (s.customerId === sess.customerId) { delete state.sessions[sid]; n++; }
  }
  saveState();
  json(res, 200, { ok: true, revokedSessions: n }, { "set-cookie": cookieHeader("tn_session", "", 0) });
});

/* ---------- me ---------- */
route("GET", /^\/api\/customer\/me$/, (req, res) => {
  const sess = customerSession(req);
  if (!sess) return json(res, 401, { error: "Not signed in." });
  if (sess.kind === "guest") return json(res, 200, { guest: true, csrf: sess.csrf });
  const c = state.customers.find((x) => x.id === sess.customerId && !x.deletedAt);
  if (!c) return json(res, 401, { error: "Account no longer exists." });
  json(res, 200, { customer: customerView(c), csrf: sess.csrf });
});

route("PATCH", /^\/api\/customer\/me$/, async (req, res) => {
  const sess = customerSession(req);
  if (!sess || sess.kind !== "customer") return json(res, 401, { error: "Sign in first." });
  if (!requireCsrf(req, sess)) return json(res, 403, { error: "CSRF check failed." });
  const c = state.customers.find((x) => x.id === sess.customerId && !x.deletedAt);
  if (!c) return json(res, 401, { error: "Account no longer exists." });
  const b = await readBody(req);
  if (b.name !== undefined) { if (!nameOk(b.name)) return json(res, 400, { error: "Invalid name." }); c.name = b.name.trim(); }
  if (b.mobile !== undefined) { if (!mobileOk(b.mobile)) return json(res, 400, { error: "Invalid mobile number." }); c.mobile = b.mobile.trim(); }
  if (b.aiPref !== undefined) {
    if (!["human", "ai"].includes(b.aiPref)) return json(res, 400, { error: "aiPref must be 'human' or 'ai'." });
    c.aiPref = { choice: b.aiPref, policyVersion: POLICY_VERSION, at: new Date().toISOString() };
    opsLog("ai_pref_changed", { customerId: c.id, choice: b.aiPref });
  }
  saveState();
  json(res, 200, { customer: customerView(c) });
});

/* ---------- account deletion ---------- */
route("DELETE", /^\/api\/customer\/me$/, async (req, res) => {
  const sess = customerSession(req);
  if (!sess || sess.kind !== "customer") return json(res, 401, { error: "Sign in first." });
  if (!requireCsrf(req, sess)) return json(res, 403, { error: "CSRF check failed." });
  const c = state.customers.find((x) => x.id === sess.customerId && !x.deletedAt);
  if (!c) return json(res, 401, { error: "Account no longer exists." });
  const b = await readBody(req);
  // Reauthentication is required.
  if (!verifyPassword(String(b.password || ""), c.pass)) {
    return json(res, 403, { error: "Reauthentication failed — enter your current password to delete the account." });
  }
  // Revoke every active customer session for this account.
  for (const [sid, s] of Object.entries(state.sessions)) {
    if (s.customerId === c.id) delete state.sessions[sid];
  }
  // Disconnect the account from rental requests (legally required booking and
  // financial records are retained under the Privacy Policy, unlinked).
  for (const r of state.requests) {
    if (r.customerId === c.id) { r.customerId = null; r.contact = { name: "[deleted account]", email: null, mobile: null }; }
  }
  // Prevent the deleted credentials from signing in again.
  state.tombstones.push({ email: c.email.toLowerCase(), at: new Date().toISOString() });
  c.deletedAt = new Date().toISOString();
  c.email = `deleted-${c.id}@removed.invalid`;
  c.pass = { salt: "x", hash: "x" };
  c.name = "[deleted]"; c.mobile = "";
  state.tokens = state.tokens.filter((t) => t.customerId !== c.id);
  saveState();
  opsLog("account_deleted", { customerId: c.id });
  json(res, 200, {
    ok: true,
    notice: "Your account is deleted and every active session was signed out. Legally required booking and financial records may be retained under the Privacy Policy, but they are no longer linked to your account and your credentials can no longer sign in.",
  }, { "set-cookie": cookieHeader("tn_session", "", 0) });
});

/* ---------- email verification ---------- */
route("POST", /^\/api\/customer\/verify-email\/request$/, (req, res) => {
  const sess = customerSession(req);
  if (!sess || sess.kind !== "customer") return json(res, 401, { error: "Sign in first." });
  if (!requireCsrf(req, sess)) return json(res, 403, { error: "CSRF check failed." });
  const c = state.customers.find((x) => x.id === sess.customerId && !x.deletedAt);
  if (!c) return json(res, 401, { error: "Account no longer exists." });
  if (c.verified) return json(res, 200, { ok: true, alreadyVerified: true });
  if (!limiter.hit("verify:" + c.id, 3, 15 * 60 * 1000)) {
    return json(res, 429, { error: "Verification email already sent — wait a few minutes." }, { "retry-after": "900" });
  }
  const raw = issueToken(c.id, "verify");
  sendEmail(c.email, "Verify your TopNotch account", `Confirm your email with this code (expires in 30 minutes, single use): ${raw}`);
  json(res, 200, { ok: true, sentTo: c.email }); // the token itself is never in the response
});

route("POST", /^\/api\/customer\/verify-email\/confirm$/, async (req, res) => {
  if (!limiter.hit("verifyc:" + clientIp(req), 10, 15 * 60 * 1000)) {
    return json(res, 429, { error: "Too many attempts." }, { "retry-after": "900" });
  }
  const b = await readBody(req);
  const out = consumeToken(b.token, "verify");
  if (out.error) return json(res, 400, { error: out.error === "expired" ? "This code has expired — request a new one." : "This code is invalid or was already used." });
  const c = state.customers.find((x) => x.id === out.customerId && !x.deletedAt);
  if (!c) return json(res, 400, { error: "Account no longer exists." });
  c.verified = true;
  saveState();
  json(res, 200, { ok: true, verified: true });
});

/* ---------- password reset ---------- */
route("POST", /^\/api\/customer\/password-reset\/request$/, async (req, res) => {
  const b = await readBody(req);
  if (!limiter.hit("pwreset:" + clientIp(req), 5, 15 * 60 * 1000)) {
    return json(res, 429, { error: "Too many reset requests." }, { "retry-after": "900" });
  }
  const c = findCustomerByEmail(b.email);
  if (c) {
    const raw = issueToken(c.id, "reset");
    sendEmail(c.email, "Reset your TopNotch password", `Use this code to set a new password (expires in 30 minutes, single use): ${raw}`);
  }
  // Same response whether the email exists or not — no account enumeration.
  json(res, 200, { ok: true, notice: "If that email has an account, a reset code is on the way." });
});

route("POST", /^\/api\/customer\/password-reset\/confirm$/, async (req, res) => {
  if (!limiter.hit("pwresetc:" + clientIp(req), 10, 15 * 60 * 1000)) {
    return json(res, 429, { error: "Too many attempts." }, { "retry-after": "900" });
  }
  const b = await readBody(req);
  if (!passwordOk(b.newPassword)) return json(res, 400, { error: "New password must be at least 10 characters." });
  const out = consumeToken(b.token, "reset");
  if (out.error) return json(res, 400, { error: out.error === "expired" ? "This reset code has expired — request a new one." : "This reset code is invalid or was already used." });
  const c = state.customers.find((x) => x.id === out.customerId && !x.deletedAt);
  if (!c) return json(res, 400, { error: "Account no longer exists." });
  c.pass = hashPassword(b.newPassword);
  // A password reset signs out every existing session for safety.
  for (const [sid, s] of Object.entries(state.sessions)) {
    if (s.customerId === c.id) delete state.sessions[sid];
  }
  saveState();
  json(res, 200, { ok: true, notice: "Password updated. Every existing session was signed out — sign in with the new password." });
});

/* ---------- rental requests ---------- */
route("POST", /^\/api\/customer\/requests$/, async (req, res) => {
  if (!limiter.hit("req:" + clientIp(req), 15, 60 * 60 * 1000)) {
    return json(res, 429, { error: "Too many requests from this device — slow down." }, { "retry-after": "3600" });
  }
  let sess = customerSession(req);
  const b = await readBody(req);
  if (sess && !requireCsrf(req, sess)) return json(res, 403, { error: "CSRF check failed." });

  const carDef = FLEET[b.carId];
  if (!carDef) return json(res, 400, { error: "Unknown vehicle." });
  const days = Number(b.days);
  if (!Number.isInteger(days) || days < 1 || days > 30) return json(res, 400, { error: "Days must be between 1 and 30." });
  if (!["pickup", "hotel", "door"].includes(b.delivery)) return json(res, 400, { error: "Unknown delivery option." });
  const start = String(b.start || "");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(start)) return json(res, 400, { error: "A start date is required." });
  const services = Array.isArray(b.services) ? b.services.filter((s) => SIGNATURE_SERVICES.has(s)) : [];

  // customer_id ALWAYS comes from the session — never from the payload.
  let customerId = null, contact = null;
  if (sess && sess.kind === "customer") {
    const c = state.customers.find((x) => x.id === sess.customerId && !x.deletedAt);
    if (!c) return json(res, 401, { error: "Account no longer exists." });
    customerId = c.id;
    contact = { name: c.name, email: c.email, mobile: c.mobile };
  } else {
    // Guests get the same access, pricing and priority — they just provide
    // contact details per request.
    const g = b.contact || {};
    if (!nameOk(g.name) || !emailOk(g.email) || !mobileOk(g.mobile)) {
      return json(res, 400, { error: "Guests need a name, valid email, and mobile number so the provider's confirmation can reach you." });
    }
    contact = { name: g.name.trim(), email: g.email.trim(), mobile: g.mobile.trim() };
    if (!sess) {
      const sid = createSession(state.sessions, { kind: "guest" });
      res.setHeader("set-cookie", cookieHeader("tn_session", sid, SESSION_TTL_MS / 1000));
      sess = { sid, ...state.sessions[sid] };
    }
  }

  // Per-request AI consent. Default is Human-only; 'ai' only if explicitly chosen.
  const aiChoice = b.aiChoice === "ai" ? "ai" : "human";
  const request = {
    id: "TN-" + crypto.randomBytes(4).toString("hex").toUpperCase(),
    carId: b.carId, start, days, delivery: b.delivery,
    services: services.map((s) => ({ id: s, status: "requested" })), // never priced or promised at request time
    customerId,
    guestSid: customerId ? null : sess.sid,
    contact,
    aiConsent: { choice: aiChoice, policyVersion: POLICY_VERSION, at: new Date().toISOString() },
    status: "pending_provider",
    quote: null,
    events: [
      { at: new Date().toISOString(), by: "system", text: "Request received. Nothing has been charged." },
      { at: new Date().toISOString(), by: "system", text: "Sent to the provider — TopNotch is waiting on their confirmation of the exact vehicle and dates before any quote is approved or payment is accepted." },
    ],
    createdAt: new Date().toISOString(),
  };
  // The consent gate runs BEFORE any prompt could be constructed.
  request.autopilot = autopilotProcess(request);
  state.requests.push(request);
  saveState();
  json(res, 201, { request: requestView(request), csrf: sess.csrf });
});

function canSeeRequest(req, r) {
  const sess = customerSession(req);
  if (!sess) return false;
  if (sess.kind === "customer") return r.customerId === sess.customerId;
  return r.guestSid === sess.sid; // guests can only see their own session's requests
}

route("GET", /^\/api\/customer\/requests\/([\w-]+)$/, (req, res, m) => {
  const r = state.requests.find((x) => x.id === m[1]);
  // 404 either way — never confirm another customer's request exists.
  if (!r || !canSeeRequest(req, r)) return json(res, 404, { error: "Request not found." });
  json(res, 200, { request: requestView(r) });
});

route("GET", /^\/api\/customer\/trips$/, (req, res) => {
  const sess = customerSession(req);
  if (!sess) return json(res, 401, { error: "Not signed in." });
  const mine = state.requests.filter((r) =>
    sess.kind === "customer" ? r.customerId === sess.customerId : r.guestSid === sess.sid);
  json(res, 200, { requests: mine.map(requestView) });
});

/* ---------- payment (demo gate — no processor integrated) ---------- */
route("POST", /^\/api\/customer\/requests\/([\w-]+)\/pay$/, async (req, res, m) => {
  const sess = customerSession(req);
  if (!sess) return json(res, 401, { error: "Not signed in." });
  if (!requireCsrf(req, sess)) return json(res, 403, { error: "CSRF check failed." });
  const r = state.requests.find((x) => x.id === m[1]);
  if (!r || !canSeeRequest(req, r)) return json(res, 404, { error: "Request not found." });
  // Payment can never confirm an unapproved booking.
  if (r.status !== "approved") {
    return json(res, 409, { error: "The provider hasn't confirmed this request yet — payment can't confirm an unapproved booking." });
  }
  r.status = "booked";
  r.paidAt = new Date().toISOString();
  r.events.push({ at: r.paidAt, by: "system", text: `Payment of $${r.quote.total.toLocaleString("en-US")} recorded (demo — no live processor). Deposit of $${r.quote.deposit.toLocaleString("en-US")} is refundable after the documented vehicle-return review and rental-agreement requirements.` });
  saveState();
  json(res, 200, { request: requestView(r) });
});

/* ---------- provider portal (separate session space) ---------- */
route("POST", /^\/api\/provider\/login$/, async (req, res) => {
  const b = await readBody(req);
  if (!limiter.hit("plogin:" + clientIp(req), 5, 10 * 60 * 1000)) {
    return json(res, 429, { error: "Too many attempts." }, { "retry-after": "600" });
  }
  if (b.email !== PROVIDER_EMAIL || String(b.password) !== PROVIDER_PASSWORD) {
    return json(res, 401, { error: "Provider credentials are incorrect." });
  }
  const sid = createSession(state.providerSessions, { kind: "provider" });
  json(res, 200, { provider: { email: PROVIDER_EMAIL, name: "Marcus R. (demo provider)" }, csrf: state.providerSessions[sid].csrf },
    { "set-cookie": cookieHeader("tn_provider", sid, SESSION_TTL_MS / 1000) });
});

route("GET", /^\/api\/provider\/requests$/, (req, res) => {
  const sess = providerSession(req);
  if (!sess) return json(res, 403, { error: "Provider portal only. Customer sessions have no access here." });
  // Providers see booking details but never other customers' account data.
  json(res, 200, {
    requests: state.requests.map((r) => ({
      id: r.id, carId: r.carId, carName: FLEET[r.carId]?.name,
      start: r.start, days: r.days, delivery: r.delivery,
      services: r.services, status: r.status,
      renterName: r.contact?.name || "[deleted account]",
      createdAt: r.createdAt,
    })),
  });
});

route("POST", /^\/api\/provider\/requests\/([\w-]+)\/decision$/, async (req, res, m) => {
  const sess = providerSession(req);
  if (!sess) return json(res, 403, { error: "Provider portal only. Customer sessions have no access here." });
  if (!requireCsrf(req, sess)) return json(res, 403, { error: "CSRF check failed." });
  const r = state.requests.find((x) => x.id === m[1]);
  if (!r) return json(res, 404, { error: "Request not found." });
  if (r.status !== "pending_provider") return json(res, 409, { error: "This request was already decided." });
  const b = await readBody(req);
  if (b.decision === "approve") {
    // Quote math is deterministic server code — not AI, not the client.
    const carDef = FLEET[r.carId];
    const deliveryFee = r.delivery === "pickup" ? 0 : (r.days >= 3 ? 0 : 149);
    r.quote = { rental: carDef.rate * r.days, deliveryFee, insurance: 0, deposit: carDef.deposit, total: carDef.rate * r.days + deliveryFee };
    r.status = "approved";
    r.events.push({ at: new Date().toISOString(), by: "provider", text: `Provider confirmed the exact vehicle and dates. Approved quote: $${r.quote.total.toLocaleString("en-US")} (insurance included in the quoted price, subject to eligibility and verification). Payment is now available.` });
  } else if (b.decision === "decline") {
    r.status = "declined";
    r.events.push({ at: new Date().toISOString(), by: "provider", text: "The provider can't make these dates work. Nothing was charged." });
  } else {
    return json(res, 400, { error: "decision must be 'approve' or 'decline'." });
  }
  saveState();
  json(res, 200, { ok: true, status: r.status });
});

/* ---------- admin (exists to prove separation — customers always refused) */
route("GET", /^\/api\/admin\/.*$/, (req, res) => {
  json(res, 403, { error: "Admin access requires staff credentials. Customer and provider sessions are never granted admin, employee, or cross-portal permissions." });
});
route("POST", /^\/api\/admin\/.*$/, (req, res) => {
  json(res, 403, { error: "Admin access requires staff credentials. Customer and provider sessions are never granted admin, employee, or cross-portal permissions." });
});

/* ---------- static: serve the app ---------- */
function serveApp(req, res) {
  const file = path.join(__dirname, "index.html");
  fs.readFile(file, (err, buf) => {
    if (err) { res.writeHead(500); return res.end("app not found"); }
    res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
    res.end("<!doctype html><html><head><meta charset=\"utf-8\"></head><body>" + buf.toString() + "</body></html>");
  });
}

/* ------------------------------------------------------------------ server */

const server = http.createServer(async (req, res) => {
  try {
    const url = req.url.split("?")[0];
    for (const r of routes) {
      if (r.method !== req.method) continue;
      const m = url.match(r.pattern);
      if (m) return await r.handler(req, res, m);
    }
    if (req.method === "GET" && (url === "/" || url === "/index.html")) return serveApp(req, res);
    json(res, 404, { error: "Not found." });
  } catch (e) {
    opsLog("server_error", { error: String(e), url: req.url });
    json(res, 400, { error: e.message === "invalid JSON" || e.message === "payload too large" ? e.message : "Request failed." });
  }
});

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`TopNotch server listening on http://localhost:${PORT}`);
    console.log(`  data:   ${DATA_PATH}`);
    console.log(`  outbox: ${OUTBOX_PATH} (email tokens are delivered here — no SMTP configured)`);
    console.log(`  AI:     ${OPENAI_MODEL ? `model ${OPENAI_MODEL}` : "paused (OPENAI_MODEL not set — deterministic flows continue)"}`);
  });
}

module.exports = { server, state, aiMetrics, POLICY_VERSION };
