/* ============================================================
   Customer accounts (WEBSITE CUSTOMER ACCOUNTS pass)

   Completely separate from staff/provider auth:
   - own table, own session store, own cookie (tn_cust)
   - a customer session can NEVER satisfy req.user (staff) checks
   - customer_id is always derived from the server session; the
     browser can never supply or change it
   - verification + reset tokens: random, single-use, short-lived,
     stored ONLY as sha256 hashes, delivered by the email system,
     never returned through any API
   - shared (DB-backed) rate limiting so limits survive restarts
     and apply across processes
   ============================================================ */
const crypto = require("node:crypto");
const { db } = require("./db");
const U = require("./util");
const { hashPassword, verifyPassword } = require("./auth");
const emails = require("./emails");

const sha256 = s => crypto.createHash("sha256").update(s).digest("hex");
const S = k => db.prepare("SELECT value FROM settings WHERE key=?").get(k)?.value || "";

/* ---------------- schema (additive only) ---------------- */
db.exec(`
CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id TEXT UNIQUE,
  name TEXT, phone TEXT,
  email TEXT UNIQUE COLLATE NOCASE,
  pass_hash TEXT, salt TEXT,
  email_verified INTEGER DEFAULT 0,
  ai_consent TEXT DEFAULT 'human',
  ai_consent_version TEXT DEFAULT '',
  ai_consent_at TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS customer_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  token_hash TEXT UNIQUE,
  customer_id INTEGER NOT NULL,
  csrf TEXT NOT NULL,
  ip TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  last_seen TEXT DEFAULT (datetime('now')),
  expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS customer_tokens (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT CHECK (kind IN ('verify','reset')),
  token_hash TEXT UNIQUE,
  customer_id INTEGER NOT NULL,
  expires_at TEXT NOT NULL,
  used INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS rate_limits (
  key TEXT PRIMARY KEY,
  window_start INTEGER,
  count INTEGER DEFAULT 0
);
`);
/* additive columns on requests: account linkage + per-request AI consent */
for (const col of ["customer_id TEXT", "ai_consent TEXT DEFAULT 'human'",
  "ai_consent_version TEXT DEFAULT ''", "ai_consent_at TEXT"]) {
  try { db.exec(`ALTER TABLE requests ADD COLUMN ${col}`); } catch (e) { /* exists */ }
}

/* ---------------- shared DB-backed rate limiter ----------------
   Survives restarts and is shared by every process on the same DB —
   the in-memory limiter in util.js remains as a fast first line. */
function dbRateLimit(key, max, windowMs) {
  const now = Date.now();
  const row = db.prepare("SELECT * FROM rate_limits WHERE key=?").get(key);
  if (!row || now - row.window_start > windowMs) {
    db.prepare(`INSERT INTO rate_limits (key, window_start, count) VALUES (?,?,1)
      ON CONFLICT(key) DO UPDATE SET window_start=excluded.window_start, count=1`).run(key, now);
    return true;
  }
  db.prepare("UPDATE rate_limits SET count=count+1 WHERE key=?").run(key);
  if (Math.random() < 0.01) db.prepare("DELETE FROM rate_limits WHERE window_start < ?").run(now - 24 * 36e5);
  return row.count + 1 <= max;
}
const limited = (req, key, max, windowMs) =>
  !U.rateLimit(req.ip, key, max, windowMs) || !dbRateLimit(`${req.ip}:${key}`, max, windowMs);

/* ---------------- sessions (30-day absolute, 7-day idle) ---------------- */
const CUST_ABS_DAYS = 30, CUST_IDLE_DAYS = 7;

function createCustomerSession(customerRowId, ip) {
  const token = crypto.randomBytes(32).toString("hex");
  const csrf = crypto.randomBytes(24).toString("hex");
  db.prepare("INSERT INTO customer_sessions (token_hash, customer_id, csrf, ip, expires_at) VALUES (?,?,?,?,datetime('now', ?))")
    .run(sha256(token), customerRowId, csrf, ip || "", `+${CUST_ABS_DAYS} days`);
  return { token, csrf };
}

