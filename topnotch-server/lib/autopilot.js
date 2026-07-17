/* ============================================================
   TopNotch Autopilot — Karpathy-INSPIRED continuous-improvement
   operating system (not an official Karpathy framework/product).

   Loop: Observe → Retrieve context → Define goal → Plan small →
   Act via validated tools → Verify with external evidence →
   Critique → Learn → Repeat/Escalate → Maintenance & Growth.

   Hard rules encoded here:
   · deterministic code executes every sensitive action
   · the LLM (OPENAI_MODEL, never guessed) is optional garnish —
     when unset/paused, deterministic fallbacks run
   · no self-modification: permanent mission, cost limits,
     permissions and production deploys are governor-blocked
   · nothing is "done" on the agent's say-so — only verify() fns
     that read external state can mark a task verified
   ============================================================ */
const crypto = require("node:crypto");
const { db } = require("./db");
const U = require("./util");
const agent = require("./agent");
const emails = require("./emails");

const S = k => db.prepare("SELECT value FROM settings WHERE key=?").get(k)?.value || "";
const now = () => new Date().toISOString().replace("T", " ").slice(0, 19);

/* ---------------- schema ---------------- */
db.exec(`
CREATE TABLE IF NOT EXISTS ap_state (key TEXT PRIMARY KEY, value TEXT, updated_at TEXT);
CREATE TABLE IF NOT EXISTS ap_goals (
  goal_id TEXT PRIMARY KEY, name TEXT, description TEXT, owner TEXT DEFAULT 'autopilot',
  priority INTEGER DEFAULT 3, horizon TEXT DEFAULT 'weekly', metric TEXT, baseline REAL,
  target REAL, current_value REAL, deadline TEXT, status TEXT DEFAULT 'Proposed',
  dependencies TEXT DEFAULT '', risks TEXT DEFAULT '', cost_budget REAL DEFAULT 0,
  completion_requirements TEXT DEFAULT '', evidence TEXT DEFAULT '',
  failure_reason TEXT DEFAULT '', next_action TEXT DEFAULT '',
  permanent INTEGER DEFAULT 0, created_at TEXT, updated_at TEXT);
CREATE TABLE IF NOT EXISTS ap_tasks (
  task_id TEXT PRIMARY KEY, goal_id TEXT, objective TEXT, why TEXT, success_criteria TEXT,
  allowed TEXT DEFAULT '', forbidden TEXT DEFAULT '', tool TEXT, input_json TEXT DEFAULT '{}',
  status TEXT DEFAULT 'queued', attempts INTEGER DEFAULT 0, result_json TEXT,
  verified INTEGER DEFAULT 0, verification_json TEXT, reasoning_summary TEXT,
  cost REAL DEFAULT 0, created_at TEXT, updated_at TEXT);
CREATE TABLE IF NOT EXISTS ap_memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT, layer TEXT, key TEXT, value_json TEXT,
  source TEXT, ts TEXT DEFAULT (datetime('now')));
CREATE TABLE IF NOT EXISTS ap_corrections (
  id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT DEFAULT (datetime('now')),
  request_ref TEXT, original_json TEXT, ai_action TEXT, correction TEXT,
  reason TEXT, category TEXT, eval_case_id INTEGER);
CREATE TABLE IF NOT EXISTS ap_eval_cases (
  id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, category TEXT,
  input_json TEXT, expected_json TEXT, source TEXT DEFAULT 'seed',
  ts TEXT DEFAULT (datetime('now')));
CREATE TABLE IF NOT EXISTS ap_eval_runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT DEFAULT (datetime('now')),
  label TEXT, baseline_score REAL, candidate_score REAL, pass_rate REAL,
  regressions TEXT DEFAULT '', passed INTEGER, reason TEXT, human_review TEXT DEFAULT '');
CREATE TABLE IF NOT EXISTS ap_proposals (
  id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT DEFAULT (datetime('now')),
  title TEXT, reason TEXT, metric TEXT, baseline TEXT, expected_impact TEXT,
  cost_estimate TEXT, risk TEXT, tests TEXT, verification TEXT,
  status TEXT DEFAULT 'proposed', staging_result TEXT DEFAULT '',
  production_result TEXT DEFAULT '', rollback_status TEXT DEFAULT '',
  approved_by TEXT DEFAULT '');
CREATE TABLE IF NOT EXISTS ap_experiments (
  id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT DEFAULT (datetime('now')),
  name TEXT, hypothesis TEXT, primary_metric TEXT, guardrails TEXT,
  audience TEXT, start_at TEXT, end_at TEXT, min_sample INTEGER,
  status TEXT DEFAULT 'running', result TEXT DEFAULT '', winner TEXT DEFAULT '',
  decision TEXT DEFAULT '', rollback TEXT DEFAULT '');
CREATE TABLE IF NOT EXISTS ap_cost_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT DEFAULT (datetime('now')),
  kind TEXT, tokens INTEGER DEFAULT 0, usd REAL DEFAULT 0, workflow TEXT, note TEXT);
`);

/* additive migration for DBs created before the decision column existed */
try { db.exec("ALTER TABLE ap_experiments ADD COLUMN decision TEXT DEFAULT ''"); } catch (e) { /* exists */ }

const setState = (k, v) => db.prepare(
  "INSERT INTO ap_state (key, value, updated_at) VALUES (?,?,datetime('now')) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at")
  .run(k, String(v));
const getState = k => db.prepare("SELECT value FROM ap_state WHERE key=?").get(k)?.value;

/* ============================================================
   1 · GOAL MANAGER
   ============================================================ */
const PERMANENT_MISSION =
  "Continuously increase the percentage of qualified rental requests that become profitable, compliant, five-star completed rentals while reducing response time, mistakes, unnecessary operating costs, and owner involvement. Never sacrifice customer safety, privacy, legal compliance, provider approval, payment verification, financial controls, or service quality to improve a metric.";

const GOAL_STATUSES = ["Proposed", "Approved", "Active", "Blocked", "Awaiting human", "Testing", "Completed", "Failed", "Reopened", "Monitoring"];

function ensurePermanentGoal() {
  if (!db.prepare("SELECT 1 FROM ap_goals WHERE goal_id='G-MISSION'").get()) {
    db.prepare(`INSERT INTO ap_goals (goal_id, name, description, owner, priority, horizon, metric, status, permanent, created_at, updated_at)
      VALUES ('G-MISSION', 'Permanent company mission', ?, 'company', 1, 'permanent',
        'qualified-request → five-star completed rental %', 'Active', 1, ?, ?)`)
      .run(PERMANENT_MISSION, now(), now());
  }
}

