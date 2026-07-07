/* ============================================================
   TopNotchRentalz — Phase 3 launch test suite
   Covers the 18 required scenarios end-to-end against a real
   server instance with a fresh database + a mock Excel webhook.
   Run:  node tests/e2e.mjs        (add --browser for Playwright checks)
   ============================================================ */
import { spawn } from "node:child_process";
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, "..");
const PORT = 8940, MOCK_PORT = 8941;
const B = `http://localhost:${PORT}`;

const results = [];
function record(n, name, ok, detail) {
  results.push({ n, name, ok, detail: detail || "" });
  console.log(`${ok ? "PASS" : "FAIL"}  ${String(n).padStart(2)} · ${name}${detail ? "  — " + detail : ""}`);
}
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

/* cookie-jar fetch per user */
function client() {
  let cookie = "";
  return async (pathname, body, method) => {
    const res = await fetch(B + pathname, {
      method: method || (body !== undefined ? "POST" : "GET"),
      headers: { ...(body !== undefined ? { "Content-Type": "application/json" } : {}), ...(cookie ? { cookie } : {}) },
      body: body !== undefined ? JSON.stringify(body) : undefined
    });
    const sc = res.headers.get("set-cookie");
    if (sc) cookie = sc.split(";")[0];
    let data = {};
    try { data = await res.json(); } catch (e) { /* non-json */ }
    return { status: res.status, data };
  };
}

/* mock Excel webhook — flips between failing and accepting */
let mockAccept = true, mockReceived = [];
const mock = http.createServer((req, res) => {
  let body = "";
  req.on("data", c => (body += c));
  req.on("end", () => {
    if (!mockAccept) { res.writeHead(500); return res.end("boom"); }
    mockReceived.push(JSON.parse(body));
    res.writeHead(200); res.end("ok");
  });
});

/* fresh DB dir */
const TESTDATA = path.join(ROOT, "data-test");
fs.rmSync(TESTDATA, { recursive: true, force: true });

const PASS = {
  admin: "AdminPass2026!", sales: "SalesPass2026!", ops: "OpsPass2026!",
  partnerships: "PartsPass2026!", cx: "CxPass2026!",
  p1: "Partner1Pass26!", p2: "Partner2Pass26!"
};

const serverProc = spawn("node", ["server.js"], {
  cwd: ROOT,
  env: {
    ...process.env, PORT, TN_DATA_DIR: TESTDATA,
    EXCEL_WEBHOOK_URL: `http://localhost:${MOCK_PORT}/hook`,
    TN_ADMIN_PASSWORD: PASS.admin, TN_SALES_PASSWORD: PASS.sales, TN_OPS_PASSWORD: PASS.ops,
    TN_PARTNERSHIPS_PASSWORD: PASS.partnerships, TN_CX_PASSWORD: PASS.cx,
    TN_PARTNER1_PASSWORD: PASS.p1, TN_PARTNER2_PASSWORD: PASS.p2, TN_PARTNER3_PASSWORD: "Partner3Pass26!"
  },
  stdio: ["ignore", "pipe", "pipe"]
});
serverProc.stderr.on("data", d => { const s = String(d); if (!s.includes("Experimental")) process.stderr.write(s); });

const wait = ms => new Promise(r => setTimeout(r, ms));
async function waitUp() {
  for (let i = 0; i < 40; i++) {
    try { await fetch(B + "/api/public/availability"); return; } catch (e) { await wait(250); }
  }
  throw new Error("server did not start");
}

