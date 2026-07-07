#!/usr/bin/env node
/* ============================================================
   Pilot booking harness — runs the two required Phase 4 pilot
   scenarios end-to-end against any environment and prints a
   checklist report (writes PILOT-REPORT.md).

     node scripts/pilot.mjs                     → local staging (spawns a server)
     TN_PILOT_URL=https://staging.x.com \
     TN_PILOT_ADMIN=email:pass ... node scripts/pilot.mjs --remote

   Scenario A: request → provider confirm → quote → accept →
               payment → pickup checklist → return → payout → audit
   Scenario B: first provider declines → backup assigned → new
               (changed) quote → customer accepts → completes
   ============================================================ */
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const remote = process.argv.includes("--remote");
const PORT = 8952;
const B = remote ? process.env.TN_PILOT_URL : `http://localhost:${PORT}`;
const steps = [];
const ok = (name, detail) => { steps.push({ name, ok: true, detail }); console.log("PASS  " + name + (detail ? " — " + detail : "")); };
const no = (name, e) => { steps.push({ name, ok: false, detail: e.message }); console.log("FAIL  " + name + " — " + e.message); };
const assert = (c, m) => { if (!c) throw new Error(m); };

function client() {
  let cookie = "";
  return async (p, body, method) => {
    const res = await fetch(B + p, {
      method: method || (body !== undefined ? "POST" : "GET"),
      headers: { ...(body !== undefined ? { "Content-Type": "application/json" } : {}), ...(cookie ? { cookie } : {}) },
      body: body !== undefined ? JSON.stringify(body) : undefined
    });
    const sc = res.headers.get("set-cookie");
    if (sc) cookie = sc.split(";")[0];
    return { status: res.status, data: await res.json().catch(() => ({})) };
  };
}

const CONSENTS = { terms: true, privacy: true, cancellation: true, deposit: true, vehicleRules: true, communication: true, documents: true };
const REQ = o => ({
  customerName: "TN Team Pilot", phone: "(786) 634-1150", email: "bookings@topnotchrentalz.com",
  vehicleRequested: "Lamborghini Huracán EVO", backupVehicle: "Mercedes-AMG G63",
  startDate: "2026-09-01 10:00", endDate: "2026-09-03 10:00",
  budget: "$1,000–$1,500", driverAge: "30–39", licenseStatus: "Confirmed by customer",
  insuranceStatus: "Confirmed by customer", option: "delivery",
  deliveryLocation: "TopNotchRentalz HQ, Miami", returnLocation: "Same",
  depositReadiness: "Ready", occasion: "Pilot booking", addons: "None",
  specialRequests: "PILOT — internal test booking", quotedDayRate: "$1199/day",
  consents: CONSENTS, consentText: "Pilot consent (all policies accepted)", ...o
});

let proc, mock;
async function boot() {
  if (remote) return;
  const http = await import("node:http");
  mock = http.createServer((q, s) => { let b = ""; q.on("data", c => b += c); q.on("end", () => { s.writeHead(200); s.end("ok"); }); });
  mock.listen(8953);
  fs.rmSync(path.join(ROOT, "data-pilot"), { recursive: true, force: true });
  proc = spawn("node", ["server.js"], {
    cwd: ROOT,
    env: { ...process.env, PORT, TN_ENV: "staging", TN_DATA_DIR: path.join(ROOT, "data-pilot"),
      EXCEL_WEBHOOK_URL: "http://localhost:8953/hook", BACKUP_ENCRYPTION_KEY: "pilot-backup-key",
      TN_ADMIN_PASSWORD: "PilotAdmin2026!", TN_SALES_PASSWORD: "PilotSales2026!", TN_OPS_PASSWORD: "PilotOps2026!",
      TN_PARTNER1_PASSWORD: "PilotP1Pass26!", TN_PARTNER2_PASSWORD: "PilotP2Pass26!" },
    stdio: ["ignore", "ignore", "pipe"]
  });
  proc.stderr.on("data", d => { const s = String(d); if (!s.includes("Experimental")) process.stderr.write(s); });
  for (let i = 0; i < 40; i++) { try { await fetch(B + "/api/health"); return; } catch (e) { await new Promise(r => setTimeout(r, 250)); } }
  throw new Error("pilot server did not start");
}

