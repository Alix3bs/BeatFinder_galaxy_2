# TOPNOTCH — Exotic Rentals Website (Design Phase)

Static site, no build step. Open `index.html` in a browser or serve the folder:

```
cd topnotch-website && python3 -m http.server 8000
```

## Pages
- `index.html` — hero (scroll from car exterior into the interior), swipeable category islands, fleet grid, chauffeur/villa/yacht services, VIP banner
- `vip.html` — VIP plan page (Silver / Black / Chrome tiers + application popup)

## Booking flow
Click any car/service → detail popup (price, specs, requirements) → **Rent Now** →
choose **Delivery** or **Drop-off & Pickup** (with exit ✕):
- Pickup shows the business address (edit in `js/data.js` → `BUSINESS`)
- Delivery shows the black/orange "Select Location" form (location, use-my-location, different return location, dates/times, contact)

## Phase 2 — connect the spreadsheet + AI agent
Requests are already collected as structured JSON (also stored in `localStorage`
under `topnotch_requests`). To go live, set `BUSINESS.bookingWebhook` in
`js/data.js` to a webhook that appends the row to the booking sheet and pings
the AI concierge agent, which then messages the owner.

## Swapping in real photography
All vehicle/service visuals are generated SVG studio art (placeholders).
Replace the art functions in `js/data.js` (`carArt`, `villaArt`, `yachtArt`,
`chauffeurArt`) or layer real images into the `.card-media` / hero scenes —
slots are structured for a drop-in swap.
