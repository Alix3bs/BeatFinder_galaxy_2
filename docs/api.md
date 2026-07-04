# API

The local API is implemented in `backend/api/server.ts`.

Base URL:

- `http://127.0.0.1:8787`

All POST routes accept JSON. Audio routes also accept `multipart/form-data`.

## Upload contract and limits

- Request bodies are limited to `BEATFINDER_MAX_UPLOAD_BYTES` (default 25 MB). Oversized requests return `413 {"error": "upload_too_large"}`.
- Supported upload formats: `.wav` natively; `.mp3` / `.m4a` only when an `ffmpeg` binary is available (`BEATFINDER_FFMPEG_BIN` or on the PATH). Unsupported formats return `415 {"error": "unsupported_audio_format"}`.
- `audio_path` (a server-side file path) is rejected over HTTP with `400 {"error": "audio_path_not_allowed"}` unless the server runs with `BEATFINDER_ALLOW_LOCAL_AUDIO_PATHS=1`. It remains available to trusted local callers (fixture loaders, CLI).
- Uploaded file names are sanitized server-side (directory components stripped, unsafe characters removed, length capped).
- Query audio is deleted immediately after feature extraction. Set `BEATFINDER_RETAIN_QUERY_AUDIO=1` to retain it for debugging; retained files live under the state directory's `storage/queries/`.
- Python CLI processing is killed after `BEATFINDER_CLI_TIMEOUT_MS` (default 120000) and returns `504 {"error": "processing_timeout"}`.
- Only `application/json` and `multipart/form-data` content types are accepted (`415 {"error": "unsupported_content_type"}` otherwise).
- Errors are structured as `{"error": "<stable_code>", "message": "<safe text>"}`; internal stack traces are never returned to clients.

The iOS app converts every selected audio or video source to 16 kHz mono 16-bit WAV (capped at 90 seconds) on-device before uploading, so production servers do not need ffmpeg for app traffic.

For local discovery enrichment, seed fixture beats and producer channels into the same local state directory before starting the API:

```bash
source .venv/bin/activate
export BEATFINDER_STATE_DIR=.beatfinder_state
python scripts/ingest/load_fixtures.py
python scripts/discovery/load_producer_seeds.py
python scripts/discovery/load_mock_youtube_backfill.py
bash scripts/dev/start_local.sh
```

Then verify producer discovery can return an indexed mock YouTube match:

```bash
curl -s -X POST http://127.0.0.1:8787/search/text \
  -H 'Content-Type: application/json' \
  -d '{"query":"sza x summer walker type beat","detected_producer_tag":"prod by salishan","top_n":3}' \
  | python -m json.tool
```

With the mock backfill loaded, the response should include `discovery.discovery_status = "found_candidate"` and a non-null `discovery.youtube_video_match` whose title includes `SZA x Summer Walker Type Beat`.

## `GET /health`

Response:

```json
{
  "status": "ok",
  "state_dir": "/absolute/path/.beatfinder_state",
  "beats_indexed": 7
}
```

## `POST /ingest/beat`

JSON request:

```json
{
  "title": "SZA x Summer Walker Type Beat - Late Nights",
  "producer_name": "Era Jay x Bani",
  "hashtags": ["#phillytypebeat"],
  "region_tags": ["philly"],
  "genre_tags": ["rnb"],
  "source_url": "https://example.com/beats/late-nights",
  "source_platform": "fixture",
  "audio_path": "backend/tests/generated_audio/late_nights.wav"
}
```

Alternative JSON audio input:

```json
{
  "title": "SZA x Summer Walker Type Beat - Late Nights",
  "producer_name": "Era Jay x Bani",
  "audio_base64": "<base64 wav bytes>",
  "audio_file_name": "late_nights.wav",
  "audio_mime_type": "audio/wav"
}
```

Multipart example:

```bash
curl -s -X POST http://127.0.0.1:8787/ingest/beat \
  -F 'title=SZA x Summer Walker Type Beat - Late Nights' \
  -F 'producer_name=Era Jay x Bani' \
  -F 'hashtags=["#phillytypebeat"]' \
  -F 'region_tags=["philly"]' \
  -F 'genre_tags=["rnb"]' \
  -F 'audio=@backend/tests/generated_audio/late_nights.wav;type=audio/wav'
```

