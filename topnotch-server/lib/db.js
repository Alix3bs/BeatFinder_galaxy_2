/* SQLite database — live source of truth. Excel is a synced report, never the DB. */
const { DatabaseSync } = require("node:sqlite");
const fs = require("node:fs");
const path = require("node:path");

const DATA_DIR = process.env.TN_DATA_DIR || path.join(__dirname, "..", "data");
fs.mkdirSync(DATA_DIR, { recursive: true });
const db = new DatabaseSync(path.join(DATA_DIR, process.env.TN_DB_FILE || "topnotch.db"));

db.exec(`
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin','sales','ops','partnerships','cx','partner')),
  partner_id TEXT,
  pass_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  must_reset INTEGER DEFAULT 0,
  active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  last_seen TEXT DEFAULT (datetime('now')),
  expires_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS reset_tokens (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  expires_at TEXT NOT NULL,
  used INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS partners (
  partner_id TEXT PRIMARY KEY,
  company TEXT NOT NULL,
  contact TEXT, phone TEXT, email TEXT, market TEXT,
  payout_method TEXT, status TEXT DEFAULT 'Approved', notes TEXT
);

CREATE TABLE IF NOT EXISTS vehicles (
  vehicle_id TEXT PRIMARY KEY,
  fleet_id TEXT, partner_id TEXT NOT NULL,
  market TEXT, year INTEGER, make TEXT, model TEXT, trim TEXT, color TEXT,
  vin TEXT, photos TEXT DEFAULT '[]',
  daily_rate REAL, weekly_rate REAL, monthly_rate REAL,
  provider_rate REAL, customer_price REAL, provider_payout REAL, profit REAL,
  deposit REAL, min_days INTEGER DEFAULT 1,
  mileage_included INTEGER DEFAULT 100, mileage_fee REAL,
  delivery_areas TEXT, delivery_fee REAL,
  min_age INTEGER DEFAULT 25, license TEXT, insurance TEXT, payments TEXT,
  status TEXT DEFAULT 'available' CHECK (status IN ('available','booked','maintenance','unavailable')),
  booked_dates TEXT DEFAULT '[]',
  last_verified TEXT, provider_contact TEXT, notes TEXT
);

CREATE TABLE IF NOT EXISTS requests (
  request_id TEXT PRIMARY KEY,
  ts TEXT DEFAULT (datetime('now')),
  status TEXT DEFAULT 'Request submitted',
  customer_name TEXT, phone TEXT, email TEXT,
  vehicle_requested TEXT, backup_vehicle TEXT,
  start_date TEXT, end_date TEXT,
  budget TEXT, driver_age TEXT, license_status TEXT, insurance_status TEXT,
  option TEXT, delivery_location TEXT, return_location TEXT,
  deposit_readiness TEXT, occasion TEXT, chauffeur TEXT, fbo TEXT,
  addons TEXT, special_requests TEXT, quoted_day_rate TEXT,
  assigned_vehicle_id TEXT, final_price REAL, internal_cost REAL, profit REAL,
  quote_amount REAL, quote_expires TEXT, quote_accepted_at TEXT,
  payment_status TEXT DEFAULT 'none',
  duplicate_of TEXT, decline_note TEXT,
  ip TEXT
);

CREATE TABLE IF NOT EXISTS rentals (
  rental_id TEXT PRIMARY KEY,
  request_id TEXT, vehicle_id TEXT, vehicle TEXT,
  customer TEXT, customer_phone TEXT,
  provider TEXT, partner_id TEXT,
  pickup_date TEXT, return_date TEXT, delivery_address TEXT,
  deposit REAL, amount_paid REAL DEFAULT 0, balance_due REAL DEFAULT 0,
  provider_payout REAL DEFAULT 0, profit REAL DEFAULT 0,
  pickup_status TEXT DEFAULT 'Pending', return_status TEXT DEFAULT 'Pending',
  deposit_refunded TEXT DEFAULT 'No', payout_paid TEXT DEFAULT 'No',
  payout_questioned TEXT DEFAULT 'No',
  review_requested TEXT DEFAULT 'No', review TEXT, notes TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT DEFAULT (datetime('now')),
  request_id TEXT, rental_id TEXT,
  kind TEXT CHECK (kind IN ('payment','deposit','refund','payout')),
  amount REAL, method TEXT, status TEXT DEFAULT 'recorded',
  recorded_by TEXT
);

CREATE TABLE IF NOT EXISTS partner_inquiries (
  inquiry_id TEXT PRIMARY KEY,
  ts TEXT DEFAULT (datetime('now')),
  company TEXT, contact TEXT, phone TEXT, email TEXT,
  market TEXT, fleet_size TEXT, notes TEXT, status TEXT DEFAULT 'New inquiry'
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT DEFAULT (datetime('now')),
  partner_id TEXT NOT NULL,
  from_email TEXT, from_role TEXT, body TEXT, read INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS reviews (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT DEFAULT (datetime('now')),
  rental_id TEXT, rating INTEGER, text TEXT, recorded_by TEXT
);

CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT DEFAULT (datetime('now')),
  audience_role TEXT, partner_id TEXT,
  type TEXT, title TEXT, body TEXT,
  delivery TEXT DEFAULT 'recorded', read INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sync_outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT DEFAULT (datetime('now')),
  table_name TEXT, row_json TEXT,
  status TEXT DEFAULT 'pending', attempts INTEGER DEFAULT 0,
  next_retry TEXT, last_error TEXT, sent_at TEXT
);

CREATE TABLE IF NOT EXISTS audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT DEFAULT (datetime('now')),
  user_email TEXT, role TEXT,
  action TEXT, entity TEXT, entity_id TEXT,
  field TEXT, old_value TEXT, new_value TEXT, related_id TEXT
);

CREATE TABLE IF NOT EXISTS uploads (
  id TEXT PRIMARY KEY,
  ts TEXT DEFAULT (datetime('now')),
  owner_email TEXT, partner_id TEXT, rental_id TEXT, vehicle_id TEXT,
  kind TEXT, filename TEXT, mime TEXT, size INTEGER, path TEXT
);
`);

