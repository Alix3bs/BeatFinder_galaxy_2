-- Lock the retrieval schema: only the backend (service role, which bypasses
-- RLS) may touch these tables. Client publishable keys get no access.
-- Idempotent: enabling RLS twice is a no-op.
do $$
declare
  t text;
begin
  foreach t in array array[
    'beats', 'beat_embeddings', 'beat_signatures', 'queries', 'query_results',
    'feedback_events', 'producer_channels', 'producer_beat_videos',
    'discovery_seeds', 'discovery_edges', 'discovery_checkpoints',
    'possible_sold_or_deleted_beats', 'legacy_beats_prototype'
  ]
  loop
    if exists (
      select 1 from information_schema.tables
      where table_schema = 'public' and table_name = t
    ) then
      execute format('alter table public.%I enable row level security', t);
    end if;
  end loop;
end
$$;

-- Pin search_path on the v1 helper functions (advisor: mutable search_path).
alter function public.set_updated_at() set search_path = public;
alter function public.jsonb_to_vector_384(jsonb) set search_path = public, extensions;
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'pad_vector_192_to_384') then
    execute 'alter function public.pad_vector_192_to_384(extensions.vector) set search_path = public, extensions';
  end if;
end
$$;
