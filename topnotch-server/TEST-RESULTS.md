# Phase 3 — End-to-End Launch Test Results

Run: 2026-07-06T14:00:44.986Z · Node v22.22.2 · fresh database per run

| # | Scenario | Result | Detail |
|---|----------|--------|--------|
| 1 | Customer submits a valid request | ✅ PASS | TN-260706-29ACAC |
| 2 | Duplicate request is detected | ✅ PASS | flagged as dup of TN-260706-29ACAC |
| 3 | Customer requests an unavailable vehicle | ✅ PASS | public status=booked; overlapping assign → 409 |
| 4 | Two providers offer the same car | ✅ PASS | P-002 + P-001 |
| 5 | Admin assigns the lowest-cost approved provider | ✅ PASS | V-1001 @ $850/day |
| 6 | Provider declines the booking | ✅ PASS | status → Under review; sales notified |
| 7 | Backup provider is assigned | ✅ PASS | V-1002 (P-001) confirmed |
| 8 | Customer receives a quote | ✅ PASS | $2,498, 3-day expiry, accepted via track page |
| 9 | Vehicle becomes booked after payment confirmation | ✅ PASS | AR-260706-29ACAC |
| 10 | Overlapping booking is blocked | ✅ PASS | assign V-1002 for 08/11–08/13 → 409 |
| 11 | Active rental is completed | ✅ PASS | AR-260706-29ACAC |
| 12 | Vehicle becomes available after return | ✅ PASS | status + booked dates cleared |
| 13 | Excel synchronization succeeds | ✅ PASS | rows delivered: 18 (CustomerRequests, PartnerInventory, ActiveRentals, Payments) |
| 14 | Excel synchronization fails and retries | ✅ PASS | attempts=2, then sent |
| 15 | Unauthorized user attempts to open admin pages | ✅ PASS | 401 anonymous; 403 wrong roles; field-level filtering works |
| 16 | Partner attempts to access another partner's inventory | ✅ PASS | 404 on foreign unit; no profit/customer-price fields |
| 17 | Sensitive provider rates cannot be accessed from public pages | ✅ PASS | file scan + public API scan clean |
| 18 | Sensitive customer information cannot be exposed | ✅ PASS | phone verification, sanitized responses, path traversal blocked |
| B1 | Browser: admin shows login gate to anonymous visitor | ✅ PASS |  |
| B2 | Browser: full booking wizard submits through the API | ✅ PASS | TN-260706-291692 |

**20/20 passed.**