# Website Customer Accounts, Guest Booking & Privacy Hardening — Results

## Files changed

| Area | Files |
|---|---|
| New server modules | `lib/customers.js` (accounts/sessions/tokens/CSRF/shared rate limiter), `lib/services.js` (signature-services catalog + checklist gate) |
| Server wiring | `server.js` (customer routes, service-order routes, request linkage + AI consent capture, services catalog endpoint) |
| Consent gate | `lib/autopilot.js` (`aiConsentFor`, `llmForRequest` — deterministic pre-prompt blocking + AI-assisted labeling) |
| Website | `account.html` + `js/account.js` (new), `js/main.js` (auth gate, prefill, AI choice, services, honest offline failure), all 7 pages (Account nav, desktop + mobile), `services.html` (signature section), `policies.html` (AI privacy section) |
| Docs | `APPLE-APP-STORE-COMPLIANCE.md`, `CUSTOMER-ACCOUNTS.md`, this file |
| Tests | `tests/customer.mjs` (36 scenarios) |

## Database migrations (all additive; existing data untouched)

- New tables: `customers`, `customer_sessions`, `customer_tokens`, `rate_limits`, `service_orders`
- `requests` gains: `customer_id`, `ai_consent` (default `'human'`), `ai_consent_version`, `ai_consent_at`

## API routes added

`POST /api/customer/register` · `POST /api/customer/login` · `POST /api/customer/logout` ·
`POST /api/customer/logout-all` · `GET/PATCH/DELETE /api/customer/me` · `GET /api/customer/trips` ·
`POST /api/customer/verify/request|complete` · `POST /api/customer/reset/request|complete` ·
`GET /api/public/services` · `GET /api/services/orders` · `PATCH /api/services/orders/:id`

## Security controls

- Customer auth fully separated from staff/provider auth (own table, cookie `tn_cust`, zero staff permissions — 12 endpoints tested refusing customer cookies).
- `customer_id` derived only from the server session; forged body values ignored (tested).
- scrypt passwords; sha256-hashed session/verify/reset tokens; single-use, short-lived tokens; reset revokes all sessions; replay + expiry rejected (tested).
- Tokens delivered only through the configured email system; enumeration-safe reset ("If that account exists, instructions have been sent.").
- HttpOnly + SameSite=Lax cookies, Secure with `TN_SECURE_COOKIES=1`; CSRF double-submit (`tn_cust_csrf` + `x-csrf`) on all state-changing customer routes (tested).
- Shared SQLite-backed rate limiter on register/login/reset/verify/delete, layered on the in-memory limiter (tested, counter verified in DB).
- Full audit: registration, verification, login failures, consent grant/withdrawal, session revocation, deletion.
- **Offline fake-success vulnerability patched**: no local request IDs, no fake "Request Received", honest "We could not send your request. Nothing was booked or charged." + labeled unsent local recovery only; preview mode only behind `?preview=dev` and always says "Preview — no request was sent."
- AI consent: Human-only default, never preselected, never required; per-request + per-account recording with policy version/timestamp; deterministic pre-prompt gate; live withdrawal wins; blocks audited; AI text labeled "AI-assisted". Proven against a mock OpenAI endpoint (zero calls for Human-only).
- Signature services: 10 stable IDs, junk IDs rejected, "Request — confirmed separately", no fixed prices, 11-item ops checklist gate — approval/charging refused (HTTP 409) until it passes, alcohol never default.

## Test results

| Suite | Result | Environment | Integration mode |
|---|---|---|---|
| `tests/customer.mjs` (this pass) | **36/36 ✅** | fresh staging DB ×2 | email captured via mock webhook; OpenAI mocked locally; payments untouched |
| Phase 3 `tests/e2e.mjs` | **18/18 ✅** | fresh staging DB | mock Excel webhook |
| Phase 4 `tests/phase4.mjs` | **10/10 ✅** | fresh staging DB | mock Excel/Stripe webhooks |
| Phase 4.1 `tests/phase41.mjs` | **20/20 ✅** | fresh staging DB | mock payment provider (staging-only) |
| Phase 5.2 `tests/phase52.mjs` | **25/25 ✅** | fresh staging DB | OPENAI unset → deterministic fallback verified |
| App-contract tests | **not present in this repository** — expected from the v5.4 zip, which never arrived in this environment | — | — |

Per-test tables: `TEST-RESULTS-CUSTOMER.md`, `TEST-RESULTS*.md`. No mocked integration is claimed live.

## Remaining mocked integrations (NOT live)

Payments (Lumino awaiting merchant credentials; mock provider staging-only) · Email (recorded/webhook until `RESEND_API_KEY`) · Excel (queues until `EXCEL_WEBHOOK_URL`) · OpenAI (`OPENAI_MODEL` unset; GPT-5.6 Sol only if its exact production API id is verified — never guessed) · Hosting/monitoring (owner infrastructure).

## Remaining production blockers (website is NOT production-ready until)

1. Live payment provider verified end-to-end (test payment + webhook + refund).
2. Live email delivery verified (verification/reset emails actually arriving).
3. Live OpenAI routing verified with a real model id — or AI left disabled (fully supported).
4. Uptime monitoring pointed at `/api/health`.
5. `TN_ENV=production`, `TN_SECURE_COOKIES=1`, HTTPS domain, `BACKUP_ENCRYPTION_KEY` set.
6. Production privacy disclosures reviewed by counsel (AI section drafted at `policies.html#ai`).

Everything code-side for this pass (verification, recovery, CSRF, shared rate limiting, honest failure, consent gating) is implemented and tested in staging.

## Rollback instructions

```
git revert <this pass's commit>      # all changes are in one commit
```
Migrations are additive-only; reverting the code leaves the extra tables/columns
inert and harmless. No existing table or column was modified or dropped, so the
previous build runs unchanged against the same database.

## Deployment instructions

1. `git pull` on the host; restart `node server.js` (Node 22+).
2. New/changed env (see `.env.example`): `TN_BASE_URL` (used in account emails),
   `TN_SECURE_COOKIES=1` in production; email vars required for verification/reset
   delivery in production.
3. First boot auto-creates the new tables/columns; no manual migration step.
4. Verify: register a test account, verify email, submit a signed-in request,
   confirm it appears in Account → Your Requests, delete the test account.
