# Agent Tools (validated registry)

The agent can act ONLY through this registry (`TOOLS` in `lib/autopilot.js`).
Unknown tools and mistyped inputs are refused before queueing (tests 3–4).
Every tool has three parts: typed `input`, deterministic `execute()`, and a
`verify()` that reads **external evidence** (database rows / notification
records) — never the tool's own return value (tests 5–6).

| Tool | Input | What it does | Verification evidence |
|---|---|---|---|
| `recheck-availability` | `requestId` | Re-runs the deterministic availability agent and stores the decision | fresh `availability_checked_at` + status on the request row |
| `chase-provider` | `requestId` | Sends the provider a reminder for an open availability check | an `AVAILABILITY_REMINDER` notification row < 5 min old |
| `expire-stale-quotes` | — | Returns overdue quotes to Under review, audited per request | zero expired-but-open quotes remaining in the DB |
| `verify-excel-sync` | — | Inspects the outbox; alerts admin if failures exist | outbox inspected timestamp (+ alert row when failed > 0) |
| `send-followup` | `requestId`, `template` | Sends ONE of the approved follow-up templates (QUOTE_EXPIRING / AVAILABILITY_CHECK / HOLD_EXPIRING) | the `CUSTOMER_*` notification/delivery record |

## Boundaries baked into the tools

- `chase-provider` refuses when `provider_messages` is paused;
  `send-followup` refuses when `customer_messages` is paused.
- `send-followup` refuses any template not on the approved list — the agent
  cannot compose arbitrary customer messages.
- No tool touches payments, permissions, schema, code, or settings. Those are
  governor-forbidden actions (`FORBIDDEN`), tested in tests 11–13.

## Failure behavior

`runTask` allows at most **3 attempts**; each failure stores the error, a
one-line reasoning summary, and a workflow-memory lesson; the third failure
escalates to ops with a recommendation (tests 7–8). Escalated tasks do not
silently re-run.
