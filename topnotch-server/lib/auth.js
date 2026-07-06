/* Authentication: scrypt-hashed passwords, opaque session tokens
   (stored hashed), sliding inactivity timeout, absolute expiry,
   password reset tokens, and the role→permission matrix. */
const crypto = require("node:crypto");
const { db } = require("./db");

const INACTIVITY_MIN = Number(process.env.TN_SESSION_IDLE_MINUTES || 30);
const ABSOLUTE_HOURS = Number(process.env.TN_SESSION_MAX_HOURS || 8);

const sha256 = s => crypto.createHash("sha256").update(s).digest("hex");

function hashPassword(password, salt) {
  salt = salt || crypto.randomBytes(16).toString("hex");
  const hash = crypto.scryptSync(password, salt, 64).toString("hex");
  return { salt, hash };
}
function verifyPassword(password, salt, expected) {
  const got = crypto.scryptSync(password, salt, 64);
  const want = Buffer.from(expected, "hex");
  return got.length === want.length && crypto.timingSafeEqual(got, want);
}

function createSession(userId) {
  const token = crypto.randomBytes(32).toString("hex");
  const expires = new Date(Date.now() + ABSOLUTE_HOURS * 36e5).toISOString();
  db.prepare("INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?,?,?)")
    .run(sha256(token), userId, expires);
  return token;
}
function destroySession(token) {
  db.prepare("DELETE FROM sessions WHERE token_hash = ?").run(sha256(token));
}
function sessionUser(token) {
  if (!token) return null;
  const s = db.prepare("SELECT * FROM sessions WHERE token_hash = ?").get(sha256(token));
  if (!s) return null;
  const now = Date.now();
  if (now > Date.parse(s.expires_at + "Z") ||
      now - Date.parse(s.last_seen + "Z") > INACTIVITY_MIN * 6e4) {
    db.prepare("DELETE FROM sessions WHERE token_hash = ?").run(s.token_hash);
    return null;
  }
  db.prepare("UPDATE sessions SET last_seen = datetime('now') WHERE token_hash = ?").run(s.token_hash);
  const u = db.prepare("SELECT id, email, name, role, partner_id, must_reset FROM users WHERE id = ? AND active = 1").get(s.user_id);
  return u || null;
}

function createResetToken(userId) {
  const token = crypto.randomBytes(24).toString("hex");
  db.prepare("INSERT INTO reset_tokens (token_hash, user_id, expires_at) VALUES (?,?,datetime('now','+1 hour'))")
    .run(sha256(token), userId);
  return token;
}
function consumeResetToken(token) {
  const r = db.prepare("SELECT * FROM reset_tokens WHERE token_hash = ? AND used = 0 AND expires_at > datetime('now')")
    .get(sha256(token));
  if (!r) return null;
  db.prepare("UPDATE reset_tokens SET used = 1 WHERE token_hash = ?").run(r.token_hash);
  return r.user_id;
}

/* ---------------- role → permission matrix ----------------
   Checked on the SERVER for every sensitive route. The UI only
   mirrors this; hiding a button is never the security boundary. */
const PERMS = {
  admin:        ["*"],
  sales:        ["requests.read", "requests.write", "quotes.write", "customers.read",
                 "vehicles.read.public", "notifications.read", "reviews.read"],
  ops:          ["rentals.read", "rentals.write", "inspections.write", "vehicles.read.public",
                 "vehicles.status.write", "requests.read", "notifications.read"],
  partnerships: ["partners.read", "partners.write", "vehicles.read.full", "vehicles.write",
                 "import.write", "inquiries.read", "notifications.read"],
  cx:           ["requests.read", "reviews.read", "reviews.write", "premium.write",
                 "notifications.read", "customers.read"],
  partner:      ["portal.self"]   // scoped by partner_id on every query
};

function can(user, perm) {
  if (!user) return false;
  const perms = PERMS[user.role] || [];
  return perms.includes("*") || perms.includes(perm);
}

module.exports = {
  hashPassword, verifyPassword,
  createSession, destroySession, sessionUser,
  createResetToken, consumeResetToken,
  can, PERMS, INACTIVITY_MIN
};