function customerFromToken(token) {
  if (!token) return null;
  const s = db.prepare("SELECT * FROM customer_sessions WHERE token_hash=?").get(sha256(token));
  if (!s) return null;
  const now = Date.now();
  if (now > Date.parse(s.expires_at + "Z") || now - Date.parse(s.last_seen + "Z") > CUST_IDLE_DAYS * 864e5) {
    db.prepare("DELETE FROM customer_sessions WHERE id=?").run(s.id);
    return null;
  }
  db.prepare("UPDATE customer_sessions SET last_seen=datetime('now') WHERE id=?").run(s.id);
  const c = db.prepare("SELECT * FROM customers WHERE id=?").get(s.customer_id);
  if (!c) { db.prepare("DELETE FROM customer_sessions WHERE id=?").run(s.id); return null; } // deleted-account protection
  return { ...c, sessionCsrf: s.csrf, sessionId: s.id };
}

/* parse the tn_cust cookie off a request — the ONLY way a customer
   identity ever enters the server. Never trusts body/query values. */
function fromReq(req) {
  const raw = (req.headers.cookie || "").split(/;\s*/).find(c => c.startsWith("tn_cust="))?.slice(8) || null;
  return customerFromToken(raw);
}
function csrfOk(req, cust) {
  return !!cust && req.headers["x-csrf"] === cust.sessionCsrf;
}

function setCustomerCookies(res, token, csrf) {
  const secure = process.env.TN_SECURE_COOKIES === "1" ? "; Secure" : "";
  const kill = token ? "" : "; Max-Age=0";
  res.setHeader("Set-Cookie", [
    `tn_cust=${token || ""}; HttpOnly; SameSite=Lax; Path=/${secure}${kill}`,
    /* csrf cookie is deliberately readable by same-origin JS so it can be
       echoed in the x-csrf header (double-submit + custom-header pattern) */
    `tn_cust_csrf=${csrf || ""}; SameSite=Lax; Path=/${secure}${kill}`
  ]);
}

/* ---------------- account e-mails (tokens only ever leave via email) ---------------- */
async function sendAccountEmail(kind, customer, token) {
  const base = process.env.TN_BASE_URL || "";
  const link = kind === "verify"
    ? `${base}/account.html#verify=${token}`
    : `${base}/account.html#reset=${token}`;
  const subject = kind === "verify" ? "Verify your TopNotchRentalz email" : "Reset your TopNotchRentalz password";
  const body = kind === "verify"
    ? `<p>Hi ${customer.name.split(" ")[0]},</p><p>Confirm this email address for your TopNotchRentalz account:</p><p><a href="${link}">${link}</a></p><p>This link works once and expires in 24 hours. If you didn't create an account, ignore this email.</p>`
    : `<p>Hi ${customer.name.split(" ")[0]},</p><p>Reset your TopNotchRentalz password:</p><p><a href="${link}">${link}</a></p><p>This link works once and expires in 30 minutes. If you didn't request this, ignore this email — your password is unchanged.</p>`;
  return emails.sendEmail(customer.email, subject, body);
}

function issueToken(kind, customerRowId) {
  const token = crypto.randomBytes(32).toString("hex");
  db.prepare("INSERT INTO customer_tokens (kind, token_hash, customer_id, expires_at) VALUES (?,?,?,datetime('now', ?))")
    .run(kind, sha256(token), customerRowId, kind === "verify" ? "+24 hours" : "+30 minutes");
  return token;
}
function consumeToken(kind, token) {
  const r = db.prepare("SELECT * FROM customer_tokens WHERE kind=? AND token_hash=? AND used=0 AND expires_at > datetime('now')")
    .get(kind, sha256(token || ""));
  if (!r) return null;                       // replay, expiry and forgery all land here
  db.prepare("UPDATE customer_tokens SET used=1 WHERE id=?").run(r.id);
  return r.customer_id;
}

/* ---------------- account operations ---------------- */
const PASSWORD_MIN = 10;
const CUST_ACTOR = c => ({ email: c.email, role: "customer" });

