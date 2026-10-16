#!/usr/bin/env python3
"""Gera os sons PROVISÓRIOS do projeto (síntese simples, sem dependências).

Serão substituídos por gravações reais (ex.: Sonniss GDC Bundle). Mantenha os mesmos
nomes de arquivo para que a troca não exija mudanças no jogo.

Uso: python3 tools/gerar_sons.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "provisorio"


# --- utilitários ---------------------------------------------------------------

def samples(seconds):
    return int(seconds * RATE)


def noise(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(samples(seconds))]


def sine(freq, seconds, phase=0.0):
    return [math.sin(phase + 2 * math.pi * freq * i / RATE) for i in range(samples(seconds))]


def envelope(sig, attack, decay):
    """Ataque linear e decaimento exponencial (decay = tempo para cair ~63%)."""
    a = max(1, samples(attack))
    out = []
    for i, s in enumerate(sig):
        t = i / RATE
        g = (i / a) if i < a else math.exp(-(t - attack) / decay)
        out.append(s * g)
    return out


def lowpass(sig, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    alpha = (1.0 / RATE) / (rc + 1.0 / RATE)
    out, y = [], 0.0
    for s in sig:
        y += alpha * (s - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    low = lowpass(sig, cutoff)
    return [s - l for s, l in zip(sig, low)]


def mix(*layers):
    n = max(len(l) for l, _ in layers)
    out = [0.0] * n
    for layer, gain in layers:
        for i, s in enumerate(layer):
            out[i] += s * gain
    return out


def pad(sig, seconds):
    return sig + [0.0] * samples(seconds)


def reverb(sig, wet, size=1.0):
    """Reverb simples: combs em paralelo + lowpass (espaço aberto, praia)."""
    delays = [int(d * size) for d in (1557, 1617, 1491, 1422, 1277, 1356)]
    fb = 0.78
    out = list(sig)
    for d in delays:
        buf = [0.0] * len(sig)
        for i in range(len(sig)):
            prev = buf[i - d] if i >= d else 0.0
            buf[i] = sig[i] + prev * fb
        for i in range(len(sig)):
            out[i] += buf[i] * wet / len(delays)
    return lowpass(out, 5000)


def normalize(sig, peak=0.9):
    m = max(abs(s) for s in sig) or 1.0
    return [s * peak / m for s in sig]


def fade_out(sig, seconds=0.02):
    n = min(len(sig), samples(seconds))
    for i in range(n):
        sig[-1 - i] *= i / n
    return sig


def save(name, sig, peak=0.9):
    OUT.mkdir(parents=True, exist_ok=True)
    sig = fade_out(normalize(sig, peak))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in sig))
    print("ok", name)


# --- sons ----------------------------------------------------------------------

def disparo_garand():
    crack = envelope(highpass(noise(0.05), 2500), 0.0005, 0.006)
    corpo = envelope(lowpass(noise(0.35), 1800), 0.001, 0.05)
    grave = envelope(sine(55, 0.3), 0.002, 0.07)
    soco = envelope(lowpass(noise(0.2), 250), 0.001, 0.04)
    seco = mix((crack, 1.0), (corpo, 0.9), (grave, 1.2), (soco, 1.0))
    return reverb(pad(seco, 1.4), wet=0.9, size=1.3)


def ping():
    parciais = [(2650, 1.0, 0.35), (3980, 0.6, 0.25), (5420, 0.35, 0.18), (7300, 0.2, 0.1)]
    corpo = mix(*[(envelope(sine(f, 0.8), 0.0005, d), g) for f, g, d in parciais])
    clique = envelope(highpass(noise(0.02), 4000), 0.0002, 0.003)
    return reverb(mix((corpo, 0.8), (clique, 0.6)), wet=0.25, size=0.6)


def metal_clack(peso=1.0, brilho=3000):
    clique = envelope(highpass(noise(0.06), brilho), 0.0003, 0.004 * peso)
    batida = envelope(lowpass(noise(0.12), 1200), 0.0005, 0.015 * peso)
    ressoa = envelope(sine(900 / peso, 0.15), 0.001, 0.02)
    return mix((clique, 1.0), (batida, 0.7), (ressoa, 0.25))


def passo_areia():
    s = envelope(lowpass(highpass(noise(0.22), 300), 2500), 0.015, 0.05)
    return mix((s, 1.0), (envelope(lowpass(noise(0.15), 150), 0.01, 0.03), 0.6))


def impacto(tipo):
    if tipo == "areia":
        s = mix((envelope(lowpass(noise(0.3), 1500), 0.001, 0.05), 1.0),
                (envelope(lowpass(noise(0.2), 200), 0.001, 0.03), 0.7))
    elif tipo == "concreto":
        s = mix((envelope(highpass(noise(0.3), 1500), 0.0003, 0.012), 1.0),
                (envelope(lowpass(noise(0.4), 800), 0.001, 0.06), 0.5))
    elif tipo == "metal":
        s = mix((envelope(highpass(noise(0.05), 3000), 0.0002, 0.004), 0.8),
                (envelope(sine(1850, 0.5), 0.0005, 0.08), 0.5),
                (envelope(sine(2930, 0.5), 0.0005, 0.05), 0.3))
    elif tipo == "madeira":
        s = mix((envelope(lowpass(noise(0.2), 2500), 0.0005, 0.015), 1.0),
                (envelope(sine(320, 0.2), 0.001, 0.03), 0.4))
    else:  # agua
        s = mix((envelope(lowpass(highpass(noise(0.5), 400), 4000), 0.003, 0.09), 1.0),
                (envelope(lowpass(noise(0.3), 300), 0.002, 0.05), 0.5))
    return reverb(pad(s, 0.3), wet=0.3, size=0.8)


def impacto_corpo():
    soco = envelope(lowpass(noise(0.25), 400), 0.001, 0.035)
    grave = envelope(sine(70, 0.25), 0.001, 0.05)
    estalo = envelope(highpass(noise(0.05), 2000), 0.0005, 0.006)
    return mix((soco, 1.0), (grave, 0.9), (estalo, 0.35))


def batimento():
    """Dois batimentos (tum-tum) em 1 s, para tocar em loop."""
    def batida(f, d):
        return envelope(lowpass(sine(f, 0.25), 200), 0.008, d)
    out = [0.0] * samples(1.0)
    for start, f, g in ((0.0, 55, 1.0), (0.22, 48, 0.75)):
        b = batida(f, 0.06)
        o = samples(start)
        for i, v in enumerate(b):
            out[o + i] += v * g
    return out


def kit_medico():
    pano = envelope(lowpass(highpass(noise(0.5), 800), 5000), 0.05, 0.12)
    clique = envelope(highpass(noise(0.03), 3000), 0.0005, 0.005)
    return mix((pano, 0.8), (pad([0.0] * samples(0.3), 0) + clique, 0.5))


def bala_passando():
    """Estalo supersônico + zumbido curto."""
    estalo = envelope(highpass(noise(0.04), 3000), 0.0002, 0.003)
    zumbido = [math.sin(2 * math.pi * (900 - 500 * i / samples(0.25)) * i / RATE) for i in range(samples(0.25))]
    zumbido = envelope(mix((zumbido, 0.5), (lowpass(noise(0.25), 3000), 0.5)), 0.01, 0.06)
    return reverb(pad(mix((estalo, 1.0), (zumbido, 0.6)), 0.3), wet=0.4, size=1.0)


def disparo_kar98():
    """Fuzil inimigo: mais seco e agudo que o Garand, pensado para ser ouvido à distância."""
    crack = envelope(highpass(noise(0.05), 3000), 0.0004, 0.005)
    corpo = envelope(lowpass(noise(0.3), 2400), 0.001, 0.04)
    grave = envelope(sine(65, 0.25), 0.002, 0.05)
    return reverb(pad(mix((crack, 1.0), (corpo, 0.8), (grave, 0.8)), 1.4), wet=1.1, size=1.4)


def morte_inimigo():
    queda = envelope(lowpass(noise(0.4), 600), 0.01, 0.08)
    equipamento = envelope(highpass(noise(0.2), 2500), 0.002, 0.02)
    return mix((queda, 1.0), (pad([0.0] * samples(0.12), 0) + equipamento, 0.4))


def mg42_tiro():
    """Um tiro curto da MG42 — tocado ~20x por segundo forma o "rasgo" característico."""
    crack = envelope(highpass(noise(0.03), 2500), 0.0003, 0.004)
    corpo = envelope(lowpass(noise(0.12), 2000), 0.0005, 0.018)
    grave = envelope(sine(80, 0.1), 0.001, 0.02)
    return reverb(pad(mix((crack, 1.0), (corpo, 0.9), (grave, 0.8)), 0.15), wet=0.35, size=0.7)


def mg42_cauda():
    """Eco que fica no ar quando a rajada termina."""
    eco = envelope(lowpass(noise(2.0), 900), 0.02, 0.45)
    return reverb(eco, wet=0.8, size=1.6)


def marcador_acerto():
    return envelope(highpass(noise(0.04), 3500), 0.0003, 0.006)


def explosao():
    """Explosão de artilharia: estalo, estrondo grave longo e chuva de detritos."""
    estalo = envelope(highpass(noise(0.08), 1500), 0.0005, 0.01)
    estrondo = envelope(lowpass(noise(2.5), 300), 0.004, 0.35)
    sub = envelope(sine(38, 1.5), 0.005, 0.3)
    corpo = envelope(lowpass(noise(1.0), 1200), 0.002, 0.12)
    chuva = [0.0] * samples(2.5)
    for _ in range(140):
        t = random.uniform(0.25, 2.2)
        grao = envelope(highpass(noise(0.02), 2000), 0.0005, 0.004)
        o = samples(t)
        g = random.uniform(0.05, 0.25) * math.exp(-(t - 0.25) * 1.2)
        for i, v in enumerate(grao):
            if o + i < len(chuva):
                chuva[o + i] += v * g
    return reverb(mix((estalo, 0.9), (estrondo, 1.0), (sub, 1.3), (corpo, 0.8), (chuva, 0.8)), wet=0.6, size=1.6)


def ambiente_praia(seconds=24.0):
    """Loop de ambiente: ondas, vento e batalha distante (estrondos e tiros abafados)."""
    n = samples(seconds)
    vento = lowpass(noise(seconds), 400)
    ondas_base = lowpass(highpass(noise(seconds), 200), 1800)
    ondas = [v * (0.35 + 0.65 * max(0.0, math.sin(2 * math.pi * i / RATE / 6.5)) ** 2) for i, v in enumerate(ondas_base)]
    out = mix((vento, 0.5), (ondas, 0.7))
    # estrondos distantes
    for _ in range(9):
        t = random.uniform(0.0, seconds - 3.0)
        boom = envelope(lowpass(noise(2.5), 140), 0.02, 0.5)
        o = samples(t)
        g = random.uniform(0.4, 1.0)
        for i, v in enumerate(boom):
            out[o + i] += v * g
    # tiros e rajadas distantes
    for _ in range(70):
        t = random.uniform(0.0, seconds - 0.5)
        tiro = envelope(lowpass(noise(0.3), 900), 0.001, 0.03)
        rajada = random.random() < 0.25
        for k in range(random.randint(6, 14) if rajada else 1):
            o = samples(t + k * 0.06)
            g = random.uniform(0.08, 0.25)
            for i, v in enumerate(tiro):
                if o + i < n:
                    out[o + i] += v * g
    # suaviza a emenda do loop
    fade = samples(1.0)
    for i in range(fade):
        a = i / fade
        out[i] = out[i] * a + out[n - fade + i] * (1 - a)
    return out[: n - fade]


def fogo():
    """Crepitar de fogo (loop curto)."""
    base = lowpass(noise(6.0), 700)
    out = [v * 0.4 for v in base]
    for _ in range(160):
        t = random.uniform(0.0, 5.9)
        estalo = envelope(highpass(noise(0.03), 1500), 0.0005, 0.005)
        o = samples(t)
        g = random.uniform(0.1, 0.6)
        for i, v in enumerate(estalo):
            if o + i < len(out):
                out[o + i] += v * g
    return out


def estatica_radio():
    """Chiado de rádio (tocado junto com falas pelo rádio)."""
    chiado = lowpass(highpass(noise(0.9), 900), 4500)
    out = []
    for i, v in enumerate(chiado):
        t = i / RATE
        g = 0.6 + 0.4 * math.sin(2 * math.pi * 7.0 * t) * math.sin(2 * math.pi * 1.3 * t)
        out.append(v * g)
    return envelope(out, 0.02, 0.35)


def motor_barco(seconds=4.0):
    """Motor diesel da embarcação (loop): ronco grave pulsante."""
    n = samples(seconds)
    base = [math.sin(2 * math.pi * 42 * i / RATE) * 0.6 + math.sin(2 * math.pi * 84 * i / RATE) * 0.3 for i in range(n)]
    pulso = [0.7 + 0.3 * math.sin(2 * math.pi * 14 * i / RATE) for i in range(n)]
    ruido = lowpass(noise(seconds), 500)
    return [b * p + r * 0.5 for b, p, r in zip(base, pulso, ruido)]


def rampa():
    """Rampa de aço caindo na água: rangido, batida metálica e espirro d'água."""
    rangido = envelope([math.sin(2 * math.pi * (180 + 60 * math.sin(i / RATE * 9)) * i / RATE) for i in range(samples(1.2))], 0.1, 0.4)
    batida = pad([0.0] * samples(1.1), 0) + metal_clack(2.5, 1500)
    espirro = pad([0.0] * samples(1.12), 0) + envelope(lowpass(highpass(noise(1.0), 400), 5000), 0.005, 0.25)
    return reverb(mix((rangido, 0.25), (batida, 1.0), (espirro, 0.8)), wet=0.4, size=1.0)


