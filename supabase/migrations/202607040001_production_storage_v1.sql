-- Production storage v1: uploaded asset registry and retention support.
-- Idempotent: safe to run repeatedly.

create table if not exists public.uploaded_audio_assets (
  id uuid primary key default gen_random_uuid(),
  category text not null default 'queries',
  bucket text not null,
  object_path text not null,
  original_file_name text,
  mime_type text,
  byte_size bigint,
  created_by uuid,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create unique index if not exists uploaded_audio_assets_bucket_object_idx
  on public.uploaded_audio_assets (bucket, object_path);

create index if not exists uploaded_audio_assets_expires_at_idx
  on public.uploaded_audio_assets (expires_at)
  where expires_at is not null;

create index if not exists queries_created_at_idx
  on public.queries (created_at);

create index if not exists feedback_events_query_id_idx
  on public.feedback_events (query_id);

-- Removes expired uploaded-audio registry rows and reports what should also
-- be deleted from Storage. Storage objects themselves must be removed through
-- the Storage API by the maintenance job that calls this function.
create or replace function public.purge_expired_query_audio()
returns table (bucket text, object_path text)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  delete from public.uploaded_audio_assets a
  where a.expires_at is not null
    and a.expires_at < now()
  returning a.bucket, a.object_path;
end;
$$;

alter table public.uploaded_audio_assets enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'uploaded_audio_assets'
      and policyname = 'service_role_full_access'
  ) then
    create policy service_role_full_access on public.uploaded_audio_assets
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end
$$;
