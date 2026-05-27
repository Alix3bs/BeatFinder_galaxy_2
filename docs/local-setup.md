# Local Setup

## Prerequisites

- Python 3.12
- Node 24
- No external Python or Node dependencies are required for the verified offline path

Default local runtime commands:

- Python: `python3`
- Node: `node`

## Environment Variables

Start from `.env.example`.

Most important values:

- `BEATFINDER_STATE_DIR`
- `BEATFINDER_PYTHON_BIN`
- `BEATFINDER_NODE_BIN`
- `PORT`
- `BEATFINDER_SUPABASE_MODE=local|mirror|primary`

Optional Hugging Face values:

- `HF_API_TOKEN`
- `BEATFINDER_HF_TEXT_ENDPOINT`
- `BEATFINDER_HF_TEXT_MODEL`
- `BEATFINDER_TEXT_EMBEDDING_DIM=384`

Optional Gemma values:

- `GEMMA_ENDPOINT`
- `GEMMA_API_KEY`
- `GEMMA_MODEL`

Optional Supabase values:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`

Mode behavior:

- `local`: no Supabase dependency
- `mirror`: local state stays authoritative and writes are mirrored to Supabase when credentials are present
- `primary`: Supabase becomes the runtime source of truth while local state is used only as scratch space for uploaded audio

## Local Fixture Flow

1. Configure the offline verified mode.

```bash
export BEATFINDER_PYTHON_BIN=python3
export BEATFINDER_NODE_BIN=node
export BEATFINDER_STATE_DIR=.beatfinder_state
export BEATFINDER_SUPABASE_MODE=local
```

2. Build the local fixture dataset.

```bash
$BEATFINDER_PYTHON_BIN scripts/ingest/load_fixtures.py
```

3. Start the API.

```bash
scripts/dev/start_local.sh
```

4. Query the API.

```bash
curl -s http://127.0.0.1:8787/health
curl -s -X POST http://127.0.0.1:8787/search/audio \
  -H 'Content-Type: application/json' \
  -d '{"audio_path":"backend/tests/generated_audio/late_nights.wav","top_n":3}'
```

## Multipart API Example

Example ingest with multipart audio:

```bash
curl -s -X POST http://127.0.0.1:8787/ingest/beat \
  -F 'title=SZA x Summer Walker Type Beat - Late Nights' \
  -F 'producer_name=Era Jay x Bani' \
  -F 'hashtags=["#phillytypebeat"]' \
  -F 'region_tags=["philly"]' \
  -F 'genre_tags=["rnb"]' \
  -F 'audio=@backend/tests/generated_audio/late_nights.wav;type=audio/wav'
```

## Supabase Setup

The repo includes runnable migrations under `supabase/migrations/`.

Recommended production outline:

1. Create or link a Supabase project.
2. Apply:
   - `supabase/migrations/202604200001_hybrid_retrieval_v1.sql`
   - `supabase/migrations/202604250001_alignment_storage_primary.sql`
3. Create the storage buckets `beat-audio` and `query-audio` if they are not already present.
4. Deploy `supabase/functions/health`.
5. Set:
   - `BEATFINDER_SUPABASE_MODE=primary`
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`

This repo does not apply migrations automatically because no live Supabase credentials were available during implementation.

## Evaluation

Run the evaluation harness:

```bash
$BEATFINDER_PYTHON_BIN scripts/eval/run_eval.py
```

Or run the full local verification flow:

```bash
scripts/dev/verify_local.sh
```

The script:

- resets a fresh local state directory
- synthesizes the fixture audio set
- ingests the fixtures
- runs exact audio, clip audio, text, and hybrid searches
- prints a JSON report
