# TopNotch Rentals — customer identity, privacy & signature services

Two-sided, mobile-first app for the South Florida luxury rental brokerage.
Renters request cars; fleet partners (providers) confirm them. TopNotch owns
no fleet — every request waits on the provider's confirmation of the exact
vehicle and dates before a quote is approved or payment is accepted.

## Files

| File | What it is |
|---|---|
| `index.html` | The entire app — single self-contained file (no dependencies). Live when served by `server.js`; honest preview mode otherwise. |
| `server.js` | Zero-dependency Node backend (node ≥ 20). Accounts, sessions, tokens, requests, provider portal, AI-consent gate. |
| `tests/api.test.mjs` | Full API test suite (28 tests). |

## Run it

```bash
# live mode (app + API on one port)
node topnotch/server.js
# open http://localhost:4305

# tests
node --test topnotch/tests/api.test.mjs
```

Opening `index.html` without the server (e.g. as a claude.ai artifact) runs
**preview mode**: every screen is explorable, but requests, accounts and
sign-in honestly refuse — nothing is simulated as sent, booked or charged.

### Environment

| Variable | Default | Meaning |
|---|---|---|
| `PORT` | `4305` | HTTP port |
| `NODE_ENV` | – | `production` adds `Secure` to cookies |
| `TN_DATA` | `topnotch/data.json` | persistence file; `:memory:` for none |
| `TN_OUTBOX` | `topnotch/outbox.log` | email outbox (no SMTP configured — tokens are delivered here, never in API responses) |
| `TN_OPS` | `topnotch/ops.log` | ops/management notices |
| `OPENAI_MODEL` | *(empty)* | **Configurable only — never guessed.** Target is GPT-5.6 Sol *only if its exact production API identifier is available*; until then leave unset and AI-assisted tasks stay paused while every deterministic flow continues. |
| `OPENAI_API_KEY` | *(empty)* | same pausing behavior when absent |
| `TN_PROVIDER_PASSWORD` | `demo-provider-pass` | demo provider portal credential (`provider@topnotch.demo`) |
| `TN_TOKEN_TTL_MS` | 30 min | test-only override for token expiry |

## Non-negotiables, as implemented

- **Request-to-book** — requests are `pending_provider` until the provider
  confirms; the quote is computed by deterministic server code and payment on
  an unapproved request returns `409`.
- **No fake signals** — no instant booking, invented response times,
  fabricated demand/booking counts or reviews anywhere. Partner dashboard
  numbers not backed by the server are labeled "Sample data".
- **Insurance** — "included in the quoted price, subject to eligibility and
  verification" at every deciding moment.
- **Deposit** — "refundable after the documented vehicle-return review and
  rental-agreement requirements"; never promised as automatic.
- **AI privacy (Apple-compliant disclosure)** — per-request and account-level
  choice between *Human-only service* (default, never preselected away) and
  *Allow AI-assisted service*; consent + policy version + timestamp recorded;
  withdrawal in Account settings. The server checks consent **before** any
  prompt is constructed (`autopilotProcess` in `server.js`); human-only
  requests are blocked from every customer-data-to-OpenAI path in
  deterministic code. AI never decides availability, pricing, approvals,
  payments, deposits, damage, refunds, payouts, permissions or disputes.
  AI-authored customer messages carry an "AI-assisted" label, and only concise
  reasoning summaries (information checked / rule used / decision / evidence /
  next action) would ever be surfaced — never hidden chain-of-thought.
- **Sessions** — HttpOnly + SameSite=Strict cookies (Secure in production);
  CSRF header required on authenticated mutations; customer, guest and
  provider sessions are separate spaces; `customer_id` always derives from the
  session, never the payload; admin routes always refuse customer/provider
  sessions.
- **Tokens** — verification and reset tokens are random, single-use,
  short-lived, stored as SHA-256 hashes, rate-limited, and delivered only via
  the email outbox.
- **Preview honesty** — with no server, a submitted request shows:
  *"Preview mode: this request was not sent because no TopNotch server is
  connected. Nothing was booked or charged."* — no fake request number,
  tracking, payment options or provider-review claims.

## Remaining integrations (mocked or absent — not silently faked)

- **Email delivery**: outbox file only; wire `SMTP_URL` + a mailer for real delivery.
- **Payments**: `/pay` records a demo payment after provider approval; no
  processor (Stripe etc.) is integrated.
- **OpenAI**: the consent gate and pause path are real; no API call is made
  (no key/model configured, and no production identifier for GPT-5.6 Sol is
  assumed).
- **Rate limiting**: in-memory sliding window with a pluggable store — a
  shared store (Redis) is required before multi-instance production.
- **Persistence**: JSON file, single-process; use a real database in production.
- Signature-service vendor assignment, hotel/FBO permission workflows and the
  partner tier ledger are product flows represented honestly in the UI
  ("Request — confirmed separately") but have no ops tooling yet.
