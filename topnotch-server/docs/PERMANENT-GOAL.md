# Permanent Goal

## The mission (verbatim, stored as goal `G-MISSION`)

> Continuously increase the percentage of qualified rental requests that
> become profitable, compliant, five-star completed rentals while reducing
> response time, mistakes, unnecessary operating costs, and owner
> involvement. Never sacrifice customer safety, privacy, legal compliance,
> provider approval, payment verification, financial controls, or service
> quality to improve a metric.

## Why it can't be edited at runtime

`updateGoal()` checks `permanent=1` **before** any field is touched and
returns `blocked` — for the agent *and* for admins. Every attempt is written
to the audit log as `autopilot.blocked`. Changing the mission requires a code
change + review + deploy (see `SECURITY-BOUNDARIES.md`). Verified by test 10.

## How every other goal hangs off it

- Goals must be measurable (`name` + `metric` + `target` or they're refused — test 1's task analog).
- Statuses: Proposed → Approved → Active → (Blocked / Awaiting human) →
  Testing → Completed / Failed → Reopened → Monitoring.
- The regression monitor reopens goals automatically (tests 15 & 24), so
  "done" is never final if the metric slips.

## Metric definition

Primary: **qualified-request → five-star completed rental %**, where
"qualified" means the availability agent returned `available` or `manual`
(i.e. a real, eligible lead). Supporting metrics tracked in
`computeMetrics()`: response time proxies (awaiting-provider count), mistake
proxies (corrections, escalations), cost (`ap_cost_log`), owner involvement
(`ownerIndependence()`).
