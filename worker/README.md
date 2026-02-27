# BeatFinder Worker (TypeScript)

This worker reads `public.search_jobs`, processes text/audio searches, writes `public.matches`, and updates job state.

## Schema corrections included

1. `public.matches` writes use only:
   - `search_id` (from `job.search_id`)
   - `user_id` (from `job.user_id`)
   - `platform`, `url`, `title`, `similarity`, `bpm`, `key`
   - No `beat_id`, `score`, or `meta` writes.
2. `search_jobs.search_id` is used everywhere for search linkage.
3. Every `public.beats` insert includes `user_id = job.user_id`.
4. Embedding trigger behavior:
   - Default: disabled direct embed calls (`WORKER_ENABLE_DIRECT_EMBED_CALLS=false`) and relies on DB triggers.
   - Optional direct call shape is correct: `[{ msg_id, message: { id, text } }]`.
5. No `node-fetch` import; uses Node 18+ global `fetch`.
6. `markJobFailed` uses null-safe payload update:
   - `jsonb_set(coalesce(payload, '{}'::jsonb), '{error}', ...)`
7. Ranking keeps `producer_tag` as highest weight.
8. If `search_jobs.search_id` is `null`, the worker marks the job failed and skips match inserts.

## Result states

Worker writes one of these to `search_jobs.payload.result_state`:
- `exact_match`
- `close_matches`
- `not_found`

## Required environment variables

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL` (Postgres connection used by worker for queue + inserts; runs with service-role DB privileges)

## Optional environment variables

- `SUPABASE_AUDIO_BUCKET` (default: `search-audio`)
- `SUPABASE_EMBED_QUERY_FUNCTION` (default: `embed_query`)
- `SUPABASE_FINGERPRINT_FUNCTION` (default: `fingerprint`)
- `SUPABASE_EMBED_BEAT_FUNCTION` (default: `embed`)
- `WORKER_ENABLE_DIRECT_EMBED_CALLS` (default: `false`)
- `WORKER_POLL_INTERVAL_MS` (default: `1200`)
- `WORKER_MATCH_LIMIT` (default: `20`)
- `WORKER_PERSIST_TOP_MATCHES` (default: `10`)
- `WORKER_EXACT_THRESHOLD` (default: `0.9`)
- `WORKER_CLOSE_THRESHOLD` (default: `0.6`)
- `BEATS_URL_COLUMN` (`source_url` or `url`, default: `source_url`)

## Run locally

```bash
cd worker
npm install
cp .env.example .env
npm run dev
```

## Build

```bash
cd worker
npm run build
npm start
```

## Deploy steps

1. Deploy required Edge Functions:

```bash
supabase functions deploy embed_query --project-ref <PROJECT_REF>
supabase functions deploy fingerprint --project-ref <PROJECT_REF>
```

2. Set worker env vars in your runtime (Railway, Render, Fly, ECS, etc.).
3. Run the worker process:

```bash
node dist/worker.js
```

4. If your DB already has pgmq triggers for beat embeddings, keep:
   - `WORKER_ENABLE_DIRECT_EMBED_CALLS=false`

5. If you prefer direct embed function calls from worker, set:
   - `WORKER_ENABLE_DIRECT_EMBED_CALLS=true`
   - `SUPABASE_EMBED_BEAT_FUNCTION=<your_embed_function_name>`
