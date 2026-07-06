/* ============================================================
   TopNotchRentalz — Operations Dashboard (API client)
   All data comes from the backend; every permission is enforced
   server-side. This file contains ZERO secrets or private data.
   ============================================================ */

const $ = (s, c) => (c || document).querySelector(s);
const $$ = (s, c) => Array.from((c || document).querySelectorAll(s));
const money = n => "$" + Number(n || 0).toLocaleString();
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

let ME = null;

async function api(path, body, method) {
  const res = await fetch("/api" + path, {
    method: method || (body !== undefined ? "POST" : "GET"),
    headers: body !== undefined ? { "Content-Type": "application/json" } : undefined,
    credentials: "same-origin",
    body: body !== undefined ? JSON.stringify(body) : undefined
  });
  if (res.status === 401) { showGate(); throw new Error("Signed out"); }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || "HTTP " + res.status);
  return data;
}

/* ============================================================
   AUTH FLOW
   ============================================================ */
const gate = $("#gate"), app = $("#app");
function showGate(msg) {
  gate.hidden = false; app.hidden = true;
  if (msg) $("#gateMsg").textContent = msg;
}
function showApp() {
  gate.hidden = true; app.hidden = false;
  $("#whoami").textContent = `${ME.name} · ${ME.role.toUpperCase()}`;
  $$("#sideNav button").forEach(b => {
    const roles = (b.dataset.roles || "").split(",").filter(Boolean);
    b.hidden = roles.length && !roles.includes(ME.role); // cosmetic only — server re-checks everything
  });
  renderAll();
}

async function boot() {
  try {
    const { user } = await api("/auth/me");
    ME = user;
    if (ME.mustReset) return askNewPassword();
    showApp();
  } catch (e) { showGate(); }
}

function askNewPassword() {
  gate.hidden = false; app.hidden = true;
  $("#loginForm").hidden = true; $("#resetForm").hidden = true; $("#newPassForm").hidden = false;
}

$("#loginBtn").addEventListener("click", doLogin);
$("#loginPass").addEventListener("keydown", e => { if (e.key === "Enter") doLogin(); });
async function doLogin() {
  $("#gateMsg").textContent = "";
  try {
    const out = await api("/auth/login", { email: $("#loginEmail").value.trim(), password: $("#loginPass").value });
    ME = out.user;
    if (ME.mustReset) return askNewPassword();
    showApp();
  } catch (e) { $("#gateMsg").textContent = e.message; }
}

$("#npBtn").addEventListener("click", async () => {
  try {
    await api("/auth/change-password", { current: $("#npCurrent").value, next: $("#npNext").value });
    const { user } = await api("/auth/me"); ME = user;
    $("#newPassForm").hidden = true; $("#loginForm").hidden = false;
    showApp();
  } catch (e) { $("#gateMsg").textContent = e.message; }
});

$("#forgotLink").addEventListener("click", e => { e.preventDefault(); $("#loginForm").hidden = true; $("#resetForm").hidden = false; });
$("#backToLogin").addEventListener("click", e => { e.preventDefault(); $("#resetForm").hidden = true; $("#loginForm").hidden = false; });
$("#resetBtn").addEventListener("click", async () => {
  const out = await api("/auth/reset/request", { email: $("#resetEmail").value.trim() }).catch(e => ({ message: e.message }));
  $("#gateMsg").textContent = out.message || "If that account exists, a reset link has been emailed.";
});
$("#logoutBtn").addEventListener("click", async () => { await api("/auth/logout", {}); location.reload(); });

/* reset link deep-linking: /admin/#reset=TOKEN */
if (location.hash.startsWith("#reset=")) {
  const token = location.hash.slice(7);
  gate.hidden = false;
  $("#loginForm").hidden = true; $("#newPassForm").hidden = false;
  $("#npCurrent").style.display = "none";
  $("#npBtn").textContent = "Set Password";
  $("#npBtn").replaceWith($("#npBtn").cloneNode(true));
  $("#npBtn").addEventListener("click", async () => {
    try {
      await api("/auth/reset/complete", { token, password: $("#npNext").value });
      location.hash = ""; location.reload();
    } catch (e) { $("#gateMsg").textContent = e.message; }
  });
}

/* auto-logout after inactivity (server enforces too) */
let idleTimer;
function armIdle() {
  clearTimeout(idleTimer);
  idleTimer = setTimeout(() => { api("/auth/logout", {}).finally(() => showGate("Signed out after inactivity.")); },
    ((ME && ME.idleMinutes) || 30) * 60e3);
}
["click", "keydown", "pointermove"].forEach(ev => addEventListener(ev, () => { if (ME && !app.hidden) armIdle(); }, { passive: true }));

/* ============================================================
   CSV EXPORT (from the API data this role is allowed to see)
   ============================================================ */