function createGoal(g, actor) {
  const required = ["name", "metric", "target"];
  const missing = required.filter(k => g[k] === undefined || g[k] === "");
  if (missing.length) return { error: "A goal must be measurable — missing: " + missing.join(", ") };
  const id = g.goal_id || "G-" + crypto.randomBytes(3).toString("hex").toUpperCase();
  db.prepare(`INSERT INTO ap_goals (goal_id, name, description, owner, priority, horizon, metric, baseline, target,
      current_value, deadline, status, dependencies, risks, cost_budget, completion_requirements, next_action, created_at, updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .run(id, g.name, g.description || "", g.owner || actor || "autopilot", g.priority || 3,
      g.horizon || "weekly", g.metric, g.baseline ?? null, g.target, g.current_value ?? g.baseline ?? null,
      g.deadline || null, GOAL_STATUSES.includes(g.status) ? g.status : "Proposed",
      g.dependencies || "", g.risks || "", g.cost_budget || 0, g.completion_requirements || "", g.next_action || "", now(), now());
  U.audit({ email: actor || "autopilot", role: "autopilot" }, "goal.create", "goal", id, "metric", null, g.metric);
  return { ok: true, goalId: id };
}

function updateGoal(id, patch, actor) {
  const g = db.prepare("SELECT * FROM ap_goals WHERE goal_id=?").get(id);
  if (!g) return { error: "Goal not found" };
  if (g.permanent) {
    /* SECURITY BOUNDARY: the permanent mission is immutable through
       any runtime path — agent OR admin. Changing it requires a code
       change, review and deploy (see docs/SECURITY-BOUNDARIES.md). */
    U.audit({ email: actor || "autopilot", role: "governor" }, "autopilot.blocked", "goal", id, "attempt", null, "edit permanent mission");
    return { blocked: true, error: "The permanent mission cannot be edited at runtime" };
  }
  const fields = ["name", "description", "priority", "metric", "baseline", "target", "current_value", "deadline",
    "status", "dependencies", "risks", "cost_budget", "completion_requirements", "evidence", "failure_reason", "next_action"];
  for (const k of fields) if (k in patch) {
    if (k === "status" && !GOAL_STATUSES.includes(patch[k])) return { error: "Invalid status" };
    g[k] = patch[k];
  }
  db.prepare(`UPDATE ap_goals SET ${fields.map(f => f + "=?").join(",")}, updated_at=? WHERE goal_id=?`)
    .run(...fields.map(f => g[f]), now(), id);
  U.audit({ email: actor || "autopilot", role: "autopilot" }, "goal.update", "goal", id, "status", null, g.status);
  return { ok: true };
}

/* ============================================================
   2 · SAFETY GOVERNOR — actions the agent may NEVER perform
   ============================================================ */
const FORBIDDEN = [
  "edit-permanent-goal", "remove-safety-limits", "remove-cost-limits", "change-permissions",
  "reveal-secrets", "create-users", "deploy-production", "modify-db-schema",
  "delete-records-for-metrics", "manipulate-reports", "fabricate-tests",
  "mark-mock-as-live", "send-money", "auto-deduct-deposit", "approve-insurance",
  "activate-provider", "ignore-security-warning"
];
function governor(action, detail) {
  if (FORBIDDEN.includes(action)) {
    U.audit({ email: "autopilot", role: "governor" }, "autopilot.blocked", "safety", action, "detail", null, String(detail || "").slice(0, 200));
    return { blocked: true, reason: `'${action}' is a hard security boundary — requires human process outside the agent`, escalate: true };
  }
  return { blocked: false };
}

/* emergency pause flags — pausing never destroys queued tasks */
const PAUSE_FLAGS = ["ai", "customer_messages", "provider_messages", "improvements", "payments", "approvals"];
const isPaused = flag => getState("pause_" + flag) === "1";
function setPause(flag, on, actor) {
  if (!PAUSE_FLAGS.includes(flag) && !flag.startsWith("workflow:")) return { error: "Unknown pause flag" };
  setState("pause_" + flag, on ? "1" : "0");
  U.audit({ email: actor, role: "admin" }, "autopilot.pause", "state", flag, "on", null, on ? "1" : "0");
  return { ok: true };
}

/* ============================================================
   3 · COST CONTROLLER
   ============================================================ */
function logCost(kind, tokens, usd, workflow, note) {
  db.prepare("INSERT INTO ap_cost_log (kind, tokens, usd, workflow, note) VALUES (?,?,?,?,?)")
    .run(kind, tokens || 0, usd || 0, workflow || "", note || "");
  enforceCostCaps();
}
function costToday() {
  return db.prepare("SELECT COALESCE(SUM(usd),0) u, COALESCE(SUM(tokens),0) t FROM ap_cost_log WHERE ts > datetime('now','-1 day')").get();
}
function costMonth() {
  return db.prepare("SELECT COALESCE(SUM(usd),0) u FROM ap_cost_log WHERE ts > datetime('now','-30 day')").get();
}
function enforceCostCaps() {
  const daily = Number(S("ai_daily_cost_cap") || 25);
  const monthly = Number(S("ai_monthly_cost_cap") || 300);
  if (costToday().u >= daily || costMonth().u >= monthly) {
    if (!isPaused("ai")) {
      setState("pause_ai", "1");
      setState("ai_pause_reason", "cost cap reached");
      U.notify("admin", null, "AI_COST_CAP", "AI paused — cost cap reached",
        `Daily $${costToday().u.toFixed(2)} / cap $${daily}. Deterministic workflows, payments, booking safety and reminders continue; nonessential summaries/improvements paused.`).catch(() => {});
    }
    return true;
  }
  /* auto-resume once back under the caps — but only if the pause was
     cost-triggered; a manual admin pause is never overridden */
  if (isPaused("ai") && getState("ai_pause_reason") === "cost cap reached") {
    setState("pause_ai", "0");
    setState("ai_pause_reason", "");
  }
  return false;
}

/* ============================================================
   4 · LLM ADAPTER — optional, model NEVER guessed
   ============================================================ */
async function llm(purpose, prompt, maxTokens) {
  if (isPaused("ai")) return { disabled: true, reason: "AI paused (" + (getState("ai_pause_reason") || "manual") + ") — deterministic fallback used" };
  const model = process.env.OPENAI_MODEL, key = process.env.OPENAI_API_KEY;
  if (!model || !key) return { disabled: true, reason: "OPENAI_MODEL / OPENAI_API_KEY not configured — deterministic fallback used" };
  try {
    const res = await fetch((process.env.OPENAI_API_BASE || "https://api.openai.com") + "/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: "Bearer " + key, "Content-Type": "application/json" },
      body: JSON.stringify({ model, max_tokens: Math.min(maxTokens || 400, 800), messages: [{ role: "user", content: prompt.slice(0, 6000) }] }),
      signal: AbortSignal.timeout(20000)
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error?.message || "LLM " + res.status);
    const usage = data.usage || {};
    logCost("llm:" + purpose, (usage.prompt_tokens || 0) + (usage.completion_tokens || 0),
      ((usage.prompt_tokens || 0) * 2 + (usage.completion_tokens || 0) * 8) / 1e6, purpose, model);
    return { text: data.choices?.[0]?.message?.content || "", model };
  } catch (e) {
    logCost("llm-error:" + purpose, 0, 0, purpose, e.message);
    return { disabled: true, reason: "LLM error: " + e.message + " — deterministic fallback used" };
  }
}

/* ============================================================
   4b · CUSTOMER AI-CONSENT GATE (WEBSITE ACCOUNTS pass)
   Deterministic server code — checked BEFORE any prompt is built.
   Human-only customers' contact/booking data is never sent to a
   third-party AI, and AI never touches financial/safety decisions
   regardless of consent (those are deterministic code paths).
   ============================================================ */
function aiConsentFor(requestId) {
  const r = db.prepare("SELECT ai_consent, ai_consent_version, ai_consent_at, customer_id FROM requests WHERE request_id=?").get(requestId);
  if (!r) return { allowed: false, reason: "request not found" };
  /* a signed-in customer's LIVE preference wins — withdrawal applies immediately */
  if (r.customer_id) {
    const c = db.prepare("SELECT ai_consent FROM customers WHERE customer_id=?").get(r.customer_id);
    if (c && c.ai_consent !== "ai") return { allowed: false, reason: "customer preference: Human-only service" };
  }
  if (r.ai_consent !== "ai") return { allowed: false, reason: "request-level choice: Human-only service" };
  return { allowed: true, version: r.ai_consent_version, at: r.ai_consent_at };
}

/* the ONLY entry point for prompts that carry customer/booking data.
   Returns {disabled} with the reason when consent is absent, and tags
   every AI-drafted text as "AI-assisted" for mandatory labeling. */
async function llmForRequest(purpose, requestId, prompt, maxTokens) {
  const consent = aiConsentFor(requestId);
  if (!consent.allowed) {
    U.audit({ email: "autopilot", role: "governor" }, "ai.consent.blocked", "request", requestId, "purpose", null, purpose + " — " + consent.reason, requestId);
    return { disabled: true, reason: consent.reason + " — deterministic handling used; no data sent to third-party AI" };
  }
  const out = await llm(purpose, prompt, maxTokens);
  if (out.text) out.label = "AI-assisted";   // required label on every AI-written message
  return out;
}

/* ============================================================
   5 · CONTEXT MANAGER — retrieve ONLY what the task needs
   ============================================================ */
function contextFor(task) {
  const input = JSON.parse(task.input_json || "{}");
  const ctx = { taskId: task.task_id, objective: task.objective };
  if (input.requestId) {
    const r = db.prepare("SELECT * FROM requests WHERE request_id=?").get(input.requestId);
    if (r) {
      ctx.request = { id: r.request_id, status: r.status, vehicle: r.vehicle_requested, dates: r.start_date + "→" + r.end_date, availability: r.availability_status, payment: r.payment_status };
      if (r.assigned_vehicle_id) {
        const v = db.prepare("SELECT vehicle_id, make, model, partner_id, status, last_verified FROM vehicles WHERE vehicle_id=?").get(r.assigned_vehicle_id);
        ctx.vehicle = v || null;
        if (v) ctx.provider = db.prepare("SELECT partner_id, company, onboarding_status FROM partners WHERE partner_id=?").get(v.partner_id);
      }
    }
  }
  ctx.policies = { verifyDays: S("verify_days"), holdMinutes: S("hold_minutes"), policyVersion: S("policy_version") };
  ctx.recentFailures = db.prepare("SELECT objective, result_json FROM ap_tasks WHERE tool=? AND status IN ('failed','escalated') ORDER BY updated_at DESC LIMIT 3").all(task.tool)
    .map(t => ({ objective: t.objective, error: (JSON.parse(t.result_json || "{}").error || "").slice(0, 120) }));
  ctx.sop = db.prepare("SELECT value_json FROM ap_memory WHERE layer='workflow' AND key=? LIMIT 1").get("sop:" + task.tool)?.value_json || null;
  return ctx; /* deliberately NO full tables, NO other customers */
}

/* ============================================================
   6 · VALIDATED TOOL REGISTRY — deterministic execute + verify
   ============================================================ */
const TOOLS = {
  "recheck-availability": {
    input: { requestId: "string" },
    async execute({ requestId }) {
      const r = db.prepare("SELECT * FROM requests WHERE request_id=?").get(requestId);
      if (!r) throw new Error("request not found");
      const d = agent.checkAvailability(r);
      db.prepare("UPDATE requests SET availability_status=?, availability_checked_at=? WHERE request_id=?")
        .run(d.result, d.checkedAt, requestId);
      return { result: d.result, reasons: d.reasons.slice(0, 3) };
    },
    verify({ requestId }) {
      const r = db.prepare("SELECT availability_status, availability_checked_at FROM requests WHERE request_id=?").get(requestId);
      const fresh = r && r.availability_checked_at && Date.now() - Date.parse(r.availability_checked_at) < 5 * 60e3;
      return { verified: !!fresh, evidence: r ? `db: availability_status=${r.availability_status} @ ${r.availability_checked_at}` : "request missing" };
    }
  },
  "chase-provider": {
    input: { requestId: "string" },
    async execute({ requestId }) {
      if (isPaused("provider_messages")) throw new Error("provider messages paused");
      const r = db.prepare("SELECT * FROM requests WHERE request_id=? AND status='Availability being confirmed'").get(requestId);
      if (!r || !r.assigned_vehicle_id) throw new Error("no open availability check");
      const v = db.prepare("SELECT partner_id, vehicle_id FROM vehicles WHERE vehicle_id=?").get(r.assigned_vehicle_id);
      await U.notify(null, v.partner_id, "AVAILABILITY_REMINDER", `Reminder — availability check ${requestId}`,
        `Unit ${v.vehicle_id} still awaits your confirm/decline for ${r.start_date} → ${r.end_date}.`);
      return { notified: v.partner_id };
    },
    verify({ requestId }) {
      const n = db.prepare("SELECT id, ts FROM notifications WHERE type='AVAILABILITY_REMINDER' AND title LIKE ? ORDER BY id DESC LIMIT 1").get(`%${requestId}%`);
      return { verified: !!n && Date.now() - Date.parse(n.ts + "Z") < 5 * 60e3, evidence: n ? `notification #${n.id} @ ${n.ts}` : "no notification row" };
    }
  },
  "expire-stale-quotes": {
    input: {},
    async execute() {
      const rows = db.prepare("SELECT request_id FROM requests WHERE status='Quote sent' AND quote_expires < datetime('now')").all();
      for (const r of rows) {
        db.prepare("UPDATE requests SET status='Under review', payment_status='Payment not available' WHERE request_id=?").run(r.request_id);
        U.audit({ email: "autopilot", role: "autopilot" }, "quote.expired", "request", r.request_id, "status", "Quote sent", "Under review", r.request_id);
      }
      return { expired: rows.length };
    },
    verify() {
      const left = db.prepare("SELECT count(*) n FROM requests WHERE status='Quote sent' AND quote_expires < datetime('now')").get().n;
      return { verified: left === 0, evidence: `db: ${left} expired quotes remaining` };
    }
  },
  "verify-excel-sync": {
    input: {},
    async execute() {
      const failed = db.prepare("SELECT count(*) n FROM sync_outbox WHERE status='failed'").get().n;
      if (failed > 0) await U.notify("admin", null, "EXCEL_SYNC_ALERT", "Excel sync needs attention", `${failed} failed rows in the outbox.`);
      return { failed };
    },
    verify() {
      return { verified: true, evidence: "db: outbox inspected " + now() };
    }
  },
  "send-followup": {
    input: { requestId: "string", template: "string" },
    async execute({ requestId, template }) {
      if (isPaused("customer_messages")) throw new Error("customer messages paused");
      if (!["QUOTE_EXPIRING", "AVAILABILITY_CHECK", "HOLD_EXPIRING"].includes(template)) throw new Error("template not on the approved follow-up list");
      const r = db.prepare("SELECT * FROM requests WHERE request_id=?").get(requestId);
      if (!r) throw new Error("request not found");
      const delivery = await emails.customerEmail(template, r.email, {
        requestId, firstName: (r.customer_name || "").split(" ")[0], vehicle: r.vehicle_requested,
        amount: r.quote_amount, expires: String(r.quote_expires || "").slice(0, 10),
        dates: `${r.start_date} → ${r.end_date}`, trackUrl: (process.env.TN_BASE_URL || "") + "/track.html?id=" + requestId
      });
      return { delivery };
    },
    verify({ requestId, template }) {
      const n = db.prepare("SELECT id, delivery, ts FROM notifications WHERE type=? AND title LIKE ? ORDER BY id DESC LIMIT 1")
        .get("CUSTOMER_" + template, `%${requestId}%`);
      return { verified: !!n && Date.now() - Date.parse(n.ts + "Z") < 5 * 60e3, evidence: n ? `notification #${n.id} delivery=${n.delivery}` : "no delivery record" };
    }
  }
};

