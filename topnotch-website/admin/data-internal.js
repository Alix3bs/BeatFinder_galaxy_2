/* ============================================================
   TopNotchRentalz — INTERNAL seed data (admin only)
   Provider rates, payouts and profit live ONLY here and in the
   admin's browser storage. Never import this file from any
   customer-facing page.

   SECURITY NOTE: this is a client-side gate suitable for a
   pilot. Before real partner volume, move the admin behind a
   real backend login (see README "Going to production").
   ============================================================ */

const ADMIN_PASS = "TOPNOTCH2026";   // change this before sharing the link

/* ---------- partner companies ---------- */
const SEED_PARTNERS = [
  { partnerId: "P-001", company: "Prestige Auto Group",  contact: "Marco D.",  phone: "(305) 555-0101", email: "fleet@prestigeauto.example", market: "Miami",  payoutMethod: "Zelle weekly",  status: "Approved", notes: "Fast confirmations. Delivery within Dade only." },
  { partnerId: "P-002", company: "Velocity Exotics",     contact: "Sasha K.",  phone: "(954) 555-0144", email: "book@velocityexotics.example", market: "Miami", payoutMethod: "Wire on return", status: "Approved", notes: "Best Lambo/Ferrari stock. 48h notice preferred." },
  { partnerId: "P-003", company: "Crown Luxury Fleet",   contact: "Andre B.",  phone: "(786) 555-0177", email: "ops@crownluxury.example",  market: "Miami",  payoutMethod: "Zelle per booking", status: "Approved", notes: "Rolls/Bentley specialists. FBO capable." }
];

/* ---------- partner inventory (full schema) ----------
   fleetId links a row to the public site's FLEET entry so
   availability changes flow to the customer site. */
