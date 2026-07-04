# BeatFinder Security

## Upload threat model

| Threat | Vector | Control |
| --- | --- | --- |
| Path traversal / arbitrary file read | `audio_path` in JSON pointing at server files | `audio_path` rejected over HTTP (400 `audio_path_not_allowed`) unless `BEATFINDER_ALLOW_LOCAL_AUDIO_PATHS=1`; second layer via `BEATFINDER_DISALLOW_AUDIO_PATHS=1` in `backend/core/audio_input.py` |
| Malicious filenames | multipart filename with `../`, control chars, quotes | server-side sanitization strips directories/unsafe characters and caps length (`sanitize_audio_file_name`); iOS also strips quotes/CRLF client-side |
| Memory / disk exhaustion | oversized bodies | `Content-Length` pre-check + streamed count with hard abort (`BEATFINDER_MAX_UPLOAD_BYTES`, default 25 MB, 413) |
| CPU exhaustion | repeated expensive audio searches | per-client fixed-window rate limit on `/search/audio`, `/search/hybrid`, `/ingest/beat` (`BEATFINDER_RATE_LIMIT_PER_MINUTE`, default 30, 429 + Retry-After); processing time-boxed by `BEATFINDER_CLI_TIMEOUT_MS` (504) |
| Decoder abuse | crafted/foreign file formats | extension + MIME allowlist (wav/mp3/m4a); actual decode is validated — WAV via the stdlib reader, mp3/m4a only through ffmpeg with a decode timeout; undecodable input returns 400/415, never crashes the request loop |
| Content smuggling | unexpected content types | only `application/json` and `multipart/form-data` accepted (415) |
| Information disclosure | stack traces in responses | CLI exit-code protocol: client errors return `{error, message}` with safe text; internals log server-side only |
| Header spoofing of rate limits | forged `X-Forwarded-For` | client key always includes the socket address alongside the first forwarded hop |

Residual risks: the in-memory rate limiter is per-instance (add platform WAF limits for fleets); WAV parsing uses Python's stdlib `wave` (memory bounded by the upload cap).

## Data retention and deletion

- Uploaded query audio is deleted immediately after feature extraction unless `BEATFINDER_RETAIN_QUERY_AUDIO=1`; retained files carry an `expires_at` and are purged via `public.purge_expired_query_audio()` (see `docs/storage.md`).
- Query records store the query text/type and scores, with an optional `created_by` id — no device identifiers, no location, no contacts.
- Beat catalog audio is the search index (reference beats), not user data.

## Secret handling

- No credentials are committed; Supabase, YouTube, and Hugging Face keys are environment-injected. `SupabaseRESTClient.from_env()` and friends return `None`/fail fast when unset.
- `/health` exposes only booleans (`supabase_configured`) — never values.
- CI runs a secret scan (gitleaks) and dependency review on every push (`.github/workflows/beatfinder-ci.yml`).

## Dependency posture

Backend dependencies are intentionally tiny (numpy only; Node stdlib only — no npm packages), which keeps the supply-chain surface minimal. The iOS app uses the Supabase Swift SDK via SPM. Dependency review runs in CI for pull requests.
