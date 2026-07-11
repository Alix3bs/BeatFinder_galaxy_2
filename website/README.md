# BeatFinder Premium Website

Static subscription storefront for the BeatFinder iOS app. When a user taps
**Upgrade** in the app, the app opens this site; checkout and billing are
handled by **Lumino**.

## Pages

| Page | Purpose |
| --- | --- |
| `index.html` | Home — hero, feature grid, how-it-works, CTA |
| `pricing.html` | Starter $4.99 / Premium $9.99 / Pro $19.99 per month |
| `checkout.html` | Redirect page — shows the chosen plan, then forwards to Lumino hosted checkout (`?plan=starter\|premium\|pro`, optional `&uid=<user>`) |
| `success.html` | Post-payment landing (Lumino success URL); deep-links back to the app |
| `cancel.html` | Aborted checkout landing (Lumino cancel URL) |
| `account.html` | Manage subscription — links to the Lumino customer portal |

## Lumino configuration

All Lumino settings live in `assets/js/lumino.js` (`LUMINO_CONFIG`):

- `checkoutBase` — your Lumino hosted-checkout endpoint.
- `portalUrl` — the Lumino customer portal URL.
- `plans.<id>.luminoPriceId` — the Lumino price ID for each plan.
- `plans.<id>.checkoutUrl` — optional full payment link per plan; takes
  precedence over `checkoutBase` when set.

The values checked in are placeholders — swap in the real IDs/URLs from the
Lumino dashboard before going live. Entitlement unlocking in the app should be
driven by Lumino webhooks on the backend, not by the client-side state this
site keeps (`localStorage` is display-only).

## App integration

- The app opens `pricing.html` (or `checkout.html?plan=premium&uid=<id>` to
  skip straight to checkout).
- `success.html` / `cancel.html` link back via the `beatfinder://` URL scheme.

## Deployment

Plain static files — no build step. Serve the `website/` directory from any
static host (Render static site, Netlify, GitHub Pages, S3+CloudFront). The
only external dependency is Google Fonts.

Local preview:

```bash
cd website && python3 -m http.server 8000
```
