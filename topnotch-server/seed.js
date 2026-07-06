/* One-time seeding: team users (one per role), partner portal users,
   partner companies and inventory. Passwords come from env or are
   generated randomly and printed ONCE to the console — never stored
   in code or in any front-end file. */
const crypto = require("node:crypto");
const { db } = require("./lib/db");
const { hashPassword } = require("./lib/auth");

function ensureUser(email, name, role, partnerId, envVar) {
  const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(email);
  if (existing) return null;
  const pw = process.env[envVar] || crypto.randomBytes(9).toString("base64url");
  const { salt, hash } = hashPassword(pw);
  db.prepare("INSERT INTO users (email, name, role, partner_id, pass_hash, salt, must_reset) VALUES (?,?,?,?,?,?,?)")
    .run(email, name, role, partnerId, hash, salt, process.env[envVar] ? 0 : 1);
  return { email, role, pw, generated: !process.env[envVar] };
}

const PARTNERS = [
  { partner_id: "P-001", company: "Prestige Auto Group", contact: "Marco D.", phone: "(305) 555-0101", email: "fleet@prestigeauto.example", market: "Miami", payout_method: "Zelle weekly", status: "Approved", notes: "Fast confirmations. Delivery within Dade only." },
  { partner_id: "P-002", company: "Velocity Exotics", contact: "Sasha K.", phone: "(954) 555-0144", email: "book@velocityexotics.example", market: "Miami", payout_method: "Wire on return", status: "Approved", notes: "Best Lambo/Ferrari stock. 48h notice preferred." },
  { partner_id: "P-003", company: "Crown Luxury Fleet", contact: "Andre B.", phone: "(786) 555-0177", email: "ops@crownluxury.example", market: "Miami", payout_method: "Zelle per booking", status: "Approved", notes: "Rolls/Bentley specialists. FBO capable." }
];

const V = (vehicle_id, fleet_id, partner_id, provider, year, make, model, trim, color, daily, providerRate, deposit, mileageFee, areas, extra) => ({
  vehicle_id, fleet_id, partner_id, market: "Miami", year, make, model, trim, color,
  daily_rate: daily, weekly_rate: daily * 6, monthly_rate: daily * 22,
  provider_rate: providerRate, customer_price: daily, provider_payout: providerRate, profit: daily - providerRate,
  deposit, min_days: 1, mileage_included: 100, mileage_fee: mileageFee,
  delivery_areas: areas, delivery_fee: 150, min_age: 25,
  license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, Zelle, wire",
  status: "available", booked_dates: "[]", last_verified: "2026-07-03", ...extra
});

const VEHICLES = [
  V("V-1001", "huracan", "P-002", "Velocity Exotics", 2023, "Lamborghini", "Huracán EVO", "RWD", "Arancio (Orange)", 1199, 850, 3000, 5, "Dade, Broward, MIA/FLL", { notes: "Front lift, ceramic tint." }),
  V("V-1002", "huracan", "P-001", "Prestige Auto Group", 2022, "Lamborghini", "Huracán EVO", "Spyder", "Nero (Black)", 1249, 900, 3000, 5, "Dade only", { booked_dates: '["2026-07-11→2026-07-13"]' }),
  V("V-1003", "urus", "P-002", "Velocity Exotics", 2023, "Lamborghini", "Urus", "S", "Giallo (Yellow)", 1099, 800, 3000, 5, "Dade, Broward, Palm Beach", {}),
  V("V-1004", "f8", "P-002", "Velocity Exotics", 2022, "Ferrari", "F8 Tributo", "Base", "Rosso Corsa", 1399, 1000, 5000, 7.5, "Dade, Broward", { status: "booked", booked_dates: '["2026-07-02→2026-07-09"]', notes: "On rent until 07/09." }),
  V("V-1005", "cullinan", "P-003", "Crown Luxury Fleet", 2023, "Rolls-Royce", "Cullinan", "Black Badge", "Black", 1499, 1100, 5000, 7.5, "Dade, Broward, FBO", { min_age: 27, delivery_fee: 0, notes: "Starlight headliner." }),
  V("V-1006", "g63", "P-001", "Prestige Auto Group", 2023, "Mercedes-AMG", "G63", "AMG", "Matte Black", 899, 650, 2500, 5, "Dade, Broward", {}),
  V("V-1007", "g63", "P-003", "Crown Luxury Fleet", 2022, "Mercedes-AMG", "G63", "AMG", "White", 949, 700, 2500, 5, "Dade, Broward, Palm Beach", { last_verified: "2026-06-28" }),
  V("V-1008", "911turbo", "P-001", "Prestige Auto Group", 2023, "Porsche", "911 Turbo S", "Turbo S", "GT Silver", 999, 720, 2500, 5, "Dade", {})
];

function seed() {
  const created = [];
  const users = [
    ["admin@topnotchrentalz.com", "Admin", "admin", null, "TN_ADMIN_PASSWORD"],
    ["sales@topnotchrentalz.com", "Sales Team", "sales", null, "TN_SALES_PASSWORD"],
    ["ops@topnotchrentalz.com", "Operations", "ops", null, "TN_OPS_PASSWORD"],
    ["partnerships@topnotchrentalz.com", "Partnerships", "partnerships", null, "TN_PARTNERSHIPS_PASSWORD"],
    ["cx@topnotchrentalz.com", "Client Experience", "cx", null, "TN_CX_PASSWORD"],
    ["portal@prestigeauto.example", "Prestige Auto Group", "partner", "P-001", "TN_PARTNER1_PASSWORD"],
    ["portal@velocityexotics.example", "Velocity Exotics", "partner", "P-002", "TN_PARTNER2_PASSWORD"],
    ["portal@crownluxury.example", "Crown Luxury Fleet", "partner", "P-003", "TN_PARTNER3_PASSWORD"]
  ];
  for (const u of users) {
    const r = ensureUser(...u);
    if (r) created.push(r);
  }

  const pIns = db.prepare(`INSERT OR IGNORE INTO partners (partner_id, company, contact, phone, email, market, payout_method, status, notes)
    VALUES (:partner_id, :company, :contact, :phone, :email, :market, :payout_method, :status, :notes)`);
  PARTNERS.forEach(p => pIns.run(p));

  const cols = Object.keys(VEHICLES[0]);
  const vIns = db.prepare(`INSERT OR IGNORE INTO vehicles (${cols.join(",")}) VALUES (${cols.map(c => ":" + c).join(",")})`);
  VEHICLES.forEach(v => vIns.run(v));

  if (created.length) {
    console.log("\n=== First-run accounts (passwords shown ONCE — change on first login) ===");
    created.forEach(c => console.log(`  ${c.role.padEnd(13)} ${c.email.padEnd(36)} ${c.generated ? "temp password: " + c.pw : "(password from env)"}`));
    console.log("===========================================================================\n");
  }
}

module.exports = { seed };
