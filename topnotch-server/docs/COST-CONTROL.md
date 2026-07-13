# Cost Control

## Configuration

| Item | Where | Default |
|---|---|---|
| Model + API key + base URL | env only: `OPENAI_MODEL`, `OPENAI_API_KEY`, `OPENAI_API_BASE` | unset → AI disabled, deterministic fallback |
| Daily cap (USD) | Admin → Settings `ai_daily_cost_cap` | $25 |
| Monthly cap (USD) | Admin → Settings `ai_monthly_cost_cap` | $300 |

The model id is **never guessed**: if `OPENAI_MODEL` is unset, `llm()`
returns a disabled-fallback result. If the owner's provider lists a model
(e.g. GPT-5.6 Sol), its exact id goes in the env var after verifying it in
the provider dashboard.

## Metering

Every LLM call logs tokens + estimated USD to `ap_cost_log` via `logCost()`,
tagged by purpose/workflow. Admin → Autopilot shows today's and 30-day spend
against the caps.

## Enforcement (`enforceCostCaps`, test 18)

Reaching either cap:
1. sets `pause_ai=1` with reason "cost cap reached",
2. notifies the admin,
3. every subsequent `llm()` call returns the deterministic fallback.

**What keeps running when AI is paused (test 19):** availability decisions,
holds, payments and payment verification, booking confirmation, reminders,
Excel sync, all registry tools, all safety gates — none of them use the LLM.

**What pauses:** optional summaries/drafts and AI-assisted parts of the
improvement cycle.

## Un-pausing

Automatic — the hourly scheduler re-checks the caps and clears a
cost-triggered pause once spend is back under both caps (a manual admin
pause is never overridden) — or manually via
Admin → Autopilot → Resume AI (which clears the pause reason).
The agent itself cannot raise or remove caps — `remove-cost-limits` is a
governor-forbidden action (test 11).