const SEED_INVENTORY = [
  { vehicleId: "V-1001", fleetId: "huracan",  partnerId: "P-002", provider: "Velocity Exotics", market: "Miami", year: 2023, make: "Lamborghini", model: "Huracán EVO", trim: "RWD", color: "Arancio (Orange)", photos: "",
    dailyRate: 1199, weeklyRate: 7194, monthlyRate: 26378, providerRate: 850, customerPrice: 1199, providerPayout: 850, profit: 349,
    deposit: 3000, minDays: 1, mileageIncluded: 100, mileageFee: 5, deliveryAreas: "Dade, Broward, MIA/FLL", deliveryFee: 150,
    minAge: 25, license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, Zelle, wire",
    status: "available", bookedDates: "", lastVerified: "2026-07-03", providerContact: "Sasha K. (954) 555-0144", notes: "Front lift, ceramic tint." },
  { vehicleId: "V-1002", fleetId: "huracan",  partnerId: "P-001", provider: "Prestige Auto Group", market: "Miami", year: 2022, make: "Lamborghini", model: "Huracán EVO", trim: "Spyder", color: "Nero (Black)", photos: "",
    dailyRate: 1249, weeklyRate: 7494, monthlyRate: 27478, providerRate: 900, customerPrice: 1249, providerPayout: 900, profit: 349,
    deposit: 3000, minDays: 1, mileageIncluded: 100, mileageFee: 5, deliveryAreas: "Dade only", deliveryFee: 150,
    minAge: 25, license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, Zelle",
    status: "available", bookedDates: "2026-07-11→2026-07-13", lastVerified: "2026-07-01", providerContact: "Marco D. (305) 555-0101", notes: "Spyder — soft top." },
  { vehicleId: "V-1003", fleetId: "urus",     partnerId: "P-002", provider: "Velocity Exotics", market: "Miami", year: 2023, make: "Lamborghini", model: "Urus", trim: "S", color: "Giallo (Yellow)", photos: "",
    dailyRate: 1099, weeklyRate: 6594, monthlyRate: 24178, providerRate: 800, customerPrice: 1099, providerPayout: 800, profit: 299,
    deposit: 3000, minDays: 1, mileageIncluded: 100, mileageFee: 5, deliveryAreas: "Dade, Broward, Palm Beach", deliveryFee: 150,
    minAge: 25, license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, Zelle, wire",
    status: "available", bookedDates: "", lastVerified: "2026-07-04", providerContact: "Sasha K. (954) 555-0144", notes: "" },
  { vehicleId: "V-1004", fleetId: "f8",       partnerId: "P-002", provider: "Velocity Exotics", market: "Miami", year: 2022, make: "Ferrari", model: "F8 Tributo", trim: "Base", color: "Rosso Corsa", photos: "",
    dailyRate: 1399, weeklyRate: 8394, monthlyRate: 30778, providerRate: 1000, customerPrice: 1399, providerPayout: 1000, profit: 399,
    deposit: 5000, minDays: 1, mileageIncluded: 100, mileageFee: 7.5, deliveryAreas: "Dade, Broward", deliveryFee: 150,
    minAge: 25, license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, wire",
    status: "booked", bookedDates: "2026-07-02→2026-07-09", lastVerified: "2026-07-02", providerContact: "Sasha K. (954) 555-0144", notes: "On rent until 07/09." },
  { vehicleId: "V-1005", fleetId: "cullinan", partnerId: "P-003", provider: "Crown Luxury Fleet", market: "Miami", year: 2023, make: "Rolls-Royce", model: "Cullinan", trim: "Black Badge", color: "Black", photos: "",
    dailyRate: 1499, weeklyRate: 8994, monthlyRate: 32978, providerRate: 1100, customerPrice: 1499, providerPayout: 1100, profit: 399,
    deposit: 5000, minDays: 1, mileageIncluded: 100, mileageFee: 7.5, deliveryAreas: "Dade, Broward, FBO", deliveryFee: 0,
    minAge: 27, license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, wire",
    status: "available", bookedDates: "", lastVerified: "2026-07-04", providerContact: "Andre B. (786) 555-0177", notes: "Starlight headliner." },
  { vehicleId: "V-1006", fleetId: "g63",      partnerId: "P-001", provider: "Prestige Auto Group", market: "Miami", year: 2023, make: "Mercedes-AMG", model: "G63", trim: "AMG", color: "Matte Black", photos: "",
    dailyRate: 899, weeklyRate: 5394, monthlyRate: 19778, providerRate: 650, customerPrice: 899, providerPayout: 650, profit: 249,
    deposit: 2500, minDays: 1, mileageIncluded: 100, mileageFee: 5, deliveryAreas: "Dade, Broward", deliveryFee: 150,
    minAge: 25, license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, Zelle",
    status: "available", bookedDates: "", lastVerified: "2026-07-03", providerContact: "Marco D. (305) 555-0101", notes: "" },
  { vehicleId: "V-1007", fleetId: "g63",      partnerId: "P-003", provider: "Crown Luxury Fleet", market: "Miami", year: 2022, make: "Mercedes-AMG", model: "G63", trim: "AMG", color: "White", photos: "",
    dailyRate: 949, weeklyRate: 5694, monthlyRate: 20878, providerRate: 700, customerPrice: 949, providerPayout: 700, profit: 249,
    deposit: 2500, minDays: 1, mileageIncluded: 100, mileageFee: 5, deliveryAreas: "Dade, Broward, Palm Beach", deliveryFee: 150,
    minAge: 25, license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, Zelle, wire",
    status: "available", bookedDates: "", lastVerified: "2026-06-28", providerContact: "Andre B. (786) 555-0177", notes: "Verify — last check 6+ days ago." },
  { vehicleId: "V-1008", fleetId: "911turbo", partnerId: "P-001", provider: "Prestige Auto Group", market: "Miami", year: 2023, make: "Porsche", model: "911 Turbo S", trim: "Turbo S", color: "GT Silver", photos: "",
    dailyRate: 999, weeklyRate: 5994, monthlyRate: 21978, providerRate: 720, customerPrice: 999, providerPayout: 720, profit: 279,
    deposit: 2500, minDays: 1, mileageIncluded: 100, mileageFee: 5, deliveryAreas: "Dade", deliveryFee: 150,
    minAge: 25, license: "Valid US/Intl license", insurance: "Full coverage transferable", payments: "Card, wire",
    status: "available", bookedDates: "", lastVerified: "2026-07-04", providerContact: "Marco D. (305) 555-0101", notes: "" }
];