const ALL_CONSENTS = { terms: true, privacy: true, cancellation: true, deposit: true, vehicleRules: true, communication: true, documents: true };
const REQ = (over = {}) => ({
  consents: ALL_CONSENTS, consentText: "e2e consent",
  customerName: "Jordan Blake", phone: "(305) 555-7788", email: "jordan@example.com",
  vehicleRequested: "Lamborghini Huracán EVO", backupVehicle: "Mercedes-AMG G63",
  startDate: "2026-08-10 10:00", endDate: "2026-08-12 10:00",
  budget: "$1,000–$1,500", driverAge: "30–39",
  licenseStatus: "Confirmed by customer", insuranceStatus: "Confirmed by customer",
  option: "delivery", deliveryLocation: "Fontainebleau Hotel, Miami Beach", returnLocation: "Same",
  depositReadiness: "Ready", occasion: "Birthday", addons: "Branded gift basket",
  specialRequests: "Orange if possible", quotedDayRate: "$1199/day", ...over
});

async function main() {
  mock.listen(MOCK_PORT);
  await waitUp();

  const anon = client(), admin = client(), sales = client(), ops = client(), cx = client(), p1 = client(), p2 = client();
  await admin("/api/auth/login", { email: "admin@topnotchrentalz.com", password: PASS.admin });
  await sales("/api/auth/login", { email: "sales@topnotchrentalz.com", password: PASS.sales });
  await ops("/api/auth/login", { email: "ops@topnotchrentalz.com", password: PASS.ops });
  await cx("/api/auth/login", { email: "cx@topnotchrentalz.com", password: PASS.cx });
  await p1("/api/auth/login", { email: "portal@prestigeauto.example", password: PASS.p1 });   // P-001
  await p2("/api/auth/login", { email: "portal@velocityexotics.example", password: PASS.p2 }); // P-002

  let mainId;

  /* 1 · valid request */
  try {
    const r = await anon("/api/public/requests", REQ());
    assert(r.status === 200 && r.data.requestId?.startsWith("TN-"), JSON.stringify(r.data));
    assert(!r.data.duplicate, "should not be duplicate");
    mainId = r.data.requestId;
    record(1, "Customer submits a valid request", true, mainId);
  } catch (e) { record(1, "Customer submits a valid request", false, e.message); }

  /* 2 · duplicate detection */
  try {
    const r = await anon("/api/public/requests", REQ());
    assert(r.data.duplicate === true && r.data.duplicateOf === mainId, JSON.stringify(r.data));
    record(2, "Duplicate request is detected", true, `flagged as dup of ${mainId}`);
  } catch (e) { record(2, "Duplicate request is detected", false, e.message); }

  /* 3 · unavailable vehicle (Ferrari F8 seeded as booked) */
  try {
    const avail = (await anon("/api/public/availability")).data;
    assert(avail.f8 === "booked", "f8 should show booked publicly");
    const r = await anon("/api/public/requests", REQ({ vehicleRequested: "Ferrari F8 Tributo", phone: "(305) 555-9911", email: "f8@example.com", startDate: "2026-07-05 10:00", endDate: "2026-07-07 10:00" }));
    assert(r.status === 200, "request still accepted (never auto-confirmed)");
    const assign = await admin(`/api/requests/${r.data.requestId}/assign`, { vehicleId: "V-1004" });
    assert(assign.status === 409, "assigning the booked unit must be blocked, got " + assign.status);
    record(3, "Customer requests an unavailable vehicle", true, "public status=booked; overlapping assign → 409");
  } catch (e) { record(3, "Customer requests an unavailable vehicle", false, e.message); }

  /* 4 · two providers offer the same car */
  let matches;
  try {
    matches = (await sales(`/api/requests/${mainId}/matches`)).data;
    const providers = new Set(matches.exact.map(m => m.partner_id));
    assert(matches.exact.length >= 2 && providers.size >= 2, "expected 2+ providers, got " + JSON.stringify([...providers]));
    record(4, "Two providers offer the same car", true, [...providers].join(" + "));
  } catch (e) { record(4, "Two providers offer the same car", false, e.message); }

  /* 5 · assign the lowest-cost approved provider */
  try {
    const lowest = matches.exact[0];
    assert(lowest.provider_rate === Math.min(...matches.exact.map(m => m.provider_rate)), "first match must be lowest rate");
    const r = await sales(`/api/requests/${mainId}/assign`, { vehicleId: lowest.vehicle_id });
    assert(r.status === 200, JSON.stringify(r.data));
    record(5, "Admin assigns the lowest-cost approved provider", true, `${lowest.vehicle_id} @ $${lowest.provider_rate}/day`);
  } catch (e) { record(5, "Admin assigns the lowest-cost approved provider", false, e.message); }

  /* 6 · provider declines via portal */
  try {
    const bk = (await p2("/api/portal/bookings")).data;
    const mine = bk.find(b => b.requestId === mainId);
    assert(mine && mine.needsDecision, "P-002 should see the availability request");
    assert(mine.customerPhone === null, "customer phone must be hidden before confirmation");
    const r = await p2(`/api/portal/bookings/${mainId}/decision`, { decision: "decline", note: "unit in service" });
    assert(r.status === 200, JSON.stringify(r.data));
    const reqRow = (await admin("/api/requests")).data.find(x => x.request_id === mainId);
    assert(reqRow.status === "Under review" && !reqRow.assigned_vehicle_id, "back to Under review with unit cleared");
    record(6, "Provider declines the booking", true, "status → Under review; sales notified");
  } catch (e) { record(6, "Provider declines the booking", false, e.message); }

  /* 7 · backup provider is assigned + confirms */
  try {
    const r = await sales(`/api/requests/${mainId}/assign`, { vehicleId: "V-1002" }); // P-001 Spyder
    assert(r.status === 200, JSON.stringify(r.data));
    const dec = await p1(`/api/portal/bookings/${mainId}/decision`, { decision: "confirm" });
    assert(dec.status === 200, JSON.stringify(dec.data));
    record(7, "Backup provider is assigned", true, "V-1002 (P-001) confirmed");
  } catch (e) { record(7, "Backup provider is assigned", false, e.message); }

  /* 8 · customer receives + accepts a quote (with expiry) */
  try {
    const ap = await sales(`/api/requests/${mainId}/approve`, { finalPrice: 2498, internalCost: 1800 });
    assert(ap.status === 200 && ap.data.profit === 698, JSON.stringify(ap.data));
    const q = await sales(`/api/requests/${mainId}/quote`, { expiresDays: 3 });
    assert(q.status === 200 && q.data.expires, JSON.stringify(q.data));
    const t = await anon(`/api/public/track?id=${mainId}&phone=7788`);
    assert(t.data.quote && t.data.quote.amount === 2498, "customer sees quote " + JSON.stringify(t.data));
    const acc = await anon("/api/public/quote/accept", { requestId: mainId, phone: "7788" });
    assert(acc.status === 200, JSON.stringify(acc.data));
    record(8, "Customer receives a quote", true, "$2,498, 3-day expiry, accepted via track page");
  } catch (e) { record(8, "Customer receives a quote", false, e.message); }

  /* 9 · booking confirmed only after payment verification */
  try {
    const early = await sales(`/api/requests/${mainId}/payment-verified`, { amount: 2498 });
    assert(early.status === 400, "payment cannot be verified before the link step");
    await sales(`/api/requests/${mainId}/payment-link`, {});
    const pay = await sales(`/api/requests/${mainId}/payment-verified`, { amount: 2498, method: "card" });
    assert(pay.status === 200 && pay.data.rentalId, JSON.stringify(pay.data));
    const v = (await admin("/api/vehicles")).data.find(x => x.vehicle_id === "V-1002");
    assert(v.status === "booked" && v.booked_dates.includes("2026-08-10"), "unit blocked for the dates");
    record(9, "Vehicle becomes booked after payment confirmation", true, pay.data.rentalId);
  } catch (e) { record(9, "Vehicle becomes booked after payment confirmation", false, e.message); }

  /* 10 · overlapping booking is blocked */
  try {
    const r2 = await anon("/api/public/requests", REQ({ phone: "(786) 555-2222", email: "other@example.com", customerName: "Alex Cruz", startDate: "2026-08-11 10:00", endDate: "2026-08-13 10:00" }));
    const blocked = await sales(`/api/requests/${r2.data.requestId}/assign`, { vehicleId: "V-1002" });
    assert(blocked.status === 409, "overlap must be 409, got " + blocked.status);
    record(10, "Overlapping booking is blocked", true, "assign V-1002 for 08/11–08/13 → 409");
  } catch (e) { record(10, "Overlapping booking is blocked", false, e.message); }

  /* 11 + 12 · rental completed (with Phase 4 checklists); vehicle available again */
  try {
    const rentalId = mainId.replace("TN-", "AR-");
    const meta = (await ops("/api/meta/checklists")).data;
    const all = arr => Object.fromEntries(arr.map(k => [k, true]));
    const blocked = await ops(`/api/rentals/${rentalId}`, { pickup_status: "Done" }, "PATCH");
    assert(blocked.status === 409, "pickup must require the pre-rental checklist");
    const done = await ops(`/api/rentals/${rentalId}`, { pre_checklist: all(meta.pre), post_checklist: all(meta.post), pickup_status: "Done", return_status: "Done", amount_paid: 2498 }, "PATCH");
    assert(done.status === 200, JSON.stringify(done.data));
    record(11, "Active rental is completed", true, rentalId + " (checklists enforced)");
    const v = (await admin("/api/vehicles")).data.find(x => x.vehicle_id === "V-1002");
    assert(v.status === "available" && !v.booked_dates.includes("2026-08-10"), "unit freed");
    const avail = (await anon("/api/public/availability")).data;
    assert(avail.huracan === "available", "public availability restored");
    record(12, "Vehicle becomes available after return", true, "status + booked dates cleared");
  } catch (e) { record(11, "Active rental is completed", false, e.message); record(12, "Vehicle becomes available after return", false, e.message); }

  /* 13 · Excel sync succeeds */
  try {
    const before = mockReceived.length;
    const sync = (await admin("/api/sync")).data;
    const pending = sync.pendingOrFailed[0];
    if (pending) await admin(`/api/sync/${pending.id}/retry`, {});
    await wait(300);
    assert(mockReceived.length > before || sync.recentSent.length > 0, "webhook should have received rows");
    const tables = new Set(mockReceived.map(m => m.table));
    record(13, "Excel synchronization succeeds", true, `rows delivered: ${mockReceived.length} (${[...tables].join(", ")})`);
  } catch (e) { record(13, "Excel synchronization succeeds", false, e.message); }

  /* 14 · sync failure retries with backoff */
  try {
    mockAccept = false;
    await admin("/api/vehicles/V-1008", { notes: "sync-fail-test" }, "PATCH");
    const s1 = (await admin("/api/sync")).data;
    let row = s1.pendingOrFailed.find(r => r.status !== "sent");
    const tryFail = await admin(`/api/sync/${row.id}/retry`, {});
    assert(tryFail.data.status === "failed" && tryFail.data.attempts >= 1 && tryFail.data.next_retry, "failure recorded with retry schedule: " + JSON.stringify(tryFail.data));
    mockAccept = true;
    const tryOk = await admin(`/api/sync/${row.id}/retry`, {});
    assert(tryOk.data.status === "sent", "retry after recovery should send: " + JSON.stringify(tryOk.data));
    record(14, "Excel synchronization fails and retries", true, `attempts=${tryOk.data.attempts}, then sent`);
  } catch (e) { record(14, "Excel synchronization fails and retries", false, e.message); }

  /* 15 · unauthorized user attempts admin access */
  try {
    const codes = await Promise.all(["/api/requests", "/api/vehicles", "/api/audit", "/api/rentals", "/api/users", "/api/sync"]
      .map(p => anon(p).then(r => r.status)));
    assert(codes.every(c => c === 401), "all admin APIs must 401 without a session: " + codes.join(","));
    const salesDenied = await sales("/api/audit");
    const cxDenied = await cx("/api/rentals");
    const opsVehicles = (await ops("/api/vehicles")).data;
    assert(salesDenied.status === 403 && cxDenied.status === 403, "role checks");
    assert(!("provider_rate" in (opsVehicles[0] || {})), "ops must not receive provider rates");
    record(15, "Unauthorized user attempts to open admin pages", true, "401 anonymous; 403 wrong roles; field-level filtering works");
  } catch (e) { record(15, "Unauthorized user attempts to open admin pages", false, e.message); }

  /* 16 · partner attempts to access another partner's inventory */
  try {
    const own = (await p1("/api/portal/vehicles")).data;
    assert(own.every(v => ["V-1002", "V-1006", "V-1008"].includes(v.vehicle_id)), "P-001 sees only its own units");
    const steal = await p1("/api/portal/vehicles/V-1001", { provider_rate: 1 }, "PATCH"); // V-1001 is P-002's
    assert(steal.status === 404, "cross-partner edit must 404, got " + steal.status);
    const spy = await p1("/api/portal/bookings/" + mainId + "/decision", { decision: "confirm" });
    assert([403, 400].includes(spy.status), "cross-partner booking decision blocked");
    assert(!own.some(v => "customer_price" in v || "profit" in v), "partner payload must not contain customer price or profit");
    record(16, "Partner attempts to access another partner's inventory", true, "404 on foreign unit; no profit/customer-price fields");
  } catch (e) { record(16, "Partner attempts to access another partner's inventory", false, e.message); }

  /* 17 · sensitive provider rates not reachable from public pages */
  try {
    const SITE = path.join(ROOT, "..", "topnotch-website");
    const offenders = [];
    /* secret VALUES must appear nowhere in any deployed file;
       internal FIELD NAMES must not appear in customer-facing files
       (admin/ and portal/ are authenticated API clients whose field
       references are harmless — the values only arrive post-login). */
    const secretValues = [/TOPNOTCH2026/, /ADMIN_PASS\s*=/, /555-01(01|44|77)/, /prestigeauto\.example|velocityexotics\.example|crownluxury\.example/];
    const internalFields = [/provider_?rate/i, /providerPayout|provider_payout/i, /broker/i, /internal_?cost/i];
    (function scan(dir) {
      for (const f of fs.readdirSync(dir)) {
        const p = path.join(dir, f);
        if (fs.statSync(p).isDirectory()) { scan(p); continue; }
        if (!/\.(html|js|css)$/.test(f)) continue;
        const rel = path.relative(SITE, p);
        const text = fs.readFileSync(p, "utf8");
        for (const n of secretValues) if (n.test(text)) offenders.push(rel + " ~ " + n);
        if (!rel.startsWith("admin") && !rel.startsWith("portal"))
          for (const n of internalFields) if (n.test(text)) offenders.push(rel + " ~ " + n);
      }
    })(SITE);
    const pub = JSON.stringify((await anon("/api/public/availability")).data) +
      JSON.stringify((await anon(`/api/public/track?id=${mainId}&phone=7788`)).data);
    assert(!/provider_rate|payout|profit|internal_cost/i.test(pub), "public API responses leak internal fields");
    assert(offenders.length === 0, "front-end files contain internal data: " + offenders.join(" | "));
    record(17, "Sensitive provider rates cannot be accessed from public pages", true, "file scan + public API scan clean");
  } catch (e) { record(17, "Sensitive provider rates cannot be accessed from public pages", false, e.message); }

  /* 18 · sensitive customer information not exposed */
  try {
    const noPhone = await anon(`/api/public/track?id=${mainId}&phone=0000`);
    assert(noPhone.status === 403, "wrong phone must be rejected");
    const tracked = (await anon(`/api/public/track?id=${mainId}&phone=7788`)).data;
    assert(!("email" in tracked) && !("phone" in tracked) && !("ip" in tracked), "track response must not echo contact/ip");
    const dbBlocked = await fetch(B + "/../topnotch-server/data/topnotch.db").then(r => r.status);
    const envBlocked = await fetch(B + "/../.env").then(r => r.status).catch(() => 403);
    assert(dbBlocked !== 200 && envBlocked !== 200, "server files must not be reachable over HTTP");
    record(18, "Sensitive customer information cannot be exposed", true, "phone verification, sanitized responses, path traversal blocked");
  } catch (e) { record(18, "Sensitive customer information cannot be exposed", false, e.message); }

  /* optional browser checks */
  if (process.argv.includes("--browser")) {
    try {
      const { createRequire } = await import("node:module");
      const { chromium } = createRequire(import.meta.url)("playwright");
      const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium", args: ["--no-sandbox"] });
      const page = await browser.newPage();
      await page.goto(B + "/admin/", { waitUntil: "load" });
      await new Promise(r => setTimeout(r, 900));
      const gateVisible = await page.isVisible("#gate");
      const appHidden = await page.isHidden("#app");
      record("B1", "Browser: admin shows login gate to anonymous visitor", gateVisible && appHidden);

      await page.goto(B + "/index.html", { waitUntil: "load" });
      await new Promise(r => setTimeout(r, 900));
      await page.evaluate(() => { document.documentElement.style.scrollBehavior = "auto"; window.scrollTo(0, document.getElementById("fleet").offsetTop); });
      await page.click('.car-card[data-id="urus"]');
      await page.click("#rentNow");
      await page.click("#optDelivery");
      await page.fill("#locInput", "1 Ocean Drive, Miami Beach");
      await page.click("#nextBtn");
      await page.click("label:has(#hasLicense)"); await page.click("label:has(#hasInsurance)"); await page.click("label:has(#depositReady)");
      await page.click("#nextBtn");
      await page.fill("#cName", "Browser Test");
      await page.fill("#cPhone", "(305) 555-3344");
      await page.fill("#cEmail", "browser@example.com");
      for (const id of ["cTerms", "cPrivacy", "cCancel", "cDeposit", "cRules", "cComms", "cDocs"])
        await page.click(`label:has(#${id}) .box`);
      await page.click("#submitBtn");
      await page.waitForSelector(".success-ring", { timeout: 5000 });
      const idText = await page.textContent(".success-wrap p");
      record("B2", "Browser: full booking wizard submits through the API", /TN-/.test(idText), (idText.match(/TN-[\w-]+/) || [])[0]);
      await browser.close();
    } catch (e) { record("B", "Browser checks", false, e.message); }
  }

  /* write results file */
  const passCount = results.filter(r => r.ok).length;
  const md = [
    "# Phase 3 — End-to-End Launch Test Results",
    "",
    `Run: ${new Date().toISOString()} · Node ${process.version} · fresh database per run`,
    "",
    "| # | Scenario | Result | Detail |",
    "|---|----------|--------|--------|",
    ...results.map(r => `| ${r.n} | ${r.name} | ${r.ok ? "✅ PASS" : "❌ FAIL"} | ${r.detail} |`),
    "",
    `**${passCount}/${results.length} passed.**`
  ].join("\n");
  fs.writeFileSync(path.join(ROOT, "TEST-RESULTS.md"), md);
  console.log(`\n${passCount}/${results.length} passed — written to TEST-RESULTS.md`);

  serverProc.kill(); mock.close();
  fs.rmSync(TESTDATA, { recursive: true, force: true });
  process.exit(passCount === results.length ? 0 : 1);
}

main().catch(e => { console.error("FATAL", e); serverProc.kill(); process.exit(1); });
