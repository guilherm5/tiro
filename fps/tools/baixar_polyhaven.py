#!/usr/bin/env python3
"""Baixa texturas e céus do Poly Haven (licença CC0: uso livre, inclusive comercial).

Uso: python3 tools/baixar_polyhaven.py
Arquivos já baixados são pulados. Os créditos vão para assets/CREDITOS.md.
Para trocar ou adicionar um material, edite TEXTURES / HDRIS abaixo.
"""
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEX_DIR = ROOT / "assets" / "texturas"
SKY_DIR = ROOT / "assets" / "ceus"
CREDITS = ROOT / "assets" / "CREDITOS_POLYHAVEN.md"

# id do Poly Haven -> resolução. 1k basta para quase tudo (GPU integrada); areia em 2k
# porque cobre o chão inteiro e fica sempre perto da câmera.
TEXTURES = {
    "damp_beach_sand_02": "2k",   # areia molhada (beira d'água)
    "coast_sand_01": "2k",        # areia seca
    "concrete_wall_008": "1k",    # bunker e muro
    "rusty_metal_02": "1k",       # ouriços tchecos
    "green_metal_rust": "1k",     # embarcação de desembarque
    "hessian_230": "1k",          # sacos de areia (juta)
    "weathered_brown_planks": "1k",  # tábuas da trincheira e do bunker
    "sand_02": "2k",              # areia fina da praia
    "sparse_grass": "1k",         # chão com grama nas encostas
    "dry_ground_rocks": "1k",     # terra com pedras (encostas íngremes, crateras)
    "bark_brown_02": "1k",        # troncos das rampas e estacas da praia
    "rock_face_03": "1k",         # rocha exposta nas encostas íngremes
}
# Modelos (glTF): vegetação e objetos de cena.
MODELS = {
    "old_military_crate": "1k",
    "ammo_box": "1k",
    "WoodenTable_01": "1k",
    "WoodenChair_01": "1k",
    "coastal_cliff_01": "1k",
    "rock_face_01": "1k",
    "namaqualand_boulder_02": "1k",
    "rock_moss_set_01": "1k",
}
MODEL_DIR = ROOT / "assets" / "modelos"
# Mapas: cor, normal (padrão OpenGL, que o Godot usa) e rugosidade.
MAPS = {"Diffuse": "cor", "nor_gl": "normal", "Rough": "rugosidade"}

HDRIS = {"kloofendal_overcast_puresky": "2k", "overcast_soil_puresky": "4k"}

HEADERS = {"User-Agent": "OperacaoUltimaLinha-asset-fetch/1.0"}


def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as r:
        return json.load(r)


def download(url, dest):
    if dest.exists() and dest.stat().st_size > 0:
        print("  já existe:", dest.relative_to(ROOT))
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=300) as r:
        dest.write_bytes(r.read())
    print("  baixado:", dest.relative_to(ROOT), f"({dest.stat().st_size // 1024} KB)")


def author_of(asset_id):
    info = get_json(f"https://api.polyhaven.com/info/{asset_id}")
    return info.get("name", asset_id), ", ".join(info.get("authors", {}).keys())


def main():
    credits = []
    for asset_id, res in TEXTURES.items():
        print(asset_id)
        files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
        for key, label in MAPS.items():
            entry = files[key][res]["jpg"]
            download(entry["url"], TEX_DIR / asset_id / f"{asset_id}_{label}.jpg")
        credits.append((asset_id, *author_of(asset_id), "textura"))
    for asset_id, res in MODELS.items():
        print(asset_id)
        files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
        gltf = files["gltf"][res]["gltf"]
        download(gltf["url"], MODEL_DIR / asset_id / f"{asset_id}.gltf")
        for rel, entry in gltf.get("include", {}).items():
            download(entry["url"], MODEL_DIR / asset_id / rel)
        credits.append((asset_id, *author_of(asset_id), "modelo 3D"))
    for asset_id, res in HDRIS.items():
        print(asset_id)
        files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
        download(files["hdri"][res]["hdr"]["url"], SKY_DIR / f"{asset_id}_{res}.hdr")
        credits.append((asset_id, *author_of(asset_id), "céu HDRI"))

    lines = ["# Poly Haven (CC0 — domínio público, uso livre)", "",
             "| Asset | Nome | Autor(es) | Tipo |", "|---|---|---|---|"]
    lines += [f"| `{a}` | {n} | {au} | {t} |" for a, n, au, t in credits]
    lines += ["", "Fonte: https://polyhaven.com — baixado por `tools/baixar_polyhaven.py`.", ""]
    CREDITS.write_text("\n".join(lines), encoding="utf-8")
    print("créditos:", CREDITS.relative_to(ROOT))


if __name__ == "__main__":
    main()
