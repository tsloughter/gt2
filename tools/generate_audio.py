"""Generate compact, original placeholder sound effects for Little Clean Crew."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 22_050
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "audio"


def envelope(time: float, duration: float, attack: float = 0.02, release: float = 0.08) -> float:
    return min(1.0, time / attack, max(0.0, (duration - time) / release))


def write_wav(name: str, samples: list[float]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT_DIR / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            value = int(max(-1.0, min(1.0, sample)) * 32767)
            frames.extend(struct.pack("<h", value))
        output.writeframes(frames)


def engine_loop() -> list[float]:
    duration = 1.2
    samples: list[float] = []
    for index in range(int(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        wobble = 1.0 + 0.035 * math.sin(2.0 * math.pi * 3.0 * time)
        base = math.sin(2.0 * math.pi * 52.0 * wobble * time)
        harmonic = math.sin(2.0 * math.pi * 104.0 * wobble * time)
        rumble = math.sin(2.0 * math.pi * 26.0 * time)
        samples.append((0.36 * base + 0.16 * harmonic + 0.12 * rumble) * 0.58)
    return samples


def hydraulic_loop() -> list[float]:
    duration = 1.4
    rng = random.Random(144)
    filtered_noise = 0.0
    samples: list[float] = []
    for index in range(int(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        filtered_noise = filtered_noise * 0.91 + rng.uniform(-1.0, 1.0) * 0.09
        whine_frequency = 185.0 + 42.0 * math.sin(2.0 * math.pi * time / duration)
        whine = math.sin(2.0 * math.pi * whine_frequency * time)
        pulse = 0.72 + 0.28 * math.sin(2.0 * math.pi * 7.0 * time)
        samples.append((0.24 * whine + 0.34 * filtered_noise) * pulse * 0.62)
    return samples


def pickup_chime() -> list[float]:
    duration = 0.88
    notes = ((0.00, 523.25), (0.22, 659.25), (0.44, 783.99))
    samples: list[float] = []
    for index in range(int(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        value = 0.0
        for start, frequency in notes:
            note_time = time - start
            if 0.0 <= note_time <= 0.38:
                note_env = envelope(note_time, 0.38, 0.012, 0.22)
                value += math.sin(2.0 * math.pi * frequency * note_time) * note_env
                value += 0.22 * math.sin(2.0 * math.pi * frequency * 2.0 * note_time) * note_env
        samples.append(value * 0.23)
    return samples


def trash_rattle() -> list[float]:
    duration = 0.72
    rng = random.Random(812)
    samples: list[float] = []
    filtered = 0.0
    for index in range(int(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        filtered = filtered * 0.72 + rng.uniform(-1.0, 1.0) * 0.28
        impacts = 0.0
        for impact_time in (0.04, 0.13, 0.25, 0.38, 0.54):
            elapsed = time - impact_time
            if 0.0 <= elapsed < 0.10:
                impacts += math.sin(2.0 * math.pi * (155.0 + impact_time * 90.0) * elapsed) * math.exp(-elapsed * 34.0)
        samples.append((filtered * 0.25 + impacts * 0.48) * envelope(time, duration, 0.01, 0.12))
    return samples


def reverse_beep() -> list[float]:
    duration = 0.22
    samples: list[float] = []
    for index in range(int(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        tone = math.sin(2.0 * math.pi * 760.0 * time)
        samples.append(tone * envelope(time, duration, 0.008, 0.045) * 0.32)
    return samples


def main() -> None:
    write_wav("engine_idle.wav", engine_loop())
    write_wav("hydraulics.wav", hydraulic_loop())
    write_wav("pickup_chime.wav", pickup_chime())
    write_wav("trash_rattle.wav", trash_rattle())
    write_wav("reverse_beep.wav", reverse_beep())
    print(f"Generated placeholder audio in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()