Response:

```json
{
  "beat_id": "uuid",
  "status": "ingested",
  "audio_storage_path": "storage/beats/...",
  "embedding_models": [
    "beatfinder-local-audio-summary-384-v1",
    "beatfinder-local-metadata-hash-384-v1"
  ],
  "signature_type": "beatfinder-perceptual-signature-v1"
}
```

## `POST /search/text`

Request:

```json
{
  "query": "sza x summer walker type beat",
  "detected_producer_tag": "prod by salishan",
  "top_n": 5
}
```

## `POST /search/audio`

JSON request:

```json
{
  "audio_path": "backend/tests/generated_audio/late_nights.wav",
  "detected_producer_tag": "prod by salishan",
  "top_n": 5
}
```

Alternative base64 request:

```json
{
  "audio_base64": "<base64 wav bytes>",
  "audio_file_name": "clip.wav",
  "audio_mime_type": "audio/wav",
  "top_n": 5
}
```

Multipart example:

```bash
curl -s -X POST http://127.0.0.1:8787/search/audio \
  -F 'top_n=5' \
  -F 'audio=@backend/tests/generated_audio/late_nights.wav;type=audio/wav'
```

## `POST /search/hybrid`

JSON request:

```json
{
  "query": "sza x summer walker type beat",
  "audio_path": "backend/tests/generated_audio/late_nights.wav",
  "detected_producer_tag": "prod by salishan",
  "top_n": 5
}
```

Multipart example:

```bash
curl -s -X POST http://127.0.0.1:8787/search/hybrid \
  -F 'query=sza x summer walker type beat' \
  -F 'top_n=5' \
  -F 'audio=@backend/tests/generated_audio/late_nights.wav;type=audio/wav'
```

## `POST /feedback`

Request:

```json
{
  "query_id": "uuid",
  "beat_id": "uuid",
  "event_type": "confirmed_match"
}
```

## Search Response Shape

Every search endpoint returns:

- `query_id`
- `query_type`
- `confidence`
- `candidate_pool_sizes`
- `results[]`
- `discovery` optional producer discovery enrichment

Each result includes:

- `beat`
- `rerank_score`
- `confidence_label`
- `embedding_score`
- `signature_score`
- `metadata_score`
- `score_breakdown`
- `explanation`

`discovery` is additive and safe for existing clients to ignore. It is populated from local/mock producer discovery data only; BeatFinder does not call live YouTube during search. If no detected producer tag is supplied, `discovery.discovery_status` is `not_applicable`.

If `detected_producer_tag` is set but the response says the tag did not match a known producer alias, make sure the producer seed script above was run against the same `BEATFINDER_STATE_DIR` as the API.

Example discovery block:

```json
{
  "detected_producer_tag": "prod by salishan",
  "matched_producer_channel": {
    "id": "uuid",
    "channel_id": "prod.salishan",
    "channel_url": "https://youtube.com/@prod.salishan",
    "producer_name": "prod.salishan",
    "aliases": ["prod.salishan"]
  },
  "producer_tag_confidence": 0.9,
  "youtube_video_match": null,
  "discovery_status": "possible_sold_or_deleted",
  "possible_reasons": [
    "sold_and_deleted",
    "unlisted",
    "private",
    "renamed",
    "hosted_on_beatstars",
    "hosted_on_traktrain",
    "not_yet_indexed",
    "producer_tag_false_positive"
  ],
  "evidence": [
    "detected producer tag normalized to 'prod by salishan'",
    "matched producer channel 'prod.salishan'",
    "no visible matching beat upload found in indexed candidates",
    "status is possible only, not certain"
  ],
  "recommended_next_searches": [
    "prod salishan type beat",
    "philly type beat",
    "sza summer walker type beat"
  ]
}
```

Discovery status values:

- `found_candidate`: the producer tag matched a known channel and an indexed YouTube beat video plausibly matches the query or top BeatFinder candidate.
- `possible_sold_or_deleted`: the producer tag matched a known channel, but no matching indexed visible video was found. This is never a certainty claim.
- `insufficient_evidence`: the detected producer tag is too weak, generic, or unmatched.
- `not_applicable`: no detected producer tag was supplied.
