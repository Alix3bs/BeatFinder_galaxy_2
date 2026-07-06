/* ============================================================
   TopNotchRentalz — Partner Portal (API client)
   The server scopes every query to the signed-in partner_id.
   Partners never see other providers, customer prices or profit.
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
  if (res.status === 401) { $("#gate").hidden = false; $("#app").hidden = true; throw new Error("Signed out"); }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || "HTTP " + res.status);
  return data;
}

async function boot() {
  try {
    const { user } = await api("/auth/me");
    ME = user;
    if (ME.role !== "partner") { $("#gateMsg").textContent = "This portal is for vehicle providers. Team members use /admin/."; return show(false); }
    if (ME.mustReset) { $("#loginForm").hidden = true; $("#newPassForm").hidden = false; return show(false); }
    show(true);
  } catch (e) { show(false); }
}
function show(inApp) {
  $("#gate").hidden = inApp; $("#app").hidden = !inApp;
  if (inApp) { $("#whoami").textContent = `${ME.name} · ${ME.partnerId}`; renderAll(); }
}

$("#loginBtn").addEventListener("click", doLogin);
$("#loginPass").addEventListener("keydown", e => { if (e.key === "Enter") doLogin(); });
async function doLogin() {
  try {
    const out = await api("/auth/login", { email: $("#loginEmail").value.trim(), password: $("#loginPass").value });
    ME = out.user;
    if (ME.role !== "partner") { $("#gateMsg").textContent = "This portal is for vehicle providers."; return; }
    if (ME.mustReset) { $("#loginForm").hidden = true; $("#newPassForm").hidden = false; return; }
    show(true);
  } catch (e) { $("#gateMsg").textContent = e.message; }
}
$("#npBtn").addEventListener("click", async () => {
  try {
    await api("/auth/change-password", { current: $("#npCurrent").value, next: $("#npNext").value });
    const { user } = await api("/auth/me"); ME = user; show(true);
  } catch (e) { $("#gateMsg").textContent = e.message; }
});
$("#logoutBtn").addEventListener("click", async () => { await api("/auth/logout", {}); location.reload(); });

$$("#sideNav button").forEach(b => b.addEventListener("click", () => {
  $$("#sideNav button").forEach(x => x.classList.toggle("on", x === b));
  $$(".tab").forEach(t => (t.hidden = t.id !== "tab-" + b.dataset.tab));
  renderAll();
}));
const activeTab = () => $("#sideNav button.on")?.dataset.tab || "vehicles";

async function renderAll() {
  const t = activeTab();
  try {
    if (t === "vehicles") await renderVehicles();
    if (t === "bookings") await renderBookings();
    if (t === "payouts") await renderPayouts();
    if (t === "messages") await renderMessages();
    const bk = await api("/portal/bookings").catch(() => []);
    $("#bkCount").textContent = bk.filter(b => b.needsDecision).length || "";
  } catch (e) { if (e.message !== "Signed out") console.warn(e); }
}

/* ----- my vehicles ----- */
async function renderVehicles() {
  const el = $("#tab-vehicles");
  const rows = await api("/portal/vehicles");
  el.innerHTML = `
    <h1>My Vehicles</h1>
    <p class="sub">Your fleet only. Update rates, deposits, mileage rules and availability — changes reach the TopNotchRentalz team instantly.</p>
    <div class="panel">
      <div class="panel-head"><h2>Fleet (${rows.length})</h2>
        <button class="btn btn-primary btn-mini" id="pvAdd">+ Add vehicle</button></div>
      <div class="tbl-wrap"><table class="tbl">
        <tr><th>Unit</th><th>Vehicle</th><th>My rate/day</th><th>Deposit</th><th>Miles/day</th><th>Status</th><th>Booked dates</th><th></th></tr>
        ${rows.map(v => `
          <tr><td><b>${v.vehicle_id}</b></td>
          <td>${v.year || ""} ${esc(v.make)} ${esc(v.model)}<br><span style="color:var(--muted)">${esc(v.trim || "")} · ${esc(v.color || "")}</span></td>
          <td>${money(v.provider_rate)}</td><td>${money(v.deposit)}</td><td>${v.mileage_included}</td>
          <td><select class="f-select" style="padding:6px 10px;font-size:11.5px" data-st="${v.vehicle_id}">
            ${["available", "booked", "maintenance", "unavailable"].map(s => `<option ${v.status === s ? "selected" : ""}>${s}</option>`).join("")}
          </select></td>
          <td style="max-width:160px;font-size:11px">${esc(JSON.parse(v.booked_dates || "[]").join(", ") || "—")}</td>
          <td class="act" data-edit="${v.vehicle_id}">Edit →</td></tr>`).join("")}
      </table></div>
    </div>
    <div id="pvForm"></div>`;
  $("#pvAdd").addEventListener("click", () => pvForm(null));
  $$("[data-edit]", el).forEach(a => a.addEventListener("click", () => pvForm(rows.find(v => v.vehicle_id === a.dataset.edit))));
  $$("[data-st]", el).forEach(s => s.addEventListener("change", async () => {
    await api("/portal/vehicles/" + s.dataset.st, { status: s.value }, "PATCH").catch(e => alert(e.message));
    renderVehicles();
  }));
}
function pvForm(v) {
  const isNew = !v; v = v || {};
  const F = [["year", "Year"], ["make", "Make *"], ["model", "Model *"], ["trim", "Trim"], ["color", "Color"],
    ["provider_rate", "My daily rate ($)"], ["deposit", "Deposit ($)"], ["mileage_included", "Miles/day"],
    ["mileage_fee", "Extra mile fee ($)"], ["min_days", "Min rental days"], ["notes", "Notes"]];
  $("#pvForm").innerHTML = `
    <div class="panel"><h2>${isNew ? "Add vehicle" : "Edit " + v.vehicle_id}</h2>
      <div class="frm">${F.map(f => `<div><label>${f[1]}</label><input class="f-input" id="pv_${f[0]}" value="${esc(v[f[0]] ?? "")}"></div>`).join("")}
      ${isNew ? "" : `<div><label>Block dates (YYYY-MM-DD→YYYY-MM-DD, comma separated)</label>
        <input class="f-input" id="pv_booked" value="${esc(JSON.parse(v.booked_dates || "[]").join(", "))}"></div>`}
      </div>
      <div class="frm-full" style="margin-top:10px">
        <label>Vehicle photos (JPEG/PNG/WebP, max 5 MB)</label>
        <input class="f-input" type="file" id="pvPhoto" accept="image/jpeg,image/png,image/webp">
      </div>
      <div style="display:flex;gap:10px;margin-top:14px">
        <button class="btn btn-primary btn-mini" id="pvSave">Save</button>
        ${isNew ? "" : '<button class="btn btn-ghost btn-mini" id="pvDel" style="border-color:rgba(239,68,68,.5);color:#f87171">Remove vehicle</button>'}
      </div>
    </div>`;
  $("#pvForm").scrollIntoView({ behavior: "smooth" });
  $("#pvPhoto")?.addEventListener("change", e => {
    const f = e.target.files[0]; if (!f || isNew) return alert(isNew ? "Save the vehicle first, then add photos." : "");
    const rd = new FileReader();
    rd.onload = async () => {
      try { await api("/uploads", { data: rd.result, vehicleId: v.vehicle_id, kind: "vehicle", filename: f.name }); alert("Photo uploaded"); }
      catch (err) { alert(err.message); }
    };
    rd.readAsDataURL(f);
  });
  $("#pvSave").addEventListener("click", async () => {
    const body = {};
    F.forEach(f => body[f[0]] = $("#pv_" + f[0]).value.trim());
    if (!isNew && $("#pv_booked")) body.booked_dates = $("#pv_booked").value.split(",").map(s => s.trim()).filter(Boolean);
    try {
      if (isNew) await api("/portal/vehicles", body);
      else await api("/portal/vehicles/" + v.vehicle_id, body, "PATCH");
      renderVehicles();
    } catch (e) { alert(e.message); }
  });
  $("#pvDel")?.addEventListener("click", async () => {
    if (!confirm("Remove this vehicle from TopNotchRentalz?")) return;
    await api("/portal/vehicles/" + v.vehicle_id, undefined, "DELETE").catch(e => alert(e.message));
    renderVehicles();
  });
}

