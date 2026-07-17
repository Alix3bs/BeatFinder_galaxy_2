/* ============================================================
   Customer accounts, guest booking & privacy hardening tests.

   Part A (in-process, fresh DB #1): AI-consent gate against a mock
   OpenAI endpoint — proves Human-only data never leaves the server.
   Part B (spawned server, fresh DB #2 + mock email webhook): the
   full account lifecycle, isolation, CSRF, rate limits, services.

   Run: node tests/customer.mjs
   ============================================================ */
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import crypto from "node:crypto";
import { DatabaseSync } from "node:sqlite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, "..");
const require = createRequire(path.join(ROOT, "server.js"));
const results = [];
const record = (n, name, okv, detail) => { results.push({ n, name, ok: okv, detail: detail || "" }); console.log(`${okv ? "PASS" : "FAIL"}  ${n} · ${name}${detail ? "  — " + detail : ""}`); };
const assert = (c, m) => { if (!c) throw new Error(m); };
const sha256 = s => crypto.createHash("sha256").update(s).digest("hex");

/* ================= PART A — in-process consent gate ================= */
const LIBDATA = path.join(ROOT, "data-cust-lib");
fs.rmSync(LIBDATA, { recursive: true, force: true });
process.env.TN_DATA_DIR = LIBDATA;
process.env.TN_ENV = "staging";

const { db: libdb } = require("./lib/db");
require("./seed").seed();
require("./lib/customers");   // creates customers tables + requests ai_consent columns
const AP = require("./lib/autopilot");

const aiHits = [];
const mockAI = http.createServer((q, s) => {
  let b = ""; q.on("data", c => b += c);
  q.on("end", () => {
    aiHits.push(JSON.parse(b));
    s.writeHead(200, { "Content-Type": "application/json" });
    s.end(JSON.stringify({ choices: [{ message: { content: "mock summary" } }], usage: { prompt_tokens: 10, completion_tokens: 5 } }));
  });
});

async function partA() {
  await new Promise(r => mockAI.listen(8963, r));
  process.env.OPENAI_MODEL = "mock-model-for-tests";
  process.env.OPENAI_API_KEY = "test-key";
  process.env.OPENAI_API_BASE = "http://localhost:8963";

  const mkReq = (id, consent, custId) => libdb.prepare(
    `INSERT INTO requests (request_id, customer_name, phone, email, vehicle_requested, start_date, end_date, ai_consent, ai_consent_version, customer_id)
     VALUES (?,?,?,?,?,?,?,?,?,?)`)
    .run(id, "Consent Test", "(305) 555-9000", "consent@example.com", "Lamborghini Urus", "2027-05-01 10:00", "2027-05-03 10:00", consent, "2026-07-06", custId || null);

  /* A1 · AI opt-in: prompt allowed, labeled AI-assisted */
  try {
    mkReq("TNC-AI-1", "ai");
    const out = await AP.llmForRequest("summary", "TNC-AI-1", "Summarize booking status", 50);
    assert(out.text === "mock summary" && out.label === "AI-assisted", JSON.stringify(out));
    assert(aiHits.length === 1, "exactly one OpenAI call expected");
    record("A1", "AI opt-in: consented request may use AI, output labeled 'AI-assisted'", true, "model=" + out.model);
  } catch (e) { record("A1", "AI opt-in", false, e.message); }

  /* A2 · Human-only: NO data leaves the server, block audited */
  try {
    mkReq("TNC-HUM-1", "human");
    const before = aiHits.length;
    const out = await AP.llmForRequest("summary", "TNC-HUM-1", "Summarize booking status", 50);
    assert(out.disabled && /Human-only/.test(out.reason), JSON.stringify(out));
    assert(aiHits.length === before, "OpenAI must NOT be called for a Human-only request");
    const audited = libdb.prepare("SELECT count(*) n FROM audit WHERE action='ai.consent.blocked' AND entity_id='TNC-HUM-1'").get().n;
    assert(audited === 1, "block must be audited");
    record("A2", "Human-only: OpenAI never called, block audited, deterministic fallback", true, out.reason.slice(0, 60));
  } catch (e) { record("A2", "Human-only blocking", false, e.message); }

  /* A3 · Withdrawal wins: request said 'ai' but account preference is now Human-only */
  try {
    libdb.prepare("INSERT INTO customers (customer_id, name, phone, email, pass_hash, salt, ai_consent) VALUES ('C-WDRAW','W D','(305) 555-9001','w@example.com','x','y','human')").run();
    mkReq("TNC-WD-1", "ai", "C-WDRAW");
    const before = aiHits.length;
    const out = await AP.llmForRequest("summary", "TNC-WD-1", "Summarize", 50);
    assert(out.disabled && /Human-only/.test(out.reason), JSON.stringify(out));
    assert(aiHits.length === before, "withdrawn consent must block immediately");
    record("A3", "Consent withdrawal applies immediately (live account preference wins)", true, out.reason.slice(0, 60));
  } catch (e) { record("A3", "Withdrawal blocking", false, e.message); }

  mockAI.close();
  delete process.env.OPENAI_MODEL; delete process.env.OPENAI_API_KEY; delete process.env.OPENAI_API_BASE;
}

