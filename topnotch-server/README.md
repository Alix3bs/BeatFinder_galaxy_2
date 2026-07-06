# TopNotchRentalz — Phase 3 Backend & Operations Documentation

## 1 · Backend architecture

- **Runtime:** Node.js 22+, **zero npm dependencies** (stdlib `http`, `node:sqlite`, `node:crypto`).
  One process serves the static customer site *and* the `/api` routes, so it deploys anywhere
  Node runs (VPS, Render, Railway, Fly.io) or splits cleanly into serverless functions later.
- **Layout:**
  - `server.js` — router, all API endpoints, static file serving, status machine
  - `lib/db.js` — SQLite schema (source of truth)
  - `lib/auth.js` — scrypt password hashing, hashed session tokens, role→permission matrix
  - `lib/util.js` — validation/sanitization, rate limiting, request logging, audit writer,
    Excel sync outbox with retry, email-first notifications
  - `seed.js` — first-run accounts, partners, inventory
  - `tests/e2e.mjs` — the 18-scenario launch suite (+2 browser checks)
- **Start:** `cd topnotch-server && cp .env.example .env && node server.js`
  (first run prints one-time temp passwords for any account without an env password;
  those accounts must change password at first login).

## 2 · Database structure (SQLite — `data/topnotch.db`)

| Table | Purpose |
|---|---|
| `users` | team + partner accounts (email, role, partner_id, scrypt hash, must_reset) |
| `sessions` | hashed session tokens, absolute + inactivity expiry |
| `reset_tokens` | one-hour single-use password reset tokens |
| `partners` | partner companies, payout method, status |
| `vehicles` | full vehicle schema incl. provider_rate, payout, profit, booked_dates, VIN |
| `requests` | customer requests + workflow status, quote, payment status, duplicate_of |
| `rentals` | active rentals: payments, deposit, payout, pickup/return, review flags |
| `payments` | payment / deposit / refund / payout entries with recorder |
| `partner_inquiries` | website partner form |
| `messages` | partner ↔ ops thread |
| `reviews` | customer reviews |
| `notifications` | all generated notifications (audience role or partner) + delivery state |
| `sync_outbox` | Excel sync queue: status, attempts, next_retry, last_error |
| `audit` | who / when / action / field / old → new / related booking |
| `uploads` | validated image uploads (inspection & vehicle photos) |

To move to Postgres later, the schema is plain SQL — swap `lib/db.js` for a `pg` client.

## 3 · Environment variables (no secret values here — see `.env.example`)

`PORT`, `TN_BASE_URL`, `TN_MARKET`, `TN_SECURE_COOKIES`, `TN_SESSION_IDLE_MINUTES`,
`TN_SESSION_MAX_HOURS`, `TN_DATA_DIR`,
`TN_ADMIN_PASSWORD`, `TN_SALES_PASSWORD`, `TN_OPS_PASSWORD`, `TN_PARTNERSHIPS_PASSWORD`,
`TN_CX_PASSWORD`, `TN_PARTNER1..3_PASSWORD` (first-run only),
`EXCEL_WEBHOOK_URL`, `EXCEL_WEBHOOK_SECRET`,
`NOTIFY_EMAIL_WEBHOOK_URL`, `NOTIFY_WEBHOOK_SECRET`.

`.env` is gitignored. Nothing secret exists in any front-end file (verified by test 17/18).

## 4 · Authentication setup

- Passwords hashed with **scrypt** (per-user salt, timing-safe compare).
- Sessions: 32-byte random tokens stored **hashed** server-side; delivered as
  `HttpOnly; SameSite=Lax` cookies (`Secure` when `TN_SECURE_COOKIES=1`).
- **Inactivity logout** (default 30 min, server-enforced + client timer) and an
  absolute 8-hour session cap.
- **Password reset:** `/api/auth/reset/request` emails a one-hour single-use link
  (`/admin/#reset=TOKEN`); the token is never returned to the browser.
- Forced password change on first login for generated temp passwords.
- Login rate-limited (10 attempts / 15 min / IP); failures audited.

## 5 · Role-permission matrix (enforced server-side on every route)

| Capability | admin | sales | ops | partnerships | cx | partner |
|---|---|---|---|---|---|---|
| Requests: view / work leads & quotes | ✅ | ✅ | view | — | view | own only |
| Assign provider / approve price / quote / verify payment | ✅ | ✅ | — | — | — | — |
| Rentals: payments, pickups, returns, inspections | ✅ | — | ✅ | — | — | own payouts |
| Vehicles: full rates (provider/broker, payout, profit) | ✅ | — | — | ✅ | — | own rates only |
| Vehicles: status / availability | ✅ | — | ✅ | ✅ | — | own units |
| Partners + import (preview) | ✅ | — | — | ✅ | — | — |
| Import **commit** | ✅ only | — | — | — | — | — |
| Reviews / premium experience | ✅ | view | — | — | ✅ | — |
| Audit log, Excel sync, team accounts | ✅ only | — | — | — | — | — |
| Portal (own fleet, bookings, payouts, messages) | — | — | — | — | — | ✅ |

