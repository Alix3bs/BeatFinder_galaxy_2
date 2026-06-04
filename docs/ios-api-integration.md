# iOS API Integration

BeatFinder iOS now has a local backend contract layer for the hybrid retrieval API:

- `BeatFinderAPIClient`
- `SearchResponse`
- `BeatSearchResult`
- `BeatFinderBackendAPI.Beat`
- `DiscoveryEnrichment`
- `MatchedProducerChannel`
- `YouTubeVideoMatch`
- `BeatFinderBackendTestViewModel`

The existing app catalog model is already named `Beat`, so the backend payload beat is namespaced as `BeatFinderBackendAPI.Beat`.

## Start The Local Backend

Run these from the repo root:

```bash
source .venv/bin/activate
export BEATFINDER_STATE_DIR=.beatfinder_state
python scripts/ingest/load_fixtures.py
python scripts/discovery/load_producer_seeds.py
python scripts/discovery/load_mock_youtube_backfill.py
bash scripts/dev/start_local.sh
```

The default iOS dev base URL is:

```text
http://127.0.0.1:8787
```

The iPhone Simulator can use `127.0.0.1` for a Mac-hosted local server. A physical iPhone usually needs the Mac LAN IP instead, for example `http://192.168.1.25:8787`, and the Mac firewall must allow the connection.

## Test From Terminal

```bash
curl -i http://127.0.0.1:8787/health
```

Then test text search and producer discovery:

```bash
curl -s -X POST http://127.0.0.1:8787/search/text \
  -H 'Content-Type: application/json' \
  -d '{"query":"sza x summer walker type beat","detected_producer_tag":"prod by salishan","top_n":3}' \
  | python -m json.tool
```

Expected local discovery result:

```text
discovery.discovery_status = found_candidate
discovery.youtube_video_match.title includes SZA x Summer Walker Type Beat
```

## Test From The App

Open Settings, then choose `Backend API Test`. The debug screen calls:

- `GET /health`
- `POST /search/text`

The text search request uses:

```json
{
  "query": "sza x summer walker type beat",
  "detected_producer_tag": "prod by salishan",
  "top_n": 3
}
```

The screen displays the top beat title, confidence, detected producer tag, matched producer channel, producer tag confidence, discovery status, YouTube video match title, possible reasons, and recommended next searches.

## Notes

`POST /search/audio` and `POST /search/hybrid` are represented in `BeatFinderAPIClient` with JSON-ready request structs for later app wiring. Multipart audio upload can be added later without changing the response model contract.

This local flow uses fixture-backed beats and mock YouTube backfill only. It does not download copyrighted audio, call live YouTube, call Hugging Face, or require Supabase live credentials.