def capsula_chao(variante):
    """Cápsula de latão quicando no chão (tinido + quique)."""
    random.seed(77 + variante)
    out = [0.0] * samples(0.5)
    t, g = 0.0, 1.0
    for _ in range(3):
        f1, f2 = random.uniform(3800, 4600), random.uniform(5800, 6800)
        tin = mix((envelope(sine(f1, 0.12), 0.0003, 0.025), 0.6), (envelope(sine(f2, 0.12), 0.0003, 0.015), 0.4),
                  (envelope(highpass(noise(0.01), 3000), 0.0002, 0.002), 0.5))
        o = samples(t)
        for i, v in enumerate(tin):
            if o + i < len(out):
                out[o + i] += v * g
        t += random.uniform(0.07, 0.12)
        g *= 0.45
    return out


def pente_chao():
    out = mix((metal_clack(1.8, 2500), 1.0), (pad([0.0] * samples(0.09), 0) + metal_clack(1.2, 3500), 0.4))
    return out


def granada_quique():
    """Granada de ferro batendo no chão: baque grave e metálico, curto."""
    return mix((metal_clack(2.4, 1200), 0.8), (envelope(lowpass(noise(0.08), 600), 0.001, 0.03), 0.6))


def pino():
    """Pino e alavanca da granada: estalo metálico fino."""
    return mix((metal_clack(0.5, 6000), 0.7), (pad([0.0] * samples(0.12), 0.0) + metal_clack(0.7, 4200), 0.5))