async function register({ name, phone, email, password }, ip) {
  name = U.strip(name); phone = U.strip(phone); email = U.strip(email).toLowerCase();
  if (!name || name.length < 2) return { error: "Valid name required" };
  if (!U.isPhone(phone)) return { error: "Valid phone required" };
  if (!U.isEmail(email)) return { error: "Valid email required" };
  if (String(password || "").length < PASSWORD_MIN) return { error: `Password must be at least ${PASSWORD_MIN} characters` };
  if (db.prepare("SELECT 1 FROM customers WHERE email=?").get(email))
    return { error: "An account with that email already exists — sign in or use password recovery." };
  const { salt, hash } = hashPassword(password);
  const customerId = "C-" + crypto.randomBytes(4).toString("hex").toUpperCase();
  const info = db.prepare(`INSERT INTO customers (customer_id, name, phone, email, pass_hash, salt, ai_consent, ai_consent_version)
    VALUES (?,?,?,?,?,?, 'human', ?)`).run(customerId, name, phone, email, hash, salt, S("policy_version"));
  const c = db.prepare("SELECT * FROM customers WHERE id=?").get(info.lastInsertRowid);
  U.audit(CUST_ACTOR(c), "customer.register", "customer", customerId, null, null, null);
  const delivery = await sendAccountEmail("verify", c, issueToken("verify", c.id)).catch(() => "recorded");
  const sess = createCustomerSession(c.id, ip);
  return { ok: true, customer: c, session: sess, verifyDelivery: delivery };
}

function login(email, password, ip) {
  email = U.strip(email).toLowerCase();
  const c = db.prepare("SELECT * FROM customers WHERE email=?").get(email);
  if (!c || !verifyPassword(String(password || ""), c.salt, c.pass_hash)) {
    U.audit({ email, role: "customer?" }, "customer.login.failed", "customer", email);
    return { error: "Invalid email or password" };
  }
  U.audit(CUST_ACTOR(c), "customer.login", "customer", c.customer_id);
  return { ok: true, customer: c, session: createCustomerSession(c.id, ip) };
}

function logout(req) {
  const raw = (req.headers.cookie || "").split(/;\s*/).find(x => x.startsWith("tn_cust="))?.slice(8);
  if (raw) db.prepare("DELETE FROM customer_sessions WHERE token_hash=?").run(sha256(raw));
}
function logoutAll(cust) {
  const n = db.prepare("DELETE FROM customer_sessions WHERE customer_id=?").run(cust.id).changes;
  U.audit(CUST_ACTOR(cust), "customer.logout.all", "customer", cust.customer_id, "sessions", n, 0);
  return n;
}

/* the ONLY fields a customer may see about themselves */
const publicMe = c => ({
  customerId: c.customer_id, name: c.name, phone: c.phone, email: c.email,
  emailVerified: !!c.email_verified, aiConsent: c.ai_consent,
  aiConsentVersion: c.ai_consent_version, aiConsentAt: c.ai_consent_at, createdAt: c.created_at
});

function updateMe(cust, patch) {
  const c = { ...cust };
  if (patch.name !== undefined) { const v = U.strip(patch.name); if (v.length < 2) return { error: "Valid name required" }; c.name = v; }
  if (patch.phone !== undefined) { const v = U.strip(patch.phone); if (!U.isPhone(v)) return { error: "Valid phone required" }; c.phone = v; }
  if (patch.aiConsent !== undefined) {
    if (!["human", "ai"].includes(patch.aiConsent)) return { error: "aiConsent must be 'human' or 'ai'" };
    if (patch.aiConsent !== cust.ai_consent) {
      c.ai_consent = patch.aiConsent;
      c.ai_consent_version = S("policy_version");
      c.ai_consent_at = new Date().toISOString();
      U.audit(CUST_ACTOR(cust), "customer.consent." + (patch.aiConsent === "ai" ? "granted" : "withdrawn"),
        "customer", cust.customer_id, "ai_consent", cust.ai_consent, patch.aiConsent);
    }
  }
  db.prepare("UPDATE customers SET name=?, phone=?, ai_consent=?, ai_consent_version=?, ai_consent_at=? WHERE id=?")
    .run(c.name, c.phone, c.ai_consent, c.ai_consent_version, c.ai_consent_at, cust.id);
  return { ok: true, me: publicMe(c) };
}

