/* ============================================================
   TOPNOTCH — fleet data + generated studio art
   NOTE: every card has an `img` slot — drop in real fleet
   photography paths later (e.g. "img/huracan.jpg") and the
   photo will render on top of the studio art automatically.
   ============================================================ */

const BUSINESS = {
  name: "TopNotchRentalz",
  // TODO: replace with the real business address
  address: "1200 Brickell Bay Drive, Suite 400",
  city: "Miami, FL 33131",
  market: "Miami",
  hours: "Mon – Sun · 9:00 AM – 9:00 PM",
  phone: "(305) 000-0000",
  whatsapp: "13050000000",           // digits only, for wa.me links
  email: "bookings@topnotchrentalz.com",
  instagram: "https://instagram.com/"
};

/* ============================================================
   INTEGRATIONS — point these at your Excel + notification stack.
   Both receive JSON POSTs. Recommended: a Power Automate flow
   ("When an HTTP request is received" → "Add a row into a table"
   on the TopNotchRentalz.xlsx workbook) or a Google Apps Script.
   Payload shape: { table: "CustomerRequests"|"PartnerInventory"|
   "ActiveRentals", row: {...} }
   ============================================================ */
const WEBHOOKS = {
  sheet: "",    // writes rows into the Excel tables
  notify: ""    // pings the team (Teams/Slack/SMS bridge) on new requests
};

/* customer-facing request pipeline (in order) */
const STATUS_FLOW = [
  "Request submitted",
  "Availability being confirmed",
  "Approved",
  "Payment required",
  "Booking confirmed"
];
/* admin-only terminal states */
const STATUS_OTHER = ["Declined", "Cancelled", "Completed"];

/* premium experience add-ons (booking form, after approval too) */
const PREMIUM_ADDONS = [
  { id: "basket",   name: "Branded gift basket",            price: "$75" },
  { id: "water",    name: "Bottled water",                  price: "Included" },
  { id: "charger",  name: "Phone charger",                  price: "Included" },
  { id: "occasion", name: "Birthday / celebration setup",   price: "$250" },
  { id: "chauffeur",name: "Chauffeur",                      price: "from $150/hr" },
  { id: "fbo",      name: "Airport / FBO pickup",           price: "$200" },
  { id: "media",    name: "Professional photos / video",    price: "$350" },
  { id: "concierge",name: "Yacht, villa or concierge",      price: "Quoted" }
];

/* shared public rental terms (per-car overrides below) */
const RENTAL_TERMS = {
  minAge: 25,
  license: "Valid driver's license (matching renter)",
  insurance: "Full-coverage insurance transferable to rental",
  payments: "Card, Zelle, wire — deposit authorized on card",
  deliveryAreas: "Miami-Dade, Broward, Palm Beach, MIA/FLL/OPF/FXE airports",
  minDays: 1,
  mileageIncluded: 100,     // per day
  deliveryFee: 150          // waived for VIP members
};

/* ---------- empty photo slot (drop real fleet shots in later) ---------- */
function emptySlot(label) {
  return `<div class="empty-slot">
    <img class="es-mark" src="img/logo-t.png" alt="">
    <span>${label || "Photo coming soon"}</span>
  </div>`;
}

/* ---------- rental extras (shown in the car detail popup) ---------- */
const EXTRAS = [
  { id: "miles",   name: "Unlimited Miles",  desc: "Worried about the miles? Drive without limits.",            price: 149, per: "day",  ico: "pin" },
  { id: "tolls",   name: "Pre-paid Tolls",   desc: "Skip the toll booth and drive with ease.",                  price: 25,  per: "day",  ico: "toll" },
  { id: "late",    name: "Late Return",      desc: "Need extra time? Return the car later, no stress.",         price: 95,  per: "trip", ico: "clock" },
  { id: "clean",   name: "Cleaning Fee",     desc: "Skip the car wash — return it as-is.",                      price: 150, per: "trip", ico: "clean" },
  { id: "fuel",    name: "Pre-paid Fuel",    desc: "Skip the gas station — return with any fuel level.",        price: 120, per: "trip", ico: "fuel" },
  { id: "seat",    name: "Child Seat",       desc: "Required for children under 12 years old.",                 price: 25,  per: "day",  ico: "seat" }
];

