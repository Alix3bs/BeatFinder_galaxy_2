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
  status: "available", booked_dates: "[]", last_verified: new Date().toISOString().slice(0, 10), ...extra
});

const VEHICLES = [
  V("V-1001", "huracan", "P-002", "Velocity Exotics", 2023, "Lamborghini", "Huracán EVO", "RWD", "Arancio (Orange)", 1199, 850, 3000, 5, "Dade, Broward, MIA/FLL", { notes: "Front lift, ceramic tint." }),
  V("V-1002", "huracan", "P-001", "Prestige Auto Group", 2022, "Lamborghini", "Huracán EVO", "Spyder", "Nero (Black)", 1249, 900, 3000, 5, "Dade only", { booked_dates: '["2026-07-11→2026-07-13"]' }),
  V("V-1003", "urus", "P-002", "Velocity Exotics", 2023, "Lamborghini", "Urus", "S", "Giallo (Yellow)", 1099, 800, 3000, 5, "Dade, Broward, Palm Beach", {}),
  V("V-1004", "f8", "P-002", "Velocity Exotics", 2022, "Ferrari", "F8 Tributo", "Base", "Rosso Corsa", 1399, 1000, 5000, 7.5, "Dade, Broward", { status: "booked", booked_dates: '["2026-07-02→2026-07-09"]', notes: "On rent until 07/09." }),
  V("V-1005", "cullinan", "P-003", "Crown Luxury Fleet", 2023, "Rolls-Royce", "Cullinan", "Black Badge", "Black", 1499, 1100, 5000, 7.5, "Dade, Broward, FBO", { min_age: 27, delivery_fee: 0, notes: "Starlight headliner." }),
  V("V-1006", "g63", "P-001", "Prestige Auto Group", 2023, "Mercedes-AMG", "G63", "AMG", "Matte Black", 899, 650, 2500, 5, "Dade, Broward", {}),
  V("V-1007", "g63", "P-003", "Crown Luxury Fleet", 2022, "Mercedes-AMG", "G63", "AMG", "White", 949, 700, 2500, 5, "Dade, Broward, Palm Beach", { last_verified: new Date(Date.now() - 9 * 864e5).toISOString().slice(0, 10) }),
  V("V-1008", "911turbo", "P-001", "Prestige Auto Group", 2023, "Porsche", "911 Turbo S", "Turbo S", "GT Silver", 999, 720, 2500, 5, "Dade", {})
];

/* real company settings — editable later in Admin → Settings */
const DEFAULT_SETTINGS = {
  business_name: "TopNotchRentalz",
  city: "Miami, Florida",
  address: "Miami, FL",
  phone: "(786) 634-1150",
  whatsapp: "17866341150",
  email: "bookings@topnotchrentalz.com",
  instagram: "@topnotchrentalz",
  hours: "Mon – Sun · 9:00 AM – 9:00 PM",
  policy_version: "2026-07-06",
  verify_days: "7",
  doc_retention_days: "90",
  /* Phase 4.1 — payments & holds (all editable in Admin → Settings) */
  payment_provider: "lumino",        // lumino | stripe | mock (mock auto-selected when no credentials)
  stripe_enabled: "0",
  hold_minutes: "20",
  quote_expiry_days: "3",
  payment_mode: "full",              // full | partial
  reservation_amount: "500",
  deposit_handling: "collected",     // collected | external | authorization (authorization only if provider supports it)
  methods_card: "1", methods_ach: "0", methods_bnpl: "0", methods_link: "1", methods_invoice: "1",
  methods_bank: "1", methods_zelle: "1", methods_cash: "1", methods_other: "0",
  tax_processing_pct: "3"            // shown to customer as taxes/processing estimate
};

function seed() {
  const isProd = (process.env.TN_ENV || "staging") === "production";
  const created = [];

  /* staff accounts exist in every environment */
  const users = [
    ["admin@topnotchrentalz.com", "Admin", "admin", null, "TN_ADMIN_PASSWORD"],
    ["sales@topnotchrentalz.com", "Sales Team", "sales", null, "TN_SALES_PASSWORD"],
    ["ops@topnotchrentalz.com", "Operations", "ops", null, "TN_OPS_PASSWORD"],
    ["partnerships@topnotchrentalz.com", "Partnerships", "partnerships", null, "TN_PARTNERSHIPS_PASSWORD"],
    ["cx@topnotchrentalz.com", "Client Experience", "cx", null, "TN_CX_PASSWORD"]
  ];
  /* demo partner portal users: staging/dev ONLY */
  if (!isProd) users.push(
    ["portal@prestigeauto.example", "Prestige Auto Group", "partner", "P-001", "TN_PARTNER1_PASSWORD"],
    ["portal@velocityexotics.example", "Velocity Exotics", "partner", "P-002", "TN_PARTNER2_PASSWORD"],
    ["portal@crownluxury.example", "Crown Luxury Fleet", "partner", "P-003", "TN_PARTNER3_PASSWORD"]
  );
  for (const u of users) {
    const r = ensureUser(...u);
    if (r) created.push(r);
  }

  /* company settings (INSERT OR IGNORE keeps admin edits) */
  const sIns = db.prepare("INSERT OR IGNORE INTO settings (key, value) VALUES (?,?)");
  Object.entries(DEFAULT_SETTINGS).forEach(([k, v]) => sIns.run(k, v));

  if (isProd) {
    /* production: NO demo partners, vehicles or transactions.
       First real inventory source: LUXX Miami — created as an
       onboarding lead; nothing publishes until Partnerships flips
       it to Active and each vehicle passes the publish checklist. */
    db.prepare(`INSERT OR IGNORE INTO partners (partner_id, company, contact, phone, email, market,
        payout_method, status, notes, onboarding_status, deal_model)
      VALUES ('P-LUXX', 'LUXX Miami', '', '', '', 'Miami', '', 'Pending',
        'First real inventory source. Import their workbook via Admin → Import Fleet; every price defaults to awaiting-confirmation until the partnerships team confirms broker rates, deposits, mileage, insurance, delivery areas, photos and contacts.',
        'Inventory pending', 'broker-markup')`).run();
  } else {
    const pIns = db.prepare(`INSERT OR IGNORE INTO partners (partner_id, company, contact, phone, email, market, payout_method, status, notes, onboarding_status)
      VALUES (:partner_id, :company, :contact, :phone, :email, :market, :payout_method, :status, :notes, 'Active')`);
    PARTNERS.forEach(p => pIns.run(p));
    const cols = Object.keys(VEHICLES[0]);
    const vIns = db.prepare(`INSERT OR IGNORE INTO vehicles (${cols.join(",")}, rate_label, photos_approved, price_approved, requirements_complete)
      VALUES (${cols.map(c => ":" + c).join(",")}, 'confirmed-broker', 1, 1, 1)`);
    VEHICLES.forEach(v => vIns.run(v));
  }

  if (created.length) {
    console.log(`\n=== First-run accounts [${isProd ? "PRODUCTION" : "staging"}] (passwords shown ONCE) ===`);
    created.forEach(c => console.log(`  ${c.role.padEnd(13)} ${c.email.padEnd(36)} ${c.generated ? "temp password: " + c.pw : "(password from env)"}`));
    console.log("===========================================================================\n");
  }
}

module.exports = { seed };
