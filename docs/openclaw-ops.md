# OpenClaw Ops Stub

OpenClaw belongs on the admin side of BeatFinder, not in the retrieval hot path.

## Good Uses

- trigger ingest batches
- run the evaluation harness
- inspect uncertain results
- rerun maintenance or re-embedding jobs
- wrap the local CLI for operator workflows

## Bad Uses

- serving `/search/*` directly
- making the ranking decision itself
- becoming a dependency for app startup

## Existing Command Surface

The current repo already exposes the commands an OpenClaw operator flow should wrap:

```bash
$BEATFINDER_PYTHON_BIN -m backend.workers.cli health --state-dir .beatfinder_state
$BEATFINDER_PYTHON_BIN -m backend.workers.cli ingest --state-dir .beatfinder_state < payload.json
$BEATFINDER_PYTHON_BIN -m backend.workers.cli search-text --state-dir .beatfinder_state < query.json
$BEATFINDER_PYTHON_BIN scripts/eval/run_eval.py
```

## Suggested Admin Tasks

- `ingest_fixtures`
- `run_eval`
- `list_uncertain_results`
- `mirror_to_supabase`

The retrieval engine already handles audio features, signatures, metadata normalization, and reranking. OpenClaw should orchestrate those pieces, not replace them.
