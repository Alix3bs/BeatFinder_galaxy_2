/* ============================================================
   Phase 4.1 test suite — Lumino adapter (mock backend), AI
   availability agent, temporary holds, payment-method selection.
   Run: node tests/phase41.mjs
   ============================================================ */
import { spawn } from "node:child_process";
import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const PORT = 8960, MOCK_XL = 8961, B = `http://localhost:${PORT}`;
const PAY_SECRET = "p41-mock-pay";
const results = [];
const rec = (n, name, okv, detail) => { results.push({ n, name, ok: okv, detail: detail || "" }); console.log(`${okv ? "PASS" : "FAIL"}  ${String(n).padStart(2)} · ${name}${detail ? "  — " + detail : ""}`); };
const assert = (c, m) => { if (!c) throw new Error(m); };

function client() {
  let cookie = "";
  return async (p, body, method, headers, raw) => {
    const res = await fetch(B + p, {
      method: method || (body !== undefined ? "POST" : "GET"),
      headers: { ...(body !== undefined && !raw ? { "Content-Type": "application/json" } : {}), ...(cookie ? { cookie } : {}), ...(headers || {}) },
      body: raw ? body : body !== undefined ? JSON.stringify(body) : undefined
    });
    const sc = res.headers.get("set-cookie");
    if (sc) cookie = sc.split(";")[0];
    return { status: res.status, data: await res.json().catch(() => ({})) };
  };
}
const sign = raw => crypto.createHmac("sha256", PAY_SECRET).update(raw).digest("hex");
const webhook = (anon, evt) => {
  const raw = JSON.stringify(evt);
  return anon("/api/payments/webhook/mock", raw, "POST", { "x-mock-signature": sign(raw), "content-type": "application/json" }, true);
};

const xlRows = [];
const mockXl = http.createServer((q, s) => { let b = ""; q.on("data", c => b += c); q.on("end", () => { xlRows.push(JSON.parse(b)); s.writeHead(200); s.end("ok"); }); });

const TESTDATA = path.join(ROOT, "data-p41");
fs.rmSync(TESTDATA, { recursive: true, force: true });
const proc = spawn("node", ["server.js"], {
  cwd: ROOT,
  env: { ...process.env, PORT, TN_ENV: "staging", TN_DATA_DIR: TESTDATA,
    EXCEL_WEBHOOK_URL: `http://localhost:${MOCK_XL}/hook`, MOCK_PAY_SECRET: PAY_SECRET, TN_RATE_REQUESTS: "100",
    TN_ADMIN_PASSWORD: "P41Admin26!!", TN_SALES_PASSWORD: "P41Sales26!!", TN_OPS_PASSWORD: "P41Ops26!!",
    TN_PARTNER1_PASSWORD: "P41Part1x26!!", TN_PARTNER2_PASSWORD: "P41Part2x26!!" },
  stdio: ["ignore", "ignore", "pipe"]
});
proc.stderr.on("data", d => { const s = String(d); if (!s.includes("Experimental")) process.stderr.write(s); });

const CONSENTS = { terms: true, privacy: true, cancellation: true, deposit: true, vehicleRules: true, communication: true, documents: true };
const REQ = o => ({
  customerName: "Pilot FortyOne", phone: "(305) 555-6161", email: "p41@example.com",
  vehicleRequested: "Lamborghini Huracán EVO", backupVehicle: "Mercedes-AMG G63",
  startDate: "2026-11-01 10:00", endDate: "2026-11-03 10:00",
  option: "delivery", deliveryLocation: "Brickell, Miami-Dade", depositReadiness: "Ready",
  driverAge: "30–39", licenseStatus: "Confirmed by customer", insuranceStatus: "Confirmed by customer",
  consents: CONSENTS, consentText: "p41 consent", ...o
});

