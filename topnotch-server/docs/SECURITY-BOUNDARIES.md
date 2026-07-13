# Security & Autonomy Boundaries

## Hard-forbidden actions (Safety Governor, tests 10–13)

The agent may NEVER, through any runtime path: edit the permanent goal,
remove safety or cost limits, change permissions, reveal secrets, create
users, deploy to production, modify the DB schema, delete records to improve
metrics, manipulate reports, fabricate test results, mark a mock as live,
send money, auto-deduct deposits, approve insurance, activate a payment
provider, or ignore a security warning.

`governor(action)` blocks these, writes an `autopilot.blocked` audit row,
and escalates. The list is code (`FORBIDDEN` in `lib/autopilot.js`) — the
agent has no tool that can modify code, so it cannot edit its own limits.

## Changing a boundary requires the human process

code change → review → tests → deploy. There is deliberately **no** admin
screen, setting, API route or agent tool that can alter the mission, the
forbidden list, role permissions, or cost-cap enforcement logic.

## What the agent can do autonomously

Only the validated registry tools (see `AGENT-TOOLS.md`): re-check
availability, chase providers, expire stale quotes, verify Excel sync, send
approved follow-up templates — each verified against external evidence and
capped at 3 attempts.

## Emergency controls (Admin → Autopilot)

Pause independently: AI · customer messages · provider messages ·
improvements. Pausing is instant, never deletes queued work, and never
disables deterministic safety flows (payment verification, booking gates,
consent, audit). Test 19 proves deterministic continuity under AI pause.

## Transparency rules

- Admin pages receive **concise reasoning summaries only**
  (Checked / Decision / Evidence / Next) — chain-of-thought is never stored
  or transmitted.
- Secrets stay in env vars; APIs expose configured/missing flags, never values.
- Every autonomous action, block and escalation is in the audit log.

## Existing protections still in force (Phases 3–4.1)

scrypt auth + 6 roles, server-side permission guards on every route,
role-filtered fields, signed webhooks + idempotency, encrypted backups,
consent versioning, rate limiting, no private data in any frontend file
(e2e scenario coverage).
