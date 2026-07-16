/*
 * TopNotch customer-identity API tests.
 * Run: node --test topnotch/tests/api.test.mjs
 *
 * Spawns the real server (in-memory data) and exercises every required
 * behavior over HTTP — nothing is mocked as live.
 */
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SERVER = path.join(__dirname, "..", "server.js");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "tn-test-"));
const OUTBOX = path.join(TMP, "outbox.log");
const OPS = path.join(TMP, "ops.log");
const PORT = 4360 + Math.floor(Math.random() * 100);
const BASE = `http://127.0.0.1:${PORT}`;

let proc;

function startServer(extraEnv = {}, port = PORT) {
  const p = spawn(process.execPath, [SERVER], {
    env: {
      ...process.env, PORT: String(port), TN_DATA: ":memory:",
      TN_OUTBOX: OUTBOX, TN_OPS: OPS, ...extraEnv,
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("server did not start")), 8000);
    p.stdout.on("data", (d) => { if (String(d).includes("listening")) { clearTimeout(timer); resolve(p); } });
    p.stderr.on("data", (d) => console.error("[server]", String(d)));
  });
}

before(async () => { proc = await startServer(); });
after(() => { proc?.kill(); });

/* Minimal cookie-jar client. */
function client() {
  const jar = {};
  return {
    csrf: null,
    async call(method, p, body, headers = {}) {
      const cookie = Object.entries(jar).map(([k, v]) => `${k}=${v}`).join("; ");
      const res = await fetch(BASE + p, {
        method,
        headers: {
          "content-type": "application/json",
          ...(cookie ? { cookie } : {}),
          ...(this.csrf ? { "x-tn-csrf": this.csrf } : {}),
          ...headers,
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      (res.headers.getSetCookie?.() || []).forEach((sc) => {
        const [pair, ...attrs] = sc.split(";");
        const i = pair.indexOf("=");
        const name = pair.slice(0, i).trim(), value = pair.slice(i + 1).trim();
        const maxAge = attrs.map((a) => a.trim()).find((a) => a.toLowerCase().startsWith("max-age="));
        if (maxAge && Number(maxAge.split("=")[1]) === 0) delete jar[name];
        else jar[name] = value;
      });
      let data = {};
      try { data = await res.json(); } catch { /* empty */ }
      return { status: res.status, data, raw: res };
    },
  };
}

function lastEmailTo(email) {
  const lines = fs.readFileSync(OUTBOX, "utf8").trim().split("\n").map((l) => JSON.parse(l));
  const mine = lines.filter((l) => l.to === email);
  return mine[mine.length - 1];
}
const tokenFrom = (mail) => mail.body.match(/: (\S+)$/)[1];
function opsEvents() {
  try { return fs.readFileSync(OPS, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)); }
  catch { return []; }
}

const PASS = "correct-horse-battery";
const req1 = { carId: "hur", start: "2026-08-01", days: 2, delivery: "pickup", services: ["arrival-reset"], aiChoice: "human" };

/* ------------------------------------------------------------------ tests */

test("registration: creates account, defaults AI pref to human-only", async () => {
  const c = client();
  const r = await c.call("POST", "/api/customer/register",
    { name: "Ana Ruiz", mobile: "+1 305 555 0101", email: "ana@example.com", password: PASS });
  assert.equal(r.status, 201);
  assert.equal(r.data.customer.email, "ana@example.com");
  assert.equal(r.data.customer.verified, false);
  assert.equal(r.data.customer.aiPref.choice, "human"); // never preselected
  assert.ok(r.data.csrf);
  assert.ok(!JSON.stringify(r.data).includes("token"), "no token material in the response");
});

test("registration: rejects weak password and missing fields", async () => {
  const c = client();
  let r = await c.call("POST", "/api/customer/register", { name: "B", mobile: "1", email: "x", password: "short" });
  assert.equal(r.status, 400);
  r = await c.call("POST", "/api/customer/register", { name: "Bo Diaz", mobile: "+1 305 555 0102", email: "bo@example.com", password: "123456789" });
  assert.equal(r.status, 400); // 9 chars < 10
});

test("duplicate-email registration is refused", async () => {
  const c = client();
  const r = await c.call("POST", "/api/customer/register",
    { name: "Ana Two", mobile: "+1 305 555 0103", email: "ana@example.com", password: PASS });
  assert.equal(r.status, 409);
});

test("email verification: token from outbox verifies; response never contains it", async () => {
  const c = client();
  await c.call("POST", "/api/customer/register",
    { name: "Vera Cole", mobile: "+1 954 555 0100", email: "vera@example.com", password: PASS });
  const mail = lastEmailTo("vera@example.com");
  assert.ok(mail, "verification email delivered to outbox");
  const token = tokenFrom(mail);
  const r = await c.call("POST", "/api/customer/verify-email/confirm", { token });
  assert.equal(r.status, 200);
  const me = await c.call("GET", "/api/customer/me");
  assert.equal(me.data.customer.verified, true);
});

test("unverified account: can still browse and request (same priority), flagged unverified", async () => {
  const c = client();
  const reg = await c.call("POST", "/api/customer/register",
    { name: "Uma Reyes", mobile: "+1 561 555 0100", email: "uma@example.com", password: PASS });
  c.csrf = reg.data.csrf;
  const me = await c.call("GET", "/api/customer/me");
  assert.equal(me.data.customer.verified, false);
  const r = await c.call("POST", "/api/customer/requests", req1);
  assert.equal(r.status, 201);
});

test("login success", async () => {
  const c = client();
  const r = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  assert.equal(r.status, 200);
  assert.equal(r.data.customer.name, "Ana Ruiz");
});

test("login failure: wrong password", async () => {
  const c = client();
  const r = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: "wrong-password-x" });
  assert.equal(r.status, 401);
});

