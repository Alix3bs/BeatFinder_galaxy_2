alter table if exists public.beats
  add column if not exists producer_aliases text[] not null default '{}',
  add column if not exists audio_features jsonb not null default '{}'::jsonb;

create or replace function public.pad_vector_192_to_384(input_vector vector(192))
returns vector(384)
language sql
immutable
as $$
  select
    case
      when input_vector is null then null
      else ('[' || trim(both '[]' from input_vector::text) || repeat(',0', 192) || ']')::vector(384)
    end
$$;

do $$
declare
  embedding_type text;
begin
  select format_type(a.atttypid, a.atttypmod)
  into embedding_type
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'beat_embeddings'
    and a.attname = 'embedding'
    and not a.attisdropped;

  if embedding_type = 'vector(192)' then
    drop index if exists public.idx_beat_embeddings_embedding_hnsw;

    alter table public.beat_embeddings
      alter column embedding type vector(384)
      using public.pad_vector_192_to_384(embedding);

    create index if not exists idx_beat_embeddings_embedding_hnsw
    on public.beat_embeddings using hnsw (embedding vector_cosine_ops);
  elsif embedding_type = 'vector(384)' then
    create index if not exists idx_beat_embeddings_embedding_hnsw
    on public.beat_embeddings using hnsw (embedding vector_cosine_ops);
  elsif embedding_type is not null then
    raise exception 'Unexpected beat_embeddings.embedding type: %', embedding_type;
  end if;
end
$$;

drop function if exists public.jsonb_to_vector_192(jsonb);

create or replace function public.jsonb_to_vector_384(p_json jsonb)
returns vector(384)
language sql
immutable
as $$
  select
    case
      when p_json is null or jsonb_typeof(p_json) <> 'array' then null
      else ('[' || string_agg(e.value, ',') || ']')::vector(384)
    end
  from jsonb_array_elements_text(p_json) as e(value)
$$;

drop function if exists public.match_beat_embeddings(jsonb, text, integer);

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
set search_path = public, extensions
as $$
  with q as (
    select public.jsonb_to_vector_384(query_embedding) as embedding
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