async function main() {
  mockXl.listen(MOCK_XL);
  for (let i = 0; i < 40; i++) { try { await fetch(B + "/api/health"); break; } catch (e) { await new Promise(r => setTimeout(r, 250)); } }
  const anon = client(), admin = client(), sales = client(), ops = client(), p1 = client(), p2 = client();
  await admin("/api/auth/login", { email: "admin@topnotchrentalz.com", password: "P41Admin26!!" });
  await sales("/api/auth/login", { email: "sales@topnotchrentalz.com", password: "P41Sales26!!" });
  await ops("/api/auth/login", { email: "ops@topnotchrentalz.com", password: "P41Ops26!!" });
  await p1("/api/auth/login", { email: "portal@prestigeauto.example", password: "P41Part1x26!!" });
  await p2("/api/auth/login", { email: "portal@velocityexotics.example", password: "P41Part2x26!!" });
  const pc = { "P-001": p1, "P-002": p2 };

  let idA, holdExp;

  /* 1 · cannot pay before requesting / before approval */
  try {
    const ghost = await anon("/api/public/pay", { requestId: "TN-000000-XXXX", phone: "0000", method: "card" });
    assert(ghost.status === 404, "unknown request must 404");
    const r = await anon("/api/public/requests", REQ({}));
    idA = r.data.requestId;
    const early = await anon("/api/public/pay", { requestId: idA, phone: "6161", method: "card" });
    assert(early.status === 409, "pay before approval must be blocked, got " + early.status);
    rec(1, "Customer cannot pay before requesting/approval", true, "404 unknown · 409 unapproved");
  } catch (e) { rec(1, "No pay before request", false, e.message); }

  /* 2 · request saved with agent verdict */
  let row;
  try {
    row = (await sales("/api/requests")).data.find(x => x.request_id === idA);
    assert(row && row.availability_status && row.availability_checked_at, "agent fields set");
    rec(2, "Request saved + agent ran", true, `availability=${row.availability_status}`);
  } catch (e) { rec(2, "Request saved", false, e.message); }

  /* 3 · AI finds the vehicle available → auto provider confirmation stage */
  try {
    assert(row.availability_status === "available", "expected available, got " + row.availability_status);
    assert(row.status === "Availability being confirmed" && row.assigned_vehicle_id, "auto-advanced to provider check with a unit");
    rec(3, "AI finds vehicle available", true, `unit ${row.assigned_vehicle_id}`);
  } catch (e) { rec(3, "AI available", false, e.message); }

  /* 4 · AI detects overlapping dates (F8 is booked 07-02→09) */
  let idOverlap;
  try {
    const r = await anon("/api/public/requests", REQ({ vehicleRequested: "Ferrari F8 Tributo", phone: "(305) 555-6262", email: "p41b@example.com", startDate: "2026-07-05 10:00", endDate: "2026-07-08 10:00" }));
    idOverlap = r.data.requestId;
    const rr = (await sales("/api/requests")).data.find(x => x.request_id === idOverlap);
    assert(rr.availability_status === "unavailable", "expected unavailable, got " + rr.availability_status);
    rec(4, "AI finds overlapping dates", true, "F8 07/05–07/08 → unavailable");
  } catch (e) { rec(4, "AI overlap", false, e.message); }

  /* 5 · AI detects stale inventory → manual confirmation required */
  try {
    await admin("/api/vehicles/V-1006", { last_verified: "2026-01-01" }, "PATCH");
    await admin("/api/vehicles/V-1007", { last_verified: "2026-01-01" }, "PATCH");
    const r = await anon("/api/public/requests", REQ({ vehicleRequested: "Mercedes-AMG G63", phone: "(305) 555-6363", email: "p41c@example.com", startDate: "2026-11-10 10:00", endDate: "2026-11-12 10:00" }));
    const rr = (await sales("/api/requests")).data.find(x => x.request_id === r.data.requestId);
    assert(rr.availability_status === "manual" && rr.status === "Manual availability confirmation required", JSON.stringify({ a: rr.availability_status, s: rr.status }));
    const notif = (await admin("/api/notifications")).data.find(n => n.type === "AI_MANUAL" && (n.title || "").includes(r.data.requestId));
    assert(notif, "ops notified");
    await admin("/api/vehicles/V-1006", { last_verified: new Date().toISOString().slice(0, 10) }, "PATCH");
    await admin("/api/vehicles/V-1007", { last_verified: new Date().toISOString().slice(0, 10) }, "PATCH");
    rec(5, "AI detects stale inventory → manual confirmation + team notified", true);
  } catch (e) { rec(5, "AI stale", false, e.message); }

  /* 6 + 8 · provider confirms → approval creates a temporary hold */
  try {
    const conf = await pc[(await sales(`/api/requests/${idA}/matches`)).data.exact[0].partner_id](`/api/portal/bookings/${idA}/decision`, { decision: "confirm" });
    assert(conf.status === 200, "provider confirm");
    rec(6, "Provider confirms availability", true);
    const ap = await sales(`/api/requests/${idA}/approve`, { finalPrice: 2498, internalCost: 1700 });
    assert(ap.status === 200 && ap.data.holdExpires, "approve must create hold: " + JSON.stringify(ap.data));
    holdExp = ap.data.holdExpires;
    const po = await anon(`/api/public/payment-options?id=${idA}&phone=6161`);
    assert(po.data.state === "available" && po.data.holdExpiresAt && po.data.breakdown.totalDueNow > 0, JSON.stringify(po.data).slice(0, 200));
    rec(8, "Temporary hold created + customer sees countdown & full breakdown", true, "expires " + holdExp.slice(11, 16));
  } catch (e) { rec(6, "Provider confirms", false, e.message); rec(8, "Hold created", false, e.message); }

  /* 7 · provider declines (separate request) */
  try {
    const r = await anon("/api/public/requests", REQ({ phone: "(305) 555-6464", email: "p41d@example.com", startDate: "2026-12-01 10:00", endDate: "2026-12-03 10:00" }));
    const rr = (await sales("/api/requests")).data.find(x => x.request_id === r.data.requestId);
    const dec = await pc[(await sales(`/api/requests/${r.data.requestId}/matches`)).data.exact.find(v => v.vehicle_id === rr.assigned_vehicle_id).partner_id](`/api/portal/bookings/${r.data.requestId}/decision`, { decision: "decline", note: "out" });
    assert(dec.status === 200, "decline");
    const after = (await sales("/api/requests")).data.find(x => x.request_id === r.data.requestId);
    assert(after.status === "Under review" && !after.assigned_vehicle_id, "back to review");
    rec(7, "Provider declines availability", true);
  } catch (e) { rec(7, "Provider declines", false, e.message); }

  /* 9 · second customer cannot reach payment on the held unit */
  try {
    const r2 = await anon("/api/public/requests", REQ({ phone: "(305) 555-6565", email: "p41e@example.com", startDate: "2026-11-02 10:00", endDate: "2026-11-04 10:00" }));
    const rr2 = (await sales("/api/requests")).data.find(x => x.request_id === r2.data.requestId);
    const heldUnit = (await sales("/api/requests")).data.find(x => x.request_id === idA).assigned_vehicle_id;
    assert(rr2.assigned_vehicle_id !== heldUnit, "agent must not assign the held unit (got " + rr2.assigned_vehicle_id + ")");
    const steal = await sales(`/api/requests/${r2.data.requestId}/assign`, { vehicleId: heldUnit });
    assert(steal.status === 409 && /hold/.test(steal.data.error), "manual assign onto hold must 409: " + JSON.stringify(steal.data));
    const po2 = await anon(`/api/public/payment-options?id=${r2.data.requestId}&phone=6565`);
    assert(po2.data.state !== "available", "second customer must not get a payment panel for the held unit");
    rec(9, "Second customer cannot pay for the held vehicle", true, "agent avoided it; manual assign 409");
  } catch (e) { rec(9, "Hold blocks second customer", false, e.message); }

  /* 10 · payment popup shows only enabled methods */
  try {
    await admin("/api/settings", { methods_zelle: "0", methods_bnpl: "0" }, "PATCH");
    const po = (await anon(`/api/public/payment-options?id=${idA}&phone=6161`)).data;
    const ids = [...po.methods.online, ...po.methods.manual].map(m => m.id);
    assert(!ids.includes("zelle") && !ids.includes("bnpl"), "disabled methods leaked: " + ids.join(","));
    assert(ids.includes("card") && ids.includes("cash"), "enabled methods present");
    const payDisabled = await anon("/api/public/pay", { requestId: idA, phone: "6161", method: "zelle" });
    assert(payDisabled.status === 400, "paying with a disabled method must fail");
    await admin("/api/settings", { methods_zelle: "1" }, "PATCH");
    rec(10, "Payment popup shows only enabled methods", true, ids.join(", "));
  } catch (e) { rec(10, "Enabled methods only", false, e.message); }

  /* 11 · payment link created via the adapter */
  let payUrl;
  try {
    const out = await anon("/api/public/pay", { requestId: idA, phone: "6161", method: "card" });
    assert(out.data.state === "redirect" && out.data.url && out.data.provider === "mock", JSON.stringify(out.data));
    payUrl = out.data.url;
    const rr = (await sales("/api/requests")).data.find(x => x.request_id === idA);
    assert(rr.payment_status === "Payment pending", "status " + rr.payment_status);
    rec(11, "Hosted payment link created via provider adapter", true, out.data.provider);
  } catch (e) { rec(11, "Payment link", false, e.message); }

  /* 12 + 13 · invalid webhook rejected; duplicate ignored */
  try {
    const raw = JSON.stringify({ id: "evt_p41_1", type: "payment.succeeded", amount: 2498, payment_id: "pm1", metadata: { requestId: idA, category: "rental-payment" } });
    const badSig = await anon("/api/payments/webhook/mock", raw, "POST", { "x-mock-signature": "f".repeat(64), "content-type": "application/json" }, true);
    assert(badSig.status === 400, "invalid signature must 400");
    rec(12, "Invalid webhook is rejected", true);
    const ok1 = await webhook(anon, { id: "evt_p41_1", type: "payment.succeeded", amount: 2498, payment_id: "pm1", metadata: { requestId: idA, category: "rental-payment" } });
    assert(ok1.status === 200 && !ok1.data.duplicate, "first delivery processed");
    const dup = await webhook(anon, { id: "evt_p41_1", type: "payment.succeeded", amount: 2498, payment_id: "pm1", metadata: { requestId: idA, category: "rental-payment" } });
    assert(dup.data.duplicate === true, "duplicate must be ignored");
    rec(13, "Duplicate webhook is ignored", true, "evt_p41_1 processed once");
  } catch (e) { rec(12, "Webhook security", false, e.message); rec(13, "Duplicate webhook", false, e.message); }

  /* 14 · successful payment confirms booking + converts hold */
  try {
    const rr = (await sales("/api/requests")).data.find(x => x.request_id === idA);
    assert(rr.status === "Booking confirmed" && rr.payment_status === "verified", JSON.stringify({ s: rr.status, p: rr.payment_status }));
    const rentals = (await ops("/api/rentals")).data;
    assert(rentals.some(x => x.request_id === idA), "rental created");
    const holds = (await admin("/api/payment-events")).data.holds.filter(h => h.request_id === idA);
    assert(holds[0].status === "converted", "hold must convert, got " + holds[0].status);
    rec(14, "Successful payment confirms the booking", true, "hold converted → " + rentals.find(x => x.request_id === idA).rental_id);
  } catch (e) { rec(14, "Payment confirms", false, e.message); }

  /* 15 · failed payment does NOT confirm */
  let idF;
  try {
    const r = await anon("/api/public/requests", REQ({ phone: "(305) 555-6767", email: "p41f@example.com", startDate: "2026-12-10 10:00", endDate: "2026-12-12 10:00" }));
    idF = r.data.requestId;
    const rr = (await sales("/api/requests")).data.find(x => x.request_id === idF);
    await pc[(await sales(`/api/requests/${idF}/matches`)).data.exact.find(v => v.vehicle_id === rr.assigned_vehicle_id).partner_id](`/api/portal/bookings/${idF}/decision`, { decision: "confirm" });
    await sales(`/api/requests/${idF}/approve`, { finalPrice: 2400, internalCost: 1700 });
    await anon("/api/public/pay", { requestId: idF, phone: "6767", method: "card" });
    await webhook(anon, { id: "evt_p41_fail", type: "payment.failed", amount: 2400, payment_id: "pmF", metadata: { requestId: idF, category: "rental-payment" } });
    const after = (await sales("/api/requests")).data.find(x => x.request_id === idF);
    assert(after.status !== "Booking confirmed" && after.payment_status === "Payment failed", JSON.stringify({ s: after.status, p: after.payment_status }));
    rec(15, "Failed payment does not confirm the booking", true, "hold stays active until expiry");
  } catch (e) { rec(15, "Failed payment", false, e.message); }

  /* 16 · expired hold blocks payment and forces recheck */
  try {
    await admin(`/api/requests/${idF}/hold`, { action: "release" });
    const blocked = await anon("/api/public/pay", { requestId: idF, phone: "6767", method: "card" });
    assert(blocked.data.state === "rechecking", "expired/released hold must trigger recheck: " + JSON.stringify(blocked.data));
    const after = (await sales("/api/requests")).data.find(x => x.request_id === idF);
    assert(after.status === "Availability being confirmed", "provider must reconfirm: " + after.status);
    rec(16, "Expired hold blocks payment → availability re-run + provider reconfirm", true);
  } catch (e) { rec(16, "Expired hold", false, e.message); }

  /* 17 · manual payment requires ADMIN verification */
  try {
    const r = await anon("/api/public/requests", REQ({ phone: "(305) 555-6868", email: "p41g@example.com", startDate: "2026-12-20 10:00", endDate: "2026-12-22 10:00" }));
    const id = r.data.requestId;
    const rr = (await sales("/api/requests")).data.find(x => x.request_id === id);
    await pc[(await sales(`/api/requests/${id}/matches`)).data.exact.find(v => v.vehicle_id === rr.assigned_vehicle_id).partner_id](`/api/portal/bookings/${id}/decision`, { decision: "confirm" });
    await sales(`/api/requests/${id}/approve`, { finalPrice: 2400, internalCost: 1700 });
    const manual = await anon("/api/public/pay", { requestId: id, phone: "6868", method: "zelle" });
    assert(manual.data.state === "manual", JSON.stringify(manual.data));
    const mid = (await sales("/api/requests")).data.find(x => x.request_id === id);
    assert(mid.payment_status === "Payment verification required" && mid.status !== "Booking confirmed", "must NOT auto-confirm");
    const salesTry = await sales(`/api/requests/${id}/payment-verified`, { amount: 2400, method: "zelle" });
    assert(salesTry.status === 403, "sales must not verify manual payments: " + salesTry.status);
    const adminOk = await admin(`/api/requests/${id}/payment-verified`, { amount: 2400, method: "zelle" });
    assert(adminOk.status === 200 && adminOk.data.rentalId, JSON.stringify(adminOk.data));
    rec(17, "Manual payment requires admin verification", true, "sales 403 → admin confirms");
  } catch (e) { rec(17, "Manual verification", false, e.message); }

  /* 18 · unavailable vehicle displays up to two alternatives (customer-safe) */
  try {
    const po = (await anon(`/api/public/payment-options?id=${idOverlap}&phone=6262`)).data;
    assert(po.state === "unavailable" && po.alternatives.length >= 1 && po.alternatives.length <= 2, JSON.stringify(po).slice(0, 160));
    const alt = po.alternatives[0];
    assert(alt.pricePerDay && alt.deposit && alt.delivery, "alt shows price/deposit/delivery");
    const sw = await anon(`/api/public/requests/${idOverlap}/choose-alternative`, { phone: "6262", model: alt.model });
    assert(sw.status === 200 && sw.data.agentResult, "switch without re-filling the form: " + JSON.stringify(sw.data));
    rec(18, "Unavailable vehicle displays alternatives + one-tap switch", true, alt.name);
  } catch (e) { rec(18, "Alternatives", false, e.message); }

  /* 19 · database and Excel update correctly */
  try {
    const sync = (await admin("/api/sync")).data;
    for (const p of sync.pendingOrFailed.slice(0, 30)) await admin(`/api/sync/${p.id}/retry`, {});
    await new Promise(r => setTimeout(r, 400));
    const tables = new Set(xlRows.map(x => x.table));
    assert(tables.has("CustomerRequests") && tables.has("Payments") && tables.has("PartnerInventory") && tables.has("ActiveRentals"),
      "tables synced: " + [...tables].join(","));
    const holdRow = xlRows.find(x => x.table === "PartnerInventory" && "activeHold" in (x.row || {}));
    assert(holdRow, "vehicle rows carry hold info");
    const leak = xlRows.some(x => JSON.stringify(x).match(/LUMINO_|api[_-]?key|card_number|cvv|webhook_secret/i));
    assert(!leak, "no credentials/card data in Excel rows");
    rec(19, "Database and Excel update correctly", true, `${xlRows.length} rows · tables: ${[...tables].join(", ")}`);
  } catch (e) { rec(19, "Excel sync", false, e.message); }

  /* 20 · customer never receives provider cost or profit details */
  try {
    const bodies = [
      (await anon(`/api/public/payment-options?id=${idA}&phone=6161`)).data,
      (await anon(`/api/public/track?id=${idA}&phone=6161`)).data,
      (await anon(`/api/public/payment-options?id=${idOverlap}&phone=6262`)).data
    ];
    const s = JSON.stringify(bodies);
    assert(!/provider_rate|providerRate|provider_payout|internal_cost|profit|payout/i.test(s), "leak: " + s.slice(0, 200));
    rec(20, "Customer never receives provider cost or profit details", true, "all public payloads scanned clean");
  } catch (e) { rec(20, "No internal leaks", false, e.message); }

  const pass = results.filter(r => r.ok).length;
  const md = ["# Phase 4.1 — Test Results (Lumino adapter · AI agent · holds · payment methods)", "",
    `Run: ${new Date().toISOString()} · fresh staging DB · provider backend: mock (Lumino adapter awaiting merchant credentials)`,
    "", "| # | Scenario | Result | Detail |", "|---|----------|--------|--------|",
    ...results.map(r => `| ${r.n} | ${r.name} | ${r.ok ? "✅ PASS" : "❌ FAIL"} | ${r.detail} |`),
    "", `**${pass}/${results.length} passed.**`].join("\n");
  fs.writeFileSync(path.join(ROOT, "TEST-RESULTS-PHASE41.md"), md);
  console.log(`\n${pass}/${results.length} passed → TEST-RESULTS-PHASE41.md`);
  proc.kill(); mockXl.close();
  fs.rmSync(TESTDATA, { recursive: true, force: true });
  process.exit(pass === results.length ? 0 : 1);
}
main().catch(e => { console.error("FATAL", e); proc.kill(); process.exit(1); });