def arremesso():
    """Braço passando rápido: sopro filtrado."""
    sig = envelope(lowpass(highpass(noise(0.35), 300), 1800), 0.12, 0.15)
    return pad(sig, 0.4)


def pavio(seconds=3.0):
    """Pavio queimando: chiado contínuo com estalinhos."""
    sig = lowpass(highpass(noise(seconds), 2500), 7000)
    out = [v * (0.55 + 0.45 * math.sin(i / RATE * 37.0) ** 2) for i, v in enumerate(sig)]
    for _ in range(int(seconds * 14)):
        o = random.randrange(0, len(out) - 400)
        for i in range(200):
            out[o + i] += random.uniform(-1, 1) * (1 - i / 200) * 0.9
    return out


def arame():
    """Arame farpado sacudindo: tilintar metálico disperso."""
    out = [0.0] * samples(0.6)
    for _ in range(9):
        f = random.uniform(2500, 5200)
        tin = envelope(sine(f, 0.08), 0.0005, 0.02)
        o = random.randrange(0, len(out) - len(tin))
        for i, v in enumerate(tin):
            out[o + i] += v * random.uniform(0.2, 0.6)
    return mix((out, 1.0), (envelope(lowpass(noise(0.6), 900), 0.05, 0.3), 0.25))


def manuseio():
    """Equipamento de lona e metal sendo manuseado (pegar/plantar uma carga)."""
    a = envelope(lowpass(noise(0.25), 1500), 0.02, 0.1)
    return mix((pad(a, 0.5), 0.7), (pad([0.0] * samples(0.18), 0.0) + metal_clack(1.4, 1800), 0.5))


