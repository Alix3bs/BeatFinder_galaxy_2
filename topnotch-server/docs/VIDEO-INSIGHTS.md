# Video Insights — Honest Analysis Record

## The two supplied videos

1. https://youtu.be/p77of4jhHkE
2. https://youtu.be/4JpwNnw0-jI

## What actually happened (full transparency, per the project's honesty rule)

**The transcripts could NOT be retrieved.** This build environment routes all
outbound traffic through a restricted proxy, and every retrieval path failed:

| Attempt | Result |
|---|---|
| `https://www.youtube.com/watch?v=p77of4jhHkE` | connection refused by proxy (HTTP 000) |
| `https://youtu.be/4JpwNnw0-jI` | connection refused by proxy (HTTP 000) |
| `https://www.youtube.com/api/timedtext?v=p77of4jhHkE&lang=en` (official captions) | connection refused by proxy (HTTP 000) |
| `https://www.googleapis.com/youtube/v3/captions?videoId=p77of4jhHkE` (Data API) | HTTP 403 (blocked / no key) |
| `https://youtubetranscript.com` (third-party transcript mirror) | connection refused by proxy (HTTP 000) |

The project rules for this phase are explicit:

> *Never claim video analysis without retrieving real transcript data.
> Never invent quotes or timestamps. Document retrieval limitations honestly.*

Therefore this document contains **zero quotes, zero timestamps, and zero
claims about what is said in either video**. Any such content would be
fabricated.

## What the Autopilot design is actually based on

Since the two specific videos were unreachable, the implementation is based on:

1. **The requirements in the Phase 5.2 specification itself**, which describe
   the desired operating loop in detail (Observe → Retrieve → Define goal →
   Plan → Act → Verify → Critique → Learn → Repeat, layered memory,
   deterministic-code-vs-AI split, evaluations, guardrails).
2. **Widely published ideas associated with Andrej Karpathy's public talks and
   writing** (e.g. "Software 2.0", LLM OS sketches, agent-loop discussions)
   as they existed in this assistant's general training knowledge — *not* from
   the two supplied videos.

For that reason the system is described everywhere as
**"Karpathy-INSPIRED"** — an original operating approach influenced by
publicly known themes — and **never** as "Karpathy's official framework",
which would be a false claim.

## Idea log (sources labeled honestly)

| Idea implemented | Source | Where it lives |
|---|---|---|
| Agent loop with explicit verify step using *external* evidence, never self-report | Phase 5.2 spec | `lib/autopilot.js → runTask()` — a task passes only when its tool's `verify()` finds DB/notification evidence |
| Hard 3-attempt limit, then human escalation | Phase 5.2 spec | `runTask()` / `escalateTask()` |
| Deterministic code for sensitive actions; LLM only for summaries/drafts | Phase 5.2 spec + general "code where possible" engineering principle | `llm()` is optional garnish; payments/bookings never call it |
| Small, relevant context per task instead of dumping tables | Phase 5.2 spec | `contextFor()` |
| Every human correction becomes a permanent eval case | Phase 5.2 spec | `recordCorrection()` |
| Nightly improvement cycle capped at 3 proposals, never auto-edits production | Phase 5.2 spec | `improvementCycle()` |
| Layered memory (business/customer/provider/workflow/engineering/improvement) | Phase 5.2 spec | `remember()` / `recall()` |
| Safety governor with a hard-coded forbidden-action list | Phase 5.2 spec | `governor()` + `FORBIDDEN` |

## What to do when the videos become reachable

If this project is later run in an environment with YouTube access, re-run the
retrieval (captions via `timedtext`, description via the watch page or Data
API), then update this file with genuinely sourced ideas — each with video ID,
timestamp, and the actual point made — and reconcile the table above.
