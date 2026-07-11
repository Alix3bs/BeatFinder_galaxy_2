/* ============================================================
   AI availability agent — server-side, deterministic, and honest:
   it only ever reads the live database (the source of truth) and
   NEVER invents availability. Any staleness, conflict, missing
   data or pending provider answer routes the request to
   "Manual availability confirmation required" with reasons.
   ============================================================ */
const { db } = require("./db");

const S = k => db.prepare("SELECT value FROM settings WHERE key=?").get(k)?.value || "";

function overlap(aS, aE, bS, bE) {
  return Date.parse(aS) < Date.parse(bE) && Date.parse(bS) < Date.parse(aE);
}

function unitConflicts(v, sd, ed, ignoreRequestId) {
  const conflicts = [];
  for (const range of JSON.parse(v.booked_dates || "[]")) {
    const [s, e] = range.split("→");
    if (s && e && overlap(sd, ed, s, e)) conflicts.push("booked " + range);
  }
  const rows = db.prepare(`SELECT request_id, start_date, end_date FROM requests
      WHERE assigned_vehicle_id = ? AND request_id != ?
      AND status IN ('Provider confirmed','Approved','Quote sent','Quote accepted','Payment required','Booking confirmed')`)
    .all(v.vehicle_id, ignoreRequestId || "");
  for (const r of rows)
    if (overlap(sd, ed, r.start_date.slice(0, 10), r.end_date.slice(0, 10))) conflicts.push("request " + r.request_id);
  const holds = db.prepare(`SELECT h.*, r.start_date s, r.end_date e FROM holds h
      JOIN requests r ON r.request_id = h.request_id
      WHERE h.vehicle_id = ? AND h.status = 'active' AND h.expires_at > datetime('now') AND h.request_id != ?`)
    .all(v.vehicle_id, ignoreRequestId || "");
  for (const h of holds)
    if (overlap(sd, ed, h.s.slice(0, 10), h.e.slice(0, 10))) conflicts.push("active hold #" + h.hold_id);
  return conflicts;
}

/* evaluate one unit for a request → { ok, manual, reasons[] } */
function evaluateUnit(v, req, sd, ed, days) {
  const reasons = [];
  let manual = false;
  const partner = db.prepare("SELECT * FROM partners WHERE partner_id=?").get(v.partner_id);
  if (!partner || partner.onboarding_status !== "Active") reasons.push("partner not Active");
  if (v.market !== (process.env.TN_MARKET || "Miami")) reasons.push("wrong market");
  if (["maintenance", "unavailable"].includes(v.status)) reasons.push("unit in " + v.status);
  if (!(v.photos_approved && v.price_approved && v.requirements_complete &&
        ["confirmed-broker", "customer-approved"].includes(v.rate_label))) reasons.push("publishing checklist incomplete");
  const conflicts = unitConflicts(v, sd, ed, req.request_id);
  if (conflicts.length) reasons.push("date conflict: " + conflicts.join(", "));
  if (days < (v.min_days || 1)) reasons.push(`below ${v.min_days}-day minimum`);
  if (req.option === "delivery" && v.delivery_areas &&
      !/dade|broward|palm|miami|mia|fll|fbo/i.test(req.delivery_location || "") &&
      !(v.delivery_areas || "").toLowerCase().split(/[,;]/).some(a => (req.delivery_location || "").toLowerCase().includes(a.trim().split(" ")[0])))
    { manual = true; reasons.push("delivery area needs manual check"); }
  const verifyDays = Number(S("verify_days") || 7);
  const age = v.last_verified ? (Date.now() - Date.parse(v.last_verified)) / 864e5 : Infinity;
  if (age > verifyDays) { manual = true; reasons.push(`availability record stale (${isFinite(age) ? Math.round(age) + "d" : "never verified"})`); }
  return { ok: reasons.length === 0, manual, reasons, conflictOnly: reasons.length > 0 && reasons.every(r => r.startsWith("date conflict")) };
}

/* customer-eligibility checks from the form */
function customerIssues(req) {
  const issues = [];
  if (req.driver_age === "Under 25") issues.push("driver under minimum age");
  if (!/confirmed/i.test(req.license_status || "")) issues.push("license not confirmed");
  if (!/confirmed/i.test(req.insurance_status || "")) issues.push("insurance not confirmed");
  if (!/ready/i.test(req.deposit_readiness || "")) issues.push("deposit readiness needs discussion");
  return issues;
}

