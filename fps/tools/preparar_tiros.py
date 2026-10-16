"""Monta os sons de tiro em camadas, a partir de gravações reais (Freesound, CC0).

Um tiro de jogo convincente não é uma gravação só: é o estalo de perto, o "corpo" grave,
o mecanismo da arma e a cauda (o eco do lugar), cada um vindo da melhor gravação para
aquela parte. As fontes estão em assets/CREDITOS.md.

Roda no Python do Blender (precisa de numpy e do módulo aud, que lê mp3):
  blender -b --factory-startup --python tools/preparar_tiros.py -- <pasta com os mp3>
Saída: assets/audio/armas/*.wav (48 kHz, 16 bits).
"""
import sys
import wave
from pathlib import Path

import aud
import numpy as np

SRC = Path(sys.argv[sys.argv.index("--") + 1])
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "armas"
RATE = 48000
rng = np.random.default_rng(1944)


def load(sound_id):
    """Gravação como array (amostras, 2) em 48 kHz."""
    sound = aud.Sound(str(SRC / f"{sound_id}.mp3")).resample(RATE, True)
    data = sound.data().astype(np.float64)
    if data.ndim == 1:
        data = data[:, None]
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    return data[:, :2]


def onset(sig, skip=0.0):
    """Primeiro instante (amostra) acima de 40% do pico, a partir de `skip` segundos."""
    mono = np.abs(sig).max(axis=1)
    start = int(skip * RATE)
    peak = mono[start:].max()
    return start + int(np.argmax(mono[start:] > peak * 0.4))


def cut(sig, start, length, fade_in=0.002, fade_out=0.05):
    part = sig[max(0, start): start + int(length * RATE)].copy()
    n_in, n_out = int(fade_in * RATE), int(fade_out * RATE)
    if n_in:
        part[:n_in] *= np.linspace(0.0, 1.0, n_in)[:, None]
    if n_out:
        part[-n_out:] *= np.linspace(1.0, 0.0, n_out)[:, None]
    return part


def one_pole(sig, cutoff, high=False):
    """Filtro de um polo (passa-baixa ou passa-alta), por canal."""
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    out = np.empty_like(sig)
    state = np.zeros(sig.shape[1])
    for i in range(len(sig)):
        state = (1.0 - a) * sig[i] + a * state
        out[i] = state
    return sig - out if high else out


def lowpass(sig, cutoff, order=2):
    for _ in range(order):
        sig = one_pole(sig, cutoff)
    return sig


def resample(sig, factor):
    """Muda a velocidade (e a altura) por `factor` (>1 = mais agudo e curto)."""
    n = int(len(sig) / factor)
    x = np.arange(n) * factor
    return np.stack([np.interp(x, np.arange(len(sig)), sig[:, c]) for c in range(sig.shape[1])], axis=1)


def thump(freq_start=95.0, freq_end=42.0, decay=0.11, length=0.35):
    """Grave curto (o "peso" do disparo que o microfone de campo não pega)."""
    t = np.arange(int(length * RATE)) / RATE
    freq = freq_end + (freq_start - freq_end) * np.exp(-t / 0.04)
    phase = 2.0 * np.pi * np.cumsum(freq) / RATE
    env = np.exp(-t / decay) * (1.0 - np.exp(-t / 0.002))
    sig = np.sin(phase) * env
    return np.stack([sig, sig], axis=1)


def mix(length, *layers):
    """Soma camadas (sinal, início em s, ganho em dB)."""
    out = np.zeros((int(length * RATE), 2))
    for sig, at, gain_db in layers:
        start = int(at * RATE)
        n = min(len(sig), len(out) - start)
        out[start:start + n] += sig[:n] * 10 ** (gain_db / 20.0)
    return out


def finish(sig, peak_db=-1.0, drive=1.6):
    """Saturação suave (segura os picos e dá densidade) e normalização."""
    sig = sig / (np.abs(sig).max() + 1e-9)
    sig = np.tanh(sig * drive) / np.tanh(drive)
    return sig / np.abs(sig).max() * 10 ** (peak_db / 20.0)


