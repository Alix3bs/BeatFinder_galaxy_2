from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from typing import Any
from uuid import uuid4


PUBLIC_DATA_SCOPE = "public_only"
PAPER_ACCOUNT_MODE = "paper"
NO_LIVE_EXECUTION_MODE = "none"


def new_id() -> str:
    return str(uuid4())


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def normalize_symbol(symbol: str) -> str:
    return symbol.strip().upper()


def normalize_tag(tag: str) -> str:
    return " ".join(tag.strip().lower().split())


@dataclass(slots=True)
class JournalMemoryLink:
    record_type: str
    record_id: str
    relation: str
    strength: float = 1.0
    created_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.record_type = normalize_tag(self.record_type)
        self.relation = normalize_tag(self.relation)
        self.strength = max(0.0, min(1.0, float(self.strength)))


@dataclass(slots=True)
class JournalMemoryItem:
    content: str
    memory_type: str
    symbol: str | None = None
    strategy_id: str | None = None
    tags: list[str] = field(default_factory=list)
    links: list[JournalMemoryLink] = field(default_factory=list)
    summary: str | None = None
    evidence: list[str] = field(default_factory=list)
    source_type: str = "research_note"
    source_title: str | None = None
    source_url: str | None = None
    source_published_at: datetime | None = None
    source_reliability: str = "unrated"
    public_data_sources: list[str] = field(default_factory=list)
    importance: float = 0.5
    confidence: float = 0.5
    status: str = "active"
    expires_at: datetime | None = None
    archived_at: datetime | None = None
    archive_reason: str | None = None
    data_scope: str = PUBLIC_DATA_SCOPE
    paper_trading_only: bool = True
    id: str = field(default_factory=new_id)
    created_at: datetime = field(default_factory=utc_now)
    updated_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.memory_type = normalize_tag(self.memory_type)
        self.source_type = normalize_tag(self.source_type)
        self.symbol = normalize_symbol(self.symbol) if self.symbol else None
        self.strategy_id = normalize_tag(self.strategy_id) if self.strategy_id else None
        self.tags = sorted({normalize_tag(tag) for tag in self.tags if tag.strip()})
        self.importance = max(0.0, min(1.0, float(self.importance)))
        self.confidence = max(0.0, min(1.0, float(self.confidence)))

    @property
    def linked_signal_ids(self) -> list[str]:
        return [link.record_id for link in self.links if link.record_type == "signal"]

    @property
    def linked_risk_ids(self) -> list[str]:
        return [link.record_id for link in self.links if link.record_type == "risk"]

    def is_expired(self, now: datetime | None = None) -> bool:
        check_time = now or utc_now()
        return self.expires_at is not None and self.expires_at <= check_time

    def retrieval_text(self) -> str:
        parts = [
            self.content,
            self.summary or "",
            self.symbol or "",
            self.strategy_id or "",
            " ".join(self.tags),
            " ".join(self.evidence),
            self.source_title or "",
        ]
        return " ".join(part for part in parts if part).lower()


@dataclass(slots=True)
class SignalRecord:
    symbol: str
    signal_type: str
    direction: str
    confidence: float
    source: str
    observed_at: datetime
    asset_class: str = "equity"
    timeframe: str = "1d"
    strategy_id: str | None = None
    features: dict[str, Any] = field(default_factory=dict)
    tags: list[str] = field(default_factory=list)
    public_data_sources: list[str] = field(default_factory=list)
    data_scope: str = PUBLIC_DATA_SCOPE
    id: str = field(default_factory=new_id)
    created_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.symbol = normalize_symbol(self.symbol)
        self.signal_type = normalize_tag(self.signal_type)
        self.direction = normalize_tag(self.direction)
        self.strategy_id = normalize_tag(self.strategy_id) if self.strategy_id else None
        self.tags = sorted({normalize_tag(tag) for tag in self.tags if tag.strip()})
        self.confidence = max(0.0, min(1.0, float(self.confidence)))


@dataclass(slots=True)
class RiskRecord:
    symbol: str
    risk_score: float
    invalidation: str
    max_loss_r: float | None = None
    position_size_r: float | None = None
    stop_loss: float | None = None
    liquidity_notes: str | None = None
    correlation_notes: str | None = None
    strategy_id: str | None = None
    public_data_sources: list[str] = field(default_factory=list)
    account_mode: str = PAPER_ACCOUNT_MODE
    data_scope: str = PUBLIC_DATA_SCOPE
    id: str = field(default_factory=new_id)
    created_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.symbol = normalize_symbol(self.symbol)
        self.strategy_id = normalize_tag(self.strategy_id) if self.strategy_id else None
        self.risk_score = max(0.0, min(1.0, float(self.risk_score)))


