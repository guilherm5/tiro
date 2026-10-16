"""Gera todos os sons do jogo por síntese (nada baixado, sem licença de terceiros).

Uso: uv run --no-project --with numpy python ferramentas/gerar_sons.py
Saída: jogo/assets/sons/*.wav (16 bits, 44,1 kHz, mono) e musica_taiko.wav (loop, não usada).
A música da luta (rock) sai de ferramentas/gerar_rock.py.
"""
import os
import wave

import numpy as np

TAXA = 44100
SAIDA = os.path.expanduser("~/Documentos/central/jogo/assets/sons")
os.makedirs(SAIDA, exist_ok=True)
rng = np.random.default_rng(7)


def t(seg):
    return np.arange(int(TAXA * seg)) / TAXA


def env(n, ataque=0.002, decaimento=0.2):
    x = np.arange(n) / TAXA
    a = np.clip(x / max(ataque, 1e-4), 0, 1)
    return a * np.exp(-x / decaimento)


def ruido(seg):
    return rng.uniform(-1, 1, int(TAXA * seg))


def passa_baixa(x, corte):
    # filtro de um polo (simples e suficiente para "abafar")
    a = np.exp(-2 * np.pi * corte / TAXA)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def passa_alta(x, corte):
    return x - passa_baixa(x, corte)


def varredura(f0, f1, seg):
    tt = t(seg)
    freq = f0 * (f1 / f0) ** (tt / seg)
    return np.sin(2 * np.pi * np.cumsum(freq) / TAXA)