function downloadCSV(name, rows) {
  if (!rows.length) return alert("Nothing to export yet");
  const cols = [...new Set(rows.flatMap(r => Object.keys(r)))];
  const escCsv = v => `"${String(v ?? "").replace(/"/g, '""')}"`;
  const csv = [cols.join(","), ...rows.map(r => cols.map(c => escCsv(r[c])).join(","))].join("\n");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8" }));
  a.download = `${name}-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
}

/* ============================================================
   TABS
   ============================================================ */
$$("#sideNav button").forEach(b => b.addEventListener("click", () => {
  $$("#sideNav button").forEach(x => x.classList.toggle("on", x === b));
  $$(".tab").forEach(t => (t.hidden = t.id !== "tab-" + b.dataset.tab));
  renderAll();
}));

let selReq = null, selRental = null;
function activeTab() { return $("#sideNav button.on")?.dataset.tab || "dash"; }

async function renderAll() {
  const t = activeTab();
  try {
    if (t === "dash") await renderDash();
    if (t === "requests") await renderRequests();
    if (t === "inventory") await renderInventory();
    if (t === "partners") await renderPartners();
    if (t === "rentals") await renderRentals();
    if (t === "import") renderImport();
    if (t === "sync") await renderSync();
    if (t === "audit") await renderAudit();
    if (t === "users") await renderUsers();
  } catch (e) {
    if (e.message !== "Signed out")
      $("#tab-" + t).innerHTML = `<h1>${t}</h1><p class="sub">${esc(e.message)}</p>`;
  }
}

/* ----- dashboard ----- */
async function renderDash() {
  const el = $("#tab-dash");
  const [reminders, reqs, rentals] = await Promise.all([
    api("/reminders").catch(() => []),
    api("/requests").catch(() => []),
    api("/rentals").catch(() => [])
  ]);
  $("#reqCount").textContent = reqs.filter(r => r.status === "Request submitted").length || "";
  const stat = (label, val) => `<div class="stat"><b>${val}</b><span>${label}</span></div>`;
  el.innerHTML = `
    <h1>Operations</h1>
    <p class="sub">Signed in as ${esc(ME.name)} (${ME.role}) · sessions auto-expire after inactivity</p>
    <div class="stat-row">
      ${stat("New requests", reqs.filter(r => r.status === "Request submitted").length)}
      ${stat("Confirming availability", reqs.filter(r => ["Under review", "Availability being confirmed"].includes(r.status)).length)}
      ${stat("Quotes open", reqs.filter(r => ["Quote sent", "Quote accepted"].includes(r.status)).length)}
      ${stat("Awaiting payment", reqs.filter(r => r.status === "Payment required").length)}
      ${stat("Active rentals", rentals.filter(x => x.return_status !== "Done").length)}
      ${ME.role === "admin" ? stat("Profit booked", money(rentals.reduce((s, x) => s + Number(x.profit || 0), 0))) : ""}
    </div>
    <div class="panel">
      <div class="panel-head"><h2>Reminders (${reminders.length})</h2></div>
      ${reminders.length ? reminders.map(r => `<div class="rem-item"><span class="rem-dot"></span>${esc(r.t)}<span class="rem-when">${esc(r.w)}</span></div>`).join("")
        : '<p class="fineprint">Nothing pending. Clean board.</p>'}
    </div>`;
}

/* ----- requests ----- */
const FLOW_BADGE = s => {
  const cls = s === "Booking confirmed" || s === "Completed" ? "ok" : ["Declined", "Cancelled"].includes(s) ? "bad" : s === "Request submitted" ? "warn" : "dim";
  return `<span class="badge ${cls}">${esc(s)}</span>`;
};

async function renderRequests() {
  const el = $("#tab-requests");
  const reqs = await api("/requests");
  el.innerHTML = `
    <h1>Customer Requests</h1>
    <p class="sub">Workflow order is enforced by the server: review → provider confirm → approve price → quote → accept → payment link → verify → confirmed.</p>
    <div class="panel">
      <div class="panel-head">
        <h2>All requests (${reqs.length})</h2>
        <button class="btn btn-ghost btn-mini" id="expReq">Export CSV</button>
      </div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>Request</th><th>Customer</th><th>Vehicle</th><th>Dates</th><th>Budget</th><th>Status</th><th></th></tr>
        ${reqs.map(r => `
          <tr class="${selReq === r.request_id ? "sel" : ""}">
            <td><b>${r.request_id}</b>${r.duplicate_of ? `<br><span class="badge warn">dup of ${r.duplicate_of}</span>` : ""}</td>
            <td>${esc(r.customer_name)}<br><span style="color:var(--muted)">${esc(r.phone)}</span></td>
            <td>${esc(r.vehicle_requested)}${r.backup_vehicle && r.backup_vehicle !== "None" ? `<br><span style="color:var(--muted)">alt: ${esc(r.backup_vehicle)}</span>` : ""}</td>
            <td>${(r.start_date || "").slice(0, 10)} →<br>${(r.end_date || "").slice(0, 10)}</td>
            <td>${esc(r.budget || "—")}</td>
            <td>${FLOW_BADGE(r.status)}</td>
            <td class="act" data-open="${r.request_id}">Open →</td>
          </tr>`).join("")}
      </table></div>
    </div>
    <div id="reqDetail"></div>`;
  $("#expReq").addEventListener("click", () => downloadCSV("CustomerRequests", reqs));
  $$("[data-open]", el).forEach(a => a.addEventListener("click", () => { selReq = a.dataset.open; renderRequestDetail(); }));
  if (selReq && reqs.some(r => r.request_id === selReq)) renderRequestDetail();
}

async function renderRequestDetail() {
  const box = $("#reqDetail");
  const reqs = await api("/requests");
  const r = reqs.find(x => x.request_id === selReq);
  if (!r || !box) return;
  let matches = { exact: [], similar: [], days: 1 };
  try { matches = await api(`/requests/${r.request_id}/matches`); } catch (e) { /* role without matching */ }
  const list = matches.exact.length ? matches.exact : matches.similar;

  const step = (label, enabled, id, cls) =>
    `<button class="btn ${cls || "btn-ghost"} btn-mini" id="${id}" ${enabled ? "" : "disabled style='opacity:.35'"}>${label}</button>`;

  box.innerHTML = `
    <div class="panel">
      <div class="panel-head">
        <h2>${r.request_id} — ${esc(r.vehicle_requested)} ${FLOW_BADGE(r.status)}</h2>
        <div style="display:flex;gap:8px;flex-wrap:wrap">
          <a class="btn btn-ghost btn-mini" href="https://wa.me/${(r.phone || "").replace(/\D/g, "")}" target="_blank">WhatsApp</a>
          <a class="btn btn-ghost btn-mini" href="mailto:${esc(r.email)}">Email</a>
          <button class="btn btn-chrome btn-mini" id="genSummary">Booking Summary</button>
        </div>
      </div>

      <div class="detail-grid">
        <div class="kv"><i>Customer</i><b>${esc(r.customer_name)} · ${esc(r.phone)}<br>${esc(r.email)}</b></div>
        <div class="kv"><i>Dates (${matches.days}d)</i><b>${esc(r.start_date)} →<br>${esc(r.end_date)}</b></div>
        <div class="kv"><i>${r.option === "pickup" ? "Showroom pickup" : "Delivery"}</i><b>${esc(r.delivery_location)}<br>Return: ${esc(r.return_location)}</b></div>
        <div class="kv"><i>Driver</i><b>Age ${esc(r.driver_age)} · ${esc(r.license_status)}<br>${esc(r.insurance_status)}</b></div>
        <div class="kv"><i>Budget / deposit</i><b>${esc(r.budget)} · ${esc(r.deposit_readiness)}</b></div>
        <div class="kv"><i>Add-ons / notes</i><b>${esc(r.addons)} · ${esc(r.special_requests)}</b></div>
        <div class="kv"><i>Assigned unit</i><b>${esc(r.assigned_vehicle_id || "—")}</b></div>
        <div class="kv"><i>Pricing</i><b>Final ${r.final_price ? money(r.final_price) : "—"} · Cost ${r.internal_cost ? money(r.internal_cost) : "—"} · Profit ${r.profit ? money(r.profit) : "—"}</b></div>
        ${r.quote_amount ? `<div class="kv"><i>Quote</i><b>${money(r.quote_amount)} · expires ${String(r.quote_expires).slice(0, 10)} · ${r.quote_accepted_at ? "ACCEPTED" : "awaiting customer"}</b></div>` : ""}
      </div>

      <h2 style="margin:18px 0 10px">Provider matching ${matches.exact.length ? "" : "· comparable class"}</h2>
      ${list.length ? list.map((v, i) => `
        <div class="match-card ${i < 2 ? "best" : ""}">
          <div>
            <b>${v.year} ${esc(v.make)} ${esc(v.model)} ${esc(v.trim)} · ${esc(v.color)}</b>
            <span style="font-size:11.5px;color:var(--muted)">${esc(v.provider)} · verified ${v.last_verified}
            ${v.conflicts.length ? `<span class="badge bad">conflict: ${esc(v.conflicts.join(", "))}</span>` : `<span class="badge ok">${v.status}</span>`}</span>
          </div>
          <div class="mc-nums">
            ${"provider_rate" in v ? `<span><i>Provider rate</i>${money(v.provider_rate)}/d</span>` : ""}
            <span><i>Customer price</i>${money(v.daily_rate)}/d</span>
            ${"profitEstimate" in v ? `<span><i>Profit (${matches.days}d)</i><b style="color:var(--orange)">${money(v.profitEstimate)}</b></span>` : ""}
          </div>
          <button class="btn btn-primary btn-mini" data-assign="${v.vehicle_id}" ${v.conflicts.length ? "disabled style='opacity:.4'" : ""}>Assign</button>
        </div>`).join("") : '<p class="fineprint">No approved provider offers this model in this market.</p>'}

      <h2 style="margin:18px 0 10px">Workflow</h2>
      <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">
        ${step("1 · Mark under review", r.status === "Request submitted", "wReview")}
        ${step("2 · Provider confirms", r.status === "Availability being confirmed", "wConfirm")}
        ${step("Provider declines", r.status === "Availability being confirmed", "wDecline")}
        ${step("3 · Approve price", r.status === "Provider confirmed", "wApprove", "btn-chrome")}
        ${step("4 · Send quote", r.status === "Approved", "wQuote", "btn-chrome")}
        ${step("5 · Issue payment link", r.status === "Quote accepted", "wPayLink", "btn-primary")}
        ${step("6 · Payment verified → confirm", r.status === "Payment required", "wPaid", "btn-primary")}
        ${step("Decline request", !["Booking confirmed", "Completed", "Declined"].includes(r.status), "wNo")}
      </div>
      ${r.status === "Provider confirmed" ? `
        <div class="frm" style="margin-top:12px">
          <div><label>Final customer price (total)</label><input class="f-input" id="wFinal" value="${r.final_price || (list[0] ? list[0].daily_rate * matches.days : "")}"></div>
          <div><label>Internal cost (provider total)</label><input class="f-input" id="wCost" value="${r.internal_cost || (list[0] && list[0].provider_rate ? list[0].provider_rate * matches.days : "")}"></div>
        </div>` : ""}
      <p class="fineprint">Two lowest approved rates are ranked first. Customers only ever see the TopNotchRentalz price. Card details are never stored on this system.</p>
    </div>`;

  const act = async (fn) => { try { await fn(); selReq = r.request_id; renderRequests(); } catch (e) { alert(e.message); } };
  $$("[data-assign]", box).forEach(b => b.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/assign`, { vehicleId: b.dataset.assign }))));
  $("#wReview")?.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/review`, {})));
  $("#wConfirm")?.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/provider-decision`, { decision: "confirm" })));
  $("#wDecline")?.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/provider-decision`, { decision: "decline", note: prompt("Reason (optional)") || "" })));
  $("#wApprove")?.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/approve`, { finalPrice: Number($("#wFinal").value), internalCost: Number($("#wCost").value) })));
  $("#wQuote")?.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/quote`, { expiresDays: Number(prompt("Quote valid for how many days?", "3")) || 3 })));
  $("#wPayLink")?.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/payment-link`, {})));
  $("#wPaid")?.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/payment-verified`, { amount: Number(prompt("Amount received", r.final_price)) || r.final_price, method: "card" })));
  $("#wNo")?.addEventListener("click", () => act(() => api(`/requests/${r.request_id}/decline`, { note: prompt("Reason") || "" })));

  $("#genSummary").addEventListener("click", () => bookingSummary(r));
}

function bookingSummary(r) {
  const total = Number(r.final_price) || Number(r.quote_amount) || 0;
  const w = window.open("", "_blank");
  w.document.write(`<!DOCTYPE html><html><head><title>${r.request_id} — Booking Summary</title>
  <style>body{font-family:Arial,sans-serif;background:#0a0a0a;color:#f2f2f2;padding:40px;max-width:680px;margin:0 auto}
  h1{color:#ff6a00;font-size:22px}.top{display:flex;justify-content:space-between;border-bottom:2px solid #ff6a00;padding-bottom:16px;margin-bottom:22px}
  table{width:100%;border-collapse:collapse;font-size:14px}td{padding:10px 6px;border-bottom:1px solid #222}
  td:first-child{color:#9a9a9a;width:220px}.big{font-size:18px;color:#ff6a00;font-weight:800}
  .foot{margin-top:26px;font-size:12px;color:#8a8a8a}@media print{body{background:#fff;color:#111}td{border-color:#ddd}}</style></head><body>
  <div class="top"><h1>TOPNOTCH — Booking Summary</h1><b>${r.request_id}</b></div>
  <table>
    <tr><td>Vehicle</td><td><b>${esc(r.vehicle_requested)}</b> (unit ${esc(r.assigned_vehicle_id || "TBD")})</td></tr>
    <tr><td>Rental dates</td><td>${esc(r.start_date)} → ${esc(r.end_date)}</td></tr>
    <tr><td>${r.option === "pickup" ? "Pickup" : "Delivery"} location</td><td>${esc(r.delivery_location)}</td></tr>
    <tr><td>Price</td><td class="big">${money(total)}</td></tr>
    <tr><td>Mileage allowance</td><td>100 miles/day included · additional miles at the listed per-mile rate</td></tr>
    <tr><td>Fuel policy</td><td>Delivered full — return full (premium), or pre-paid fuel add-on</td></tr>
    <tr><td>Requirements</td><td>25+ · valid license · full-coverage insurance · refundable deposit</td></tr>
    <tr><td>Add-ons</td><td>${esc(r.addons)}</td></tr>
    <tr><td>Quote expires</td><td>${r.quote_expires ? String(r.quote_expires).slice(0, 10) : "—"}</td></tr>
    <tr><td>Booking contact</td><td>TopNotchRentalz</td></tr>
  </table>
  <div class="foot">Booking is confirmed once availability, requirements and payment are verified. Policies: see the Policies page.</div>
  <script>window.print()<\/script></body></html>`);
  w.document.close();
}

/* ----- inventory ----- */
async function renderInventory() {
  const el = $("#tab-inventory");
  const rows = await api("/vehicles");
  const full = rows.length && "provider_rate" in rows[0];
  el.innerHTML = `
    <h1>Partner Inventory</h1>
    <p class="sub">${full ? "Full internal view — provider rates never reach customer pages." : "Operational view — rates are restricted for your role."}</p>
    <div class="panel">
      <div class="panel-head">
        <h2>Vehicles (${rows.length})</h2>
        <div style="display:flex;gap:8px">
          ${full ? '<button class="btn btn-primary btn-mini" id="invAdd">+ Add vehicle</button>' : ""}
          <button class="btn btn-ghost btn-mini" id="invExp">Export CSV</button>
        </div>
      </div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>Unit</th><th>Vehicle</th><th>Partner</th>${full ? "<th>Provider rate</th><th>Customer price</th><th>Profit/day</th>" : "<th>Daily rate</th>"}<th>Status</th><th>Verified</th>${full ? "<th></th>" : ""}</tr>
        ${rows.map(v => `
          <tr>
            <td><b>${v.vehicle_id}</b></td>
            <td>${v.year || ""} ${esc(v.make)} ${esc(v.model)}<br><span style="color:var(--muted)">${esc(v.trim || "")} · ${esc(v.color || "")}</span></td>
            <td>${esc(v.partner_id)}</td>
            ${full ? `<td>${money(v.provider_rate)}/d</td><td>${money(v.customer_price)}/d</td>
                     <td style="color:var(--orange);font-weight:800">${money((v.customer_price || 0) - (v.provider_rate || 0))}</td>`
                   : `<td>${money(v.daily_rate)}/d</td>`}
            <td><select class="f-select" style="padding:6px 10px;font-size:11.5px" data-st="${v.vehicle_id}">
              ${["available", "booked", "maintenance", "unavailable"].map(s => `<option ${v.status === s ? "selected" : ""}>${s}</option>`).join("")}
            </select></td>
            <td>${v.last_verified || "—"}<br><span class="act" data-verify="${v.vehicle_id}">Verify today</span></td>
            ${full ? `<td class="act" data-edit="${v.vehicle_id}">Edit →</td>` : ""}
          </tr>`).join("")}
      </table></div>
    </div>
    <div id="invForm"></div>`;
  $("#invExp").addEventListener("click", () => downloadCSV("PartnerInventory", rows));
  $("#invAdd")?.addEventListener("click", () => invForm(null));
  $$("[data-edit]", el).forEach(a => a.addEventListener("click", () => invForm(rows.find(v => v.vehicle_id === a.dataset.edit))));
  $$("[data-verify]", el).forEach(a => a.addEventListener("click", async () => {
    await api(`/vehicles/${a.dataset.verify}`, { last_verified: new Date().toISOString().slice(0, 10) }, "PATCH").catch(e => alert(e.message));
    renderInventory();
  }));
  $$("[data-st]", el).forEach(s => s.addEventListener("change", async () => {
    await api(`/vehicles/${s.dataset.st}`, { status: s.value }, "PATCH").catch(e => alert(e.message));
    renderInventory();
  }));
}

const INV_FIELDS = [
  ["vehicle_id", "Vehicle ID"], ["fleet_id", "Site fleet ID"], ["partner_id", "Partner ID"], ["market", "Market"],
  ["year", "Year"], ["make", "Make"], ["model", "Model"], ["trim", "Trim"], ["color", "Color"], ["vin", "VIN"],
  ["daily_rate", "Daily retail"], ["weekly_rate", "Weekly"], ["monthly_rate", "Monthly"], ["provider_rate", "Provider/broker rate"],
  ["customer_price", "Customer price"], ["provider_payout", "Provider payout"], ["profit", "Profit"],
  ["deposit", "Deposit"], ["min_days", "Min days"], ["mileage_included", "Miles/day"], ["mileage_fee", "Extra mile fee"],
  ["delivery_areas", "Delivery areas"], ["delivery_fee", "Delivery fee"], ["min_age", "Min age"], ["license", "License req"],
  ["insurance", "Insurance req"], ["payments", "Payment methods"], ["last_verified", "Last verified"],
  ["provider_contact", "Provider contact"], ["notes", "Notes"]
];
function invForm(v) {
  const isNew = !v;
  v = v || {};
  $("#invForm").innerHTML = `
    <div class="panel">
      <h2>${isNew ? "Add vehicle" : "Edit " + v.vehicle_id}</h2>
      <div class="frm">${INV_FIELDS.map(f => `<div><label>${f[1]}</label><input class="f-input" id="if_${f[0]}" value="${esc(v[f[0]] ?? "")}" ${!isNew && f[0] === "vehicle_id" ? "readonly" : ""}></div>`).join("")}</div>
      <div style="display:flex;gap:10px;margin-top:14px">
        <button class="btn btn-primary btn-mini" id="ifSave">Save vehicle</button>
        ${isNew ? "" : '<button class="btn btn-ghost btn-mini" id="ifDelete" style="border-color:rgba(239,68,68,.5);color:#f87171">Remove</button>'}
      </div>
    </div>`;
  $("#invForm").scrollIntoView({ behavior: "smooth" });
  $("#ifSave").addEventListener("click", async () => {
    const body = {};
    INV_FIELDS.forEach(f => { body[f[0]] = $("#if_" + f[0]).value.trim(); });
    try {
      if (isNew) await api("/vehicles", body);
      else await api("/vehicles/" + v.vehicle_id, body, "PATCH");
      renderInventory();
    } catch (e) { alert(e.message); }
  });
  $("#ifDelete")?.addEventListener("click", async () => {
    if (!confirm("Remove this vehicle?")) return;
    await api("/vehicles/" + v.vehicle_id, undefined, "DELETE").catch(e => alert(e.message));
    renderInventory();
  });
}

/* ----- partners ----- */
async function renderPartners() {
  const el = $("#tab-partners");
  const [partners, inq] = await Promise.all([api("/partners"), api("/partner-inquiries").catch(() => [])]);
  el.innerHTML = `
    <h1>Partner Companies</h1>
    <p class="sub">Approved partners appear in matching. Portal users are created in the Team tab.</p>
    <div class="panel">
      <div class="panel-head"><h2>Partners (${partners.length})</h2>
        <button class="btn btn-primary btn-mini" id="pAdd">+ Add partner</button></div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>ID</th><th>Company</th><th>Contact</th><th>Market</th><th>Payout</th><th>Status</th></tr>
        ${partners.map(p => `
          <tr><td><b>${p.partner_id}</b></td><td>${esc(p.company)}</td>
          <td>${esc(p.contact)}<br><span style="color:var(--muted)">${esc(p.phone)} · ${esc(p.email)}</span></td>
          <td>${esc(p.market)}</td><td>${esc(p.payout_method)}</td>
          <td><select class="f-select" style="padding:6px 10px;font-size:11.5px" data-pst="${p.partner_id}">
            ${["Approved", "Pending", "Paused"].map(s => `<option ${p.status === s ? "selected" : ""}>${s}</option>`).join("")}
          </select></td></tr>`).join("")}
      </table></div>
    </div>
    <div class="panel">
      <h2>Website partner inquiries (${inq.length})</h2>
      ${inq.length ? `<div class="tbl-wrap"><table class="tbl">
        <tr><th>Date</th><th>Company</th><th>Contact</th><th>Market</th><th>Fleet</th><th>Notes</th></tr>
        ${inq.map(q => `<tr><td>${(q.ts || "").slice(0, 10)}</td><td><b>${esc(q.company)}</b></td>
        <td>${esc(q.contact)}<br><span style="color:var(--muted)">${esc(q.phone)} · ${esc(q.email)}</span></td>
        <td>${esc(q.market)}</td><td>${esc(q.fleet_size)}</td><td>${esc(q.notes)}</td></tr>`).join("")}</table></div>`
      : '<p class="fineprint">No inquiries yet.</p>'}
    </div>
    <div id="pForm"></div>`;
  $$("[data-pst]", el).forEach(s => s.addEventListener("change", async () => {
    await api("/partners/" + s.dataset.pst, { status: s.value }, "PATCH").catch(e => alert(e.message));
  }));
  $("#pAdd").addEventListener("click", () => {
    $("#pForm").innerHTML = `<div class="panel"><h2>Add partner</h2><div class="frm">
      ${[["company", "Company"], ["contact", "Contact"], ["phone", "Phone"], ["email", "Email"], ["market", "Market"], ["payout_method", "Payout method"], ["notes", "Notes"]]
        .map(f => `<div><label>${f[1]}</label><input class="f-input" id="pf_${f[0]}"></div>`).join("")}</div>
      <button class="btn btn-primary btn-mini" id="pfSave" style="margin-top:14px">Save partner</button></div>`;
    $("#pfSave").addEventListener("click", async () => {
      const body = {};
      ["company", "contact", "phone", "email", "market", "payout_method", "notes"].forEach(k => body[k] = $("#pf_" + k).value.trim());
      try { await api("/partners", body); renderPartners(); } catch (e) { alert(e.message); }
    });
  });
}

/* ----- rentals ----- */
async function renderRentals() {
  const el = $("#tab-rentals");
  const rentals = await api("/rentals");
  el.innerHTML = `
    <h1>Active Rentals</h1>
    <p class="sub">Payments, deposits, payouts, pickups, returns and inspections.</p>
    <div class="panel">
      <div class="panel-head"><h2>Rentals (${rentals.length})</h2>
        <button class="btn btn-ghost btn-mini" id="rentExp">Export CSV</button></div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>Rental</th><th>Vehicle</th><th>Customer</th><th>Provider</th><th>Pickup</th><th>Return</th><th>Balance</th><th>Profit</th><th></th></tr>
        ${rentals.map(x => `
          <tr class="${selRental === x.rental_id ? "sel" : ""}">
            <td><b>${x.rental_id}</b></td><td>${esc(x.vehicle)}</td>
            <td>${esc(x.customer)}<br><span style="color:var(--muted)">${esc(x.customer_phone)}</span></td>
            <td>${esc(x.provider)}</td>
            <td>${(x.pickup_date || "").slice(0, 16)}<br><span class="badge ${x.pickup_status === "Done" ? "ok" : "warn"}">${x.pickup_status}</span></td>
            <td>${(x.return_date || "").slice(0, 16)}<br><span class="badge ${x.return_status === "Done" ? "ok" : "warn"}">${x.return_status}</span></td>
            <td>${money(Math.max(0, (x.balance_due || 0) - (x.amount_paid || 0)))}</td>
            <td style="color:var(--orange);font-weight:800">${money(x.profit)}</td>
            <td class="act" data-ropen="${x.rental_id}">Open →</td>
          </tr>`).join("")}
      </table></div>
      ${rentals.length ? "" : '<p class="fineprint">Verify a payment on a request to create the first rental.</p>'}
    </div>
    <div id="rentDetail"></div>`;
  $("#rentExp").addEventListener("click", () => downloadCSV("ActiveRentals", rentals));
  $$("[data-ropen]", el).forEach(a => a.addEventListener("click", () => { selRental = a.dataset.ropen; renderRentalDetail(); }));
  if (selRental && rentals.some(x => x.rental_id === selRental)) renderRentalDetail();
}

async function renderRentalDetail() {
  const box = $("#rentDetail");
  const rentals = await api("/rentals");
  const x = rentals.find(r => r.rental_id === selRental);
  if (!x || !box) return;
  const photos = await api("/uploads?rentalId=" + x.rental_id).catch(() => []);
  box.innerHTML = `
    <div class="panel">
      <div class="panel-head"><h2>${x.rental_id} — ${esc(x.vehicle)}</h2>
        <a class="btn btn-ghost btn-mini" href="https://wa.me/${(x.customer_phone || "").replace(/\D/g, "")}" target="_blank">WhatsApp customer</a></div>
      <div class="frm">
        <div><label>Amount paid</label><input class="f-input" id="rPaid" type="number" value="${x.amount_paid || 0}"></div>
        <div><label>Total due</label><input class="f-input" id="rDue" type="number" value="${x.balance_due || 0}"></div>
        <div><label>Deposit held</label><input class="f-input" id="rDep" type="number" value="${x.deposit || 0}"></div>
        <div><label>Provider payout</label><input class="f-input" id="rPayout" type="number" value="${x.provider_payout || 0}"></div>
        <div><label>Pickup status</label><select class="f-select" id="rPick">${["Pending", "Scheduled", "Done"].map(s => `<option ${x.pickup_status === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div><label>Return status</label><select class="f-select" id="rRet">${["Pending", "Due", "Done"].map(s => `<option ${x.return_status === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div><label>Deposit refunded</label><select class="f-select" id="rDepRef">${["No", "Yes"].map(s => `<option ${x.deposit_refunded === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div><label>Payout paid</label><select class="f-select" id="rPayoutPaid">${["No", "Yes"].map(s => `<option ${x.payout_paid === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div><label>Review requested</label><select class="f-select" id="rRevReq">${["No", "Yes"].map(s => `<option ${x.review_requested === s ? "selected" : ""}>${s}</option>`).join("")}</select></div>
        <div class="frm-full"><label>Customer review</label><input class="f-input" id="rReview" value="${esc(x.review || "")}"></div>
        <div class="frm-full"><label>Notes</label><input class="f-input" id="rNotes" value="${esc(x.notes || "")}"></div>
        <div class="frm-full">
          <label>Inspection photos (pickup &amp; return) — JPEG/PNG/WebP, max 5 MB</label>
          <input class="f-input" type="file" id="rPhotos" accept="image/jpeg,image/png,image/webp" multiple>
          <div class="insp-row">${photos.map(p => `<img src="/api/files/${p.id}" title="${esc(p.kind)} · ${esc(p.owner_email)}">`).join("")}</div>
        </div>
      </div>
      <div style="display:flex;gap:10px;margin-top:14px;flex-wrap:wrap">
        <button class="btn btn-primary btn-mini" id="rSave">Save rental</button>
        <span class="fineprint" style="margin:0;align-self:center">Balance: <b>${money(Math.max(0, (x.balance_due || 0) - (x.amount_paid || 0)))}</b>${"profit" in x ? ` · Profit: <b style="color:var(--orange)">${money(x.profit)}</b>` : ""}</span>
      </div>
    </div>`;

  $("#rPhotos").addEventListener("change", e => {
    [...e.target.files].slice(0, 6).forEach(f => {
      const rd = new FileReader();
      rd.onload = async () => {
        try { await api("/uploads", { data: rd.result, rentalId: x.rental_id, kind: "inspection", filename: f.name }); renderRentalDetail(); }
        catch (err) { alert(err.message); }
      };
      rd.readAsDataURL(f);
    });
  });
  $("#rSave").addEventListener("click", async () => {
    try {
      await api("/rentals/" + x.rental_id, {
        amount_paid: Number($("#rPaid").value) || 0, balance_due: Number($("#rDue").value) || 0,
        deposit: Number($("#rDep").value) || 0, provider_payout: Number($("#rPayout").value) || 0,
        pickup_status: $("#rPick").value, return_status: $("#rRet").value,
        deposit_refunded: $("#rDepRef").value, payout_paid: $("#rPayoutPaid").value,
        review_requested: $("#rRevReq").value, review: $("#rReview").value, notes: $("#rNotes").value
      }, "PATCH");
      renderRentals();
    } catch (e) { alert(e.message); }
  });
}

/* ----- import ----- */
function renderImport() {
  const el = $("#tab-import");
  el.innerHTML = `
    <h1>Import Partner Fleet</h1>
    <p class="sub">Upload a CSV fleet sheet (save Excel workbooks as CSV). Preview shows new / updated / duplicates / problems — an <b>admin</b> must approve the commit.</p>
    <div class="panel">
      <h2>1 · Upload sheet</h2>
      <input class="f-input" type="file" id="impFile" accept=".csv,text/csv">
      <p class="fineprint">Recognized columns: Provider, Year, Make, Model, Trim, Color, Daily/Weekly/Monthly Rate,
      Broker Rate, Customer Rate, Deposit, Mileage, Mile Fee, Min Days, Delivery Areas, Delivery Fee, Driver Age,
      License, Insurance, Payment Methods, Availability, Booked Dates, Photos, Provider Contact, Notes, VIN, Vehicle ID.</p>
      <button class="btn btn-primary btn-mini" id="impPreview" style="margin-top:10px">Preview Import</button>
    </div>
    <div id="impResult"></div>`;
  let csvText = "";
  $("#impFile").addEventListener("change", e => {
    const f = e.target.files[0];
    if (!f) return;
    const rd = new FileReader();
    rd.onload = () => (csvText = rd.result);
    rd.readAsText(f);
  });
  $("#impPreview").addEventListener("click", async () => {
    if (!csvText) return alert("Choose a CSV file first");
    try {
      const out = await api("/import/preview", { csv: csvText });
      const s = out.summary;
      const sec = (label, arr, fmt) => arr.length ? `<h2 style="margin-top:14px">${label} (${arr.length})</h2>` +
        arr.slice(0, 20).map(fmt).join("") : "";
      $("#impResult").innerHTML = `
        <div class="panel">
          <h2>2 · Preview</h2>
          <div class="stat-row">
            <div class="stat"><b>${s.new}</b><span>New vehicles</span></div>
            <div class="stat"><b>${s.updated}</b><span>Updated</span></div>
            <div class="stat"><b>${s.duplicates}</b><span>Duplicates</span></div>
            <div class="stat"><b>${s.missingFields}</b><span>Missing fields</span></div>
            <div class="stat"><b>${s.invalidPrices}</b><span>Invalid prices</span></div>
            <div class="stat"><b>${s.conflicts}</b><span>ID/VIN conflicts</span></div>
          </div>
          ${sec("New", out.report.newVehicles, r => `<div class="rem-item"><span class="rem-dot"></span>Line ${r.line}: ${esc(r.rec.make)} ${esc(r.rec.model)} ${esc(r.rec.trim || "")} — ${esc(r.rec.partner_id)}</div>`)}
          ${sec("Updated", out.report.updated, r => `<div class="rem-item"><span class="rem-dot"></span>Line ${r.line}: updates ${r.vehicleId}</div>`)}
          ${sec("Duplicate rows skipped", out.report.duplicates, r => `<div class="rem-item"><span class="rem-dot"></span>Line ${r.line}: duplicate of ${esc(r.key)}</div>`)}
          ${sec("Missing required fields", out.report.missingFields, r => `<div class="rem-item"><span class="rem-dot"></span>Line ${r.line}: ${esc(r.missing.join(", "))}</div>`)}
          ${sec("Invalid prices", out.report.invalidPrices, r => `<div class="rem-item"><span class="rem-dot"></span>Line ${r.line}: ${esc(r.field)} = "${esc(r.value)}"</div>`)}
          ${sec("Conflicts", out.report.conflicts, r => `<div class="rem-item"><span class="rem-dot"></span>Line ${r.line}: ${esc(r.reason)}</div>`)}
          <div style="margin-top:16px">
            ${ME.role === "admin"
              ? `<button class="btn btn-primary" id="impCommit">Approve &amp; Commit (${s.new} new, ${s.updated} updates)</button>`
              : '<p class="fineprint">Preview saved. Ask an <b>admin</b> to approve and commit this import.</p>'}
          </div>
        </div>`;
      $("#impCommit")?.addEventListener("click", async () => {
        try {
          const done = await api("/import/commit", { token: out.token });
          $("#impResult").innerHTML = `<div class="panel"><h2>Committed</h2><p class="fineprint">${done.created} created, ${done.updated} updated. Rows queued for Excel sync.</p></div>`;
        } catch (e) { alert(e.message); }
      });
    } catch (e) { alert(e.message); }
  });
}

/* ----- sync ----- */
async function renderSync() {
  const el = $("#tab-sync");
  const s = await api("/sync");
  el.innerHTML = `
    <h1>Excel Synchronization</h1>
    <p class="sub">${s.configured ? "Webhook configured — rows flow to the workbook automatically with retries."
      : "EXCEL_WEBHOOK_URL is not set on the server yet — rows queue here until it is (nothing is lost)."}</p>
    <div class="panel">
      <h2>Pending / failed (${s.pendingOrFailed.length})</h2>
      ${s.pendingOrFailed.length ? `<div class="tbl-wrap"><table class="tbl">
        <tr><th>ID</th><th>Table</th><th>Status</th><th>Attempts</th><th>Last error</th><th>Next retry</th><th></th></tr>
        ${s.pendingOrFailed.map(r => `<tr><td>${r.id}</td><td>${esc(r.table_name)}</td>
          <td><span class="badge ${r.status === "failed" ? "bad" : "warn"}">${r.status}</span></td>
          <td>${r.attempts}</td><td style="max-width:280px">${esc(r.last_error || "")}</td><td>${esc(r.next_retry || "")}</td>
          <td class="act" data-retry="${r.id}">Retry now</td></tr>`).join("")}</table></div>`
      : '<p class="fineprint">Outbox is clear.</p>'}
    </div>
    <div class="panel"><h2>Recently synced</h2>
      ${s.recentSent.length ? s.recentSent.map(r => `<div class="rem-item"><span class="rem-dot"></span>#${r.id} ${esc(r.table_name)}<span class="rem-when">${esc(r.sent_at)}</span></div>`).join("") : '<p class="fineprint">None yet.</p>'}
    </div>`;
  $$("[data-retry]", el).forEach(a => a.addEventListener("click", async () => {
    await api("/sync/" + a.dataset.retry + "/retry", {}); renderSync();
  }));
}

/* ----- audit ----- */
async function renderAudit() {
  const el = $("#tab-audit");
  const rows = await api("/audit");
  el.innerHTML = `
    <h1>Audit Log</h1>
    <p class="sub">Every sensitive change: who, when, what changed, old → new, related booking.</p>
    <div class="panel">
      <div class="panel-head"><h2>Last ${rows.length} entries</h2>
        <button class="btn btn-ghost btn-mini" id="audExp">Export CSV</button></div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>When</th><th>Who</th><th>Action</th><th>Entity</th><th>Field</th><th>Old → New</th><th>Related</th></tr>
        ${rows.map(a => `<tr><td>${esc(a.ts)}</td><td>${esc(a.user_email)}<br><span style="color:var(--muted)">${esc(a.role)}</span></td>
          <td>${esc(a.action)}</td><td>${esc(a.entity)} ${esc(a.entity_id)}</td><td>${esc(a.field || "")}</td>
          <td style="max-width:260px">${a.field ? esc(a.old_value ?? "—") + " → <b>" + esc(a.new_value ?? "—") + "</b>" : ""}</td>
          <td>${esc(a.related_id || "")}</td></tr>`).join("")}
      </table></div>
    </div>`;
  $("#audExp").addEventListener("click", () => downloadCSV("AuditLog", rows));
}

/* ----- users ----- */
async function renderUsers() {
  const el = $("#tab-users");
  const users = await api("/users");
  el.innerHTML = `
    <h1>Team &amp; Portal Accounts</h1>
    <p class="sub">Roles: admin · sales · ops · partnerships · cx · partner (partner accounts need a Partner ID).</p>
    <div class="panel">
      <h2>Accounts (${users.length})</h2>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>Email</th><th>Name</th><th>Role</th><th>Partner</th><th>Status</th></tr>
        ${users.map(u => `<tr><td>${esc(u.email)}</td><td>${esc(u.name)}</td><td><span class="badge dim">${u.role}</span></td>
          <td>${esc(u.partner_id || "")}</td><td>${u.active ? '<span class="badge ok">active</span>' : '<span class="badge bad">disabled</span>'}${u.must_reset ? ' <span class="badge warn">must reset</span>' : ""}</td></tr>`).join("")}
      </table></div>
    </div>
    <div class="panel">
      <h2>Add account</h2>
      <div class="frm">
        <div><label>Email</label><input class="f-input" id="uEmail"></div>
        <div><label>Name</label><input class="f-input" id="uName"></div>
        <div><label>Role</label><select class="f-select" id="uRole">${["sales", "ops", "partnerships", "cx", "partner", "admin"].map(r => `<option>${r}</option>`).join("")}</select></div>
        <div><label>Partner ID (partner role only)</label><input class="f-input" id="uPartner" placeholder="P-00X"></div>
        <div><label>Temp password (min 10 chars — they must change it)</label><input class="f-input" id="uPass"></div>
      </div>
      <button class="btn btn-primary btn-mini" id="uAdd" style="margin-top:14px">Create account</button>
    </div>`;
  $("#uAdd").addEventListener("click", async () => {
    try {
      await api("/users", { email: $("#uEmail").value.trim(), name: $("#uName").value.trim(), role: $("#uRole").value, partnerId: $("#uPartner").value.trim(), password: $("#uPass").value });
      renderUsers();
    } catch (e) { alert(e.message); }
  });
}

boot();