def passo_concreto():
    """Bota no concreto: estalo curto e seco + baque grave."""
    click = envelope(highpass(noise(0.05), 1500), 0.001, 0.012)
    thump = envelope(lowpass(noise(0.12), 220), 0.004, 0.03)
    return mix((click, 0.7), (thump, 0.8), (envelope(lowpass(highpass(noise(0.18), 600), 3000), 0.01, 0.05), 0.25))


def passo_madeira():
    """Tábua oca: baque com ressonância grave."""
    knock = envelope(sine(random.uniform(150, 200), 0.18), 0.002, 0.05)
    return mix((knock, 0.8), (envelope(lowpass(noise(0.1), 900), 0.002, 0.02), 0.5),
               (envelope(highpass(noise(0.03), 2000), 0.001, 0.008), 0.25))


def passo_agua():
    """Pé entrando e saindo da água rasa: chuá + borbulhas."""
    splash = envelope(lowpass(highpass(noise(0.45), 400), 4000), 0.03, 0.14)
    out = list(splash)
    for _ in range(6):
        f = random.uniform(500, 1400)
        b = envelope(sine(f, 0.06), 0.002, 0.02)
        o = random.randrange(0, len(out) - len(b))
        for i, v in enumerate(b):
            out[o + i] += v * 0.25
    return out