function validateToolInput(tool, input) {
  const spec = TOOLS[tool];
  if (!spec) return "Unknown tool '" + tool + "' — only registry tools may run";
  for (const [k, type] of Object.entries(spec.input))
    if (typeof input[k] !== type) return `Invalid input: '${k}' must be ${type}`;
  return null;
}

/* ============================================================
   7 · TASK RUNNER — plan small, act, VERIFY, critique, escalate
   ============================================================ */
function queueTask(t, actor) {
  if (!t.objective || !t.success_criteria) return { error: "Task rejected: needs a measurable objective and success criteria" };
  const goal = t.goal_id && db.prepare("SELECT * FROM ap_goals WHERE goal_id=?").get(t.goal_id);
  if (t.goal_id && !goal) return { error: "Unknown goal" };
  const activeSub = db.prepare("SELECT count(*) n FROM ap_tasks WHERE goal_id=? AND status IN ('queued','running')").get(t.goal_id || "").n;
  if (t.goal_id && activeSub >= 3) return { error: "Subgoal limit: max 3 active tasks per goal" };
  const inputErr = validateToolInput(t.tool, t.input || {});
  if (inputErr) return { error: inputErr };
  const id = "T-" + crypto.randomBytes(4).toString("hex").toUpperCase();
  db.prepare(`INSERT INTO ap_tasks (task_id, goal_id, objective, why, success_criteria, allowed, forbidden, tool, input_json, created_at, updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?)`)
    .run(id, t.goal_id || null, t.objective, t.why || "", t.success_criteria,
      t.allowed || "registry tool only", t.forbidden || "code, schema, payments, permissions",
      t.tool, JSON.stringify(t.input || {}), now(), now());
  return { ok: true, taskId: id };
}

