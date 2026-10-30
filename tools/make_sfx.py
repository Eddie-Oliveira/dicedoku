"""Generates the game's small original sound effects (16-bit mono WAV) into godot/assets/sfx/.
Run: python3 tools/make_sfx.py   (pure Python, no dependencies; deterministic)."""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "sfx")
rnd = random.Random(7)

def env(i, n, attack=0.01, release=0.6):
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = max(0.0, 1.0 - i / n) ** (1.0 / max(release, 0.05))
    return a * r

def tone(freq, dur, vol=0.5, release=0.6, wave_fn=math.sin, vib=0.0):
    n = int(SR * dur)
    return [vol * env(i, n, release=release) * wave_fn(2 * math.pi * freq * (i / SR) + vib * math.sin(2 * math.pi * 6 * i / SR)) for i in range(n)]

def sweep(f0, f1, dur, vol=0.4, release=0.8):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / SR
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * 9 * i / SR)
        out.append(vol * env(i, n, release=release) * trem * math.sin(ph))
    return out

def noise(dur, vol=0.3, release=0.3):
    n = int(SR * dur)
    return [vol * env(i, n, attack=0.001, release=release) * (rnd.random() * 2 - 1) for i in range(n)]

def mix(*parts, offsets=None):
    offsets = offsets or [0] * len(parts)
    n = max(int(o * SR) + len(p) for p, o in zip(parts, offsets))
    out = [0.0] * n
    for p, o in zip(parts, offsets):
        s = int(o * SR)
        for i, v in enumerate(p):
            out[s + i] += v
    return out

def save(name, data):
    peak = max(1e-6, max(abs(v) for v in data))
    k = 0.85 / peak if peak > 0.85 else 1.0
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * k)) * 32767)) for v in data))

os.makedirs(OUT, exist_ok=True)
clicks = [noise(0.03, 0.5, 0.15) for _ in range(6)]
save("roll", mix(*clicks, offsets=[0, 0.05, 0.11, 0.16, 0.24, 0.31]))
save("hold", tone(1400, 0.08, 0.35, 0.3))
save("lock", mix(noise(0.02, 0.6, 0.1), tone(180, 0.15, 0.5, 0.4), offsets=[0, 0.01]))
save("hit", mix(tone(880, 0.25, 0.4), tone(1320, 0.35, 0.4), offsets=[0, 0.08]))
save("miss", tone(140, 0.4, 0.5, 0.7, vib=4.0))
save("coin", mix(tone(1568, 0.18, 0.35, 0.3), tone(2093, 0.3, 0.35, 0.5), offsets=[0, 0.06]))
save("curse", mix(sweep(700, 180, 0.7, 0.45), noise(0.5, 0.08, 0.8)))
save("ward", mix(tone(660, 0.4, 0.3), tone(990, 0.5, 0.3), tone(1320, 0.6, 0.25), offsets=[0, 0.05, 0.1]))
save("buy", mix(tone(1175, 0.12, 0.3, 0.3), tone(1568, 0.12, 0.3, 0.3), tone(2349, 0.3, 0.3), offsets=[0, 0.07, 0.14]))
save("win", mix(*[tone(f, 0.35, 0.3) for f in (523, 659, 784, 1047)], offsets=[0, 0.12, 0.24, 0.36]))
save("turn", mix(tone(784, 0.5, 0.25, 0.8), tone(1175, 0.6, 0.18, 0.8), offsets=[0, 0.02]))
save("memo", mix(noise(0.12, 0.15, 0.5), tone(2000, 0.05, 0.08, 0.3), offsets=[0, 0.05]))
print("sfx written to", os.path.normpath(OUT))
