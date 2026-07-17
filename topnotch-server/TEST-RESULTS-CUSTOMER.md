# Customer Accounts, Guest Booking & Privacy Hardening — Test Results

Run: 2026-07-17T03:06:50.075Z · fresh staging databases · email captured via mock webhook · OpenAI mocked locally

| # | Scenario | Result | Detail |
|---|----------|--------|--------|
| A1 | AI opt-in: consented request may use AI, output labeled 'AI-assisted' | ✅ PASS | model=mock-model-for-tests |
| A2 | Human-only: OpenAI never called, block audited, deterministic fallback | ✅ PASS | request-level choice: Human-only service — deterministic han |
| A3 | Consent withdrawal applies immediately (live account preference wins) | ✅ PASS | customer preference: Human-only service — deterministic hand |
| 1 | Registration: account + session, verification email sent, Human-only default | ✅ PASS | C-C809FFAD |
| 2 | Duplicate registration refused (case-insensitive email) | ✅ PASS | An account with that email already exists — sign i |
| 3 | Email verification: emailed single-use token verifies the address | ✅ PASS |  |
| 4 | Verification-token replay rejected (single-use) | ✅ PASS |  |
| 5 | Login succeeds with correct password (second device session) | ✅ PASS |  |
| 6 | Login failure rejected and audited | ✅ PASS | 1 failed logins audited |
| 7 | Password reset: enumeration-safe, emailed token, all sessions revoked | ✅ PASS | "If that account exists, instructions have been sent." |
| 8 | Reset-token expiration enforced (expired token refused) | ✅ PASS |  |
| 9 | Reset-token replay rejected; password unchanged | ✅ PASS |  |
| 10 | Guest request: identical pipeline, customer_id NULL, Human-only default | ✅ PASS | TN-260717-27F3BE |
| 11 | Signed-in request linked via server session; forged customer_id ignored | ✅ PASS | C-C809FFAD |
| 12 | Trip/request history: only requests linked to the authenticated customer_id | ✅ PASS | TN-260717-0925AB |
| 13 | Customer B cannot access Customer A's requests or profile | ✅ PASS |  |
| 14 | Customer session blocked from ALL staff APIs | ✅ PASS | 8 endpoints refused |
| 15 | Customer session blocked from provider portal APIs | ✅ PASS |  |
| 16 | Staff session / customer session fully separated | ✅ PASS |  |
| 17 | Provider session / customer session fully separated | ✅ PASS |  |
| 18 | AI opt-in recorded: choice + policy version + timestamp + audit | ✅ PASS | v2026-07-06 |
| 19 | AI opt-out/default: Human-only recorded when not explicitly opted in | ✅ PASS |  |
| 20 | AI-consent withdrawal in account settings works and is audited | ✅ PASS | granted×1 withdrawn×1 |
| 21 | CSRF: state-changing routes reject missing/wrong x-csrf header | ✅ PASS |  |
| 22 | Rate limiting: registration throttled; counter persisted in shared DB table | ✅ PASS |  |
| 23 | Logout invalidates the session | ✅ PASS |  |
| 24 | Sign out of all devices revokes every session (audited) | ✅ PASS | 4 sessions |
| 25 | Permanent account deletion (password-confirmed, audited) | ✅ PASS |  |
| 26 | Deleted-account protection: login and old sessions both fail | ✅ PASS |  |
| 27 | Offline fake-success vulnerability patched (no local TN ids, honest failure, labeled unsent) | ✅ PASS |  |
| 28 | Provider confirmation requirement intact (no quote before confirm) | ✅ PASS | Approve the final price first (current: Availability being c |
| 29 | Payment verification pipeline gate intact (no premature payment) | ✅ PASS |  |
| 30 | Double-booking prevention intact (date conflict → unavailable) | ✅ PASS |  |
| 31 | Signature services: 10-item catalog, stable IDs only, junk rejected | ✅ PASS | arrival-reset-kit,family-arrival |
| 32 | Service approval blocked until 11-item ops checklist passes (409) | ✅ PASS | This service cannot be promised or charged yet — the operati |
| 33 | Service approves only after full checklist incl. customer price approval | ✅ PASS |  |

**36/36 passed.**