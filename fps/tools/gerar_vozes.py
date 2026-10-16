#!/usr/bin/env python3
"""Gera vozes PROVISÓRIAS (voz neural Piper) para todas as falas dos arquivos .dlg.

Cada fala vira assets/audio/voz/<id_da_fala>.wav — o jogo toca sozinho (ver
autoload/dialogue.gd). Quando houver dublagem real, basta substituir os arquivos
(mesmo nome; .ogg também funciona) e apagar os provisórios.

Uso: python3 -I tools/gerar_vozes.py <pasta_do_piper> <pasta_das_vozes> [--todas]
     Sem --todas, só gera falas que ainda não têm arquivo.
Piper: https://github.com/rhasspy/piper (MIT) · vozes: huggingface.co/rhasspy/piper-voices
"""
import math
import random
import re
import struct
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIALOGUE_DIR = ROOT / "data" / "dialogue"
OUT = ROOT / "assets" / "audio" / "voz"

# personagem -> (voz, velocidade: <1 = mais rápido)
CAST = {
    "MILLER": ("pt_BR-cadu-medium", 0.85),
    "REED": ("pt_BR-edresson-low", 0.92),
    "WALKER": ("pt_BR-jeff-medium", 0.88),
    "HAYES": ("pt_BR-faber-medium", 1.0),
    "RÁDIO": ("pt_BR-faber-medium", 1.05),
    "SOLDADO FERIDO": ("pt_BR-jeff-medium", 1.2),
    "OBSERVADOR": ("pt_BR-edresson-low", 0.9),
    "DUVAL": ("pt_BR-faber-medium", 1.05),
    "KELLER": ("pt_BR-cadu-medium", 1.0),
}
DEFAULT_VOICE = ("pt_BR-faber-medium", 1.0)

SPEAKER = re.compile(r"^([A-ZÀ-ÖØ-Ý][A-ZÀ-ÖØ-Ý ]*?)(?:,\s*([^:]+))?:\s*(.+)$")


def parse_lines():
    """Mesmas regras do DialogueParser do jogo: [id], NOME[, TAG]: texto."""
    lines = []
    for path in sorted(DIALOGUE_DIR.glob("*.dlg")):
        current, count = None, 0
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or line.startswith("@"):
                continue
            if line.startswith("[") and line.endswith("]"):
                current, count = line[1:-1].strip().lstrip("!").strip(), 0
                continue
            m = SPEAKER.match(line)
            if current and m:
                count += 1
                lines.append({"id": f"{current}_{count:02d}", "speaker": m.group(1).strip(),
                              "tag": (m.group(2) or "").strip(), "text": m.group(3).strip()})
    return lines


def tts_text(text):
    # Gritos em CAIXA ALTA: a voz lê melhor em caixa normal.
    letters = [c for c in text if c.isalpha()]
    if letters and all(c.isupper() for c in letters):
        text = re.sub(r"(^|[!?.]\s+)(\w)", lambda m: m.group(1) + m.group(2).upper(), text.lower())
    return text


def read_wav(path):
    with wave.open(str(path)) as w:
        r, n = w.getframerate(), w.getnframes()
        return [v / 32768 for v in struct.unpack("<%dh" % n, w.readframes(n))], r


def write_wav(path, samples, rate):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


def radio(samples, rate):
    """Rádio de campanha: faixa estreita, saturação e chiado."""
    def one_pole(sig, cutoff, high):
        rc = 1 / (2 * math.pi * cutoff)
        a = (1 / rate) / (rc + 1 / rate)
        out, y = [], 0.0
        for s in sig:
            y += a * (s - y)
            out.append(s - y if high else y)
        return out
    sig = one_pole(one_pole(samples, 450, True), 2800, False)
    sig = one_pole(sig, 2800, False)
    sig = [math.tanh(s * 4.0) / math.tanh(4.0) for s in sig]
    return [s * 0.8 + random.uniform(-0.03, 0.03) for s in sig]


def normalize(samples, peak):
    m = max((abs(s) for s in samples), default=1.0) or 1.0
    return [s * peak / m for s in samples]


def main(piper_dir, voices_dir, regenerate_all):
    OUT.mkdir(parents=True, exist_ok=True)
    piper = piper_dir / "piper"
    lines = parse_lines()
    made = 0
    for line in lines:
        dest = OUT / f"{line['id']}.wav"
        if dest.exists() and not regenerate_all:
            continue
        voice, speed = CAST.get(line["speaker"], DEFAULT_VOICE)
        shout = "!" in line["text"]
        tmp = OUT / "_tmp.wav"
        subprocess.run([str(piper), "--model", str(voices_dir / f"{voice}.onnx"), "--output_file", str(tmp),
                        "--length_scale", str(speed * (0.9 if shout else 1.0)), "--sentence_silence", "0.15"],
                       input=tts_text(line["text"]).encode("utf-8"), check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        samples, rate = read_wav(tmp)
        tmp.unlink()
        is_radio = line["speaker"] == "RÁDIO" or "RÁDIO" in line["tag"].upper()
        if is_radio:
            samples = radio(samples, rate)
        peak = 0.95 if shout else (0.55 if line["speaker"] == "SOLDADO FERIDO" else 0.8)
        write_wav(dest, normalize(samples, peak), rate)
        made += 1
        print("ok", line["id"], line["speaker"], "(rádio)" if is_radio else "")
    print(f"{made} falas geradas de {len(lines)}.")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), "--todas" in sys.argv)
