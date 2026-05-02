create extension if not exists pgcrypto;
create extension if not exists vector;
create extension if not exists pg_trgm;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.beats (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  raw_title text not null,
  canonical_title text,
  producer_name text,
  source_url text,
  source_platform text,
  cover_art_url text,
  bpm numeric,
  musical_key text,
  duration_seconds numeric,
  genre_tags text[] not null default '{}',
  region_tags text[] not null default '{}',
  hashtags text[] not null default '{}',
  artist_refs text[] not null default '{}',
  artist_combo_refs text[] not null default '{}',
  producer_combo_refs text[] not null default '{}',
  type_beat_phrases text[] not null default '{}',
  normalized_search_phrases text[] not null default '{}',
  audio_storage_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.beat_embeddings (
  id uuid primary key default gen_random_uuid(),
  beat_id uuid not null references public.beats(id) on delete cascade,
  model_name text not null,
  embedding vector(192),
  embedding_version text,
  created_at timestamptz not null default now()
);

create table if not exists public.beat_signatures (
  id uuid primary key default gen_random_uuid(),
  beat_id uuid not null references public.beats(id) on delete cascade,
  signature_type text not null,
  signature_payload jsonb not null,
  signature_version text,
  created_at timestamptz not null default now()
);

create table if not exists public.queries (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  query_type text not null check (query_type in ('audio', 'text', 'hybrid')),
  raw_text text,
  audio_storage_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.query_results (
  id uuid primary key default gen_random_uuid(),
  query_id uuid not null references public.queries(id) on delete cascade,
  beat_id uuid not null references public.beats(id) on delete cascade,
  embedding_score numeric,
  signature_score numeric,
  metadata_score numeric,
  rerank_score numeric not null,
  score_breakdown jsonb not null,
  rank integer not null,
  created_at timestamptz not null default now()
);

create table if not exists public.feedback_events (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  query_id uuid not null references public.queries(id) on delete cascade,
  beat_id uuid not null references public.beats(id) on delete cascade,
  event_type text not null check (event_type in ('clicked', 'saved', 'confirmed_match', 'rejected')),
  created_at timestamptz not null default now()
);

drop trigger if exists beats_set_updated_at on public.beats;
create trigger beats_set_updated_at
before update on public.beats
for each row
execute function public.set_updated_at();

create index if not exists idx_beats_created_at on public.beats(created_at desc);
create index if not exists idx_beats_raw_title_trgm on public.beats using gin (raw_title gin_trgm_ops);
create index if not exists idx_beats_canonical_title_trgm on public.beats using gin (canonical_title gin_trgm_ops);
create index if not exists idx_beats_hashtags on public.beats using gin (hashtags);
create index if not exists idx_beats_artist_refs on public.beats using gin (artist_refs);
create index if not exists idx_beats_artist_combo_refs on public.beats using gin (artist_combo_refs);
create index if not exists idx_beats_producer_combo_refs on public.beats using gin (producer_combo_refs);
create index if not exists idx_beats_region_tags on public.beats using gin (region_tags);
create index if not exists idx_beats_genre_tags on public.beats using gin (genre_tags);
create index if not exists idx_beats_type_beat_phrases on public.beats using gin (type_beat_phrases);
create index if not exists idx_beats_normalized_search_phrases on public.beats using gin (normalized_search_phrases);
create index if not exists idx_beat_embeddings_beat_model on public.beat_embeddings(beat_id, model_name);
create index if not exists idx_beat_embeddings_embedding_hnsw on public.beat_embeddings using hnsw (embedding vector_cosine_ops);
create index if not exists idx_beat_signatures_beat_type on public.beat_signatures(beat_id, signature_type);
create index if not exists idx_queries_created_at on public.queries(created_at desc);
create index if not exists idx_query_results_query_rank on public.query_results(query_id, rank);
create index if not exists idx_feedback_events_query on public.feedback_events(query_id);

create or replace function public.jsonb_to_vector_192(p_json jsonb)
returns vector(192)
language sql
immutable
as $$
  select
    case
      when p_json is null or jsonb_typeof(p_json) <> 'array' then null
      else ('[' || string_agg(e.value, ',') || ']')::vector(192)
    end
  from jsonb_array_elements_text(p_json) as e(value)
$$;

create or replace function public.match_beat_embeddings(
  query_embedding jsonb,
  embedding_model text,
  match_count integer default 20
)
returns table (
  beat_id uuid,
  model_name text,
  similarity double precision
)
language sql
stable
security invoker
set search_path = public
as $$
  with q as (
    select public.jsonb_to_vector_192(query_embedding) as embedding
  )
  select
    be.beat_id,
    be.model_name,
    greatest(0::double precision, 1 - (be.embedding <=> q.embedding)) as similarity
  from public.beat_embeddings be
  cross join q
  where q.embedding is not null
    and be.embedding is not null
    and be.model_name = embedding_model
  order by be.embedding <=> q.embedding asc
  limit greatest(1, least(match_count, 50))
$$;

create or replace function public.search_beats_by_metadata_term(
  query_text text,
  match_count integer default 20
)
returns table (
  beat_id uuid,
  metadata_score real
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    b.id as beat_id,
    greatest(
      similarity(coalesce(b.raw_title, ''), coalesce(query_text, '')),
      similarity(coalesce(b.canonical_title, ''), coalesce(query_text, '')),
      similarity(array_to_string(b.normalized_search_phrases, ' '), coalesce(query_text, ''))
    )::real as metadata_score
  from public.beats b
  where coalesce(query_text, '') <> ''
  order by metadata_score desc, b.created_at desc
  limit greatest(1, least(match_count, 50))
$$;

insert into storage.buckets (id, name, public)
values ('beat-audio', 'beat-audio', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('query-audio', 'query-audio', false)
on conflict (id) do nothing;
