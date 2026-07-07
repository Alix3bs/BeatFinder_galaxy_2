/* ============================================================
   TopNotchRentalz API + static server (zero dependencies)
   Node 22+ (node:sqlite). Live DB = SQLite; Excel = synced report.
   Secrets live in environment variables only — see .env.example.
   ============================================================ */
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

/* tiny .env loader (no dependency) */
const envFile = path.join(__dirname, ".env");
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}

const { db, DATA_DIR } = require("./lib/db");
const auth = require("./lib/auth");
const U = require("./lib/util");
const backup = require("./lib/backup");
const stripe = require("./lib/stripe");
const emails = require("./lib/emails");
const { seed } = require("./seed");
seed();

const SETTING = k => db.prepare("SELECT value FROM settings WHERE key=?").get(k)?.value || "";
const allSettings = () => Object.fromEntries(db.prepare("SELECT key, value FROM settings").all().map(r => [r.key, r.value]));

/* server-held signing key for temporary file links (generated once) */
if (!SETTING("file_signing_key")) {
  db.prepare("INSERT INTO settings (key, value) VALUES ('file_signing_key', ?)").run(crypto.randomBytes(32).toString("hex"));
}
const fileSig = (id, exp) =>
  crypto.createHmac("sha256", SETTING("file_signing_key")).update(`${id}.${exp}`).digest("hex");

const PORT = Number(process.env.PORT || 8902);
const SITE_DIR = path.resolve(__dirname, "..", "topnotch-website");
const UPLOAD_DIR = path.join(DATA_DIR, "uploads");
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

/* ============================================================
   STATUS MACHINE (Priority 8 order — server-enforced)
   ============================================================ */
const FLOW = [
  "Request submitted", "Under review", "Availability being confirmed",
  "Provider confirmed", "Approved", "Quote sent", "Quote accepted",
  "Payment required", "Booking confirmed", "Completed"
];
const TERMINAL = ["Declined", "Cancelled", "Completed"];
const CUSTOMER_LABEL = s => ({
  "Request submitted": "Request submitted",
  "Under review": "Availability being confirmed",
  "Availability being confirmed": "Availability being confirmed",
  "Provider confirmed": "Availability being confirmed",
  "Approved": "Approved",
  "Quote sent": "Approved",
  "Quote accepted": "Approved",
  "Payment required": "Payment required",
  "Booking confirmed": "Booking confirmed",
  "Completed": "Booking confirmed"
}[s] || s);

/* ---------- date overlap guard ---------- */
function rangesOverlap(aS, aE, bS, bE) {
  return Date.parse(aS) < Date.parse(bE) && Date.parse(bS) < Date.parse(aE);
}
function vehicleConflicts(vehicleId, start, end, ignoreRequestId) {
  const v = db.prepare("SELECT booked_dates FROM vehicles WHERE vehicle_id = ?").get(vehicleId);
  if (!v) return ["vehicle not found"];
  const conflicts = [];
  for (const r of JSON.parse(v.booked_dates || "[]")) {
    const [s, e] = r.split("→");
    if (s && e && rangesOverlap(start, end, s, e)) conflicts.push(r);
  }
  const rows = db.prepare(`SELECT request_id, start_date, end_date FROM requests
    WHERE assigned_vehicle_id = ? AND status IN ('Provider confirmed','Approved','Quote sent','Quote accepted','Payment required','Booking confirmed')
    AND request_id != ?`).all(vehicleId, ignoreRequestId || "");
  for (const r of rows) {
    if (rangesOverlap(start, end, r.start_date.slice(0, 10), r.end_date.slice(0, 10)))
      conflicts.push(`request ${r.request_id}`);
  }
  return conflicts;
}

/* ---------- field filters (what each audience may see) ---------- */
const VEHICLE_PUBLIC = ["vehicle_id", "fleet_id", "year", "make", "model", "trim", "color", "market",
  "daily_rate", "weekly_rate", "monthly_rate", "deposit", "min_days", "mileage_included", "mileage_fee",
  "delivery_areas", "delivery_fee", "min_age", "license", "insurance", "payments", "status"];
const VEHICLE_PORTAL = [...VEHICLE_PUBLIC, "booked_dates", "provider_rate", "provider_payout", "last_verified", "notes", "photos", "vin"];
const pick = (obj, keys) => Object.fromEntries(keys.filter(k => k in obj).map(k => [k, obj[k]]));

/* ============================================================
   ROUTER
   ============================================================ */
const routes = [];
function route(method, pattern, handler, opts = {}) {
  routes.push({ method, re: new RegExp("^" + pattern.replace(/:(\w+)/g, "(?<$1>[\\w.\\-]+)") + "$"), handler, opts });
}
const json = (res, code, obj) => {
  res.writeHead(code, { "Content-Type": "application/json", "Cache-Control": "no-store" });
  res.end(JSON.stringify(obj));
};
const bad = (res, msg, code = 400) => json(res, code, { error: msg });

/* ============================================================
   PUBLIC ROUTES
   ============================================================ */
/* publishing controls: a unit is publicly visible only when its
   partner is Active, its checklist is complete, and availability was
   verified within the configurable window. Stale verification demotes
   it to "on-request" (no instant quoting) and alerts partnerships. */
function publishableUnits() {
  const verifyDays = Number(SETTING("verify_days") || 7);
  const activePartners = new Set(db.prepare(
    "SELECT partner_id FROM partners WHERE onboarding_status='Active'").all().map(p => p.partner_id));
  return db.prepare("SELECT * FROM vehicles WHERE fleet_id IS NOT NULL").all().map(v => {
    const partnerOk = activePartners.has(v.partner_id);
    const checklistOk = v.photos_approved && v.price_approved && v.requirements_complete &&
      ["confirmed-broker", "customer-approved"].includes(v.rate_label);
    const fresh = v.last_verified && (Date.now() - Date.parse(v.last_verified)) / 864e5 <= verifyDays;
    let pub = null;
    if (partnerOk && checklistOk && ["available", "booked", "maintenance"].includes(v.status)) {
      pub = v.status === "available" ? (fresh ? "available" : "on-request") : v.status;
    }
    return { ...v, publicStatus: pub, stale: partnerOk && checklistOk && v.status === "available" && !fresh };
  });
}

route("GET", "/api/public/availability", (req, res) => {
  const map = {};
  for (const v of publishableUnits()) {
    if (!v.publicStatus) continue;
    const rank = { available: 3, "on-request": 2, booked: 1, maintenance: 0 };
    if (!(v.fleet_id in map) || rank[v.publicStatus] > rank[map[v.fleet_id]]) map[v.fleet_id] = v.publicStatus;
  }
  json(res, 200, map);
});

route("GET", "/api/public/settings", (req, res) => {
  const s = allSettings();
  json(res, 200, {
    businessName: s.business_name, city: s.city, address: s.address, phone: s.phone,
    whatsapp: s.whatsapp, email: s.email, instagram: s.instagram, hours: s.hours,
    policyVersion: s.policy_version
  });
});

