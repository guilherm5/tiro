#!/usr/bin/env python3
"""Recorta tiros individuais da "Free Firearm Sound Library" (OpenGameArt, CC0).

Cada arquivo da biblioteca tem vários disparos com silêncio entre eles. Este script
detecta cada disparo, recorta com a cauda (eco), converte para mono 48 kHz 16 bits e
salva em assets/audio/armas/.

Uso: python3 -I tools/preparar_sons_armas.py "<pasta Prepared SFX Library>"
Biblioteca: https://opengameart.org/content/the-free-firearm-sound-library
"""
import struct
import sys
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "armas"

# (arquivo da biblioteca, prefixo de saída, duração máx. de cada tiro em s, máx. de tiros)
JOBS = [
    ("1917/B_24P.wav", "garand_tiro", 1.8, 4),            # Springfield 1917 .30-06, perto
    ("Mosin Nagant/M_26P.wav", "kar98_tiro", 2.2, 4),      # Mosin Nagant, média distância
    ("PPSh/P_30P.wav", "mg42_tiro", 0.16, 6),              # tiro curto (tocado ~20x/s)
]
# Cauda de rajada: o eco depois do último tiro de uma rajada longa.
TAIL_JOB = ("PPSh/P_22P.wav", "mg42_cauda", 2.0)


def read_mono_48k(path):
    with wave.open(str(path)) as w:
        channels, width, rate = w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(w.getnframes())
    frame = channels * width
    samples = []
    scale = float(1 << (8 * width - 1))
    for i in range(0, len(raw) - frame + 1, frame):
        total = 0.0
        for c in range(channels):
            b = raw[i + c * width: i + (c + 1) * width]
            if width == 3:
                v = int.from_bytes(b, "little", signed=True)
            elif width == 2:
                v = struct.unpack("<h", b)[0]
            else:
                v = struct.unpack("<i", b)[0]
            total += v / scale
        samples.append(total / channels)
    step = max(1, rate // 48000)
    # Decimação com média (filtro passa-baixa simples).
    return [sum(samples[i:i + step]) / step for i in range(0, len(samples) - step + 1, step)], rate // step


def find_onsets(sig, rate, min_gap=0.35):
    win = int(rate * 0.004)
    env = [max(abs(x) for x in sig[i:i + win]) for i in range(0, len(sig) - win, win)]
    peak = max(env)
    onsets, last = [], -1e9
    for k, e in enumerate(env):
        t = k * win
        if e > peak * 0.3 and (t - last) / rate > min_gap:
            onsets.append(t)
            last = t
    return onsets


def write(path, sig, rate, peak=0.95):
    m = max(abs(x) for x in sig) or 1.0
    sig = [x * peak / m for x in sig]
    fade = min(len(sig), int(rate * 0.04))
    for i in range(fade):
        sig[-1 - i] *= i / fade
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in sig))
    print("ok", path.relative_to(OUT.parent.parent.parent), f"{len(sig) / rate:.2f}s")


def main(library):
    for src, prefix, max_len, max_count in JOBS:
        sig, rate = read_mono_48k(library / src)
        onsets = find_onsets(sig, rate)
        for n, start in enumerate(onsets[:max_count], 1):
            begin = max(0, start - int(rate * 0.003))
            end = begin + int(rate * max_len)
            following = [o for o in onsets if o > start]
            if following:
                end = min(end, following[0] - int(rate * 0.02))
            write(OUT / f"{prefix}_{n}.wav", sig[begin:end], rate)
    src, name, length = TAIL_JOB
    sig, rate = read_mono_48k(library / src)
    # Último instante com som forte = fim da rajada; dali para frente é a cauda.
    win = int(rate * 0.004)
    peak = max(abs(x) for x in sig)
    last_loud = max(i for i in range(0, len(sig), win) if abs(sig[i]) > peak * 0.3)
    tail = sig[last_loud + int(rate * 0.03): last_loud + int(rate * (0.03 + length))]
    fade_in = int(rate * 0.03)
    for i in range(fade_in):
        tail[i] *= i / fade_in
    write(OUT / f"{name}.wav", tail, rate, 0.6)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
