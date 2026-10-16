"""Textura da cabeça do PCI v3 a partir da selfie.

Uso: uv run --no-project --with pillow --with numpy python ferramentas/textura_rosto_v3.py
Saída: referencias/rosto_v3.png (1024x1024)

Layout:
  x 0..702, y 0..695   selfie (escala 1:1) com o fundo apagado e os fones de ouvido removidos;
                       a cabeça e o cabelo são projetados de frente nessa área.
  x 720..1010          "nuca": cachos (topo), degradê raspado (meio) e pele (baixo), usada
                       pela parte de trás da cabeça (mapeamento cilíndrico).
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REF = os.path.expanduser("~/Documentos/central/referencias")
selfie = Image.open(os.path.join(REF, "pci_selfie.webp")).convert("RGB")
W, H = selfie.size
foto = np.asarray(selfie).astype(np.float32)

# --- silhueta da cabeça (cabelo + rosto + barba), traçada sobre a grade da foto ---
contorno = [(238, 200), (236, 140), (255, 85), (300, 45), (360, 28), (420, 24), (480, 34), (530, 65),
            (556, 115), (562, 170), (556, 215), (552, 260), (556, 330), (553, 385), (538, 440), (512, 515),
            (470, 572), (408, 592), (346, 575), (302, 518), (276, 445), (262, 390), (258, 330), (262, 260),
            (250, 220)]
mascara = Image.new("L", (W, H), 0)
ImageDraw.Draw(mascara).polygon(contorno, fill=255)
m = np.asarray(mascara).astype(np.float32) / 255.0

# --- cores de referência: mediana das duas bochechas e do cabelo ---
pele = np.median(np.concatenate([foto[300:345, 292:330].reshape(-1, 3), foto[300:345, 480:518].reshape(-1, 3)]), 0)
pele = pele * np.array([0.8, 0.77, 0.72])   # a bochecha está com luz direta; o tom médio do rosto é mais escuro
cabelo = np.array([46.0, 30.0, 27.0])        # castanho bem escuro (a foto puxa para o roxo pela luz do céu)

# --- apaga os fones de ouvido (pretos, dentro das orelhas) com a cor da pele ---
fones = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(fones)
d.ellipse((256, 340, 282, 392), fill=255)   # orelha esquerda da foto
d.ellipse((540, 310, 560, 360), fill=255)   # orelha direita da foto
f = np.asarray(fones.filter(ImageFilter.GaussianBlur(3))).astype(np.float32)[..., None] / 255.0
foto = foto * (1 - f) + pele * 0.85 * f

# --- céu aparecendo entre os cachos vira cor de cabelo; tira o tom roxo do cabelo ---
lum = foto.mean(2)
ys = np.arange(H)[:, None]
regiao_cabelo = np.broadcast_to(ys < 182, lum.shape)
# tira o tom roxo gradualmente (cheio no cabelo, nada a partir do meio da testa)
tinta = np.clip((235 - ys) / 65.0, 0, 1)[..., None]
foto *= 1 - tinta * (1 - np.array([1.0, 0.92, 0.72]))
claro = (lum > 150) & regiao_cabelo
foto[claro] = cabelo
# cachos mais escuros e menos rosados (a luz do céu clareia as pontas na foto)
escurece = np.clip((200 - ys) / 30.0, 0, 1)[..., None] * np.broadcast_to(np.ones((1, W, 1)), (H, W, 1))
foto = foto * (1 - 0.35 * escurece) + cabelo * 0.35 * escurece * 0.6
# --- fundo claro (céu, muro) e folhas verdes perto das têmporas e orelhas viram pele ---
r, g, b = foto[..., 0], foto[..., 1], foto[..., 2]
xs = np.arange(W)[None, :]
lateral = np.broadcast_to((ys >= 182) & (ys < 470), lum.shape) & ((xs < 290) | (xs > 522))
fundo = lateral & ((lum > 175) | ((g > r + 4) & (g > b)))
foto[fundo] = pele

# --- fora da cabeça: cor sólida (cabelo em cima, pele embaixo), com a borda suavizada ---
fora = np.where(ys[..., None] < 230, cabelo, pele).astype(np.float32) * np.ones((H, W, 1), np.float32)
borda = np.asarray(mascara.filter(ImageFilter.GaussianBlur(5))).astype(np.float32)[..., None] / 255.0
foto = foto * borda + fora * (1 - borda)

# --- canvas 1024 ---
tela = np.zeros((1024, 1024, 3), np.float32)
tela[:H, :W] = foto
tela[H:, :W] = pele  # abaixo da foto: pele (pescoço)

# --- nuca: cachos da foto no topo, degradê no meio, pele embaixo ---
rng = np.random.default_rng(5)
cachos = Image.fromarray(foto[50:170, 300:520].astype(np.uint8)).resize((290, 300))
cachos = np.asarray(cachos).astype(np.float32)
x0, x1 = 720, 1010
for y in range(1024):
    if y < 300:
        linha = cachos[y]
    elif y < 650:
        t = (y - 300) / 350.0  # degradê: de cabelo curtinho para pele
        escuro = np.array([38, 26, 22], np.float32)
        ruido = rng.uniform(0, 1, (x1 - x0, 1))
        pontos = (ruido < (0.85 - 0.75 * t)).astype(np.float32)
        linha = pele * (1 - pontos) + escuro * pontos
        linha = linha * (0.9 + 0.1 * rng.uniform(0, 1, (x1 - x0, 1)))
    else:
        linha = np.tile(pele * 0.88, (x1 - x0, 1))
    tela[y, x0:x1] = linha
tela[:, x1:] = tela[:, x1 - 1:x1]
tela[:, W:x0] = tela[:, x0:x0 + 1]
img = Image.fromarray(np.clip(tela, 0, 255).astype(np.uint8))
# suaviza só a faixa da nuca (o degradê de pontos fica com cara de cabelo raspado)
nuca = img.crop((x0, 300, x1, 650)).filter(ImageFilter.GaussianBlur(0.8))
img.paste(nuca, (x0, 300))
img.save(os.path.join(REF, "rosto_v3.png"))
print("rosto_v3.png", img.size, "pele média", pele.round())