route("POST", "/api/public/requests", async (req, res) => {
  if (!U.rateLimit(req.ip, "requests", 5, 10 * 60e3)) return bad(res, "Too many requests — please try again shortly.", 429);
  const b = req.body || {};
  if (b.website) return json(res, 200, { ok: true, requestId: "TN-OK" }); // honeypot: swallow silently

  const name = U.strip(b.customerName), phone = U.strip(b.phone), email = U.strip(b.email);
  const vehicle = U.strip(b.vehicleRequested);
  const start = U.strip(b.startDate), end = U.strip(b.endDate);
  if (!name || !isNaN(name) || name.length < 2) return bad(res, "Valid name required");
  if (!U.isPhone(phone)) return bad(res, "Valid phone required");
  if (!U.isEmail(email)) return bad(res, "Valid email required");
  if (!vehicle) return bad(res, "Vehicle required");
  const sd = start.slice(0, 10), ed = end.slice(0, 10);
  if (!U.isDate(sd) || !U.isDate(ed) || Date.parse(ed) <= Date.parse(sd)) return bad(res, "Valid date range required");

  /* legal consent — every box must be explicitly ticked (never pre-checked) */
  const CONSENT_ITEMS = ["terms", "privacy", "cancellation", "deposit", "vehicleRules", "communication", "documents"];
  const c = b.consents || {};
  const missingConsent = CONSENT_ITEMS.filter(k => c[k] !== true);
  if (missingConsent.length) return bad(res, "Please accept all required policies before submitting (" + missingConsent.join(", ") + ")");

  /* duplicate detection: same phone/email + vehicle + overlapping dates, still open */
  const dupe = db.prepare(`SELECT request_id, start_date, end_date FROM requests
      WHERE vehicle_requested = ? AND (phone = ? OR email = ?)
      AND status NOT IN ('Declined','Cancelled','Completed')`).all(vehicle, phone, email)
    .find(r => rangesOverlap(sd, ed, r.start_date.slice(0, 10), r.end_date.slice(0, 10)));

  const id = U.rid("TN");
  db.prepare(`INSERT INTO requests (request_id, customer_name, phone, email, vehicle_requested, backup_vehicle,
      start_date, end_date, budget, driver_age, license_status, insurance_status, option, delivery_location,
      return_location, deposit_readiness, occasion, chauffeur, fbo, addons, special_requests, quoted_day_rate,
      duplicate_of, ip)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .run(id, name, phone, email, vehicle, U.strip(b.backupVehicle), start, end,
      U.strip(b.budget), U.strip(b.driverAge), U.strip(b.licenseStatus), U.strip(b.insuranceStatus),
      U.strip(b.option), U.strip(b.deliveryLocation), U.strip(b.returnLocation), U.strip(b.depositReadiness),
      U.strip(b.occasion), U.strip(b.chauffeurNeeded), U.strip(b.fboPickup), U.stripLong(b.addons),
      U.stripLong(b.specialRequests), U.strip(b.quotedDayRate), dupe ? dupe.request_id : null, req.ip);

  db.prepare("INSERT INTO consents (request_id, ip, policy_version, consent_text, items) VALUES (?,?,?,?,?)")
    .run(id, req.ip, SETTING("policy_version"), U.stripLong(b.consentText || ""), JSON.stringify(CONSENT_ITEMS));

  const row = db.prepare("SELECT * FROM requests WHERE request_id = ?").get(id);
  U.queueSync("CustomerRequests", row);
  emails.customerEmail("REQUEST_RECEIVED", email, {
    requestId: id, firstName: name.split(" ")[0], vehicle, dates: `${start} → ${end}`,
    trackUrl: `${process.env.TN_BASE_URL || ""}/track.html?id=${id}&ph=${phone.replace(/\D/g, "").slice(-4)}`
  }).catch(() => {});
  if (!dupe) {
    await U.notify("sales", null, "NEW_REQUEST", `New request ${id} — ${vehicle}`,
      `Customer: ${name} · ${phone} · ${email}\nVehicle: ${vehicle} (backup: ${row.backup_vehicle || "none"})\nDates: ${start} → ${end}\nBudget: ${row.budget}\nDelivery: ${row.delivery_location}\nAge: ${row.driver_age} · License: ${row.license_status} · Insurance: ${row.insurance_status}\nDeposit: ${row.deposit_readiness}\nSpecial: ${row.special_requests}`);
  } else {
    await U.notify("sales", null, "DUPLICATE_REQUEST", `Possible duplicate ${id} (of ${dupe.request_id})`,
      `${name} re-submitted ${vehicle} for overlapping dates.`);
  }
  json(res, 200, { ok: true, requestId: id, duplicate: !!dupe, duplicateOf: dupe?.request_id });
});

route("GET", "/api/public/track", (req, res) => {
  if (!U.rateLimit(req.ip, "track", 30, 10 * 60e3)) return bad(res, "Slow down.", 429);
  const id = U.strip(req.query.id), phone = U.strip(req.query.phone).replace(/\D/g, "");
  const r = db.prepare("SELECT * FROM requests WHERE request_id = ?").get(id);
  if (!r) return bad(res, "Request not found", 404);
  const rp = (r.phone || "").replace(/\D/g, "");
  if (!phone || !rp.endsWith(phone.slice(-4))) return bad(res, "Phone verification failed", 403);
  const out = {
    requestId: r.request_id,
    status: TERMINAL.includes(r.status) && r.status !== "Completed" ? r.status : CUSTOMER_LABEL(r.status),
    vehicle: r.vehicle_requested, startDate: r.start_date, endDate: r.end_date,
    option: r.option, deliveryLocation: r.option === "pickup" ? "Showroom" : r.delivery_location
  };
  if (["Quote sent", "Quote accepted", "Payment required", "Booking confirmed", "Completed"].includes(r.status)) {
    out.quote = { amount: r.quote_amount, expires: r.quote_expires, accepted: !!r.quote_accepted_at, internalStatus: r.status === "Quote sent" ? "awaiting-acceptance" : "accepted" };
  }
  json(res, 200, out);
});

route("POST", "/api/public/quote/accept", async (req, res) => {
  if (!U.rateLimit(req.ip, "quote", 10, 10 * 60e3)) return bad(res, "Slow down.", 429);
  const id = U.strip(req.body.requestId), phone = U.strip(req.body.phone).replace(/\D/g, "");
  const r = db.prepare("SELECT * FROM requests WHERE request_id = ?").get(id);
  if (!r || !(r.phone || "").replace(/\D/g, "").endsWith(phone.slice(-4))) return bad(res, "Not found", 404);
  if (r.status !== "Quote sent") return bad(res, "No open quote on this request");
  if (r.quote_expires && Date.parse(r.quote_expires) < Date.now()) return bad(res, "This quote has expired — contact us for a refresh.");
  db.prepare("UPDATE requests SET status='Quote accepted', quote_accepted_at=datetime('now') WHERE request_id=?").run(id);
  U.audit(null, "quote.accepted", "request", id, "status", "Quote sent", "Quote accepted", id);
  await U.notify("sales", null, "QUOTE_ACCEPTED", `Quote accepted — ${id}`, `${r.customer_name} accepted $${r.quote_amount}. Issue the payment/deposit link.`);
  emails.customerEmail("QUOTE_ACCEPTED", r.email, {
    requestId: id, firstName: r.customer_name.split(" ")[0], vehicle: r.vehicle_requested,
    amount: r.quote_amount,
    trackUrl: `${process.env.TN_BASE_URL || ""}/track.html?id=${id}&ph=${(r.phone || "").replace(/\D/g, "").slice(-4)}`
  }).catch(() => {});
  json(res, 200, { ok: true });
});

route("POST", "/api/public/partner-inquiries", async (req, res) => {
  if (!U.rateLimit(req.ip, "inq", 5, 10 * 60e3)) return bad(res, "Too many submissions.", 429);
  const b = req.body || {};
  if (b.website) return json(res, 200, { ok: true });
  const company = U.strip(b.company);
  if (!company || !U.isPhone(b.phone || "")) return bad(res, "Company and phone required");
  const id = U.rid("PR");
  db.prepare("INSERT INTO partner_inquiries (inquiry_id, company, contact, phone, email, market, fleet_size, notes) VALUES (?,?,?,?,?,?,?,?)")
    .run(id, company, U.strip(b.contact), U.strip(b.phone), U.strip(b.email), U.strip(b.market), U.strip(b.fleetSize), U.stripLong(b.notes));
  U.queueSync("PartnerInquiries", db.prepare("SELECT * FROM partner_inquiries WHERE inquiry_id=?").get(id));
  await U.notify("partnerships", null, "PARTNER_INQUIRY", `Partner inquiry — ${company}`, `${U.strip(b.contact)} · ${U.strip(b.phone)} · ${U.strip(b.market)}`);
  json(res, 200, { ok: true, inquiryId: id });
});

/* ============================================================
   AUTH
   ============================================================ */
function setSessionCookie(res, token) {
  const secure = process.env.TN_SECURE_COOKIES === "1" ? "; Secure" : "";
  res.setHeader("Set-Cookie", `tn_sess=${token}; HttpOnly; SameSite=Lax; Path=/${secure}${token ? "" : "; Max-Age=0"}`);
}

route("POST", "/api/auth/login", (req, res) => {
  if (!U.rateLimit(req.ip, "login", 10, 15 * 60e3)) return bad(res, "Too many attempts — wait 15 minutes.", 429);
  const email = U.strip(req.body.email).toLowerCase();
  const u = db.prepare("SELECT * FROM users WHERE lower(email)=? AND active=1").get(email);
  if (!u || !auth.verifyPassword(String(req.body.password || ""), u.salt, u.pass_hash)) {
    U.audit({ email, role: "?" }, "auth.login.failed", "user", email);
    return bad(res, "Invalid email or password", 401);
  }
  const token = auth.createSession(u.id);
  setSessionCookie(res, token);
  U.audit(u, "auth.login", "user", u.email);
  json(res, 200, { ok: true, user: { email: u.email, name: u.name, role: u.role, partnerId: u.partner_id, mustReset: !!u.must_reset } });
});

route("POST", "/api/auth/logout", (req, res) => {
  if (req.token) auth.destroySession(req.token);
  setSessionCookie(res, "");
  json(res, 200, { ok: true });
});

route("GET", "/api/auth/me", (req, res) => {
  if (!req.user) return bad(res, "Not signed in", 401);
  json(res, 200, { user: { email: req.user.email, name: req.user.name, role: req.user.role, partnerId: req.user.partner_id, mustReset: !!req.user.must_reset, idleMinutes: auth.INACTIVITY_MIN } });
});

route("POST", "/api/auth/change-password", (req, res) => {
  if (!req.user) return bad(res, "Not signed in", 401);
  const u = db.prepare("SELECT * FROM users WHERE id=?").get(req.user.id);
  const next = String(req.body.next || "");
  if (next.length < 10) return bad(res, "New password must be at least 10 characters");
  if (!u.must_reset && !auth.verifyPassword(String(req.body.current || ""), u.salt, u.pass_hash))
    return bad(res, "Current password incorrect", 403);
  const { salt, hash } = auth.hashPassword(next);
  db.prepare("UPDATE users SET pass_hash=?, salt=?, must_reset=0 WHERE id=?").run(hash, salt, u.id);
  U.audit(req.user, "auth.password.changed", "user", u.email);
  json(res, 200, { ok: true });
});

route("POST", "/api/auth/reset/request", async (req, res) => {
  if (!U.rateLimit(req.ip, "reset", 5, 15 * 60e3)) return bad(res, "Too many attempts", 429);
  const email = U.strip(req.body.email).toLowerCase();
  const u = db.prepare("SELECT * FROM users WHERE lower(email)=? AND active=1").get(email);
  if (u) {
    const token = auth.createResetToken(u.id);
    /* token is delivered by email only — never returned to the browser */
    await U.notify(null, null, "PASSWORD_RESET", `Password reset — ${u.email}`,
      `Reset link: ${process.env.TN_BASE_URL || "http://localhost:" + PORT}/admin/#reset=${token} (valid 1 hour)`);
    console.log(`[reset] token for ${u.email}: ${token}`);
  }
  json(res, 200, { ok: true, message: "If that account exists, a reset link has been emailed." });
});

route("POST", "/api/auth/reset/complete", (req, res) => {
  const userId = auth.consumeResetToken(String(req.body.token || ""));
  if (!userId) return bad(res, "Reset link is invalid or expired", 400);
  const next = String(req.body.password || "");
  if (next.length < 10) return bad(res, "Password must be at least 10 characters");
  const { salt, hash } = auth.hashPassword(next);
  db.prepare("UPDATE users SET pass_hash=?, salt=?, must_reset=0 WHERE id=?").run(hash, salt, userId);
  db.prepare("DELETE FROM sessions WHERE user_id=?").run(userId);
  U.audit(null, "auth.password.reset", "user", String(userId));
  json(res, 200, { ok: true });
});

/* ============================================================
   STAFF API (server-side permission checks on every route)
   ============================================================ */
const guard = perm => (req, res) => {
  if (!req.user) { bad(res, "Sign in required", 401); return false; }
  if (!auth.can(req.user, perm)) {
    U.audit(req.user, "authz.denied", "perm", perm);
    bad(res, "Your role does not allow this action", 403);
    return false;
  }
  return true;
};

/* ----- vehicles ----- */
route("GET", "/api/vehicles", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  const rows = db.prepare("SELECT * FROM vehicles ORDER BY vehicle_id").all();
  if (auth.can(req.user, "vehicles.read.full")) return json(res, 200, rows);
  if (auth.can(req.user, "vehicles.read.public"))
    return json(res, 200, rows.map(v => pick(v, [...VEHICLE_PUBLIC, "partner_id", "booked_dates", "last_verified"])));
  bad(res, "Forbidden", 403);
});

const VEHICLE_EDITABLE = ["fleet_id", "partner_id", "market", "year", "make", "model", "trim", "color", "vin",
  "daily_rate", "weekly_rate", "monthly_rate", "provider_rate", "customer_price", "provider_payout", "profit",
  "deposit", "min_days", "mileage_included", "mileage_fee", "delivery_areas", "delivery_fee",
  "min_age", "license", "insurance", "payments", "status", "booked_dates", "last_verified", "provider_contact", "notes",
  "rate_label", "photos_approved", "price_approved", "requirements_complete", "deal_model"];
const RATE_LABELS = ["public-retail", "confirmed-broker", "customer-approved", "awaiting-confirmation"];

function applyVehiclePatch(req, res, v, body, allowedFields) {
  const audited = ["daily_rate", "provider_rate", "customer_price", "provider_payout", "deposit", "status", "booked_dates"];
  for (const k of allowedFields) {
    if (!(k in body)) continue;
    let val = typeof body[k] === "string" ? U.stripLong(body[k]) : body[k];
    const MONEY_FIELDS = ["daily_rate", "weekly_rate", "monthly_rate", "provider_rate", "customer_price",
      "provider_payout", "profit", "deposit", "mileage_fee", "delivery_fee"];
    if (MONEY_FIELDS.includes(k) && !U.isMoney(val)) return bad(res, `Invalid amount for ${k}`);
    if (k === "status" && !["available", "booked", "maintenance", "unavailable"].includes(val)) return bad(res, "Invalid status");
    if (k === "rate_label" && !RATE_LABELS.includes(val)) return bad(res, "rate_label must be one of: " + RATE_LABELS.join(", "));
    if (["photos_approved", "price_approved", "requirements_complete"].includes(k)) val = val === true || val === 1 || val === "1" || val === "true" ? 1 : 0;
    if (audited.includes(k) && String(v[k]) !== String(val))
      U.audit(req.user, "vehicle.update", "vehicle", v.vehicle_id, k, v[k], typeof val === "object" ? JSON.stringify(val) : val);
    v[k] = typeof val === "object" ? JSON.stringify(val) : val;
  }
  const sets = VEHICLE_EDITABLE.map(k => `${k}=?`).join(",");
  db.prepare(`UPDATE vehicles SET ${sets} WHERE vehicle_id=?`).run(...VEHICLE_EDITABLE.map(k => v[k]), v.vehicle_id);
  U.queueSync("PartnerInventory", db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(v.vehicle_id));
  return json(res, 200, { ok: true });
}

route("POST", "/api/vehicles", (req, res) => {
  if (!guard("vehicles.write")(req, res)) return;
  const b = req.body || {};
  if (!b.make || !b.model || !b.partner_id) return bad(res, "make, model, partner_id required");
  const id = b.vehicle_id && /^[\w-]{2,24}$/.test(b.vehicle_id) ? b.vehicle_id : U.rid("V");
  if (db.prepare("SELECT 1 FROM vehicles WHERE vehicle_id=?").get(id)) return bad(res, "Vehicle ID already exists", 409);
  db.prepare("INSERT INTO vehicles (vehicle_id, partner_id, make, model, status, booked_dates) VALUES (?,?,?,?, 'available','[]')")
    .run(id, U.strip(b.partner_id), U.strip(b.make), U.strip(b.model));
  const v = db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(id);
  U.audit(req.user, "vehicle.create", "vehicle", id);
  applyVehiclePatch(req, res, v, b, VEHICLE_EDITABLE);
});

