from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from models.audio.io import write_wav_mono

FIXTURE_SAMPLE_RATE = 16_000


@dataclass(slots=True)
class FixtureItem:
    slug: str
    title: str
    producer_name: str
    hashtags: list[str]
    region_tags: list[str]
    genre_tags: list[str]
    bpm: float
    root_hz: float
    pattern: str
    source_url: str
    source_platform: str
    audio_path: str | None = None


def load_fixture_specs() -> list[FixtureItem]:
    catalog_path = Path(__file__).with_name("fixtures").joinpath("fixture_catalog.json")
    payload = json.loads(catalog_path.read_text(encoding="utf-8"))
    return [FixtureItem(**entry) for entry in payload["fixtures"]]


def materialize_fixtures(output_dir: str | Path) -> list[dict[str, Any]]:
    root = Path(output_dir)
    root.mkdir(parents=True, exist_ok=True)
    materialized: list[dict[str, Any]] = []
    for spec in load_fixture_specs():
        audio = synthesize_audio(spec)
        audio_path = root / f"{spec.slug}.wav"
        write_wav_mono(audio_path, audio, sample_rate=FIXTURE_SAMPLE_RATE)
        row = {
            "slug": spec.slug,
            "title": spec.title,
            "producer_name": spec.producer_name,
            "hashtags": spec.hashtags,
            "region_tags": spec.region_tags,
            "genre_tags": spec.genre_tags,
            "bpm": spec.bpm,
            "source_url": spec.source_url,
            "source_platform": spec.source_platform,
            "audio_path": str(audio_path),
        }
        materialized.append(row)
    return materialized


def write_clip(source_path: str | Path, destination_path: str | Path, *, start_seconds: float, duration_seconds: float) -> str:
    from models.audio.io import read_wav_mono

    samples, sample_rate = read_wav_mono(source_path, target_sample_rate=FIXTURE_SAMPLE_RATE)
    start_index = int(start_seconds * sample_rate)
    end_index = int((start_seconds + duration_seconds) * sample_rate)
    clip = samples[start_index:end_index]
    write_wav_mono(destination_path, clip, sample_rate=sample_rate)
    return str(destination_path)


def synthesize_audio(spec: FixtureItem, duration_seconds: float = 8.0) -> np.ndarray:
    length = int(duration_seconds * FIXTURE_SAMPLE_RATE)
    timeline = np.arange(length, dtype=np.float32) / FIXTURE_SAMPLE_RATE
    signal = np.zeros(length, dtype=np.float32)
    rng = np.random.default_rng(abs(hash(spec.slug)) % (2**32))

    bass = 0.35 * np.sin(2 * math.pi * spec.root_hz * timeline)
    pad = 0.15 * np.sin(2 * math.pi * spec.root_hz * 2 * timeline + 0.3)
    signal += bass + pad

    beat_period = 60.0 / spec.bpm
    events = _pattern_events(spec.pattern, duration_seconds=duration_seconds, beat_period=beat_period)
    for time_seconds, kind in events:
        start = int(time_seconds * FIXTURE_SAMPLE_RATE)
        end = min(start + 4000, length)
        voice = _drum_voice(kind, rng, end - start)
        signal[start:end] += voice

    movement = 0.07 * np.sin(2 * math.pi * (spec.root_hz / 4.0) * timeline * (1.0 if "drill" in spec.pattern else 0.5))
    signal += movement
    signal += rng.normal(0.0, 0.004, size=length).astype(np.float32)

    peak = np.max(np.abs(signal))
    if peak > 0:
        signal /= peak * 1.1
    return signal.astype(np.float32)


def _pattern_events(pattern: str, *, duration_seconds: float, beat_period: float) -> list[tuple[float, str]]:
    events: list[tuple[float, str]] = []
    current = 0.0
    while current < duration_seconds:
        if pattern == "drill":
            events.extend(
                [
                    (current, "kick"),
                    (current + beat_period * 0.5, "hat"),
                    (current + beat_period, "snare"),
                    (current + beat_period * 1.5, "hat"),
                ]
            )
        elif pattern == "bounce":
            events.extend(
                [
                    (current, "kick"),
                    (current + beat_period * 0.25, "hat"),
                    (current + beat_period * 0.75, "snare"),
                    (current + beat_period * 1.25, "hat"),
                ]
            )
        else:
            events.extend(
                [
                    (current, "kick"),
                    (current + beat_period * 0.5, "hat"),
                    (current + beat_period * 1.0, "snare"),
                    (current + beat_period * 1.5, "hat"),
                    (current + beat_period * 1.75, "kick"),
                ]
            )
        current += beat_period * 2.0
    return [(time_seconds, kind) for time_seconds, kind in events if time_seconds < duration_seconds]


def _drum_voice(kind: str, rng: np.random.Generator, length: int) -> np.ndarray:
    timeline = np.arange(length, dtype=np.float32) / FIXTURE_SAMPLE_RATE
    if kind == "kick":
        return 0.55 * np.exp(-timeline * 12.0) * np.sin(2 * math.pi * (55 - timeline * 20) * timeline)
    if kind == "snare":
        return 0.2 * np.exp(-timeline * 18.0) * rng.normal(0.0, 1.0, size=length).astype(np.float32)
    return 0.08 * np.exp(-timeline * 40.0) * np.sin(2 * math.pi * 6000.0 * timeline)
