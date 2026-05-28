from __future__ import annotations

from collections import Counter, defaultdict
from datetime import date, datetime
from typing import Iterable

from .models import (
    NO_LIVE_EXECUTION_MODE,
    PAPER_ACCOUNT_MODE,
    PUBLIC_DATA_SCOPE,
    AssetMemoryProfile,
    FeedbackEvent,
    JournalMemoryItem,
    JournalMemoryLink,
    MemoryFilter,
    PostTradeReview,
    RiskRecord,
    SignalRecord,
    StrategyMemoryProfile,
    TradeJournalEntry,
    WeeklyReview,
    normalize_symbol,
    normalize_tag,
    utc_now,
)


class MemoryJournal:
    """In-memory journal service for public-data, paper-trading workflows.

    The service deliberately has no broker integration, no live-order model, and
    no private-account fields. A storage adapter can wrap these records later.
    """

    def __init__(self) -> None:
        self.memory_items: dict[str, JournalMemoryItem] = {}
        self.signals: dict[str, SignalRecord] = {}
        self.risks: dict[str, RiskRecord] = {}
        self.trades: dict[str, TradeJournalEntry] = {}
        self.post_trade_reviews: dict[str, PostTradeReview] = {}
        self.feedback_events: dict[str, FeedbackEvent] = {}
        self.asset_profiles: dict[str, AssetMemoryProfile] = {}
        self.strategy_profiles: dict[str, StrategyMemoryProfile] = {}
        self.weekly_reviews: dict[str, WeeklyReview] = {}

    def add_signal(self, signal: SignalRecord) -> SignalRecord:
        self._assert_public_data(signal.data_scope)
        self.signals[signal.id] = signal
        self._upsert_asset_profile(signal.symbol, signal.asset_class)
        return signal

    def add_risk(self, risk: RiskRecord) -> RiskRecord:
        self._assert_public_data(risk.data_scope)
        self._assert_paper_mode(risk.account_mode)
        self.risks[risk.id] = risk
        profile = self._upsert_asset_profile(risk.symbol)
        if risk.invalidation:
            self._append_unique(profile.risk_notes, risk.invalidation)
        return risk

    def add_memory_item(self, item: JournalMemoryItem) -> JournalMemoryItem:
        self._assert_public_data(item.data_scope)
        if not item.paper_trading_only:
            raise ValueError("Journal memory items must remain paper-trading only.")
        for link in item.links:
            self._assert_link_target_exists(link)
        self.memory_items[item.id] = item
        return item

    def link_memory(
        self,
        memory_id: str,
        *,
        record_type: str,
        record_id: str,
        relation: str,
        strength: float = 1.0,
    ) -> JournalMemoryItem:
        item = self.memory_items[memory_id]
        link = JournalMemoryLink(
            record_type=record_type,
            record_id=record_id,
            relation=relation,
            strength=strength,
        )
        self._assert_link_target_exists(link)
        item.links.append(link)
        item.updated_at = utc_now()
        return item

    def log_trade(self, trade: TradeJournalEntry) -> TradeJournalEntry:
        self._assert_public_data(trade.data_scope)
        self._assert_paper_mode(trade.account_mode)
        if trade.execution_mode != NO_LIVE_EXECUTION_MODE:
            raise ValueError("Live execution is not supported by the journal subsystem.")
        for signal_id in trade.linked_signal_ids:
            if signal_id not in self.signals:
                raise ValueError(f"Unknown linked signal id: {signal_id}")
        for risk_id in trade.linked_risk_ids:
            if risk_id not in self.risks:
                raise ValueError(f"Unknown linked risk id: {risk_id}")
        self.trades[trade.trade_id] = trade
        self._upsert_asset_profile(trade.symbol, trade.asset_class)
        self._upsert_strategy_profile(trade.strategy_id, trade.setup_name)
        return trade

    def add_post_trade_review(self, review: PostTradeReview) -> PostTradeReview:
        self._assert_public_data(review.data_scope)
        if review.trade_id not in self.trades:
            raise ValueError(f"Unknown trade id for review: {review.trade_id}")
        self.post_trade_reviews[review.id] = review
        trade = self.trades[review.trade_id]
        trade.status = "closed"
        trade.updated_at = utc_now()
        self.refresh_profiles()
        return review

    def record_feedback(self, feedback: FeedbackEvent) -> FeedbackEvent:
        self._assert_public_data(feedback.data_scope)
        self.feedback_events[feedback.id] = feedback
        if feedback.target_type == "signal" and feedback.target_id in self.signals:
            signal = self.signals[feedback.target_id]
            if feedback.score_delta is not None:
                signal.confidence = self._clamp01(signal.confidence + feedback.score_delta)
        if feedback.target_type == "risk" and feedback.target_id in self.risks:
            risk = self.risks[feedback.target_id]
            if feedback.risk_delta is not None:
                risk.risk_score = self._clamp01(risk.risk_score + feedback.risk_delta)
        return feedback

    def retrieve_memory_items(
        self,
        filters: MemoryFilter | None = None,
        *,
        limit: int = 10,
        now: datetime | None = None,
    ) -> list[JournalMemoryItem]:
        filters = filters or MemoryFilter()
        scored_items: list[tuple[float, JournalMemoryItem]] = []
        for item in self.memory_items.values():
            if not self._matches_filter(item, filters, now=now):
                continue
            score = self._score_memory(item, filters)
            scored_items.append((score, item))
        scored_items.sort(key=lambda pair: (pair[0], pair[1].updated_at), reverse=True)
        return [item for _, item in scored_items[:limit]]

    def archive_memory(self, memory_id: str, reason: str) -> JournalMemoryItem:
        item = self.memory_items[memory_id]
        item.status = "archived"
        item.archive_reason = reason
        item.archived_at = utc_now()
        item.updated_at = item.archived_at
        return item

    def archive_expired(self, *, now: datetime | None = None) -> list[JournalMemoryItem]:
        check_time = now or utc_now()
        expired: list[JournalMemoryItem] = []
        for item in self.memory_items.values():
            if item.status == "active" and item.is_expired(check_time):
                item.status = "expired"
                item.archived_at = check_time
                item.archive_reason = "expired"
                item.updated_at = check_time
                expired.append(item)
        return expired

    def refresh_profiles(self) -> None:
        for symbol in {trade.symbol for trade in self.trades.values()}:
            self.asset_profiles[symbol] = self._build_asset_profile(symbol)
        for strategy_id in {trade.strategy_id for trade in self.trades.values()}:
            self.strategy_profiles[strategy_id] = self._build_strategy_profile(strategy_id)

    def build_weekly_review(self, period_start: date, period_end: date) -> WeeklyReview:
        trades = [
            trade
            for trade in self.trades.values()
            if trade.exit_at is not None and period_start <= trade.exit_at.date() <= period_end
        ]
        reviews = [
            review for review in self.post_trade_reviews.values() if review.trade_id in {t.trade_id for t in trades}
        ]
        feedback = [
            event
            for event in self.feedback_events.values()
            if period_start <= event.created_at.date() <= period_end
        ]
        pnl_values = [review.pnl_r for review in reviews]
        wins = [value for value in pnl_values if value > 0]
        strength_counts = Counter(tag for review in reviews for tag in review.strength_tags)
        mistake_counts = Counter(tag for review in reviews for tag in review.mistake_tags)
        risk_alerts = self._weekly_risk_alerts(trades, feedback)
        total_pnl = round(sum(pnl_values), 4)
        trade_count = len(trades)
        weekly = WeeklyReview(
            period_start=period_start,
            period_end=period_end,
            trade_count=trade_count,
            win_rate=round(len(wins) / trade_count, 4) if trade_count else 0.0,
            total_pnl_r=total_pnl,
            average_pnl_r=round(total_pnl / trade_count, 4) if trade_count else 0.0,
            top_strengths=[tag for tag, _ in strength_counts.most_common(5)],
            recurring_mistakes=[tag for tag, _ in mistake_counts.most_common(5)],
            risk_alerts=risk_alerts,
            asset_highlights=self._aggregate_by_asset(trades, reviews),
            strategy_highlights=self._aggregate_by_strategy(trades, reviews),
            action_items=self._weekly_action_items(mistake_counts, risk_alerts),
            source_trade_ids=[trade.trade_id for trade in trades],
            feedback_event_ids=[event.id for event in feedback],
        )
        self.weekly_reviews[weekly.id] = weekly
        return weekly

    def research_context(self, filters: MemoryFilter | None = None, *, limit: int = 10) -> dict[str, object]:
        items = self.retrieve_memory_items(filters, limit=limit)
        return {
            "data_scope": PUBLIC_DATA_SCOPE,
            "execution_mode": NO_LIVE_EXECUTION_MODE,
            "paper_trading_only": True,
            "memory_count": len(items),
            "items": [
                {
                    "id": item.id,
                    "memory_type": item.memory_type,
                    "symbol": item.symbol,
                    "strategy_id": item.strategy_id,
                    "summary": item.summary,
                    "content": item.content,
                    "evidence": item.evidence,
                    "source_title": item.source_title,
                    "source_type": item.source_type,
                    "source_url": item.source_url,
                    "source_reliability": item.source_reliability,
                    "links": [
                        {
                            "record_type": link.record_type,
                            "record_id": link.record_id,
                            "relation": link.relation,
                            "strength": link.strength,
                        }
                        for link in item.links
                    ],
                }
                for item in items
            ],
        }

    def _build_asset_profile(self, symbol: str) -> AssetMemoryProfile:
        normalized_symbol = normalize_symbol(symbol)
        trades = [trade for trade in self.trades.values() if trade.symbol == normalized_symbol]
        reviews = [review for review in self.post_trade_reviews.values() if review.trade_id in {t.trade_id for t in trades}]
        pnl_values = [review.pnl_r for review in reviews]
        wins = [value for value in pnl_values if value > 0]
        mistake_counts = Counter(tag for review in reviews for tag in review.mistake_tags)
        strength_counts = Counter(tag for review in reviews for tag in review.strength_tags)
        profile = AssetMemoryProfile(
            symbol=normalized_symbol,
            asset_class=trades[-1].asset_class if trades else "equity",
            recurring_patterns=[tag for tag, _ in strength_counts.most_common(5)],
            risk_notes=[tag for tag, _ in mistake_counts.most_common(5)],
            strategy_fit=self._strategy_fit_for_trades(trades, reviews),
            trade_count=len(trades),
            win_rate=round(len(wins) / len(trades), 4) if trades else 0.0,
            average_pnl_r=round(sum(pnl_values) / len(pnl_values), 4) if pnl_values else 0.0,
            last_reviewed_at=utc_now(),
            public_data_sources=sorted({source for trade in trades for source in trade.public_data_sources}),
        )
        return profile

    def _build_strategy_profile(self, strategy_id: str) -> StrategyMemoryProfile:
        normalized_strategy = normalize_tag(strategy_id)
        trades = [trade for trade in self.trades.values() if trade.strategy_id == normalized_strategy]
        reviews = [review for review in self.post_trade_reviews.values() if review.trade_id in {t.trade_id for t in trades}]
        pnl_values = [review.pnl_r for review in reviews]
        wins = [value for value in pnl_values if value > 0]
        mistake_counts = Counter(tag for review in reviews for tag in review.mistake_tags)
        strength_counts = Counter(tag for review in reviews for tag in review.strength_tags)
        return StrategyMemoryProfile(
            strategy_id=normalized_strategy,
            strategy_name=trades[-1].setup_name if trades else normalized_strategy,
            setup_tags=sorted({tag for trade in trades for tag in trade.tags}),
            strengths=[tag for tag, _ in strength_counts.most_common(5)],
            failure_modes=[tag for tag, _ in mistake_counts.most_common(5)],
            market_conditions=sorted({trade.market_context for trade in trades if trade.market_context}),
            risk_notes=[risk.invalidation for risk in self.risks.values() if risk.strategy_id == normalized_strategy],
            trade_count=len(trades),
            win_rate=round(len(wins) / len(trades), 4) if trades else 0.0,
            average_pnl_r=round(sum(pnl_values) / len(pnl_values), 4) if pnl_values else 0.0,
            last_reviewed_at=utc_now(),
            public_data_sources=sorted({source for trade in trades for source in trade.public_data_sources}),
        )

    def _matches_filter(self, item: JournalMemoryItem, filters: MemoryFilter, *, now: datetime | None) -> bool:
        if item.data_scope != PUBLIC_DATA_SCOPE or not item.paper_trading_only:
            return False
        if not filters.include_archived and item.status != "active":
            return False
        if not filters.include_expired and item.is_expired(now):
            return False
        if filters.symbol and item.symbol != normalize_symbol(filters.symbol):
            return False
        if filters.strategy_id and item.strategy_id != normalize_tag(filters.strategy_id):
            return False
        if filters.memory_types and item.memory_type not in {normalize_tag(kind) for kind in filters.memory_types}:
            return False
        if filters.tags and not {normalize_tag(tag) for tag in filters.tags}.issubset(set(item.tags)):
            return False
        if filters.linked_record_types:
            record_types = {link.record_type for link in item.links}
            if not record_types.intersection({normalize_tag(kind) for kind in filters.linked_record_types}):
                return False
        if filters.linked_record_ids:
            record_ids = {link.record_id for link in item.links}
            if not record_ids.intersection(set(filters.linked_record_ids)):
                return False
        if filters.source_types:
            if item.source_type not in {normalize_tag(kind) for kind in filters.source_types}:
                return False
        if filters.min_importance is not None and item.importance < filters.min_importance:
            return False
        if filters.created_after and item.created_at < filters.created_after:
            return False
        if filters.created_before and item.created_at > filters.created_before:
            return False
        if filters.query and not set(normalize_tag(filters.query).split()).intersection(item.retrieval_text().split()):
            return False
        return True

    def _score_memory(self, item: JournalMemoryItem, filters: MemoryFilter) -> float:
        score = item.importance + (item.confidence * 0.25) + sum(link.strength for link in item.links) * 0.1
        if filters.query:
            query_terms = set(normalize_tag(filters.query).split())
            text_terms = set(item.retrieval_text().split())
            score += len(query_terms.intersection(text_terms)) * 0.2
        return score

    def _assert_link_target_exists(self, link: JournalMemoryLink) -> None:
        stores = {
            "signal": self.signals,
            "risk": self.risks,
            "trade": self.trades,
            "review": self.post_trade_reviews,
            "feedback": self.feedback_events,
        }
        if link.record_type not in stores:
            raise ValueError(f"Unsupported link record type: {link.record_type}")
        if link.record_id not in stores[link.record_type]:
            raise ValueError(f"Unknown {link.record_type} id: {link.record_id}")

    def _upsert_asset_profile(self, symbol: str, asset_class: str = "equity") -> AssetMemoryProfile:
        normalized_symbol = normalize_symbol(symbol)
        profile = self.asset_profiles.get(normalized_symbol)
        if profile is None:
            profile = AssetMemoryProfile(symbol=normalized_symbol, asset_class=asset_class)
            self.asset_profiles[normalized_symbol] = profile
        return profile

    def _upsert_strategy_profile(self, strategy_id: str, strategy_name: str) -> StrategyMemoryProfile:
        normalized_strategy = normalize_tag(strategy_id)
        profile = self.strategy_profiles.get(normalized_strategy)
        if profile is None:
            profile = StrategyMemoryProfile(strategy_id=normalized_strategy, strategy_name=strategy_name)
            self.strategy_profiles[normalized_strategy] = profile
        return profile

    def _aggregate_by_asset(
        self, trades: list[TradeJournalEntry], reviews: list[PostTradeReview]
    ) -> dict[str, dict[str, float | int]]:
        by_asset: dict[str, list[float]] = defaultdict(list)
        review_by_trade = {review.trade_id: review for review in reviews}
        for trade in trades:
            review = review_by_trade.get(trade.trade_id)
            if review:
                by_asset[trade.symbol].append(review.pnl_r)
        return {
            symbol: {
                "trade_count": len(values),
                "average_pnl_r": round(sum(values) / len(values), 4),
                "total_pnl_r": round(sum(values), 4),
            }
            for symbol, values in by_asset.items()
            if values
        }

    def _aggregate_by_strategy(
        self, trades: list[TradeJournalEntry], reviews: list[PostTradeReview]
    ) -> dict[str, dict[str, float | int]]:
        by_strategy: dict[str, list[float]] = defaultdict(list)
        review_by_trade = {review.trade_id: review for review in reviews}
        for trade in trades:
            review = review_by_trade.get(trade.trade_id)
            if review:
                by_strategy[trade.strategy_id].append(review.pnl_r)
        return {
            strategy: {
                "trade_count": len(values),
                "average_pnl_r": round(sum(values) / len(values), 4),
                "total_pnl_r": round(sum(values), 4),
            }
            for strategy, values in by_strategy.items()
            if values
        }

    def _strategy_fit_for_trades(
        self, trades: Iterable[TradeJournalEntry], reviews: list[PostTradeReview]
    ) -> dict[str, str]:
        review_by_trade = {review.trade_id: review for review in reviews}
        pnl_by_strategy: dict[str, list[float]] = defaultdict(list)
        for trade in trades:
            review = review_by_trade.get(trade.trade_id)
            if review:
                pnl_by_strategy[trade.strategy_id].append(review.pnl_r)
        fit: dict[str, str] = {}
        for strategy_id, values in pnl_by_strategy.items():
            average = sum(values) / len(values)
            fit[strategy_id] = "strong" if average > 0.5 else "weak" if average < 0 else "mixed"
        return fit

    def _weekly_risk_alerts(self, trades: list[TradeJournalEntry], feedback: list[FeedbackEvent]) -> list[str]:
        alerts: list[str] = []
        linked_risk_ids = {risk_id for trade in trades for risk_id in trade.linked_risk_ids}
        for risk_id in linked_risk_ids:
            risk = self.risks.get(risk_id)
            if risk and risk.risk_score >= 0.75:
                alerts.append(f"{risk.symbol}: high risk score {risk.risk_score:.2f} - {risk.invalidation}")
        for event in feedback:
            if event.risk_delta and event.risk_delta > 0:
                alerts.append(f"Feedback raised risk on {event.target_type}:{event.target_id}")
        return alerts

    def _weekly_action_items(self, mistake_counts: Counter[str], risk_alerts: list[str]) -> list[str]:
        items = [f"Reduce repeat mistake: {tag}" for tag, _ in mistake_counts.most_common(3)]
        if risk_alerts:
            items.append("Review risk sizing rules before the next paper session.")
        return items or ["Keep logging setups, risk notes, and post-trade reviews."]

    @staticmethod
    def _append_unique(values: list[str], value: str) -> None:
        if value not in values:
            values.append(value)

    @staticmethod
    def _assert_public_data(data_scope: str) -> None:
        if data_scope != PUBLIC_DATA_SCOPE:
            raise ValueError("Only public-data journal records are supported.")

    @staticmethod
    def _assert_paper_mode(account_mode: str) -> None:
        if account_mode != PAPER_ACCOUNT_MODE:
            raise ValueError("Only paper-trading journal records are supported.")

    @staticmethod
    def _clamp01(value: float) -> float:
        return max(0.0, min(1.0, float(value)))
