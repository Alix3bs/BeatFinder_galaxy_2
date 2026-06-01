# API

The local API is implemented in `backend/api/server.ts`.

Base URL:

- `http://127.0.0.1:8787`

All POST routes accept JSON. Audio routes also accept `multipart/form-data`.

For local discovery enrichment, seed fixture beats and producer channels into the same local state directory before starting the API:

```bash
source .venv/bin/activate
export BEATFINDER_STATE_DIR=.beatfinder_state
python scripts/ingest/load_fixtures.py
python scripts/discovery/load_producer_seeds.py
bash scripts/dev/start_local.sh
```

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
