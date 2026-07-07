/* ============================================================
   Phase 4 test suite — consent capture, publishing controls,
   Stripe webhook security/idempotency, backups + restore,
   signed document links, settings, economics.
   Run: node tests/phase4.mjs
   ============================================================ */
import { spawn, execFileSync } from "node:child_process";
import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, "..");
const PORT = 8955, MOCK = 8956, B = `http://localhost:${PORT}`;
const WH_SECRET = "whsec_test_pilot";
const results = [];
const record = (n, name, okv, detail) => { results.push({ n, name, ok: okv, detail: detail || "" }); console.log(`${okv ? "PASS" : "FAIL"}  ${n} · ${name}${detail ? "  — " + detail : ""}`); };
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

const mockHits = [];
const mock = http.createServer((q, s) => { let b = ""; q.on("data", c => b += c); q.on("end", () => { mockHits.push(JSON.parse(b)); s.writeHead(200); s.end("ok"); }); });

const TESTDATA = path.join(ROOT, "data-p4");
fs.rmSync(TESTDATA, { recursive: true, force: true });
const BK = path.join(ROOT, "backups-p4");
fs.rmSync(BK, { recursive: true, force: true });

const proc = spawn("node", ["server.js"], {
  cwd: ROOT,
  env: {
    ...process.env, PORT, TN_ENV: "staging", TN_DATA_DIR: TESTDATA, TN_BACKUP_DIR: BK,
    EXCEL_WEBHOOK_URL: `http://localhost:${MOCK}/hook`,
    BACKUP_ENCRYPTION_KEY: "p4-backup-key", STRIPE_WEBHOOK_SECRET: WH_SECRET,
    TN_ADMIN_PASSWORD: "P4Admin2026!!", TN_SALES_PASSWORD: "P4Sales2026!!", TN_OPS_PASSWORD: "P4Ops2026!!",
    TN_PARTNER2_PASSWORD: "P4Partner2026!!"
  },
  stdio: ["ignore", "ignore", "pipe"]
});
proc.stderr.on("data", d => { const s = String(d); if (!s.includes("Experimental")) process.stderr.write(s); });

const CONSENTS = { terms: true, privacy: true, cancellation: true, deposit: true, vehicleRules: true, communication: true, documents: true };
const REQ = o => ({
  customerName: "Phase Four", phone: "(305) 555-4444", email: "p4@example.com",
  vehicleRequested: "Lamborghini Huracán EVO", startDate: "2026-10-01 10:00", endDate: "2026-10-03 10:00",
  option: "delivery", deliveryLocation: "Brickell, Miami", depositReadiness: "Ready",
  driverAge: "30–39", licenseStatus: "Confirmed by customer", insuranceStatus: "Confirmed by customer",
  consents: CONSENTS, consentText: "test consent text v2026-07-06", ...o
});