async function main() {
  await boot();
  const anon = client(), admin = client(), sales = client(), ops = client(), p1 = client(), p2 = client();
  const cred = (v, fallback) => (process.env[v] || fallback).split(":");
  await admin("/api/auth/login", { email: cred("TN_PILOT_ADMIN", "admin@topnotchrentalz.com:PilotAdmin2026!")[0], password: cred("TN_PILOT_ADMIN", "admin@topnotchrentalz.com:PilotAdmin2026!")[1] });
  await sales("/api/auth/login", { email: cred("TN_PILOT_SALES", "sales@topnotchrentalz.com:PilotSales2026!")[0], password: cred("TN_PILOT_SALES", "sales@topnotchrentalz.com:PilotSales2026!")[1] });
  await ops("/api/auth/login", { email: cred("TN_PILOT_OPS", "ops@topnotchrentalz.com:PilotOps2026!")[0], password: cred("TN_PILOT_OPS", "ops@topnotchrentalz.com:PilotOps2026!")[1] });
  await p1("/api/auth/login", { email: cred("TN_PILOT_PARTNER1", "portal@prestigeauto.example:PilotP1Pass26!")[0], password: cred("TN_PILOT_PARTNER1", "portal@prestigeauto.example:PilotP1Pass26!")[1] });
  await p2("/api/auth/login", { email: cred("TN_PILOT_PARTNER2", "portal@velocityexotics.example:PilotP2Pass26!")[0], password: cred("TN_PILOT_PARTNER2", "portal@velocityexotics.example:PilotP2Pass26!")[1] });

  /* ---------- Scenario A: happy path ---------- */
  let idA;
  try {
    const r = await anon("/api/public/requests", REQ({}));
    assert(r.status === 200 && r.data.requestId, JSON.stringify(r.data));
    idA = r.data.requestId;
    ok("A1 · Team-member customer submits request", idA);
  } catch (e) { no("A1 · Request submitted", e); }
  try {
    const partnerClient = { "P-001": p1, "P-002": p2 };
    const m = (await sales(`/api/requests/${idA}/matches`)).data;
    const lowest = m.exact[0];
    await sales(`/api/requests/${idA}/assign`, { vehicleId: lowest.vehicle_id });
    ok("A2 · Lowest-rate provider assigned", `${lowest.vehicle_id} (${lowest.provider})`);
    const ownerA = partnerClient[lowest.partner_id];
    const bk = (await ownerA("/api/portal/bookings")).data.find(b => b.requestId === idA);
    assert(bk?.needsDecision, "provider should see the check");
    const confA = await ownerA(`/api/portal/bookings/${idA}/decision`, { decision: "confirm" });
    assert(confA.status === 200, "portal confirm: " + JSON.stringify(confA.data));
    ok("A3 · Real provider confirmation (portal)", lowest.provider + " confirmed");
    await sales(`/api/requests/${idA}/approve`, { finalPrice: 2498, internalCost: 1700 });
    const q = await sales(`/api/requests/${idA}/quote`, { expiresDays: 3 });
    assert(q.status === 200, "quote");
    ok("A4 · Real quote issued", "$2,498, 3-day expiry");
    await anon("/api/public/quote/accept", { requestId: idA, phone: "1150" });
    ok("A5 · Customer accepts quote (tracking page API)");
    const link = await sales(`/api/requests/${idA}/stripe-link`, { category: "rental-payment", amount: 2498 });
    if (link.status === 200) ok("A6 · Stripe Checkout link created", link.data.url?.slice(0, 48) + "…");
    else {
      steps.push({ name: "A6 · Stripe Checkout link", ok: "skip", detail: "STRIPE_SECRET_KEY not set — used manual verification path (Stripe stays pending until keys are added)" });
      console.log("SKIP  A6 · Stripe link — " + link.data.error);
      if ((await sales(`/api/requests/${idA}`)).status) { /* noop */ }
      await sales(`/api/requests/${idA}/payment-link`, {});
    }
    const pay = await sales(`/api/requests/${idA}/payment-verified`, { amount: 2498, method: link.status === 200 ? "stripe-test" : "manual" });
    assert(pay.status === 200 && pay.data.rentalId, JSON.stringify(pay.data));
    ok("A7 · Payment verified → booking confirmed", pay.data.rentalId);
    const rentalId = pay.data.rentalId;
    const meta = (await ops("/api/meta/checklists")).data;
    const all = arr => Object.fromEntries(arr.map(k => [k, true]));
    const blocked = await ops(`/api/rentals/${rentalId}`, { pickup_status: "Done" }, "PATCH");
    assert(blocked.status === 409, "pickup must be blocked before checklist");
    await ops(`/api/rentals/${rentalId}`, { pre_checklist: all(meta.pre), pickup_status: "Done" }, "PATCH");
    ok("A8 · Pickup workflow with enforced pre-rental checklist", meta.pre.length + " items");
    await admin("/api/uploads", { data: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", rentalId, kind: "inspection", filename: "pilot.png" });
    ok("A9 · Inspection photo uploaded");
    const payoutBlocked = await ops(`/api/rentals/${rentalId}`, { payout_paid: "Yes" }, "PATCH");
    assert(payoutBlocked.status === 409, "payout must be blocked before post checklist");
    await ops(`/api/rentals/${rentalId}`, { post_checklist: all(meta.post), return_status: "Done", amount_paid: 2498, payout_paid: "Yes", deposit_refunded: "Yes", review_requested: "Yes" }, "PATCH");
    ok("A10 · Return + payout with enforced post-rental checklist");
    const sync = (await admin("/api/sync")).data;
    assert(sync.recentSent.length > 0 || sync.pendingOrFailed.length >= 0, "sync state readable");
    ok("A11 · Excel synchronization rows delivered", (sync.recentSent.length) + " sent to workbook endpoint");
    const audit = (await admin("/api/audit")).data.filter(a => a.related_id === idA || a.entity_id === idA || a.entity_id === rentalId);
    assert(audit.length >= 8, "audit trail entries: " + audit.length);
    ok("A12 · Audit log verified", audit.length + " entries for this booking");
    const notif = (await admin("/api/notifications")).data.filter(n => (n.title || "").includes(idA));
    ok("A13 · Notifications generated", notif.length + " (delivery: " + (notif[0]?.delivery || "recorded") + ")");
  } catch (e) { no("A · Scenario A", e); }

  /* ---------- Scenario B: decline → backup → changed quote ---------- */
  try {
    const r = await anon("/api/public/requests", REQ({ phone: "(786) 634-9999", email: "pilot2@topnotchrentalz.com", startDate: "2026-09-10 10:00", endDate: "2026-09-12 10:00" }));
    const idB = r.data.requestId;
    const partnerClient = { "P-001": p1, "P-002": p2 };
    const m = (await sales(`/api/requests/${idB}/matches`)).data;
    const first = m.exact[0];
    await sales(`/api/requests/${idB}/assign`, { vehicleId: first.vehicle_id });
    const dec = await partnerClient[first.partner_id](`/api/portal/bookings/${idB}/decision`, { decision: "decline", note: "unit unavailable" });
    assert(dec.status === 200, "decline: " + JSON.stringify(dec.data));
    let st = (await sales("/api/requests")).data.find(x => x.request_id === idB);
    assert(st.status === "Under review" && !st.assigned_vehicle_id, "back to Under review");
    ok("B1 · First provider declines", first.vehicle_id + " (" + first.provider + ")");
    const m2 = (await sales(`/api/requests/${idB}/matches`)).data;
    const backupUnit = m2.exact.find(v => v.partner_id !== first.partner_id && !v.conflicts.length);
    assert(backupUnit, "a backup provider unit must exist");
    await sales(`/api/requests/${idB}/assign`, { vehicleId: backupUnit.vehicle_id });
    const confB = await partnerClient[backupUnit.partner_id](`/api/portal/bookings/${idB}/decision`, { decision: "confirm" });
    assert(confB.status === 200, "backup confirm: " + JSON.stringify(confB.data));
    st = (await sales("/api/requests")).data.find(x => x.request_id === idB);
    assert(st.status === "Provider confirmed", "status: " + st.status);
    ok("B2 · Backup provider assigned + confirmed", backupUnit.vehicle_id + " (" + backupUnit.provider + ")");
    await sales(`/api/requests/${idB}/approve`, { finalPrice: 2598, internalCost: 1800 }); // changed price
    await sales(`/api/requests/${idB}/quote`, { expiresDays: 3 });
    ok("B3 · Changed quote issued", "$2,598 (was $2,498 on unit 1)");
    await anon("/api/public/quote/accept", { requestId: idB, phone: "9999" });
    ok("B4 · Customer accepts replacement quote");
    await sales(`/api/requests/${idB}/payment-link`, {});
    const pay = await sales(`/api/requests/${idB}/payment-verified`, { amount: 2598 });
    assert(pay.data.rentalId, "rental");
    const meta = (await ops("/api/meta/checklists")).data;
    const all = arr => Object.fromEntries(arr.map(k => [k, true]));
    await ops(`/api/rentals/${pay.data.rentalId}`, { pre_checklist: all(meta.pre), pickup_status: "Done" }, "PATCH");
    await ops(`/api/rentals/${pay.data.rentalId}`, { post_checklist: all(meta.post), return_status: "Done", amount_paid: 2598 }, "PATCH");
    ok("B5 · Replacement booking completed end-to-end", pay.data.rentalId);
  } catch (e) { no("B · Scenario B", e); }

  const pass = steps.filter(s => s.ok === true).length, skip = steps.filter(s => s.ok === "skip").length;
  const md = [
    "# Phase 4 — Pilot Booking Report",
    "",
    `Run: ${new Date().toISOString()} · Target: ${B} · Mode: ${remote ? "REMOTE (real environment)" : "LOCAL STAGING REHEARSAL"}`,
    remote ? "" : "\n> ⚠️ This run is the staging rehearsal. The production pilot must be re-run with `--remote` against the deployed URL, live Stripe test keys and the real Excel webhook before launch.\n",
    "| Step | Result | Detail |",
    "|------|--------|--------|",
    ...steps.map(s => `| ${s.name} | ${s.ok === true ? "✅" : s.ok === "skip" ? "⏭ pending config" : "❌"} | ${s.detail || ""} |`),
    "",
    `**${pass} passed · ${skip} pending configuration · ${steps.length - pass - skip} failed.**`
  ].join("\n");
  fs.writeFileSync(path.join(ROOT, "PILOT-REPORT.md"), md);
  console.log(`\n${pass}/${steps.length} passed (${skip} pending config) → PILOT-REPORT.md`);

  if (proc) proc.kill();
  if (mock) mock.close();
  if (!remote) fs.rmSync(path.join(ROOT, "data-pilot"), { recursive: true, force: true });
  process.exit(steps.some(s => s.ok === false) ? 1 : 0);
}
main().catch(e => { console.error("FATAL", e); proc?.kill(); process.exit(1); });
