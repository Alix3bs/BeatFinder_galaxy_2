# TopNotchRentalz — Website + Operations System

Static site, no build step. Open `index.html` or serve the folder:

```
cd topnotch-website && python3 -m http.server 8000
```

## Pages
| Page | Purpose |
|---|---|
| `index.html` | Hero, category islands, fleet, services, VIP banner |
| `vip.html` | VIP membership tiers + application |
| `services.html` | Chauffeur / VIP services + premium experience |
| `policies.html` | Requirements, terms, privacy, cancellation, deposit/refund, damage, tickets/tolls, mileage, smoking, fuel |
| `partners.html` | Partner (fleet owner) inquiry form |
| `contact.html` | WhatsApp / phone / showroom |
| `track.html` | Customer request tracking (5-step status) |
| `admin/` | **Operations dashboard** (passcode-gated, unlinked from customer pages) |

## Booking pipeline ("Request to Book")
Nothing is auto-confirmed. Customer statuses:
**Request submitted → Availability being confirmed → Approved → Payment required → Booking confirmed**
(admin can also set Declined / Cancelled / Completed).

The 4-step request wizard collects: delivery/pickup + location, dates/times,
driver age, license + insurance + deposit confirmations, budget, backup
vehicle, occasion, chauffeur / FBO, extras + premium add-ons, notes, and
full contact info. Requests get an id like `TN-260705-8FQ2`.

## Admin dashboard (`admin/index.html`)
Default passcode `TOPNOTCH2026` — **change `ADMIN_PASS` in `admin/data-internal.js`.**
- **Dashboard**: stats + auto-generated reminders (confirm availability, chase
  payment, deliveries/pickups due, returns due, deposit refunds, provider
  payouts, review requests, stale availability verifications)
- **Requests**: full detail, provider matching (two lowest approved rates),
  assign provider, final price / internal cost / profit, approve / decline,
  Confirm Booking → creates the Active Rental and books the unit
- **Inventory**: full vehicle schema (year/make/model/trim/color, retail +
  provider rates, payout, profit, deposit, mileage, delivery areas, driver
  requirements, status, booked dates, last-verified, provider contact, notes)
- **Partners**: partner companies + website inquiries
- **Active Rentals**: payments, balance, deposit, payout, pickup/return
  status, inspection photo uploads, reviews, profit per booking
- **Booking Summary** button generates the premium customer summary (print/PDF)
- Every table exports to CSV (opens directly in Excel)

## Excel connection
All writes go to localStorage **and**, when configured, POST to
`WEBHOOKS.sheet` in `js/data.js` as `{ table, row }` with tables:
`CustomerRequests`, `PartnerInventory`, `ActiveRentals`, `Partners`,
`PartnerInquiries`. Point it at:
- **Power Automate**: "When an HTTP request is received" → switch on `table`
  → "Add a row into a table" on `TopNotchRentalz.xlsx` (OneDrive/SharePoint), or
- **Google Apps Script** web app appending to Sheets.

`WEBHOOKS.notify` receives a compact JSON summary of each new request
(car, dates, location, customer contact, age, insurance, deposit readiness) —
wire it to Teams/Slack/SMS so the team is pinged immediately.

## Data safety
- Customer pages load only `js/data.js` — retail prices, public terms.
- Provider/broker rates, payouts, profit, contacts and booked dates live only
  in `admin/data-internal.js` + the admin's browser storage.
- **Going to production**: the admin gate is client-side and fine for a pilot,
  but before real partner volume move `admin/` behind a real login (e.g. a
  tiny backend or hosting-level basic auth) and move webhooks server-side.

## Branding
Real TOPNOTCH logo in `img/` (transparent PNGs). Display font is self-hosted
**Chango** (matches the bubble wordmark); body is Manrope (`fonts/`).

## Hero interior video
Drop a starlight-interior clip (Maybach / Rolls / Escalade) at
`img/hero-interior.mp4` — it fades in over the animated starlight cockpit.
Until then, the animated art shows.

## Real photography
Car slots are intentionally empty ("Photo coming soon"). Add image paths to
FLEET entries / swap `emptySlot()` in `js/main.js` when the shoot is ready.