/* weekly ≈ 1 day free, monthly ≈ locked member-style rate */
const weeklyRate  = d => d * 6;
const monthlyRate = d => d * 22;
const extraMileRate = d => (d >= 1200 ? 7.5 : d >= 800 ? 5 : d >= 500 ? 3.5 : 2);

/* ---------- studio art generator ---------- */
/* paint = main body color of the silhouette */
function studioBase(inner, glowColor) {
  const glow = glowColor || "#ff6a00";
  return `
  <svg viewBox="0 0 640 400" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <radialGradient id="bgGlow" cx="50%" cy="18%" r="80%">
        <stop offset="0%" stop-color="#232323"/>
        <stop offset="55%" stop-color="#101010"/>
        <stop offset="100%" stop-color="#070707"/>
      </radialGradient>
      <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#0c0c0c"/>
        <stop offset="100%" stop-color="#050505"/>
      </linearGradient>
      <linearGradient id="chrome" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#fafafa"/>
        <stop offset="45%" stop-color="#c9ced5"/>
        <stop offset="55%" stop-color="#8d929a"/>
        <stop offset="100%" stop-color="#e7e9ed"/>
      </linearGradient>
      <radialGradient id="uGlow" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stop-color="${glow}" stop-opacity=".55"/>
        <stop offset="100%" stop-color="${glow}" stop-opacity="0"/>
      </radialGradient>
    </defs>
    <rect width="640" height="400" fill="url(#bgGlow)"/>
    <rect y="300" width="640" height="100" fill="url(#floor)"/>
    <ellipse cx="320" cy="70" rx="300" ry="90" fill="rgba(255,255,255,.03)"/>
    <line x1="60" y1="300" x2="580" y2="300" stroke="rgba(255,255,255,.06)"/>
    ${inner}
  </svg>`;
}

function wheel(cx, cy, r) {
  return `
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="#0a0a0a" stroke="#1c1c1c" stroke-width="3"/>
    <circle cx="${cx}" cy="${cy}" r="${r * 0.62}" fill="url(#chrome)"/>
    <circle cx="${cx}" cy="${cy}" r="${r * 0.2}" fill="#111"/>
    <g stroke="#111" stroke-width="4">
      <line x1="${cx - r * 0.55}" y1="${cy}" x2="${cx + r * 0.55}" y2="${cy}"/>
      <line x1="${cx}" y1="${cy - r * 0.55}" x2="${cx}" y2="${cy + r * 0.55}"/>
      <line x1="${cx - r * 0.4}" y1="${cy - r * 0.4}" x2="${cx + r * 0.4}" y2="${cy + r * 0.4}"/>
      <line x1="${cx - r * 0.4}" y1="${cy + r * 0.4}" x2="${cx + r * 0.4}" y2="${cy - r * 0.4}"/>
    </g>`;
}