route("PATCH", "/api/vehicles/:id", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  const v = db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(req.params.id);
  if (!v) return bad(res, "Not found", 404);
  if (auth.can(req.user, "vehicles.write")) return applyVehiclePatch(req, res, v, req.body || {}, VEHICLE_EDITABLE);
  if (auth.can(req.user, "vehicles.status.write")) return applyVehiclePatch(req, res, v, req.body || {}, ["status", "booked_dates", "last_verified"]);
  bad(res, "Your role does not allow vehicle edits", 403);
});

route("DELETE", "/api/vehicles/:id", (req, res) => {
  if (!guard("vehicles.write")(req, res)) return;
  db.prepare("DELETE FROM vehicles WHERE vehicle_id=?").run(req.params.id);
  U.audit(req.user, "vehicle.delete", "vehicle", req.params.id);
  json(res, 200, { ok: true });
});

/* ----- partners ----- */
route("GET", "/api/partners", (req, res) => {
  if (!guard("partners.read")(req, res)) return;
  json(res, 200, db.prepare("SELECT * FROM partners").all());
});
route("POST", "/api/partners", (req, res) => {
  if (!guard("partners.write")(req, res)) return;
  const b = req.body || {};
  if (!b.company) return bad(res, "Company required");
  const id = "P-" + String(db.prepare("SELECT COUNT(*) n FROM partners").get().n + 1).padStart(3, "0");
  db.prepare("INSERT INTO partners (partner_id, company, contact, phone, email, market, payout_method, status, notes) VALUES (?,?,?,?,?,?,?,?,?)")
    .run(id, U.strip(b.company), U.strip(b.contact), U.strip(b.phone), U.strip(b.email), U.strip(b.market), U.strip(b.payout_method), U.strip(b.status || "Approved"), U.stripLong(b.notes));
  U.audit(req.user, "partner.create", "partner", id);
  U.queueSync("Partners", db.prepare("SELECT * FROM partners WHERE partner_id=?").get(id));
  json(res, 200, { ok: true, partnerId: id });
});
route("PATCH", "/api/partners/:id", (req, res) => {
  if (!guard("partners.write")(req, res)) return;
  const p = db.prepare("SELECT * FROM partners WHERE partner_id=?").get(req.params.id);
  if (!p) return bad(res, "Not found", 404);
  const ONBOARDING = ["Lead", "Discussion", "Terms pending", "Documents pending", "Inventory pending", "Active", "Paused", "Terminated"];
  const DEALS = ["split-80-20", "referral-fixed", "broker-markup", "flat-payout", "custom"];
  for (const k of ["company", "contact", "phone", "email", "market", "payout_method", "status", "notes", "onboarding_status", "deal_model", "deal_terms"]) {
    if (k in (req.body || {})) {
      const val = U.stripLong(req.body[k]);
      if (k === "onboarding_status" && !ONBOARDING.includes(val)) return bad(res, "onboarding_status must be one of: " + ONBOARDING.join(", "));
      if (k === "deal_model" && !DEALS.includes(val)) return bad(res, "deal_model must be one of: " + DEALS.join(", "));
      if (String(p[k]) !== String(val)) U.audit(req.user, "partner.update", "partner", p.partner_id, k, p[k], val);
      p[k] = val;
    }
  }
  db.prepare(`UPDATE partners SET company=?,contact=?,phone=?,email=?,market=?,payout_method=?,status=?,notes=?,
      onboarding_status=?,deal_model=?,deal_terms=? WHERE partner_id=?`)
    .run(p.company, p.contact, p.phone, p.email, p.market, p.payout_method, p.status, p.notes,
      p.onboarding_status, p.deal_model, p.deal_terms, p.partner_id);
  U.queueSync("Partners", db.prepare("SELECT * FROM partners WHERE partner_id=?").get(p.partner_id));
  json(res, 200, { ok: true });
});
route("GET", "/api/partner-inquiries", (req, res) => {
  if (!guard("inquiries.read")(req, res)) return;
  json(res, 200, db.prepare("SELECT * FROM partner_inquiries ORDER BY ts DESC").all());
});

/* ----- requests + workflow ----- */
route("GET", "/api/requests", (req, res) => {
  if (!guard("requests.read")(req, res)) return;
  json(res, 200, db.prepare("SELECT * FROM requests ORDER BY ts DESC").all());
});

route("GET", "/api/requests/:id/matches", (req, res) => {
  if (!guard("requests.read")(req, res)) return;
  const r = db.prepare("SELECT * FROM requests WHERE request_id=?").get(req.params.id);
  if (!r) return bad(res, "Not found", 404);
  const want = (r.vehicle_requested || "").toLowerCase();
  const approved = new Set(db.prepare("SELECT partner_id FROM partners WHERE onboarding_status='Active'").all().map(p => p.partner_id));
  const pool = db.prepare("SELECT * FROM vehicles WHERE market=?").all(process.env.TN_MARKET || "Miami")
    .filter(v => approved.has(v.partner_id));
  const exact = pool.filter(v => want.includes(v.model.toLowerCase()));
  const similarPool = pool.filter(v => !exact.includes(v));
  const days = Math.max(1, Math.round((Date.parse(r.end_date) - Date.parse(r.start_date)) / 864e5) || 1);
  const sd = r.start_date.slice(0, 10), ed = r.end_date.slice(0, 10);
  const shape = v => ({
    ...pick(v, [...VEHICLE_PUBLIC, "partner_id", "provider_rate", "provider_contact", "last_verified", "booked_dates"]),
    provider: db.prepare("SELECT company FROM partners WHERE partner_id=?").get(v.partner_id)?.company,
    conflicts: vehicleConflicts(v.vehicle_id, sd, ed, r.request_id),
    profitEstimate: (v.customer_price - v.provider_rate) * days
  });
  const rank = l => l.sort((a, b) => (a.status === "available" ? 0 : 1) - (b.status === "available" ? 0 : 1) || a.provider_rate - b.provider_rate);
  json(res, 200, { days, exact: rank(exact.map(shape)).slice(0, 6), similar: rank(similarPool.map(shape)).slice(0, 2) });
});

function getReq(res, id) {
  const r = db.prepare("SELECT * FROM requests WHERE request_id=?").get(id);
  if (!r) bad(res, "Not found", 404);
  return r;
}
function setStatus(user, r, next) {
  U.audit(user, "request.status", "request", r.request_id, "status", r.status, next, r.request_id);
  db.prepare("UPDATE requests SET status=? WHERE request_id=?").run(next, r.request_id);
  U.queueSync("CustomerRequests", db.prepare("SELECT * FROM requests WHERE request_id=?").get(r.request_id));
}

