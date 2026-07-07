# TopNotchRentalz — Phase 4 Launch Report

Date: 2026-07-07 · Prepared from the `claude/exotic-rental-site-design-50vuqr` branch

> ## ⚠️ Phase 4 status: **NOT COMPLETE — deployment pending operator accounts**
> Everything below marked ✅ was built and verified by automated tests in this
> repository. Items marked 🔶 require accounts/credentials only the
> TopNotchRentalz team can create (hosting, Stripe, email domain, the real LUXX
> workbook). Per the phase requirement, Phase 4 must not be marked complete
> until the system is deployed and one pilot booking has run on the deployed
> environment — the exact runbook for that is at the bottom.

## 1 · Production URL / 2 · Staging URL
🔶 **Pending deploy.** Everything is packaged for a 30-minute setup:
`deploy/DEPLOY.md` (step-by-step for Render / Railway / Fly / VPS),
`deploy/render.yaml` (creates both environments with persistent disks),
`deploy/topnotch.service` + `deploy/Caddyfile` (VPS: auto-restart + HTTPS).
Suggested: `topnotchrentalz.com` (prod) and `staging.topnotchrentalz.com`.

## 3 · Hosting provider and persistence confirmation
🔶 Provider choice is yours (guide compares options); the guide includes the
mandatory persistence check — *deploy twice, confirm data written between
deploys survives* — and warns off serverless hosts whose disks are wiped.
SQLite, uploads and backups all live on the mounted persistent disk
(`TN_DATA_DIR`, `TN_BACKUP_DIR`).

## 4 · Database backup and restore test
✅ **Tested.** Daily AES-256-GCM-encrypted backups, 30-day retention,
automatic backup before every fleet import, manual button + status history in
Admin → Settings, restore CLI (`scripts/restore.mjs`). Automated test 7
(TEST-RESULTS-PHASE4.md) creates an encrypted backup, restores it to a scratch
path and reads it back (8 users verified). Customer documents are excluded
from backup archives by design.

## 5 · Real authentication test
✅ Re-verified this phase (Phase 3 suite re-run: **20/20**): scrypt hashes,
hashed HttpOnly session cookies, 30-min inactivity + 8h cap, forced first-login
change, reset flow, per-role 401/403 enforcement.

## 6 · Stripe test results
✅ Code-complete and security-tested: hosted Checkout (card data never touches
the server), 8 payment categories, security-deposit as manual-capture
authorization, payments blocked until quote acceptance, post-rental
damage/mileage/toll charges require admin + documented authorization note,
webhook **signature verified** and **duplicate deliveries ignored**, only
Stripe IDs/amount/currency/status/timestamps stored (Phase 4 tests 5–6).
🔶 A live checkout session needs your `sk_test_` keys — the pilot run
covers it (harness auto-detects keys; today it reports "pending config").

## 7 · Excel synchronization test
✅ Outbox → webhook with row-level dedupe key (`rowKey`) + `syncedAt` stamp on
every row (Excel upserts; stale Excel edits can't overwrite newer DB records —
DB is the source of truth), retry with backoff, last-success time + pending +
failed counts + retry button + admin-only error details, "not configured /
missing workbook" reported clearly in Admin → Excel Sync and System Health.
Verified against a live mock endpoint incl. fail→retry→success.
🔶 Point `EXCEL_WEBHOOK_URL` at the real Power Automate flow for the
TopNotchRentalz workbook (recipe in README §6); tables now also include
Quotes (in CustomerRequests), Payments, Deposits/Payouts (in payments rows),
Reviews, and AuditLog is exportable.

## 8 · Email-delivery test
✅ 13 branded black/orange templates (request received → review request)
implemented server-side and fired at the right workflow moments; internal
notifications route by team role; emails contain status + tracking link only —
never license/insurance/payment details. Reply-to `bookings@topnotchrentalz.com`.
🔶 Actual delivery needs `RESEND_API_KEY` (verify the domain) **or** a
Power Automate send-mail flow URL. Until then every email is recorded in-app
with delivery state "recorded" (visible in System Health).

## 9 · Document-security test
✅ **Tested** (Phase 4 test 8): private storage outside the web root, no
permanent URLs, signed 15-minute temporary links (HMAC, tamper-rejected),
type + size + magic-byte validation, access logging to the audit trail, admin
deletion control, automatic retention deletion (`doc_retention_days` setting),
partners see only their own files. Malware scanning: not available on a
zero-dependency stack — listed as a known limitation (mitigations: strict
image-only types + magic bytes + size cap).

