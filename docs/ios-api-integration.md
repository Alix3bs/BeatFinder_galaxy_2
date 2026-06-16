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
- `BeatSearchViewModel`

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

## Use The Real Search UI

The main `SearchView` now calls the local BeatFinder backend through `BeatSearchViewModel` and `BeatFinderAPIClient`.

For local text testing:

1. Start the backend with the fixture, producer seed, and mock YouTube backfill commands above.
2. Open the app in the iPhone Simulator.
3. Go to the Search tab.
4. Enter `sza x summer walker type beat` in the main query field.
5. Enter `prod by salishan` in the optional detected producer tag field.
6. Tap `Find Beat`.

Expected local result:

```text
discovery_status = found_candidate
matched producer channel = prod.salishan
youtube video match title includes SZA x Summer Walker Type Beat
recommended next searches includes prod salishan type beat
```

The result card shows the top beat title, confidence, producer tag, matched producer channel, producer tag confidence, discovery status, YouTube video match title, possible sold/deleted reasons when applicable, and recommended next searches.

Audio upload and microphone search also route through `POST /search/audio` using a local base64 payload. They do not call live YouTube or download copyrighted audio.

## Use The Upload UI

The main Upload tab now uses the same backend API contract instead of the old placeholder matcher.

Supported local flows:

- Files audio/video import: the app copies the selected file into a temporary working file, extracts audio from videos when needed, base64-encodes the audio, then calls `POST /search/audio`.
- Link import: the app validates the URL and calls `POST /search/hybrid` with the URL as a query hint.
- Optional producer tag: the Upload screen includes a detected producer tag field. For local fixture testing, use `prod by salishan`.

Current backend contract:

```json
{
  "audio_base64": "<base64 audio bytes>",
  "audio_file_name": "snippet.m4a",
  "audio_mime_type": "audio/mp4",
  "detected_producer_tag": "prod by salishan",
  "top_n": 3
}
```

If the backend is not running, the app shows:

```text
Backend unavailable. Start local BeatFinder backend and try again.
```

If the audio/hybrid endpoint is missing from the running backend build, the app shows a clean dev message and keeps the UI stable.

After a backend audio or hybrid response, the Upload screen and result sheet can show:

- top beat title
- confidence
- matched producer channel
- producer tag confidence
- discovery status
- YouTube video match title
- possible sold/deleted reasons
- recommended next searches

## Test From The Debug Screen

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

## CI Coverage

GitHub Actions now runs backend lint/unit/eval checks, typechecks the Swift API client contract, and attempts an iOS simulator build on a macOS runner. This is the preferred cloud verification path when local Mac storage makes Xcode unreliable.

See `docs/ci.md` for the workflow details and the Actions link.

## Notes

`POST /search/audio` is wired from the real upload/record Search UI and the Upload tab with JSON base64 payloads. `POST /search/hybrid` is wired from the Upload tab link flow with a JSON request. Multipart audio upload can be added later without changing the response model contract.

This local flow uses fixture-backed beats and mock YouTube backfill only. It does not download copyrighted audio, call live YouTube, call Hugging Face, or require Supabase live credentials.
