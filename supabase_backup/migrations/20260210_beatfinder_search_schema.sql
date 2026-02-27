-- BeatFinder MVP search schema + strict RLS

create extension if not exists pgcrypto;

create table if not exists public.searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  query_type text not null,
  query_text text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  search_id uuid not null references public.searches(id) on delete cascade,
  platform text not null,
  url text not null,
  title text not null,
  similarity double precision not null check (similarity >= 0 and similarity <= 1),
  bpm integer,
  key text,
  created_at timestamptz not null default now()
);

create table if not exists public.saved_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  notes text,
  created_at timestamptz not null default now(),
  unique (user_id, match_id)
);

create index if not exists idx_searches_user_created_at on public.searches(user_id, created_at desc);
create index if not exists idx_matches_search_similarity on public.matches(search_id, similarity desc);
create index if not exists idx_saved_matches_user_created_at on public.saved_matches(user_id, created_at desc);

alter table public.searches enable row level security;
alter table public.matches enable row level security;
alter table public.saved_matches enable row level security;

drop policy if exists "searches_select_own" on public.searches;
create policy "searches_select_own"
on public.searches
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "searches_insert_own" on public.searches;
create policy "searches_insert_own"
on public.searches
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "searches_update_own" on public.searches;
create policy "searches_update_own"
on public.searches
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "searches_delete_own" on public.searches;
create policy "searches_delete_own"
on public.searches
for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists "matches_select_own" on public.matches;
create policy "matches_select_own"
on public.matches
for select
to authenticated
using (
  exists (
    select 1
    from public.searches s
    where s.id = matches.search_id
      and s.user_id = auth.uid()
  )
);

drop policy if exists "matches_insert_own" on public.matches;
create policy "matches_insert_own"
on public.matches
for insert
to authenticated
with check (
  exists (
    select 1
    from public.searches s
    where s.id = matches.search_id
      and s.user_id = auth.uid()
  )
);

drop policy if exists "matches_update_own" on public.matches;
create policy "matches_update_own"
on public.matches
for update
to authenticated
using (
  exists (
    select 1
    from public.searches s
    where s.id = matches.search_id
      and s.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.searches s
    where s.id = matches.search_id
      and s.user_id = auth.uid()
  )
);

drop policy if exists "matches_delete_own" on public.matches;
create policy "matches_delete_own"
on public.matches
for delete
to authenticated
using (
  exists (
    select 1
    from public.searches s
    where s.id = matches.search_id
      and s.user_id = auth.uid()
  )
);

drop policy if exists "saved_matches_select_own" on public.saved_matches;
create policy "saved_matches_select_own"
on public.saved_matches
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "saved_matches_insert_own" on public.saved_matches;
create policy "saved_matches_insert_own"
on public.saved_matches
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "saved_matches_update_own" on public.saved_matches;
create policy "saved_matches_update_own"
on public.saved_matches
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "saved_matches_delete_own" on public.saved_matches;
create policy "saved_matches_delete_own"
on public.saved_matches
for delete
to authenticated
using (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('snippets', 'snippets', false)
on conflict (id) do nothing;

drop policy if exists "avatars_select_own" on storage.objects;
create policy "avatars_select_own"
on storage.objects
for select
to authenticated
using (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
on storage.objects
for update
to authenticated
using (bucket_id = 'avatars' and owner = auth.uid())
with check (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own"
on storage.objects
for delete
to authenticated
using (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists "snippets_select_own" on storage.objects;
create policy "snippets_select_own"
on storage.objects
for select
to authenticated
using (bucket_id = 'snippets' and owner = auth.uid());

drop policy if exists "snippets_insert_own" on storage.objects;
create policy "snippets_insert_own"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'snippets' and owner = auth.uid());

drop policy if exists "snippets_delete_own" on storage.objects;
create policy "snippets_delete_own"
on storage.objects
for delete
to authenticated
using (bucket_id = 'snippets' and owner = auth.uid());