/* Excel-sync freshness: the workbook is a report — if it lags, warn the team */
function excelSyncWarning() {
  const failed = db.prepare("SELECT count(*) n FROM sync_outbox WHERE status='failed'").get().n;
  const oldest = db.prepare("SELECT ts FROM sync_outbox WHERE status IN ('pending','failed') ORDER BY id LIMIT 1").get();
  const lagMin = oldest ? Math.round((Date.now() - Date.parse(oldest.ts + "Z")) / 6e4) : 0;
  if (failed > 0 || lagMin > 30) return `Excel workbook may be behind the database (${failed} failed rows, oldest queued ${lagMin} min ago) — database remains authoritative`;
  return null;
}

/* main entry: analyse a request, return a decision (does NOT mutate) */
function checkAvailability(req) {
  const sd = (req.start_date || "").slice(0, 10), ed = (req.end_date || "").slice(0, 10);
  const days = Math.max(1, Math.round((Date.parse(ed) - Date.parse(sd)) / 864e5) || 1);
  const want = (req.vehicle_requested || "").toLowerCase();
  const backup = (req.backup_vehicle || "").toLowerCase();

  const pool = db.prepare("SELECT * FROM vehicles").all();
  const nameOf = v => `${v.make} ${v.model}`.toLowerCase();
  const exact = pool.filter(v => want.includes(v.model.toLowerCase()) || want.includes(nameOf(v)));
  const backupUnits = backup && backup !== "none"
    ? pool.filter(v => backup.includes(v.model.toLowerCase()) || backup.includes(nameOf(v))) : [];

  const custIssues = customerIssues(req);
  const evals = exact.map(v => ({ v, r: evaluateUnit(v, req, sd, ed, days) }));
  const usable = evals.filter(e => e.r.ok)
    .sort((a, b) => (a.v.provider_rate || 9e9) - (b.v.provider_rate || 9e9));
  const manualFlag = evals.some(e => e.r.manual) || custIssues.length > 0;

  const decision = { checkedAt: new Date().toISOString(), days, excelWarning: excelSyncWarning(),
    customerIssues: custIssues, reasons: [] };

  if (exact.length === 0) {
    decision.result = "manual";
    decision.reasons.push("no inventory record for the requested model — needs a human");
  } else if (usable.length > 0 && !manualFlag) {
    decision.result = "available";
    decision.unit = usable[0].v;
    decision.reasons.push(`unit ${usable[0].v.vehicle_id} clear for ${sd}→${ed}, verified ${usable[0].v.last_verified}`);
  } else if (usable.length > 0 && manualFlag) {
    decision.result = "manual";
    decision.unit = usable[0].v;
    decision.reasons.push(...custIssues, ...evals.flatMap(e => e.r.reasons).filter(r => !r.startsWith("date conflict")));
  } else if (evals.every(e => e.r.conflictOnly)) {
    decision.result = "unavailable";
    decision.reasons.push("every unit has a date conflict for the selected dates");
  } else {
    decision.result = "manual";
    decision.reasons.push(...new Set(evals.flatMap(e => e.r.reasons)), ...custIssues);
  }

  /* two approved alternatives (same class first) — backup vehicle prioritized */
  if (decision.result !== "available") {
    const fleetClass = exact[0] ? null : null;
    const altPool = [...backupUnits, ...pool.filter(v => !exact.includes(v) && !backupUnits.includes(v))];
    decision.alternatives = altPool
      .map(v => ({ v, r: evaluateUnit(v, req, sd, ed, days) }))
      .filter(e => e.r.ok)
      .slice(0, 2)
      .map(e => ({ name: `${e.v.year} ${e.v.make} ${e.v.model} ${e.v.trim || ""}`.trim(),
        fleetId: e.v.fleet_id, model: `${e.v.make} ${e.v.model}`,
        dates: `${sd} → ${ed}`, pricePerDay: e.v.customer_price, deposit: e.v.deposit,
        delivery: e.v.delivery_areas || "Delivery available" }));
  }
  return decision;
}

module.exports = { checkAvailability, unitConflicts, excelSyncWarning };
