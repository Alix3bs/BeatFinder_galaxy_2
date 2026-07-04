# BeatFinder Production Roadmap

Audit date: 2026-07-04
Audited commit: `15d96e2` (Prepare BeatFinder backend URL configuration)
Verified baseline in this environment: backend lint passes, 75 backend unit tests pass (1 skipped Supabase live test), fixture evaluation passes.

Classification legend:

- **complete** — implemented, wired into the running app or API, covered by tests
- **partially implemented** — real code exists but a production-relevant gap remains
- **mocked** — behavior works but the data or dependency is simulated
- **missing** — not implemented yet
- **blocked by external credentials** — code can be finished, but activation requires accounts or secrets the repository must not contain

## Verification method

Every classification below was checked against the code, not filenames or prior chat claims:

- Backend behavior was verified by reading `backend/` and `models/` sources and by running the full test suite, lint, and evaluation harness in this environment.
- iOS behavior was verified against the Xcode target membership in `BeatFinder.xcodeproj/project.pbxproj`. The app target compiles 89 flat files under `BeatFinder/`. The `BeatFinder/Features/`, `BeatFinder/App/`, `BeatFinder/Components/`, and `BeatFinder/Models/` subdirectories are **stale duplicates that are not compiled** into the app; only the test targets use file-system-synchronized groups.

## Backend

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Hybrid retrieval engine (text / audio / hybrid) | complete | `backend/retrieval/service.py` fuses audio embedding, signature, and metadata scores with explainable breakdowns; covered by `test_integration_retrieval.py`, `test_signature_and_scoring.py`, eval harness |
| Ingest pipeline | complete | `backend/ingest/service.py` + fixture loader; CI smoke test ingests 7 fixture beats |
| HTTP API (`/health`, `/ingest/beat`, `/search/*`, `/feedback`) | complete | `backend/api/server.ts` spawns the Python CLI per request; JSON + multipart supported |
| Multipart audio upload parsing | partially implemented | `backend/api/request_parsers.ts` parses multipart and forwards file bytes as base64; **no MIME/extension allowlist, no size limit, no request timeout, no structured error contract** |
| Upload safety (traversal, filenames, retention) | partially implemented | `audio_path` from a request is passed to `LocalStateStore.store_audio_file`, which reads **any server-readable path** — must be restricted to trusted/local callers; uploaded filenames are used in destination names without sanitization; query audio is retained forever (no retention rule) |
| Local storage adapter | complete | `backend/storage/local_store.py`, JSON-table backed, used by CI |
| Supabase storage adapter (mirror + primary) | blocked by external credentials | `backend/storage/supabase_store.py` implements REST-based mirror and primary stores with env config; live integration test skips without `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`; contract/parity covered by mocks in `test_storage_adapter_parity.py` |
| Supabase migrations | partially implemented | Three migrations in `supabase/migrations/` cover beats, embeddings, discovery; idempotency and rollback/backup documentation need review; no migration runner command documented for deploy |
| Storage health diagnostics | missing | `/health` reports state dir and beat count but not the active storage mode |
| Query normalization + metadata parsing | complete | `models/metadata/normalize.py`, `parser.py`; `test_metadata_parser.py`, `test_query_normalization.py` |
| Text embeddings | mocked (deterministic) | `models/embedding/providers.py` uses a deterministic local embedder; Hugging Face HTTP adapter is wired but needs `HF_API_TOKEN` (blocked by external credentials) |
| Gemma reasoning layer | mocked (deterministic fallback) | `models/metadata/gemma_adapter.py`; remote hook exists, no credentials |
| Reranking / score fusion | complete | `backend/rerank/scoring.py` with explainable breakdown and confidence labels; calibration against larger eval sets still thin |
| Evaluation harness | partially implemented | `scripts/eval/run_eval.py` checks fixture rankings; no persisted P@1/P@3/recall metrics or regression thresholds |
| Rate limiting / request size limits | missing | no limits in `backend/api/server.ts` |
| Structured error responses | partially implemented | errors are classified 400/500 by message regex; raw exception text (potentially including stack content) is returned to clients |

## Producer discovery / YouTube

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Producer channel store (channels, videos, seeds, edges, checkpoints) | complete | `backend/discovery/producer_channels.py`; dedupe + checkpoints tested |
| Backfill engine (pagination, resume, dedupe) | complete (engine), mocked (data) | `backend/discovery/youtube_discovery.py` supports paged backfill with checkpoints; the only client is `mock_youtube_client.py` + fixtures |
| Official YouTube Data API client | missing | no `youtube.googleapis.com` client; needs env-keyed metadata-only client with quota/rate handling; activation blocked by external credentials (API key) |
| Channel handle → channel ID resolution | missing | seeds carry handles; no resolution step exists |
| Scheduled incremental sync | missing | no scheduler/CLI for incremental updates; `last_scanned_at` is tracked |
| Related-search generation (aliases, hashtags, artist/city combos) | complete | `backend/discovery/hashtag_expander.py`, `search_enrichment.py`; tested |
| Missing-video (sold/deleted) inference | complete | `backend/discovery/sold_deleted_inference.py` uses uncertainty statuses (`found_candidate`, `no_visible_match`, `possible_sold_or_deleted`, `insufficient_evidence`) with evidence and confidence; never asserts certainty |
| City/style classification | partially implemented | `backend/discovery/city_style_classifier.py` is keyword-based; no controlled taxonomy file, no confidence-weighted multi-label output, no audio-signal fusion |