/* ================= PART B — spawned server ================= */
const PORT = 8961, MOCK = 8962, B = `http://localhost:${PORT}`;
const TESTDATA = path.join(ROOT, "data-cust");
fs.rmSync(TESTDATA, { recursive: true, force: true });

const emailsSeen = [];
const mockMail = http.createServer((q, s) => {
  let b = ""; q.on("data", c => b += c);
  q.on("end", () => { try { emailsSeen.push(JSON.parse(b)); } catch (e) {} s.writeHead(200); s.end("ok"); });
});
const lastEmailTo = to => [...emailsSeen].reverse().find(m => m.to === to && m.html);
const tokenFrom = (m, kind) => (m?.html?.match(new RegExp("#" + kind + "=([a-f0-9]+)")) || [])[1];

function jar() {
  const cookies = {};
  const client = async (p, body, method, headers) => {
    const res = await fetch(B + p, {
      method: method || (body !== undefined ? "POST" : "GET"),
      headers: {
        ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
        ...(Object.keys(cookies).length ? { cookie: Object.entries(cookies).map(([k, v]) => `${k}=${v}`).join("; ") } : {}),
        ...(headers || {})
      },
      body: body !== undefined ? JSON.stringify(body) : undefined
    });
    for (const sc of res.headers.getSetCookie?.() || []) {
      const [kv] = sc.split(";");
      const [k, v] = kv.split("=");
      if (v === "" || /Max-Age=0/.test(sc)) delete cookies[k]; else cookies[k] = v;
    }
    return { status: res.status, data: await res.json().catch(() => ({})), cookies };
  };
  client.csrf = () => cookies.tn_cust_csrf || "";
  client.cookies = cookies;
  return client;
}

const CONSENTS = { terms: true, privacy: true, cancellation: true, deposit: true, vehicleRules: true, communication: true, documents: true };
const REQ = o => ({
  customerName: "Cust Test", phone: "(305) 555-7100", email: "custa@example.com",
  vehicleRequested: "Lamborghini Huracán EVO", startDate: "2027-06-01 10:00", endDate: "2027-06-03 10:00",
  option: "delivery", deliveryLocation: "Brickell, Miami", depositReadiness: "Ready",
  driverAge: "30–39", licenseStatus: "Confirmed by customer", insuranceStatus: "Confirmed by customer",
  consents: CONSENTS, consentText: "consent v2026-07-06", ...o
});

const proc = spawn("node", ["server.js"], {
  cwd: ROOT,
  env: {
    ...process.env, PORT, TN_ENV: "staging", TN_DATA_DIR: TESTDATA,
    TN_RATE_REQUESTS: "100", TN_BASE_URL: B,
    NOTIFY_EMAIL_WEBHOOK_URL: `http://localhost:${MOCK}/email`,
    TN_ADMIN_PASSWORD: "CustAdmin2026!!", TN_SALES_PASSWORD: "CustSales2026!!", TN_PARTNER2_PASSWORD: "CustPartner2026!!"
  },
  stdio: ["ignore", "ignore", "pipe"]
});
proc.stderr.on("data", d => { const s = String(d); if (!s.includes("Experimental")) process.stderr.write(s); });

const serverDb = () => new DatabaseSync(path.join(TESTDATA, "topnotch.db"));

