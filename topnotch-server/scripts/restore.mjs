#!/usr/bin/env node
/* Restore an encrypted backup. Run with the server STOPPED:
     BACKUP_ENCRYPTION_KEY=... node scripts/restore.mjs topnotch-2026-07-06-04-00.db.enc
   Restores into data/topnotch.db (previous db saved as .pre-restore). */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
process.env.TN_DATA_DIR = process.env.TN_DATA_DIR || path.join(ROOT, "data");
const { restoreTo, BACKUP_DIR } = require(path.join(ROOT, "lib", "backup.js"));

const file = process.argv[2];
if (!file) {
  console.log("Available backups in", BACKUP_DIR + ":");
  for (const f of fs.readdirSync(BACKUP_DIR).filter(f => f.startsWith("topnotch-"))) console.log("  " + f);
  console.log("\nUsage: node scripts/restore.mjs <backup-file>");
  process.exit(1);
}
const target = path.join(process.env.TN_DATA_DIR, "topnotch.db");
if (fs.existsSync(target)) fs.copyFileSync(target, target + ".pre-restore");
const out = restoreTo(file, target);
console.log(`Restored ${file} → ${target} (users table: ${out.users} rows). Previous db kept at ${target}.pre-restore`);
console.log("Start the server again to resume.");
