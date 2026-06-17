# Backend Deployment Readiness

BeatFinder now supports a configurable iOS backend URL, but the production backend still needs to be hosted before TestFlight or real users can rely on search/upload flows outside local development.

## iOS Backend URL Modes

The app keeps local simulator development working by default:

```text
http://127.0.0.1:8787
```

For a physical iPhone on the same Wi-Fi network as your Mac, replace the LAN placeholder with your Mac IP:

```text
http://YOUR_MAC_IP:8787
```

For TestFlight or production, deploy the BeatFinder backend and replace the production placeholder:

```text
https://YOUR-BEATFINDER-BACKEND.example.com
```

The app does not commit real hosted URLs, Supabase keys, service-role credentials, Hugging Face tokens, or any private endpoint secrets.

## Settings Flow

In the iOS app, open Settings, then `Backend API Settings`.

The screen can:

- show the active backend URL
- switch between local simulator, LAN iPhone, production placeholder, and custom URL modes
- save the selected URL mode locally on device
- call `GET /health` with `Test Backend Connection`
- run the fixture discovery smoke request with `Run Discovery Smoke Test`

If the backend is unreachable, Search and Upload show:

```text
Backend unavailable. Check your BeatFinder backend URL in Settings.
```

## Local Verification

Start the local backend from the repo root:

```bash
source .venv/bin/activate
export BEATFINDER_STATE_DIR=.beatfinder_state
python scripts/ingest/load_fixtures.py
python scripts/discovery/load_producer_seeds.py
python scripts/discovery/load_mock_youtube_backfill.py
bash scripts/dev/start_local.sh
```

Then verify:

```bash
curl -i http://127.0.0.1:8787/health
```

For physical iPhone LAN testing, use the Mac IP in Settings and test from another device on the same network:

```bash
curl -i http://YOUR_MAC_IP:8787/health
```

## Still Needed Before Real Users

- Host the backend API behind HTTPS with stable DNS.
- Add production process supervision, logs, metrics, and alerting.
- Run the Supabase primary-mode integration suite with real project credentials in a secret-gated CI job.
- Replace synthetic fixture-only accuracy checks with licensed beat datasets.
- Add production audio storage policies, retention rules, and upload size limits.
- Add rate limiting and abuse protection for search/upload endpoints.
- Calibrate confidence labels on real-world audio, vocal-over-beat clips, tempo shifts, and pitch shifts.
- Add an operator runbook for model refreshes, producer seed refreshes, and discovery backfills.