NOVOS = {
    "granada_quique": (granada_quique, 0.8), "pino": (pino, 0.6), "arremesso": (arremesso, 0.5),
    "pavio": (pavio, 0.6), "arame": (arame, 0.6), "manuseio": (manuseio, 0.6),
}
for _i in range(1, 4):
    NOVOS[f"passo_concreto_{_i}"] = (passo_concreto, 0.55)
    NOVOS[f"passo_madeira_{_i}"] = (passo_madeira, 0.55)
    NOVOS[f"passo_agua_{_i}"] = (passo_agua, 0.6)

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        # Gera só os sons pedidos (ex.: python3 tools/gerar_sons.py pavio arame)
        random.seed(1944)
        for nome in sys.argv[1:]:
            func, peak = NOVOS[nome]
            save(nome, func(), peak)
        sys.exit(0)
    random.seed(1944)
    save("garand_disparo", disparo_garand(), 0.95)
    save("garand_ping", ping(), 0.7)
    save("garand_seco", metal_clack(0.6, 5000), 0.5)
    save("garand_pente_entra", metal_clack(1.0, 2500), 0.7)
    save("garand_ferrolho", mix((metal_clack(1.6, 2000), 1.0),
                                (pad([0.0] * samples(0.07), 0.0) + metal_clack(1.2, 3000), 0.8)), 0.8)
    for i in range(1, 5):
        save(f"passo_areia_{i}", passo_areia(), 0.6)
    for tipo in ("areia", "concreto", "metal", "madeira", "agua"):
        save(f"impacto_{tipo}", impacto(tipo), 0.8)
    save("impacto_corpo", impacto_corpo(), 0.85)
    save("batimento", batimento(), 0.9)
    save("kit_medico", kit_medico(), 0.6)
    save("bala_passando", bala_passando(), 0.7)
    save("kar98_disparo", disparo_kar98(), 0.95)
    save("queda_corpo", morte_inimigo(), 0.7)
    save("mg42_tiro", mg42_tiro(), 0.9)
    save("mg42_cauda", mg42_cauda(), 0.6)
    save("marcador_acerto", marcador_acerto(), 0.4)
    save("explosao", explosao(), 0.95)
    save("ambiente_praia", ambiente_praia(), 0.7)
    save("fogo", fogo(), 0.6)
    save("estatica_radio", estatica_radio(), 0.6)
    save("motor_barco", motor_barco(), 0.6)
    save("rampa", rampa(), 0.9)
    for i in range(1, 4):
        save(f"capsula_chao_{i}", capsula_chao(i), 0.5)
    save("pente_chao", pente_chao(), 0.6)
    for nome, (func, peak) in NOVOS.items():
        save(nome, func(), peak)
