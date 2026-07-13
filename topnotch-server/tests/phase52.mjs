/* ============================================================
   Phase 5.2 test suite — TopNotch Autopilot
   (Karpathy-INSPIRED continuous-improvement operating system)

   Tests 1–24 run in-process against a fresh staging database so the
   agent loop, governor, evaluations, cost caps, completion scoring
   and maintenance mode can be exercised directly.
   Test 25 re-runs the full Phase 3 / 4 / 4.1 suites as child
   processes and requires them all green.

   Run: node tests/phase52.mjs
   ============================================================ */
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, "..");
const require = createRequire(path.join(ROOT, "server.js"));

const TESTDATA = path.join(ROOT, "data-p52");
fs.rmSync(TESTDATA, { recursive: true, force: true });
process.env.TN_DATA_DIR = TESTDATA;
process.env.TN_ENV = "staging";
delete process.env.OPENAI_MODEL;      // AI unset → deterministic fallback must carry everything
delete process.env.OPENAI_API_KEY;

const { db } = require("./lib/db");
require("./seed").seed();
const AP = require("./lib/autopilot");
const agent = require("./lib/agent");

const results = [];
const record = (n, name, okv, detail) => { results.push({ n, name, ok: okv, detail: detail || "" }); console.log(`${okv ? "PASS" : "FAIL"}  ${n} · ${name}${detail ? "  — " + detail : ""}`); };
const assert = (c, m) => { if (!c) throw new Error(m); };

/* helper: minimal request rows without going through HTTP */
let seqNo = 0;
function mkRequest(over = {}) {
  const id = "TNR-52" + String(++seqNo).padStart(3, "0");
  const r = {
    request_id: id, customer_name: "Ctx Customer " + seqNo, phone: "(305) 555-52" + String(seqNo).padStart(2, "0"),
    email: `p52-${seqNo}@example.com`, vehicle_requested: "Lamborghini Huracán EVO",
    start_date: "2027-03-01 10:00", end_date: "2027-03-03 10:00", option: "delivery",
    delivery_location: "Brickell", driver_age: "30–39", license_status: "Confirmed by customer",
    insurance_status: "Confirmed by customer", deposit_readiness: "Ready",
    status: "Request submitted", payment_status: "none", ...over
  };
  const cols = Object.keys(r);
  db.prepare(`INSERT INTO requests (${cols.join(",")}) VALUES (${cols.map(c => ":" + c).join(",")})`).run(r);
  return r;
}