## 10 · Role-access test / 11 · Partner-isolation test
✅ Re-verified: anonymous → 401 everywhere, wrong role → 403 + audited,
field-level filtering (ops never receives provider rates; economics endpoint
is admin/sales only), partners cannot see or edit other fleets, customer
contact hidden from partners until confirmation.

## 12 · Mobile booking test
✅ The browser test drives the full wizard (now 4 steps + 7 explicit,
un-pre-checked consent checkboxes) through the real API; mobile layout
unchanged from the approved design (sticky wizard nav, floating
WhatsApp/call buttons).

## 13 · Complete pilot-booking results
✅ **Staging rehearsal: 17/18 (1 pending config)** — see `PILOT-REPORT.md`.
Scenario A: team-member request → lowest-rate provider assigned → real portal
confirmation → quote → acceptance → payment → enforced 12-item pre-rental
checklist → inspection upload → enforced 11-item post-rental checklist →
payout → 37 audit entries → 9 notifications → Excel rows queued.
Scenario B: first provider declines → backup provider assigned + confirms →
**changed** quote ($2,598 vs $2,498) → customer accepts → completes.
🔶 The **production pilot** must be re-run on the deployed URL with Stripe
test keys + the real workbook: `node scripts/pilot.mjs --remote` (env-driven
credentials) — it prints the same checklist against the live system.

## 14 · Remaining simulated features
| Feature | Status |
|---|---|
| Hosting/URLs | pending your provider account (guide + configs ready) |
| Stripe live session | pending `sk_test_`/`sk_live_` keys (webhook + gating fully tested) |
| Email delivery | pending Resend key or Power Automate flow (templates fire now, recorded in-app) |
| LUXX Miami inventory | partner seeded as *Inventory pending*; awaiting their workbook → save as CSV → Admin → Import Fleet (`templates/luxx-import-template.csv`); every imported price defaults to **awaiting-confirmation** and stays unpublished until Partnerships confirms authorization, rates, deposit, mileage, insurance, delivery areas, photos, contact — then flips the partner to **Active** |
| SMS/WhatsApp automation | email-first as specified; add later behind the same notify flow |
| Malware scanning on uploads | not possible dependency-free; mitigated (types/magic/size) |
| XLSX direct upload | CSV import implemented; save-as-CSV from Excel |

## 15 · Known limitations
- SQLite = single-node; right for this stage, swap to Postgres if multi-region.
- Client-side session idle timer is cosmetic; the server timeout is the boundary.
- Quote-expiry emails run on a 6-hour tick (not to the minute).

## Emergency rollback procedure
In `deploy/DEPLOY.md`: redeploy previous commit (schema is additive-only) →
if data damaged, stop service, `node scripts/restore.mjs <backup>` (previous
db kept at `.pre-restore`), start, verify System Health, review Audit Log.

## Admin launch checklist (run in order)
1. Create host account → deploy staging + production per `deploy/DEPLOY.md`; run the persistence check.
2. Set all env vars (`.env.example`) — unique passwords per environment, `BACKUP_ENCRYPTION_KEY`, `TN_SECURE_COOKIES=1`, `TN_BASE_URL`.
3. Sign in with first-boot temp passwords → forced change → create real team accounts in Admin → Team.
4. Admin → Settings: confirm business info ((786) 634-1150 · bookings@topnotchrentalz.com · @topnotchrentalz) — edit anytime, no code.
5. Create the Power Automate workbook flow → paste URL into `EXCEL_WEBHOOK_URL` → confirm a row lands (Admin → Excel Sync).
6. Verify `topnotchrentalz.com` in Resend (or build the email flow) → set key → System Health shows email LIVE.
7. Stripe: add `sk_test_` + webhook endpoint `/api/stripe/webhook` + `whsec_` secret.
8. Receive the LUXX workbook → save as CSV → Import Fleet preview → admin commit → Partnerships confirms every field → flip LUXX to **Active** → verify vehicles publish.
9. Run the production pilot: `node scripts/pilot.mjs --remote` (both scenarios) + one human walk-through on an iPhone.
10. Point UptimeRobot at `/api/health`; schedule nightly off-host copy of `backups/`.
11. Only after 1–10 pass: announce launch. **Then** Phase 4 is complete.