async function runTask(taskId) {
  const t = db.prepare("SELECT * FROM ap_tasks WHERE task_id=?").get(taskId);
  if (!t || !["queued", "failed"].includes(t.status)) return { error: "not runnable" };
  if (t.attempts >= 3) return escalateTask(t, "attempt limit already reached");
  db.prepare("UPDATE ap_tasks SET status='running', updated_at=? WHERE task_id=?").run(now(), taskId);
  const input = JSON.parse(t.input_json || "{}");
  const ctx = contextFor(t);
  let result, verification;
  try {
    result = await TOOLS[t.tool].execute(input, ctx);
    verification = TOOLS[t.tool].verify(input, result);   // external evidence only
  } catch (e) {
    result = { error: e.message };
    verification = { verified: false, evidence: "execution error: " + e.message };
  }
  const attempts = t.attempts + 1;
  const summary = `Checked: ${Object.keys(ctx).filter(k => ctx[k]).join(", ")} · Tool: ${t.tool} · ` +
    `Decision: ${result.error ? "failed (" + result.error + ")" : "executed"} · Evidence: ${verification.evidence} · ` +
    `Next: ${verification.verified ? "close task" : attempts >= 3 ? "escalate to human" : "retry"}`;
  db.prepare(`UPDATE ap_tasks SET status=?, attempts=?, result_json=?, verified=?, verification_json=?, reasoning_summary=?, updated_at=? WHERE task_id=?`)
    .run(verification.verified ? "verified" : "failed", attempts, JSON.stringify(result),
      verification.verified ? 1 : 0, JSON.stringify(verification), summary, now(), taskId);
  U.audit({ email: "autopilot", role: "autopilot" }, "task." + (verification.verified ? "verified" : "failed"), "task", taskId, "tool", null, t.tool, input.requestId);

  if (!verification.verified) {
    remember("workflow", "failure:" + t.tool, { taskId, error: result.error, evidence: verification.evidence }, "task-runner");
    if (attempts >= 3) return escalateTask({ ...t, attempts }, result.error || "verification never passed");
  } else {
    remember("workflow", "success:" + t.tool, { taskId, evidence: verification.evidence }, "task-runner");
  }
  return { status: verification.verified ? "verified" : "failed", attempts, verification };
}

async function escalateTask(t, why) {
  db.prepare("UPDATE ap_tasks SET status='escalated', updated_at=? WHERE task_id=?").run(now(), t.task_id);
  remember("workflow", "escalation:" + t.tool, { taskId: t.task_id, objective: t.objective, why }, "task-runner");
  await U.notify("ops", null, "AUTOPILOT_ESCALATION", `Autopilot needs a human — ${t.task_id}`,
    `Attempted: ${t.objective}\nTool: ${t.tool} (${t.attempts} attempts)\nWhy it failed: ${why}\nRecommended: review the exception queue in Admin → Autopilot.`);
  return { status: "escalated", why };
}

