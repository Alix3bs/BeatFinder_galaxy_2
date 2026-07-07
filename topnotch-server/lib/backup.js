/* Encrypted database backups: daily schedule, 30-day retention,
   pre-migration/import backups, manual trigger, tested restore.
   Customer documents (uploads/) are intentionally EXCLUDED from
   these archives — back them up separately to private storage. */
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { db, DATA_DIR } = require("./db");

const BACKUP_DIR = process.env.TN_BACKUP_DIR || path.join(DATA_DIR, "..", "backups");
fs.mkdirSync(BACKUP_DIR, { recursive: true });
const RETENTION = Number(process.env.TN_BACKUP_RETENTION || 30);

function key() {
  const k = process.env.BACKUP_ENCRYPTION_KEY;
  if (!k) return null;
  return crypto.createHash("sha256").update(k).digest();
}

function encryptFile(src, dst) {
  const k = key();
  const data = fs.readFileSync(src);
  if (!k) { fs.writeFileSync(dst.replace(/\.enc$/, ""), data); return { file: dst.replace(/\.enc$/, ""), encrypted: 0, size: data.length }; }
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", k, iv);
  const out = Buffer.concat([iv, cipher.update(data), cipher.final(), cipher.getAuthTag()]);
  fs.writeFileSync(dst, out);
  return { file: dst, encrypted: 1, size: out.length };
}

function decryptFile(src, dst) {
  const k = key();
  const raw = fs.readFileSync(src);
  if (!src.endsWith(".enc")) { fs.writeFileSync(dst, raw); return; }
  if (!k) throw new Error("BACKUP_ENCRYPTION_KEY required to restore an encrypted backup");
  const iv = raw.subarray(0, 12), tag = raw.subarray(raw.length - 16), body = raw.subarray(12, raw.length - 16);
  const dec = crypto.createDecipheriv("aes-256-gcm", k, iv);
  dec.setAuthTag(tag);
  fs.writeFileSync(dst, Buffer.concat([dec.update(body), dec.final()]));
}

function backupNow(reason) {
  const stamp = new Date().toISOString().replace(/[:T]/g, "-").slice(0, 16);
  const tmp = path.join(BACKUP_DIR, `.tmp-${stamp}.db`);
  const dst = path.join(BACKUP_DIR, `topnotch-${stamp}.db.enc`);
  try {
    db.exec(`VACUUM INTO '${tmp.replace(/'/g, "''")}'`);   // consistent snapshot
    const info = encryptFile(tmp, dst);
    fs.unlinkSync(tmp);
    db.prepare("INSERT INTO backups (file, size, encrypted, reason, status) VALUES (?,?,?,?, 'ok')")
      .run(path.basename(info.file), info.size, info.encrypted, reason || "scheduled");
    prune();
    return { ok: true, file: path.basename(info.file), encrypted: !!info.encrypted, size: info.size };
  } catch (e) {
    try { fs.existsSync(tmp) && fs.unlinkSync(tmp); } catch (_) {}
    db.prepare("INSERT INTO backups (file, reason, status, error) VALUES (?,?, 'failed', ?)")
      .run(path.basename(dst), reason || "scheduled", String(e.message).slice(0, 300));
    return { ok: false, error: e.message };
  }
}

function prune() {
  const files = fs.readdirSync(BACKUP_DIR).filter(f => f.startsWith("topnotch-")).sort();
  while (files.length > RETENTION) {
    const f = files.shift();
    try { fs.unlinkSync(path.join(BACKUP_DIR, f)); } catch (_) {}
  }
}

function lastBackup() {
  return db.prepare("SELECT * FROM backups WHERE status='ok' ORDER BY id DESC LIMIT 1").get() || null;
}

/* daily scheduler: run at boot if none in the last 24h, then every 24h */
function schedule() {
  const last = lastBackup();
  if (!last || Date.now() - Date.parse(last.ts + "Z") > 24 * 36e5) backupNow("daily");
  setInterval(() => backupNow("daily"), 24 * 36e5).unref();
}

/* restore test used by the suite and scripts/restore.mjs */
function restoreTo(backupFile, targetPath) {
  decryptFile(path.join(BACKUP_DIR, backupFile), targetPath);
  const { DatabaseSync } = require("node:sqlite");
  const check = new DatabaseSync(targetPath);
  const n = check.prepare("SELECT count(*) n FROM users").get().n;
  check.close();
  return { ok: true, users: n };
}

module.exports = { backupNow, lastBackup, schedule, restoreTo, BACKUP_DIR };
