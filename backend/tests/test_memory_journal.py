from __future__ import annotations

import unittest
from datetime import date, datetime, timedelta, timezone

from memory.journal import (
    FeedbackEvent,
    JournalMemoryItem,
    JournalMemoryLink,
    MemoryFilter,
    MemoryJournal,
    PostTradeReview,
    RiskRecord,
    SignalRecord,
    TradeJournalEntry,
)


class MemoryJournalTests(unittest.TestCase):
    def setUp(self) -> None:
        self.journal = MemoryJournal()
        self.observed_at = datetime(2026, 5, 18, 14, 30, tzinfo=timezone.utc)

    def test_memory_items_link_to_signal_and_risk_and_retrieve_with_filters(self) -> None:
        signal = self.journal.add_signal(
            SignalRecord(
                symbol="aapl",
                signal_type="breakout",
                direction="long",
                confidence=0.72,
                source="public scanner",
                observed_at=self.observed_at,
                strategy_id="opening-range-breakout",
                tags=["breakout", "volume"],
                public_data_sources=["nasdaq public quote"],
            )
        )
        risk = self.journal.add_risk(
            RiskRecord(
                symbol="AAPL",
                strategy_id="opening-range-breakout",
                risk_score=0.64,
                max_loss_r=1.0,
                position_size_r=0.5,
                invalidation="Breakout fails below VWAP.",
                public_data_sources=["nasdaq public quote"],
            )
        )
        memory = self.journal.add_memory_item(
            JournalMemoryItem(
                memory_type="setup_note",
                symbol="AAPL",
                strategy_id="opening-range-breakout",
                content="AAPL opening range breakout only works when volume confirms.",
                summary="Volume confirmation matters for this setup.",
                source_type="public_market_note",
                tags=["breakout", "volume"],
                importance=0.8,
                confidence=0.7,
                links=[
                    JournalMemoryLink("signal", signal.id, "supports", 0.9),
                    JournalMemoryLink("risk", risk.id, "constrains", 0.8),
                ],
                evidence=["Public tape showed relative volume above baseline."],
                public_data_sources=["nasdaq public quote"],
            )
        )

        results = self.journal.retrieve_memory_items(
            MemoryFilter(
                symbol="aapl",
                strategy_id="opening-range-breakout",
                tags=["breakout"],
                linked_record_types=["signal"],
                linked_record_ids=[signal.id],
                source_types=["public_market_note"],
                query="volume breakout",
            )
        )

        self.assertEqual([item.id for item in results], [memory.id])
        self.assertEqual(memory.linked_signal_ids, [signal.id])
        self.assertEqual(memory.linked_risk_ids, [risk.id])

    def test_trade_review_feedback_and_profiles_are_paper_only(self) -> None:
        signal = self.journal.add_signal(
            SignalRecord(
                symbol="MSFT",
                signal_type="pullback",
                direction="long",
                confidence=0.6,
                source="public chart",
                observed_at=self.observed_at,
                strategy_id="trend-pullback",
            )
        )
        risk = self.journal.add_risk(
            RiskRecord(
                symbol="MSFT",
                strategy_id="trend-pullback",
                risk_score=0.7,
                max_loss_r=1.0,
                position_size_r=0.4,
                stop_loss=418.0,
                invalidation="Close below prior day low.",
            )
        )
        trade = self.journal.log_trade(
            TradeJournalEntry(
                symbol="MSFT",
                strategy_id="trend-pullback",
                setup_name="Trend Pullback",
                direction="long",
                thesis="Public price action reclaimed moving average support.",
                planned_entry=425.0,
                planned_stop=418.0,
                planned_target=439.0,
                actual_entry=425.5,
                actual_exit=438.5,
                quantity=10,
                risk_amount=75.0,
                reward_risk_ratio=2.0,
                invalidation="Close below prior day low.",
                entry_at=self.observed_at,
                exit_at=self.observed_at + timedelta(hours=5),
                market_context="large-cap tech trend day",
                research_notes="Public macro calendar was quiet.",
                setup_snapshot={"relative_volume": 1.4},
                tags=["pullback", "trend"],
                linked_signal_ids=[signal.id],
                linked_risk_ids=[risk.id],
                public_data_sources=["public exchange prints"],
            )
        )
        review = self.journal.add_post_trade_review(
            PostTradeReview(
                trade_id=trade.trade_id,
                outcome="win",
                pnl_r=1.8,
                followed_plan=True,
                strength_tags=["patient-entry", "followed-stop"],
                max_adverse_excursion_r=0.25,
                max_favorable_excursion_r=2.1,
                entry_quality_score=0.8,
                exit_quality_score=0.75,
                risk_management_score=0.9,
                what_worked="Waited for confirmation.",
                lesson="Keep waiting for volume confirmation.",
                next_action="Reuse playbook in paper mode.",
            )
        )
        self.journal.record_feedback(
            FeedbackEvent(
                target_type="signal",
                target_id=signal.id,
                event_type="score_adjustment",
                source="post_trade_review",
                score_delta=0.1,
                notes="Signal worked with confirmation.",
            )
        )
        self.journal.record_feedback(
            FeedbackEvent(
                target_type="risk",
                target_id=risk.id,
                event_type="risk_adjustment",
                source="post_trade_review",
                risk_delta=-0.15,
                notes="Risk was controlled in paper trade.",
            )
        )

        self.assertEqual(review.trade_id, trade.trade_id)
        self.assertAlmostEqual(self.journal.signals[signal.id].confidence, 0.7)
        self.assertAlmostEqual(self.journal.risks[risk.id].risk_score, 0.55)
        self.assertEqual(self.journal.asset_profiles["MSFT"].trade_count, 1)
        self.assertEqual(self.journal.asset_profiles["MSFT"].average_pnl_r, 1.8)
        self.assertEqual(self.journal.strategy_profiles["trend-pullback"].win_rate, 1.0)

        with self.assertRaises(ValueError):
            self.journal.log_trade(
                TradeJournalEntry(
                    symbol="MSFT",
                    strategy_id="trend-pullback",
                    setup_name="Trend Pullback",
                    direction="long",
                    thesis="Would be live, which is forbidden.",
                    planned_entry=1,
                    planned_stop=0.9,
                    planned_target=1.2,
                    invalidation="n/a",
                    execution_mode="live",
                )
            )

    def test_weekly_review_aggregates_mistakes_strengths_and_risk_alerts(self) -> None:
        trade, risk = self._closed_trade_with_review(
            symbol="TSLA",
            strategy_id="failed-breakout",
            pnl_r=-0.8,
            risk_score=0.82,
            mistake_tags=["chased-entry", "ignored-invalidation"],
            strength_tags=["logged-plan"],
        )
        feedback = FeedbackEvent(
            target_type="risk",
            target_id=risk.id,
            event_type="risk_override",
            source="weekly_review",
            risk_delta=0.1,
            notes="Paper trade exceeded planned heat.",
        )
        feedback.created_at = datetime(2026, 5, 20, 12, tzinfo=timezone.utc)
        self.journal.record_feedback(feedback)

        weekly = self.journal.build_weekly_review(date(2026, 5, 18), date(2026, 5, 24))

        self.assertEqual(weekly.trade_count, 1)
        self.assertEqual(weekly.source_trade_ids, [trade.trade_id])
        self.assertEqual(weekly.recurring_mistakes[:2], ["chased-entry", "ignored-invalidation"])
        self.assertIn("logged-plan", weekly.top_strengths)
        self.assertTrue(any("high risk score" in alert for alert in weekly.risk_alerts))
        self.assertIn("Reduce repeat mistake: chased-entry", weekly.action_items)
        self.assertIn(feedback.id, weekly.feedback_event_ids)

    def test_archive_expired_excludes_old_memories_unless_requested(self) -> None:
        now = datetime(2026, 5, 25, tzinfo=timezone.utc)
        item = self.journal.add_memory_item(
            JournalMemoryItem(
                memory_type="research_note",
                content="Old catalyst note should expire before future summaries.",
                symbol="NVDA",
                tags=["catalyst"],
                expires_at=now - timedelta(days=1),
            )
        )

        self.assertEqual(self.journal.retrieve_memory_items(MemoryFilter(symbol="NVDA"), now=now), [])
        self.assertEqual(
            [memory.id for memory in self.journal.retrieve_memory_items(
                MemoryFilter(symbol="NVDA", include_expired=True),
                now=now,
            )],
            [item.id],
        )

        expired = self.journal.archive_expired(now=now)

        self.assertEqual([memory.id for memory in expired], [item.id])
        self.assertEqual(item.status, "expired")
        self.assertEqual(item.archive_reason, "expired")
        self.assertEqual(self.journal.retrieve_memory_items(MemoryFilter(symbol="NVDA"), now=now), [])
        self.assertEqual(
            [memory.id for memory in self.journal.retrieve_memory_items(
                MemoryFilter(symbol="NVDA", include_archived=True, include_expired=True),
                now=now,
            )],
            [item.id],
        )

    def test_research_context_contains_public_summarization_fields(self) -> None:
        item = self.journal.add_memory_item(
            JournalMemoryItem(
                memory_type="research_note",
                content="Public earnings transcript highlighted margin pressure.",
                summary="Margins were the main risk.",
                symbol="AMD",
                source_type="public_filing",
                source_title="AMD public earnings transcript",
                source_url="https://example.com/public-transcript",
                source_reliability="primary_public_source",
                evidence=["Management discussed gross margin pressure."],
                tags=["earnings", "margin"],
            )
        )

        context = self.journal.research_context(MemoryFilter(symbol="AMD", query="margin"), limit=3)

        self.assertTrue(context["paper_trading_only"])
        self.assertEqual(context["execution_mode"], "none")
        self.assertEqual(context["data_scope"], "public_only")
        self.assertEqual(context["items"][0]["id"], item.id)
        self.assertEqual(context["items"][0]["source_type"], "public_filing")
        self.assertEqual(context["items"][0]["source_reliability"], "primary_public_source")
        self.assertIn("Management discussed gross margin pressure.", context["items"][0]["evidence"])

    def _closed_trade_with_review(
        self,
        *,
        symbol: str,
        strategy_id: str,
        pnl_r: float,
        risk_score: float,
        mistake_tags: list[str],
        strength_tags: list[str],
    ) -> tuple[TradeJournalEntry, RiskRecord]:
        risk = self.journal.add_risk(
            RiskRecord(
                symbol=symbol,
                strategy_id=strategy_id,
                risk_score=risk_score,
                invalidation="Invalid if price reclaims failed breakout level.",
            )
        )
        trade = self.journal.log_trade(
            TradeJournalEntry(
                symbol=symbol,
                strategy_id=strategy_id,
                setup_name="Failed Breakout",
                direction="short",
                thesis="Public chart failed breakout resistance.",
                planned_entry=100,
                planned_stop=103,
                planned_target=94,
                actual_entry=100,
                actual_exit=102.4,
                invalidation="Close above failed breakout level.",
                entry_at=datetime(2026, 5, 20, 14, tzinfo=timezone.utc),
                exit_at=datetime(2026, 5, 20, 18, tzinfo=timezone.utc),
                linked_risk_ids=[risk.id],
                tags=["failed-breakout"],
            )
        )
        self.journal.add_post_trade_review(
            PostTradeReview(
                trade_id=trade.trade_id,
                outcome="loss" if pnl_r < 0 else "win",
                pnl_r=pnl_r,
                followed_plan=False,
                mistake_tags=mistake_tags,
                strength_tags=strength_tags,
                what_failed="Entered before confirmation.",
                next_action="Require confirmation before paper entries.",
            )
        )
        return trade, risk


if __name__ == "__main__":
    unittest.main()
