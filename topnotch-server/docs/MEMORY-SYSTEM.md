# Memory System

Six layers in `ap_memory` (`remember(layer, key, value, source)` /
`recall(layer, like, limit)`), each entry ≤4 KB, viewable in Admin → Memory.

| Layer | What goes in | Examples written today |
|---|---|---|
| `business` | metrics snapshots, daily reports | `daily-report:2026-07-13` |
| `customer` | per-customer preferences/lessons (keyed per customer, never mixed) | repeat-renter notes |
| `provider` | provider behavior (response speed, reliability) | chase outcomes |
| `workflow` | successes, failures, escalations, corrections, SOPs per tool | `failure:chase-provider`, `sop:recheck-availability` |
| `engineering` | technical lessons (sync failures, timeouts) | outbox retry patterns |
| `improvement` | each improvement cycle's metrics + proposals | `cycle:2026-07-13` |

## Rules

1. **No cross-pollination:** memory keys are namespaced; the Context Manager
   only pulls the SOP for the current tool and failures of the same tool —
   never another customer's entries (test 2).
2. **Compact lessons, not transcripts:** values are truncated JSON facts.
3. **Write-on-event:** the task runner records `success:*` / `failure:*` /
   `escalation:*` automatically; corrections write `correction:*`;
   schedulers write reports and cycles. Humans never need to curate it.
4. **Read path:** `recall()` is newest-first with a LIMIT — memory can only
   inform, never flood, a task's context.
