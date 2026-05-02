# API

The local API is implemented in `backend/api/server.ts`.

Base URL:

- `http://127.0.0.1:8787`

All POST routes accept JSON. Audio routes also accept `multipart/form-data`.

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
  "top_n": 5
}
```

## `POST /search/audio`

JSON request:

```json
{
  "audio_path": "backend/tests/generated_audio/late_nights.wav",
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

Each result includes:

- `beat`
- `rerank_score`
- `confidence_label`
- `embedding_score`
- `signature_score`
- `metadata_score`
- `score_breakdown`
- `explanation`
