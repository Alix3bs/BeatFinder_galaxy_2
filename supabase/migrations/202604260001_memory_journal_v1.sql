-- BeatFinder-adjacent public-data memory/journal subsystem.
-- This schema is paper-trading compatible only. It stores research, signals,
-- risk notes, journal entries, reviews, and feedback; it does not model or
-- authorize live order execution.

create extension if not exists pgcrypto;

create table if not exists journal_signal_records (
  id uuid primary key default gen_random_uuid(),
  symbol text not null,
  asset_class text not null default 'equity',
  timeframe text not null default '1d',
  signal_type text not null,
  direction text not null,
  confidence numeric not null check (confidence >= 0 and confidence <= 1),
  source text not null,
  strategy_id text,
  observed_at timestamptz not null,
  features jsonb not null default '{}',
  tags text[] not null default '{}',
  public_data_sources text[] not null default '{}',
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  created_at timestamptz not null default now()
);

create table if not exists journal_risk_records (
  id uuid primary key default gen_random_uuid(),
  symbol text not null,
  strategy_id text,
  risk_score numeric not null check (risk_score >= 0 and risk_score <= 1),
  max_loss_r numeric,
  position_size_r numeric,
  stop_loss numeric,
  invalidation text not null,
  liquidity_notes text,
  correlation_notes text,
  public_data_sources text[] not null default '{}',
  account_mode text not null default 'paper' check (account_mode = 'paper'),
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  created_at timestamptz not null default now()
);

