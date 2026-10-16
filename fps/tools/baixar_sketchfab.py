#!/usr/bin/env python3
"""Baixa modelos do Sketchfab (só licenças que permitem uso em jogo comercial com crédito:
CC BY e CC0) em formato glTF para assets/modelos/<nome>/, com o arquivo de licença.

O token da API vem da variável de ambiente SKETCHFAB_TOKEN (nunca grave o token em arquivo):
  SKETCHFAB_TOKEN=... python3 -I tools/baixar_sketchfab.py
Os créditos vão para assets/CREDITOS_SKETCHFAB.md.
"""
import io
import json
import os
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "modelos"
CREDITS = ROOT / "assets" / "CREDITOS_SKETCHFAB.md"
ALLOWED = {"CC Attribution", "CC0 Public Domain"}

# nome da pasta -> uid do modelo no Sketchfab
MODELS = {
    "capacete_stahlhelm": "a0ae41c430ac4f1190fff89a3c565b4a",
    "caixote_municao_ww2": "d75a20ea23fe4ec0b63a3e6aa35ee57a",
    "caixotes_madeira_ww2": "c0118df63dd94b95a0100b0ba8e817f2",
    "caixa_municao_mg42": "e3be03e53d564f0d87e37ff05d517e4b",
    "telefone_campanha": "bccb73645bfa4925b76d4d52a5be3711",
    "lampiao": "db09a6bddee14139a51f53da91951450",
    "granada_haste": "58bde95b080244f2a60a0910d1f1f4a9",
    "binoculo": "a06f78bed3ef45068fe53eef00f90084",
    "sacos_areia": "8cda4370170746d393aa311a7c080c50",
    "lcvp": "e2edab27282d415db2351a47d164744b",
    "lcvp_aberto": "d112cbc8f65140b7a9118bb39d4db8e5",
    "sherman_destruido": "931f910486234ea683ce9fde5f9d008e",
    "contratorpedeiro": "2514094cc7ba415599e5ffea92395296",
    "casa_francesa": "b79fc74625354c2c8b693ae3b5645cf0",
    "capacete_m1": "6131ae334da74d279af337839fddee22",
    "galao": "612cdbbed93242c0b158c01fe2b5ea34",
    "bazuca": "6b1d0c8c2f78483d8b398b8d923a8928",
    "radio_scr300": "e2b40a2f3fa64c94bd39b06dbe0b5596",
    "p47": "3ff78eecd09d4398b6b1eef882c688a5",
}


def api(url, token):
    req = urllib.request.Request(url, headers={"Authorization": f"Token {token}"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def main():
    token = os.environ.get("SKETCHFAB_TOKEN")
    if not token:
        sys.exit("defina SKETCHFAB_TOKEN")
    credits = []
    for folder, uid in MODELS.items():
        info = api(f"https://api.sketchfab.com/v3/models/{uid}", token)
        license_label = (info.get("license") or {}).get("label", "")
        if license_label not in ALLOWED:
            print("pulado (licença):", folder, license_label)
            continue
        author = info["user"]["displayName"] or info["user"]["username"]
        credits.append((folder, info["name"], author, license_label, info["viewerUrl"]))
        dest = OUT / folder
        if (dest / "scene.gltf").exists() or any(dest.glob("*.glb")):
            print("já existe:", folder)
            continue
        link = api(f"https://api.sketchfab.com/v3/models/{uid}/download", token)["gltf"]["url"]
        with urllib.request.urlopen(link, timeout=300) as r:
            data = r.read()
        dest.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for member in z.namelist():
                target = (dest / member).resolve()
                if not str(target).startswith(str(dest.resolve())):
                    continue  # caminho suspeito dentro do zip
                if member.endswith("/"):
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(z.read(member))
        (dest / "LICENCA.txt").write_text(
            f"{info['name']} — {author}\n{info['viewerUrl']}\nLicença: {license_label}\n", encoding="utf-8")
        print("baixado:", folder, f"({len(data) // 1024} KB)")
    lines = ["# Modelos do Sketchfab", "", "Uso livre com crédito ao autor (CC BY 4.0) ou domínio público (CC0).", "",
             "| Pasta | Modelo | Autor | Licença | Link |", "|---|---|---|---|---|"]
    lines += [f"| `{f}` | {n} | {a} | {l} | {u} |" for f, n, a, l, u in credits]
    lines += ["", "Baixados por `tools/baixar_sketchfab.py`.", ""]
    CREDITS.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
