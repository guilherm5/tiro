# Créditos de assets de terceiros

Tudo que vem de fora do projeto, com fonte e licença. Atualize ao adicionar assets.

## Texturas e céu — Poly Haven (CC0)

Lista detalhada em `CREDITOS_POLYHAVEN.md` (gerada por `tools/baixar_polyhaven.py`).

## Sons de tiro — Freesound (CC0)

Montados em camadas por `tools/preparar_tiros.py` (`garand_tiro_*`, `garand_npc_tiro_*`,
`kar98_tiro_*`, `mg42_tiro_*`, `mg42_cauda`). Todas as fontes são CC0 (domínio público):
- "Rifle gunshot, one shot" — felix.blume — https://freesound.org/s/710084/
- "Mauser 98k Shooting" e "Mauser 98k - bolt-action mechanism sound" — Walking.With.Microphones — https://freesound.org/s/802675/ e https://freesound.org/s/802673/
- "a loud gunshot in the woods" — florianreichelt — https://freesound.org/s/563015/
- "Distant Gunshot" — Resaural — https://freesound.org/s/541164/

## Sons de armas (antigos) — The Free Firearm Sound Library (CC0)

- Fonte: https://opengameart.org/content/the-free-firearm-sound-library
- Licença: CC0 (domínio público, uso livre inclusive comercial).
- Recortados por `tools/preparar_sons_armas.py` para `assets/audio/armas/`:
  - `garand_tiro_*` ← Springfield 1917 (.30-06), perto
  - `kar98_tiro_*` ← Mosin Nagant, média distância
  - `mg42_tiro_*`, `mg42_cauda` ← PPSh (tocado mais grave para lembrar a MG42)

## Sons de recarga — "Gun reload sounds" (OpenGameArt, CC0)

- Fonte: https://opengameart.org/content/gun-reload-sounds — licença CC0.
- `garand_pente_entra.wav` ← gunreload1.wav (encaixe) · `garand_ferrolho.wav` ← assaultriflereload1.wav (ferrolho).

## Modelos 3D — Sketchfab (CC BY 4.0: uso livre com crédito ao autor)

- "WW2 German Wehrmacht Soldier" — Tactical_Beard — https://sketchfab.com/3d-models/ww2-german-wehrmacht-soldier-8f519608b01247fbb9d7bc119ce961ff
- "WW2 US Army Ranger" — Tactical_Beard — https://sketchfab.com/3d-models/ww2-us-army-ranger-dcbe89cd5de243af8e4677b769a831c6
- "WW2 Panzergrenadier 2k" — britdawgmasterfunk — https://sketchfab.com/3d-models/ww2-panzergrenadier-2k-cc0-6a104431bcb8400080b79446ec019696
- "Realistic M1 Garand (Updated)" — Kommander Karl — https://sketchfab.com/3d-models/realistic-m1-garand-updated-6fd36614d97d4f7e887ef0e2f2cf8733
- "Kar98k Free Model" — Danya (dsamuta) — https://sketchfab.com/3d-models/kar98k-free-model-e88c90c8e203401fa28e8f4ef03e657f

Modificações: esqueleto e pesos adicionados (`tools/blender/rig_soldado.py`), escala/orientação
ajustadas e texturas reduzidas a 2048 px (`tools/blender/preparar_arma.py`). Licenças originais
em `assets/personagens/*/LICENCA_CC-BY.txt` e `assets/armas/*/LICENCA_CC-BY.txt`.

## Objetos de cena — Sketchfab (CC BY 4.0) e Poly Haven (CC0)

Lista com autores e links em `CREDITOS_SKETCHFAB.md` (gerada por `tools/baixar_sketchfab.py`)
e `CREDITOS_POLYHAVEN.md`. Os modelos do Sketchfab foram reduzidos (tamanho real e texturas
de 1024 px) por `tools/blender/preparar_objeto.py`.

## Personagens e animações — Universal Animation Library (Quaternius, CC0; não usada mais nos soldados)

- Fonte: https://quaternius.com/packs/universalanimationlibrary.html (versão Standard; arquivo
  glTF do espelho https://github.com/J-Ponzo/gltf-universal-animation-library).
- Licença: CC0. Arquivo em `assets/personagens/ual/` (boneco + 46 animações).

## Animações de fuzil — Mixamo (Adobe)

Os três soldados receberam esqueleto pelo auto-rig do Mixamo (mixamo.com, conta do autor
do jogo) e as animações de fuzil (parado, andar, correr, mirar, atirar, agachado, mortes,
reação a tiro, granada) foram exportadas já no esqueleto de cada um. Licença do Mixamo:
uso livre, sem royalties, em jogos; não podem ser redistribuídas como arquivos de animação
avulsos. Montagem: `tools/blender/montar_mixamo.py` (ficam embutidas nos .glb).

## Vozes provisórias — Piper (voz neural)

- Programa: Piper (https://github.com/rhasspy/piper, licença MIT), geradas por `tools/gerar_vozes.py`.
- Vozes (https://huggingface.co/rhasspy/piper-voices):
  - `pt_BR-cadu-medium` (Miller), `pt_BR-jeff-medium` (Walker, soldado ferido),
    `pt_BR-faber-medium` (Hayes, rádio) — conjuntos de dados CC0.
  - `pt_BR-edresson-low` (Reed) — TTS-Portuguese-Corpus, Edresson Casanova, **CC BY 4.0**.
- São provisórias: serão trocadas por dublagem real (mesmos nomes de arquivo).

## Sons provisórios (do projeto)

`assets/audio/provisorio/` — sintetizados por `tools/gerar_sons.py`. Serão substituídos aos poucos.
