#!/usr/bin/env python3
"""Sintetiza todos os sons do jogo (efeitos .wav e trilha .ogg em loop).
Uso: python3 tools/gen_audio.py   (da raiz do projeto; precisa de numpy e ffmpeg)
Tudo é gerado por síntese: nenhuma amostra de terceiros."""
import os, subprocess, wave
import numpy as np

SR = 32000
rng = np.random.default_rng(7)
SFX_DIR = "assets/audio/sfx"
MUSIC_DIR = "assets/audio/music"
os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(MUSIC_DIR, exist_ok=True)

def t_(dur): return np.arange(int(SR * dur)) / SR
def hz(note):  # nota MIDI -> Hz
    return 440.0 * 2 ** ((note - 69) / 12)

def env(n, a=0.004, d=0.08, s=0.0, r=0.05, hold=None):
    """ADSR simples; s=0 => decaimento exponencial (som de sino/pluck)."""
    e = np.zeros(n)
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = max(ai, 1)
    e[:ai] = np.linspace(0, 1, ai)
    rest = n - ai
    if rest > 0:
        k = np.arange(rest) / SR
        e[ai:] = s + (1 - s) * np.exp(-k / max(d, 1e-3))
    if ri > 0 and n > ri:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e

def sine(f, dur, ph=0.0): return np.sin(2 * np.pi * f * t_(dur) + ph)
def tri(f, dur): return 2 / np.pi * np.arcsin(np.sin(2 * np.pi * f * t_(dur)))
def saw(f, dur): return 2 * ((f * t_(dur)) % 1.0) - 1
def square(f, dur): return np.sign(np.sin(2 * np.pi * f * t_(dur)))
def noise(dur): return rng.uniform(-1, 1, int(SR * dur))

def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1 - a) * x[i] + a * prev
        y[i] = prev
    return y

def lowpass_fast(x, cutoff, order=2):
    y = x
    for _ in range(order):
        y = lowpass(y, cutoff)
    return y

def bell(f, dur, ratio=3.5, index=2.0, decay=0.25):
    t = t_(dur)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * np.exp(-t / (decay * 0.6))
    return np.sin(2 * np.pi * f * t + mod) * env(len(t), 0.002, decay, 0, 0.02)

def place(buf, sig, at):
    i = int(at * SR)
    n = min(len(sig), len(buf) - i)
    if n > 0:
        buf[i:i + n] += sig[:n]
    return buf

def echo(x, delay, fb=0.35, taps=4, mix=0.5):
    out = x.copy()
    d = int(delay * SR)
    for k in range(1, taps + 1):
        sh = d * k
        if sh >= len(x): break
        out[sh:] += x[:len(x) - sh] * (fb ** k) * mix
    return out

def reverb(x, wet=0.25, size=1.0):
    """Reverb barata: ecos densos com decaimento (suficiente para dar 'ar' aos sinos)."""
    combs = [int(SR * s * size) for s in (0.0297, 0.0371, 0.0411, 0.0437)]
    sig = x.copy()
    for d in combs:
        for k in range(1, 6):
            sh = d * k
            if sh < len(x):
                sig[sh:] += x[:len(x) - sh] * (0.62 ** k) * 0.25
    return x * (1 - wet) + sig * wet