def save(name, sig, mono=False):
    if mono:
        sig = sig.mean(axis=1, keepdims=True)
    fade = int(0.02 * RATE)
    sig[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    data = (np.clip(sig, -1.0, 1.0) * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(data.shape[1])
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"ok {name}.wav {len(sig) / RATE:.2f}s {'mono' if mono else 'estéreo'}")


# --- fontes ---------------------------------------------------------------------------
rifle = load("710084")       # tiro de fuzil, estéreo, gravação de campo (felix.blume)
mauser = load("802675")      # Mauser 98k de perto (Walking.With.Microphones)
woods = load("563015")       # tiro na mata, cauda longa em estéreo (florianreichelt)
distant = load("541164")     # tiro distante com eco (Resaural)
bolt = load("802673")        # mecanismo do Mauser (Walking.With.Microphones)

rifle_hit = rifle[onset(rifle) - 96:]
mauser_hit = mauser[onset(mauser) - 96:]
woods_hit = onset(woods)
woods_tail = woods[woods_hit + int(0.06 * RATE):]
distant_tail = distant[onset(distant) + int(0.05 * RATE):]
clack = cut(bolt, onset(bolt) - 48, 0.09, fade_out=0.04)

# --- M1 Garand do jogador (estéreo) -----------------------------------------------------
# Corpo: tiro de fuzil; estalo: o começo do Mauser; grave sintético; mecanismo; cauda da mata.
tails = [woods_tail, distant_tail, woods_tail]
for i, (speed, tail) in enumerate(zip([1.0, 0.97, 1.03], tails), 1):
    body = resample(cut(rifle_hit, 0, 0.5, fade_out=0.25), speed)
    crack = one_pole(cut(mauser_hit, 0, 0.07, fade_out=0.04), 1500.0, high=True)
    tail_part = lowpass(cut(tail, 0, 2.2, fade_in=0.03, fade_out=0.9), 5000.0)
    shot = mix(2.4, (body, 0.0, 0.0), (crack, 0.0, -4.0), (thump(), 0.0, -3.0),
               (clack, 0.045, -16.0), (tail_part, 0.03, -17.0))
    save(f"garand_tiro_{i}", finish(shot, drive=1.2))

# --- tiros de NPC (mono, para som 3D) ---------------------------------------------------
# A cauda é curta: o eco do lugar vem da reverberação do jogo e a distância abafa os agudos.
for i, speed in enumerate([1.0, 0.96, 1.04], 1):
    body = resample(cut(mauser_hit, 0, 0.9, fade_out=0.5), speed)
    shot = mix(1.3, (body, 0.0, 0.0), (thump(110, 50, 0.08), 0.0, -6.0),
               (lowpass(cut(woods_tail, int(i * 0.1 * RATE), 1.2, fade_in=0.03, fade_out=0.6), 4000.0), 0.03, -16.0))
    save(f"kar98_tiro_{i}", finish(shot, drive=1.1), mono=True)
for i, speed in enumerate([1.0, 0.97], 1):
    body = resample(cut(rifle_hit, 0, 0.6, fade_out=0.3), speed)
    shot = mix(1.3, (body, 0.0, 0.0), (thump(), 0.0, -6.0),
               (lowpass(cut(distant_tail, 0, 1.2, fade_in=0.03, fade_out=0.6), 4000.0), 0.03, -16.0))
    save(f"garand_npc_tiro_{i}", finish(shot, drive=1.1), mono=True)

# --- MG42 (mono) --------------------------------------------------------------------------
# A MG42 dispara ~20 tiros/s o mesmo cartucho do Mauser: cada disparo é o estalo do Mauser,
# curto, com grave; tocados em sequência dão o "rasgo" característico.
for i in range(1, 6):
    speed = 1.0 + rng.uniform(-0.05, 0.05)
    start = int(rng.uniform(0, 0.002) * RATE)
    crack = resample(cut(mauser_hit, start, 0.11, fade_out=0.07), speed)
    shot = mix(0.14, (crack, 0.0, 0.0), (thump(120, 60, 0.035, 0.12), 0.0, -4.0))
    save(f"mg42_tiro_{i}", finish(shot, drive=2.0), mono=True)
save("mg42_cauda", finish(lowpass(cut(woods_tail, 0, 2.0, fade_in=0.03, fade_out=1.0), 3500.0)) * 0.7, mono=True)
