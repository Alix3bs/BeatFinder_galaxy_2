# Owner Independence

Measured from **real audit rows**, not estimates (`ownerIndependence()`,
Admin → Owner Independence, test 17).

## What's counted per booking

Owner/staff approvals (payment verification, price approval, quote send),
manual availability assignments, manual reminder emails, deposit and payout
follow-ups. Escalations are tracked separately as error interventions.
`interventionsPerBooking = human actions ÷ confirmed bookings`;
`minutesPerBooking` estimates ~3 min per action.

## Levels

| Level | Name | Interventions/booking |
|---|---|---|
| 1 | Owner Operated | > 8 |
| 2 | Owner Supervised | > 5 |
| 3 | Exception Managed | > 2.5 |
| 4 | Owner Light | > 1 |
| 5 | Self-Running Operations | ≤ 1 |

**Target: Level 5** — the business runs on deterministic workflows +
Autopilot tools, and humans handle only the protected list below.

## Deliberately NEVER automated (protected list)

Damage deductions · Large refunds · Payout disputes · Fraud/legal ·
Financial-rule changes · Security changes · Production deploys ·
New provider activation.

Reaching Level 5 does **not** remove these; the dashboard says "Maintain"
rather than proposing further automation of them.

## How the score improves

The dashboard's recommendation points at the highest-count human
intervention; the improvement cycle can then propose a deterministic rule or
registry tool for it — through the normal eval + approval gate, never by
silently removing a human checkpoint.