create table if not exists journal_trade_entries (
  trade_id uuid primary key default gen_random_uuid(),
  symbol text not null,
  asset_class text not null default 'equity',
  strategy_id text not null,
  setup_name text not null,
  direction text not null,
  market_session text,
  thesis text not null,
  planned_entry numeric not null,
  planned_stop numeric not null,
  planned_target numeric not null,
  actual_entry numeric,
  actual_exit numeric,
  quantity numeric,
  risk_amount numeric,
  reward_risk_ratio numeric,
  invalidation text not null,
  entry_at timestamptz,
  exit_at timestamptz,
  status text not null default 'planned'
    check (status in ('planned', 'open', 'closed', 'cancelled', 'reviewed')),
  execution_notes text,
  market_context text,
  research_notes text,
  setup_snapshot jsonb not null default '{}',
  tags text[] not null default '{}',
  linked_signal_ids uuid[] not null default '{}',
  linked_risk_ids uuid[] not null default '{}',
  public_data_sources text[] not null default '{}',
  account_mode text not null default 'paper' check (account_mode = 'paper'),
  execution_mode text not null default 'none' check (execution_mode in ('none', 'paper')),
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists journal_post_trade_reviews (
  id uuid primary key default gen_random_uuid(),
  trade_id uuid not null references journal_trade_entries(trade_id) on delete cascade,
  outcome text not null check (outcome in ('win', 'loss', 'breakeven', 'scratch')),
  pnl_r numeric not null,
  followed_plan boolean not null,
  mistake_tags text[] not null default '{}',
  strength_tags text[] not null default '{}',
  max_adverse_excursion_r numeric,
  max_favorable_excursion_r numeric,
  entry_quality_score numeric check (entry_quality_score is null or entry_quality_score between 0 and 1),
  exit_quality_score numeric check (exit_quality_score is null or exit_quality_score between 0 and 1),
  risk_management_score numeric check (risk_management_score is null or risk_management_score between 0 and 1),
  what_worked text,
  what_failed text,
  lesson text,
  next_action text,
  review_notes text,
  public_data_sources text[] not null default '{}',
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  created_at timestamptz not null default now()
);

create table if not exists journal_memory_items (
  id uuid primary key default gen_random_uuid(),
  memory_type text not null,
  content text not null,
  summary text,
  evidence text[] not null default '{}',
  symbol text,
  strategy_id text,
  tags text[] not null default '{}',
  source_type text not null default 'research_note',
  source_title text,
  source_url text,
  source_published_at timestamptz,
  source_reliability text not null default 'unrated',
  public_data_sources text[] not null default '{}',
  importance numeric not null default 0.5 check (importance between 0 and 1),
  confidence numeric not null default 0.5 check (confidence between 0 and 1),
  embedding_text text,
  status text not null default 'active' check (status in ('active', 'archived', 'expired')),
  expires_at timestamptz,
  archived_at timestamptz,
  archive_reason text,
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  paper_trading_only boolean not null default true check (paper_trading_only = true),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists journal_memory_links (
  id uuid primary key default gen_random_uuid(),
  memory_id uuid not null references journal_memory_items(id) on delete cascade,
  record_type text not null check (record_type in ('signal', 'risk', 'trade', 'review', 'feedback')),
  record_id uuid not null,
  relation text not null,
  strength numeric not null default 1 check (strength between 0 and 1),
  created_at timestamptz not null default now(),
  unique (memory_id, record_type, record_id, relation)
);

create table if not exists journal_feedback_events (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('signal', 'risk', 'trade', 'review', 'memory_item', 'asset_profile', 'strategy_profile')),
  target_id text not null,
  event_type text not null,
  source text not null,
  score_delta numeric,
  risk_delta numeric,
  notes text,
  public_data_sources text[] not null default '{}',
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  created_at timestamptz not null default now()
);

create table if not exists journal_asset_memory_profiles (
  symbol text primary key,
  asset_class text not null default 'equity',
  recurring_patterns text[] not null default '{}',
  risk_notes text[] not null default '{}',
  strategy_fit jsonb not null default '{}',
  trade_count integer not null default 0,
  win_rate numeric not null default 0,
  average_pnl_r numeric not null default 0,
  last_reviewed_at timestamptz,
  public_data_sources text[] not null default '{}',
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  updated_at timestamptz not null default now()
);

create table if not exists journal_strategy_memory_profiles (
  strategy_id text primary key,
  strategy_name text not null,
  setup_tags text[] not null default '{}',
  strengths text[] not null default '{}',
  failure_modes text[] not null default '{}',
  market_conditions text[] not null default '{}',
  risk_notes text[] not null default '{}',
  trade_count integer not null default 0,
  win_rate numeric not null default 0,
  average_pnl_r numeric not null default 0,
  last_reviewed_at timestamptz,
  public_data_sources text[] not null default '{}',
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  updated_at timestamptz not null default now()
);

create table if not exists journal_weekly_reviews (
  id uuid primary key default gen_random_uuid(),
  period_start date not null,
  period_end date not null,
  trade_count integer not null default 0,
  win_rate numeric not null default 0,
  total_pnl_r numeric not null default 0,
  average_pnl_r numeric not null default 0,
  top_strengths text[] not null default '{}',
  recurring_mistakes text[] not null default '{}',
  risk_alerts text[] not null default '{}',
  asset_highlights jsonb not null default '{}',
  strategy_highlights jsonb not null default '{}',
  action_items text[] not null default '{}',
  source_trade_ids uuid[] not null default '{}',
  feedback_event_ids uuid[] not null default '{}',
  data_scope text not null default 'public_only' check (data_scope = 'public_only'),
  created_at timestamptz not null default now(),
  unique (period_start, period_end)
);

create index if not exists idx_journal_signal_symbol on journal_signal_records(symbol);
create index if not exists idx_journal_signal_strategy on journal_signal_records(strategy_id);
create index if not exists idx_journal_signal_tags on journal_signal_records using gin(tags);

create index if not exists idx_journal_risk_symbol on journal_risk_records(symbol);
create index if not exists idx_journal_risk_strategy on journal_risk_records(strategy_id);

create index if not exists idx_journal_trade_symbol on journal_trade_entries(symbol);
create index if not exists idx_journal_trade_strategy on journal_trade_entries(strategy_id);
create index if not exists idx_journal_trade_status on journal_trade_entries(status);
create index if not exists idx_journal_trade_tags on journal_trade_entries using gin(tags);

create index if not exists idx_journal_review_trade on journal_post_trade_reviews(trade_id);
create index if not exists idx_journal_review_mistakes on journal_post_trade_reviews using gin(mistake_tags);
create index if not exists idx_journal_review_strengths on journal_post_trade_reviews using gin(strength_tags);

create index if not exists idx_journal_memory_symbol_strategy on journal_memory_items(symbol, strategy_id);
create index if not exists idx_journal_memory_status_expires on journal_memory_items(status, expires_at);
create index if not exists idx_journal_memory_tags on journal_memory_items using gin(tags);
create index if not exists idx_journal_memory_evidence on journal_memory_items using gin(evidence);
create index if not exists idx_journal_memory_links_target on journal_memory_links(record_type, record_id);

create index if not exists idx_journal_feedback_target on journal_feedback_events(target_type, target_id);
create index if not exists idx_journal_feedback_event_type on journal_feedback_events(event_type);

create or replace function archive_expired_journal_memory(p_now timestamptz default now())
returns integer
language plpgsql
as $$
declare
  affected integer;
begin
  update journal_memory_items
  set
    status = 'expired',
    archived_at = p_now,
    archive_reason = coalesce(archive_reason, 'expired'),
    updated_at = p_now
  where status = 'active'
    and expires_at is not null
    and expires_at <= p_now;

  get diagnostics affected = row_count;
  return affected;
end;
$$;
