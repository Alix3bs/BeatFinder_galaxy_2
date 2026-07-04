# BeatFinder Storage

## Modes

Set `BEATFINDER_SUPABASE_MODE` to choose the storage adapter (`backend/storage/runtime.py`):

| Mode | Behavior | Requirements |
| --- | --- | --- |
| `local` (default) | File-backed JSON state under `BEATFINDER_STATE_DIR`. Used by CI and offline development. | none |
| `mirror` | Local-first reads/writes plus best-effort Supabase mirror writes. Falls back to local when Supabase env is absent. | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` |
| `primary` | Supabase Postgres/pgvector is the source of truth; local state is scratch space for audio processing. Fails fast if env is missing. | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` |

`GET /health` reports `storage_mode` and `supabase_configured` (a boolean — never the values themselves) so a deployment's active mode can be verified without exposing secrets.

## Environment variables

| Variable | Purpose | Default |
| --- | --- | --- |
| `BEATFINDER_SUPABASE_MODE` | storage mode (`local` / `mirror` / `primary`) | `local` |
| `SUPABASE_URL` | Supabase project URL | unset |
| `SUPABASE_SERVICE_ROLE_KEY` | service-role key (server-side only, never shipped to clients or committed) | unset |
| `BEATFINDER_STATE_DIR` | local/scratch state directory | `.beatfinder_state` |
| `BEATFINDER_RETAIN_QUERY_AUDIO` | keep uploaded query audio after processing | off (deleted immediately) |
| `BEATFINDER_QUERY_AUDIO_TTL_DAYS` | retention horizon for retained query audio | `7` |

## Migrations

Migrations live in `supabase/migrations/` and are idempotent (`create table if not exists`, `create or replace function`, guarded policies), so re-running them is safe.

Apply with the Supabase CLI:

```bash
supabase link --project-ref <project-ref>
supabase db push
```

Or directly with psql:

```bash
psql "$SUPABASE_DB_URL" -f supabase/migrations/202604200001_hybrid_retrieval_v1.sql
psql "$SUPABASE_DB_URL" -f supabase/migrations/202604250001_alignment_storage_primary.sql
psql "$SUPABASE_DB_URL" -f supabase/migrations/202605310001_producer_discovery_v1.sql
psql "$SUPABASE_DB_URL" -f supabase/migrations/202607040001_production_storage_v1.sql
```

Buckets `beat-audio` and `query-audio` must exist in Supabase Storage (private; access through the service role only).

## Retention

- Uploaded **query audio** is deleted from the state directory immediately after feature extraction unless `BEATFINDER_RETAIN_QUERY_AUDIO=1`.
- When retention is enabled and Supabase mode is active, each retained file is registered in `public.uploaded_audio_assets` with an `expires_at` horizon (`BEATFINDER_QUERY_AUDIO_TTL_DAYS`, default 7 days).
- A scheduled maintenance job should call `select * from public.purge_expired_query_audio();` and then delete the returned `bucket`/`object_path` pairs through the Storage API. The function removes only registry rows; it cannot delete storage objects itself.
- **Beat catalog audio** (ingested reference beats) is retained indefinitely — it is the search index, not user data.
- No personal data beyond an optional `created_by` user id is stored with queries or feedback events.

## Backup and rollback

- **Backup**: Supabase provides daily automated Postgres backups on paid tiers; additionally run `supabase db dump -f backup.sql` (or `pg_dump`) before applying new migrations. Storage buckets should be replicated with `supabase storage cp -r` or a scheduled export if beat audio is not reproducible.
- **Rollback strategy**: migrations are additive-only (new tables, new columns, new functions). Rolling back application code is always safe against a newer schema. To roll back a schema change, restore from the pre-migration dump rather than writing down-migrations — the additive style keeps this a rare event.
- **Local mode**: the entire state is the `BEATFINDER_STATE_DIR` directory; copying it is a complete backup.

## Adapter contract

All three adapters implement `backend/storage/base.py:BeatStore`. Contract and parity are covered by:

- `backend/tests/test_storage_adapter_parity.py` — candidate-generation parity
- `backend/tests/test_production_storage.py` — runtime mode selection, missing-configuration failures, migration structure, uploaded-asset registration
- `backend/tests/test_supabase_primary_integration.py` — live integration (skips without credentials)