function carArt(type, paint) {
  const p = paint || "#111214";
  let body = "";

  if (type === "super") {
    body = `
      <ellipse cx="320" cy="308" rx="250" ry="16" fill="url(#uGlow)"/>
      <path d="M62,290 C70,262 118,252 168,248 C205,208 262,186 330,184 C398,182 452,198 488,228 C540,234 578,252 588,272 C596,284 592,290 580,292 L62,292 Z" fill="${p}"/>
      <path d="M196,246 C226,214 276,198 330,197 C376,196 414,206 442,226 L420,246 Z" fill="#05070a" opacity=".9"/>
      <path d="M70,284 L582,284 L580,292 L62,292 Z" fill="#ff6a00" opacity=".85"/>
      <path d="M168,248 C205,208 262,186 330,184 L330,192 C266,194 214,214 180,250 Z" fill="rgba(255,255,255,.16)"/>
      <ellipse cx="176" cy="290" rx="46" ry="42" fill="#070707"/>
      <ellipse cx="486" cy="290" rx="46" ry="42" fill="#070707"/>
      ${wheel(176, 288, 38)}
      ${wheel(486, 288, 38)}
      <rect x="560" y="252" width="22" height="8" rx="4" fill="#ff6a00" opacity=".9"/>
      <path d="M62,290 C70,262 118,252 168,248 L160,258 C120,262 84,272 76,292 Z" fill="rgba(255,255,255,.05)"/>`;
  } else if (type === "suv") {
    body = `
      <ellipse cx="320" cy="312" rx="255" ry="16" fill="url(#uGlow)"/>
      <path d="M84,292 C84,258 96,238 118,232 L142,178 C148,162 162,154 182,152 L420,152 C444,152 458,160 470,176 L502,228 C540,236 560,254 562,276 C564,288 558,294 546,294 L84,294 Z" fill="${p}"/>
      <path d="M158,180 C164,168 172,164 186,164 L288,164 L288,224 L134,224 Z M304,164 L414,164 C430,164 438,170 446,180 L472,224 L304,224 Z" fill="#05070a" opacity=".9"/>
      <path d="M88,282 L560,282 L558,294 L84,294 Z" fill="#ff6a00" opacity=".8"/>
      <path d="M118,232 L142,178 C148,162 162,154 182,152 L196,152 L166,232 Z" fill="rgba(255,255,255,.08)"/>
      <ellipse cx="188" cy="292" rx="50" ry="46" fill="#070707"/>
      <ellipse cx="470" cy="292" rx="50" ry="46" fill="#070707"/>
      ${wheel(188, 290, 42)}
      ${wheel(470, 290, 42)}
      <rect x="536" y="248" width="20" height="10" rx="5" fill="#ff6a00" opacity=".9"/>`;
  } else { /* sedan */
    body = `
      <ellipse cx="320" cy="310" rx="255" ry="15" fill="url(#uGlow)"/>
      <path d="M66,288 C70,262 100,250 150,244 C176,212 224,194 296,192 L380,192 C428,194 462,206 486,232 C536,238 570,254 578,272 C584,283 580,290 568,290 L66,290 Z" fill="${p}"/>
      <path d="M172,242 C196,214 238,202 296,201 L372,201 C408,203 436,212 458,234 L432,242 Z" fill="#05070a" opacity=".9"/>
      <path d="M72,280 L574,280 L568,290 L66,290 Z" fill="#ff6a00" opacity=".8"/>
      <path d="M150,244 C176,212 224,194 296,192 L296,200 C232,202 190,218 166,246 Z" fill="rgba(255,255,255,.12)"/>
      <ellipse cx="182" cy="288" rx="46" ry="42" fill="#070707"/>
      <ellipse cx="478" cy="288" rx="46" ry="42" fill="#070707"/>
      ${wheel(182, 286, 37)}
      ${wheel(478, 286, 37)}
      <rect x="552" y="252" width="20" height="8" rx="4" fill="#ff6a00" opacity=".9"/>`;
  }
  return studioBase(body);
}