Partners never receive: other providers, other rates, customer_price, profit,
customers on other bookings, or internal notes (test 16). Customer phone is
withheld from partners until the booking is confirmed.

## 6 · Excel connection instructions

1. In Power Automate create **"When an HTTP request is received"**.
2. Add a **Switch** on `@{triggerBody()?['table']}` with cases:
   `PartnerInventory`, `CustomerRequests`, `ActiveRentals`, `Partners`,
   `PartnerInquiries`, `Payments`, `Reviews`.
3. Each case: **"Add a row into a table"** on `TopNotchRentalz.xlsx`
   (OneDrive/SharePoint), mapping fields from `triggerBody()?['row']`.
4. Paste the flow URL into `EXCEL_WEBHOOK_URL` in `.env`; optionally check the
   `X-TN-Secret` header equals `EXCEL_WEBHOOK_SECRET` inside the flow.
5. Done — every change queues in `sync_outbox`, sends with exponential backoff
   retries (2→4→8… max 60 min), and failures appear in **Admin → Excel Sync**
   with one-click retry. The database remains the source of truth; Excel is the
   reporting workbook. (Google Apps Script works identically.)

Notifications: point `NOTIFY_EMAIL_WEBHOOK_URL` at a flow that emails the JSON
(`audienceRole`, `type`, `title`, `body`) to the right team inbox. Undelivered
notifications are still recorded in-app. SMS/WhatsApp can be added later by
swapping the flow — no code change.

## 7 · Deployment instructions

1. Server with Node 22+ → copy `topnotch-server/` + `topnotch-website/`.
2. `cp .env.example .env`, set passwords + webhook URLs, `TN_SECURE_COOKIES=1`.
3. Run behind HTTPS (Caddy/nginx or platform TLS): proxy 443 → `PORT`.
4. `node server.js` under a supervisor (`systemd`, `pm2`, or platform runtime).
5. First boot prints temp passwords for unset accounts → sign in → forced change.
6. Verify **Admin → Excel Sync** shows "configured" and a test row lands in the workbook.

## 8 · Backup and recovery

- **What to back up:** the `TN_DATA_DIR` folder — `topnotch.db` (+ `-wal`/`-shm`) and `uploads/`.
- **How:** nightly `sqlite3 data/topnotch.db ".backup backups/topnotch-$(date +%F).db"`
  (or simply snapshot the folder while using WAL mode) + copy off-server (S3/Drive).
- **Recovery:** stop the server, restore the folder, restart. Excel is a secondary
  copy of approved fields; the outbox will re-sync anything queued.
- Logs rotate in `logs/access.log`; audit history lives in the DB and is included in backups.

## 9 · Security test results (from `tests/e2e.mjs`, scenarios 15–18)

- Anonymous requests to every staff/admin API → **401**; wrong-role → **403**; all denials audited.
- Field-level filtering verified: ops receives vehicles **without** provider_rate/payout/profit.
- Partner cross-tenant access → **404/403**; partner payloads contain no customer_price/profit.
- Static file scan: no passcodes, no provider rates/contacts, no internal field
  names in customer-facing files; path traversal to `.env`/DB blocked.
- Public track endpoint requires phone verification and never echoes email/phone/IP.
- Uploads: magic-byte validated JPEG/PNG/WebP, 5 MB cap, served only through an
  authenticated, partner-scoped endpoint.

## 10 · End-to-end test results

See **`TEST-RESULTS.md`** — regenerated on every run:
`node tests/e2e.mjs --browser` → **20/20 PASS** (18 required scenarios + 2 browser checks),
fresh database per run, including sync fail→retry→success and overlap blocking.

## 11 · Still simulated rather than live

| Area | Current state | Path to live |
|---|---|---|
| **Payments** | "Payment verified" is recorded manually by staff after collecting via your card link/Zelle/wire. **No card data is ever stored.** | Add Stripe Payment Links/Checkout + webhook → auto-verify. |
| **Email delivery** | Sent via `NOTIFY_EMAIL_WEBHOOK_URL` when configured; otherwise recorded in-app with "recorded" status. | Point the env var at a Power Automate email flow or Resend proxy. |
| **Excel workbook** | Outbox + retries fully working (proven against a mock endpoint). | Paste the real flow URL into `EXCEL_WEBHOOK_URL`. |
| **SMS/WhatsApp notifications** | Email-first as specified; links open WhatsApp manually. | Twilio/WhatsApp Business API behind the same notify flow. |
| **XLSX import** | CSV fully implemented (preview → admin approval → commit). Excel files must be saved as CSV first. | Add an xlsx parser dependency if raw .xlsx upload is wanted. |
| **Seed partners/fleet** | Prestige/Velocity/Crown are demo rows (`.example` emails). | Replace via admin UI or importer before launch. |
| **Reset-link email** | Generated + logged server-side; delivered only when the notify webhook is set. | Same email flow as above. |

The system is **not** claimed production-ready until you have: set real
passwords via env, enabled HTTPS + `TN_SECURE_COOKIES=1`, configured the two
webhook URLs, and replaced seed partner data. Everything else — private rates,
customer data, authentication, uploads, webhooks, permissions — is already
protected by the backend (verified by the suite above).
