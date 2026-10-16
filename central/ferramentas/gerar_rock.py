"""Gera a trilha de rock do jogo por síntese (bateria, guitarra distorcida, baixo).

Uso: uv run --no-project --with numpy python ferramentas/gerar_rock.py
Saída: jogo/assets/sons/musica_luta.wav (loop de 16 compassos, 150 BPM, mi menor).
"""
import os
import wave

import numpy as np

TAXA = 44100
SAIDA = os.path.expanduser("~/Documentos/central/jogo/assets/sons/musica_luta.wav")
rng = np.random.default_rng(3)
BPM = 150
BATIDA = 60 / BPM
COMPASSOS = 16
total = np.zeros(int(TAXA * COMPASSOS * 4 * BATIDA) + TAXA)


def fir_passa_baixa(x, corte, taps=101):
    n = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(2 * corte / TAXA * n) * np.hamming(taps)
    return np.convolve(x, h / h.sum(), mode="same")


def colocar(som, tempo_batidas, ganho=1.0):
    i = int(tempo_batidas * BATIDA * TAXA)
    j = min(len(total), i + len(som))
    total[i:j] += som[: j - i] * ganho


def tt(seg):
    return np.arange(int(TAXA * seg)) / TAXA


# ---------- bateria ----------
def bumbo():
    t = tt(0.35)
    freq = 50 + 110 * np.exp(-t * 30)
    corpo = np.sin(2 * np.pi * np.cumsum(freq) / TAXA) * np.exp(-t * 9)
    clique = rng.uniform(-1, 1, len(t)) * np.exp(-t * 400) * 0.4
    return corpo + clique


def caixa():
    t = tt(0.25)
    ruido = rng.uniform(-1, 1, len(t))
    ruido = ruido - fir_passa_baixa(ruido, 1200)  # tira o grave do ruído
    tom = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    return ruido * np.exp(-t * 16) * 0.8 + tom * 0.6


def chimbal(aberto=False):
    t = tt(0.25 if aberto else 0.06)
    r = rng.uniform(-1, 1, len(t))
    r = r - fir_passa_baixa(r, 6000)
    return r * np.exp(-t * (12 if aberto else 70)) * 0.35


def prato():
    t = tt(1.6)
    r = rng.uniform(-1, 1, len(t))
    r = r - fir_passa_baixa(r, 4000)
    return r * np.exp(-t * 2.2) * 0.45


BUMBO, CAIXA, CHIMBAL, CHIMBAL_ABERTO, PRATO = bumbo(), caixa(), chimbal(), chimbal(True), prato()

for c in range(COMPASSOS):
    b = c * 4
    if c % 4 == 0:
        colocar(PRATO, b, 0.9)
    for k in range(8):
        colocar(CHIMBAL_ABERTO if k == 7 and c % 2 == 1 else CHIMBAL, b + k * 0.5, 0.9)
    for pos in (0, 1.5, 2.5) if c % 2 == 0 else (0, 0.5, 2, 2.5):
        colocar(BUMBO, b + pos, 1.0)
    colocar(CAIXA, b + 1, 0.9)
    colocar(CAIXA, b + 3, 0.9)
    if c % 4 == 3:  # virada de caixa no fim da frase
        for k in range(4):
            colocar(CAIXA, b + 3 + k * 0.25, 0.5 + k * 0.12)


# ---------- guitarra (power chords distorcidos) e baixo ----------
def nota_hz(semitons_de_mi2):
    return 82.41 * 2 ** (semitons_de_mi2 / 12)


def guitarra(semitom, batidas, abafada=False):
    seg = batidas * BATIDA * (0.55 if abafada else 0.97)
    t = tt(seg)
    sinal = np.zeros_like(t)
    for intervalo, peso in ((0, 1.0), (7, 0.8), (12, 0.6)):  # tônica, quinta, oitava
        f = nota_hz(semitom + intervalo)
        for desafinacao in (-0.12, 0.12):  # duas guitarras levemente fora = som cheio
            fase = 2 * np.pi * f * (1 + desafinacao / 100) * t
            sinal += peso * (2 * ((fase / (2 * np.pi)) % 1) - 1)  # dente de serra
    sinal = np.tanh(sinal * 6.0)  # distorção
    sinal = fir_passa_baixa(sinal, 2200 if abafada else 3800)
    envelope = np.minimum(1, t / 0.004) * (np.exp(-t * 14) if abafada else np.exp(-t * 0.8))
    return sinal * envelope


def baixo(semitom, batidas):
    seg = batidas * BATIDA * 0.95
    t = tt(seg)
    f = nota_hz(semitom - 12)
    s = np.tanh(np.sin(2 * np.pi * f * t) * 2.5) + 0.3 * np.sin(4 * np.pi * f * t)
    return fir_passa_baixa(s, 700) * np.minimum(1, t / 0.005) * np.exp(-t * 1.5)


# Parte A: palhetada abafada em mi com acentos (estilo riff de luta); parte B: acordes abertos.
riff_a = [(0, 0.5, True), (0, 0.5, True), (3, 0.5, False), (0, 0.5, True), (5, 0.5, False), (0, 0.5, True),
          (6, 0.5, False), (5, 0.5, False)]
riff_a2 = [(0, 0.5, True), (0, 0.5, True), (3, 0.5, False), (0, 0.5, True), (10, 0.5, False), (8, 0.5, False),
           (7, 0.5, False), (5, 0.5, False)]
acordes_b = [(8, 4), (10, 4), (0, 4), (0, 2), (3, 2)]

for c in range(COMPASSOS):
    b = c * 4
    if c < 8:
        riff = riff_a if c % 2 == 0 else riff_a2
        pos = 0.0
        for semitom, dur, abafada in riff:
            colocar(guitarra(semitom, dur, abafada), b + pos, 0.55)
            colocar(baixo(semitom, dur), b + pos, 0.5)
            pos += dur
pos = 8 * 4
for semitom, dur in acordes_b + acordes_b[:3] + [(5, 4)]:
    if pos >= COMPASSOS * 4:
        break
    colocar(guitarra(semitom, dur), pos, 0.5)
    for k in range(int(dur * 2)):  # baixo em colcheias por baixo dos acordes
        colocar(baixo(semitom, 0.5), pos + k * 0.5, 0.45)
    pos += dur

musica = total[: int(TAXA * COMPASSOS * 4 * BATIDA)]
musica = np.tanh(musica / np.max(np.abs(musica)) * 1.6) * 0.8  # "master" com leve compressão
borda = int(TAXA * 0.01)
musica[:borda] *= np.linspace(0, 1, borda)
musica[-borda:] *= np.linspace(1, 0, borda)
with wave.open(SAIDA, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(TAXA)
    w.writeframes((musica * 32767).astype(np.int16).tobytes())
print(f"musica_luta.wav  {len(musica) / TAXA:.1f}s  {BPM} BPM")