function villaArt() {
  return studioBase(`
    <ellipse cx="320" cy="316" rx="260" ry="14" fill="url(#uGlow)"/>
    <rect x="120" y="170" width="180" height="130" fill="#101010" stroke="#232323"/>
    <rect x="300" y="130" width="220" height="170" fill="#161616" stroke="#2a2a2a"/>
    <rect x="316" y="150" width="60" height="42" fill="#ff8c1a" opacity=".85"/>
    <rect x="390" y="150" width="60" height="42" fill="#ffb15c" opacity=".6"/>
    <rect x="316" y="210" width="134" height="66" fill="#ff6a00" opacity=".3"/>
    <rect x="138" y="192" width="42" height="34" fill="#ff8c1a" opacity=".55"/>
    <rect x="196" y="192" width="42" height="34" fill="#ffb15c" opacity=".35"/>
    <rect x="138" y="244" width="100" height="46" fill="#ff6a00" opacity=".22"/>
    <rect x="100" y="298" width="440" height="6" fill="url(#chrome)" opacity=".5"/>
    <rect x="150" y="304" width="340" height="18" fill="#0f1a1f" opacity=".9"/>
    <rect x="150" y="304" width="340" height="18" fill="#ff6a00" opacity=".08"/>
    <path d="M84,300 L84,236 C84,222 74,220 66,226 M84,240 C92,230 100,228 104,236 M84,252 C76,244 66,244 62,252" stroke="#1f1f1f" stroke-width="7" fill="none" stroke-linecap="round"/>
    <path d="M556,300 L556,222 C556,206 544,204 536,212 M556,228 C566,216 576,214 580,224 M556,244 C546,234 536,234 532,244" stroke="#1c1c1c" stroke-width="8" fill="none" stroke-linecap="round"/>`);
}

function yachtArt() {
  return studioBase(`
    <rect x="0" y="286" width="640" height="114" fill="#07131a"/>
    <rect x="0" y="286" width="640" height="3" fill="#ff6a00" opacity=".35"/>
    <ellipse cx="320" cy="300" rx="260" ry="12" fill="url(#uGlow)"/>
    <path d="M90,286 L560,286 L520,244 C500,226 470,218 430,218 L150,218 C132,218 122,228 116,244 Z" fill="#0e0e10"/>
    <path d="M90,286 L560,286 L552,294 L102,294 Z" fill="#13181c"/>
    <path d="M150,218 L430,218 L420,190 C414,176 402,170 384,170 L220,170 C200,170 188,180 178,196 Z" fill="#15151a"/>
    <rect x="226" y="182" width="150" height="14" rx="7" fill="#ff8c1a" opacity=".8"/>
    <rect x="150" y="230" width="290" height="10" rx="5" fill="#ff6a00" opacity=".45"/>
    <path d="M240,170 L262,140 L286,170 Z" fill="url(#chrome)" opacity=".8"/>
    <path d="M118,242 L520,242" stroke="rgba(255,255,255,.14)" stroke-width="2"/>
    <ellipse cx="320" cy="330" rx="200" ry="8" fill="#ff6a00" opacity=".08"/>`);
}

function chauffeurArt() {
  return studioBase(`
    <ellipse cx="320" cy="310" rx="255" ry="15" fill="url(#uGlow)"/>
    <path d="M60,288 C64,260 96,248 152,242 C180,208 232,190 310,188 L396,188 C446,190 480,204 502,232 C548,240 576,254 582,272 C588,283 584,290 572,290 L60,290 Z" fill="#0b0b0d"/>
    <path d="M176,240 C202,210 248,198 310,197 L388,197 C424,199 452,210 472,234 L446,240 Z" fill="#04060a"/>
    <path d="M66,280 L578,280 L572,290 L60,290 Z" fill="url(#chrome)" opacity=".55"/>
    <ellipse cx="180" cy="288" rx="46" ry="42" fill="#070707"/>
    <ellipse cx="482" cy="288" rx="46" ry="42" fill="#070707"/>
    ${wheel(180, 286, 37)}
    ${wheel(482, 286, 37)}
    <rect x="284" y="150" width="76" height="22" rx="11" fill="#ff6a00"/>
    <text x="322" y="166" text-anchor="middle" font-family="Manrope, sans-serif" font-size="12" font-weight="800" fill="#000">VIP</text>`);
}

