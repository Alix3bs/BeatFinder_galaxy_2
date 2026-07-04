from __future__ import annotations

import contextlib
import os
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

FFMPEG_DECODE_TIMEOUT_SECONDS = 120


class UnsupportedAudioFormatError(ValueError):
    """The audio file cannot be decoded by the available decoders."""


class AudioDecodeError(ValueError):
    """The audio file matched a supported format but could not be decoded."""


def load_audio_mono(path: str | Path, target_sample_rate: int = 16_000) -> tuple[np.ndarray, int]:
    """Decode any supported audio file to mono float32 samples.

    WAV decodes natively. Other formats (mp3, m4a) require an ffmpeg binary,
    resolved from `BEATFINDER_FFMPEG_BIN` or the PATH. Without ffmpeg,
    non-WAV input raises UnsupportedAudioFormatError with a clear message.
    """

    source = Path(path)
    suffix = source.suffix.lower()
    if suffix in {".wav", ""}:
        try:
            return read_wav_mono(source, target_sample_rate)
        except (wave.Error, EOFError) as error:
            raise AudioDecodeError(f"Could not decode WAV audio: {error}") from error

    ffmpeg_bin = resolve_ffmpeg_binary()
    if ffmpeg_bin is None:
        raise UnsupportedAudioFormatError(
            f"Cannot decode {suffix or 'unknown'} audio without ffmpeg. "
            "Upload WAV audio, or install ffmpeg on the backend."
        )
    return _decode_with_ffmpeg(source, ffmpeg_bin, target_sample_rate)


def resolve_ffmpeg_binary() -> str | None:
    configured = os.getenv("BEATFINDER_FFMPEG_BIN", "").strip()
    if configured:
        return configured if Path(configured).exists() else None
    return shutil.which("ffmpeg")


def _decode_with_ffmpeg(
    source: Path,
    ffmpeg_bin: str,
    target_sample_rate: int,
) -> tuple[np.ndarray, int]:
    with tempfile.TemporaryDirectory(prefix="beatfinder-ffmpeg-") as temp_dir:
        wav_path = Path(temp_dir) / "decoded.wav"
        command = [
            ffmpeg_bin,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(source),
            "-ac",
            "1",
            "-ar",
            str(target_sample_rate),
            "-sample_fmt",
            "s16",
            str(wav_path),
        ]
        try:
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=FFMPEG_DECODE_TIMEOUT_SECONDS,
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise AudioDecodeError("Audio decoding timed out.") from error
        if completed.returncode != 0 or not wav_path.exists():
            detail = (completed.stderr or "").strip().splitlines()
            raise AudioDecodeError(
                f"Could not decode audio file: {detail[-1] if detail else 'unknown ffmpeg error'}"
            )
        return read_wav_mono(wav_path, target_sample_rate)


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