route("POST", "/api/requests/:id/assign", async (req, res) => {
  if (!guard("requests.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  const v = db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(U.strip(req.body.vehicleId));
  if (!v) return bad(res, "Vehicle not found", 404);
  const conflicts = vehicleConflicts(v.vehicle_id, r.start_date.slice(0, 10), r.end_date.slice(0, 10), r.request_id);
  if (conflicts.length) return bad(res, "Date conflict on this unit: " + conflicts.join(", "), 409);
  db.prepare("UPDATE requests SET assigned_vehicle_id=? WHERE request_id=?").run(v.vehicle_id, r.request_id);
  U.audit(req.user, "request.assign", "request", r.request_id, "assigned_vehicle_id", r.assigned_vehicle_id, v.vehicle_id, r.request_id);
  setStatus(req.user, r, "Availability being confirmed");
  /* notify the provider with ONLY what they need to confirm */
  await U.notify(null, v.partner_id, "AVAILABILITY_REQUEST", `Availability check — ${v.year} ${v.make} ${v.model}`,
    `Unit ${v.vehicle_id}: ${r.start_date} → ${r.end_date}. Delivery area: ${r.option === "pickup" ? "Showroom pickup" : r.delivery_location}. Reply in your portal: confirm or decline. (Request ${r.request_id})`);
  emails.customerEmail("AVAILABILITY_CHECK", r.email, {
    requestId: r.request_id, firstName: r.customer_name.split(" ")[0], vehicle: r.vehicle_requested,
    dates: `${r.start_date} → ${r.end_date}`,
    trackUrl: `${process.env.TN_BASE_URL || ""}/track.html?id=${r.request_id}&ph=${(r.phone || "").replace(/\D/g, "").slice(-4)}`
  }).catch(() => {});
  json(res, 200, { ok: true });
});

async function providerDecision(req, res, r, decision, note, actor) {
  if (!["Availability being confirmed"].includes(r.status)) return bad(res, "No availability check is open on this request");
  if (decision === "confirm") {
    setStatus(actor, r, "Provider confirmed");
    await U.notify("sales", null, "PROVIDER_CONFIRMED", `Provider confirmed — ${r.request_id}`, `Unit ${r.assigned_vehicle_id} is available. Approve final price next.`);
  } else {
    db.prepare("UPDATE requests SET assigned_vehicle_id=NULL, decline_note=? WHERE request_id=?").run(U.strip(note || ""), r.request_id);
    U.audit(actor, "request.provider.declined", "request", r.request_id, "assigned_vehicle_id", r.assigned_vehicle_id, null, r.request_id);
    setStatus(actor, r, "Under review");
    await U.notify("sales", null, "PROVIDER_DECLINED", `Provider declined — ${r.request_id}`, `Unit ${r.assigned_vehicle_id || ""} declined${note ? ": " + note : ""}. Assign the backup provider.`);
  }
  json(res, 200, { ok: true });
}
route("POST", "/api/requests/:id/provider-decision", (req, res) => {
  if (!guard("requests.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  providerDecision(req, res, r, req.body.decision === "confirm" ? "confirm" : "decline", req.body.note, req.user);
});

route("POST", "/api/requests/:id/approve", (req, res) => {
  if (!guard("quotes.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  if (r.status !== "Provider confirmed") return bad(res, "Provider must confirm availability before approval (current: " + r.status + ")");
  const final = Number(req.body.finalPrice), cost = Number(req.body.internalCost);
  if (!U.isMoney(final) || !final || !U.isMoney(cost)) return bad(res, "Valid final price and internal cost required");
  U.audit(req.user, "request.price.approved", "request", r.request_id, "final_price", r.final_price, final, r.request_id);
  db.prepare("UPDATE requests SET final_price=?, internal_cost=?, profit=? WHERE request_id=?")
    .run(final, cost, final - cost, r.request_id);
  setStatus(req.user, r, "Approved");
  json(res, 200, { ok: true, profit: final - cost });
});

route("POST", "/api/requests/:id/quote", async (req, res) => {
  if (!guard("quotes.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  if (r.status !== "Approved") return bad(res, "Approve the final price first (current: " + r.status + ")");
  const days = Math.min(14, Math.max(1, Number(req.body.expiresDays) || 3));
  const expires = new Date(Date.now() + days * 864e5).toISOString();
  db.prepare("UPDATE requests SET quote_amount=?, quote_expires=? WHERE request_id=?").run(r.final_price, expires, r.request_id);
  setStatus(req.user, r, "Quote sent");
  U.audit(req.user, "quote.sent", "request", r.request_id, "quote_amount", null, r.final_price, r.request_id);
  await U.notify("sales", null, "QUOTE_SENT", `Quote sent — ${r.request_id}`, `$${r.final_price}, expires ${expires.slice(0, 10)}. Customer accepts via their tracking page.`);
  emails.customerEmail("QUOTE_ISSUED", r.email, {
    requestId: r.request_id, firstName: r.customer_name.split(" ")[0], vehicle: r.vehicle_requested,
    dates: `${r.start_date} → ${r.end_date}`, amount: r.final_price, expires: expires.slice(0, 10),
    trackUrl: `${process.env.TN_BASE_URL || ""}/track.html?id=${r.request_id}&ph=${(r.phone || "").replace(/\D/g, "").slice(-4)}`
  }).catch(() => {});
  json(res, 200, { ok: true, expires });
});

route("POST", "/api/requests/:id/payment-link", async (req, res) => {
  if (!guard("quotes.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  if (r.status !== "Quote accepted") return bad(res, "Customer must accept the quote first (current: " + r.status + ")");
  db.prepare("UPDATE requests SET payment_status='link-issued' WHERE request_id=?").run(r.request_id);
  setStatus(req.user, r, "Payment required");
  await U.notify("sales", null, "PAYMENT_DUE", `Payment due — ${r.request_id}`, `Send payment/deposit link to ${r.customer_name} (${r.phone}). Card details are handled by the payment provider — never stored here.`);
  json(res, 200, { ok: true });
});

/* shared confirmation path: manual verification AND the Stripe
   webhook both land here — the status machine gates both. */
async function confirmBooking(actor, r, amount, method, stripeInfo) {
  const v = db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(r.assigned_vehicle_id);
  if (!v) return { error: "No provider unit assigned" };
  const sd = r.start_date.slice(0, 10), ed = r.end_date.slice(0, 10);
  const conflicts = vehicleConflicts(v.vehicle_id, sd, ed, r.request_id);
  if (conflicts.length) return { error: "Overlap appeared since assignment: " + conflicts.join(", "), code: 409 };

  db.prepare(`INSERT INTO payments (request_id, kind, category, amount, method, status, recorded_by,
      stripe_customer_id, stripe_payment_intent, currency)
    VALUES (?,?,?,?,?,?,?,?,?,?)`)
    .run(r.request_id, "payment", stripeInfo?.category || "rental-payment", amount, method, "verified",
      actor?.email || "stripe-webhook", stripeInfo?.customerId || null, stripeInfo?.paymentIntent || null, "usd");
  U.audit(actor, "payment.verified", "request", r.request_id, "amount", null, amount, r.request_id);
  db.prepare("UPDATE requests SET payment_status='verified' WHERE request_id=?").run(r.request_id);
  setStatus(actor, r, "Booking confirmed");

  const booked = JSON.parse(v.booked_dates || "[]"); booked.push(`${sd}→${ed}`);
  db.prepare("UPDATE vehicles SET status='booked', booked_dates=? WHERE vehicle_id=?").run(JSON.stringify(booked), v.vehicle_id);
  U.audit(actor, "vehicle.update", "vehicle", v.vehicle_id, "status", v.status, "booked", r.request_id);
  U.queueSync("PartnerInventory", db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(v.vehicle_id));

  const rentalId = r.request_id.replace("TN-", "AR-");
  const partner = db.prepare("SELECT company FROM partners WHERE partner_id=?").get(v.partner_id);
  db.prepare(`INSERT OR REPLACE INTO rentals (rental_id, request_id, vehicle_id, vehicle, customer, customer_phone,
      provider, partner_id, pickup_date, return_date, delivery_address, deposit, amount_paid, balance_due, provider_payout, profit)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .run(rentalId, r.request_id, v.vehicle_id, `${v.year} ${v.make} ${v.model} ${v.trim}`, r.customer_name, r.phone,
      partner?.company || "", v.partner_id, r.start_date, r.end_date,
      r.option === "pickup" ? "Showroom" : r.delivery_location,
      v.deposit, amount, Math.max(0, (r.final_price || 0) - amount), r.internal_cost || 0, r.profit || 0);
  U.queueSync("ActiveRentals", db.prepare("SELECT * FROM rentals WHERE rental_id=?").get(rentalId));
  U.queueSync("Payments", { request_id: r.request_id, kind: "payment", category: stripeInfo?.category || "rental-payment", amount, by: actor?.email || "stripe" });
  await U.notify("ops", null, "BOOKING_CONFIRMED", `Booking confirmed — ${rentalId}`, `${v.year} ${v.make} ${v.model} for ${r.customer_name}. Prepare ${r.option === "pickup" ? "showroom handover" : "delivery to " + r.delivery_location} on ${r.start_date}.`);
  await U.notify(null, v.partner_id, "BOOKING_CONFIRMED", `Booking confirmed — unit ${v.vehicle_id}`, `${r.start_date} → ${r.end_date}. Customer: ${r.customer_name}, ${r.phone}. ${r.option === "pickup" ? "Showroom pickup" : "Delivery: " + r.delivery_location}.`);
  emails.customerEmail("BOOKING_CONFIRMED", r.email, {
    requestId: r.request_id, firstName: r.customer_name.split(" ")[0],
    vehicle: `${v.year} ${v.make} ${v.model}`, dates: `${r.start_date} → ${r.end_date}`,
    handover: r.option === "pickup" ? "Showroom pickup" : "Delivered to " + r.delivery_location,
    trackUrl: `${process.env.TN_BASE_URL || ""}/track.html?id=${r.request_id}&ph=${(r.phone || "").replace(/\D/g, "").slice(-4)}`
  }).catch(() => {});
  return { ok: true, rentalId };
}

route("POST", "/api/requests/:id/payment-verified", async (req, res) => {
  if (!guard("requests.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  if (r.status !== "Payment required") return bad(res, "Issue the payment link first (current: " + r.status + ")");
  const out = await confirmBooking(req.user, r, Number(req.body.amount) || r.final_price || 0, U.strip(req.body.method || "card"));
  if (out.error) return bad(res, out.error, out.code || 400);
  json(res, 200, out);
});

route("POST", "/api/requests/:id/decline", (req, res) => {
  if (!guard("requests.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  db.prepare("UPDATE requests SET decline_note=? WHERE request_id=?").run(U.strip(req.body.note || ""), r.request_id);
  U.audit(req.user, "request.declined", "request", r.request_id, "status", r.status, "Declined", r.request_id);
  setStatus(req.user, r, "Declined");
  json(res, 200, { ok: true });
});

route("POST", "/api/requests/:id/review", (req, res) => { /* sales marks lead reviewed */
  if (!guard("requests.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  if (r.status !== "Request submitted") return bad(res, "Already in progress");
  setStatus(req.user, r, "Under review");
  json(res, 200, { ok: true });
});

/* ----- rentals ----- */
route("GET", "/api/rentals", (req, res) => {
  if (!guard("rentals.read")(req, res)) return;
  json(res, 200, db.prepare("SELECT * FROM rentals ORDER BY created_at DESC").all());
});
/* operational checklists — enforced before handover and before payout */
const PRE_CHECKLIST = ["provider_confirmed", "customer_approved", "license_verified", "insurance_verified",
  "contract_signed", "payment_verified", "deposit_verified", "delivery_confirmed",
  "pre_inspection_done", "start_mileage_recorded", "fuel_recorded", "keys_released"];
const POST_CHECKLIST = ["vehicle_returned", "return_time_recorded", "final_mileage_recorded", "fuel_recorded",
  "post_inspection_done", "damage_reviewed", "tolls_tickets_checked", "deposit_decided",
  "payout_approved", "review_request_sent", "vehicle_reavailable"];
route("GET", "/api/meta/checklists", (req, res) => json(res, 200, { pre: PRE_CHECKLIST, post: POST_CHECKLIST }));

route("PATCH", "/api/rentals/:id", async (req, res) => {
  if (!guard("rentals.write")(req, res)) return;
  const x = db.prepare("SELECT * FROM rentals WHERE rental_id=?").get(req.params.id);
  if (!x) return bad(res, "Not found", 404);

  /* checklist updates (audited per flipped item) */
  for (const [col, items] of [["pre_checklist", PRE_CHECKLIST], ["post_checklist", POST_CHECKLIST]]) {
    if (req.body && typeof req.body[col] === "object" && req.body[col]) {
      const cur = JSON.parse(x[col] || "{}");
      for (const k of items) {
        if (k in req.body[col] && !!cur[k] !== !!req.body[col][k]) {
          U.audit(req.user, "rental.checklist", "rental", x.rental_id, `${col}.${k}`, !!cur[k], !!req.body[col][k], x.request_id);
          cur[k] = !!req.body[col][k];
        }
      }
      x[col] = JSON.stringify(cur);
    }
  }
  const pre = JSON.parse(x.pre_checklist || "{}"), post = JSON.parse(x.post_checklist || "{}");
  if (req.body.pickup_status === "Done" && x.pickup_status !== "Done") {
    const missing = PRE_CHECKLIST.filter(k => !pre[k]);
    if (missing.length) return bad(res, "Pre-rental checklist incomplete: " + missing.join(", "), 409);
  }
  if (req.body.payout_paid === "Yes" && x.payout_paid !== "Yes") {
    const missing = POST_CHECKLIST.filter(k => !post[k]);
    if (missing.length) return bad(res, "Post-rental checklist incomplete before payout: " + missing.join(", "), 409);
  }

  const fields = ["amount_paid", "balance_due", "deposit", "provider_payout", "pickup_status", "return_status",
    "deposit_refunded", "payout_paid", "review_requested", "review", "notes", "pre_checklist", "post_checklist"];
  const audited = ["amount_paid", "deposit", "provider_payout", "pickup_status", "return_status", "deposit_refunded", "payout_paid"];
  for (const k of fields) {
    if (!(k in (req.body || {})) || k.endsWith("_checklist")) continue;
    const val = typeof req.body[k] === "string" ? U.stripLong(req.body[k]) : req.body[k];
    if (/amount|deposit|payout|balance/.test(k) && !U.isMoney(val)) return bad(res, "Invalid amount for " + k);
    if (audited.includes(k) && String(x[k]) !== String(val))
      U.audit(req.user, "rental.update", "rental", x.rental_id, k, x[k], val, x.request_id);
    x[k] = val;
  }
  const custEmail = db.prepare("SELECT email, customer_name FROM requests WHERE request_id=?").get(x.request_id);
  if (req.body.deposit_refunded === "Yes" && custEmail?.email)
    emails.customerEmail("DEPOSIT_STATUS", custEmail.email, { requestId: x.request_id, firstName: (custEmail.customer_name || "").split(" ")[0], message: `Your $${x.deposit} security deposit has been released. Allow 3–7 business days for your bank to post it.` }).catch(() => {});
  if (req.body.review_requested === "Yes" && custEmail?.email)
    emails.customerEmail("REVIEW_REQUEST", custEmail.email, { requestId: x.request_id, firstName: (custEmail.customer_name || "").split(" ")[0], vehicle: x.vehicle, instagram: SETTING("instagram") }).catch(() => {});
  db.prepare(`UPDATE rentals SET ${fields.map(f => f + "=?").join(",")} WHERE rental_id=?`)
    .run(...fields.map(f => x[f]), x.rental_id);

  if (x.return_status === "Done") {
    const v = db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(x.vehicle_id);
    if (v && v.status === "booked") {
      const range = `${x.pickup_date.slice(0, 10)}→${x.return_date.slice(0, 10)}`;
      const booked = JSON.parse(v.booked_dates || "[]").filter(b => b !== range);
      db.prepare("UPDATE vehicles SET status='available', booked_dates=? WHERE vehicle_id=?").run(JSON.stringify(booked), v.vehicle_id);
      U.audit(req.user, "vehicle.update", "vehicle", v.vehicle_id, "status", "booked", "available", x.rental_id);
      U.queueSync("PartnerInventory", db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(v.vehicle_id));
    }
    const r0 = db.prepare("SELECT * FROM requests WHERE request_id=?").get(x.request_id);
    if (r0 && r0.status === "Booking confirmed") setStatus(req.user, r0, "Completed");
    if (x.deposit_refunded !== "Yes") await U.notify("ops", null, "DEPOSIT_REFUND", `Refund deposit — ${x.rental_id}`, `$${x.deposit} to ${x.customer}`);
    if (x.payout_paid !== "Yes") await U.notify("admin", null, "PROVIDER_PAYOUT", `Provider payout — ${x.rental_id}`, `$${x.provider_payout} to ${x.provider}`);
    if (x.review_requested !== "Yes") await U.notify("cx", null, "REVIEW_REQUEST", `Request review — ${x.rental_id}`, `${x.customer} (${x.customer_phone})`);
  }
  U.queueSync("ActiveRentals", db.prepare("SELECT * FROM rentals WHERE rental_id=?").get(x.rental_id));
  json(res, 200, { ok: true });
});

/* ----- payments ----- */
route("GET", "/api/payments", (req, res) => {
  if (!req.user || !(auth.can(req.user, "*") || req.user.role === "admin" || auth.can(req.user, "requests.read"))) return bad(res, "Forbidden", 403);
  json(res, 200, db.prepare("SELECT * FROM payments ORDER BY ts DESC").all());
});
route("POST", "/api/payments", (req, res) => {
  if (!guard("requests.write")(req, res)) return;
  const b = req.body || {};
  if (!["payment", "deposit", "refund", "payout"].includes(b.kind)) return bad(res, "Invalid kind");
  if (!U.isMoney(b.amount) || !Number(b.amount)) return bad(res, "Invalid amount");
  db.prepare("INSERT INTO payments (request_id, rental_id, kind, amount, method, recorded_by) VALUES (?,?,?,?,?,?)")
    .run(U.strip(b.requestId), U.strip(b.rentalId), b.kind, Number(b.amount), U.strip(b.method), req.user.email);
  U.audit(req.user, "payment." + b.kind, "payment", b.rentalId || b.requestId, "amount", null, b.amount, b.requestId);
  U.queueSync("Payments", { ...b, by: req.user.email, ts: new Date().toISOString() });
  json(res, 200, { ok: true });
});

/* ----- reviews ----- */
route("GET", "/api/reviews", (req, res) => {
  if (!guard("reviews.read")(req, res)) return;
  json(res, 200, db.prepare("SELECT * FROM reviews ORDER BY ts DESC").all());
});
route("POST", "/api/reviews", (req, res) => {
  if (!guard("reviews.write")(req, res)) return;
  const rating = Number(req.body.rating);
  if (!(rating >= 1 && rating <= 5)) return bad(res, "Rating 1–5 required");
  db.prepare("INSERT INTO reviews (rental_id, rating, text, recorded_by) VALUES (?,?,?,?)")
    .run(U.strip(req.body.rentalId), rating, U.stripLong(req.body.text), req.user.email);
  U.queueSync("Reviews", { rentalId: req.body.rentalId, rating, text: req.body.text });
  json(res, 200, { ok: true });
});

/* ----- notifications / reminders ----- */
route("GET", "/api/notifications", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  const rows = req.user.role === "partner"
    ? db.prepare("SELECT * FROM notifications WHERE partner_id=? ORDER BY ts DESC LIMIT 100").all(req.user.partner_id)
    : req.user.role === "admin"
      ? db.prepare("SELECT * FROM notifications ORDER BY ts DESC LIMIT 200").all()
      : db.prepare("SELECT * FROM notifications WHERE audience_role=? OR audience_role IS NULL AND partner_id IS NULL ORDER BY ts DESC LIMIT 100").all(req.user.role);
  json(res, 200, rows);
});

route("GET", "/api/reminders", (req, res) => {
  if (!req.user || req.user.role === "partner") return bad(res, "Forbidden", 403);
  const out = [];
  for (const r of db.prepare("SELECT * FROM requests WHERE status NOT IN ('Declined','Cancelled','Completed')").all()) {
    if (r.status === "Request submitted") out.push({ t: `Review new request ${r.request_id} — ${r.vehicle_requested} (${r.customer_name})`, w: "sales" });
    if (r.status === "Availability being confirmed") out.push({ t: `Provider has not answered availability — ${r.request_id} (unit ${r.assigned_vehicle_id})`, w: "chase" });
    if (r.status === "Quote sent") out.push({ t: `Quote awaiting customer — ${r.request_id} ($${r.quote_amount}, expires ${String(r.quote_expires).slice(0, 10)})`, w: "quote" });
    if (r.status === "Payment required") out.push({ t: `Payment due — ${r.customer_name} (${r.phone}) on ${r.request_id}`, w: "payment" });
  }
  const t = new Date().toISOString().slice(0, 10);
  for (const x of db.prepare("SELECT * FROM rentals").all()) {
    if (x.pickup_status !== "Done" && x.pickup_date && x.pickup_date.slice(0, 10) <= t) out.push({ t: `Delivery/pickup prep — ${x.vehicle} for ${x.customer}`, w: x.pickup_date });
    if (x.return_status !== "Done" && x.return_date && x.return_date.slice(0, 10) <= t) out.push({ t: `Return due — ${x.vehicle} (${x.customer})`, w: x.return_date });
    if (x.return_status === "Done" && x.deposit_refunded !== "Yes") out.push({ t: `Refund deposit $${x.deposit} — ${x.customer}`, w: "deposit" });
    if (x.return_status === "Done" && x.payout_paid !== "Yes") out.push({ t: `Provider payout $${x.provider_payout} — ${x.provider}`, w: "payout" });
    if (x.return_status === "Done" && x.review_requested !== "Yes") out.push({ t: `Request review — ${x.customer}`, w: "review" });
  }
  for (const v of db.prepare("SELECT * FROM vehicles").all()) {
    const age = (Date.now() - Date.parse(v.last_verified || 0)) / 864e5;
    if (age > 5) out.push({ t: `Re-verify availability — ${v.year} ${v.make} ${v.model} (${v.vehicle_id})`, w: Math.round(age) + "d" });
  }
  json(res, 200, out);
});

/* ----- audit + sync (admin) ----- */
route("GET", "/api/audit", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  if (req.user.role !== "admin") return bad(res, "Admin only", 403);
  json(res, 200, db.prepare("SELECT * FROM audit ORDER BY id DESC LIMIT 500").all());
});
route("GET", "/api/sync", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  if (req.user.role !== "admin") return bad(res, "Admin only", 403);
  json(res, 200, {
    pendingOrFailed: db.prepare("SELECT * FROM sync_outbox WHERE status != 'sent' ORDER BY id DESC LIMIT 100").all(),
    recentSent: db.prepare("SELECT id, ts, table_name, sent_at FROM sync_outbox WHERE status='sent' ORDER BY id DESC LIMIT 20").all(),
    configured: !!process.env.EXCEL_WEBHOOK_URL
  });
});
route("POST", "/api/sync/:id/retry", async (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  if (req.user.role !== "admin") return bad(res, "Admin only", 403);
  db.prepare("UPDATE sync_outbox SET next_retry=datetime('now'), status='pending' WHERE id=?").run(req.params.id);
  await U.drainOutbox();
  json(res, 200, db.prepare("SELECT * FROM sync_outbox WHERE id=?").get(req.params.id));
});

/* ----- users (admin only) ----- */
route("GET", "/api/users", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  if (req.user.role !== "admin") return bad(res, "Admin only", 403);
  json(res, 200, db.prepare("SELECT id, email, name, role, partner_id, active, must_reset, created_at FROM users").all());
});
route("POST", "/api/users", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  if (req.user.role !== "admin") return bad(res, "Admin only", 403);
  const b = req.body || {};
  if (!U.isEmail(b.email || "")) return bad(res, "Valid email required");
  if (!auth.PERMS[b.role]) return bad(res, "Invalid role");
  if (String(b.password || "").length < 10) return bad(res, "Password min 10 chars");
  const { salt, hash } = auth.hashPassword(b.password);
  try {
    db.prepare("INSERT INTO users (email, name, role, partner_id, pass_hash, salt, must_reset) VALUES (?,?,?,?,?,?,1)")
      .run(U.strip(b.email).toLowerCase(), U.strip(b.name), b.role, U.strip(b.partnerId) || null, hash, salt);
  } catch (e) { return bad(res, "Email already exists", 409); }
  U.audit(req.user, "user.create", "user", b.email, "role", null, b.role);
  json(res, 200, { ok: true });
});

/* ----- uploads (auth; magic-byte + size validation; permissioned reads) ----- */
const MAGIC = { jpeg: [0xff, 0xd8, 0xff], png: [0x89, 0x50, 0x4e, 0x47], webp: [0x52, 0x49, 0x46, 0x46] };
route("POST", "/api/uploads", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  const b = req.body || {};
  const data = String(b.data || "");
  const m = data.match(/^data:image\/(jpeg|png|webp);base64,(.+)$/);
  if (!m) { U.audit(req.user, "upload.rejected", "upload", "type"); return bad(res, "Only JPEG/PNG/WebP images accepted"); }
  const buf = Buffer.from(m[2], "base64");
  if (buf.length > 5 * 1024 * 1024) { U.audit(req.user, "upload.rejected", "upload", "size"); return bad(res, "Max 5 MB per photo"); }
  const magic = MAGIC[m[1] === "jpeg" ? "jpeg" : m[1]];
  if (!magic.every((v, i) => buf[i] === v)) { U.audit(req.user, "upload.rejected", "upload", "magic"); return bad(res, "File content does not match its type"); }
  const id = crypto.randomUUID();
  const ext = m[1] === "jpeg" ? "jpg" : m[1];
  const file = path.join(UPLOAD_DIR, `${id}.${ext}`);
  fs.writeFileSync(file, buf);
  db.prepare("INSERT INTO uploads (id, owner_email, partner_id, rental_id, vehicle_id, kind, filename, mime, size, path) VALUES (?,?,?,?,?,?,?,?,?,?)")
    .run(id, req.user.email, req.user.partner_id || U.strip(b.partnerId) || null, U.strip(b.rentalId) || null,
      U.strip(b.vehicleId) || null, U.strip(b.kind || "photo"), U.strip(b.filename || "photo"), "image/" + m[1], buf.length, file);
  U.audit(req.user, "upload.create", "upload", id, "kind", null, b.kind, b.rentalId || b.vehicleId);
  json(res, 200, { ok: true, id, url: "/api/files/" + id });
});
route("GET", "/api/uploads", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  let rows = db.prepare("SELECT id, ts, owner_email, partner_id, rental_id, vehicle_id, kind, filename, size FROM uploads ORDER BY ts DESC LIMIT 200").all();
  if (req.user.role === "partner") rows = rows.filter(u => u.partner_id === req.user.partner_id);
  if (req.query.rentalId) rows = rows.filter(u => u.rental_id === req.query.rentalId);
  if (req.query.vehicleId) rows = rows.filter(u => u.vehicle_id === req.query.vehicleId);
  json(res, 200, rows);
});
/* File access: session-authenticated OR signed temporary link.
   No permanent public URLs exist; every view is access-logged. */
route("GET", "/api/files/:id", (req, res) => {
  const u = db.prepare("SELECT * FROM uploads WHERE id=?").get(req.params.id);
  if (!u) return bad(res, "Not found", 404);
  const { exp, sig } = req.query;
  const signedOk = exp && sig && Number(exp) > Date.now() &&
    crypto.timingSafeEqual(Buffer.from(fileSig(u.id, exp)), Buffer.from(String(sig).padEnd(64, "0").slice(0, 64)));
  if (!signedOk) {
    if (!req.user) return bad(res, "Sign in required", 401);
    if (req.user.role === "partner" && u.partner_id !== req.user.partner_id) return bad(res, "Forbidden", 403);
  }
  U.audit(req.user, "file.view", "upload", u.id, "via", null, signedOk ? "signed-link" : "session", u.rental_id || u.vehicle_id);
  res.writeHead(200, { "Content-Type": u.mime, "Cache-Control": "private, no-store" });
  fs.createReadStream(u.path).pipe(res);
});

route("POST", "/api/files/:id/sign", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  const u = db.prepare("SELECT * FROM uploads WHERE id=?").get(req.params.id);
  if (!u) return bad(res, "Not found", 404);
  if (req.user.role === "partner" && u.partner_id !== req.user.partner_id) return bad(res, "Forbidden", 403);
  const exp = Date.now() + Math.min(60, Number(req.body.minutes) || 15) * 60e3;
  U.audit(req.user, "file.sign", "upload", u.id, "expires", null, new Date(exp).toISOString(), u.rental_id);
  json(res, 200, { url: `/api/files/${u.id}?exp=${exp}&sig=${fileSig(u.id, exp)}`, expires: new Date(exp).toISOString() });
});

route("DELETE", "/api/uploads/:id", (req, res) => {
  if (!adminOnly(req, res)) return;
  const u = db.prepare("SELECT * FROM uploads WHERE id=?").get(req.params.id);
  if (!u) return bad(res, "Not found", 404);
  try { fs.unlinkSync(u.path); } catch (e) { /* already gone */ }
  db.prepare("DELETE FROM uploads WHERE id=?").run(u.id);
  U.audit(req.user, "upload.delete", "upload", u.id, "kind", u.kind, null, u.rental_id || u.vehicle_id);
  json(res, 200, { ok: true });
});

/* ============================================================
   PARTNER INVENTORY IMPORT (CSV; preview → admin approval → commit)
   ============================================================ */
const IMPORT_HEADERS = {
  provider: "partner_id", "provider id": "partner_id", year: "year", make: "make", model: "model", trim: "trim",
  color: "color", "daily rate": "daily_rate", "weekly rate": "weekly_rate", "monthly rate": "monthly_rate",
  "broker rate": "provider_rate", "b2b rate": "provider_rate", "provider rate": "provider_rate",
  "customer rate": "customer_price", "customer price": "customer_price", deposit: "deposit",
  mileage: "mileage_included", "additional mile fee": "mileage_fee", "mile fee": "mileage_fee",
  "minimum rental": "min_days", "min days": "min_days", "delivery areas": "delivery_areas",
  "delivery fee": "delivery_fee", "driver age": "min_age", "min age": "min_age", license: "license",
  insurance: "insurance", "payment methods": "payments", availability: "status", "booked dates": "booked_dates",
  photos: "photos", "vehicle photos": "photos", "provider contact": "provider_contact", notes: "notes",
  vin: "vin", "vehicle id": "vehicle_id"
};
const importPreviews = new Map();

function parseCSV(text) {
  const rows = [];
  let row = [], cell = "", inQ = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (inQ) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (ch === '"') inQ = false;
      else cell += ch;
    } else if (ch === '"') inQ = true;
    else if (ch === ",") { row.push(cell); cell = ""; }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(cell); rows.push(row); row = []; cell = "";
    } else cell += ch;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  return rows.filter(r => r.some(c => c.trim() !== ""));
}

route("POST", "/api/import/preview", (req, res) => {
  if (!guard("import.write")(req, res)) return;
  const rows = parseCSV(String(req.body.csv || ""));
  if (rows.length < 2) return bad(res, "CSV needs a header row and at least one vehicle");
  const header = rows[0].map(h => IMPORT_HEADERS[h.trim().toLowerCase()] || null);
  const partners = new Map(db.prepare("SELECT partner_id, company FROM partners").all().flatMap(p => [[p.partner_id, p.partner_id], [p.company.toLowerCase(), p.partner_id]]));
  const seenIds = new Set();
  const report = { newVehicles: [], updated: [], duplicates: [], missingFields: [], invalidPrices: [], conflicts: [] };
  const parsed = [];

  rows.slice(1).forEach((cells, i) => {
    const rec = {};
    header.forEach((h, c) => { if (h) rec[h] = (cells[c] || "").trim(); });
    const line = i + 2;
    if (rec.partner_id) rec.partner_id = partners.get(rec.partner_id.toLowerCase()) || rec.partner_id;
    const missing = ["partner_id", "make", "model", "daily_rate"].filter(k => !rec[k]);
    if (missing.length) { report.missingFields.push({ line, missing, rec }); return; }
    if (!partners.has(rec.partner_id.toLowerCase()) && !db.prepare("SELECT 1 FROM partners WHERE partner_id=?").get(rec.partner_id)) {
      report.missingFields.push({ line, missing: ["unknown provider '" + rec.partner_id + "'"], rec }); return;
    }
    const badPrice = ["daily_rate", "weekly_rate", "monthly_rate", "provider_rate", "customer_price", "deposit", "mileage_fee", "delivery_fee"]
      .find(k => rec[k] && (isNaN(Number(rec[k].replace(/[$,]/g, ""))) || Number(rec[k].replace(/[$,]/g, "")) < 0));
    if (badPrice) { report.invalidPrices.push({ line, field: badPrice, value: rec[badPrice], rec }); return; }
    ["daily_rate", "weekly_rate", "monthly_rate", "provider_rate", "customer_price", "deposit", "mileage_fee", "delivery_fee", "min_days", "mileage_included", "min_age", "year"]
      .forEach(k => { if (rec[k]) rec[k] = Number(String(rec[k]).replace(/[$,]/g, "")); });

    const key = rec.vin || rec.vehicle_id;
    if (key) {
      if (seenIds.has(key)) { report.duplicates.push({ line, key, rec }); return; }
      seenIds.add(key);
      const clash = rec.vehicle_id && db.prepare("SELECT partner_id FROM vehicles WHERE vehicle_id=?").get(rec.vehicle_id);
      if (clash && clash.partner_id !== rec.partner_id) { report.conflicts.push({ line, key, reason: "vehicle_id belongs to another provider", rec }); return; }
      const vinClash = rec.vin && db.prepare("SELECT vehicle_id, partner_id FROM vehicles WHERE vin=?").get(rec.vin);
      if (vinClash && vinClash.partner_id !== rec.partner_id) { report.conflicts.push({ line, key, reason: "VIN belongs to another provider", rec }); return; }
    }
    const existing = (rec.vehicle_id && db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(rec.vehicle_id)) ||
      (rec.vin && db.prepare("SELECT * FROM vehicles WHERE vin=?").get(rec.vin)) ||
      db.prepare("SELECT * FROM vehicles WHERE partner_id=? AND make=? AND model=? AND ifnull(trim,'')=? AND ifnull(color,'')=?")
        .get(rec.partner_id, rec.make, rec.model, rec.trim || "", rec.color || "");
    if (existing) { rec.vehicle_id = existing.vehicle_id; report.updated.push({ line, vehicleId: existing.vehicle_id, rec }); }
    else report.newVehicles.push({ line, rec });
    parsed.push(rec);
  });

  const token = crypto.randomUUID();
  importPreviews.set(token, { parsed, by: req.user.email, ts: Date.now() });
  setTimeout(() => importPreviews.delete(token), 30 * 60e3).unref();
  json(res, 200, { token, summary: {
    new: report.newVehicles.length, updated: report.updated.length, duplicates: report.duplicates.length,
    missingFields: report.missingFields.length, invalidPrices: report.invalidPrices.length, conflicts: report.conflicts.length
  }, report });
});

route("POST", "/api/import/commit", (req, res) => {
  if (!req.user) return bad(res, "Sign in required", 401);
  if (req.user.role !== "admin") return bad(res, "Import commits require admin approval", 403);
  const p = importPreviews.get(String(req.body.token || ""));
  if (!p) return bad(res, "Preview expired — run the preview again", 410);
  importPreviews.delete(req.body.token);
  backup.backupNow("pre-import by " + req.user.email); // snapshot before bulk changes
  let created = 0, updated = 0;
  for (const rec of p.parsed) {
    const id = rec.vehicle_id || U.rid("V");
    const existing = db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(id);
    if (existing) {
      for (const k of Object.keys(rec)) if (k in existing && rec[k] !== "" && rec[k] != null) existing[k] = rec[k];
      const cols = VEHICLE_EDITABLE;
      db.prepare(`UPDATE vehicles SET ${cols.map(c => c + "=?").join(",")} WHERE vehicle_id=?`)
        .run(...cols.map(c => existing[c]), id);
      updated++;
    } else {
      db.prepare(`INSERT INTO vehicles (vehicle_id, partner_id, market, year, make, model, trim, color, vin,
          daily_rate, weekly_rate, monthly_rate, provider_rate, customer_price, provider_payout, profit,
          deposit, min_days, mileage_included, mileage_fee, delivery_areas, delivery_fee, min_age, license,
          insurance, payments, status, booked_dates, provider_contact, notes, last_verified)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,date('now'))`)
        .run(id, rec.partner_id, rec.market || process.env.TN_MARKET || "Miami", rec.year || null, rec.make, rec.model,
          rec.trim || "", rec.color || "", rec.vin || null,
          rec.daily_rate || 0, rec.weekly_rate || (rec.daily_rate || 0) * 6, rec.monthly_rate || (rec.daily_rate || 0) * 22,
          rec.provider_rate || 0, rec.customer_price || rec.daily_rate || 0, rec.provider_rate || 0,
          (rec.customer_price || rec.daily_rate || 0) - (rec.provider_rate || 0),
          rec.deposit || 0, rec.min_days || 1, rec.mileage_included || 100, rec.mileage_fee || 0,
          rec.delivery_areas || "", rec.delivery_fee || 0, rec.min_age || 25, rec.license || "", rec.insurance || "",
          rec.payments || "", ["available", "booked", "maintenance", "unavailable"].includes(rec.status) ? rec.status : "available",
          rec.booked_dates ? JSON.stringify(String(rec.booked_dates).split(";").map(s => s.trim()).filter(Boolean)) : "[]",
          rec.provider_contact || "", rec.notes || "");
      created++;
    }
    U.queueSync("PartnerInventory", db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(id));
  }
  U.audit(req.user, "import.commit", "inventory", `${created} new / ${updated} updated`, null, null, null, "previewed by " + p.by);
  json(res, 200, { ok: true, created, updated });
});

/* ============================================================
   STRIPE — hosted Checkout links + verified, idempotent webhook
   ============================================================ */
route("POST", "/api/requests/:id/stripe-link", async (req, res) => {
  if (!guard("requests.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  const category = U.strip(req.body.category || "rental-payment");
  const amount = Number(req.body.amount) || r.final_price || 0;
  if (!amount) return bad(res, "Amount required");

  if (stripe.POST_RENTAL.includes(category)) {
    /* damage / mileage / tolls: admin-only, never automatic, must be documented */
    if (req.user.role !== "admin") return bad(res, "Post-rental charges require admin review", 403);
    if (!U.strip(req.body.authorizationNote)) return bad(res, "Documented authorization (authorizationNote) is required for post-rental charges");
  } else {
    /* pre-booking money is blocked until the quote is accepted */
    if (!["Quote accepted", "Payment required", "Booking confirmed"].includes(r.status))
      return bad(res, "Payments stay blocked until provider confirmation, price approval and quote acceptance (current: " + r.status + ")");
    if (r.status === "Quote accepted") {
      db.prepare("UPDATE requests SET payment_status='link-issued' WHERE request_id=?").run(r.request_id);
      setStatus(req.user, r, "Payment required");
    }
  }
  try {
    const out = await stripe.createCheckout({
      requestId: r.request_id, category, amount,
      description: `${r.vehicle_requested} · ${category} · ${r.request_id}`,
      customerEmail: r.email
    });
    if (stripe.POST_RENTAL.includes(category))
      U.audit(req.user, "payment.postrental.link", "request", r.request_id, "category", null, `${category} $${amount} — ${U.strip(req.body.authorizationNote)}`, r.request_id);
    U.audit(req.user, "stripe.link.created", "request", r.request_id, "amount", null, amount, r.request_id);
    emails.customerEmail("PAYMENT_REQUIRED", r.email, {
      requestId: r.request_id, firstName: r.customer_name.split(" ")[0], vehicle: r.vehicle_requested,
      amount, category, payUrl: out.url
    }).catch(() => {});
    json(res, 200, out);
  } catch (e) { bad(res, e.message, 502); }
});

route("POST", "/api/stripe/webhook", async (req, res) => {
  if (!stripe.verifySignature(req.rawBody || "", req.headers["stripe-signature"])) {
    U.audit(null, "stripe.webhook.rejected", "stripe", "signature");
    return bad(res, "Invalid signature", 400);
  }
  let event;
  try { event = JSON.parse(req.rawBody); } catch (e) { return bad(res, "Bad payload"); }
  const requestId = event.data?.object?.metadata?.requestId;
  if (stripe.seenEvent(event.id, event.type, requestId))
    return json(res, 200, { ok: true, duplicate: true }); // idempotent: duplicate delivery ignored

  if (event.type === "checkout.session.completed") {
    const s = event.data.object;
    const r = requestId && db.prepare("SELECT * FROM requests WHERE request_id=?").get(requestId);
    const category = s.metadata?.category || "rental-payment";
    const amount = (s.amount_total || 0) / 100;
    if (r && r.status === "Payment required" && !stripe.POST_RENTAL.includes(category) && category !== "security-deposit") {
      const out = await confirmBooking(null, r, amount, "stripe", {
        category, customerId: s.customer || null, paymentIntent: s.payment_intent || null
      });
      if (out.error) await U.notify("admin", null, "STRIPE_CONFLICT", `Paid but not confirmable — ${requestId}`, out.error);
    } else if (r) {
      /* deposits, add-ons, post-rental: record only; admin reviews */
      db.prepare(`INSERT INTO payments (request_id, kind, category, amount, method, status, recorded_by, stripe_customer_id, stripe_payment_intent, currency)
        VALUES (?,?,?,?,?,?,?,?,?,?)`)
        .run(requestId, category === "security-deposit" ? "deposit" : "payment", category, amount, "stripe", "verified",
          "stripe-webhook", s.customer || null, s.payment_intent || null, s.currency || "usd");
      U.audit(null, "stripe.payment.recorded", "request", requestId, "category", null, `${category} $${amount}`, requestId);
      U.queueSync("Payments", { request_id: requestId, category, amount, by: "stripe" });
    }
  }
  json(res, 200, { ok: true });
});

/* ============================================================
   QUOTE ECONOMICS (internal only — admin + sales)
   ============================================================ */
route("GET", "/api/requests/:id/economics", (req, res) => {
  if (!req.user || !["admin", "sales"].includes(req.user.role)) return bad(res, req.user ? "Forbidden" : "Sign in required", req.user ? 403 : 401);
  const r = getReq(res, req.params.id); if (!r) return;
  const v = r.assigned_vehicle_id && db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(r.assigned_vehicle_id);
  const p = v && db.prepare("SELECT * FROM partners WHERE partner_id=?").get(v.partner_id);
  const days = Math.max(1, Math.round((Date.parse(r.end_date) - Date.parse(r.start_date)) / 864e5) || 1);
  const customerPrice = Number(r.final_price) || (v ? v.customer_price * days : 0);
  const model = (v && v.deal_model) || (p && p.deal_model) || "broker-markup";
  let payout;
  switch (model) {
    case "split-80-20": payout = customerPrice * 0.8; break;
    case "referral-fixed": payout = Number((p?.deal_terms.match(/\d+/) || [150])[0]); break;
    case "flat-payout": payout = v ? v.provider_payout * days : 0; break;
    default: payout = Number(r.internal_cost) || (v ? v.provider_rate * days : 0);
  }
  const delivery = Number(SETTING("delivery_fee") || 0);
  const processingFee = Math.round((customerPrice * 0.029 + 0.30) * 100) / 100;
  const gross = customerPrice - payout;
  json(res, 200, {
    days, dealModel: model, dealTerms: (v && v.deal_model ? v : p)?.deal_terms || "",
    publicRetail: v ? v.daily_rate * days : null,
    providerRate: v ? v.provider_rate * days : null,
    customerPrice, deliveryAddons: delivery,
    providerPayout: Math.round(payout * 100) / 100,
    grossProfit: Math.round(gross * 100) / 100,
    processingFee,
    netProfitEstimate: Math.round((gross - processingFee) * 100) / 100,
    rateLabel: v ? v.rate_label : null
  });
});

/* customer-communication templates (sales/cx triggered) */
route("POST", "/api/requests/:id/notify-customer", async (req, res) => {
  if (!guard("requests.write")(req, res)) return;
  const r = getReq(res, req.params.id); if (!r) return;
  const tpl = U.strip(req.body.template);
  if (!["VEHICLE_UNAVAILABLE", "ALTERNATIVE_OFFERED", "AVAILABILITY_CHECK", "QUOTE_EXPIRING", "DELIVERY_REMINDER", "RETURN_REMINDER", "DEPOSIT_STATUS"].includes(tpl))
    return bad(res, "Unknown template");
  const delivery = await emails.customerEmail(tpl, r.email, {
    requestId: r.request_id, firstName: r.customer_name.split(" ")[0], vehicle: r.vehicle_requested,
    dates: `${r.start_date} → ${r.end_date}`, amount: r.quote_amount || r.final_price,
    expires: String(r.quote_expires || "").slice(0, 10),
    altVehicle: U.strip(req.body.altVehicle || r.backup_vehicle),
    when: U.strip(req.body.when || ""), message: U.stripLong(req.body.message || ""),
    trackUrl: `${process.env.TN_BASE_URL || ""}/track.html?id=${r.request_id}&ph=${(r.phone || "").replace(/\D/g, "").slice(-4)}`
  });
  U.audit(req.user, "email.customer", "request", r.request_id, "template", null, tpl, r.request_id);
  json(res, 200, { ok: true, delivery });
});

/* ============================================================
   SETTINGS / BACKUPS / SYSTEM HEALTH (admin)
   ============================================================ */
const adminOnly = (req, res) => {
  if (!req.user) { bad(res, "Sign in required", 401); return false; }
  if (req.user.role !== "admin") { bad(res, "Admin only", 403); return false; }
  return true;
};

const EDITABLE_SETTINGS = ["business_name", "city", "address", "phone", "whatsapp", "email",
  "instagram", "hours", "policy_version", "verify_days", "doc_retention_days"];
route("GET", "/api/settings", (req, res) => {
  if (!adminOnly(req, res)) return;
  json(res, 200, Object.fromEntries(Object.entries(allSettings()).filter(([k]) => EDITABLE_SETTINGS.includes(k))));
});
route("PATCH", "/api/settings", (req, res) => {
  if (!adminOnly(req, res)) return;
  for (const k of EDITABLE_SETTINGS) {
    if (!(k in (req.body || {}))) continue;
    const old = SETTING(k);
    const val = U.strip(req.body[k]);
    if (String(old) !== String(val)) U.audit(req.user, "settings.update", "settings", k, k, old, val);
    db.prepare("INSERT INTO settings (key, value, updated_by) VALUES (?,?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=datetime('now'), updated_by=excluded.updated_by")
      .run(k, val, req.user.email);
  }
  json(res, 200, { ok: true });
});

route("GET", "/api/system/backups", (req, res) => {
  if (!adminOnly(req, res)) return;
  json(res, 200, {
    encryptionConfigured: !!process.env.BACKUP_ENCRYPTION_KEY,
    retention: Number(process.env.TN_BACKUP_RETENTION || 30),
    last: backup.lastBackup(),
    history: db.prepare("SELECT * FROM backups ORDER BY id DESC LIMIT 40").all()
  });
});
route("POST", "/api/system/backup", (req, res) => {
  if (!adminOnly(req, res)) return;
  const out = backup.backupNow("manual by " + req.user.email);
  U.audit(req.user, "backup.manual", "backup", out.file || "failed", null, null, out.ok ? "ok" : out.error);
  json(res, out.ok ? 200 : 500, out);
});

route("GET", "/api/health", (req, res) => json(res, 200, { ok: true, ts: new Date().toISOString() }));

route("GET", "/api/system/health", (req, res) => {
  if (!adminOnly(req, res)) return;
  const day = "datetime('now','-1 day')";
  const q = sql => { try { return db.prepare(sql).get(); } catch (e) { return { n: "err" }; } };
  const dirSize = d => { try { return fs.readdirSync(d).reduce((s, f) => s + fs.statSync(path.join(d, f)).size, 0); } catch (e) { return 0; } };
  const lastB = backup.lastBackup();
  json(res, 200, {
    env: process.env.TN_ENV || "staging",
    db: { ok: !!q("SELECT 1 n").n, sizeBytes: fs.existsSync(path.join(DATA_DIR, "topnotch.db")) ? fs.statSync(path.join(DATA_DIR, "topnotch.db")).size : 0 },
    backups: {
      lastOkAt: lastB?.ts || null,
      ageHours: lastB ? Math.round((Date.now() - Date.parse(lastB.ts + "Z")) / 36e5) : null,
      failures24h: q(`SELECT count(*) n FROM backups WHERE status='failed' AND ts > ${day}`).n,
      encrypted: !!process.env.BACKUP_ENCRYPTION_KEY
    },
    excelSync: {
      configured: !!process.env.EXCEL_WEBHOOK_URL,
      pending: q("SELECT count(*) n FROM sync_outbox WHERE status='pending'").n,
      failed: q("SELECT count(*) n FROM sync_outbox WHERE status='failed'").n,
      lastSuccessAt: db.prepare("SELECT sent_at FROM sync_outbox WHERE status='sent' ORDER BY id DESC LIMIT 1").get()?.sent_at || null
    },
    email: {
      configured: !!(process.env.RESEND_API_KEY || process.env.NOTIFY_EMAIL_WEBHOOK_URL),
      recordedOnly24h: q(`SELECT count(*) n FROM notifications WHERE delivery='recorded' AND ts > ${day}`).n
    },
    stripe: {
      configured: stripe.configured(),
      webhookSecretSet: !!process.env.STRIPE_WEBHOOK_SECRET,
      rejectedWebhooks24h: q(`SELECT count(*) n FROM audit WHERE action='stripe.webhook.rejected' AND ts > ${day}`).n
    },
    security: {
      failedLogins24h: q(`SELECT count(*) n FROM audit WHERE action='auth.login.failed' AND ts > ${day}`).n,
      authzDenied24h: q(`SELECT count(*) n FROM audit WHERE action='authz.denied' AND ts > ${day}`).n,
      activeSessions: q("SELECT count(*) n FROM sessions WHERE expires_at > datetime('now')").n
    },
    storage: { uploadsBytes: dirSize(UPLOAD_DIR), backupsBytes: dirSize(backup.BACKUP_DIR) },
    uploads: { failed24h: q(`SELECT count(*) n FROM audit WHERE action='upload.rejected' AND ts > ${day}`).n }
  });
});

/* ============================================================
   PARTNER PORTAL (every query scoped to the signed-in partner)
   ============================================================ */
const partnerOnly = (req, res) => {
  if (!req.user || req.user.role !== "partner" || !req.user.partner_id) { bad(res, "Partner sign-in required", 403); return false; }
  return true;
};

route("GET", "/api/portal/vehicles", (req, res) => {
  if (!partnerOnly(req, res)) return;
  const rows = db.prepare("SELECT * FROM vehicles WHERE partner_id=?").all(req.user.partner_id);
  /* own rates only — never customer_price, profit, or other providers */
  json(res, 200, rows.map(v => pick(v, ["vehicle_id", "fleet_id", "year", "make", "model", "trim", "color", "vin",
    "provider_rate", "provider_payout", "deposit", "min_days", "mileage_included", "mileage_fee",
    "delivery_areas", "delivery_fee", "status", "booked_dates", "last_verified", "notes", "photos"])));
});
route("POST", "/api/portal/vehicles", (req, res) => {
  if (!partnerOnly(req, res)) return;
  const b = req.body || {};
  if (!b.make || !b.model) return bad(res, "Make and model required");
  const id = U.rid("V");
  db.prepare(`INSERT INTO vehicles (vehicle_id, partner_id, market, year, make, model, trim, color,
      provider_rate, deposit, mileage_included, mileage_fee, min_days, status, booked_dates, last_verified)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?, 'available','[]', date('now'))`)
    .run(id, req.user.partner_id, process.env.TN_MARKET || "Miami", Number(b.year) || null, U.strip(b.make), U.strip(b.model),
      U.strip(b.trim), U.strip(b.color), Number(b.provider_rate) || 0, Number(b.deposit) || 0,
      Number(b.mileage_included) || 100, Number(b.mileage_fee) || 0, Number(b.min_days) || 1);
  U.audit(req.user, "portal.vehicle.create", "vehicle", id);
  U.queueSync("PartnerInventory", db.prepare("SELECT * FROM vehicles WHERE vehicle_id=?").get(id));
  json(res, 200, { ok: true, vehicleId: id });
});
route("PATCH", "/api/portal/vehicles/:id", (req, res) => {
  if (!partnerOnly(req, res)) return;
  const v = db.prepare("SELECT * FROM vehicles WHERE vehicle_id=? AND partner_id=?").get(req.params.id, req.user.partner_id);
  if (!v) return bad(res, "Not found", 404); /* other providers' units are invisible */
  applyVehiclePatch(req, res, v, req.body || {},
    ["provider_rate", "deposit", "mileage_included", "mileage_fee", "min_days", "status", "booked_dates", "last_verified", "notes", "color", "trim", "year"]);
});
route("DELETE", "/api/portal/vehicles/:id", (req, res) => {
  if (!partnerOnly(req, res)) return;
  const v = db.prepare("SELECT * FROM vehicles WHERE vehicle_id=? AND partner_id=?").get(req.params.id, req.user.partner_id);
  if (!v) return bad(res, "Not found", 404);
  db.prepare("DELETE FROM vehicles WHERE vehicle_id=?").run(v.vehicle_id);
  U.audit(req.user, "portal.vehicle.delete", "vehicle", v.vehicle_id);
  json(res, 200, { ok: true });
});

route("GET", "/api/portal/bookings", (req, res) => {
  if (!partnerOnly(req, res)) return;
  const mine = new Set(db.prepare("SELECT vehicle_id FROM vehicles WHERE partner_id=?").all(req.user.partner_id).map(v => v.vehicle_id));
  const rows = db.prepare(`SELECT * FROM requests WHERE assigned_vehicle_id IS NOT NULL
      AND status IN ('Availability being confirmed','Provider confirmed','Approved','Quote sent','Quote accepted','Payment required','Booking confirmed','Completed')`)
    .all().filter(r => mine.has(r.assigned_vehicle_id));
  json(res, 200, rows.map(r => ({
    requestId: r.request_id, vehicleId: r.assigned_vehicle_id, status: r.status,
    startDate: r.start_date, endDate: r.end_date,
    deliveryArea: r.option === "pickup" ? "Showroom handover" : r.delivery_location,
    /* customer details only after confirmation */
    customer: ["Booking confirmed", "Completed"].includes(r.status) ? r.customer_name : "Shared after confirmation",
    customerPhone: ["Booking confirmed", "Completed"].includes(r.status) ? r.phone : null,
    needsDecision: r.status === "Availability being confirmed"
  })));
});
route("POST", "/api/portal/bookings/:id/decision", async (req, res) => {
  if (!partnerOnly(req, res)) return;
  const r = db.prepare("SELECT * FROM requests WHERE request_id=?").get(req.params.id);
  if (!r) return bad(res, "Not found", 404);
  const v = r.assigned_vehicle_id && db.prepare("SELECT * FROM vehicles WHERE vehicle_id=? AND partner_id=?").get(r.assigned_vehicle_id, req.user.partner_id);
  if (!v) return bad(res, "This booking is not assigned to your fleet", 403);
  providerDecision(req, res, r, req.body.decision === "confirm" ? "confirm" : "decline", req.body.note, req.user);
});

route("GET", "/api/portal/payouts", (req, res) => {
  if (!partnerOnly(req, res)) return;
  const rows = db.prepare("SELECT rental_id, vehicle, pickup_date, return_date, provider_payout, payout_paid, payout_questioned, return_status FROM rentals WHERE partner_id=?").all(req.user.partner_id);
  json(res, 200, rows);
});
route("POST", "/api/portal/payouts/:rentalId/question", async (req, res) => {
  if (!partnerOnly(req, res)) return;
  const x = db.prepare("SELECT * FROM rentals WHERE rental_id=? AND partner_id=?").get(req.params.rentalId, req.user.partner_id);
  if (!x) return bad(res, "Not found", 404);
  db.prepare("UPDATE rentals SET payout_questioned='Yes' WHERE rental_id=?").run(x.rental_id);
  U.audit(req.user, "payout.questioned", "rental", x.rental_id, "payout_questioned", "No", "Yes", x.request_id);
  await U.notify("admin", null, "PAYOUT_QUESTIONED", `Payout questioned — ${x.rental_id}`, `${req.user.name}: "${U.strip(req.body.note || "")}"`);
  json(res, 200, { ok: true });
});

route("GET", "/api/portal/messages", (req, res) => {
  if (!partnerOnly(req, res)) return;
  json(res, 200, db.prepare("SELECT * FROM messages WHERE partner_id=? ORDER BY ts").all(req.user.partner_id));
});
route("POST", "/api/portal/messages", async (req, res) => {
  if (!partnerOnly(req, res)) return;
  const body = U.stripLong(req.body.body);
  if (!body) return bad(res, "Empty message");
  db.prepare("INSERT INTO messages (partner_id, from_email, from_role, body) VALUES (?,?,?,?)")
    .run(req.user.partner_id, req.user.email, "partner", body);
  await U.notify("ops", null, "PARTNER_MESSAGE", `Message from ${req.user.name}`, body.slice(0, 200));
  json(res, 200, { ok: true });
});
route("POST", "/api/messages", (req, res) => { /* staff reply */
  if (!req.user || req.user.role === "partner") return bad(res, "Staff only", 403);
  db.prepare("INSERT INTO messages (partner_id, from_email, from_role, body) VALUES (?,?,?,?)")
    .run(U.strip(req.body.partnerId), req.user.email, req.user.role, U.stripLong(req.body.body));
  json(res, 200, { ok: true });
});
route("GET", "/api/messages/:partnerId", (req, res) => {
  if (!req.user || req.user.role === "partner") return bad(res, "Staff only", 403);
  json(res, 200, db.prepare("SELECT * FROM messages WHERE partner_id=? ORDER BY ts").all(req.params.partnerId));
});

/* ============================================================
   HTTP PLUMBING — body parse, cookies, static files, logging
   ============================================================ */
const MIME = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".png": "image/png",
  ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".woff2": "font/woff2", ".mp4": "video/mp4", ".ico": "image/x-icon" };

const server = http.createServer(async (req, res) => {
  const t0 = Date.now();
  res.on("finish", () => U.logReq(req, res, Date.now() - t0));
  try {
    const url = new URL(req.url, "http://x");
    req.query = Object.fromEntries(url.searchParams);
    req.ip = (req.headers["x-forwarded-for"] || "").split(",")[0].trim() || req.socket.remoteAddress;
    req.token = (req.headers.cookie || "").split(/;\s*/).find(c => c.startsWith("tn_sess="))?.slice(8) || null;
    req.user = auth.sessionUser(req.token);

    if (url.pathname.startsWith("/api/")) {
      if (["POST", "PATCH", "PUT", "DELETE"].includes(req.method)) {
        req.rawBody = await new Promise((resolve, reject) => {
          let size = 0; const chunks = [];
          req.on("data", c => { size += c.length; if (size > 8 * 1024 * 1024) { reject(new Error("Payload too large")); req.destroy(); } else chunks.push(c); });
          req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
          req.on("error", reject);
        });
        try { req.body = req.rawBody ? JSON.parse(req.rawBody) : {}; } catch (e) { req.body = {}; }
      }
      for (const r of routes) {
        if (r.method !== req.method) continue;
        const m = url.pathname.match(r.re);
        if (!m) continue;
        req.params = m.groups || {};
        return await r.handler(req, res);
      }
      return bad(res, "Not found", 404);
    }

    /* static site — never serve server code or data */
    let p = path.normalize(path.join(SITE_DIR, decodeURIComponent(url.pathname)));
    if (!p.startsWith(SITE_DIR)) return bad(res, "Forbidden", 403);
    if (fs.existsSync(p) && fs.statSync(p).isDirectory()) p = path.join(p, "index.html");
    if (!fs.existsSync(p)) return bad(res, "Not found", 404);
    res.writeHead(200, { "Content-Type": MIME[path.extname(p)] || "application/octet-stream" });
    fs.createReadStream(p).pipe(res);
  } catch (e) {
    console.error("[error]", req.method, req.url, e.message);
    if (!res.headersSent) bad(res, "Server error", 500);
  }
});

/* Excel sync worker */
setInterval(() => U.drainOutbox().catch(() => {}), 60e3).unref();

/* daily housekeeping: encrypted backup, document retention,
   stale-verification alerts, quote-expiring emails */
backup.schedule();
async function dailyTick() {
  /* delete expired customer documents (photos of licenses etc.) */
  const days = Number(SETTING("doc_retention_days") || 90);
  const old = db.prepare(`SELECT * FROM uploads WHERE kind='document' AND ts < datetime('now', ?)`).all(`-${days} days`);
  for (const u of old) {
    try { fs.unlinkSync(u.path); } catch (e) { /* gone */ }
    db.prepare("DELETE FROM uploads WHERE id=?").run(u.id);
    U.audit(null, "upload.retention.delete", "upload", u.id, "kind", u.kind, null, u.rental_id);
  }
  /* stale availability → alert partnerships (once per unit per day) */
  for (const v of publishableUnits().filter(v => v.stale)) {
    const dupe = db.prepare("SELECT 1 FROM notifications WHERE type='STALE_VERIFICATION' AND body LIKE ? AND ts > datetime('now','-1 day')").get(`%${v.vehicle_id}%`);
    if (!dupe) await U.notify("partnerships", null, "STALE_VERIFICATION",
      `Availability on request — ${v.year} ${v.make} ${v.model}`,
      `Unit ${v.vehicle_id} has not been verified in over ${SETTING("verify_days")} days. It now shows "Availability on request" and instant quoting is paused.`);
  }
  /* quote-expiring reminders (within 24h) */
  const expiring = db.prepare(`SELECT * FROM requests WHERE status='Quote sent'
    AND quote_expires BETWEEN datetime('now') AND datetime('now','+1 day')`).all();
  for (const r of expiring) {
    const dupe = db.prepare("SELECT 1 FROM notifications WHERE type='CUSTOMER_QUOTE_EXPIRING' AND title LIKE ?").get(`%${r.request_id}%`);
    if (!dupe) emails.customerEmail("QUOTE_EXPIRING", r.email, {
      requestId: r.request_id, firstName: r.customer_name.split(" ")[0], vehicle: r.vehicle_requested,
      amount: r.quote_amount, expires: String(r.quote_expires).slice(0, 10),
      trackUrl: `${process.env.TN_BASE_URL || ""}/track.html?id=${r.request_id}&ph=${(r.phone || "").replace(/\D/g, "").slice(-4)}`
    }).catch(() => {});
  }
}
dailyTick().catch(() => {});
setInterval(() => dailyTick().catch(() => {}), 6 * 36e5).unref();

if (require.main === module) {
  server.listen(PORT, () => console.log(`TopNotchRentalz server → http://localhost:${PORT}  (site: ${SITE_DIR})`));
}
module.exports = { server, PORT };