/* ---------- category islands ---------- */
const CATEGORIES = [
  { id: "all",        icon: "★",  name: "All Fleet",        type: "filter" },
  { id: "lamborghini",icon: "L",  name: "Lamborghini",      type: "filter" },
  { id: "ferrari",    icon: "F",  name: "Ferrari",          type: "filter" },
  { id: "mclaren",    icon: "M",  name: "McLaren",          type: "filter" },
  { id: "rolls-royce",icon: "RR", name: "Rolls-Royce",      type: "filter" },
  { id: "bentley",    icon: "B",  name: "Bentley",          type: "filter" },
  { id: "mercedes",   icon: "MB", name: "Mercedes-Benz",    type: "filter" },
  { id: "bmw",        icon: "BM", name: "BMW",              type: "filter" },
  { id: "audi",       icon: "A",  name: "Audi",             type: "filter" },
  { id: "porsche",    icon: "P",  name: "Porsche",          type: "filter" },
  { id: "range-rover",icon: "R",  name: "Range Rover",      type: "filter" },
  { id: "corvette",   icon: "C",  name: "Corvette",         type: "filter" },
  { id: "chauffeur",  icon: "♛",  name: "Chauffeur",        type: "anchor", href: "#services" },
  { id: "villas",     icon: "⌂",  name: "Villas",           type: "anchor", href: "#services" },
  { id: "yachts",     icon: "⚓", name: "Yachts",           type: "anchor", href: "#services" },
  { id: "vip",        icon: "✦",  name: "VIP Plan",         type: "link",   href: "vip.html", vip: true }
];

/* ---------- fleet (CUSTOMER-FACING ONLY — no provider/broker
   rates, payouts or profit ever live in this file) ---------- */
/* availability overrides (default: available). Admin dashboard
   changes flow through localStorage at runtime. */
const VEHICLE_STATUS_SEED = { f8: "booked", autobio: "maintenance" };

function vehicleStatus(id) {
  try {
    const o = JSON.parse(localStorage.getItem("tn_vehicle_status") || "{}");
    if (o[id]) return o[id];
  } catch (e) { /* ignore */ }
  return VEHICLE_STATUS_SEED[id] || "available";
}

/* two comparable alternatives: same category first, then closest price */
function comparableAlternatives(car, n) {
  return FLEET
    .filter(f => f.id !== car.id && vehicleStatus(f.id) === "available")
    .sort((a, b) => {
      const catA = (a.cat === car.cat ? 0 : 1) - (b.cat === car.cat ? 0 : 1);
      if (catA) return catA;
      return Math.abs(a.price - car.price) - Math.abs(b.price - car.price);
    })
    .slice(0, n || 2);
}

