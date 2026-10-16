"""Texturas geradas para o dojo: estandartes com kanji, céu noturno, lua, papel de shoji.

Uso: uv run --no-project --with pillow --with numpy python ferramentas/texturas_dojo.py
Saída: texturas/gerado/*.png
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SAIDA = os.path.expanduser("~/Documentos/central/texturas/gerado")
os.makedirs(SAIDA, exist_ok=True)
FONTE = "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"
if not os.path.exists(FONTE):
    import glob
    FONTE = (glob.glob("/usr/share/fonts/**/DroidSansFallback*.ttf", recursive=True) or [None])[0]
rng = np.random.default_rng(9)


def papel(w, h, cor=(232, 218, 184), ruido=10):
    base = np.ones((h, w, 3), np.float32) * np.array(cor, np.float32)
    fibras = rng.normal(0, ruido, (h, w, 1)).astype(np.float32)
    img = Image.fromarray(np.clip(base + fibras, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    return img


# estandartes (kakejiku): papel creme, dois kanji na vertical, carimbo vermelho
for nome, texto in (("estandarte_budo", "武道"), ("estandarte_shinobi", "忍者"), ("estandarte_tamashii", "魂"), ("estandarte_shin", "心技体")):
    img = papel(256, 768)
    d = ImageDraw.Draw(img)
    # moldura de tecido escuro em cima e embaixo
    d.rectangle((0, 0, 256, 60), fill=(40, 26, 18))
    d.rectangle((0, 708, 256, 768), fill=(40, 26, 18))
    d.rectangle((0, 60, 18, 708), fill=(70, 48, 30))
    d.rectangle((238, 60, 256, 708), fill=(70, 48, 30))
    tam = 200 if len(texto) <= 2 else 160
    fonte = ImageFont.truetype(FONTE, tam)
    y = 100 if len(texto) > 1 else 260
    for ch in texto:
        d.text((128, y), ch, font=fonte, fill=(20, 16, 14), anchor="mt")
        y += tam + 10
    d.rectangle((150, 640, 200, 690), fill=(170, 30, 25))
    d.text((175, 665), "印", font=ImageFont.truetype(FONTE, 34), fill=(235, 200, 190), anchor="mm")
    img.save(os.path.join(SAIDA, nome + ".png"))

# papel de shoji (claro, fibroso)
papel(256, 256, (240, 228, 196), 8).save(os.path.join(SAIDA, "shoji.png"))

# céu noturno: azul escuro em cima, roxo perto do horizonte, estrelas
w, h = 2048, 512
y = np.linspace(0, 1, h)[:, None]
topo = np.array([6, 8, 22], np.float32)
horizonte = np.array([48, 30, 58], np.float32)
ceu = topo + (horizonte - topo) * (y ** 2.2)[..., None]
ceu = np.broadcast_to(ceu, (h, w, 3)).copy()
estrelas = rng.uniform(0, 1, (h, w)) > 0.9985
brilho = rng.uniform(120, 255, (h, w)) * (1 - y * 0.8)
ceu[estrelas] = np.stack([brilho[estrelas]] * 3, -1)
Image.fromarray(np.clip(ceu, 0, 255).astype(np.uint8)).save(os.path.join(SAIDA, "ceu.png"))

# lua: disco com manchas e halo
n = 512
yy, xx = np.mgrid[0:n, 0:n] / n - 0.5
r = np.sqrt(xx ** 2 + yy ** 2)
manchas = Image.fromarray((rng.uniform(0, 255, (64, 64))).astype(np.uint8)).resize((n, n), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))
m = np.asarray(manchas).astype(np.float32) / 255.0
disco = (r < 0.3).astype(np.float32)
cor = np.array([255, 246, 220], np.float32) * (0.82 + 0.18 * m[..., None])
halo = np.clip(1 - (r - 0.3) / 0.2, 0, 1)[..., None] * np.array([120, 120, 150], np.float32) * (r >= 0.3)[..., None]
lua = cor * disco[..., None] + halo
alfa = np.clip(disco + np.clip(1 - (r - 0.3) / 0.2, 0, 1) * (r >= 0.3) * 0.6, 0, 1) * 255
rgba = np.concatenate([np.clip(lua, 0, 255), alfa[..., None]], -1)
Image.fromarray(rgba.astype(np.uint8), "RGBA").save(os.path.join(SAIDA, "lua.png"))
print("texturas geradas em", SAIDA, "fonte:", FONTE)
