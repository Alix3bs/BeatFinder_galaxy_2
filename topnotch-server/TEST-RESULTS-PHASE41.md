# Phase 4.1 — Test Results (Lumino adapter · AI agent · holds · payment methods)

Run: 2026-07-13T06:12:43.105Z · fresh staging DB · provider backend: mock (Lumino adapter awaiting merchant credentials)

| # | Scenario | Result | Detail |
|---|----------|--------|--------|
| 1 | Customer cannot pay before requesting/approval | ✅ PASS | 404 unknown · 409 unapproved |
| 2 | Request saved + agent ran | ✅ PASS | availability=available |
| 3 | AI finds vehicle available | ✅ PASS | unit V-1001 |
| 4 | AI finds overlapping dates | ✅ PASS | F8 07/05–07/08 → unavailable |
| 5 | AI detects stale inventory → manual confirmation + team notified | ✅ PASS |  |
| 6 | Provider confirms availability | ✅ PASS |  |
| 8 | Temporary hold created + customer sees countdown & full breakdown | ✅ PASS | expires 06:32 |
| 7 | Provider declines availability | ✅ PASS |  |
| 9 | Second customer cannot pay for the held vehicle | ✅ PASS | agent avoided it; manual assign 409 |
| 10 | Payment popup shows only enabled methods | ✅ PASS | card, link, invoice, bank, cash |
| 11 | Hosted payment link created via provider adapter | ✅ PASS | mock |
| 12 | Invalid webhook is rejected | ✅ PASS |  |
| 13 | Duplicate webhook is ignored | ✅ PASS | evt_p41_1 processed once |
| 14 | Successful payment confirms the booking | ✅ PASS | hold converted → AR-260713-423197 |
| 15 | Failed payment does not confirm the booking | ✅ PASS | hold stays active until expiry |
| 16 | Expired hold blocks payment → availability re-run + provider reconfirm | ✅ PASS |  |
| 17 | Manual payment requires admin verification | ✅ PASS | sales 403 → admin confirms |
| 18 | Unavailable vehicle displays alternatives + one-tap switch | ✅ PASS | 2023 Mercedes-AMG G63 AMG |
| 19 | Database and Excel update correctly | ✅ PASS | 64 rows · tables: CustomerRequests, PartnerInventory, Payments, ActiveRentals |
| 20 | Customer never receives provider cost or profit details | ✅ PASS | all public payloads scanned clean |

**20/20 passed.**