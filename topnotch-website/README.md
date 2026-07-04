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

## Branding
The real TOPNOTCH logo lives in `img/` (`logo-t.png` mark + `logo-topnotch.png`
wordmark, extracted to transparent PNGs). Headings use the self-hosted
**Chango** font (`fonts/`) to match the bubble wordmark; body text is Manrope.

## Hero interior video
Drop a starlight-interior clip (Maybach / Rolls-Royce / Escalade) at
`img/hero-interior.mp4` — it auto-plays and fades in over the animated
starlight cockpit art when you scroll into the interior phase. Good free
sources: pexels.com or coverr.co, search "car interior starlight / luxury
car interior night". Until the file exists, the animated art shows instead.

## Swapping in real photography
Car photo slots are intentionally **empty** ("Photo coming soon") and ready
for real fleet shots — replace `emptySlot()` usages in `js/main.js` or extend
`FLEET` entries with image paths. Service cards still use generated art
(`villaArt`, `yachtArt`, `chauffeurArt` in `js/data.js`).
