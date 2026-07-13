# Continuous Improvement

## Nightly cycle (after the 8:00 PM America/New_York daily report)

`improvementCycle()`:
1. Computes real funnel metrics (`computeMetrics()`).
2. Derives candidate improvements from observed friction (slow provider
   confirmations, expired holds, failed Excel rows, manual-review rate,
   recorded-only emails).
3. Writes **at most 3** proposals per run (test 20), each with: title,
   reason (with the observed numbers), metric, baseline, expected impact,
   cost estimate, risk level, tests, and verification plan (test 21).

## What the cycle can NEVER do

- Edit production code, prompts, schema, permissions or settings.
- Auto-apply anything. Proposals sit in the Improvement Backlog until:
  - **low risk** → may be staged, where an evaluation run must meet the
    baseline with zero regressions (test 14);
  - **medium/high risk** → requires explicit human approval before staging.
- Survive a regression: a failing candidate is auto-rolled-back, the goal is
  reopened at priority 1, and the admin is notified (test 15).

## Pausing

Admin → Autopilot → "Pause improvements" stops the cycle immediately
(`isPaused("improvements")`); queued proposals are kept, not deleted.

## Experiments (growth side)

`createExperiment` requires name, hypothesis, primary metric and minimum
sample size; guardrails default to "no drop in completion or complaint
rate". The server **refuses** experiments touching safety, security,
consent, deposits, legal policies, payouts, payment verification, access
control or privacy (test 22). Results are recorded as numbers with an
explicit adopt / revert / iterate decision.
