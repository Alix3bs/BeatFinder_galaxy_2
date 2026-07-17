# Apple App Store Compliance — TopNotchRentalz

This document exists so a future iOS app (and the reviewers who inspect it)
can rely on product facts that are already true on the website/backend.
It makes **no claims about Apple rules that Apple has not published** — in
particular, we do **not** claim Apple requires a "Made with AI" badge; we
simply disclose AI use honestly in our own privacy policy and product copy.

## Product facts (implemented and tested)

| Fact | Implementation |
|---|---|
| Accounts are optional | Guest booking gets identical price, fleet access, priority and signature-service access (`tests/customer.mjs`) |
| Guest booking is available | "Continue as guest" is one of three equal choices at booking start |
| Account deletion is inside the product | Account → Delete Account: permanent, password-confirmed, in-product (`DELETE /api/customer/me`) |
| AI-assisted service is optional | Per-request choice + account preference; **defaults to Human-only**, never preselected, never required to book |
| Human-only service is available | When chosen, no contact/booking data is sent to third-party AI — enforced in deterministic server code (`aiConsentFor`/`llmForRequest`) |
| Provider confirmation is required | No booking confirms without the provider approving the exact unit |
| Vehicle rental is a physical service | Real-world car rental fulfilled offline |
| Payment uses external physical-service payment methods | Configured payment provider (hosted checkout / bank / Zelle / cash with staff verification). **No Apple In-App Purchase for rentals** — IAP is not used for physical services |

## App Review Notes (template — fill the bracketed values at submission)

```
TopNotchRentalz is a physical-service app: customers request real-world
exotic-car rentals in South Florida, fulfilled offline by our team and
licensed vehicle providers.

ACCOUNTS
- Accounts are optional. Guest booking is available from the first screen
  of the booking flow with identical pricing and access.
- Account deletion is built into the product: Account → Delete Account
  (password-confirmed, immediate, permanent).

AI DISCLOSURE
- AI-assisted service is OPTIONAL and defaults to OFF (Human-only).
- Human-only service sends no contact or booking data to third-party AI.
- AI never decides availability, payments, deposits, damage, refunds,
  provider payouts or provider approval.

PAYMENTS
- Vehicle rentals are physical services; we do not use In-App Purchase.
- Payment happens through our payment provider's hosted checkout or
  approved offline methods (bank transfer, Zelle, cash) verified by staff.

DEMO / REVIEW ACCOUNT
- Email: [review demo email]
- Password: [review demo password]
- The demo account is staging-only and cannot trigger real charges.
- To exercise the flow: choose any vehicle → Request to Book → submit;
  the request enters "Availability being confirmed" and no payment is
  ever taken without staff/provider approval.

URLS
- Privacy Policy: [https://<domain>/policies.html#privacy] (AI section at #ai)
- Support: [https://<domain>/contact.html]
- Account deletion instructions: sign in → Account → Delete Account;
  also documented at [https://<domain>/policies.html#privacy]
```

## Things this document deliberately does NOT claim

- That Apple requires a "Made with AI" label (no such published rule is cited).
- That the app exists or has been submitted (it has not, as of this pass).
- That any mocked integration is live — see `WEBSITE-ACCOUNTS-RESULTS.md`
  for the honest live-vs-mocked table.