/* ----- bookings ----- */
async function renderBookings() {
  const el = $("#tab-bookings");
  const rows = await api("/portal/bookings");
  el.innerHTML = `
    <h1>Booking Requests</h1>
    <p class="sub">Confirm or decline availability. Customer contact details are shared once the booking is confirmed.</p>
    <div class="panel">
      ${rows.length ? `<div class="tbl-wrap"><table class="tbl">
        <tr><th>Request</th><th>Unit</th><th>Dates</th><th>Handover</th><th>Customer</th><th>Status</th><th></th></tr>
        ${rows.map(b => `
          <tr><td><b>${b.requestId}</b></td><td>${b.vehicleId}</td>
          <td>${(b.startDate || "").slice(0, 10)} → ${(b.endDate || "").slice(0, 10)}</td>
          <td>${esc(b.deliveryArea)}</td>
          <td>${esc(b.customer)}${b.customerPhone ? `<br><span style="color:var(--muted)">${esc(b.customerPhone)}</span>` : ""}</td>
          <td><span class="badge ${b.status === "Booking confirmed" ? "ok" : b.needsDecision ? "warn" : "dim"}">${esc(b.status)}</span></td>
          <td>${b.needsDecision ? `<button class="btn btn-primary btn-mini" data-yes="${b.requestId}">Confirm</button>
            <button class="btn btn-ghost btn-mini" data-no="${b.requestId}">Decline</button>` : ""}</td></tr>`).join("")}
      </table></div>` : '<p class="fineprint">No bookings assigned to your fleet yet.</p>'}
    </div>`;
  $$("[data-yes]", el).forEach(b => b.addEventListener("click", async () => {
    await api(`/portal/bookings/${b.dataset.yes}/decision`, { decision: "confirm" }).catch(e => alert(e.message));
    renderAll();
  }));
  $$("[data-no]", el).forEach(b => b.addEventListener("click", async () => {
    await api(`/portal/bookings/${b.dataset.no}/decision`, { decision: "decline", note: prompt("Reason (optional)") || "" }).catch(e => alert(e.message));
    renderAll();
  }));
}

