# Memory Journal Subsystem

This subsystem stores public-data research memory, paper trade journal entries, post-trade reviews, scoring/risk feedback, asset profiles, strategy profiles, and weekly reviews.

It is deliberately **not** a live execution system:

- `account_mode` is constrained to `paper`
- `execution_mode` is constrained to `none` or paper-only notes
- `data_scope` is constrained to `public_only`
- no broker credentials, private account data, live orders, or live portfolio state are modeled

## What It Fixes

- Strong memory links: `JournalMemoryLink` connects memory items to signal, risk, trade, review, and feedback records with relation labels and strengths.
- Trade journal fields: entries include planned/actual prices, risk, invalidation, setup snapshot, market context, research notes, linked signal/risk ids, and public data sources.
- Post-trade review structure: reviews include outcome, PnL in R, plan adherence, MAE/MFE, quality scores, mistakes, strengths, lessons, and next actions.
- Feedback events: scoring and risk feedback can target signals, risks, trades, reviews, memories, assets, or strategies.
- Asset and strategy memory profiles: profiles aggregate recurring patterns, risk notes, win rate, average PnL in R, and strategy fit.
- Weekly review logic: weekly reviews summarize trades, strengths, mistakes, risk alerts, asset highlights, strategy highlights, action items, and feedback ids.
- Retrieval filters: memory retrieval can filter by symbol, strategy, type, tags, linked record type/id, source type, importance, date, query, archive, and expiry state.
- Archive/expiration behavior: expired memories are excluded by default and can be archived with explicit reasons.
- Research/summarization readiness: memory items include summary, evidence, source metadata, source reliability, public data sources, and a public-only context exporter.

## Minimal Usage

```python
from datetime import datetime, timezone

from memory.journal import (
    JournalMemoryItem,
    JournalMemoryLink,
    MemoryFilter,
    MemoryJournal,
    RiskRecord,
    SignalRecord,
)

journal = MemoryJournal()

signal = journal.add_signal(SignalRecord(
    symbol="AAPL",
    signal_type="breakout",
    direction="long",
    confidence=0.72,
    source="public scanner",
    observed_at=datetime.now(timezone.utc),
))

risk = journal.add_risk(RiskRecord(
    symbol="AAPL",
    risk_score=0.64,
    invalidation="Breakout fails below VWAP.",
))

journal.add_memory_item(JournalMemoryItem(
    memory_type="setup_note",
    symbol="AAPL",
    content="Opening range breakout needs volume confirmation.",
    links=[
        JournalMemoryLink("signal", signal.id, "supports", 0.9),
        JournalMemoryLink("risk", risk.id, "constrains", 0.8),
    ],
    tags=["breakout", "volume"],
))

results = journal.retrieve_memory_items(MemoryFilter(
    symbol="AAPL",
    linked_record_types=["signal"],
    query="volume breakout",
))
```

## Supabase

The migration `supabase/migrations/202604260001_memory_journal_v1.sql` creates:

- `journal_signal_records`
- `journal_risk_records`
- `journal_trade_entries`
- `journal_post_trade_reviews`
- `journal_memory_items`
- `journal_memory_links`
- `journal_feedback_events`
- `journal_asset_memory_profiles`
- `journal_strategy_memory_profiles`
- `journal_weekly_reviews`

The SQL schema mirrors the Python models but keeps this subsystem separate from BeatFinder's audio retrieval tables.

## Example Outputs

See:

- `memory/journal/examples/paper_trade_review.json`
- `memory/journal/examples/weekly_review.json`
- `memory/journal/examples/research_context.json`

