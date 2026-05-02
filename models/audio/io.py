from __future__ import annotations

import contextlib
import wave
from pathlib import Path

import numpy as np


def read_wav_mono(path: str | Path, target_sample_rate: int = 16_000) -> tuple[np.ndarray, int]:
    source = Path(path)
    with contextlib.closing(wave.open(str(source), "rb")) as handle:
        channels = handle.getnchannels()
        sample_width = handle.getsampwidth()
        sample_rate = handle.getframerate()
        frame_count = handle.getnframes()
        raw = handle.readframes(frame_count)

    if sample_width == 1:
        audio = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    elif sample_width == 2:
        audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    else:
        raise ValueError(f"Unsupported WAV sample width: {sample_width}")

    if channels > 1:
        audio = audio.reshape(-1, channels).mean(axis=1)

    audio = np.clip(audio, -1.0, 1.0)
    if sample_rate != target_sample_rate:
        audio = resample_linear(audio, sample_rate, target_sample_rate)
        sample_rate = target_sample_rate
    return audio.astype(np.float32), sample_rate


def write_wav_mono(path: str | Path, samples: np.ndarray, sample_rate: int = 16_000) -> None:
    clipped = np.clip(samples.astype(np.float32), -1.0, 1.0)
    pcm = (clipped * 32767.0).astype(np.int16)
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with contextlib.closing(wave.open(str(destination), "wb")) as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(pcm.tobytes())


def resample_linear(samples: np.ndarray, src_rate: int, dst_rate: int) -> np.ndarray:
    if src_rate == dst_rate:
        return samples
    if samples.size == 0:
        return samples
    duration = samples.shape[0] / src_rate
    old_positions = np.linspace(0.0, duration, num=samples.shape[0], endpoint=False)
    new_length = int(round(duration * dst_rate))
    new_positions = np.linspace(0.0, duration, num=max(new_length, 1), endpoint=False)
    return np.interp(new_positions, old_positions, samples).astype(np.float32)
