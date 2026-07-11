# Lumino Payment Integration — Status & Onboarding Guide

## Implementation status (honest classification)

| Layer | Status |
|---|---|
| **Payment-provider adapter** (checkout, invoice, status, refunds, verified webhooks, dedupe, category/booking linkage) | ✅ Built and fully exercised by tests 10–17 in `TEST-RESULTS-PHASE41.md` |
| **Lumino backend** | 🔶 **Adapter ready, awaiting merchant credentials + API documentation.** Endpoint paths, auth header and signature scheme are env-configurable so they can be matched to Lumino's docs without code changes. **Not claimed live.** |
| **Mock checkout** | ✅ Staging/tests only (hard-disabled when `TN_ENV=production`). Drives the full hold → popup → signed webhook → booking pipeline. |
| **Manual payment fallback** | ✅ Live logic: bank transfer / Zelle / cash / other → "Payment verification required" → admin-only verification → confirmed. Never auto-confirms. |
| **Stripe** | ✅ Kept as an optional adapter, **disabled** unless an admin sets `stripe_enabled=1` *and* keys exist in env. |
| **Security-deposit authorization + capture** | 🚫 **Unsupported until confirmed.** `deposit_handling=authorization` is rejected by the server unless the active provider officially supports it (`LUMINO_SUPPORTS_AUTH_CAPTURE=1` only after written confirmation). Default: clearly-labeled **collected** deposit or **external** admin-approved process. Never simulated. |

## The Lumino integration is NOT live until all of these pass on the deployed environment
1. Real merchant credentials configured (env vars below) — never in code or the browser.
2. Real webhook signature verification succeeds against a Lumino-sent event.
3. A low-value test payment succeeds end-to-end (hold → checkout → webhook → Booking confirmed).
4. A failed/canceled payment is handled (booking NOT confirmed, customer + team notified).
5. A duplicate webhook delivery is rejected as duplicate.
6. A refund is executed and recorded.
7. The full request → availability → hold → payment → booking flow passes (`node scripts/pilot.mjs --remote`).

## What TopNotchRentalz must obtain from Lumino (no secret values here)

**Account/permissions**
- Approved merchant account for vehicle-rental / high-ticket transactions (share expected ticket sizes: $500–$15,000).
- API access enabled with permissions: create checkout/payment sessions, create invoices, read payment status, create refunds, manage webhooks.
- Written confirmation of which features the account supports: ACH/bank, BNPL/payment plans, **authorization + delayed capture** (for deposits), partial refunds.

**Credentials → environment variables (server-side only)**
| Item from Lumino | Env var |
|---|---|
| API base URL | `LUMINO_API_BASE` |
| Secret API key | `LUMINO_API_KEY` |
| Webhook signing secret | `LUMINO_WEBHOOK_SECRET` |
| Auth header name/prefix (if not `Authorization: Bearer`) | `LUMINO_AUTH_HEADER`, `LUMINO_AUTH_PREFIX` |
| Signature header + scheme docs | `LUMINO_SIGNATURE_HEADER` (adapter expects HMAC-SHA256 hex of the raw body — if Lumino uses a different scheme, adjust `lib/payments.js → lumino.verifyWebhook`, ~10 lines) |
| Endpoint paths (if they differ from the defaults) | `LUMINO_CHECKOUT_PATH`, `LUMINO_INVOICE_PATH`, `LUMINO_STATUS_PATH`, `LUMINO_REFUND_PATH` |
| Feature confirmations | `LUMINO_SUPPORTS_ACH`, `LUMINO_SUPPORTS_BNPL`, `LUMINO_SUPPORTS_AUTH_CAPTURE` (set to 1 only with written confirmation) |

**Webhook settings to configure in the Lumino dashboard**
- Endpoint: `https://<your-domain>/api/payments/webhook/lumino`
- Events: payment succeeded, payment failed, payment canceled/expired, refund updated (exact names per Lumino's docs).
- Signing: enabled, with the secret mirrored into `LUMINO_WEBHOOK_SECRET`.
- Success/cancel redirect URLs are set per-session by the server to the customer's tracking page.

## Data handling guarantees (already enforced + tested)
- Card/bank details never touch the TopNotchRentalz server — hosted checkout only.
- Stored per transaction: provider name, external payment/session ref, status, amount, currency, category, timestamps, booking/request linkage. Nothing else.
- Credentials, secrets and merchant info: env only; the admin UI shows configured/missing flags, never values.
- Excel receives payment rows without any credentials or card data (verified by test 19).
- A browser redirect alone never confirms anything — only verified webhooks or admin verification do.