def salvar(nome, x, volume=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * volume
    dados = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(SAIDA, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(dados.tobytes())
    print(f"{nome}.wav  {len(x) / TAXA:.2f}s")


def soco(grave, seg, estalo):
    n = int(TAXA * seg)
    corpo = varredura(grave * 2.2, grave, seg) * env(n, 0.001, seg / 4)
    tapa = passa_alta(ruido(seg), 1500) * env(n, 0.0005, 0.012) * estalo
    abafado = passa_baixa(ruido(seg), 400) * env(n, 0.001, seg / 5) * 0.8
    return corpo + tapa + abafado


salvar("golpe_fraco", soco(150, 0.18, 0.9), 0.75)
salvar("golpe_forte", soco(90, 0.32, 1.4) + 0.4 * soco(60, 0.32, 0.0), 0.95)

# bloqueio: madeira/antebraço, curto e seco
n = int(TAXA * 0.12)
bloq = (np.sin(2 * np.pi * 820 * t(0.12)) + 0.6 * np.sin(2 * np.pi * 1340 * t(0.12))) * env(n, 0.0005, 0.02)
bloq += passa_alta(ruido(0.12), 2500) * env(n, 0.0003, 0.008) * 0.8
salvar("bloqueio", bloq, 0.7)

# corte de katana: assobio de ar + brilho metálico
n = int(TAXA * 0.45)
assobio = passa_alta(ruido(0.45), 2500) * np.sin(np.pi * np.clip(t(0.45) / 0.25, 0, 1)) ** 2
metal = sum(np.sin(2 * np.pi * f * t(0.45)) / (k + 1) for k, f in enumerate([2630, 3810, 5120])) * env(n, 0.06, 0.12)
salvar("corte", assobio * 0.8 + metal * 0.5 + soco(110, 0.45, 0.5) * 0.6, 0.9)

# vento (golpe no ar)
n = int(TAXA * 0.25)
salvar("vento", passa_alta(passa_baixa(ruido(0.25), 3000), 500) * np.sin(np.pi * t(0.25) / 0.25) ** 2, 0.5)

# queda: corpo no tatame
n = int(TAXA * 0.6)
queda = passa_baixa(ruido(0.6), 250) * env(n, 0.002, 0.12) * 2 + varredura(70, 45, 0.6) * env(n, 0.001, 0.15)
salvar("queda", queda, 0.9)

# gongo: parciais inarmônicas com batimento lento
n = int(TAXA * 3.0)
tt = t(3.0)
gongo = sum(a * np.sin(2 * np.pi * f * tt + 0.3 * np.sin(2 * np.pi * 2.1 * tt)) * np.exp(-tt / d)
            for f, a, d in [(110, 1.0, 1.6), (178, 0.7, 1.2), (262, 0.5, 0.9), (395, 0.35, 0.6), (523, 0.2, 0.4)])
gongo += passa_baixa(ruido(3.0), 600) * env(n, 0.001, 0.05)
salvar("gongo", gongo, 0.8)

# nocaute: estrondo grave com cauda
n = int(TAXA * 1.6)
ko = varredura(160, 35, 1.6) * env(n, 0.001, 0.5) + passa_baixa(ruido(1.6), 300) * env(n, 0.001, 0.35) * 1.5
salvar("ko", ko + 0.5 * gongo[:n], 1.0)

# agarrão: pano puxado
n = int(TAXA * 0.3)
salvar("agarrao", passa_baixa(passa_alta(ruido(0.3), 800), 4000) * env(n, 0.02, 0.08) + soco(130, 0.3, 0.2) * 0.4, 0.6)

# shuriken: assobio agudo + "tim"
n = int(TAXA * 0.35)
sh = varredura(3000, 1800, 0.35) * 0.3 * np.sin(np.pi * t(0.35) / 0.35) + passa_alta(ruido(0.35), 4000) * 0.3
sh += np.sin(2 * np.pi * 4200 * t(0.35)) * env(n, 0.001, 0.05) * 0.5
salvar("shuriken", sh, 0.6)

# super: ar subindo + acorde metálico
n = int(TAXA * 1.0)
sup = varredura(200, 1600, 1.0) * np.clip(t(1.0) / 0.8, 0, 1) * 0.5
sup += sum(np.sin(2 * np.pi * f * t(1.0)) for f in [440, 554, 659, 880]) * env(n, 0.5, 0.4) * 0.3
sup += passa_alta(ruido(1.0), 3000) * np.clip(t(1.0) / 1.0, 0, 1) * 0.3
salvar("super", sup, 0.85)


# ---------- música: taiko + flauta pentatônica, loop de 16 compassos ----------
BPM = 132
batida = 60 / BPM
compassos = 16
dur = compassos * 4 * batida
musica = np.zeros(int(TAXA * dur))


def colocar(som, tempo, ganho=1.0):
    i = int(tempo * TAXA)
    j = min(len(musica), i + len(som))
    musica[i:j] += som[: j - i] * ganho


def taiko(grave=True):
    seg = 0.5 if grave else 0.18
    n = int(TAXA * seg)
    f = 62 if grave else 210
    return varredura(f * 1.8, f, seg) * env(n, 0.002, seg / 3) + passa_baixa(ruido(seg), 500 if grave else 2000) * env(n, 0.001, 0.03) * 0.6


T_GRAVE = taiko(True)
T_AGUDO = taiko(False)
padrao = [(0, 1, True), (1.5, 0.6, False), (2, 0.9, True), (3, 0.5, False), (3.5, 0.5, False)]
for c in range(compassos):
    for pos, g, grave in padrao:
        colocar(T_GRAVE if grave else T_AGUDO, (c * 4 + pos) * batida, g)
    if c % 4 == 3:  # virada no fim de cada frase
        for k in range(4):
            colocar(T_AGUDO, (c * 4 + 2 + k * 0.5) * batida, 0.7)

# escala pentatônica japonesa (in): mi, fá, lá, si, dó
escala = [329.6, 349.2, 440.0, 493.9, 523.3, 659.3, 698.5, 880.0]
melodia = [(0, 4, 2), (2, 3, 1), (3, 2, 1), (4, 0, 3), (8, 5, 2), (10, 4, 1), (11, 3, 1), (12, 2, 4),
           (16, 4, 2), (18, 6, 2), (20, 5, 1), (21, 4, 1), (22, 3, 2), (24, 2, 3), (27, 1, 1), (28, 0, 4)]


def flauta(freq, seg):
    tt = t(seg)
    vibrato = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * tt) * np.clip(tt / 0.3, 0, 1)
    fase = 2 * np.pi * np.cumsum(freq * vibrato) / TAXA
    tom = np.sin(fase) + 0.3 * np.sin(2 * fase) + 0.1 * np.sin(3 * fase)
    sopro = passa_alta(ruido(seg), 3000) * 0.08
    n = len(tt)
    forma = np.clip(tt / 0.06, 0, 1) * np.clip((seg - tt) / 0.12, 0, 1)
    return (tom + sopro) * forma[:n]


for volta in range(2):  # a frase de 8 compassos toca duas vezes
    base = volta * 32
    for pos, nota, tempos in melodia:
        colocar(flauta(escala[nota], tempos * batida * 0.95), (base + pos) * batida, 0.22)

# fade curto nas pontas para o loop não estalar
borda = int(TAXA * 0.01)
musica[:borda] *= np.linspace(0, 1, borda)
musica[-borda:] *= np.linspace(1, 0, borda)
salvar("musica_taiko", musica, 0.7)