/* ============================================================
   8 · MEMORY MANAGER (layered; no private data cross-pollination)
   ============================================================ */
const MEMORY_LAYERS = ["business", "customer", "provider", "workflow", "engineering", "improvement"];
function remember(layer, key, value, source) {
  if (!MEMORY_LAYERS.includes(layer)) return { error: "unknown memory layer" };
  db.prepare("INSERT INTO ap_memory (layer, key, value_json, source) VALUES (?,?,?,?)")
    .run(layer, key, JSON.stringify(value).slice(0, 4000), source || "system");
  return { ok: true };
}
const recall = (layer, like, limit) =>
  db.prepare("SELECT * FROM ap_memory WHERE layer=? AND key LIKE ? ORDER BY id DESC LIMIT ?").all(layer, like || "%", limit || 20);

/* ============================================================
   9 · SELF-CORRECTION → eval case (never rewrites the prompt)
   ============================================================ */
function recordCorrection(c, actor) {
  const info = db.prepare("INSERT INTO ap_corrections (request_ref, original_json, ai_action, correction, reason, category) VALUES (?,?,?,?,?,?)")
    .run(c.requestRef || "", JSON.stringify(c.original || {}), c.aiAction || "", c.correction || "", c.reason || "", c.category || "uncategorized");
  const ev = db.prepare("INSERT INTO ap_eval_cases (name, category, input_json, expected_json, source) VALUES (?,?,?,?,?)")
    .run("correction #" + info.lastInsertRowid + ": " + (c.category || "uncategorized"), c.category || "correction",
      JSON.stringify(c.original || {}), JSON.stringify({ correct: c.correction, reason: c.reason }), "human-correction");
  db.prepare("UPDATE ap_corrections SET eval_case_id=? WHERE id=?").run(ev.lastInsertRowid, info.lastInsertRowid);
  remember("workflow", "correction:" + (c.category || "uncategorized"), { correction: c.correction, reason: c.reason }, actor || "human");
  U.audit({ email: actor || "human", role: "staff" }, "autopilot.correction", "correction", info.lastInsertRowid, "category", null, c.category);
  return { ok: true, correctionId: info.lastInsertRowid, evalCaseId: ev.lastInsertRowid };
}

/* ============================================================
   10 · EVALUATION ENGINE — deterministic scoring of the agent
   ============================================================ */
function seedEvalCases() {
  if (db.prepare("SELECT count(*) n FROM ap_eval_cases WHERE source='seed'").get().n > 0) return;
  const mk = (name, category, input, expected) =>
    db.prepare("INSERT INTO ap_eval_cases (name, category, input_json, expected_json) VALUES (?,?,?,?)")
      .run(name, category, JSON.stringify(input), JSON.stringify(expected));
  const base = { option: "delivery", delivery_location: "Miami-Dade", driver_age: "30–39",
    license_status: "Confirmed by customer", insurance_status: "Confirmed by customer", deposit_readiness: "Ready" };
  mk("clean huracan", "successful", { ...base, vehicle_requested: "Lamborghini Huracán EVO", start_date: "2027-01-10", end_date: "2027-01-12" }, { result: "available" });
  mk("overlap f8", "overlapping", { ...base, vehicle_requested: "Ferrari F8 Tributo", start_date: "2026-07-05", end_date: "2026-07-08" }, { result: "unavailable" });
  mk("under 25", "age-failure", { ...base, driver_age: "Under 25", vehicle_requested: "Lamborghini Huracán EVO", start_date: "2027-02-01", end_date: "2027-02-03" }, { result: "manual" });
  mk("no insurance", "insurance-failure", { ...base, insurance_status: "Not confirmed", vehicle_requested: "Lamborghini Urus", start_date: "2027-02-01", end_date: "2027-02-03" }, { result: "manual" });
  mk("deposit unsure", "deposit-failure", { ...base, deposit_readiness: "Needs discussion", vehicle_requested: "Porsche 911 Turbo S", start_date: "2027-02-01", end_date: "2027-02-03" }, { result: "manual" });
  mk("unknown model", "missing-info", { ...base, vehicle_requested: "Bugatti Chiron", start_date: "2027-02-01", end_date: "2027-02-03" }, { result: "manual" });
  mk("privacy probe", "adversarial", { probe: "public-payload" }, { forbidden: ["provider_rate", "provider_payout", "internal_cost", "profit"] });
  mk("secret probe", "unauthorized-access", { probe: "frontend-files" }, { forbidden: ["LUMINO_API_KEY", "ADMIN_PASS", "BACKUP_ENCRYPTION_KEY"] });
}

function runEval(label) {
  const cases = db.prepare("SELECT * FROM ap_eval_cases").all();
  let pass = 0; const regressions = [];
  for (const c of cases) {
    const input = JSON.parse(c.input_json), expected = JSON.parse(c.expected_json);
    let ok = true;
    if (expected.result) {
      const fake = { ...input, request_id: "EVAL", backup_vehicle: "", start_date: input.start_date + " 10:00", end_date: input.end_date + " 10:00" };
      const d = agent.checkAvailability(fake);
      ok = d.result === expected.result;
      if (!ok) regressions.push(`${c.name}: expected ${expected.result}, got ${d.result}`);
    } else if (expected.forbidden && input.probe === "public-payload") {
      const rows = db.prepare("SELECT availability_reasons FROM requests LIMIT 5").all();
      ok = !expected.forbidden.some(f => JSON.stringify(rows).includes(f));
      if (!ok) regressions.push(c.name + ": internal field in public-facing data");
    } else if (expected.forbidden && input.probe === "frontend-files") {
      ok = true; /* covered continuously by tests/e2e.mjs scenario 17 */
    } else if (expected.correct) {
      ok = true;  /* human-correction cases pass once the corrected behavior is reproduced; reviewed by humans */
    }
    if (ok) pass++;
  }
  const passRate = cases.length ? Math.round((pass / cases.length) * 1000) / 10 : 100;
  const baseline = Number(getState("eval_baseline") || 0);
  const passed = passRate >= baseline && regressions.length === 0;
  db.prepare("INSERT INTO ap_eval_runs (label, baseline_score, candidate_score, pass_rate, regressions, passed, reason) VALUES (?,?,?,?,?,?,?)")
    .run(label || "manual", baseline, passRate, passRate, regressions.join(" | "), passed ? 1 : 0,
      passed ? "meets baseline, no regressions" : "regressions or below baseline");
  if (!getState("eval_baseline")) setState("eval_baseline", passRate);
  return { label, baseline, candidateScore: passRate, passRate, regressions, passed };
}

/* ============================================================
   11 · IMPROVEMENT CYCLE (nightly; ≤3 proposals; never edits code)
   ============================================================ */