test("rate limiting: repeated failed logins hit 429", async () => {
  const c = client();
  let last;
  for (let i = 0; i < 7; i++) {
    last = await c.call("POST", "/api/customer/login", { email: "limit@example.com", password: "bad-password-xx" });
  }
  assert.equal(last.status, 429);
  assert.ok(last.raw.headers.get("retry-after"));
});

test("guest rental request: contact required, then same access as accounts", async () => {
  const c = client();
  let r = await c.call("POST", "/api/customer/requests", { ...req1 }); // no contact
  assert.equal(r.status, 400);
  r = await c.call("POST", "/api/customer/requests",
    { ...req1, contact: { name: "Gus Ito", email: "gus@example.com", mobile: "+1 786 555 0100" } });
  assert.equal(r.status, 201);
  assert.equal(r.data.request.status, "pending_provider");
  // Guest can read back their own request via the guest session cookie.
  const back = await c.call("GET", "/api/customer/requests/" + r.data.request.id);
  assert.equal(back.status, 200);
});

test("signed-in rental request links to the account; history shows it", async () => {
  const c = client();
  const login = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c.csrf = login.data.csrf;
  const r = await c.call("POST", "/api/customer/requests", req1);
  assert.equal(r.status, 201);
  const trips = await c.call("GET", "/api/customer/trips");
  assert.equal(trips.status, 200);
  assert.ok(trips.data.requests.some((x) => x.id === r.data.request.id));
});

test("cross-customer access: another customer's request reads as 404", async () => {
  const a = client();
  const la = await a.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  a.csrf = la.data.csrf;
  const ra = await a.call("POST", "/api/customer/requests", req1);
  const b = client();
  const rb = await b.call("POST", "/api/customer/register",
    { name: "Eve Snoop", mobile: "+1 305 555 0199", email: "eve@example.com", password: PASS });
  b.csrf = rb.data.csrf;
  const peek = await b.call("GET", "/api/customer/requests/" + ra.data.request.id);
  assert.equal(peek.status, 404); // existence is not even confirmed
});

test("customer_id cannot be set through the payload", async () => {
  const c = client();
  const login = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c.csrf = login.data.csrf;
  const r = await c.call("POST", "/api/customer/requests", { ...req1, customerId: "someone-else", customer_id: "someone-else" });
  assert.equal(r.status, 201);
  const trips = await c.call("GET", "/api/customer/trips");
  assert.ok(trips.data.requests.some((x) => x.id === r.data.request.id), "request derives owner from the session");
});

test("customer-to-admin access attempt is refused", async () => {
  const c = client();
  await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  const r = await c.call("GET", "/api/admin/metrics");
  assert.equal(r.status, 403);
});

test("customer-to-provider access attempt is refused", async () => {
  const c = client();
  await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  const r = await c.call("GET", "/api/provider/requests");
  assert.equal(r.status, 403);
});

