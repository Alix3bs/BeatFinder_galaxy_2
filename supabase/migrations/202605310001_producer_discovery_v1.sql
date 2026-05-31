create table if not exists public.producer_channels (
  id uuid primary key default gen_random_uuid(),
  platform text not null default 'youtube',
  channel_id text not null,
  channel_url text not null,
  producer_name text not null,
  aliases text[] not null default '{}',
  city_tags text[] not null default '{}',
  style_tags text[] not null default '{}',
  discovered_from text,
  confidence numeric not null default 1.0,
  first_seen_at timestamptz not null default now(),
  last_scanned_at timestamptz,
  unique (platform, channel_id)
);

create table if not exists public.producer_beat_videos (
  id uuid primary key default gen_random_uuid(),
  producer_channel_id uuid not null references public.producer_channels(id) on delete cascade,
  video_id text not null,
  video_url text not null,
  title text not null,
  description text,
  upload_date date,
  hashtags text[] not null default '{}',
  normalized_search_phrases text[] not null default '{}',
  artist_refs text[] not null default '{}',
  artist_combo_refs text[] not null default '{}',
  producer_refs text[] not null default '{}',
  producer_combo_refs text[] not null default '{}',
  city_tags text[] not null default '{}',
  region_tags text[] not null default '{}',
  style_tags text[] not null default '{}',
  type_beat_phrases text[] not null default '{}',
  beat_store_links text[] not null default '{}',
  audio_signature_status text not null default 'not_processed',
  visibility_status text not null default 'public',
  last_seen_at timestamptz not null default now(),
  unique (producer_channel_id, video_id)
);

create table if not exists public.discovery_seeds (
  id uuid primary key default gen_random_uuid(),
  seed_type text not null,
  seed_value text not null,
  source text not null,
  priority integer not null default 50,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  unique (seed_type, seed_value)
);

create table if not exists public.discovery_edges (
  id uuid primary key default gen_random_uuid(),
  from_type text not null,
  from_id text not null,
  to_type text not null,
  to_id text not null,
  relation text not null,
  confidence numeric not null default 0,
  evidence jsonb not null default '{}'::jsonb
);

create table if not exists public.discovery_checkpoints (
  producer_channel_id uuid primary key references public.producer_channels(id) on delete cascade,
  page_token text,
  completed boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.possible_sold_or_deleted_beats (
  id uuid primary key default gen_random_uuid(),
  detected_producer_tag text not null,
  matched_producer_channel_id uuid not null references public.producer_channels(id) on delete cascade,
  query_audio_id text,
  nearest_candidates jsonb not null default '[]'::jsonb,
  evidence jsonb not null default '{}'::jsonb,
  confidence numeric not null default 0,
  possible_reasons text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists idx_producer_channels_aliases on public.producer_channels using gin (aliases);
create index if not exists idx_producer_channels_city_tags on public.producer_channels using gin (city_tags);
create index if not exists idx_producer_channels_style_tags on public.producer_channels using gin (style_tags);
create index if not exists idx_producer_beat_videos_channel_seen on public.producer_beat_videos(producer_channel_id, last_seen_at desc);
create index if not exists idx_producer_beat_videos_video_id on public.producer_beat_videos(video_id);
create index if not exists idx_producer_beat_videos_title_trgm on public.producer_beat_videos using gin (title gin_trgm_ops);
create index if not exists idx_producer_beat_videos_hashtags on public.producer_beat_videos using gin (hashtags);
create index if not exists idx_producer_beat_videos_artist_combo_refs on public.producer_beat_videos using gin (artist_combo_refs);
create index if not exists idx_producer_beat_videos_city_tags on public.producer_beat_videos using gin (city_tags);
create index if not exists idx_producer_beat_videos_region_tags on public.producer_beat_videos using gin (region_tags);
create index if not exists idx_producer_beat_videos_style_tags on public.producer_beat_videos using gin (style_tags);
create index if not exists idx_discovery_seeds_status_priority on public.discovery_seeds(status, priority, created_at);
create index if not exists idx_possible_sold_or_deleted_channel on public.possible_sold_or_deleted_beats(matched_producer_channel_id, created_at desc);
