from __future__ import annotations

import math
from pathlib import Path

import numpy as np

from backend.core.types import AudioFeatures, VECTOR_DIMENSION
from .io import read_wav_mono

FRAME_SIZE = 1024
HOP_SIZE = 512


def extract_audio_features(audio_path: str | Path) -> AudioFeatures:
    samples, sample_rate = read_wav_mono(audio_path)
    if samples.size < FRAME_SIZE:
        samples = np.pad(samples, (0, FRAME_SIZE - samples.size))

    frames = frame_signal(samples, FRAME_SIZE, HOP_SIZE)
    window = np.hanning(FRAME_SIZE).astype(np.float32)
    spectrum = np.abs(np.fft.rfft(frames * window, axis=1)).astype(np.float32)
    spectrum += 1e-8
    mean_spectrum = spectrum.mean(axis=0)
    freqs = np.fft.rfftfreq(FRAME_SIZE, d=1.0 / sample_rate)

    frame_energy = np.sqrt(np.mean(frames ** 2, axis=1))
    onset_strength = np.maximum(0.0, np.diff(frame_energy, prepend=frame_energy[:1]))
    spectral_flux = np.sqrt(np.mean(np.diff(spectrum, axis=0, prepend=spectrum[:1]) ** 2, axis=1))

    spectral_centroid = float(np.sum(freqs * mean_spectrum) / np.sum(mean_spectrum))
    spectral_bandwidth = float(
        math.sqrt(np.sum(((freqs - spectral_centroid) ** 2) * mean_spectrum) / np.sum(mean_spectrum))
    )

    chroma = compute_chroma(mean_spectrum, freqs)
    band_energies = resample_vector(mean_spectrum, 24)
    onset_pattern = resample_vector(onset_strength, 32)
    envelope_pattern = resample_vector(np.abs(samples), 32)
    spectral_shape = resample_vector(mean_spectrum, 32)
    spectral_flux_pattern = resample_vector(spectral_flux, 32)
    summary_vector = build_summary_vector(
        samples=samples,
        sample_rate=sample_rate,
        frame_energy=frame_energy,
        onset_strength=onset_strength,
        spectral_centroid=spectral_centroid,
        spectral_bandwidth=spectral_bandwidth,
    )

    return AudioFeatures(
        duration_seconds=float(samples.shape[0] / sample_rate),
        sample_rate=sample_rate,
        tempo_bpm=estimate_tempo(onset_strength, sample_rate=sample_rate, hop_size=HOP_SIZE),
        rms_energy=float(np.sqrt(np.mean(samples ** 2))),
        zero_crossing_rate=float(np.mean(np.abs(np.diff(np.signbit(samples).astype(np.int8))))),
        spectral_centroid=spectral_centroid,
        spectral_bandwidth=spectral_bandwidth,
        silence_ratio=float(np.mean(np.abs(samples) < 0.02)),
        peak_amplitude=float(np.max(np.abs(samples))),
        chroma=normalize_vector(chroma),
        band_energies=normalize_vector(band_energies),
        onset_pattern=normalize_vector(onset_pattern),
        envelope_pattern=normalize_vector(envelope_pattern),
        spectral_shape=normalize_vector(spectral_shape),
        spectral_flux_pattern=normalize_vector(spectral_flux_pattern),
        summary_vector=summary_vector,
    )


def audio_features_to_embedding(features: AudioFeatures) -> list[float]:
    embedding = [
        *features.chroma,
        *resample_vector(features.band_energies, 64),
        *resample_vector(features.onset_pattern, 64),
        *resample_vector(features.envelope_pattern, 64),
        *resample_vector(features.spectral_shape, 64),
        *resample_vector(features.spectral_flux_pattern, 64),
        *resample_vector(features.summary_vector, 52),
    ]
    if len(embedding) < VECTOR_DIMENSION:
        embedding.extend([0.0] * (VECTOR_DIMENSION - len(embedding)))
    return normalize_vector(embedding[:VECTOR_DIMENSION])


def frame_signal(samples: np.ndarray, frame_size: int, hop_size: int) -> np.ndarray:
    frames: list[np.ndarray] = []
    for start in range(0, max(samples.shape[0] - frame_size + 1, 1), hop_size):
        frame = samples[start : start + frame_size]
        if frame.shape[0] < frame_size:
            frame = np.pad(frame, (0, frame_size - frame.shape[0]))
        frames.append(frame.astype(np.float32))
    return np.vstack(frames)


def compute_chroma(mean_spectrum: np.ndarray, freqs: np.ndarray) -> list[float]:
    chroma = np.zeros(12, dtype=np.float32)
    valid = freqs > 27.5
    pitches = 69 + 12 * np.log2(freqs[valid] / 440.0)
    pitch_classes = np.mod(np.round(pitches).astype(int), 12)
    for index, pitch_class in enumerate(pitch_classes):
        chroma[pitch_class] += float(mean_spectrum[valid][index])
    return chroma.tolist()


def estimate_tempo(onset_strength: np.ndarray, sample_rate: int, hop_size: int) -> float | None:
    if onset_strength.size < 4 or np.max(onset_strength) <= 1e-6:
        return None
    frame_rate = sample_rate / hop_size
    min_lag = int(frame_rate * 60 / 200)
    max_lag = int(frame_rate * 60 / 60)
    autocorr = np.correlate(onset_strength, onset_strength, mode="full")[onset_strength.size - 1 :]
    search = autocorr[min_lag:max_lag]
    if search.size == 0:
        return None
    best_lag = int(np.argmax(search) + min_lag)
    return float(60 * frame_rate / max(best_lag, 1))


def build_summary_vector(
    *,
    samples: np.ndarray,
    sample_rate: int,
    frame_energy: np.ndarray,
    onset_strength: np.ndarray,
    spectral_centroid: float,
    spectral_bandwidth: float,
) -> list[float]:
    duration = samples.shape[0] / sample_rate
    energy_quantiles = np.quantile(frame_energy, np.linspace(0.05, 0.95, 10)).tolist()
    onset_quantiles = np.quantile(onset_strength, np.linspace(0.1, 0.9, 8)).tolist()
    summary = [
        min(duration / 30.0, 1.0),
        float(np.sqrt(np.mean(samples ** 2))),
        float(np.mean(np.abs(samples))),
        float(np.mean(np.abs(samples) < 0.02)),
        float(np.max(np.abs(samples))),
        min(spectral_centroid / 8_000.0, 1.0),
        min(spectral_bandwidth / 8_000.0, 1.0),
        float(np.mean(np.abs(np.diff(samples)))),
        *energy_quantiles,
        *onset_quantiles,
        *resample_vector(frame_energy, 10),
    ]
    return normalize_vector(summary)


def normalize_vector(values: list[float] | np.ndarray) -> list[float]:
    vector = np.asarray(values, dtype=np.float32)
    norm = float(np.linalg.norm(vector))
    if norm <= 1e-8:
        return vector.tolist()
    return (vector / norm).tolist()


def resample_vector(values: list[float] | np.ndarray, size: int) -> list[float]:
    array = np.asarray(values, dtype=np.float32)
    if array.size == 0:
        return [0.0] * size
    old_positions = np.linspace(0.0, 1.0, num=array.shape[0], endpoint=True)
    new_positions = np.linspace(0.0, 1.0, num=size, endpoint=True)
    return np.interp(new_positions, old_positions, array).astype(np.float32).tolist()