def finish(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak

def write_wav(path, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())

def sfx(name, x, peak=0.8):
    # pequeno fade-in/out para evitar cliques
    x = finish(x, peak)
    f = int(0.002 * SR)
    x[:f] *= np.linspace(0, 1, f); x[-f:] *= np.linspace(1, 0, f)
    write_wav(f"{SFX_DIR}/{name}.wav", x)

# ───────── efeitos ─────────
n = int(0.05 * SR)
sfx("click", (lowpass(noise(0.05), 5000) * env(n, 0.001, 0.012, 0, 0.01) * 0.6 + sine(1500, 0.05) * env(n, 0.001, 0.015, 0, 0.01) * 0.5), 0.55)
n = int(0.07 * SR)
sfx("nav", sine(880, 0.07) * env(n, 0.002, 0.02, 0, 0.02) * 0.6 + sine(1320, 0.07) * env(n, 0.002, 0.015, 0, 0.02) * 0.3, 0.5)
x = np.zeros(int(0.32 * SR))
for i, at in enumerate((0.0, 0.14)):
    place(x, (square(150, 0.14) * 0.5 + saw(75, 0.14) * 0.5) * env(int(0.14 * SR), 0.003, 0.06, 0, 0.03), at)
sfx("error", lowpass_fast(x, 1800), 0.6)
x = np.zeros(int(0.5 * SR))
place(x, bell(hz(76), 0.35, 3.0, 1.2, 0.18), 0.0); place(x, bell(hz(83), 0.4, 3.0, 1.2, 0.22), 0.09)
sfx("success", reverb(x, 0.25, 0.7), 0.7)
x = np.zeros(int(0.5 * SR))
for i, nt in enumerate((72, 76, 79)):
    place(x, tri(hz(nt), 0.18) * env(int(0.18 * SR), 0.004, 0.09, 0, 0.05), 0.07 * i)
sfx("hire", reverb(x, 0.2, 0.6), 0.7)
x = np.zeros(int(0.5 * SR))
for i, nt in enumerate((67, 64)):
    place(x, lowpass_fast(saw(hz(nt), 0.22), 1400) * env(int(0.22 * SR), 0.004, 0.12, 0, 0.06), 0.13 * i)
sfx("fire", x, 0.6)
x = np.zeros(int(0.7 * SR))
place(x, bell(hz(88), 0.5, 3.5, 1.5, 0.3), 0.0); place(x, bell(hz(93), 0.6, 3.5, 1.5, 0.35), 0.07)
sfx("cash", reverb(x, 0.2, 0.6), 0.7)
t = t_(0.14); ph = np.cumsum(2 * np.pi * np.linspace(380, 980, len(t)) / SR)
sfx("train", np.sin(ph) * env(len(t), 0.004, 0.08, 0.3, 0.04) * 0.8, 0.6)
x = np.zeros(int(0.9 * SR))
for i, nt in enumerate((72, 76, 79, 84)):
    place(x, bell(hz(nt), 0.5, 2.0, 1.0, 0.3), 0.075 * i)
sfx("research", reverb(x, 0.3, 0.8), 0.75)
x = np.zeros(int(0.8 * SR))
for i, nt in enumerate((79, 84, 88)):
    place(x, bell(hz(nt), 0.5, 2.5, 0.9, 0.3), 0.12 * i)
sfx("ready", reverb(x, 0.3, 0.8), 0.75)
# lançamento: acorde + arpejo (fanfarra curta)
x = np.zeros(int(1.8 * SR))
for nt in (60, 64, 67):
    place(x, (tri(hz(nt), 0.9) + 0.4 * saw(hz(nt), 0.9)) * env(int(0.9 * SR), 0.03, 0.5, 0.25, 0.3) * 0.5, 0.0)
for i, nt in enumerate((72, 76, 79, 84)):
    place(x, bell(hz(nt), 0.9, 2.0, 1.0, 0.45) * 0.9, 0.18 + 0.1 * i)
sfx("release", reverb(lowpass_fast(x, 7000, 1), 0.35, 1.1), 0.8)
x = bell(hz(69), 1.0, 3.0, 1.2, 0.5)
sfx("month", reverb(x, 0.3, 0.9), 0.55)
x = np.zeros(int(0.6 * SR))
place(x, bell(hz(74), 0.4, 2.0, 0.8, 0.25), 0.0); place(x, bell(hz(81), 0.5, 2.0, 0.8, 0.3), 0.1)
sfx("event_good", reverb(x, 0.25, 0.7), 0.65)
x = np.zeros(int(0.7 * SR))
place(x, lowpass_fast(saw(hz(50), 0.3), 900) * env(int(0.3 * SR), 0.01, 0.2, 0, 0.1), 0.0)
place(x, lowpass_fast(saw(hz(46), 0.4), 800) * env(int(0.4 * SR), 0.01, 0.25, 0, 0.12), 0.18)
sfx("event_bad", x, 0.6)
x = np.zeros(int(1.6 * SR))
for i, nt in enumerate((64, 62, 59, 55)):
    place(x, lowpass_fast(saw(hz(nt), 0.45), 1100) * env(int(0.45 * SR), 0.01, 0.3, 0, 0.15), 0.32 * i)
sfx("bankrupt", reverb(x, 0.3, 1.0), 0.7)

# ───────── trilha em loop (ambiente, 96 BPM, 8 compassos) ─────────
BPM = 96
beat = 60.0 / BPM
bars = 8
L = int(bars * 4 * beat * SR)
TAIL = int(3.0 * SR)
left = np.zeros(L + TAIL); right = np.zeros(L + TAIL)
chords = [  # (raiz grave, notas do pad, notas do arpejo)
    (45, (57, 60, 64, 67, 71), (69, 72, 76, 79, 83)),   # Am9
    (41, (53, 57, 60, 64, 67), (65, 69, 72, 76, 79)),   # Fmaj7
    (48, (55, 59, 64, 67, 71), (67, 71, 72, 76, 79)),   # Cmaj7
    (43, (55, 59, 62, 66, 69), (67, 71, 74, 78, 81)),   # Gadd9 (cor: G B D F# A)
]
def stereo_add(sig, at, pan):
    i = int(at * SR)
    n = min(len(sig), L + TAIL - i)
    if n <= 0: return
    left[i:i + n] += sig[:n] * (1 - pan) ** 0.5
    right[i:i + n] += sig[:n] * pan ** 0.5

for ci, (root, pad, arp) in enumerate(chords):
    at = ci * 2 * 4 * beat
    dur = 2 * 4 * beat + 1.4
    # pad: serras levemente desafinadas, filtradas, ataque lento
    for nt in pad:
        for det, pan in ((-0.12, 0.3), (0.12, 0.7)):
            f = hz(nt) * (1 + det / 100)
            s = lowpass_fast(saw(f, dur) * 0.5 + tri(f / 2, dur) * 0.5, 1400, 2)
            s *= env(len(s), 1.2, 3.0, 0.7, 1.2) * 0.07
            stereo_add(s, at, pan)
    # baixo: seno suave em pulsos de semínima
    for b in range(8):
        s = sine(hz(root), beat * 1.1) * env(int(beat * 1.1 * SR), 0.01, 0.5, 0.2, 0.2) * 0.22
        stereo_add(s, at + b * beat, 0.5)
    # arpejo: pluck de triângulo em colcheias, vozes alternando L/R com eco
    pattern = [0, 2, 4, 2, 1, 3, 4, 3, 0, 3, 2, 4, 1, 2, 3, 1]
    for k in range(16):
        nt = arp[pattern[k]]
        s = (tri(hz(nt), 0.5) * 0.7 + sine(hz(nt) * 2, 0.5) * 0.15) * env(int(0.5 * SR), 0.003, 0.18, 0, 0.1)
        s *= 0.10 * (0.7 + 0.3 * rng.random())
        stereo_add(s, at + k * beat * 0.5, 0.25 if k % 2 == 0 else 0.75)

# reverb/eco por canal (cada canal com tempos diferentes para largura)
def room(x, scale):
    out = x.copy()
    for d, g in ((0.043, 0.35), (0.067, 0.3), (0.101, 0.25), (0.157, 0.2), (0.233, 0.15), (0.331, 0.1)):
        sh = int(d * scale * SR)
        out[sh:] += x[:len(x) - sh] * g
    return out
left = room(echo(left, beat * 0.75, 0.35, 3, 0.45), 1.0)
right = room(echo(right, beat * 0.5, 0.35, 3, 0.45), 1.17)
# dobra a cauda sobre o começo => loop sem emenda
def fold(x):
    y = x[:L].copy()
    y[:TAIL] += x[L:L + TAIL]
    return y
stereo = np.stack([fold(left), fold(right)], axis=1)
stereo = stereo / (np.max(np.abs(stereo)) or 1.0) * 0.62
raw = "/tmp/music_raw.wav"
with wave.open(raw, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((np.clip(stereo, -1, 1) * 32767).astype("<i2").tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-c:a", "libvorbis", "-q:a", "3", f"{MUSIC_DIR}/ambient_loop.ogg"], check=True)
print("áudio gerado:", sorted(os.listdir(SFX_DIR)), os.path.getsize(f"{MUSIC_DIR}/ambient_loop.ogg") // 1024, "KB de música")
