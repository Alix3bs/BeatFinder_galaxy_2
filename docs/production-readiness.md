# Production Readiness

BeatFinder Hybrid Retrieval v1 is a runnable prototype. Before real users depend on exact beat identification, these areas need production hardening.

## Dataset And Ingestion

- Build a real licensed beat dataset with clear rights for storage, analysis, and matching.
- Define a YouTube and BeatStars ingestion strategy that respects platform terms, creator permissions, takedowns, and attribution.
- Track provenance for every beat, clip, producer alias, upload source, and metadata update.

## Audio Matching Quality

- Replace the lightweight v1 perceptual signature with stronger production audio fingerprinting.
- Add vocal-over-beat matching so searches from released songs can still identify the underlying instrumental.
- Add pitch-shift and tempo-shift tolerance for common edits, sped-up/slowed versions, snippets, and platform transcoding.
- Evaluate short clips, noisy recordings, phone captures, intro/outro sections, and vocals mixed over beats.

## Models And Retrieval

- Connect Hugging Face or another approved model provider for real model-based metadata embeddings.
- Validate any audio embedding model against licensed BeatFinder-style data instead of only synthetic fixtures.
- Keep Gemma-family reasoning behind the existing interface and measure whether it improves metadata expansion and rerank explanations.
- Calibrate confidence thresholds with labeled queries so `likely_exact_match`, `likely_candidates`, and `no_confident_exact_match` reflect real outcomes.

## Supabase And Backend Operations

- Run the live Supabase primary integration suite against a real project after applying all migrations.
- Add migration rollback notes and backup procedures before production schema changes.
- Add monitoring for ingest failures, search latency, empty result rates, low-confidence searches, storage failures, and model-provider errors.
- Add alerting for queue backlog, Supabase RPC failures, and sudden shifts in confidence distributions.

## Product Integration

- Wire the iOS app to the v1 API routes for ingest, audio search, text search, hybrid search, and feedback.
- Add user-facing states for likely exact matches, likely candidates, and no confident match.
- Capture feedback events for clicked, saved, confirmed, and rejected results so ranking can improve over time.

## Evaluation Loop

- Maintain an offline benchmark with licensed real audio and expected matches.
- Track top-k accuracy, exact-match precision, no-match honesty, and confidence calibration over time.
- Review false positives manually before raising exact-match confidence thresholds.
