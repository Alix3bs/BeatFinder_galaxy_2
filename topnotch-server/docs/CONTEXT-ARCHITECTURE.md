# Context Architecture

## Principle

The agent never sees "everything". `contextFor(task)` assembles the minimum
context a task needs, freshly, from the live database:

| Slice | Contents | Condition |
|---|---|---|
| `request` | id, status, vehicle, dates, availability, payment status | only the task's own `requestId` |
| `vehicle` | id, make/model, partner, status, last_verified | only if assigned to that request |
| `provider` | partner id, company, onboarding status | only the vehicle's own provider |
| `policies` | verify_days, hold_minutes, policy_version | always |
| `recentFailures` | last 3 failures of the SAME tool (objective + trimmed error) | always |
| `sop` | stored SOP memory for this tool, if any | always |

## What is deliberately excluded

- Full table dumps of any kind.
- Other customers' requests, names, emails, phones (verified by test 2 —
  the context JSON is asserted to contain no other customer's data and no
  contact PII at all).
- Secrets/credentials — they live in env vars the context builder never reads.
- Provider economics beyond what the tool itself queries server-side.

## Why

1. **Privacy:** a compromised or confused agent step can't leak what it never
   received.
2. **Quality:** small, relevant context beats a giant prompt — decisions are
   deterministic where possible and reviewable everywhere.
3. **Cost:** the optional LLM sees ≤6,000 chars (`llm()` truncates), keeping
   token spend bounded.
