# Maintenance & Growth Mode

## Two modes (`ap_state.mode`, toggled in Admin → Autopilot)

- **build** (default): active development; the improvement cycle focuses on
  closing completion-score gaps.
- **maintenance**: the system is considered operational; the emphasis shifts
  to watching for regressions and growth experiments.

## What maintenance mode does NOT change

Schedulers, tools, evaluations, cost caps, the daily report and all safety
gates run identically in both modes. Maintenance is a posture, not an
off-switch.

## Reopening work automatically (test 24)

`monitorAndReopen()` runs after every daily report and can be triggered any
time. It reopens a **priority-1 incident goal** (status `Reopened`) when:
- Excel sync has failed rows,
- escalations spike (>2 in 24h),
- the latest evaluation run failed (regression).

Duplicate incident goals are prevented; in maintenance mode the admin
additionally gets a `MAINTENANCE_REOPEN` notification so reopened work is
never silent.

## Exit criteria for an incident goal

The reopened goal closes through the normal goal lifecycle once the metric
is back to target (e.g. 0 failed sync rows) — with evidence, like every
other goal.
