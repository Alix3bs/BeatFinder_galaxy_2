/* ============================================================
   TopNotchRentalz — Operations Dashboard
   Requests → matching → approval → rental → payout, all synced
   to localStorage + the Excel webhook (WEBHOOKS.sheet).
   ============================================================ */

const $ = (s, c) => (c || document).querySelector(s);
const $$ = (s, c) => Array.from((c || document).querySelectorAll(s));
const money = n => "$" + Number(n || 0).toLocaleString();
const today = () => new Date().toISOString().slice(0, 10);

/* ---------- stores ---------- */
const store = {
  get(k, seed) {
    const raw = localStorage.getItem(k);
    if (raw) { try { return JSON.parse(raw); } catch (e) { /* fallthrough */ } }
    if (seed) { localStorage.setItem(k, JSON.stringify(seed)); return JSON.parse(JSON.stringify(seed)); }
    return [];
  },
  set(k, v) { localStorage.setItem(k, JSON.stringify(v)); }
};
let INV = store.get("tn_inventory", SEED_INVENTORY);
let PARTNERS = store.get("tn_partners", SEED_PARTNERS);
let REQS = store.get("tn_requests");
let RENTALS = store.get("tn_rentals");
const INQUIRIES = () => store.get("tn_partner_inquiries");

function saveInv() { store.set("tn_inventory", INV); pushVehicleStatus(); }
function savePartners() { store.set("tn_partners", PARTNERS); }
function saveReqs() { store.set("tn_requests", REQS); }
function saveRentals() { store.set("tn_rentals", RENTALS); }

/* reflect inventory availability onto the customer site:
   a public FLEET id shows "available" if ANY linked provider unit is available */
function pushVehicleStatus() {
  const map = {};
  INV.forEach(v => {
    if (!v.fleetId) return;
    const cur = map[v.fleetId];
    if (v.status === "available") map[v.fleetId] = "available";
    else if (!cur) map[v.fleetId] = v.status;
  });
  localStorage.setItem("tn_vehicle_status", JSON.stringify(map));
}

async function sync(table, row) {
  if (!WEBHOOKS.sheet) return;
  try {
    await fetch(WEBHOOKS.sheet, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ table, row }) });
  } catch (e) { console.warn("Excel webhook unreachable", e); }
}

