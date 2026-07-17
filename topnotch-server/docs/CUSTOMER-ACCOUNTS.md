# Customer Accounts — Security, Retention & Deletion

## Architecture

Customer auth is a fully separate system from staff/provider auth:

| | Staff/Provider | Customer |
|---|---|---|
| Table | `users` | `customers` |
| Sessions | `sessions`, cookie `tn_sess` | `customer_sessions`, cookie `tn_cust` |
| Permissions | role matrix (`lib/auth.js`) | none — only `/api/customer/*` + public routes |
| CSRF | header-based JSON + SameSite | double-submit `tn_cust_csrf` cookie + `x-csrf` header |

A customer cookie can never satisfy `req.user` (staff) or partner checks —
tested explicitly (customer vs `/api/requests`, `/api/partners`,
`/api/rentals`, `/api/settings`, `/api/portal/*`).

`customer_id` is derived ONLY from the server session. It is never accepted
from the browser, and unauthenticated email addresses are never used to look
up another customer's requests.

## Token & session hygiene

- Passwords: scrypt via the existing `hashPassword` (same function as staff).
- Session tokens: 32 random bytes, stored as sha256 hashes; 30-day absolute
  expiry, 7-day idle expiry; deleted-account sessions die immediately.
- Verification tokens: random, single-use, 24 h, stored hashed.
- Reset tokens: random, single-use, 30 min, stored hashed; completing a
  reset revokes every session. Replay of a used or expired token fails.
- Tokens leave the server ONLY inside emails through the configured email
  system; no API ever returns them. Password-reset requests always answer
  "If that account exists, instructions have been sent."
- Cookies: HttpOnly (session), SameSite=Lax, Secure when
  `TN_SECURE_COOKIES=1` (required in production).
- Rate limiting: in-memory limiter PLUS a shared SQLite-backed limiter
  (`rate_limits` table) on register/login/reset/verify/delete, so limits
  survive restarts and apply across processes on the same database.

## Audit trail

`customer.register`, `customer.verified`, `customer.login`,
`customer.login.failed`, `customer.consent.granted`,
`customer.consent.withdrawn`, `customer.logout.all`,
`customer.reset.completed`, `customer.delete`, plus request-level
`request.ai_consent` with policy version.

## Data retention

| Data | Retention |
|---|---|
| Account profile (name, phone, email, password hash, AI preference) | Until the customer deletes the account |
| Sessions & tokens | Deleted on logout/expiry/reset/deletion |
| Requests & rentals & payments | Retained as business/financial records per company policy and law, **unlinked** from deleted accounts |
| Uploaded documents (licenses etc.) | Auto-deleted after `doc_retention_days` (default 90) — pre-existing Phase 4 control |
| Unsent request drafts | Stored only in the customer's own browser (localStorage), labeled unsent; never on the server |

## Permanent deletion (in-product)

Account → Delete Account (password confirmation required):
1. all sessions and tokens are deleted;
2. the customer row (name, phone, email, hash, preferences) is deleted;
3. requests keep their operational copy of contact details as business
   records but lose the account link (`customer_id = NULL`);
4. the deletion is audited without storing the deleted email.

Deleted-account login fails (no account); a deleted account's old session
cookie fails on the next request.

## AI privacy (customer-facing contract)

- Default is **Human-only**; AI permission is never preselected and never
  required to book. The choice, policy version and timestamp are recorded
  per request AND per account.
- Withdrawal in Account settings applies immediately — the consent gate
  re-checks the customer's LIVE preference before every prompt build.
- Enforcement is deterministic server code (`lib/autopilot.js →
  aiConsentFor()/llmForRequest()`), audited on every block.
- AI-written text is labeled "AI-assisted" and AI never touches
  availability, payments, deposits, damage, refunds, payouts or provider
  approval — those paths never call the LLM at all.
