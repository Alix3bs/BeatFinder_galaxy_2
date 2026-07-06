# BeatFinder Backend Deployment

Deployable container for the BeatFinder backend (Node HTTP API + Python
retrieval engine). **No deployment or paid resource is created without the
owner's approval** — this document prepares everything up to that step.

## Runtime shape

- Single container: Node 24 serves HTTP and spawns the Python CLI per request.
- CPU-only; no GPU. Memory footprint is small (numpy + JSON state).
- State: `/data` volume in `local` mode, or Supabase Postgres/Storage in
  `mirror`/`primary` mode (see `docs/storage.md`).
- ffmpeg is included so mp3/m4a uploads decode server-side; the iOS app
  already normalizes to WAV, so ffmpeg is a fallback, not a requirement.

## Build, run, verify

```bash
docker build -t beatfinder-backend .
docker run -d -p 8787:8787 -v beatfinder-state:/data --name beatfinder beatfinder-backend
curl -fsS http://127.0.0.1:8787/health
```

Production start command (what the image runs): `node --experimental-strip-types backend/api/server.ts`.

Graceful shutdown: the server closes on SIGTERM/SIGINT and exits within 10 s (`backend/api/server.ts`), so rolling deploys drain cleanly.

## Environment variables

| Variable | Purpose | Default |
| --- | --- | --- |
| `PORT` | listen port | `8787` |
| `BEATFINDER_STATE_DIR` | state/scratch directory (mount a volume here) | `/data` in the image |
| `BEATFINDER_SUPABASE_MODE` | `local` / `mirror` / `primary` | `local` |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Supabase project (inject as host secrets, never commit) | unset |
| `BEATFINDER_MAX_UPLOAD_BYTES` | request body cap | 26214400 (25 MB) |
| `BEATFINDER_CLI_TIMEOUT_MS` | per-request processing timeout | 120000 |
| `BEATFINDER_CORS_ORIGIN` | `Access-Control-Allow-Origin` value | `*` |
| `BEATFINDER_ALLOW_LOCAL_AUDIO_PATHS` | accept `audio_path` over HTTP (dev only; leave unset in production) | off |
| `BEATFINDER_RETAIN_QUERY_AUDIO` | keep uploaded query audio (leave unset in production) | off |
| `BEATFINDER_QUERY_AUDIO_TTL_DAYS` | retention horizon when retention is on | 7 |
| `BEATFINDER_YOUTUBE_API_KEY` | discovery backfill jobs only (not needed by the API) | unset |
| `HF_API_TOKEN`, `BEATFINDER_HF_TEXT_ENDPOINT`, `BEATFINDER_HF_TEXT_MODEL` | optional live text embeddings | unset |

Development vs production: development uses `.env` + `scripts/dev/start_local.sh`; production injects the variables above through the host's secret manager. Nothing secret is baked into the image or the repository.

## HTTPS and CORS

The container serves plain HTTP. Terminate TLS at the platform edge (all hosts below provide managed HTTPS). The iOS app expects an `https://` production URL in Settings. Restrict `BEATFINDER_CORS_ORIGIN` to the real web origin if a web client ships; the iOS app does not need CORS.

## Persistent storage plan

- **Pilot (single instance)**: `BEATFINDER_SUPABASE_MODE=local` with a persistent volume mounted at `/data`. Back up by snapshotting the volume.
- **Production**: `BEATFINDER_SUPABASE_MODE=primary` with Supabase Postgres + Storage. `/data` is then scratch-only and needs no durability. This also unlocks multiple instances behind a load balancer (local mode must stay single-instance).

## Database migration command

Run once per new Supabase environment, and after pulling new migrations:

```bash
supabase link --project-ref <project-ref>
supabase db push          # applies supabase/migrations/*.sql (idempotent)
```

(or `psql "$SUPABASE_DB_URL" -f supabase/migrations/<file>.sql` in order — see `docs/storage.md`).

## Logging

The server logs structured JSON lines to stdout/stderr (startup config, request errors, CLI failures, shutdown) — every host below captures container stdout natively. Client-facing errors are sanitized; details stay in the logs.

## Host comparison

| Host | Runtime fit | Cost structure | Storage | Background jobs | Scaling | Ops difficulty |
| --- | --- | --- | --- | --- | --- | --- |
| **Render** | Dockerfile deploy, health checks, managed TLS | free/hobby tier; paid from ~$7/mo | persistent disks on paid plans | cron jobs supported | vertical + horizontal (paid) | **lowest** — git-push deploys |
| **Railway** | Dockerfile deploy, simple env/secrets | usage-based, ~$5 floor | volumes supported | cron via services | vertical mainly | low |
| **Fly.io** | Dockerfile-native, global regions | usage-based, small VMs cheap | Fly volumes (single-region) | Fly Machines cron | good horizontal | medium — CLI-driven |
| **Google Cloud Run** | container-native, scale-to-zero | per-request CPU/RAM; generous free tier | **no persistent volume** — requires Supabase mode | Cloud Scheduler + Jobs | excellent autoscaling | medium — GCP setup |
| **AWS (App Runner/ECS)** | container-native | most complex pricing | EFS possible (ECS) | EventBridge | excellent | **highest** |