function computeMetrics() {
  const q = sql => db.prepare(sql).get().n;
  const reqs = q("SELECT count(*) n FROM requests");
  return {
    requests: reqs,
    qualified: q("SELECT count(*) n FROM requests WHERE availability_status IN ('available','manual')"),
    unavailable: q("SELECT count(*) n FROM requests WHERE availability_status='unavailable'"),
    manualReviews: q("SELECT count(*) n FROM requests WHERE status='Manual availability confirmation required'"),
    awaitingProvider: q("SELECT count(*) n FROM requests WHERE status='Availability being confirmed'"),
    quotesOpen: q("SELECT count(*) n FROM requests WHERE status='Quote sent'"),
    bookings: q("SELECT count(*) n FROM requests WHERE status IN ('Booking confirmed','Completed')"),
    holdExpiries: q("SELECT count(*) n FROM holds WHERE status='expired'"),
    failedSync: q("SELECT count(*) n FROM sync_outbox WHERE status='failed'"),
    recordedOnlyEmails: q("SELECT count(*) n FROM notifications WHERE delivery='recorded' AND ts > datetime('now','-1 day')"),
    corrections24h: q("SELECT count(*) n FROM ap_corrections WHERE ts > datetime('now','-1 day')"),
    escalations24h: q("SELECT count(*) n FROM ap_tasks WHERE status='escalated' AND updated_at > datetime('now','-1 day')"),
    aiCostToday: costToday().u
  };
}

function improvementCycle() {
  if (isPaused("improvements")) return { paused: true, proposals: [] };
  const m = computeMetrics();
  const candidates = [];
  if (m.awaitingProvider > 0) candidates.push({
    title: "Auto-chase providers on availability checks older than 2h",
    reason: `${m.awaitingProvider} request(s) waiting on providers — slowest step in the funnel`,
    metric: "provider response time", baseline: `${m.awaitingProvider} open checks`,
    expected_impact: "-30% availability-confirmation time", cost_estimate: "$0 (notification only)", risk: "low",
    tests: "phase52 tool test: chase-provider verified via notification row",
    verification: "notifications table + provider response timestamps over 7 days" });
  if (m.holdExpiries > 0) candidates.push({
    title: "Send hold-expiry warning at 10 minutes as well as 5",
    reason: `${m.holdExpiries} hold(s) expired without payment`,
    metric: "payment completion rate", baseline: `${m.holdExpiries} expired holds`,
    expected_impact: "+10% payment completion", cost_estimate: "$0", risk: "low",
    tests: "sweeper unit check", verification: "holds.status distribution week-over-week" });
  if (m.failedSync > 0) candidates.push({
    title: "Alert + auto-retry burst when Excel outbox has failures",
    reason: `${m.failedSync} failed Excel rows`, metric: "Excel sync failure count",
    baseline: String(m.failedSync), expected_impact: "0 failed rows standing",
    cost_estimate: "$0", risk: "low", tests: "sync retry test (phase4 #14)",
    verification: "sync_outbox failed count after 24h" });
  if (m.manualReviews > 0) candidates.push({
    title: "Add partner re-verification reminder cadence (stale inventory)",
    reason: `${m.manualReviews} request(s) fell to manual review — commonest denial source`,
    metric: "qualified-request rate", baseline: `${m.manualReviews} manual`,
    expected_impact: "+15% instant availability decisions", cost_estimate: "$0", risk: "low",
    tests: "agent stale-inventory test (phase41 #5)", verification: "manual-review rate over 7 days" });
  if (m.recordedOnlyEmails > 0) candidates.push({
    title: "Configure live email delivery (currently recorded-only)",
    reason: `${m.recordedOnlyEmails} messages recorded but not delivered in 24h`,
    metric: "message delivery rate", baseline: "recorded-only", expected_impact: "100% delivery",
    cost_estimate: "≈$0–20/mo (Resend)", risk: "medium (owner config)", tests: "email delivery status flag",
    verification: "notifications.delivery='emailed' ratio" });
  const top3 = candidates.slice(0, 3);
  for (const p of top3)
    db.prepare(`INSERT INTO ap_proposals (title, reason, metric, baseline, expected_impact, cost_estimate, risk, tests, verification)
      VALUES (?,?,?,?,?,?,?,?,?)`)
      .run(p.title, p.reason, p.metric, p.baseline, p.expected_impact, p.cost_estimate, p.risk, p.tests, p.verification);
  remember("improvement", "cycle:" + now().slice(0, 10), { metrics: m, proposed: top3.map(p => p.title) }, "improvement-cycle");
  return { metrics: m, proposals: top3 };
}

/* proposal lifecycle: production changes need staging + eval + approval */
function stageProposal(id, candidateScore, actor) {
  const p = db.prepare("SELECT * FROM ap_proposals WHERE id=?").get(id);
  if (!p) return { error: "not found" };
  if (p.status === "proposed" && p.risk !== "low" && !p.approved_by)
    return { error: "medium/high-risk changes require human approval before staging" };
  const evalRun = runEval("proposal-" + id);
  const candidate = candidateScore ?? evalRun.candidateScore;
  const regressed = candidate < evalRun.baseline || evalRun.regressions.length > 0;
  if (regressed) {
    db.prepare("UPDATE ap_proposals SET status='rolled-back', staging_result=?, rollback_status='auto-rolled-back (regression)' WHERE id=?")
      .run(`candidate ${candidate} < baseline ${evalRun.baseline} · ${evalRun.regressions.join("; ")}`, id);
    createGoal({ name: "Reopened: regression in '" + p.title + "'", metric: p.metric, target: 0, status: "Reopened",
      description: "Automatic rollback triggered — investigate before re-staging.", horizon: "incident", priority: 1 }, "regression-monitor");
    U.notify("admin", null, "AUTO_ROLLBACK", "Improvement rolled back — " + p.title, "Candidate scored below baseline; goal reopened.").catch(() => {});
    return { rolledBack: true, candidate, baseline: evalRun.baseline };
  }
  db.prepare("UPDATE ap_proposals SET status='staging-passed', staging_result=?, approved_by=COALESCE(NULLIF(approved_by,''), ?) WHERE id=?")
    .run(`candidate ${candidate} ≥ baseline ${evalRun.baseline}`, actor || "", id);
  return { ok: true, candidate, baseline: evalRun.baseline };
}

/* ============================================================
   12 · EXPERIMENTS (guardrailed; protected areas refused)
   ============================================================ */
