# Central: jogo de luta 3D estilo PS2

**Para jogar:** `~/Documentos/central/jogar.sh` (ou `jogar.sh demo` para CPU contra CPU).
Vídeo de uma luta completa: `docs/videos/luta_demo.mp4`.

Estado atual do projeto. O histórico do que foi feito está em [DIARIO.md](DIARIO.md)
e o passo a passo para refazer qualquer arquivo em [PIPELINE.md](PIPELINE.md).

Última atualização: 14/10/2026.

## Onde estamos

| Fase | Situação |
|---|---|
| 1. Ambiente | ✅ |
| 2. Primeiro personagem | ✅ PCI com 28 animações (`pci_v4.glb`) e katana na mão |
| 3. Primeira luta | ✅ |
| A. Fundação | ✅ quadros fixos, golpes em dados, buffer, IA e testes pela mesma entrada |
| B. Movimentação | ✅ pulo, agachar, corrida, esquiva, passo lateral 3D, arena circular |
| C. Ataque e defesa | ✅ 4 botões, alto/médio/baixo/aéreo, defesa SF, agarrão + escape, queda e levantar |
| D. Combos | ✅ sequência 1-2-4, cancelamento em especial, malabarismo, escala de dano, contador |
| E. Especiais | ✅ shuriken, corte com katana, voadora, super com barra |
| F. Estrutura | ✅ menu, melhor de 3, pausa, treino, 2 jogadores, dificuldade |
| G. Apresentação | ✅ PCI v3 (rosto da selfie, cabelo, texturas assadas), dojo com luz assada e texturas CC0, efeitos, HUD com retratos, rock. Ver [REPAGINADA.md](REPAGINADA.md) |
| H. CPU | ✅ reage, defende alto/baixo, pune, malabarismo, anti-aéreo, 3 níveis |
| I. Segundo lutador | ⏳ próximo |

Detalhes de jogo, golpes e testes: [JOGO.md](JOGO.md).

## Ferramentas (todas verificadas rodando)

| Ferramenta | Versão | Caminho |
|---|---|---|
| Blender | 5.2.2 LTS | `ferramentas/blender` (atalho para `~/Documentos/blender-5.2.2-linux-x64 (4)/blender`) |
| Godot | 4.7.2 stable (GDScript, sem .NET) | `ferramentas/Godot_v4.7.2-stable_linux.x86_64` |
| Python para imagens | uv + pillow (temporário, `uv run --with pillow`) | não instala nada no sistema |

Máquina: Debian 13, 12 threads, 31 GiB RAM, GPU Intel Iris Xe (Vulkan, Mesa 25.0.7).
A Godot roda em Forward+ / Vulkan nessa GPU sem problema.

### Por que Godot e não Unreal
Decidido em 14/10. A UE5 no Linux é feita para NVIDIA/AMD dedicada, pede 60+ GB
e login Epic; a Iris Xe ia sofrer. O visual de PS2 não precisa de Lumen/Nanite.
A Godot tem ~75 MB, não pede conta e roda bem aqui.

## Personagem 1: PCI (o ninja)

Nome no jogo: **PCI**. Da referência: cabelo curto cacheado (degradê), bigode, cavanhaque, gola alta preta,
faixas cruzadas no peito, obi com nó na frente, antebraços enfaixados, calça larga,
perneiras enfaixadas, tabi. Katana nas costas: cabo sobre o ombro **direito**, bainha
descendo até o quadril esquerdo. Existe uma variante com máscara cobrindo nariz e boca.

### Versão atual: v2
- Arquivos: `exportados/pci_v2.glb` (Godot), `exportados/pci_v2_mixamo.fbx` (Mixamo),
  `blender/arquivos/pci_v2.blend`.
- 3.260 triângulos (personagem de PS2 tinha de 3 a 6 mil). 1,75 m de envergadura, 1,85 m de altura com o cabelo.
- Pose T, mãos abertas, uma malha só, 10 materiais.
- Rosto: foto da referência projetada de frente (estilo "foto no rosto" da época).
- Imagens: `blender/renders/pci_v2_*.png` e, já dentro da Godot, `docs/capturas/pci_v2_godot_*.png`.

### Limitações conhecidas da v2
- Cabelo: os cachos são esferas facetadas espalhadas no topo, ainda parecem "bolinhas".
- Rosto: a foto original tem só 511x762 px; o rosto inteiro ocupa ~200 px. Uma foto
  maior melhora direto a textura.
- As faixas são anéis geométricos; numa v3 dá para trocar por textura (menos triângulos, mais detalhe).
- Sem máscara: a variante com o rosto coberto ainda não existe.

## Próximo passo

**Segundo lutador** (fase I). Precisa de uma referência (imagem) e de um nome. O pipeline
já está pronto: modelo por script → Mixamo → `pci_montagem.py` adaptado → `dados/<nome>.json`.
Pendências conhecidas: emenda de tom na lateral do rosto do PCI; Hurricane Kick do Mixamo veio quebrado.

## Pastas

```
central/
├── referencias/   imagem conceito, recortes e rosto_textura.png
├── blender/
│   ├── scripts/   pci_v2.py (modelo), pci_montagem.py (rig + animações), katana.py
│   ├── arquivos/  .blend gerados
│   └── renders/   imagens do Blender
├── exportados/    FBX/GLB que saem do Blender
├── jogo/          projeto Godot (ver JOGO.md)
├── jogar.sh       abre o jogo
├── ferramentas/   Godot, atalho do Blender, gerar_sons.py
├── legado/        versões antigas dos scripts da luta (fase 3)
└── docs/          esta documentação + capturas/
```