/* ---------- CSV export (opens straight in Excel) ---------- */
function toCSV(rows) {
  if (!rows.length) return "";
  const cols = [...new Set(rows.flatMap(r => Object.keys(r)))].filter(c => c !== "inspectionPhotos");
  const esc = v => `"${String(v ?? "").replace(/"/g, '""')}"`;
  return [cols.join(","), ...rows.map(r => cols.map(c => esc(r[c])).join(","))].join("\n");
}
function downloadCSV(name, rows) {
  const blob = new Blob(["﻿" + toCSV(rows)], { type: "text/csv;charset=utf-8" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = name + "-" + today() + ".csv";
  a.click();
  URL.revokeObjectURL(a.href);
}

/* ---------- gate ---------- */
const gate = $("#gate"), app = $("#app");
function unlock() { gate.hidden = true; app.hidden = false; renderAll(); }
if (sessionStorage.getItem("tn_admin") === "1") unlock();
$("#gateBtn").addEventListener("click", tryPass);
$("#gatePass").addEventListener("keydown", e => { if (e.key === "Enter") tryPass(); });
function tryPass() {
  if ($("#gatePass").value === ADMIN_PASS) {
    sessionStorage.setItem("tn_admin", "1");
    unlock();
  } else {
    $("#gatePass").value = "";
    $("#gatePass").placeholder = "Wrong passcode";
  }
}

/* ---------- tabs ---------- */
$$("#sideNav button").forEach(b => b.addEventListener("click", () => {
  $$("#sideNav button").forEach(x => x.classList.toggle("on", x === b));
  $$(".tab").forEach(t => (t.hidden = t.id !== "tab-" + b.dataset.tab));
  renderAll();
}));
$("#exportAll").addEventListener("click", () => {
  downloadCSV("PartnerInventory", INV);
  downloadCSV("CustomerRequests", REQS);
  downloadCSV("ActiveRentals", RENTALS);
  downloadCSV("Partners", PARTNERS);
});

/* ============================================================
   VEHICLE MATCHING
   Same model across all approved providers in the right market
   → two lowest provider rates. Falls back to similar class.
   ============================================================ */
function rentalDays(req) {
  const s = new Date(req.startDate), e = new Date(req.endDate);
  const d = Math.round((e - s) / 864e5);
  return isNaN(d) || d < 1 ? 1 : d;
}
function findMatches(req) {
  const want = (req.vehicleRequested || "").toLowerCase();
  const approved = new Set(PARTNERS.filter(p => p.status === "Approved").map(p => p.partnerId));
  const pool = INV.filter(v => approved.has(v.partnerId) && v.market === BUSINESS.market);
  const exact = pool.filter(v => want.includes(v.model.toLowerCase()) || want.includes((v.make + " " + v.model).toLowerCase()));
  const fleetCar = FLEET.find(f => f.name === req.vehicleRequested);
  const similar = fleetCar
    ? pool.filter(v => !exact.includes(v) && FLEET.some(f => f.id === v.fleetId && f.cat === fleetCar.cat))
    : [];
  const rank = list => list
    .sort((a, b) => (a.status === "available" ? 0 : 1) - (b.status === "available" ? 0 : 1) || a.providerRate - b.providerRate);
  return { exact: rank(exact).slice(0, 4), similar: rank(similar).slice(0, 2), days: rentalDays(req) };
}

/* ============================================================
   RENDERERS
   ============================================================ */
let selReq = null, selRental = null;

function renderAll() {
  REQS = store.get("tn_requests");
  $("#reqCount").textContent = REQS.filter(r => r.status === STATUS_FLOW[0]).length || "";
  renderDash(); renderRequests(); renderInventory(); renderPartners(); renderRentals();
}

/* ----- dashboard + reminders ----- */
function reminders() {
  const out = [];
  REQS.forEach(r => {
    if (r.status === STATUS_FLOW[0]) out.push({ t: `Confirm availability with provider — ${r.vehicleRequested} for ${r.customerName}`, w: r.requestId });
    if (r.status === STATUS_FLOW[1]) out.push({ t: `Chasing provider — follow up on ${r.vehicleRequested} (${r.requestId})`, w: "availability" });
    if (r.status === "Approved") out.push({ t: `Send payment link to ${r.customerName} — ${r.vehicleRequested}`, w: "payment" });
    if (r.status === "Payment required") out.push({ t: `Awaiting payment from ${r.customerName} (${r.phone})`, w: "payment" });
  });
  RENTALS.forEach(x => {
    const t = today();
    if (x.pickupStatus !== "Done" && x.pickupDate && x.pickupDate.slice(0, 10) <= t)
      out.push({ t: `${x.deliveryAddress && x.deliveryAddress !== "Showroom" ? "Deliver" : "Hand over"} ${x.vehicle} to ${x.customer}`, w: x.pickupDate });
    if (x.returnStatus !== "Done" && x.returnDate && x.returnDate.slice(0, 10) <= t)
      out.push({ t: `Vehicle return due — ${x.vehicle} from ${x.customer}`, w: x.returnDate });
    if (x.returnStatus === "Done" && x.depositRefunded !== "Yes")
      out.push({ t: `Refund deposit ${money(x.deposit)} to ${x.customer}`, w: "deposit" });
    if (x.returnStatus === "Done" && x.payoutPaid !== "Yes")
      out.push({ t: `Pay provider ${x.provider} — ${money(x.providerPayout)}`, w: "payout" });
    if (x.returnStatus === "Done" && x.reviewRequested !== "Yes")
      out.push({ t: `Request a review from ${x.customer}`, w: "review" });
  });
  INV.forEach(v => {
    const age = (new Date(today()) - new Date(v.lastVerified || 0)) / 864e5;
    if (age > 5) out.push({ t: `Re-verify availability — ${v.year} ${v.make} ${v.model} @ ${v.provider}`, w: `${Math.round(age)}d old` });
  });
  return out;
}

function renderDash() {
  const el = $("#tab-dash");
  const newReqs = REQS.filter(r => r.status === STATUS_FLOW[0]).length;
  const confirming = REQS.filter(r => r.status === STATUS_FLOW[1]).length;
  const awaitingPay = REQS.filter(r => ["Approved", "Payment required"].includes(r.status)).length;
  const active = RENTALS.filter(x => x.returnStatus !== "Done").length;
  const revenue = RENTALS.reduce((s, x) => s + Number(x.amountPaid || 0), 0);
  const profit = RENTALS.reduce((s, x) => s + Number(x.profit || 0), 0);
  const rem = reminders();
  el.innerHTML = `
    <h1>Operations</h1>
    <p class="sub">${BUSINESS.name} · ${BUSINESS.market} · ${today()}</p>
    <div class="stat-row">
      <div class="stat"><b>${newReqs}</b><span>New requests</span></div>
      <div class="stat"><b>${confirming}</b><span>Confirming availability</span></div>
      <div class="stat"><b>${awaitingPay}</b><span>Awaiting payment</span></div>
      <div class="stat"><b>${active}</b><span>Active rentals</span></div>
      <div class="stat"><b>${money(revenue)}</b><span>Collected</span></div>
      <div class="stat"><b>${money(profit)}</b><span>Profit booked</span></div>
    </div>
    <div class="panel">
      <div class="panel-head"><h2>Reminders (${rem.length})</h2></div>
      ${rem.length ? rem.map(r => `<div class="rem-item"><span class="rem-dot"></span>${r.t}<span class="rem-when">${r.w}</span></div>`).join("")
        : '<p class="fineprint">Nothing pending. Clean board.</p>'}
    </div>`;
}

/* ----- requests ----- */
function statusBadge(s) {
  const cls = s === "Booking confirmed" ? "ok" : ["Declined", "Cancelled"].includes(s) ? "bad" : s === STATUS_FLOW[0] ? "warn" : "dim";
  return `<span class="badge ${cls}">${s}</span>`;
}

function renderRequests() {
  const el = $("#tab-requests");
  el.innerHTML = `
    <h1>Customer Requests</h1>
    <p class="sub">Nothing is auto-confirmed — every request needs a human yes.</p>
    <div class="panel">
      <div class="panel-head">
        <h2>All requests (${REQS.length})</h2>
        <button class="btn btn-ghost btn-mini" id="expReq">Export CSV</button>
      </div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>Request</th><th>Customer</th><th>Vehicle</th><th>Dates</th><th>Budget</th><th>Deposit</th><th>Status</th><th></th></tr>
        ${[...REQS].reverse().map(r => `
          <tr class="${selReq === r.requestId ? "sel" : ""}">
            <td><b>${r.requestId}</b><br><span style="color:var(--muted)">${(r.timestamp || "").slice(0, 10)}</span></td>
            <td>${r.customerName}<br><span style="color:var(--muted)">${r.phone}</span></td>
            <td>${r.vehicleRequested}${r.backupVehicle && r.backupVehicle !== "None" ? `<br><span style="color:var(--muted)">alt: ${r.backupVehicle}</span>` : ""}</td>
            <td>${(r.startDate || "").slice(0, 10)} →<br>${(r.endDate || "").slice(0, 10)}</td>
            <td>${r.budget || "—"}</td>
            <td>${r.depositReadiness || "—"}</td>
            <td>${statusBadge(r.status)}</td>
            <td class="act" data-open="${r.requestId}">Open →</td>
          </tr>`).join("")}
      </table></div>
    </div>
    <div id="reqDetail"></div>`;
  $("#expReq").addEventListener("click", () => downloadCSV("CustomerRequests", REQS));
  $$("[data-open]", el).forEach(a => a.addEventListener("click", () => { selReq = a.dataset.open; renderRequestDetail(); }));
  if (selReq) renderRequestDetail();
}

function renderRequestDetail() {
  const r = REQS.find(x => x.requestId === selReq);
  const box = $("#reqDetail");
  if (!r || !box) return;
  const m = findMatches(r);
  const days = m.days;
  const matches = m.exact.length ? m.exact : m.similar;
  const best2 = matches.slice(0, 2);

  box.innerHTML = `
    <div class="panel">
      <div class="panel-head">
        <h2>${r.requestId} — ${r.vehicleRequested}</h2>
        <div style="display:flex;gap:8px;flex-wrap:wrap">
          <a class="btn btn-ghost btn-mini" href="https://wa.me/${(r.phone || "").replace(/\D/g, "")}" target="_blank">WhatsApp customer</a>
          <a class="btn btn-ghost btn-mini" href="mailto:${r.email}">Email</a>
          <button class="btn btn-chrome btn-mini" id="genSummary">Booking Summary</button>
        </div>
      </div>

      <div class="detail-grid">
        <div class="kv"><i>Customer</i><b>${r.customerName} · ${r.phone}<br>${r.email}</b></div>
        <div class="kv"><i>Dates (${days} day${days > 1 ? "s" : ""})</i><b>${r.startDate} →<br>${r.endDate}</b></div>
        <div class="kv"><i>${r.option === "pickup" ? "Showroom pickup" : "Delivery"}</i><b>${r.deliveryLocation}<br>Return: ${r.returnLocation}</b></div>
        <div class="kv"><i>Driver</i><b>Age ${r.driverAge} · License: ${r.licenseStatus}<br>Insurance: ${r.insuranceStatus}</b></div>
        <div class="kv"><i>Budget / deposit</i><b>${r.budget} · Deposit ${r.depositReadiness}</b></div>
        <div class="kv"><i>Occasion / notes</i><b>${r.occasion || "—"} · ${r.specialRequests}</b></div>
        <div class="kv"><i>Add-ons</i><b>${r.addons}</b></div>
        <div class="kv"><i>Quoted</i><b>${r.quotedDayRate} · Chauffeur: ${r.chauffeurNeeded} · FBO: ${r.fboPickup}</b></div>
      </div>

      <h2 style="margin:18px 0 10px">Provider matching ${m.exact.length ? "" : "· no exact match — comparable class shown"}</h2>
      ${matches.length ? matches.map((v, i) => {
        const profit = (Number(r.finalCustomerPrice) || v.customerPrice * days) - v.providerRate * days;
        return `
        <div class="match-card ${i < 2 ? "best" : ""}">
          <div>
            <b>${v.year} ${v.make} ${v.model} ${v.trim} · ${v.color}</b>
            <span style="font-size:11.5px;color:var(--muted)">${v.provider} · ${v.providerContact} · verified ${v.lastVerified}
            ${v.status !== "available" ? ` · <span class="badge bad">${v.status}</span>` : ` · <span class="badge ok">available</span>`}
            ${v.bookedDates ? ` · booked: ${v.bookedDates}` : ""}</span>
          </div>
          <div class="mc-nums">
            <span><i>Provider rate</i>${money(v.providerRate)}/day</span>
            <span><i>Customer price</i>${money(v.customerPrice)}/day</span>
            <span><i>Profit (${days}d)</i><b style="color:var(--orange)">${money(profit)}</b></span>
          </div>
          <button class="btn btn-primary btn-mini" data-assign="${v.vehicleId}">Assign</button>
        </div>`;
      }).join("") : '<p class="fineprint">No approved provider offers this model in this market yet — add it in Inventory.</p>'}
      ${best2.length ? `<p class="fineprint">Two lowest approved rates: ${best2.map(v => `${v.provider} ${money(v.providerRate)}/day`).join(" · ")}. Customers only ever see the TopNotchRentalz price.</p>` : ""}

      <h2 style="margin:18px 0 10px">Decision</h2>
      <div class="frm">
        <div><label>Status</label>
          <select class="f-select" id="dStatus">
            ${[...STATUS_FLOW, ...STATUS_OTHER].map(s => `<option ${r.status === s ? "selected" : ""}>${s}</option>`).join("")}
          </select></div>
        <div><label>Assigned provider unit</label>
          <select class="f-select" id="dProvider">
            <option value="">— none —</option>
            ${INV.map(v => `<option value="${v.vehicleId}" ${r.assignedProvider === v.vehicleId ? "selected" : ""}>${v.vehicleId} · ${v.make} ${v.model} · ${v.provider}</option>`).join("")}
          </select></div>
        <div><label>Final customer price (total)</label><input class="f-input" id="dFinal" value="${r.finalCustomerPrice || ""}" placeholder="e.g. ${matches[0] ? matches[0].customerPrice * days : ""}"></div>
        <div><label>Internal cost (provider total)</label><input class="f-input" id="dCost" value="${r.internalCost || ""}" placeholder="e.g. ${matches[0] ? matches[0].providerRate * days : ""}"></div>
        <div><label>Profit</label><input class="f-input" id="dProfit" value="${r.profit || ""}" placeholder="auto" readonly style="opacity:.8"></div>
      </div>
      <div style="display:flex;gap:10px;flex-wrap:wrap;margin-top:14px">
        <button class="btn btn-primary btn-mini" id="dSave">Save</button>
        <button class="btn btn-chrome btn-mini" id="dApprove">Approve</button>
        <button class="btn btn-ghost btn-mini" id="dConfirm">Confirm Booking → Active Rental</button>
        <button class="btn btn-ghost btn-mini" id="dDecline" style="border-color:rgba(239,68,68,.5);color:#f87171">Decline</button>
      </div>
    </div>`;

  const recalc = () => {
    const f = Number($("#dFinal").value) || 0, c = Number($("#dCost").value) || 0;
    $("#dProfit").value = f && c ? f - c : "";
  };
  ["dFinal", "dCost"].forEach(id => $("#" + id).addEventListener("input", recalc));

  $$("[data-assign]", box).forEach(b => b.addEventListener("click", () => {
    const v = INV.find(x => x.vehicleId === b.dataset.assign);
    $("#dProvider").value = v.vehicleId;
    $("#dFinal").value = v.customerPrice * days;
    $("#dCost").value = v.providerRate * days;
    recalc();
  }));

  const persist = status => {
    Object.assign(r, {
      status: status || $("#dStatus").value,
      assignedProvider: $("#dProvider").value,
      finalCustomerPrice: $("#dFinal").value,
      internalCost: $("#dCost").value,
      profit: $("#dProfit").value
    });
    saveReqs(); sync("CustomerRequests", r); renderAll();
  };
  $("#dSave").addEventListener("click", () => persist());
  $("#dApprove").addEventListener("click", () => persist("Approved"));
  $("#dDecline").addEventListener("click", () => persist("Declined"));
  $("#dConfirm").addEventListener("click", () => {
    const unit = INV.find(x => x.vehicleId === $("#dProvider").value);
    if (!unit) return alert("Assign a provider unit first.");
    persist("Booking confirmed");
    const rental = {
      rentalId: r.requestId.replace("TN-", "AR-"),
      requestId: r.requestId,
      vehicle: `${unit.year} ${unit.make} ${unit.model} ${unit.trim}`,
      vehicleId: unit.vehicleId,
      customer: r.customerName, customerPhone: r.phone,
      provider: unit.provider, providerContact: unit.providerContact,
      pickupDate: r.startDate, returnDate: r.endDate,
      deliveryAddress: r.option === "pickup" ? "Showroom" : r.deliveryLocation,
      deposit: unit.deposit, amountPaid: 0,
      balanceDue: Number(r.finalCustomerPrice) || 0,
      providerPayout: Number(r.internalCost) || 0,
      profit: Number(r.profit) || 0,
      pickupStatus: "Pending", returnStatus: "Pending",
      depositRefunded: "No", payoutPaid: "No", reviewRequested: "No",
      inspectionPhotos: [], review: "", notes: ""
    };
    RENTALS.push(rental); saveRentals(); sync("ActiveRentals", rental);
    unit.status = "booked";
    unit.bookedDates = [unit.bookedDates, `${(r.startDate || "").slice(0, 10)}→${(r.endDate || "").slice(0, 10)}`].filter(Boolean).join(", ");
    saveInv(); sync("PartnerInventory", unit);
    selRental = rental.rentalId;
    renderAll();
  });

  $("#genSummary").addEventListener("click", () => bookingSummary(r));
}

/* ----- premium booking summary (print/PDF) ----- */
function bookingSummary(r) {
  const unit = INV.find(x => x.vehicleId === r.assignedProvider);
  const total = Number(r.finalCustomerPrice) || 0;
  const paid = RENTALS.find(x => x.requestId === r.requestId)?.amountPaid || 0;
  const w = window.open("", "_blank");
  w.document.write(`<!DOCTYPE html><html><head><title>${r.requestId} — Booking Summary</title>
  <style>
    body{font-family:'Manrope',Arial,sans-serif;background:#0a0a0a;color:#f2f2f2;padding:40px;max-width:680px;margin:0 auto}
    h1{color:#ff6a00;font-size:22px;letter-spacing:.02em} .top{display:flex;justify-content:space-between;align-items:center;border-bottom:2px solid #ff6a00;padding-bottom:16px;margin-bottom:22px}
    table{width:100%;border-collapse:collapse;font-size:14px} td{padding:10px 6px;border-bottom:1px solid #222;vertical-align:top}
    td:first-child{color:#9a9a9a;width:220px} .big{font-size:18px;color:#ff6a00;font-weight:800}
    .foot{margin-top:26px;font-size:12px;color:#8a8a8a;line-height:1.7}
    @media print{body{background:#fff;color:#111} td:first-child{color:#666} td{border-color:#ddd} .foot{color:#666}}
  </style></head><body>
  <div class="top"><h1>TOPNOTCH — Booking Summary</h1><b>${r.requestId}</b></div>
  <table>
    <tr><td>Vehicle</td><td><b>${unit ? `${unit.year} ${unit.make} ${unit.model} ${unit.trim} · ${unit.color}` : r.vehicleRequested}</b></td></tr>
    <tr><td>Rental dates</td><td>${r.startDate} → ${r.endDate}</td></tr>
    <tr><td>${r.option === "pickup" ? "Pickup" : "Delivery"} location</td><td>${r.deliveryLocation}</td></tr>
    <tr><td>Price</td><td class="big">${money(total)}</td></tr>
    <tr><td>Security deposit</td><td>${money(unit ? unit.deposit : "")} (refundable, authorized before release)</td></tr>
    <tr><td>Mileage allowance</td><td>${unit ? unit.mileageIncluded : RENTAL_TERMS.mileageIncluded} miles/day included</td></tr>
    <tr><td>Additional mileage</td><td>$${unit ? unit.mileageFee : ""} per mile</td></tr>
    <tr><td>Fuel policy</td><td>Delivered full — return full (premium fuel), or pre-paid fuel add-on</td></tr>
    <tr><td>Requirements</td><td>${unit ? unit.minAge : RENTAL_TERMS.minAge}+ · valid license · full-coverage insurance · deposit on file</td></tr>
    <tr><td>Add-ons</td><td>${r.addons}</td></tr>
    <tr><td>Amount paid</td><td>${money(paid)}</td></tr>
    <tr><td>Remaining balance</td><td class="big">${money(Math.max(0, total - paid))}</td></tr>
    <tr><td>Booking contact</td><td>${BUSINESS.name} · ${BUSINESS.phone} · ${BUSINESS.email}</td></tr>
  </table>
  <div class="foot">Booking is confirmed once requirements are verified and payment is completed.
  Cancellation, deposit and mileage policies: topnotchrentalz — Policies page. Thank you for riding TOPNOTCH.</div>
  <script>window.print()<\/script></body></html>`);
  w.document.close();
}

/* ----- inventory ----- */
const INV_FIELDS = [
  ["vehicleId", "Vehicle ID"], ["fleetId", "Site fleet ID (links to website card)"], ["partnerId", "Partner ID"], ["provider", "Provider"],
  ["market", "Market"], ["year", "Year"], ["make", "Make"], ["model", "Model"], ["trim", "Trim"], ["color", "Color"], ["photos", "Photo URLs"],
  ["dailyRate", "Daily retail"], ["weeklyRate", "Weekly"], ["monthlyRate", "Monthly"], ["providerRate", "Provider/broker rate"],
  ["customerPrice", "TopNotch customer price"], ["providerPayout", "Provider payout"], ["profit", "Profit/commission"],
  ["deposit", "Deposit"], ["minDays", "Min days"], ["mileageIncluded", "Miles/day"], ["mileageFee", "Extra mile fee"],
  ["deliveryAreas", "Delivery areas"], ["deliveryFee", "Delivery fee"], ["minAge", "Min age"], ["license", "License req"],
  ["insurance", "Insurance req"], ["payments", "Payment methods"], ["bookedDates", "Booked dates"],
  ["lastVerified", "Last verified"], ["providerContact", "Provider contact"], ["notes", "Notes"]
];

function renderInventory() {
  const el = $("#tab-inventory");
  el.innerHTML = `
    <h1>Partner Inventory</h1>
    <p class="sub">Internal view — provider rates and payouts are never exposed on the customer site.</p>
    <div class="panel">
      <div class="panel-head">
        <h2>Vehicles (${INV.length})</h2>
        <div style="display:flex;gap:8px">
          <button class="btn btn-primary btn-mini" id="invAdd">+ Add vehicle</button>
          <button class="btn btn-ghost btn-mini" id="invExp">Export CSV</button>
        </div>
      </div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>Unit</th><th>Vehicle</th><th>Provider</th><th>Provider rate</th><th>Customer price</th><th>Profit/day</th><th>Status</th><th>Verified</th><th></th></tr>
        ${INV.map(v => `
          <tr>
            <td><b>${v.vehicleId}</b></td>
            <td>${v.year} ${v.make} ${v.model}<br><span style="color:var(--muted)">${v.trim} · ${v.color}</span></td>
            <td>${v.provider}</td>
            <td>${money(v.providerRate)}/d</td>
            <td>${money(v.customerPrice)}/d</td>
            <td style="color:var(--orange);font-weight:800">${money(v.customerPrice - v.providerRate)}</td>
            <td>
              <select class="f-select" style="padding:6px 10px;font-size:11.5px" data-st="${v.vehicleId}">
                ${["available", "booked", "maintenance", "unavailable"].map(s => `<option ${v.status === s ? "selected" : ""}>${s}</option>`).join("")}
              </select>
            </td>
            <td>${v.lastVerified || "—"}<br><span class="act" data-verify="${v.vehicleId}">Verify today</span></td>
            <td class="act" data-edit="${v.vehicleId}">Edit →</td>
          </tr>`).join("")}
      </table></div>
    </div>
    <div id="invForm"></div>`;
  $("#invExp").addEventListener("click", () => downloadCSV("PartnerInventory", INV));
  $("#invAdd").addEventListener("click", () => invForm(null));
  $$("[data-edit]", el).forEach(a => a.addEventListener("click", () => invForm(a.dataset.edit)));
  $$("[data-verify]", el).forEach(a => a.addEventListener("click", () => {
    const v = INV.find(x => x.vehicleId === a.dataset.verify);
    v.lastVerified = today(); saveInv(); sync("PartnerInventory", v); renderInventory();
  }));
  $$("[data-st]", el).forEach(s => s.addEventListener("change", () => {
    const v = INV.find(x => x.vehicleId === s.dataset.st);
    v.status = s.value; saveInv(); sync("PartnerInventory", v); renderAll();
  }));
}

function invForm(id) {
  const v = id ? INV.find(x => x.vehicleId === id) : Object.fromEntries(INV_FIELDS.map(f => [f[0], ""]));
  if (!id) { v.vehicleId = "V-" + String(1000 + INV.length + 1); v.market = BUSINESS.market; v.status = "available"; v.lastVerified = today(); }
  $("#invForm").innerHTML = `
    <div class="panel">
      <h2>${id ? "Edit " + id : "Add vehicle"}</h2>
      <div class="frm">
        ${INV_FIELDS.map(f => `<div><label>${f[1]}</label><input class="f-input" id="if_${f[0]}" value="${v[f[0]] ?? ""}"></div>`).join("")}
      </div>
      <div style="display:flex;gap:10px;margin-top:14px">
        <button class="btn btn-primary btn-mini" id="ifSave">Save vehicle</button>
        ${id ? '<button class="btn btn-ghost btn-mini" id="ifDelete" style="border-color:rgba(239,68,68,.5);color:#f87171">Remove</button>' : ""}
      </div>
    </div>`;
  $("#invForm").scrollIntoView({ behavior: "smooth" });
  $("#ifSave").addEventListener("click", () => {
    INV_FIELDS.forEach(f => {
      const raw = $("#if_" + f[0]).value.trim();
      v[f[0]] = /Rate|Price|Payout|profit|deposit|Fee|year|minDays|mileage|minAge/i.test(f[0]) && raw !== "" && !isNaN(raw) ? Number(raw) : raw;
    });
    if (!id) { v.status = "available"; INV.push(v); }
    saveInv(); sync("PartnerInventory", v); renderInventory();
  });
  if (id) $("#ifDelete").addEventListener("click", () => {
    INV = INV.filter(x => x.vehicleId !== id); saveInv(); renderInventory();
  });
}

/* ----- partners ----- */
function renderPartners() {
  const el = $("#tab-partners");
  const inq = INQUIRIES();
  el.innerHTML = `
    <h1>Partner Companies</h1>
    <p class="sub">Approved partners appear in vehicle matching. Rates stay internal.</p>
    <div class="panel">
      <div class="panel-head">
        <h2>Partners (${PARTNERS.length})</h2>
        <button class="btn btn-primary btn-mini" id="pAdd">+ Add partner</button>
      </div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>ID</th><th>Company</th><th>Contact</th><th>Market</th><th>Payout</th><th>Status</th><th>Notes</th></tr>
        ${PARTNERS.map(p => `
          <tr>
            <td><b>${p.partnerId}</b></td>
            <td>${p.company}</td>
            <td>${p.contact}<br><span style="color:var(--muted)">${p.phone} · ${p.email}</span></td>
            <td>${p.market}</td>
            <td>${p.payoutMethod}</td>
            <td><select class="f-select" style="padding:6px 10px;font-size:11.5px" data-pst="${p.partnerId}">
              ${["Approved", "Pending", "Paused"].map(s => `<option ${p.status === s ? "selected" : ""}>${s}</option>`).join("")}
            </select></td>
            <td style="max-width:220px">${p.notes || ""}</td>
          </tr>`).join("")}
      </table></div>
    </div>
    <div class="panel">
      <h2>Website partner inquiries (${inq.length})</h2>
      ${inq.length ? `<div class="tbl-wrap"><table class="tbl">
        <tr><th>Date</th><th>Company</th><th>Contact</th><th>Market</th><th>Fleet</th><th>Notes</th></tr>
        ${[...inq].reverse().map(q => `<tr><td>${(q.timestamp || "").slice(0, 10)}</td><td><b>${q.company}</b></td>
          <td>${q.contact}<br><span style="color:var(--muted)">${q.phone} · ${q.email}</span></td>
          <td>${q.market}</td><td>${q.fleetSize}</td><td>${q.notes}</td></tr>`).join("")}
      </table></div>` : '<p class="fineprint">No inquiries yet — share the Partner page link.</p>'}
    </div>
    <div id="pForm"></div>`;
  $$("[data-pst]", el).forEach(s => s.addEventListener("change", () => {
    const p = PARTNERS.find(x => x.partnerId === s.dataset.pst);
    p.status = s.value; savePartners(); renderAll();
  }));
  $("#pAdd").addEventListener("click", () => {
    $("#pForm").innerHTML = `
      <div class="panel"><h2>Add partner</h2>
        <div class="frm">
          ${[["company", "Company"], ["contact", "Contact person"], ["phone", "Phone"], ["email", "Email"], ["market", "Market"], ["payoutMethod", "Payout method"], ["notes", "Notes"]]
            .map(f => `<div><label>${f[1]}</label><input class="f-input" id="pf_${f[0]}"></div>`).join("")}
        </div>
        <button class="btn btn-primary btn-mini" id="pfSave" style="margin-top:14px">Save partner</button>
      </div>`;
    $("#pfSave").addEventListener("click", () => {
      const p = { partnerId: "P-" + String(PARTNERS.length + 1).padStart(3, "0"), status: "Approved" };
      ["company", "contact", "phone", "email", "market", "payoutMethod", "notes"].forEach(k => (p[k] = $("#pf_" + k).value.trim()));
      if (!p.company) return alert("Company name required");
      PARTNERS.push(p); savePartners(); sync("Partners", p); renderPartners();
    });
  });
}

/* ----- active rentals ----- */
function renderRentals() {
  const el = $("#tab-rentals");
  el.innerHTML = `
    <h1>Active Rentals</h1>
    <p class="sub">Payments, deposits, payouts, pickups, returns and inspections.</p>
    <div class="panel">
      <div class="panel-head">
        <h2>Rentals (${RENTALS.length})</h2>
        <button class="btn btn-ghost btn-mini" id="rentExp">Export CSV</button>
      </div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>Rental</th><th>Vehicle</th><th>Customer</th><th>Provider</th><th>Pickup</th><th>Return</th><th>Balance</th><th>Profit</th><th></th></tr>
        ${[...RENTALS].reverse().map(x => `
          <tr class="${selRental === x.rentalId ? "sel" : ""}">
            <td><b>${x.rentalId}</b></td>
            <td>${x.vehicle}</td>
            <td>${x.customer}<br><span style="color:var(--muted)">${x.customerPhone}</span></td>
            <td>${x.provider}</td>
            <td>${(x.pickupDate || "").slice(0, 16)}<br><span class="badge ${x.pickupStatus === "Done" ? "ok" : "warn"}">${x.pickupStatus}</span></td>
            <td>${(x.returnDate || "").slice(0, 16)}<br><span class="badge ${x.returnStatus === "Done" ? "ok" : "warn"}">${x.returnStatus}</span></td>
            <td>${money(Math.max(0, (x.balanceDue || 0) - (x.amountPaid || 0)))}</td>
            <td style="color:var(--orange);font-weight:800">${money(x.profit)}</td>
            <td class="act" data-ropen="${x.rentalId}">Open →</td>
          </tr>`).join("")}
      </table></div>
      ${RENTALS.length ? "" : '<p class="fineprint">Confirm a request to create the first rental.</p>'}
    </div>
    <div id="rentDetail"></div>`;
  $("#rentExp").addEventListener("click", () => downloadCSV("ActiveRentals", RENTALS));
  $$("[data-ropen]", el).forEach(a => a.addEventListener("click", () => { selRental = a.dataset.ropen; renderRentalDetail(); }));
  if (selRental) renderRentalDetail();
}

function renderRentalDetail() {
  const x = RENTALS.find(r => r.rentalId === selRental);
  const box = $("#rentDetail");
  if (!x || !box) return;
  box.innerHTML = `
    <div class="panel">
      <div class="panel-head"><h2>${x.rentalId} — ${x.vehicle}</h2>
        <a class="btn btn-ghost btn-mini" href="https://wa.me/${(x.customerPhone || "").replace(/\D/g, "")}" target="_blank">WhatsApp customer</a>
      </div>
      <div class="frm">
        <div><label>Amount paid</label><input class="f-input" id="rPaid" type="number" value="${x.amountPaid || 0}"></div>
        <div><label>Total due</label><input class="f-input" id="rDue" type="number" value="${x.balanceDue || 0}"></div>
        <div><label>Deposit held</label><input class="f-input" id="rDep" type="number" value="${x.deposit || 0}"></div>
        <div><label>Provider payout</label><input class="f-input" id="rPayout" type="number" value="${x.providerPayout || 0}"></div>
        <div><label>Pickup status</label><select class="f-select" id="rPick">${["Pending", "Scheduled", "Done"].map(s => `<option ${x.pickupStatus === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div><label>Return status</label><select class="f-select" id="rRet">${["Pending", "Due", "Done"].map(s => `<option ${x.returnStatus === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div><label>Deposit refunded</label><select class="f-select" id="rDepRef">${["No", "Yes"].map(s => `<option ${x.depositRefunded === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div><label>Payout paid</label><select class="f-select" id="rPayoutPaid">${["No", "Yes"].map(s => `<option ${x.payoutPaid === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div><label>Review requested</label><select class="f-select" id="rRevReq">${["No", "Yes"].map(s => `<option ${x.reviewRequested === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div class="frm-full"><label>Customer review</label><input class="f-input" id="rReview" value="${x.review || ""}" placeholder="5★ — 'Car was perfect…'"></div>
        <div class="frm-full"><label>Notes</label><input class="f-input" id="rNotes" value="${x.notes || ""}"></div>
        <div class="frm-full">
          <label>Inspection photos (pickup &amp; return)</label>
          <input class="f-input" type="file" id="rPhotos" accept="image/*" multiple>
          <div class="insp-row">${(x.inspectionPhotos || []).map(p => `<img src="${p}">`).join("")}</div>
        </div>
      </div>
      <div style="display:flex;gap:10px;margin-top:14px;flex-wrap:wrap">
        <button class="btn btn-primary btn-mini" id="rSave">Save rental</button>
        <span class="fineprint" style="margin:0;align-self:center">Balance after payment: <b id="rBal">${money(Math.max(0, (x.balanceDue || 0) - (x.amountPaid || 0)))}</b> · Profit: <b style="color:var(--orange)">${money(x.profit)}</b></span>
      </div>
    </div>`;

  $("#rPhotos").addEventListener("change", e => {
    [...e.target.files].slice(0, 6).forEach(f => {
      const rd = new FileReader();
      rd.onload = () => {
        x.inspectionPhotos = [...(x.inspectionPhotos || []), rd.result].slice(-8);
        saveRentals(); renderRentalDetail();
      };
      rd.readAsDataURL(f);
    });
  });
  $("#rSave").addEventListener("click", () => {
    Object.assign(x, {
      amountPaid: Number($("#rPaid").value) || 0,
      balanceDue: Number($("#rDue").value) || 0,
      deposit: Number($("#rDep").value) || 0,
      providerPayout: Number($("#rPayout").value) || 0,
      pickupStatus: $("#rPick").value,
      returnStatus: $("#rRet").value,
      depositRefunded: $("#rDepRef").value,
      payoutPaid: $("#rPayoutPaid").value,
      reviewRequested: $("#rRevReq").value,
      review: $("#rReview").value,
      notes: $("#rNotes").value
    });
    /* free the unit when the car comes back */
    if (x.returnStatus === "Done") {
      const unit = INV.find(v => v.vehicleId === x.vehicleId);
      if (unit && unit.status === "booked") { unit.status = "available"; saveInv(); sync("PartnerInventory", unit); }
    }
    saveRentals(); sync("ActiveRentals", { ...x, inspectionPhotos: (x.inspectionPhotos || []).length + " photos" });
    renderAll();
  });
}

/* ---------- boot ---------- */
pushVehicleStatus();