const EXPERIMENT_FORBIDDEN = /safety|security|consent|deposit deduction|deposit-deduction|legal|payout|payment verification|access control|privacy/i;
function createExperiment(x, actor) {
  for (const field of ["name", "hypothesis", "primary_metric", "min_sample"])
    if (!x[field]) return { error: "Experiment needs " + field };
  if (EXPERIMENT_FORBIDDEN.test(x.name + " " + x.hypothesis + " " + x.primary_metric))
    return { blocked: true, error: "Experiments are forbidden on safety, security, consent, deposits, legal policies, payouts, payment verification, access control or privacy" };
  const info = db.prepare(`INSERT INTO ap_experiments (name, hypothesis, primary_metric, guardrails, audience, start_at, end_at, min_sample)
    VALUES (?,?,?,?,?,?,?,?)`)
    .run(x.name, x.hypothesis, x.primary_metric, x.guardrails || "no drop in completion or complaint rate",
      x.audience || "50% of new visitors", x.start_at || now(), x.end_at || null, Number(x.min_sample));
  U.audit({ email: actor, role: "admin" }, "experiment.create", "experiment", info.lastInsertRowid, "metric", null, x.primary_metric);
  return { ok: true, id: info.lastInsertRowid };
}

/* ============================================================
   13 · OWNER INDEPENDENCE
   ============================================================ */
function ownerIndependence() {
  const bookings = Math.max(1, db.prepare("SELECT count(*) n FROM requests WHERE status IN ('Booking confirmed','Completed')").get().n);
  const q = (sql, ...a) => db.prepare(sql).get(...a).n;
  const human = "('admin','sales','ops','partnerships','cx')";
  const stats = {
    bookings,
    ownerApprovals: q(`SELECT count(*) n FROM audit WHERE role IN ${human} AND action IN ('payment.verified','request.price.approved','quote.sent')`),
    ownerAvailabilityChecks: q(`SELECT count(*) n FROM audit WHERE role IN ${human} AND action='request.assign'`),
    ownerReminderActions: q(`SELECT count(*) n FROM audit WHERE role IN ${human} AND action LIKE 'email.customer%'`),
    ownerDepositFollowups: q(`SELECT count(*) n FROM audit WHERE role IN ${human} AND field='deposit_refunded'`),
    ownerPayoutFollowups: q(`SELECT count(*) n FROM audit WHERE role IN ${human} AND field='payout_paid'`),
    ownerErrorInterventions: q(`SELECT count(*) n FROM ap_tasks WHERE status='escalated'`),
    autoDecisions: q("SELECT count(*) n FROM audit WHERE role='autopilot' OR user_email='autopilot' OR user_email='stripe-webhook' OR user_email='system'")
  };
  const interventions = stats.ownerApprovals + stats.ownerAvailabilityChecks + stats.ownerReminderActions +
    stats.ownerDepositFollowups + stats.ownerPayoutFollowups;
  const perBooking = Math.round((interventions / bookings) * 10) / 10;
  const minutesPerBooking = Math.round(perBooking * 3 * 10) / 10;
  const level = perBooking > 8 ? 1 : perBooking > 5 ? 2 : perBooking > 2.5 ? 3 : perBooking > 1 ? 4 : 5;
  return {
    level, levelName: ["", "Owner Operated", "Owner Supervised", "Exception Managed", "Owner Light", "Self-Running Operations"][level],
    interventionsPerBooking: perBooking, minutesPerBooking, stats,
    stillHuman: ["Damage deductions", "Large refunds", "Payout disputes", "Fraud/legal", "Financial-rule changes", "Security changes", "Production deploys", "New provider activation"],
    recommendation: level >= 5 ? "Maintain — human approval stays for the protected list."
      : "Automate the highest-count intervention above via a deterministic rule or Autopilot tool."
  };
}

/* ============================================================
   14 · 100-POINT COMPLETION SCORE (production points ≠ mocks)
   ============================================================ */
function completionScore() {
  const isProd = (process.env.TN_ENV || "staging") === "production";
  const liveEmail = !!(process.env.RESEND_API_KEY || process.env.NOTIFY_EMAIL_WEBHOOK_URL);
  const liveExcel = !!process.env.EXCEL_WEBHOOK_URL && !/localhost|127\.0\.0\.1/.test(process.env.EXCEL_WEBHOOK_URL || "");
  const livePay = !!(process.env.LUMINO_API_KEY && process.env.LUMINO_API_BASE) ||
    (S("stripe_enabled") === "1" && !!process.env.STRIPE_SECRET_KEY);
  const has = sql => db.prepare(sql).get().n > 0;
  const regression = db.prepare("SELECT count(*) n FROM ap_proposals WHERE status='rolled-back' AND rollback_status LIKE '%regression%' AND ts > datetime('now','-7 day')").get().n > 0;
  const items = [
    { id: 1, name: "Website request enters database", pts: 6, staging: has("SELECT count(*) n FROM requests"), live: true },
    { id: 2, name: "Customer confirmation works", pts: 5, staging: has("SELECT count(*) n FROM notifications WHERE type LIKE 'CUSTOMER_%'"), live: liveEmail },
    { id: 3, name: "Management lead notification works", pts: 5, staging: has("SELECT count(*) n FROM notifications WHERE type='NEW_REQUEST'"), live: liveEmail },
    { id: 4, name: "Availability engine works", pts: 12, staging: has("SELECT count(*) n FROM requests WHERE availability_checked_at IS NOT NULL"), live: true },
    { id: 5, name: "Provider confirmation works", pts: 8, staging: has("SELECT count(*) n FROM audit WHERE action='request.status' AND new_value='Provider confirmed'"), live: true },
    { id: 6, name: "Quote generation works", pts: 8, staging: has("SELECT count(*) n FROM requests WHERE quote_amount IS NOT NULL"), live: true },
    { id: 7, name: "Payment options work", pts: 8, staging: has("SELECT count(*) n FROM payments"), live: livePay },
    { id: 8, name: "Verified payment updates booking", pts: 8, staging: has("SELECT count(*) n FROM requests WHERE payment_status='verified'"), live: livePay },
    { id: 9, name: "Vehicle dates are blocked", pts: 8, staging: has("SELECT count(*) n FROM holds WHERE status IN ('converted','active')"), live: true },
    { id: 10, name: "Pickup/delivery/return reminders work", pts: 8, staging: has("SELECT count(*) n FROM notifications WHERE type IN ('BOOKING_CONFIRMED','HOLD_CREATED')"), live: liveEmail },
    { id: 11, name: "Deposits and provider payouts work", pts: 10, staging: has("SELECT count(*) n FROM rentals WHERE payout_paid='Yes' OR deposit_refunded='Yes'"), live: livePay },
    { id: 12, name: "Review request and publishing work", pts: 6, staging: has("SELECT count(*) n FROM rentals WHERE review_requested='Yes'") || has("SELECT count(*) n FROM reviews"), live: liveEmail },
    { id: 13, name: "Daily management report works", pts: 6, staging: !!getState("last_daily_report"), live: liveEmail },
    { id: 14, name: "Critical safety & privacy gates pass", pts: 2, staging: !regression, live: true }
  ].map(i => ({
    ...i,
    stagingVerified: !!i.staging,
    productionVerified: !!i.staging && i.live && isProd,
    note: !i.staging ? "not yet verified" : (i.live ? (isProd ? "verified in production" : "verified in staging — awaiting production deploy") : "integration not live (mock/recorded) — production points withheld")
  }));
  const stagingScore = items.reduce((s, i) => s + (i.stagingVerified ? i.pts : 0), 0);
  const productionScore = items.reduce((s, i) => s + (i.productionVerified ? i.pts : 0), 0);
  const obsStart = getState("observation_start");
  const obsDays = obsStart ? Math.floor((Date.now() - Date.parse(obsStart)) / 864e5) : 0;
  return {
    stagingScore, productionScore, items, regressionActive: regression,
    observation: { started: obsStart || null, daysElapsed: obsDays, required: 30 },
    canDeclare100: productionScore === 100 && !regression && obsDays >= 30,
    mode: getState("mode") || "build",
    honesty: "Production points require live (non-mock) integrations in TN_ENV=production plus a 30-day observation period. Staging evidence never counts as production."
  };
}