async function partB() {
  mockMail.listen(MOCK);
  for (let i = 0; i < 40; i++) { try { await fetch(B + "/api/health"); break; } catch (e) { await new Promise(r => setTimeout(r, 250)); } }

  const A = jar(), A2 = jar(), Bc = jar(), C = jar(), staff = jar(), partner = jar(), anon = jar();

  /* 1 · registration (audited, verification email sent, human default) */
  try {
    const r = await A("/api/customer/register", { name: "Customer A", phone: "3055557100", email: "custa@example.com", password: "PasswordA-10chars" });
    assert(r.status === 200 && r.data.me.customerId?.startsWith("C-"), JSON.stringify(r.data));
    assert(r.data.me.aiConsent === "human", "AI must default to human");
    assert(A.cookies.tn_cust && A.csrf(), "session + csrf cookies expected");
    await new Promise(r2 => setTimeout(r2, 400));
    assert(lastEmailTo("custa@example.com"), "verification email must be delivered via configured email system");
    record(1, "Registration: account + session, verification email sent, Human-only default", true, r.data.me.customerId);
  } catch (e) { record(1, "Registration", false, e.message); }

  /* 2 · duplicate registration refused */
  try {
    const r = await anon("/api/customer/register", { name: "Customer A2", phone: "3055557101", email: "CUSTA@example.com", password: "PasswordA-10chars" });
    assert(r.status === 400 && /already exists/.test(r.data.error), JSON.stringify(r.data));
    record(2, "Duplicate registration refused (case-insensitive email)", true, r.data.error.slice(0, 50));
  } catch (e) { record(2, "Duplicate registration", false, e.message); }

  /* 3 · email verification via emailed token */
  try {
    const token = tokenFrom(lastEmailTo("custa@example.com"), "verify");
    assert(token, "verify token must appear ONLY in the email");
    const r = await anon("/api/customer/verify/complete", { token });
    assert(r.status === 200, JSON.stringify(r.data));
    const me = await A("/api/customer/me");
    assert(me.data.me.emailVerified === true, "flag must flip");
    globalThis.usedVerifyToken = token;
    record(3, "Email verification: emailed single-use token verifies the address", true);
  } catch (e) { record(3, "Email verification", false, e.message); }

  /* 4 · verification-token replay rejected */
  try {
    const r = await anon("/api/customer/verify/complete", { token: globalThis.usedVerifyToken });
    assert(r.status === 400 && /invalid|used|expired/i.test(r.data.error), JSON.stringify(r.data));
    record(4, "Verification-token replay rejected (single-use)", true);
  } catch (e) { record(4, "Verify replay", false, e.message); }

  /* 5+6 · login success / failure (failure audited) */
  try {
    const bad = await A2("/api/customer/login", { email: "custa@example.com", password: "WrongPassword10" });
    assert(bad.status === 401, "wrong password must 401");
    const ok = await A2("/api/customer/login", { email: "custa@example.com", password: "PasswordA-10chars" });
    assert(ok.status === 200 && ok.data.me.customerId, JSON.stringify(ok.data));
    const d = serverDb();
    const failedAudit = d.prepare("SELECT count(*) n FROM audit WHERE action='customer.login.failed'").get().n;
    d.close();
    assert(failedAudit >= 1, "login failure must be audited");
    record(5, "Login succeeds with correct password (second device session)", true);
    record(6, "Login failure rejected and audited", true, failedAudit + " failed logins audited");
  } catch (e) { record(5, "Login", false, e.message); record(6, "Login failure", false, e.message); }

  /* 7 · password reset: enumeration-safe + full flow revokes sessions */
  try {
    const noAcct = await anon("/api/customer/reset/request", { email: "ghost@example.com" });
    const hasAcct = await anon("/api/customer/reset/request", { email: "custa@example.com" });
    assert(noAcct.data.message === hasAcct.data.message, "responses must be identical (no enumeration)");
    await new Promise(r2 => setTimeout(r2, 400));
    const token = tokenFrom(lastEmailTo("custa@example.com"), "reset");
    assert(token, "reset token only via email");
    const done = await anon("/api/customer/reset/complete", { token, password: "NewPasswordA-10" });
    assert(done.status === 200, JSON.stringify(done.data));
    const dead = await A("/api/customer/me");
    assert(dead.status === 401, "old sessions must be revoked after reset");
    const relog = await A("/api/customer/login", { email: "custa@example.com", password: "NewPasswordA-10" });
    assert(relog.status === 200, "new password must work");
    globalThis.usedResetToken = token;
    record(7, "Password reset: enumeration-safe, emailed token, all sessions revoked", true, `"${hasAcct.data.message}"`);
  } catch (e) { record(7, "Password reset", false, e.message); }

  /* 8 · reset-token expiration */
  try {
    const d = serverDb();
    const plain = crypto.randomBytes(32).toString("hex");
    const cid = d.prepare("SELECT id FROM customers WHERE email='custa@example.com'").get().id;
    d.prepare("INSERT INTO customer_tokens (kind, token_hash, customer_id, expires_at) VALUES ('reset', ?, ?, datetime('now','-1 minute'))")
      .run(sha256(plain), cid);
    d.close();
    const r = await anon("/api/customer/reset/complete", { token: plain, password: "AnotherPass-10" });
    assert(r.status === 400 && /invalid|expired|used/i.test(r.data.error), JSON.stringify(r.data));
    record(8, "Reset-token expiration enforced (expired token refused)", true);
  } catch (e) { record(8, "Reset expiry", false, e.message); }

  /* 9 · reset-token replay */
  try {
    const r = await anon("/api/customer/reset/complete", { token: globalThis.usedResetToken, password: "ReplayPass-10x" });
    assert(r.status === 400, JSON.stringify(r.data));
    const probe = jar();   // NEVER the anon jar — it must stay cookie-free for the guest tests
    const relog = await probe("/api/customer/login", { email: "custa@example.com", password: "NewPasswordA-10" });
    assert(relog.status === 200, "password must be unchanged after replay attempt");
    record(9, "Reset-token replay rejected; password unchanged", true);
  } catch (e) { record(9, "Reset replay", false, e.message); }

  /* 10 · guest request: same access, customer_id NULL */
  try {
    const r = await anon("/api/public/requests", REQ({ email: "guest@example.com", phone: "(305) 555-7200", customerName: "Guest Person" }));
    assert(r.status === 200 && r.data.requestId, JSON.stringify(r.data));
    const d = serverDb();
    const row = d.prepare("SELECT customer_id, ai_consent FROM requests WHERE request_id=?").get(r.data.requestId);
    d.close();
    assert(row.customer_id === null && row.ai_consent === "human", JSON.stringify(row));
    globalThis.guestReqId = r.data.requestId;
    record(10, "Guest request: identical pipeline, customer_id NULL, Human-only default", true, r.data.requestId);
  } catch (e) { record(10, "Guest request", false, e.message); }

  /* 11 · signed-in request: customer_id from SESSION (body value ignored) */
  try {
    const r = await A("/api/public/requests", REQ({
      email: "custa@example.com", phone: "(305) 555-7100",
      vehicleRequested: "Lamborghini Urus", startDate: "2027-07-01 10:00", endDate: "2027-07-03 10:00",
      customer_id: "C-FORGED", customerId: "C-FORGED"     // must be ignored
    }));
    assert(r.status === 200, JSON.stringify(r.data));
    const d = serverDb();
    const row = d.prepare("SELECT customer_id FROM requests WHERE request_id=?").get(r.data.requestId);
    const realId = d.prepare("SELECT customer_id FROM customers WHERE email='custa@example.com'").get().customer_id;
    d.close();
    assert(row.customer_id === realId && row.customer_id !== "C-FORGED", `expected ${realId}, got ${row.customer_id}`);
    globalThis.aReqId = r.data.requestId;
    record(11, "Signed-in request linked via server session; forged customer_id ignored", true, row.customer_id);
  } catch (e) { record(11, "Signed-in request", false, e.message); }

  /* 12 · request history shows own requests only */
  try {
    const t = await A("/api/customer/trips");
    assert(t.status === 200, JSON.stringify(t.data));
    const ids = t.data.requests.map(r => r.request_id);
    assert(ids.includes(globalThis.aReqId), "own request visible");
    assert(!ids.includes(globalThis.guestReqId), "guest request (same phone style, unauthenticated email) must NOT appear");
    record(12, "Trip/request history: only requests linked to the authenticated customer_id", true, ids.join(","));
  } catch (e) { record(12, "History", false, e.message); }

  /* 13 · customer B cannot see customer A's data */
  try {
    const rb = await Bc("/api/customer/register", { name: "Customer B", phone: "3055557300", email: "custb@example.com", password: "PasswordB-10chars" });
    assert(rb.status === 200, JSON.stringify(rb.data));
    /* register Customer C now, BEFORE the rate-limit test exhausts the registration limiter */
    const rc = await C("/api/customer/register", { name: "Customer C", phone: "3055557600", email: "custc@example.com", password: "PasswordC-10chars" });
    assert(rc.status === 200, "customer C registration: " + JSON.stringify(rc.data));
    const t = await Bc("/api/customer/trips");
    assert(t.data.requests.length === 0 && t.data.rentals.length === 0, "B must see nothing of A's");
    const me = await Bc("/api/customer/me");
    assert(me.data.me.email === "custb@example.com", "B sees only B");
    record(13, "Customer B cannot access Customer A's requests or profile", true);
  } catch (e) { record(13, "Cross-customer isolation", false, e.message); }

  /* 14 · customer session cannot reach staff APIs */
  try {
    const targets = ["/api/requests", "/api/vehicles", "/api/partners", "/api/rentals", "/api/settings", "/api/audit", "/api/users", "/api/autopilot/status"];
    for (const t of targets) {
      const r = await A(t);
      assert([401, 403].includes(r.status), `${t} must refuse a customer cookie, got ${r.status}`);
    }
    record(14, "Customer session blocked from ALL staff APIs", true, targets.length + " endpoints refused");
  } catch (e) { record(14, "Staff API isolation", false, e.message); }

  /* 15 · customer session cannot reach provider portal APIs */
  try {
    for (const t of ["/api/portal/vehicles", "/api/portal/bookings", "/api/portal/payouts", "/api/portal/messages"]) {
      const r = await A(t);
      assert([401, 403].includes(r.status), `${t} must refuse a customer cookie, got ${r.status}`);
    }
    record(15, "Customer session blocked from provider portal APIs", true);
  } catch (e) { record(15, "Provider API isolation", false, e.message); }

  /* 16 · staff session is NOT a customer session */
  try {
    const sl = await staff("/api/auth/login", { email: "sales@topnotchrentalz.com", password: "CustSales2026!!" });
    assert(sl.status === 200, "staff login");
    const r = await staff("/api/customer/me");
    assert(r.status === 401, "staff cookie must not read a customer account");
    record(16, "Staff session / customer session fully separated", true);
  } catch (e) { record(16, "Staff separation", false, e.message); }

  /* 17 · provider session is NOT a customer session */
  try {
    const pl = await partner("/api/auth/login", { email: "portal@velocityexotics.example", password: "CustPartner2026!!" });
    assert(pl.status === 200, "partner login");
    const r = await partner("/api/customer/me");
    assert(r.status === 401, "partner cookie must not read a customer account");
    const r2 = await partner("/api/customer/trips");
    assert(r2.status === 401, "partner cookie must not read customer trips");
    record(17, "Provider session / customer session fully separated", true);
  } catch (e) { record(17, "Provider separation", false, e.message); }

  /* 18 · AI opt-in recorded per request (choice + version + timestamp + audit) */
  try {
    const r = await anon("/api/public/requests", REQ({
      email: "optin@example.com", phone: "(305) 555-7400", customerName: "Opt In",
      vehicleRequested: "Porsche 911 Turbo S", startDate: "2027-08-01 10:00", endDate: "2027-08-03 10:00",
      aiChoice: "ai"
    }));
    const d = serverDb();
    const row = d.prepare("SELECT ai_consent, ai_consent_version, ai_consent_at FROM requests WHERE request_id=?").get(r.data.requestId);
    const audited = d.prepare("SELECT count(*) n FROM audit WHERE action='request.ai_consent' AND entity_id=?").get(r.data.requestId).n;
    d.close();
    assert(row.ai_consent === "ai" && row.ai_consent_version && row.ai_consent_at && audited === 1, JSON.stringify(row));
    record(18, "AI opt-in recorded: choice + policy version + timestamp + audit", true, `v${row.ai_consent_version}`);
  } catch (e) { record(18, "AI opt-in", false, e.message); }

  /* 19 · AI opt-out (and absence of choice) records human */
  try {
    const r = await anon("/api/public/requests", REQ({
      email: "optout@example.com", phone: "(305) 555-7500", customerName: "Opt Out",
      vehicleRequested: "Mercedes-AMG G63", startDate: "2027-08-05 10:00", endDate: "2027-08-07 10:00"
    }));
    const d = serverDb();
    const row = d.prepare("SELECT ai_consent FROM requests WHERE request_id=?").get(r.data.requestId);
    d.close();
    assert(row.ai_consent === "human", "default must be human");
    record(19, "AI opt-out/default: Human-only recorded when not explicitly opted in", true);
  } catch (e) { record(19, "AI opt-out", false, e.message); }

  /* 20 · consent withdrawal from account settings (audited) */
  try {
    const up = await A("/api/customer/me", { aiConsent: "ai" }, "PATCH", { "x-csrf": A.csrf() });
    assert(up.status === 200 && up.data.me.aiConsent === "ai", JSON.stringify(up.data));
    const down = await A("/api/customer/me", { aiConsent: "human" }, "PATCH", { "x-csrf": A.csrf() });
    assert(down.status === 200 && down.data.me.aiConsent === "human", JSON.stringify(down.data));
    const d = serverDb();
    const g = d.prepare("SELECT count(*) n FROM audit WHERE action='customer.consent.granted'").get().n;
    const w = d.prepare("SELECT count(*) n FROM audit WHERE action='customer.consent.withdrawn'").get().n;
    d.close();
    assert(g >= 1 && w >= 1, "grant + withdrawal must both be audited");
    record(20, "AI-consent withdrawal in account settings works and is audited", true, `granted×${g} withdrawn×${w}`);
  } catch (e) { record(20, "Consent withdrawal", false, e.message); }

  /* 21 · CSRF rejection on state-changing customer routes */
  try {
    const r = await A("/api/customer/me", { name: "CSRF Attack" }, "PATCH"); // no x-csrf header
    assert(r.status === 403 && /Security check/.test(r.data.error), JSON.stringify(r.data));
    const r2 = await A("/api/customer/logout-all", {}, "POST");
    assert(r2.status === 403, "logout-all without csrf must fail");
    const me = await A("/api/customer/me");
    assert(me.data.me.name !== "CSRF Attack", "name must be unchanged");
    record(21, "CSRF: state-changing routes reject missing/wrong x-csrf header", true);
  } catch (e) { record(21, "CSRF", false, e.message); }

  /* 22 · rate limiting on registration (shared DB-backed limiter) */
  try {
    let got429 = false;
    for (let i = 0; i < 10 && !got429; i++) {
      const r = await anon("/api/customer/register", { name: "RL", phone: "3055559999", email: `rl${i}@example.com`, password: "RateLimit-10ch" });
      if (r.status === 429) got429 = true;
    }
    assert(got429, "429 expected within 10 rapid registrations");
    const d = serverDb();
    const rows = d.prepare("SELECT count(*) n FROM rate_limits WHERE key LIKE '%cust-register%'").get().n;
    d.close();
    assert(rows >= 1, "shared rate_limits table must hold the counter (not process-only)");
    record(22, "Rate limiting: registration throttled; counter persisted in shared DB table", true);
  } catch (e) { record(22, "Rate limiting", false, e.message); }

  /* 23 · logout kills the session */
  try {
    await A2("/api/customer/login", { email: "custa@example.com", password: "NewPasswordA-10" });
    const out = await A2("/api/customer/logout", {});
    assert(out.status === 200, "logout ok");
    const me = await A2("/api/customer/me");
    assert(me.status === 401, "session must be dead after logout");
    record(23, "Logout invalidates the session", true);
  } catch (e) { record(23, "Logout", false, e.message); }

  /* 24 · logout-all revokes every device */
  try {
    const D1 = jar(), D2 = jar();
    await D1("/api/customer/login", { email: "custa@example.com", password: "NewPasswordA-10" });
    await D2("/api/customer/login", { email: "custa@example.com", password: "NewPasswordA-10" });
    const out = await D1("/api/customer/logout-all", {}, "POST", { "x-csrf": D1.csrf() });
    assert(out.status === 200 && out.data.revoked >= 2, JSON.stringify(out.data));
    const d2 = await D2("/api/customer/me");
    assert(d2.status === 401, "second device must be signed out too");
    const audited = (() => { const d = serverDb(); const n = d.prepare("SELECT count(*) n FROM audit WHERE action='customer.logout.all'").get().n; d.close(); return n; })();
    assert(audited >= 1, "revocation audited");
    record(24, "Sign out of all devices revokes every session (audited)", true, out.data.revoked + " sessions");
  } catch (e) { record(24, "Logout all", false, e.message); }

  /* 25+26 · account deletion + deleted-account login/session protection */
  try {
    const wrong = await C("/api/customer/me", { password: "wrongpass-10" }, "DELETE", { "x-csrf": C.csrf() });
    assert(wrong.status === 400, "wrong password must block deletion");
    const del = await C("/api/customer/me", { password: "PasswordC-10chars" }, "DELETE", { "x-csrf": C.csrf() });
    assert(del.status === 200, JSON.stringify(del.data));
    const me = await C("/api/customer/me");
    assert(me.status === 401, "old session cookie must be dead");
    const relog = await C("/api/customer/login", { email: "custc@example.com", password: "PasswordC-10chars" });
    assert(relog.status === 401, "deleted account must not log in");
    const d = serverDb();
    const gone = d.prepare("SELECT count(*) n FROM customers WHERE email='custc@example.com'").get().n;
    const audited = d.prepare("SELECT count(*) n FROM audit WHERE action='customer.delete'").get().n;
    d.close();
    assert(gone === 0 && audited >= 1, "row deleted + audited");
    record(25, "Permanent account deletion (password-confirmed, audited)", true);
    record(26, "Deleted-account protection: login and old sessions both fail", true);
  } catch (e) { record(25, "Deletion", false, e.message); record(26, "Deleted-account protection", false, e.message); }

  /* 27 · offline honesty: served JS contains the honest-failure path and no fake IDs */
  try {
    const js = await (await fetch(B + "/js/main.js")).text();
    assert(js.includes("We could not send your request") || js.includes("could not send"), "honest failure copy must be served");
    assert(js.includes("Nothing was booked or charged"), "explicit nothing-booked copy required");
    assert(!js.includes("const newRequestId"), "local request-ID generator must be gone");
    assert(js.includes("tn_unsent_requests") && js.includes("unsent: true"), "unsent recovery storage must be labeled");
    assert(js.includes("Preview — no request was sent."), "preview mode must self-identify");
    record(27, "Offline fake-success vulnerability patched (no local TN ids, honest failure, labeled unsent)", true);
  } catch (e) { record(27, "Offline honesty", false, e.message); }

  /* 28 · provider confirmation still required before quote/payment */
  try {
    const admin = jar();
    await admin("/api/auth/login", { email: "admin@topnotchrentalz.com", password: "CustAdmin2026!!" });
    const q = await admin(`/api/requests/${globalThis.aReqId}/quote`, { amount: 2500 }, "POST");
    assert(q.status === 400, "quote before provider confirmation must be rejected: " + JSON.stringify(q.data));
    record(28, "Provider confirmation requirement intact (no quote before confirm)", true, q.data.error?.slice(0, 60));
  } catch (e) { record(28, "Provider confirmation", false, e.message); }

  /* 29 · payment verification gate intact (no pay before quote acceptance) */
  try {
    const r = await anon("/api/public/pay", { requestId: globalThis.aReqId, phone: "7100", method: "card" });
    assert(r.status === 400 || r.data.state === "not-ready" || r.data.error, "payment before an accepted quote must not proceed: " + JSON.stringify(r.data));
    record(29, "Payment verification pipeline gate intact (no premature payment)", true);
  } catch (e) { record(29, "Payment gate", false, e.message); }

  /* 30 · double-booking prevention intact (F8 booked dates conflict) */
  try {
    const r = await anon("/api/public/requests", REQ({
      email: "dbl@example.com", phone: "(305) 555-7700", customerName: "Double Book",
      vehicleRequested: "Ferrari F8 Tributo", startDate: "2026-07-05 10:00", endDate: "2026-07-08 10:00"
    }));
    const d = serverDb();
    const row = d.prepare("SELECT availability_status FROM requests WHERE request_id=?").get(r.data.requestId);
    d.close();
    assert(row.availability_status === "unavailable", "overlapping dates must be unavailable, got " + row.availability_status);
    record(30, "Double-booking prevention intact (date conflict → unavailable)", true);
  } catch (e) { record(30, "Double booking", false, e.message); }

  /* 31 · signature services: stable IDs stored, unknown IDs dropped */
  try {
    const cat = await anon("/api/public/services");
    assert(cat.data.services.length === 10 && cat.data.note === "Request — confirmed separately.", "catalog must list 10 services");
    const r = await anon("/api/public/requests", REQ({
      email: "svc@example.com", phone: "(305) 555-7800", customerName: "Svc Test",
      vehicleRequested: "Lamborghini Urus", startDate: "2027-09-01 10:00", endDate: "2027-09-03 10:00",
      services: ["arrival-reset-kit", "family-arrival", "free-champagne-hoax", "<script>x</script>"]
    }));
    assert(r.data.services.length === 2, "only valid stable IDs may be stored: " + JSON.stringify(r.data.services));
    globalThis.svcReqId = r.data.requestId;
    record(31, "Signature services: 10-item catalog, stable IDs only, junk rejected", true, r.data.services.join(","));
  } catch (e) { record(31, "Signature services", false, e.message); }

  /* 32+33 · service cannot be approved/charged before the checklist passes */
  try {
    const admin = jar();
    await admin("/api/auth/login", { email: "admin@topnotchrentalz.com", password: "CustAdmin2026!!" });
    const list = await admin(`/api/services/orders?requestId=${globalThis.svcReqId}`);
    assert(list.data.orders.length === 2, "two orders expected");
    const oid = list.data.orders[0].id;
    const early = await admin(`/api/services/orders/${oid}`, { status: "approved" }, "PATCH");
    assert(early.status === 409 && /checklist is incomplete/.test(early.data.error), JSON.stringify(early.data));
    /* complete the checklist properly, then approve */
    const done = await admin(`/api/services/orders/${oid}`, {
      status: "approved",
      vendor: "Miami Concierge Co", vendorPrice: 180, fulfillmentOwner: "ops@topnotchrentalz.com",
      checklist: {
        safety_questions: true, allergy_requirements: true, child_seat_size: "n/a",
        location_permission: true, vendor_assigned: true, vendor_price_confirmed: true,
        customer_approved_price: true, timing_confirmed: true, fulfillment_owner: true,
        completion_evidence: true
      }
    }, "PATCH");
    assert(done.status === 200 && done.data.checklistPassed, JSON.stringify(done.data));
    record(32, "Service approval blocked until 11-item ops checklist passes (409)", true, early.data.error.slice(0, 60));
    record(33, "Service approves only after full checklist incl. customer price approval", true);
  } catch (e) { record(32, "Service gate", false, e.message); record(33, "Service approval", false, e.message); }

  proc.kill(); mockMail.close();
}

async function main() {
  await partA();
  await partB();

  const pass = results.filter(r => r.ok).length;
  const md = ["# Customer Accounts, Guest Booking & Privacy Hardening — Test Results", "",
    `Run: ${new Date().toISOString()} · fresh staging databases · email captured via mock webhook · OpenAI mocked locally`,
    "", "| # | Scenario | Result | Detail |", "|---|----------|--------|--------|",
    ...results.map(r => `| ${r.n} | ${r.name} | ${r.ok ? "✅ PASS" : "❌ FAIL"} | ${String(r.detail).replace(/\|/g, "/")} |`),
    "", `**${pass}/${results.length} passed.**`].join("\n");
  fs.writeFileSync(path.join(ROOT, "TEST-RESULTS-CUSTOMER.md"), md);
  console.log(`\n${pass}/${results.length} passed → TEST-RESULTS-CUSTOMER.md`);

  fs.rmSync(TESTDATA, { recursive: true, force: true });
  fs.rmSync(LIBDATA, { recursive: true, force: true });
  process.exit(pass === results.length ? 0 : 1);
}
main().catch(e => { console.error("FATAL", e); proc.kill(); process.exit(1); });