/* permanent deletion: personal data is removed; business/financial records
   (requests, rentals, payments) are retained for legal/accounting purposes
   but UNLINKED from the account. Documented in docs/CUSTOMER-ACCOUNTS.md. */
function deleteMe(cust, password) {
  if (!verifyPassword(String(password || ""), cust.salt, cust.pass_hash))
    return { error: "Password confirmation failed" };
  db.prepare("UPDATE requests SET customer_id=NULL WHERE customer_id=?").run(cust.customer_id);
  db.prepare("DELETE FROM customer_sessions WHERE customer_id=?").run(cust.id);
  db.prepare("DELETE FROM customer_tokens WHERE customer_id=?").run(cust.id);
  db.prepare("DELETE FROM customers WHERE id=?").run(cust.id);
  U.audit({ email: "[deleted]", role: "customer" }, "customer.delete", "customer", cust.customer_id,
    "retention", null, "account + sessions + tokens deleted; business records unlinked and retained per policy");
  return { ok: true };
}

/* trips: ONLY rows linked to the authenticated customer_id */
function trips(cust) {
  const requests = db.prepare(`SELECT request_id, status, vehicle_requested, start_date, end_date, option,
      delivery_location, quote_amount, quote_expires, payment_status, ts
    FROM requests WHERE customer_id=? ORDER BY ts DESC LIMIT 100`).all(cust.customer_id);
  const rentals = db.prepare(`SELECT r.rental_id, r.vehicle, r.pickup_date, r.return_date, r.pickup_status, r.return_status
    FROM rentals r JOIN requests q ON q.request_id = r.request_id
    WHERE q.customer_id=? ORDER BY r.created_at DESC LIMIT 100`).all(cust.customer_id);
  return { requests, rentals };
}

/* verification + reset flows (enumeration-safe) */
async function requestVerify(cust) {
  db.prepare("UPDATE customer_tokens SET used=1 WHERE customer_id=? AND kind='verify'").run(cust.id);
  const delivery = await sendAccountEmail("verify", cust, issueToken("verify", cust.id)).catch(() => "recorded");
  return { ok: true, delivery };
}
function completeVerify(token) {
  const rowId = consumeToken("verify", token);
  if (!rowId) return { error: "That verification link is invalid, already used, or expired. Request a new one from your account page." };
  db.prepare("UPDATE customers SET email_verified=1 WHERE id=?").run(rowId);
  const c = db.prepare("SELECT * FROM customers WHERE id=?").get(rowId);
  U.audit(CUST_ACTOR(c), "customer.verified", "customer", c.customer_id);
  return { ok: true };
}
async function requestReset(email) {
  const c = db.prepare("SELECT * FROM customers WHERE email=?").get(U.strip(email).toLowerCase());
  if (c) {
    db.prepare("UPDATE customer_tokens SET used=1 WHERE customer_id=? AND kind='reset'").run(c.id);
    await sendAccountEmail("reset", c, issueToken("reset", c.id)).catch(() => {});
  }
  /* identical response whether or not the account exists */
  return { ok: true, message: "If that account exists, instructions have been sent." };
}
function completeReset(token, password) {
  if (String(password || "").length < PASSWORD_MIN) return { error: `Password must be at least ${PASSWORD_MIN} characters` };
  const rowId = consumeToken("reset", token);
  if (!rowId) return { error: "That reset link is invalid, already used, or expired. Request a new one." };
  const { salt, hash } = hashPassword(password);
  db.prepare("UPDATE customers SET pass_hash=?, salt=? WHERE id=?").run(hash, salt, rowId);
  db.prepare("DELETE FROM customer_sessions WHERE customer_id=?").run(rowId); // revoke everywhere
  const c = db.prepare("SELECT * FROM customers WHERE id=?").get(rowId);
  U.audit(CUST_ACTOR(c), "customer.reset.completed", "customer", c.customer_id, "sessions", null, "all revoked");
  return { ok: true };
}

module.exports = {
  fromReq, csrfOk, setCustomerCookies, createCustomerSession,
  register, login, logout, logoutAll, publicMe, updateMe, deleteMe, trips,
  requestVerify, completeVerify, requestReset, completeReset,
  dbRateLimit, limited
};