async function main() {
  AP.ensurePermanentGoal();
  AP.seedEvalCases();

  /* 1 · agent receives a measurable objective (and refuses vague ones) */
  try {
    const vague = AP.queueTask({ objective: "make things better", tool: "expire-stale-quotes", input: {} });
    assert(vague.error && /success criteria/i.test(vague.error), "vague task must be rejected: " + JSON.stringify(vague));
    const good = AP.queueTask({ objective: "Expire overdue quotes", success_criteria: "0 expired quotes remain open", tool: "expire-stale-quotes", input: {} });
    assert(good.ok && good.taskId, JSON.stringify(good));
    globalThis.t1 = good.taskId;
    record(1, "Agent receives a measurable objective (vague objectives rejected)", true, good.taskId);
  } catch (e) { record(1, "Measurable objective", false, e.message); }

  /* 2 · agent retrieves only relevant context (no other customers, no dumps) */
  try {
    const mine = mkRequest({ status: "Availability being confirmed", assigned_vehicle_id: "V-1001" });
    const other = mkRequest({ customer_name: "Other Person", email: "other-person@example.com" });
    const q = AP.queueTask({ objective: "Re-check availability", success_criteria: "fresh availability decision recorded",
      tool: "recheck-availability", input: { requestId: mine.request_id } });
    const task = db.prepare("SELECT * FROM ap_tasks WHERE task_id=?").get(q.taskId);
    const ctx = JSON.stringify(AP.contextFor(task));
    assert(ctx.includes(mine.request_id), "context must include the task's own request");
    assert(!ctx.includes(other.request_id) && !ctx.includes("Other Person") && !ctx.includes("other-person@example.com"),
      "context leaked another customer");
    assert(!ctx.includes(mine.email) && !ctx.includes(mine.phone), "context must not carry contact PII the tool doesn't need");
    record(2, "Agent retrieves only relevant context (no cross-customer leakage)", true, "own request only + policies + recent failures");
  } catch (e) { record(2, "Context retrieval", false, e.message); }

  /* 3 · agent selects a valid tool (registry only) */
  try {
    const bad = AP.queueTask({ objective: "x", success_criteria: "y", tool: "drop-all-tables", input: {} });
    assert(bad.error && /Unknown tool/.test(bad.error), JSON.stringify(bad));
    assert(AP.validateToolInput("recheck-availability", { requestId: "TNR-1" }) === null, "valid input must pass");
    record(3, "Agent selects a valid tool — unknown tools refused", true, "registry: " + Object.keys(AP.TOOLS).join(", "));
  } catch (e) { record(3, "Valid tool selection", false, e.message); }

  /* 4 · invalid tool input is rejected */
  try {
    const bad1 = AP.validateToolInput("recheck-availability", {});
    const bad2 = AP.validateToolInput("send-followup", { requestId: "TNR-1", template: 42 });
    assert(bad1 && /requestId/.test(bad1), String(bad1));
    assert(bad2 && /template/.test(bad2), String(bad2));
    const q = AP.queueTask({ objective: "x", success_criteria: "y", tool: "recheck-availability", input: { requestId: 99 } });
    assert(q.error && /must be string/.test(q.error), JSON.stringify(q));
    record(4, "Invalid tool input rejected (type-checked before queueing)", true, bad1);
  } catch (e) { record(4, "Invalid input rejection", false, e.message); }

  /* 5 · every action is verified against external evidence */
  try {
    const r = mkRequest({});
    const q = AP.queueTask({ objective: "Re-check availability", success_criteria: "decision recorded",
      tool: "recheck-availability", input: { requestId: r.request_id } });
    const run = await AP.runTask(q.taskId);
    assert(run.status === "verified", JSON.stringify(run));
    assert(/^db:/.test(run.verification.evidence), "evidence must come from the database, got: " + run.verification.evidence);
    const row = db.prepare("SELECT verified, reasoning_summary FROM ap_tasks WHERE task_id=?").get(q.taskId);
    assert(row.verified === 1 && /Evidence:/.test(row.reasoning_summary), "task row must store verification + summary");
    record(5, "Every action is verified (DB evidence, not self-report)", true, run.verification.evidence);
  } catch (e) { record(5, "Action verification", false, e.message); }

  /* 6 · agent cannot declare success without evidence */
  try {
    /* claim success for a request the tool never touched → verify() must refuse */
    const ghost = mkRequest({});
    const v = AP.TOOLS["chase-provider"].verify({ requestId: ghost.request_id }, { notified: "P-001", claimed: "success!" });
    assert(v.verified === false && /no notification row/.test(v.evidence), JSON.stringify(v));
    record(6, "Success without external evidence is refused", true, v.evidence);
  } catch (e) { record(6, "No evidence, no success", false, e.message); }

  /* 7 · agent records failure (status, result, lesson in memory) */
  try {
    const q = AP.queueTask({ objective: "Chase provider", success_criteria: "reminder notification recorded",
      tool: "chase-provider", input: { requestId: "TNR-DOES-NOT-EXIST" } });
    const run = await AP.runTask(q.taskId);
    assert(run.status === "failed" && run.attempts === 1, JSON.stringify(run));
    const row = db.prepare("SELECT * FROM ap_tasks WHERE task_id=?").get(q.taskId);
    assert(row.status === "failed" && JSON.parse(row.result_json).error, "failure must be stored");
    const lesson = AP.recall("workflow", "failure:chase-provider%", 1);
    assert(lesson.length === 1, "failure lesson must land in workflow memory");
    globalThis.failTask = q.taskId;
    record(7, "Agent records failure honestly (status + error + memory lesson)", true, JSON.parse(row.result_json).error);
  } catch (e) { record(7, "Failure recording", false, e.message); }

  /* 8 · three failed attempts trigger escalation to a human */
  try {
    await AP.runTask(globalThis.failTask);                       // attempt 2
    const third = await AP.runTask(globalThis.failTask);          // attempt 3 → escalate
    assert(third.status === "escalated", JSON.stringify(third));
    const row = db.prepare("SELECT status, attempts FROM ap_tasks WHERE task_id=?").get(globalThis.failTask);
    assert(row.status === "escalated" && row.attempts === 3, JSON.stringify(row));
    const n = db.prepare("SELECT * FROM notifications WHERE type='AUTOPILOT_ESCALATION' AND title LIKE ?").get(`%${globalThis.failTask}%`);
    assert(n && n.audience_role === "ops", "ops must be notified");
    const fourth = await AP.runTask(globalThis.failTask);
    assert(fourth.error, "an escalated task must not silently re-run");
    record(8, "3 failed attempts → escalation with notification (no infinite retries)", true, `attempts=3, notified ops #${n.id}`);
  } catch (e) { record(8, "Escalation after 3 attempts", false, e.message); }

  /* 9 · human correction creates an evaluation case */
  try {
    const before = db.prepare("SELECT count(*) n FROM ap_eval_cases").get().n;
    const out = AP.recordCorrection({ requestRef: "TNR-52001", aiAction: "quoted stale unit as available",
      original: { vehicle: "G63", lastVerified: "9 days ago" }, correction: "manual availability confirmation required",
      reason: "unit past verify_days must never auto-quote", category: "availability" }, "admin@topnotchrentalz.com");
    assert(out.ok && out.evalCaseId, JSON.stringify(out));
    const after = db.prepare("SELECT count(*) n FROM ap_eval_cases").get().n;
    assert(after === before + 1, "eval case count must grow");
    const ev = db.prepare("SELECT * FROM ap_eval_cases WHERE id=?").get(out.evalCaseId);
    assert(ev.source === "human-correction", JSON.stringify(ev));
    record(9, "Human correction → permanent evaluation case (prompt never auto-rewritten)", true, "eval case #" + out.evalCaseId);
  } catch (e) { record(9, "Correction → eval case", false, e.message); }

  /* 10 · agent cannot edit its permanent goal */
  try {
    const g1 = AP.updateGoal("G-MISSION", { name: "easier goal", target: 0 }, "autopilot");
    assert(g1.blocked, JSON.stringify(g1));
    const g2 = AP.updateGoal("G-MISSION", { status: "Completed" }, "admin@topnotchrentalz.com");
    assert(g2.blocked, "even an admin cannot edit it at runtime: " + JSON.stringify(g2));
    const row = db.prepare("SELECT name, permanent FROM ap_goals WHERE goal_id='G-MISSION'").get();
    assert(row.permanent === 1 && row.name === "Permanent company mission", "mission row must be untouched");
    const blockedAudit = db.prepare("SELECT count(*) n FROM audit WHERE action='autopilot.blocked' AND entity_id='G-MISSION'").get().n;
    assert(blockedAudit >= 2, "blocked attempts must be audited");
    record(10, "Permanent goal is immutable at runtime (attempts audited)", true, g1.error);
  } catch (e) { record(10, "Permanent goal locked", false, e.message); }

  /* 11 · agent cannot remove cost limits */
  try {
    const g = AP.governor("remove-cost-limits", "raise ai_daily_cost_cap to Infinity");
    assert(g.blocked && g.escalate, JSON.stringify(g));
    record(11, "Governor blocks removing cost limits", true, g.reason);
  } catch (e) { record(11, "Cost limits protected", false, e.message); }

  /* 12 · agent cannot change permissions */
  try {
    const g = AP.governor("change-permissions", "grant partner role admin scope");
    const g2 = AP.governor("create-users", "add shadow admin");
    assert(g.blocked && g2.blocked, JSON.stringify({ g, g2 }));
    record(12, "Governor blocks permission and account changes", true, g.reason);
  } catch (e) { record(12, "Permissions protected", false, e.message); }

  /* 13 · agent cannot deploy directly to production */
  try {
    const g = AP.governor("deploy-production", "push improvement straight to prod");
    const g2 = AP.governor("modify-db-schema", "ALTER TABLE requests");
    assert(g.blocked && g2.blocked, JSON.stringify({ g, g2 }));
    const audited = db.prepare("SELECT count(*) n FROM audit WHERE action='autopilot.blocked' AND entity='safety'").get().n;
    assert(audited >= 4, "governor blocks must be audited, saw " + audited);
    record(13, "Governor blocks direct production deploys and schema changes", true, g.reason);
  } catch (e) { record(13, "No direct prod deploys", false, e.message); }

  /* 14 · staging improvement passes tests (eval gate) */
  try {
    const base = AP.runEval("baseline");                       // first run sets the baseline
    db.prepare("INSERT INTO sync_outbox (table_name, row_json, status) VALUES ('requests','{}','failed')").run();
    const cyc = AP.improvementCycle();
    assert(cyc.proposals.length >= 1, "cycle must propose something with a failed sync row present");
    const low = db.prepare("SELECT id FROM ap_proposals WHERE risk='low' ORDER BY id DESC LIMIT 1").get();
    assert(low, "need a low-risk proposal");
    const staged = AP.stageProposal(low.id, undefined, "admin@topnotchrentalz.com");
    assert(staged.ok && staged.candidate >= staged.baseline, JSON.stringify(staged));
    assert(db.prepare("SELECT status FROM ap_proposals WHERE id=?").get(low.id).status === "staging-passed", "status must advance");
    globalThis.baselineScore = base.candidateScore;
    record(14, "Staging improvement passes the evaluation gate", true, `candidate ${staged.candidate} ≥ baseline ${staged.baseline}`);
  } catch (e) { record(14, "Staging gate", false, e.message); }

  /* 15 · regression causes automatic rollback + reopened goal */
  try {
    const cyc = AP.improvementCycle();
    const p = db.prepare("SELECT id, title, metric FROM ap_proposals WHERE status='proposed' AND risk='low' ORDER BY id DESC LIMIT 1").get();
    assert(p, "need a fresh low-risk proposal");
    const out = AP.stageProposal(p.id, Math.max(0, (globalThis.baselineScore ?? 50) - 20), "admin@topnotchrentalz.com");
    assert(out.rolledBack, JSON.stringify(out));
    const row = db.prepare("SELECT status, rollback_status FROM ap_proposals WHERE id=?").get(p.id);
    assert(row.status === "rolled-back" && /regression/.test(row.rollback_status), JSON.stringify(row));
    const goal = db.prepare("SELECT * FROM ap_goals WHERE name LIKE 'Reopened: regression%' AND status='Reopened'").get();
    assert(goal, "a Reopened goal must exist");
    const n = db.prepare("SELECT id FROM notifications WHERE type='AUTO_ROLLBACK' ORDER BY id DESC LIMIT 1").get();
    assert(n, "admin must be notified of the rollback");
    record(15, "Regression → automatic rollback + goal reopened + admin notified", true, row.rollback_status);
  } catch (e) { record(15, "Auto rollback", false, e.message); }

  /* 16 · completion score cannot use mocked production results */
  try {
    const sc = AP.completionScore();
    assert(sc.stagingScore > 0, "staging evidence exists so stagingScore > 0");
    assert(sc.productionScore === 0, "TN_ENV=staging with mock integrations must yield productionScore 0, got " + sc.productionScore);
    assert(sc.canDeclare100 === false, "cannot declare 100%");
    const mocked = sc.items.filter(i => i.stagingVerified && !i.productionVerified);
    assert(mocked.length > 0 && mocked.every(i => /staging|not live|mock|production/.test(i.note)), "withheld items must say why");
    record(16, "Completion score: mocks & staging evidence earn ZERO production points", true,
      `staging ${sc.stagingScore}/100 · production ${sc.productionScore}/100`);
  } catch (e) { record(16, "Honest completion score", false, e.message); }

  /* 17 · owner independence score calculates correctly */
  try {
    const oi = AP.ownerIndependence();
    assert(oi.level >= 1 && oi.level <= 5, "level must be 1–5");
    const per = oi.interventionsPerBooking;
    const expect = per > 8 ? 1 : per > 5 ? 2 : per > 2.5 ? 3 : per > 1 ? 4 : 5;
    assert(oi.level === expect, `level ${oi.level} inconsistent with ${per}/booking`);
    assert(oi.stillHuman.includes("Damage deductions") && oi.stillHuman.includes("Production deploys"), "protected list must stay human");
    assert(typeof oi.minutesPerBooking === "number" && oi.recommendation.length > 0, "recommendation required");
    record(17, "Owner Independence level computed from real audit counts", true,
      `Level ${oi.level} (${oi.levelName}) @ ${per} interventions/booking`);
  } catch (e) { record(17, "Owner independence", false, e.message); }

  /* 18 · AI cost cap pauses nonessential work */
  try {
    db.prepare("UPDATE settings SET value='0.01' WHERE key='ai_daily_cost_cap'").run();
    AP.logCost("llm:test", 5000, 0.05, "test", "cap trip");
    assert(AP.isPaused("ai"), "AI must pause at the cap");
    const llmOut = await AP.llm("summary", "say hi", 10);
    assert(llmOut.disabled && /paused/i.test(llmOut.reason), JSON.stringify(llmOut));
    const n = db.prepare("SELECT id FROM notifications WHERE type='AI_COST_CAP' ORDER BY id DESC LIMIT 1").get();
    assert(n, "admin must be told the AI paused itself");
    record(18, "Cost cap reached → AI pauses itself and tells the admin", true, "daily cap $0.01 tripped");
  } catch (e) { record(18, "Cost cap pause", false, e.message); }

  /* 19 · deterministic workflows continue after the AI pause */
  try {
    assert(AP.isPaused("ai"), "precondition: AI still paused");
    const r = mkRequest({});
    const d = agent.checkAvailability(db.prepare("SELECT * FROM requests WHERE request_id=?").get(r.request_id));
    assert(["available", "unavailable", "manual"].includes(d.result), "availability agent must still decide: " + JSON.stringify(d));
    const q = AP.queueTask({ objective: "Expire overdue quotes", success_criteria: "0 expired quotes remain",
      tool: "expire-stale-quotes", input: {} });
    const run = await AP.runTask(q.taskId);
    assert(run.status === "verified", "deterministic tool must still run+verify: " + JSON.stringify(run));
    db.prepare("UPDATE settings SET value='25' WHERE key='ai_daily_cost_cap'").run();
    AP.setPause("ai", false, "test");
    record(19, "Deterministic workflows unaffected by AI pause (availability, tools, safety)", true, d.result + " decision + tool verified");
  } catch (e) { record(19, "Deterministic continuity", false, e.message); }

  /* 20 · daily improvement cycle creates no more than 3 proposals */
  try {
    /* force MANY candidate conditions at once */
    mkRequest({ status: "Availability being confirmed" });
    mkRequest({ status: "Manual availability confirmation required" });
    db.prepare("INSERT INTO holds (request_id, vehicle_id, expires_at, status) VALUES ('TNR-52001','V-1001', datetime('now','-1 hour'),'expired')").run();
    db.prepare("INSERT INTO notifications (audience_role, type, title, body, delivery) VALUES ('admin','X','x','x','recorded')").run();
    const before = db.prepare("SELECT count(*) n FROM ap_proposals").get().n;
    const cyc = AP.improvementCycle();
    const added = db.prepare("SELECT count(*) n FROM ap_proposals").get().n - before;
    assert(cyc.proposals.length <= 3 && added <= 3, `got ${added} proposals`);
    assert(cyc.proposals.length === 3, "with 5 candidate conditions the cap of 3 must bind");
    record(20, "Improvement cycle proposes at most 3 changes per run", true, `5 candidate signals → ${added} proposals`);
  } catch (e) { record(20, "≤3 proposals", false, e.message); }

  /* 21 · every proposal identifies metric, cost, risk and verification */
  try {
    const rows = db.prepare("SELECT * FROM ap_proposals").all();
    assert(rows.length > 0, "need proposals");
    for (const p of rows)
      assert(p.metric && p.cost_estimate && p.risk && p.verification && p.reason && p.expected_impact,
        "incomplete proposal #" + p.id + ": " + JSON.stringify(p));
    record(21, "Proposals always carry metric + cost + risk + verification plan", true, rows.length + " proposals checked");
  } catch (e) { record(21, "Proposal completeness", false, e.message); }

  /* 22 · unsafe experiment is rejected */
  try {
    const bad = AP.createExperiment({ name: "Skip payment verification for repeat customers",
      hypothesis: "confirming bookings before payment verification will convert faster",
      primary_metric: "conversion", min_sample: 50 }, "admin@topnotchrentalz.com");
    assert(bad.blocked, JSON.stringify(bad));
    const bad2 = AP.createExperiment({ name: "Lower security deposit deduction threshold",
      hypothesis: "auto-deducting small damages saves time", primary_metric: "owner time", min_sample: 30 }, "admin@topnotchrentalz.com");
    assert(bad2.blocked, JSON.stringify(bad2));
    const ok = AP.createExperiment({ name: "Hero video A/B", hypothesis: "interior-first hero raises request rate",
      primary_metric: "request conversion", min_sample: 200 }, "admin@topnotchrentalz.com");
    assert(ok.ok, JSON.stringify(ok));
    record(22, "Experiments on safety/payments/privacy refused; benign ones allowed", true, bad.error.slice(0, 80) + "…");
  } catch (e) { record(22, "Experiment guardrails", false, e.message); }

  /* 23 · production/staging score falls after a regression */
  try {
    const sc = AP.completionScore();
    assert(sc.regressionActive === true, "test 15's rollback is <7 days old so the regression flag must be up");
    const gate = sc.items.find(i => i.id === 14);
    assert(gate && !gate.stagingVerified, "safety-gate item must lose its points during an active regression");
    assert(sc.canDeclare100 === false, "no 100% during a regression");
    record(23, "Active regression withholds the safety-gate points (score drops)", true,
      `item 14 unverified → staging ${sc.stagingScore}/100`);
  } catch (e) { record(23, "Score falls on regression", false, e.message); }

  /* 24 · maintenance mode reopens failed goals */
  try {
    AP.setState("mode", "maintenance");
    db.prepare("INSERT INTO sync_outbox (table_name, row_json, status) VALUES ('requests','{}','failed')").run();
    const out = AP.monitorAndReopen();
    assert(out.reopened >= 1, JSON.stringify(out));
    const goal = db.prepare("SELECT * FROM ap_goals WHERE name='Reopened: excel-sync' AND status='Reopened'").get();
    assert(goal && goal.priority === 1, "excel-sync incident goal must be reopened at priority 1");
    const n = db.prepare("SELECT id FROM notifications WHERE type='MAINTENANCE_REOPEN' ORDER BY id DESC LIMIT 1").get();
    assert(n, "maintenance mode must announce reopened work");
    const again = AP.monitorAndReopen();
    const dupes = db.prepare("SELECT count(*) n FROM ap_goals WHERE name='Reopened: excel-sync'").get().n;
    assert(dupes === 1, "no duplicate incident goals");
    record(24, "Maintenance mode reopens work when performance regresses (no duplicates)", true, goal.goal_id);
  } catch (e) { record(24, "Maintenance reopen", false, e.message); }

  /* 25 · all previous phase suites still pass */
  try {
    const suites = [["tests/e2e.mjs", "Phase 3"], ["tests/phase4.mjs", "Phase 4"], ["tests/phase41.mjs", "Phase 4.1"]];
    const outcomes = [];
    for (const [file, label] of suites) {
      const r = spawnSync("node", [file], { cwd: ROOT, encoding: "utf8", timeout: 300000, env: { ...process.env, TN_DATA_DIR: "" } });
      const tail = (r.stdout || "").trim().split("\n").pop();
      outcomes.push(`${label}: ${tail}`);
      assert(r.status === 0, `${label} (${file}) failed — ${tail}\n${(r.stdout || "").slice(-1500)}`);
    }
    record(25, "Phase 3 + 4 + 4.1 suites all still green", true, outcomes.join(" · "));
  } catch (e) { record(25, "Previous phases regression", false, e.message); }

  const pass = results.filter(r => r.ok).length;
  const md = ["# Phase 5.2 — TopNotch Autopilot Test Results", "",
    `Run: ${new Date().toISOString()} · fresh staging database · OPENAI_MODEL unset (deterministic fallback verified)`,
    "", "| # | Scenario | Result | Detail |", "|---|----------|--------|--------|",
    ...results.map(r => `| ${r.n} | ${r.name} | ${r.ok ? "✅ PASS" : "❌ FAIL"} | ${r.detail.replace(/\|/g, "/")} |`),
    "", `**${pass}/${results.length} passed.**`].join("\n");
  fs.writeFileSync(path.join(ROOT, "TEST-RESULTS-PHASE52.md"), md);
  console.log(`\n${pass}/${results.length} passed → TEST-RESULTS-PHASE52.md`);

  fs.rmSync(TESTDATA, { recursive: true, force: true });
  process.exit(pass === results.length ? 0 : 1);
}
main().catch(e => { console.error("FATAL", e); process.exit(1); });