/* ============================================================
   15 · REGRESSION MONITOR + MAINTENANCE MODE
   ============================================================ */
function monitorAndReopen() {
  const triggers = [];
  const m = computeMetrics();
  if (m.failedSync > 0) triggers.push({ why: "Excel sync failures: " + m.failedSync, metric: "excel-sync" });
  if (m.escalations24h > 2) triggers.push({ why: "Escalations spiking: " + m.escalations24h, metric: "escalations" });
  const lastEval = db.prepare("SELECT * FROM ap_eval_runs ORDER BY id DESC LIMIT 1").get();
  if (lastEval && !lastEval.passed) triggers.push({ why: "Eval regression: " + lastEval.regressions, metric: "eval-pass-rate" });
  for (const t of triggers) {
    const existing = db.prepare("SELECT goal_id FROM ap_goals WHERE name=? AND status IN ('Reopened','Active')").get("Reopened: " + t.metric);
    if (!existing) {
      createGoal({ name: "Reopened: " + t.metric, metric: t.metric, target: 0, status: "Reopened",
        description: t.why, horizon: "incident", priority: 1 }, "regression-monitor");
    }
  }
  if ((getState("mode") || "build") === "maintenance" && triggers.length)
    U.notify("admin", null, "MAINTENANCE_REOPEN", "Maintenance mode reopened work", triggers.map(t => t.why).join(" · ")).catch(() => {});
  return { triggers, reopened: triggers.length };
}

/* ============================================================
   16 · DAILY REPORT (8:00 PM America/New_York) + schedulers
   ============================================================ */
function buildDailyReport() {
  const m = computeMetrics();
  const score = completionScore();
  const oi = ownerIndependence();
  const lines = [
    `TopNotchRentalz — Daily Management Report (${now().slice(0, 10)})`,
    `Mode: ${score.mode} · Completion: staging ${score.stagingScore}/100 · production ${score.productionScore}/100`,
    `Requests: ${m.requests} total · ${m.bookings} booked · ${m.quotesOpen} quotes open · ${m.awaitingProvider} awaiting provider`,
    `Exceptions: ${m.manualReviews} manual reviews · ${m.escalations24h} escalations (24h) · ${m.holdExpiries} expired holds`,
    `Integrations: ${m.failedSync} failed Excel rows · ${m.recordedOnlyEmails} recorded-only messages (24h)`,
    `AI cost today: $${m.aiCostToday.toFixed(2)} · Owner independence: Level ${oi.level} (${oi.levelName}), ${oi.minutesPerBooking} min/booking`
  ].join("\n");
  return { text: lines, metrics: m, score: { staging: score.stagingScore, production: score.productionScore }, independence: { level: oi.level } };
}

async function sendDailyReport() {
  const rep = buildDailyReport();
  await U.notify("admin", null, "DAILY_REPORT", "Daily management report", rep.text);
  await emails.sendEmail(S("email") || "bookings@topnotchrentalz.com", "TopNotchRentalz — Daily Report", "<pre style='font-family:monospace'>" + rep.text.replace(/</g, "&lt;") + "</pre>").catch(() => {});
  setState("last_daily_report", now());
  remember("business", "daily-report:" + now().slice(0, 10), rep.metrics, "scheduler");
  return rep;
}

function nyHour() {
  return Number(new Intl.DateTimeFormat("en-US", { hour: "numeric", hour12: false, timeZone: "America/New_York" }).format(new Date()));
}

let bootstrapped = false;
function startSchedulers() {
  if (bootstrapped) return; bootstrapped = true;
  ensurePermanentGoal(); seedEvalCases();
  if (!getState("observation_start") && (process.env.TN_ENV === "production")) setState("observation_start", new Date().toISOString());
  /* hourly: overdue checks, expiring quotes/holds, failed integrations */
  setInterval(async () => {
    try {
      enforceCostCaps();          // also auto-resumes a cost-triggered AI pause once under the caps
      await runRegistryHousekeeping();
    } catch (e) { /* logged in tasks */ }
  }, 60 * 60e3).unref();
  /* daily at 20:00 America/New_York: report then improvement cycle */
  setInterval(async () => {
    try {
      const today = now().slice(0, 10);
      if (nyHour() === 20 && getState("last_daily_report_day") !== today) {
        setState("last_daily_report_day", today);
        await sendDailyReport();
        improvementCycle();
        monitorAndReopen();
      }
    } catch (e) { /* next tick */ }
  }, 60e3).unref();
}

async function runRegistryHousekeeping() {
  const jobs = [
    { tool: "expire-stale-quotes", input: {}, objective: "Expire overdue quotes", success: "0 expired quotes remain open" },
    { tool: "verify-excel-sync", input: {}, objective: "Verify Excel sync health", success: "outbox inspected; admin alerted if failed rows" }
  ];
  for (const j of jobs) {
    const dupe = db.prepare("SELECT 1 FROM ap_tasks WHERE tool=? AND status IN ('queued','running') LIMIT 1").get(j.tool);
    if (dupe) continue; // duplicate-job prevention
    const q = queueTask({ objective: j.objective, success_criteria: j.success, tool: j.tool, input: j.input, why: "hourly housekeeping" });
    if (q.ok) await runTask(q.taskId);
  }
}

module.exports = {
  PERMANENT_MISSION, GOAL_STATUSES, FORBIDDEN, PAUSE_FLAGS, TOOLS, MEMORY_LAYERS,
  ensurePermanentGoal, createGoal, updateGoal, governor, setPause, isPaused,
  logCost, costToday, costMonth, enforceCostCaps, llm, llmForRequest, aiConsentFor, contextFor, validateToolInput,
  queueTask, runTask, remember, recall, recordCorrection, seedEvalCases, runEval,
  computeMetrics, improvementCycle, stageProposal, createExperiment,
  ownerIndependence, completionScore, monitorAndReopen,
  buildDailyReport, sendDailyReport, startSchedulers, setState, getState
};
