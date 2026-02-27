-- Beats index schema for semantic + fingerprint search.

create extension if not exists vector;
create extension if not exists pg_trgm;

create table if not exists public.beats (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'unknown',
  title text not null,
  source_url text not null,
  bpm integer,
  key text,
  embedding vector(1536),
  created_at timestamptz not null default now()
);

create table if not exists public.beat_fingerprints (
  id uuid primary key default gen_random_uuid(),
  beat_id uuid not null references public.beats(id) on delete cascade,
  fingerprint_hash text not null,
  algorithm text not null default 'sha256',
  created_at timestamptz not null default now()
);

create index if not exists idx_beats_created_at on public.beats(created_at desc);
create index if not exists idx_beats_owner on public.beats(owner_user_id);
create index if not exists idx_beats_embedding_cosine on public.beats using ivfflat (embedding vector_cosine_ops) with (lists = 100);
create index if not exists idx_beat_fingerprints_hash on public.beat_fingerprints(fingerprint_hash);

create unique index if not exists idx_beat_fingerprints_unique
  on public.beat_fingerprints(beat_id, fingerprint_hash, algorithm);

grant select, insert, update, delete on public.beats to authenticated;
grant select, insert, update, delete on public.beat_fingerprints to authenticated;

alter table public.beats enable row level security;
alter table public.beat_fingerprints enable row level security;

drop policy if exists "beats_select_authenticated" on public.beats;
create policy "beats_select_authenticated"
on public.beats
for select
to authenticated
using (true);

drop policy if exists "beats_insert_owner" on public.beats;
create policy "beats_insert_owner"
on public.beats
for insert
to authenticated
with check (auth.uid() = owner_user_id);

drop policy if exists "beats_update_owner" on public.beats;
create policy "beats_update_owner"
on public.beats
for update
to authenticated
using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);

drop policy if exists "beats_delete_owner" on public.beats;
create policy "beats_delete_owner"
on public.beats
for delete
to authenticated
using (auth.uid() = owner_user_id);

drop policy if exists "beat_fingerprints_select_authenticated" on public.beat_fingerprints;
create policy "beat_fingerprints_select_authenticated"
on public.beat_fingerprints
for select
to authenticated
using (true);

drop policy if exists "beat_fingerprints_insert_owner" on public.beat_fingerprints;
create policy "beat_fingerprints_insert_owner"
on public.beat_fingerprints
for insert
to authenticated
with check (
  exists (
    select 1
    from public.beats b
    where b.id = beat_fingerprints.beat_id
      and b.owner_user_id = auth.uid()
  )
);

drop policy if exists "beat_fingerprints_update_owner" on public.beat_fingerprints;
create policy "beat_fingerprints_update_owner"
on public.beat_fingerprints
for update
to authenticated
using (
  exists (
    select 1
    from public.beats b
    where b.id = beat_fingerprints.beat_id
      and b.owner_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.beats b
    where b.id = beat_fingerprints.beat_id
      and b.owner_user_id = auth.uid()
  )
);

drop policy if exists "beat_fingerprints_delete_owner" on public.beat_fingerprints;
create policy "beat_fingerprints_delete_owner"
on public.beat_fingerprints
for delete
to authenticated
using (
  exists (
    select 1
    from public.beats b
    where b.id = beat_fingerprints.beat_id
      and b.owner_user_id = auth.uid()
  )
);

alter table public.saved_matches
  add column if not exists beat_id uuid references public.beats(id) on delete cascade;

alter table public.saved_matches
  alter column match_id drop not null;

create unique index if not exists idx_saved_matches_user_beat_unique
  on public.saved_matches(user_id, beat_id)
  where beat_id is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'saved_matches_match_or_beat_required'
  ) then
    alter table public.saved_matches
      add constraint saved_matches_match_or_beat_required
      check (match_id is not null or beat_id is not null);
  end if;
end
$$;

create or replace function public.jsonb_to_vector_1536(p_json jsonb)
returns vector(1536)
language sql
immutable
as $$
  select
    case
      when p_json is null or jsonb_typeof(p_json) <> 'array' then null
      else ('[' || string_agg(e.value, ',') || ']')::vector(1536)
    end
  from jsonb_array_elements_text(p_json) as e(value)
$$;

drop function if exists public.search_beats_by_embedding(jsonb, integer, double precision);
create function public.search_beats_by_embedding(
  query_embedding jsonb,
  match_count integer default 20,
  min_similarity double precision default 0
)
returns table (
  beat_id uuid,
  title text,
  platform text,
  url text,
  bpm integer,
  key text,
  similarity double precision
)
language sql
stable
security invoker
set search_path = public
as $$
  with q as (
    select public.jsonb_to_vector_1536(query_embedding) as embedding
  )
  select
    b.id as beat_id,
    b.title,
    b.platform,
    b.source_url as url,
    b.bpm,
    b.key,
    greatest(0::double precision, 1 - (b.embedding <=> q.embedding)) as similarity
  from public.beats b
  cross join q
  where q.embedding is not null
    and b.embedding is not null
    and (1 - (b.embedding <=> q.embedding)) >= min_similarity
  order by b.embedding <=> q.embedding asc
  limit greatest(1, least(match_count, 50))
$$;

grant execute on function public.search_beats_by_embedding(jsonb, integer, double precision) to authenticated;

drop function if exists public.search_beats_by_fingerprint_hash(text, integer);
create function public.search_beats_by_fingerprint_hash(
  query_hash text,
  match_count integer default 20
)
returns table (
  beat_id uuid,
  title text,
  platform text,
  url text,
  bpm integer,
  key text,
  similarity double precision
)
language sql
stable
security invoker
set search_path = public
as $$
  with n as (
    select lower(trim(coalesce(query_hash, ''))) as hash
  ),
  ranked as (
    select
      b.id as beat_id,
      b.title,
      b.platform,
      b.source_url as url,
      b.bpm,
      b.key,
      case
        when lower(f.fingerprint_hash) = n.hash then 1::double precision
        else similarity(lower(f.fingerprint_hash), n.hash)::double precision
      end as similarity
    from public.beat_fingerprints f
    join public.beats b on b.id = f.beat_id
    cross join n
    where n.hash <> ''
      and (
        lower(f.fingerprint_hash) = n.hash
        or similarity(lower(f.fingerprint_hash), n.hash) >= 0.45
      )
  )
  select *
  from ranked
  order by similarity desc, beat_id
  limit greatest(1, least(match_count, 50))
$$;

grant execute on function public.search_beats_by_fingerprint_hash(text, integer) to authenticated;