const FLEET = [
  { id: "huracan",   brand: "lamborghini", name: "Lamborghini Huracán EVO", cat: "Supercar", body: "super",  paint: "#ff6a00", price: 1199, deposit: 3000, hp: "631 HP", zero60: "2.9s", top: "202 mph", seats: 2, hot: true },
  { id: "urus",      brand: "lamborghini", name: "Lamborghini Urus",        cat: "Super SUV", body: "suv",   paint: "#15161a", price: 1099, deposit: 3000, hp: "641 HP", zero60: "3.1s", top: "190 mph", seats: 4 },
  { id: "f8",        brand: "ferrari",     name: "Ferrari F8 Tributo",      cat: "Supercar", body: "super",  paint: "#c1121f", price: 1399, deposit: 5000, hp: "710 HP", zero60: "2.8s", top: "211 mph", seats: 2, hot: true },
  { id: "720s",      brand: "mclaren",     name: "McLaren 720S",            cat: "Supercar", body: "super",  paint: "#d9dde3", price: 1299, deposit: 5000, hp: "710 HP", zero60: "2.7s", top: "212 mph", seats: 2 },
  { id: "cullinan",  brand: "rolls-royce", name: "Rolls-Royce Cullinan",    cat: "Ultra-Luxury SUV", body: "suv", paint: "#0d0e12", price: 1499, deposit: 5000, hp: "563 HP", zero60: "4.9s", top: "155 mph", seats: 5, hot: true },
  { id: "ghost",     brand: "rolls-royce", name: "Rolls-Royce Ghost",       cat: "Ultra-Luxury Sedan", body: "sedan", paint: "#e8eaee", price: 1399, deposit: 5000, hp: "563 HP", zero60: "4.6s", top: "155 mph", seats: 5 },
  { id: "bentayga",  brand: "bentley",     name: "Bentley Bentayga",        cat: "Luxury SUV", body: "suv",  paint: "#101312", price: 1099, deposit: 3000, hp: "542 HP", zero60: "4.4s", top: "180 mph", seats: 5 },
  { id: "g63",       brand: "mercedes",    name: "Mercedes-AMG G63",        cat: "Luxury SUV", body: "suv",  paint: "#0c0c0e", price: 899,  deposit: 2500, hp: "577 HP", zero60: "4.5s", top: "137 mph", seats: 5, hot: true },
  { id: "s580",      brand: "mercedes",    name: "Mercedes-Benz S580",      cat: "Executive Sedan", body: "sedan", paint: "#191b1f", price: 599, deposit: 1500, hp: "496 HP", zero60: "4.4s", top: "130 mph", seats: 5 },
  { id: "m8",        brand: "bmw",         name: "BMW M8 Competition",      cat: "Grand Tourer", body: "sedan", paint: "#0f1116", price: 649, deposit: 1500, hp: "617 HP", zero60: "3.0s", top: "190 mph", seats: 4 },
  { id: "r8",        brand: "audi",        name: "Audi R8 V10 Performance", cat: "Supercar", body: "super",  paint: "#2b2e33", price: 849,  deposit: 2500, hp: "602 HP", zero60: "3.1s", top: "205 mph", seats: 2 },
  { id: "911turbo",  brand: "porsche",     name: "Porsche 911 Turbo S",     cat: "Supercar", body: "super",  paint: "#c9ced5", price: 999,  deposit: 2500, hp: "640 HP", zero60: "2.6s", top: "205 mph", seats: 4 },
  { id: "autobio",   brand: "range-rover", name: "Range Rover Autobiography", cat: "Luxury SUV", body: "suv", paint: "#111413", price: 749, deposit: 2000, hp: "523 HP", zero60: "4.4s", top: "155 mph", seats: 5 },
  { id: "c8",        brand: "corvette",    name: "Corvette C8 Stingray",    cat: "Sports Car", body: "super", paint: "#ff8c1a", price: 499, deposit: 1000, hp: "495 HP", zero60: "2.9s", top: "194 mph", seats: 2 }
];

/* ---------- services ---------- */
const SERVICES = [
  {
    id: "chauffeur", name: "Chauffeur Services", art: chauffeurArt,
    desc: "Professional, discreet drivers in blacked-out luxury vehicles. Airport transfers, events, nights out — door to door.",
    priceLabel: "from $150 / hour",
    price: 150, unit: "hour",
    specs: [["24/7", "Availability"], ["Pro", "Drivers"], ["Black", "Fleet"], ["VIP", "Discretion"]],
    notes: ["Licensed & insured professional chauffeurs", "Airport meet & greet included", "Hourly, daily and event packages", "Complimentary water & phone chargers"]
  },
  {
    id: "villas", name: "Villa Services", art: villaArt,
    desc: "Hand-picked waterfront and estate villas. Private pools, city views, full concierge stocking before you arrive.",
    priceLabel: "from $1,500 / night",
    price: 1500, unit: "night",
    specs: [["5–10", "Bedrooms"], ["Pool", "Private"], ["Chef", "On Request"], ["24/7", "Concierge"]],
    notes: ["Waterfront & gated estate options", "Pre-arrival fridge stocking available", "Housekeeping included", "Pair with a car for bundle pricing"]
  },
  {
    id: "yachts", name: "Yacht Charters", art: yachtArt,
    desc: "Day charters and sunset cruises on crewed luxury yachts. Captain, fuel and water toys arranged for you.",
    priceLabel: "from $2,500 / day",
    price: 2500, unit: "day",
    specs: [["40–120", "Feet"], ["Crew", "Included"], ["Toys", "Water"], ["BYOB", "Friendly"]],
    notes: ["Captain & crew included", "Jet skis & floats on request", "Catering packages available", "Marina pickup or private dock"]
  }
];