## iOS app (compiled target only)

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| Galaxy-style SwiftUI design | complete | preserved across views; do not regress |
| Backend URL configuration (local / LAN / production / custom, validation, test connection) | complete | Phase 1: `BeatFinderAPIClient.swift` configuration types + `BeatFinderBackendTestView`; tests in `BeatFinderBackendConfigurationTests.swift` |
| Text search → backend | complete | `SearchView` → `BeatSearchViewModel` → `BeatFinderAPIClient.searchText`; mapping tests in `BeatSearchBackendMappingTests.swift` |
| Audio upload search → backend | partially implemented | `UploadView` (inline view model) sends base64 JSON to `/search/audio`; **no multipart, no progress reporting, no file-size guard, whole file loaded into memory** |
| Results mapped into `BeatResultModel` | complete | `BeatFinderAPIModels.swift` + mapping tests |
| Save to Safe / duplicate prevention | complete | `SavedBeatStore.swift` with multi-key dedupe; `SavedBeatStoreTests.swift` |
| Safe UI (view, delete) | complete | `SafeView.swift` (inline `SafeViewModel`) |
| Saved JSON migration/versioning | partially implemented | storage key is versioned (`…v1`) but there is no decode-failure migration path |
| Search history / re-run saved searches | missing | no history store exists |
| Result detail screen | partially implemented | `ResultDetailView.swift` exists; share/open-source-link/save affordances need verification and accessibility work |
| StoreKit 2 subscriptions | partially implemented | `SubscriptionManager.swift` is real StoreKit 2 (products, purchase, restore, entitlements, transaction updates); **no entitlement gating model (free vs pro limits), no StoreKit test configuration file in repo**; product IDs are placeholders until App Store Connect setup (blocked by external credentials) |
| Accessibility labels / Dynamic Type audit | partially implemented | some identifiers exist for UI tests; no systematic pass |
| Stale duplicate sources (`Features/`, `App/`, `Components/`, `Models/`, root `UploadViewModel.swift`, etc.) | cleanup needed | not compiled; risk of editing the wrong file; candidates for removal in a cleanup phase |

## Infrastructure

| Feature | Status | Evidence / gap |
| --- | --- | --- |
| GitHub Actions CI (backend + iOS simulator build) | complete | `.github/workflows/beatfinder-ci.yml`; passing at `15d96e2` |
| Deployment container (Dockerfile, start command, graceful shutdown) | missing | no Dockerfile/.dockerignore; server has no SIGTERM handling |
| Hosting comparison / deploy docs | partially implemented | `docs/backend-deployment-readiness.md` exists from Phase 1; needs host comparison and container details |
| Secret scanning / dependency checks in CI | missing | not configured |
| TestFlight / App Store readiness docs | missing | to be created in Phase 11 |

## Blocked-by-credentials summary

These cannot be finished beyond mock/contract level without the owner supplying accounts or secrets (which must never be committed):

1. Supabase live project (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) — activates mirror/primary storage and live integration tests.
2. YouTube Data API key (`BEATFINDER_YOUTUBE_API_KEY`) — activates real channel/video metadata backfill.
3. Hugging Face token (`HF_API_TOKEN`) — activates real text embeddings.
4. Apple Developer / App Store Connect — signing, provisioning, real product IDs, TestFlight.
5. Hosting account (Render/Fly/Cloud Run/…) — deployment requires owner approval before creating paid resources.

## Phase plan

The remaining work proceeds in the phases defined by the product owner:

- Phase 2 — real audio upload contract hardening (validation, limits, cleanup, retention, iOS multipart/progress)
- Phase 3 — production storage (Supabase adapter completeness, migrations, retention, storage-mode health)
- Phase 4 — official YouTube Data API discovery architecture (mock-tested, env-activated)
- Phase 5 — explainable regional style classification with taxonomy and confidence
- Phase 6 — search quality: normalization, aliasing, calibration, eval metrics
- Phase 7 — Safe/history/result experience completion
- Phase 8 — entitlement model + StoreKit test configuration
- Phase 9 — deployable container + hosting comparison
- Phase 10 — security/privacy hardening and compliance docs
- Phase 11 — CI extension + TestFlight/App Store/release checklists
- Phase 12 — final production audit

Each phase lands as its own commit and must keep the currently passing CI green.
