# TopNotch Autopilot — Architecture

A **Karpathy-INSPIRED** (not official — see `VIDEO-INSIGHTS.md`) continuous-
improvement operating system layered on top of the existing deterministic
booking backend. Zero new dependencies; everything lives in
`lib/autopilot.js` + routes in `server.js` + seven admin pages.

## The permanent loop

```
Observe → Retrieve relevant context → Define measurable goal
→ Plan the smallest safe action → Use validated tools
→ Verify with EXTERNAL evidence → Critique → Record the lesson
→ Escalate when blocked → Repeat until verified completion
→ Maintenance & Growth Mode → Reopen whenever performance regresses
```

## The 20 components and where they live (all in `lib/autopilot.js` unless noted)

| # | Component | Implementation |
|---|---|---|
| 1 | Goal Manager | `ensurePermanentGoal` / `createGoal` / `updateGoal` — goals require name+metric+target; permanent goal immutable |
| 2 | Context Manager | `contextFor(task)` — only the task's own request/vehicle/provider + policies + last 3 failures + SOP. Never full tables, never other customers |
| 3 | Planner | `queueTask` — smallest safe action, one registry tool, max 3 active tasks per goal |
| 4 | Tool Executor | `TOOLS` registry + `validateToolInput` — typed inputs, unknown tools refused |
| 5 | Workflow Engine | `runTask` — execute → verify → critique → persist `reasoning_summary` |
| 6 | Rules Engine | deterministic checks inside every tool + the existing server status machine |
| 7 | Evaluation Engine | `seedEvalCases` / `runEval` — deterministic scoring vs baseline |
| 8 | Critic | the `verify()` step of every tool: external DB/notification evidence only; self-report is never accepted |
| 9 | Memory Manager | `remember` / `recall` over 6 layers (`MEMORY_LAYERS`) |
| 10 | Scheduler | `startSchedulers` — hourly housekeeping; daily 8:00 PM America/New_York report → improvement cycle → monitor |
| 11 | Event Queue | `ap_tasks` table (queued/running/verified/failed/escalated) |
| 12 | Retry Manager | `runTask` attempt counter — hard limit 3, then `escalateTask` |
| 13 | Safety Governor | `governor` + `FORBIDDEN` list — blocks & audits |
| 14 | Cost Controller | `logCost` / `enforceCostCaps` — daily & monthly caps pause AI |
| 15 | Human Approval Manager | proposal `approved_by` gate; medium/high-risk cannot stage without a human |
| 16 | Improvement Backlog | `ap_proposals` + Admin → Improvement Backlog |
| 17 | Experiment Manager | `createExperiment` + `EXPERIMENT_FORBIDDEN` guardrails |
| 18 | Regression Monitor | `monitorAndReopen` + auto-rollback in `stageProposal` |
| 19 | Daily Report Generator | `buildDailyReport` / `sendDailyReport` |
| 20 | Owner Dashboard | Admin pages: Autopilot, Goals, Improvement Backlog, Evaluations, Owner Independence, Experiments, Memory |

## Deterministic code vs AI

- **Deterministic (always):** availability decisions, holds, payments,
  payment verification, booking confirmation, reminders, Excel sync, audit,
  every registry tool, every safety gate.
- **AI (optional garnish):** summaries and drafts via `llm()` — used only if
  `OPENAI_MODEL` **and** `OPENAI_API_KEY` are set; the model id is never
  guessed. Any AI failure/pause falls back to deterministic output.
  Test 19 proves the system runs fully with AI off.

## Data model (10 tables, additive only)

`ap_state`, `ap_goals`, `ap_tasks`, `ap_memory`, `ap_corrections`,
`ap_eval_cases`, `ap_eval_runs`, `ap_proposals`, `ap_experiments`,
`ap_cost_log`. No existing table was modified.

## Transparency

The server stores and exposes only `reasoning_summary` — a one-line
Checked/Decision/Evidence/Next record per task. Chain-of-thought is neither
stored nor transmitted.
