/* Validation, sanitization, rate limiting, logging, audit, sync outbox, notifications. */
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { db, DATA_DIR } = require("./db");

/* ---------- logging ---------- */
const LOG_DIR = path.join(DATA_DIR, "..", "logs");
fs.mkdirSync(LOG_DIR, { recursive: true });
const accessLog = fs.createWriteStream(path.join(LOG_DIR, "access.log"), { flags: "a" });
function logReq(req, res, ms, extra) {
  const line = `${new Date().toISOString()} ${req.socket.remoteAddress} ${req.method} ${req.url} ${res.statusCode} ${ms}ms${extra ? " " + extra : ""}\n`;
  accessLog.write(line);
}

/* ---------- validation / sanitization ---------- */
const strip = v => String(v ?? "").replace(/[<>]/g, "").replace(/\s+/g, " ").trim().slice(0, 500);
const stripLong = v => String(v ?? "").replace(/[<>]/g, "").trim().slice(0, 2000);
const isEmail = v => /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,24}$/.test(v);
const isPhone = v => String(v).replace(/\D/g, "").length >= 7;
const isDate = v => /^\d{4}-\d{2}-\d{2}$/.test(v) && !isNaN(Date.parse(v));
const isMoney = v => v === "" || v == null || (!isNaN(Number(v)) && Number(v) >= 0 && Number(v) < 1e7);

/* ---------- rate limiting (per-IP token buckets) ---------- */
const buckets = new Map();
function rateLimit(ip, key, max, windowMs) {
  const k = `${ip}:${key}`;
  const now = Date.now();
  let b = buckets.get(k);
  if (!b || now - b.start > windowMs) { b = { start: now, n: 0 }; buckets.set(k, b); }
  b.n++;
  if (buckets.size > 5000) buckets.clear();
  return b.n <= max;
}

/* ---------- ids ---------- */
const rid = prefix =>
  prefix + "-" + new Date().toISOString().slice(2, 10).replace(/-/g, "") + "-" +
  crypto.randomBytes(3).toString("hex").toUpperCase();

/* ---------- audit ---------- */
function audit(user, action, entity, entityId, field, oldValue, newValue, relatedId) {
  db.prepare(`INSERT INTO audit (user_email, role, action, entity, entity_id, field, old_value, new_value, related_id)
              VALUES (?,?,?,?,?,?,?,?,?)`)
    .run(user?.email || "system", user?.role || "system", action, entity, String(entityId ?? ""),
         field ?? null, oldValue == null ? null : String(oldValue).slice(0, 400),
         newValue == null ? null : String(newValue).slice(0, 400), relatedId ?? null);
}

/* ---------- Excel sync outbox (server-side only; retries with backoff) ---------- */
function queueSync(table, row) {
  db.prepare("INSERT INTO sync_outbox (table_name, row_json, next_retry) VALUES (?,?,datetime('now'))")
    .run(table, JSON.stringify(row));
}
async function drainOutbox() {
  const url = process.env.EXCEL_WEBHOOK_URL;
  const rows = db.prepare(
    "SELECT * FROM sync_outbox WHERE status IN ('pending','failed') AND next_retry <= datetime('now') ORDER BY id LIMIT 20").all();
  for (const r of rows) {
    if (!url) {
      db.prepare("UPDATE sync_outbox SET status='failed', attempts=attempts+1, last_error='EXCEL_WEBHOOK_URL not configured', next_retry=datetime('now','+10 minutes') WHERE id=?").run(r.id);
      continue;
    }
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-TN-Secret": process.env.EXCEL_WEBHOOK_SECRET || "" },
        body: JSON.stringify({ table: r.table_name, row: JSON.parse(r.row_json) }),
        signal: AbortSignal.timeout(10000)
      });
      if (!res.ok) throw new Error("HTTP " + res.status);
      db.prepare("UPDATE sync_outbox SET status='sent', sent_at=datetime('now'), attempts=attempts+1, last_error=NULL WHERE id=?").run(r.id);
    } catch (e) {
      const attempts = r.attempts + 1;
      const backoffMin = Math.min(60, 2 ** attempts); // 2,4,8,…60 min
      db.prepare("UPDATE sync_outbox SET status='failed', attempts=?, last_error=?, next_retry=datetime('now', ?) WHERE id=?")
        .run(attempts, String(e.message).slice(0, 300), `+${backoffMin} minutes`, r.id);
    }
  }
}

/* ---------- notifications (email-first; falls back to recorded) ---------- */
async function notify(audienceRole, partnerId, type, title, body) {
  let delivery = "recorded";
  const hook = process.env.NOTIFY_EMAIL_WEBHOOK_URL; // e.g. Power Automate "send an email" flow / Resend proxy
  if (hook) {
    try {
      const res = await fetch(hook, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-TN-Secret": process.env.NOTIFY_WEBHOOK_SECRET || "" },
        body: JSON.stringify({ audienceRole, partnerId, type, title, body }),
        signal: AbortSignal.timeout(8000)
      });
      if (res.ok) delivery = "emailed";
    } catch (e) { /* stays recorded */ }
  }
  db.prepare("INSERT INTO notifications (audience_role, partner_id, type, title, body, delivery) VALUES (?,?,?,?,?,?)")
    .run(audienceRole || null, partnerId || null, type, title, stripLong(body), delivery);
}

module.exports = {
  logReq, strip, stripLong, isEmail, isPhone, isDate, isMoney,
  rateLimit, rid, audit, queueSync, drainOutbox, notify
};