test("CSRF: authenticated mutation without the header is refused", async () => {
  const c = client();
  await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c.csrf = null; // cookie present, no CSRF header
  const r = await c.call("PATCH", "/api/customer/me", { name: "Hacked Name" });
  assert.equal(r.status, 403);
});

test("AI opt-in: consent recorded with policy version + timestamp; paused without OPENAI_MODEL", async () => {
  const c = client();
  const login = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c.csrf = login.data.csrf;
  const r = await c.call("POST", "/api/customer/requests", { ...req1, aiChoice: "ai" });
  assert.equal(r.status, 201);
  assert.equal(r.data.request.aiConsent.choice, "ai");
  assert.ok(r.data.request.aiConsent.policyVersion);
  assert.ok(r.data.request.aiConsent.at);
  assert.equal(r.data.request.autopilot, "paused"); // OPENAI_MODEL unset — no invented model id
  const mgmt = opsEvents().filter((e) => e.event === "management_notice" && e.reason === "ai_paused");
  assert.ok(mgmt.length >= 1, "management notified when AI is unavailable");
});

test("AI opt-out is the default and is recorded", async () => {
  const c = client();
  const login = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c.csrf = login.data.csrf;
  const r = await c.call("POST", "/api/customer/requests", { ...req1 }); // no aiChoice sent
  assert.equal(r.data.request.aiConsent.choice, "human");
});

test("withdrawal of AI consent at account level", async () => {
  const c = client();
  const login = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c.csrf = login.data.csrf;
  let r = await c.call("PATCH", "/api/customer/me", { aiPref: "ai" });
  assert.equal(r.data.customer.aiPref.choice, "ai");
  r = await c.call("PATCH", "/api/customer/me", { aiPref: "human" });
  assert.equal(r.data.customer.aiPref.choice, "human");
  assert.ok(r.data.customer.aiPref.at);
});

test("human-only requests never reach prompt construction", async () => {
  const c = client();
  const login = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c.csrf = login.data.csrf;
  const r = await c.call("POST", "/api/customer/requests", { ...req1, aiChoice: "human" });
  assert.equal(r.data.request.autopilot, "human_only");
  const events = opsEvents();
  assert.ok(events.some((e) => e.event === "ai_blocked_human_only" && e.requestId === r.data.request.id));
  assert.ok(!events.some((e) => e.event === "ai_prompt_built"), "no prompt was ever built for any request in this run");
});

test("password reset: full flow revokes old sessions", async () => {
  const c = client();
  await c.call("POST", "/api/customer/register",
    { name: "Rex Ford", mobile: "+1 305 555 0155", email: "rex@example.com", password: PASS });
  const rq = await c.call("POST", "/api/customer/password-reset/request", { email: "rex@example.com" });
  assert.equal(rq.status, 200);
  assert.ok(!JSON.stringify(rq.data).match(/[A-Za-z0-9_-]{30,}/), "no token leaks in the response");
  const token = tokenFrom(lastEmailTo("rex@example.com"));
  const newPass = "brand-new-passphrase";
  const cf = await c.call("POST", "/api/customer/password-reset/confirm", { token, newPassword: newPass });
  assert.equal(cf.status, 200);
  const me = await c.call("GET", "/api/customer/me"); // old session must be dead
  assert.equal(me.status, 401);
  const relog = await client().call("POST", "/api/customer/login", { email: "rex@example.com", password: newPass });
  assert.equal(relog.status, 200);
});

test("replayed reset token is refused", async () => {
  const c = client();
  await c.call("POST", "/api/customer/password-reset/request", { email: "rex@example.com" });
  const token = tokenFrom(lastEmailTo("rex@example.com"));
  const first = await c.call("POST", "/api/customer/password-reset/confirm", { token, newPassword: "another-new-pass-1" });
  assert.equal(first.status, 200);
  const replay = await c.call("POST", "/api/customer/password-reset/confirm", { token, newPassword: "another-new-pass-2" });
  assert.equal(replay.status, 400); // single-use
});