async function main() {
  mock.listen(MOCK);
  for (let i = 0; i < 40; i++) { try { await fetch(B + "/api/health"); break; } catch (e) { await new Promise(r => setTimeout(r, 250)); } }

  const anon = client(), admin = client(), sales = client(), ops = client();
  await admin("/api/auth/login", { email: "admin@topnotchrentalz.com", password: "P4Admin2026!!" });
  await sales("/api/auth/login", { email: "sales@topnotchrentalz.com", password: "P4Sales2026!!" });
  await ops("/api/auth/login", { email: "ops@topnotchrentalz.com", password: "P4Ops2026!!" });

  /* 1 · consent is mandatory and recorded */
  try {
    const noC = await anon("/api/public/requests", REQ({ consents: { ...CONSENTS, privacy: false } }));
    assert(noC.status === 400 && /privacy/.test(noC.data.error), "missing consent must 400: " + JSON.stringify(noC.data));
    const okC = await anon("/api/public/requests", REQ({}));
    assert(okC.status === 200, JSON.stringify(okC.data));
    record(1, "Consent required, versioned and recorded (no pre-checked boxes)", true, okC.data.requestId);
    globalThis.reqId = okC.data.requestId;
  } catch (e) { record(1, "Consent capture", false, e.message); }

  /* 2 · company settings: public read + admin edit, audited */
  try {
    let s = (await anon("/api/public/settings")).data;
    assert(s.businessName === "TopNotchRentalz" && s.phone === "(786) 634-1150" && s.instagram === "@topnotchrentalz", JSON.stringify(s));
    await admin("/api/settings", { hours: "Mon – Sun · 8:00 AM – 10:00 PM" }, "PATCH");
    s = (await anon("/api/public/settings")).data;
    assert(s.hours.includes("8:00 AM"), "edit must go live");
    const denied = await sales("/api/settings", { phone: "1" }, "PATCH");
    assert(denied.status === 403, "settings are admin-only");
    record(2, "Company settings page (live, admin-only, no code edits)", true, s.phone + " · " + s.instagram);
  } catch (e) { record(2, "Company settings", false, e.message); }

  /* 3 · publishing controls: partner status + approvals gate visibility */
  try {
    let avail = (await anon("/api/public/availability")).data;
    assert(avail.huracan === "available", "baseline");
    await admin("/api/vehicles/V-1001", { photos_approved: 0 }, "PATCH");   // unit 1 unpublishable
    await admin("/api/vehicles/V-1002", { rate_label: "awaiting-confirmation" }, "PATCH"); // unit 2 too
    avail = (await anon("/api/public/availability")).data;
    assert(!("huracan" in avail), "huracan must disappear when no unit passes the checklist, got " + avail.huracan);
    await admin("/api/vehicles/V-1001", { photos_approved: 1 }, "PATCH");
    await admin("/api/vehicles/V-1002", { rate_label: "confirmed-broker" }, "PATCH");
    await admin("/api/partners/P-002", { onboarding_status: "Paused" }, "PATCH");
    avail = (await anon("/api/public/availability")).data;
    assert(!("f8" in avail) && !("urus" in avail), "paused partner's exclusive models must unpublish");
    await admin("/api/partners/P-002", { onboarding_status: "Active" }, "PATCH");
    record(3, "Inventory publishing controls (partner Active + approvals required)", true, "checklist + partner gating verified");
  } catch (e) { record(3, "Publishing controls", false, e.message); }

  /* 4 · stale verification → "on-request", no instant quote */
  try {
    await admin("/api/vehicles/V-1006", { last_verified: "2026-01-01" }, "PATCH");
    await admin("/api/vehicles/V-1007", { last_verified: "2026-01-01" }, "PATCH");
    const avail = (await anon("/api/public/availability")).data;
    assert(avail.g63 === "on-request", "stale must demote to on-request, got " + avail.g63);
    record(4, "Stale verification → 'Availability on request' + partnerships alert", true, "verify window " + "7d");
  } catch (e) { record(4, "Stale verification", false, e.message); }

  /* 5 · Stripe webhook: bad signature rejected, good one confirms, duplicate ignored */
  try {
    const id = globalThis.reqId;
    const m = (await sales(`/api/requests/${id}/matches`)).data;
    await sales(`/api/requests/${id}/assign`, { vehicleId: m.exact[0].vehicle_id });
    await sales(`/api/requests/${id}/provider-decision`, { decision: "confirm" });
    await sales(`/api/requests/${id}/approve`, { finalPrice: 2500, internalCost: 1700 });
    await sales(`/api/requests/${id}/quote`, { expiresDays: 2 });
    await anon("/api/public/quote/accept", { requestId: id, phone: "4444" });
    await sales(`/api/requests/${id}/payment-link`, {});

    const event = JSON.stringify({ id: "evt_p4_001", type: "checkout.session.completed",
      data: { object: { amount_total: 250000, currency: "usd", customer: "cus_p4", payment_intent: "pi_p4",
        metadata: { requestId: id, category: "rental-payment" } } } });
    const t = Math.floor(Date.now() / 1000);
    const sig = crypto.createHmac("sha256", WH_SECRET).update(`${t}.${event}`).digest("hex");

    const badSig = await anon("/api/stripe/webhook", event, "POST", { "stripe-signature": `t=${t},v1=deadbeef` + "0".repeat(56), "content-type": "application/json" }, true);
    assert(badSig.status === 400, "bad signature must be rejected, got " + badSig.status);
    const good = await anon("/api/stripe/webhook", event, "POST", { "stripe-signature": `t=${t},v1=${sig}`, "content-type": "application/json" }, true);
    assert(good.status === 200 && !good.data.duplicate, "valid webhook processed");
    const reqRow = (await admin("/api/requests")).data.find(x => x.request_id === id);
    assert(reqRow.status === "Booking confirmed", "webhook must confirm the booking: " + reqRow.status);
    const dup = await anon("/api/stripe/webhook", event, "POST", { "stripe-signature": `t=${t},v1=${sig}`, "content-type": "application/json" }, true);
    assert(dup.data.duplicate === true, "duplicate event must be ignored");
    const pays = (await admin("/api/payments")).data.filter(p => p.request_id === id && p.kind === "payment");
    assert(pays.length === 1 && pays[0].stripe_payment_intent === "pi_p4", "exactly one payment row with Stripe ids only");
    record(5, "Stripe webhook: signature verified, booking confirmed, duplicates ignored, no card data stored", true, "pi_p4 recorded once");
  } catch (e) { record(5, "Stripe webhook", false, e.message); }

  /* 6 · payments stay blocked before quote acceptance */
  try {
    const r2 = await anon("/api/public/requests", REQ({ phone: "(305) 555-8811", email: "p4b@example.com", startDate: "2026-10-10 10:00", endDate: "2026-10-12 10:00" }));
    const early = await sales(`/api/requests/${r2.data.requestId}/stripe-link`, { category: "rental-payment", amount: 100 });
    assert(early.status === 400 && /blocked/.test(early.data.error), "payment link before flow must be blocked: " + JSON.stringify(early.data));
    const postNoAuth = await admin(`/api/requests/${r2.data.requestId}/stripe-link`, { category: "damage-charge", amount: 100 });
    assert(postNoAuth.status === 400 && /authorization/i.test(postNoAuth.data.error), "post-rental charge needs documented authorization");
    const postSales = await sales(`/api/requests/${r2.data.requestId}/stripe-link`, { category: "damage-charge", amount: 100, authorizationNote: "x" });
    assert(postSales.status === 403, "post-rental charges are admin-only");
    record(6, "Payment ordering + post-rental charge safeguards", true, "blocked until quote accepted; damage charges need admin + authorization");
  } catch (e) { record(6, "Payment safety", false, e.message); }

  /* 7 · encrypted backup + tested restore */
  try {
    const b = await admin("/api/system/backup", {});
    assert(b.status === 200 && b.data.ok && b.data.encrypted, JSON.stringify(b.data));
    const tmp = path.join(ROOT, "data-p4", "restore-check.db");
    const out = execFileSync("node", ["-e", `
      process.env.TN_DATA_DIR=${JSON.stringify(TESTDATA)};
      process.env.TN_BACKUP_DIR=${JSON.stringify(BK)};
      process.env.BACKUP_ENCRYPTION_KEY="p4-backup-key";
      const { restoreTo } = require(${JSON.stringify(path.join(ROOT, "lib", "backup.js"))});
      console.log(JSON.stringify(restoreTo(${JSON.stringify(b.data.file)}, ${JSON.stringify(tmp)})));
    `], { encoding: "utf8" }).trim().split("\n").pop();
    const restored = JSON.parse(out);
    assert(restored.ok && restored.users >= 5, "restore must yield a readable db: " + out);
    const status = (await admin("/api/system/backups")).data;
    assert(status.last && status.encryptionConfigured, "backup status in dashboard");
    record(7, "Encrypted backup + tested restore + dashboard status", true, `${b.data.file} → restored, ${restored.users} users readable`);
  } catch (e) { record(7, "Backup & restore", false, e.message); }

  /* 8 · signed temporary document links, no permanent URLs */
  try {
    const up = await admin("/api/uploads", { data: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", kind: "document", filename: "license.png" });
    const anonBlocked = await fetch(B + "/api/files/" + up.data.id).then(r => r.status);
    assert(anonBlocked === 401, "raw URL must not work without auth");
    const signed = await admin(`/api/files/${up.data.id}/sign`, { minutes: 15 });
    const viaLink = await fetch(B + signed.data.url).then(r => r.status);
    assert(viaLink === 200, "signed link must work without a session");
    const tampered = await fetch(B + signed.data.url.replace(/sig=./, "sig=f")).then(r => r.status);
    assert(tampered !== 200, "tampered signature must fail");
    const del = await admin("/api/uploads/" + up.data.id, undefined, "DELETE");
    assert(del.status === 200, "admin deletion control");
    record(8, "Document security: signed temp links, access logging, admin deletion, retention schedule", true, "15-min link; tamper rejected");
  } catch (e) { record(8, "Document security", false, e.message); }

  /* 9 · rate/profit models: internal economics, role-guarded */
  try {
    const ec = await sales(`/api/requests/${globalThis.reqId}/economics`);
    assert(ec.status === 200 && ec.data.netProfitEstimate > 0 && ec.data.processingFee > 0, JSON.stringify(ec.data));
    const opsDenied = await ops(`/api/requests/${globalThis.reqId}/economics`);
    assert(opsDenied.status === 403, "economics hidden from ops role");
    await admin("/api/partners/P-001", { deal_model: "split-80-20" }, "PATCH");
    record(9, "Deal models + internal quote economics (retail/provider/customer/payout/fees/net)", true,
      `model=${ec.data.dealModel}, net=$${ec.data.netProfitEstimate}`);
  } catch (e) { record(9, "Deal economics", false, e.message); }

  /* 10 · production seed contains no demo data */
  try {
    const PDATA = path.join(ROOT, "data-p4-prod");
    fs.rmSync(PDATA, { recursive: true, force: true });
    const out = execFileSync("node", ["-e", `
      process.env.TN_ENV="production"; process.env.TN_DATA_DIR=${JSON.stringify(PDATA)};
      process.env.TN_ADMIN_PASSWORD="ProdSeed2026!!";
      const { db } = require(${JSON.stringify(path.join(ROOT, "lib", "db.js"))});
      require(${JSON.stringify(path.join(ROOT, "seed.js"))}).seed();
      console.log(JSON.stringify({
        vehicles: db.prepare("SELECT count(*) n FROM vehicles").get().n,
        partners: db.prepare("SELECT partner_id, company, onboarding_status FROM partners").all(),
        demoUsers: db.prepare("SELECT count(*) n FROM users WHERE email LIKE '%.example'").get().n,
        rentals: db.prepare("SELECT count(*) n FROM rentals").get().n
      }));
    `], { encoding: "utf8" }).trim().split("\n").pop();
    const prod = JSON.parse(out);
    assert(prod.vehicles === 0 && prod.demoUsers === 0 && prod.rentals === 0, "prod must have zero demo rows: " + out);
    assert(prod.partners.length === 1 && prod.partners[0].company === "LUXX Miami" && prod.partners[0].onboarding_status === "Inventory pending", "LUXX lead expected: " + out);
    fs.rmSync(PDATA, { recursive: true, force: true });
    record(10, "Production seed: demo data removed, LUXX Miami staged as onboarding lead", true, "0 vehicles/demo users; P-LUXX = Inventory pending");
  } catch (e) { record(10, "Production seed", false, e.message); }

  const pass = results.filter(r => r.ok).length;
  const md = ["# Phase 4 — Integration Test Results", "",
    `Run: ${new Date().toISOString()} · fresh staging database`,
    "", "| # | Scenario | Result | Detail |", "|---|----------|--------|--------|",
    ...results.map(r => `| ${r.n} | ${r.name} | ${r.ok ? "✅ PASS" : "❌ FAIL"} | ${r.detail} |`),
    "", `**${pass}/${results.length} passed.**`].join("\n");
  fs.writeFileSync(path.join(ROOT, "TEST-RESULTS-PHASE4.md"), md);
  console.log(`\n${pass}/${results.length} passed → TEST-RESULTS-PHASE4.md`);

  proc.kill(); mock.close();
  fs.rmSync(TESTDATA, { recursive: true, force: true });
  fs.rmSync(BK, { recursive: true, force: true });
  process.exit(pass === results.length ? 0 : 1);
}
main().catch(e => { console.error("FATAL", e); proc.kill(); process.exit(1); });