@dataclass(slots=True)
class TradeJournalEntry:
    symbol: str
    strategy_id: str
    setup_name: str
    direction: str
    thesis: str
    planned_entry: float
    planned_stop: float
    planned_target: float
    invalidation: str
    trade_id: str = field(default_factory=new_id)
    asset_class: str = "equity"
    market_session: str | None = None
    actual_entry: float | None = None
    actual_exit: float | None = None
    quantity: float | None = None
    risk_amount: float | None = None
    reward_risk_ratio: float | None = None
    entry_at: datetime | None = None
    exit_at: datetime | None = None
    status: str = "planned"
    execution_notes: str | None = None
    market_context: str | None = None
    research_notes: str | None = None
    setup_snapshot: dict[str, Any] = field(default_factory=dict)
    tags: list[str] = field(default_factory=list)
    linked_signal_ids: list[str] = field(default_factory=list)
    linked_risk_ids: list[str] = field(default_factory=list)
    public_data_sources: list[str] = field(default_factory=list)
    account_mode: str = PAPER_ACCOUNT_MODE
    execution_mode: str = NO_LIVE_EXECUTION_MODE
    data_scope: str = PUBLIC_DATA_SCOPE
    created_at: datetime = field(default_factory=utc_now)
    updated_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.symbol = normalize_symbol(self.symbol)
        self.strategy_id = normalize_tag(self.strategy_id)
        self.setup_name = normalize_tag(self.setup_name)
        self.direction = normalize_tag(self.direction)
        self.status = normalize_tag(self.status)
        self.tags = sorted({normalize_tag(tag) for tag in self.tags if tag.strip()})


@dataclass(slots=True)
class PostTradeReview:
    trade_id: str
    outcome: str
    pnl_r: float
    followed_plan: bool
    mistake_tags: list[str] = field(default_factory=list)
    strength_tags: list[str] = field(default_factory=list)
    max_adverse_excursion_r: float | None = None
    max_favorable_excursion_r: float | None = None
    exit_quality_score: float | None = None
    entry_quality_score: float | None = None
    risk_management_score: float | None = None
    what_worked: str | None = None
    what_failed: str | None = None
    lesson: str | None = None
    next_action: str | None = None
    review_notes: str | None = None
    public_data_sources: list[str] = field(default_factory=list)
    data_scope: str = PUBLIC_DATA_SCOPE
    id: str = field(default_factory=new_id)
    created_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.outcome = normalize_tag(self.outcome)
        self.mistake_tags = sorted({normalize_tag(tag) for tag in self.mistake_tags if tag.strip()})
        self.strength_tags = sorted({normalize_tag(tag) for tag in self.strength_tags if tag.strip()})


@dataclass(slots=True)
class FeedbackEvent:
    target_type: str
    target_id: str
    event_type: str
    source: str
    score_delta: float | None = None
    risk_delta: float | None = None
    notes: str | None = None
    public_data_sources: list[str] = field(default_factory=list)
    data_scope: str = PUBLIC_DATA_SCOPE
    id: str = field(default_factory=new_id)
    created_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.target_type = normalize_tag(self.target_type)
        self.event_type = normalize_tag(self.event_type)
        self.source = normalize_tag(self.source)


@dataclass(slots=True)
class AssetMemoryProfile:
    symbol: str
    asset_class: str = "equity"
    recurring_patterns: list[str] = field(default_factory=list)
    risk_notes: list[str] = field(default_factory=list)
    strategy_fit: dict[str, str] = field(default_factory=dict)
    trade_count: int = 0
    win_rate: float = 0.0
    average_pnl_r: float = 0.0
    last_reviewed_at: datetime | None = None
    public_data_sources: list[str] = field(default_factory=list)
    data_scope: str = PUBLIC_DATA_SCOPE
    updated_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.symbol = normalize_symbol(self.symbol)


@dataclass(slots=True)
class StrategyMemoryProfile:
    strategy_id: str
    strategy_name: str
    setup_tags: list[str] = field(default_factory=list)
    strengths: list[str] = field(default_factory=list)
    failure_modes: list[str] = field(default_factory=list)
    market_conditions: list[str] = field(default_factory=list)
    risk_notes: list[str] = field(default_factory=list)
    trade_count: int = 0
    win_rate: float = 0.0
    average_pnl_r: float = 0.0
    last_reviewed_at: datetime | None = None
    public_data_sources: list[str] = field(default_factory=list)
    data_scope: str = PUBLIC_DATA_SCOPE
    updated_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        self.strategy_id = normalize_tag(self.strategy_id)
        self.strategy_name = self.strategy_name.strip()


@dataclass(slots=True)
class WeeklyReview:
    period_start: date
    period_end: date
    trade_count: int
    win_rate: float
    total_pnl_r: float
    average_pnl_r: float
    top_strengths: list[str]
    recurring_mistakes: list[str]
    risk_alerts: list[str]
    asset_highlights: dict[str, Any]
    strategy_highlights: dict[str, Any]
    action_items: list[str]
    source_trade_ids: list[str]
    feedback_event_ids: list[str]
    data_scope: str = PUBLIC_DATA_SCOPE
    id: str = field(default_factory=new_id)
    created_at: datetime = field(default_factory=utc_now)


@dataclass(slots=True)
class MemoryFilter:
    symbol: str | None = None
    strategy_id: str | None = None
    memory_types: list[str] | None = None
    tags: list[str] | None = None
    linked_record_types: list[str] | None = None
    linked_record_ids: list[str] | None = None
    source_types: list[str] | None = None
    min_importance: float | None = None
    created_after: datetime | None = None
    created_before: datetime | None = None
    include_archived: bool = False
    include_expired: bool = False
    query: str | None = None