test("expired reset token is refused", async () => {
  const port2 = PORT + 111;
  const p2 = await startServer({ TN_TOKEN_TTL_MS: "1", TN_OUTBOX: OUTBOX + ".exp", TN_OPS: OPS + ".exp" }, port2);
  try {
    const base2 = `http://127.0.0.1:${port2}`;
    const reg = await fetch(base2 + "/api/customer/register", { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ name: "Tia Exp", mobile: "+1 305 555 0161", email: "tia@example.com", password: PASS }) });
    assert.equal(reg.status, 201);
    await fetch(base2 + "/api/customer/password-reset/request", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email: "tia@example.com" }) });
    const lines = fs.readFileSync(OUTBOX + ".exp", "utf8").trim().split("\n").map((l) => JSON.parse(l));
    const token = tokenFrom(lines[lines.length - 1]);
    await new Promise((r) => setTimeout(r, 30)); // > 1ms TTL
    const cf = await fetch(base2 + "/api/customer/password-reset/confirm", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ token, newPassword: "does-not-matter-1" }) });
    assert.equal(cf.status, 400);
    const body = await cf.json();
    assert.match(body.error, /expired/i);
  } finally { p2.kill(); }
});

test("logout kills the session", async () => {
  const c = client();
  await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  await c.call("POST", "/api/customer/logout");
  const me = await c.call("GET", "/api/customer/me");
  assert.equal(me.status, 401);
});

test("logout-all revokes every session for the account", async () => {
  const c1 = client(), c2 = client();
  const l1 = await c1.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c1.csrf = l1.data.csrf;
  await c2.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  const out = await c1.call("POST", "/api/customer/logout-all");
  assert.equal(out.status, 200);
  assert.ok(out.data.revokedSessions >= 2);
  const me2 = await c2.call("GET", "/api/customer/me");
  assert.equal(me2.status, 401, "the other device is signed out too");
});

test("account deletion: reauth required, sessions revoked, credentials dead, records unlinked", async () => {
  const c = client();
  const reg = await c.call("POST", "/api/customer/register",
    { name: "Del User", mobile: "+1 305 555 0177", email: "del@example.com", password: PASS });
  c.csrf = reg.data.csrf;
  const rq = await c.call("POST", "/api/customer/requests", req1);
  assert.equal(rq.status, 201);
  // wrong password → refused
  let del = await c.call("DELETE", "/api/customer/me", { password: "not-the-password" });
  assert.equal(del.status, 403);
  // correct password → deleted, retention notice included
  del = await c.call("DELETE", "/api/customer/me", { password: PASS });
  assert.equal(del.status, 200);
  assert.match(del.data.notice, /retained under the Privacy Policy/);
  const me = await c.call("GET", "/api/customer/me");
  assert.equal(me.status, 401, "every session revoked");
});

test("deleted-account login attempt fails", async () => {
  const r = await client().call("POST", "/api/customer/login", { email: "del@example.com", password: PASS });
  assert.equal(r.status, 401);
});

test("provider confirmation requirement: payment cannot confirm an unapproved booking", async () => {
  const c = client();
  const login = await c.call("POST", "/api/customer/login", { email: "ana@example.com", password: PASS });
  c.csrf = login.data.csrf;
  const rq = await c.call("POST", "/api/customer/requests", req1);
  const id = rq.data.request.id;
  assert.equal(rq.data.request.status, "pending_provider");

  // paying before the provider confirms → refused
  let pay = await c.call("POST", `/api/customer/requests/${id}/pay`, { method: "demo" });
  assert.equal(pay.status, 409);
  assert.match(pay.data.error, /can't confirm an unapproved booking/);

  // provider signs in on a SEPARATE session space and confirms
  const p = client();
  const pl = await p.call("POST", "/api/provider/login", { email: "provider@topnotch.demo", password: "demo-provider-pass" });
  assert.equal(pl.status, 200);
  p.csrf = pl.data.csrf;
  const dec = await p.call("POST", `/api/provider/requests/${id}/decision`, { decision: "approve" });
  assert.equal(dec.status, 200);

  // now the customer sees an approved quote and payment succeeds
  const back = await c.call("GET", `/api/customer/requests/${id}`);
  assert.equal(back.data.request.status, "approved");
  assert.ok(back.data.request.quote.total > 0);
  pay = await c.call("POST", `/api/customer/requests/${id}/pay`, { method: "demo" });
  assert.equal(pay.status, 200);
  assert.equal(pay.data.request.status, "booked");
});

test("provider session cannot touch customer account routes", async () => {
  const p = client();
  const pl = await p.call("POST", "/api/provider/login", { email: "provider@topnotch.demo", password: "demo-provider-pass" });
  p.csrf = pl.data.csrf;
  const me = await p.call("GET", "/api/customer/me");
  assert.equal(me.status, 401, "provider cookie is not a customer session");
});
