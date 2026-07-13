# Evaluation System

## Dataset

Seeded cases (`seedEvalCases`) cover: successful booking, overlapping dates,
age failure, insurance failure, deposit failure, missing info, an adversarial
privacy probe (no internal fields in public payloads), and an
unauthorized-access probe. Every **human correction** logged in Admin →
Evaluations adds a permanent case tagged `human-correction` (test 9).

## Scoring (`runEval`)

Deterministic: availability cases are replayed through the real
`agent.checkAvailability`; privacy probes scan real public-facing data.
Pass rate is compared to the stored baseline; any individual expectation miss
is a named **regression**. A run passes only with `score ≥ baseline` AND
zero regressions.

## Gate for changes

`stageProposal` runs an eval before any proposal advances:
- pass → `staging-passed` (test 14)
- regression → automatic `rolled-back`, a priority-1 **Reopened** goal, and
  an admin notification (test 15).

Medium/high-risk proposals additionally require a human `approved_by` before
they may even be staged.

## Self-correction policy

A correction **never rewrites a prompt automatically**. It becomes an eval
case + a workflow-memory lesson; behavior changes only through the normal
proposal → eval → approval pipeline. This is deliberate: silent prompt
mutation is how agent systems drift.

## Real bug caught by this system during Phase 5.2

The seeded "no insurance" case exposed that `agent.js` used a substring
match `/confirmed/i`, which wrongly accepted the site's literal
`"Not confirmed"` value — an uninsured customer would have passed the
insurance check. Fixed to an anchored `/^confirmed/i` (see the comment in
`lib/agent.js`), after which the eval baseline reached 100%. This is the
evaluation loop doing exactly its job.