db.exec(`
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TEXT DEFAULT (datetime('now')),
  updated_by TEXT
);

CREATE TABLE IF NOT EXISTS consents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT DEFAULT (datetime('now')),
  request_id TEXT,
  ip TEXT,
  policy_version TEXT,
  consent_text TEXT,
  items TEXT
);

CREATE TABLE IF NOT EXISTS stripe_events (
  event_id TEXT PRIMARY KEY,
  ts TEXT DEFAULT (datetime('now')),
  type TEXT,
  request_id TEXT,
  status TEXT
);

CREATE TABLE IF NOT EXISTS backups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT DEFAULT (datetime('now')),
  file TEXT, size INTEGER, encrypted INTEGER,
  reason TEXT, status TEXT, error TEXT
);
`);

/* additive migrations — safe to run on existing databases */
function addColumn(table, col, def) {
  const cols = db.prepare(`PRAGMA table_info(${table})`).all().map(c => c.name);
  if (!cols.includes(col)) db.exec(`ALTER TABLE ${table} ADD COLUMN ${col} ${def}`);
}
addColumn("partners", "onboarding_status", "TEXT DEFAULT 'Lead'");
addColumn("partners", "deal_model", "TEXT DEFAULT 'broker-markup'");
addColumn("partners", "deal_terms", "TEXT DEFAULT ''");
addColumn("vehicles", "rate_label", "TEXT DEFAULT 'awaiting-confirmation'");
addColumn("vehicles", "photos_approved", "INTEGER DEFAULT 0");
addColumn("vehicles", "price_approved", "INTEGER DEFAULT 0");
addColumn("vehicles", "requirements_complete", "INTEGER DEFAULT 0");
addColumn("vehicles", "deal_model", "TEXT DEFAULT ''");
addColumn("payments", "stripe_customer_id", "TEXT");
addColumn("payments", "stripe_payment_intent", "TEXT");
addColumn("payments", "currency", "TEXT DEFAULT 'usd'");
addColumn("payments", "category", "TEXT DEFAULT ''");
addColumn("payments", "authorization_note", "TEXT");
addColumn("rentals", "pre_checklist", "TEXT DEFAULT '{}'");
addColumn("rentals", "post_checklist", "TEXT DEFAULT '{}'");
addColumn("sync_outbox", "row_key", "TEXT");
addColumn("uploads", "expires_at", "TEXT");

module.exports = { db, DATA_DIR };