/* ----- payouts ----- */
async function renderPayouts() {
  const el = $("#tab-payouts");
  const rows = await api("/portal/payouts");
  el.innerHTML = `
    <h1>My Payouts</h1>
    <p class="sub">Amounts owed to you per completed booking. Question anything that looks off.</p>
    <div class="panel">
      ${rows.length ? `<div class="tbl-wrap"><table class="tbl">
        <tr><th>Rental</th><th>Vehicle</th><th>Dates</th><th>Payout</th><th>Status</th><th></th></tr>
        ${rows.map(x => `<tr><td><b>${x.rental_id}</b></td><td>${esc(x.vehicle)}</td>
          <td>${(x.pickup_date || "").slice(0, 10)} → ${(x.return_date || "").slice(0, 10)}</td>
          <td style="color:var(--orange);font-weight:800">${money(x.provider_payout)}</td>
          <td>${x.payout_paid === "Yes" ? '<span class="badge ok">paid</span>' : '<span class="badge warn">pending</span>'}
              ${x.payout_questioned === "Yes" ? ' <span class="badge bad">questioned</span>' : ""}</td>
          <td>${x.payout_questioned !== "Yes" ? `<span class="act" data-q="${x.rental_id}">Question</span>` : ""}</td></tr>`).join("")}
      </table></div>` : '<p class="fineprint">No payouts yet.</p>'}
    </div>`;
  $$("[data-q]", el).forEach(a => a.addEventListener("click", async () => {
    await api(`/portal/payouts/${a.dataset.q}/question`, { note: prompt("What looks wrong?") || "" }).catch(e => alert(e.message));
    renderPayouts();
  }));
}

/* ----- messages ----- */
async function renderMessages() {
  const el = $("#tab-messages");
  const rows = await api("/portal/messages");
  el.innerHTML = `
    <h1>Messages</h1>
    <p class="sub">Direct line to the TopNotchRentalz operations team.</p>
    <div class="panel">
      <div style="max-height:380px;overflow-y:auto;display:grid;gap:8px;margin-bottom:14px" id="msgList">
        ${rows.length ? rows.map(m => `
          <div style="justify-self:${m.from_role === "partner" ? "end" : "start"};max-width:75%;padding:10px 14px;border-radius:14px;font-size:13px;
            background:${m.from_role === "partner" ? "rgba(255,106,0,.12)" : "rgba(255,255,255,.05)"};border:1px solid var(--line)">
            ${esc(m.body)}<div style="font-size:10px;color:var(--muted);margin-top:4px">${esc(m.from_email)} · ${esc(m.ts)}</div>
          </div>`).join("") : '<p class="fineprint">No messages yet — say hi.</p>'}
      </div>
      <div style="display:flex;gap:10px">
        <input class="f-input" id="msgBody" placeholder="Message the ops team…" style="flex:1">
        <button class="btn btn-primary btn-mini" id="msgSend">Send</button>
      </div>
    </div>`;
  const send = async () => {
    const body = $("#msgBody").value.trim();
    if (!body) return;
    await api("/portal/messages", { body }).catch(e => alert(e.message));
    renderMessages();
  };
  $("#msgSend").addEventListener("click", send);
  $("#msgBody").addEventListener("keydown", e => { if (e.key === "Enter") send(); });
}

boot();
