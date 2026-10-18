"""Rebuild LoB's original, deterministic mechanical feedback (no sampled assets)."""
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "새-게임-프로젝트/assets/audio/feedback"
RATE = 44100
# duration, body frequency, noise mix, decay, output peak
SOUNDS = {
    "click": (.045, 760, .32, 85, .16),
    "load": (.13, 340, .58, 34, .32),
    "confirm": (.18, 190, .40, 25, .36),
    "fire": (.22, 110, .76, 24, .58),
    "fire_power": (.30, 75, .72, 18, .65),
    "hit": (.12, 430, .65, 38, .35),
    "armor": (.20, 940, .25, 26, .32),
    "overheat": (.36, 520, .07, 8, .33),
    "reload": (.27, 240, .62, 17, .32),
    "cool": (.34, 180, .93, 9, .25),
    "ready": (.18, 610, .15, 25, .24),
    "reward": (.38, 660, .07, 11, .30),
}


def build(name, spec):
    duration, frequency, noise_mix, decay, peak = spec
    rng = random.Random(name)
    samples = []
    low = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        # Low-pass the noise instead of using piercing full-band white noise.
        low += .24 * (rng.uniform(-1, 1) - low)
        local_t = t
        f = frequency
        if name == "overheat":
            local_t = t % .18
            f *= 1 if t < .18 else .79
        elif name == "reward":
            local_t = t % .126
            f *= (1, 1.25, 1.5)[min(2, int(t / .126))]
        body = math.sin(2 * math.pi * f * local_t) + .22 * math.sin(2 * math.pi * f * 2.71 * local_t)
        envelope = min(1, local_t / .002) * math.exp(-decay * local_t)
        envelope *= min(1, (duration - t) / .018)
        value = (body * (1-noise_mix) + low * noise_mix * 2.4) * envelope
        # A second mechanical contact gives the magazine latch a tactile double step.
        if name in ("load", "confirm", "reload") and t > .055:
            dt = t - .055
            value += .28 * math.sin(2*math.pi*frequency*1.7*dt) * math.exp(-65*dt) * min(1, dt/.002)
        samples.append(value)
    maximum = max(abs(x) for x in samples)
    pcm = [round(x / maximum * peak * 32767) for x in samples]
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as file:
        file.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        file.writeframes(struct.pack("<" + "h" * len(pcm), *pcm))
    assert max(abs(x) for x in pcm) < 32767
    return {"file": path.name, "duration": duration, "peak": peak, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"origin": "Original procedural synthesis for ProjectLoB; no third-party recordings", "sample_rate": RATE,
                "generator": "tools/build_feedback_audio.py", "sounds": [build(name, spec) for name, spec in SOUNDS.items()]}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(SOUNDS)} original mono WAV cues; unclipped, bounded duration.")