**Recommendation**: Render for the pilot (persistent disk keeps `local` mode viable, one-click TLS, cron for the YouTube sync job), moving to Cloud Run + Supabase `primary` mode when autoscaling matters. Both paths use the same image unchanged.

## Upload limits and abuse posture

Request bodies are capped (`BEATFINDER_MAX_UPLOAD_BYTES`), non-JSON/multipart content types are rejected, `audio_path` is denied over HTTP, filenames are sanitized, processing is time-boxed, and errors are structured without stack traces. Platform-level rate limiting (Cloudflare/host WAF) is recommended in front of `/search/audio` and `/search/hybrid`; see `docs/security.md`.

## Deployment checklist (requires owner approval)

1. Choose host (recommendation above) and create the service from this repo's Dockerfile.
2. Mount a volume at `/data` (Render/Railway/Fly) **or** configure Supabase env for `primary` mode (Cloud Run).
3. Set environment variables; leave the dev-only flags unset.
4. Apply Supabase migrations if using `mirror`/`primary`.
5. Verify `GET /health` shows the expected `storage_mode` and `supabase_configured`.
6. Put the public HTTPS URL into the iOS app's Settings → Backend → Production.

## Render staging (approved host)

Staging URL: `https://beatfinder-staging.onrender.com` *(placeholder — record the real URL Render assigns after the first deploy)*

The service is defined as code in [`render.yaml`](../render.yaml). Apply it via **Render Dashboard → New → Blueprint → this repository → branch `beatfinder-system-v1`**.

### Service configuration

| Setting | Value |
| --- | --- |
| Service type / runtime | Web Service / Docker (repo `Dockerfile`) |
| Branch | `beatfinder-system-v1` (auto-deploy on push to this branch only) |
| Plan | Starter (smallest plan that supports persistent disks) |
| Health check path | `/health` |
| Persistent disk | `beatfinder-state`, 1 GB, mounted at `/data` |
| HTTPS | provided by Render's managed TLS on the `onrender.com` URL |

### Environment variables (staging, no secrets)

| Name | Value |
| --- | --- |
| `BEATFINDER_SUPABASE_MODE` | `local` |
| `BEATFINDER_STATE_DIR` | `/data/beatfinder_state` |
| `PORT` | `8787` |
| `PYTHONUNBUFFERED` | `1` |
| `NODE_ENV` | `production` |

All other variables keep their safe defaults (25 MB upload cap, 30 req/min rate limit, query-audio deletion after processing, local audio paths denied). Supabase and YouTube credentials are **not** set at this stage.

### Disk permissions

Render mounts the persistent disk at `/data` owned by root at runtime. The container starts as root only long enough for `scripts/deploy/entrypoint.sh` to create `BEATFINDER_STATE_DIR` and hand ownership to the non-root `beatfinder` user via `gosu`; the API server itself never runs as root. CI's container job exercises this exact path on every push.

### Estimated monthly cost (verify on render.com/pricing before applying)

| Item | Estimate |
| --- | --- |
| Web Service, Starter plan | ~$7.00 / month |
| Persistent disk, 1 GB @ ~$0.25/GB | ~$0.25 / month |
| **Total staging estimate** | **~$7.25 / month** |

The free instance type cannot be used: it does not support persistent disks and spins down on idle.

### Post-deploy verification

```bash
BASE=https://<assigned-url>.onrender.com
curl -fsS "$BASE/health"                      # expect status ok, storage_mode local
curl -fsS -X POST "$BASE/search/text" \
  -H 'Content-Type: application/json' \
  -d '{"query":"philly type beat","top_n":3}' # expect JSON with results/discovery keys
```

The health response contains only `status`, `state_dir`, `beats_indexed`, `storage_mode`, `supabase_configured` (boolean), and `query_audio_retention` — no secret values. Confirm state persistence by triggering **Manual Deploy → Restart** in the Render dashboard and checking `beats_indexed` is unchanged afterward.

### Rollback

- **Bad deploy**: Render Dashboard → the service → *Events/Deploys* → pick the previous successful deploy → **Rollback**. Rollbacks reuse the already-built image and take effect in seconds.
- **Bad commit**: revert the commit on `beatfinder-system-v1` and push; auto-deploy ships the revert.
- **Disk data**: the disk is independent of deploys; nothing in a rollback touches `/data`. Render supports disk snapshots for restore points before risky changes.

### Remaining step after staging is verified

Provision Supabase, run `supabase db push` (idempotent migrations in `supabase/migrations/`), then set `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` in the Render dashboard (never in the repo) and flip `BEATFINDER_SUPABASE_MODE` to `primary`. See `docs/storage.md`.
