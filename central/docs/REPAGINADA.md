# Repaginada gráfica (estilo PS2): progresso

Pedido do Guilherme (14/10, noite): melhorar muito os gráficos no geral (personagem,
cenário etc.), aproximando do PS2. Pode decidir sobre o PCI. Fotos novas:
`referencias/pci_selfie.webp` (702x695, rosto de frente) e `referencias/pci_ilustracao.png`.

**Se a sessão parar no meio:** ler este arquivo e continuar do primeiro item não marcado.

## Decisões
- Rosto do PCI vem da selfie (6x mais resolução que a referência antiga), projetado de frente
  numa cabeça modelada de verdade (sobrancelha, nariz, boca, queixo, maçãs, orelhas).
- Cabelo: volume "high-top" com a textura dos cachos da própria foto; laterais em degradê.
- Corpo construído em volta das juntas reais do esqueleto do Mixamo
  (`blender/juntas_pci.json`) para deformar bem.
- **Sem passar pelo Mixamo de novo:** os pesos do esqueleto são transferidos da malha antiga
  (`pci_rig.fbx`) para a nova no Blender (Data Transfer).
- Texturas do corpo "assadas" (bake no Cycles): cor + sombreamento de oclusão num atlas,
  como os jogos de PS2. Variante vermelha (2P) assada separada.
- Cenário refeito no Blender com texturas CC0 e iluminação assada nas texturas.

## Pontos do rosto na selfie (pixels)
linha do cabelo y≈190 · sobrancelhas 240 · olhos 285 (x≈330 e 480) · ponta do nariz 350 ·
boca 395 · fim da barba 565 · bochechas x 270..545 · eixo central x≈408 ·
escala usada: 1 px = 0,000545 m · altura dos olhos no modelo: z = 1,695 m.

## Etapas
- [x] Fotos salvas, juntas do esqueleto extraídas
- [x] Textura do rosto v3 (`ferramentas/textura_rosto_v3.py` → `referencias/rosto_v3.png`)
- [x] Modelo PCI v3 no Blender (`blender/scripts/pci_v3.py`): 5.580 triângulos, cabelo é volume da própria cabeça
- [x] Bake do atlas do corpo (1P e 2P), 1024 px
- [x] Montagem v5: transferência de pesos + animações → `pci_v5.glb` (2.916 vértices, 0 sem peso)
- [x] Godot: atlas, troca de atlas no 2P, katana; 16 testes de mecânica passam
- [x] Cenário dojo v2 (`blender/scripts/cenario_dojo.py`, texturas CC0 do ambientCG em `texturas/`), luz assada (128 amostras, 14 min), na Godot via `scripts/cenario.gd` + `shaders/luz_assada.gdshader`
- [x] Sombra bolha, faíscas, anel de bloqueio, poeira, rastro da katana, clarão de K.O. (`scripts/efeitos.gd`)
- [x] HUD com retratos (recorte da selfie)
- [x] Vídeo (`docs/videos/luta_v3.mp4`) e documentação

## Problemas achados no caminho
- Fill do fundo da selfie com borrão gerava listras coloridas; trocado por cor sólida + borda suave.
- Cabelo como casca separada deixava vão e degrau; virou volume da própria cabeça.
- Projeção lateral pegava o canto do olho; agora usa uma faixa de bochecha sem feições.
- Ao trocar a função de projeção, apaguei junto o bloco do cabelo (cabeça virou "ovo"); recolocado.
- O .glb do cenário veio com materiais sem nome; o carregador usa a ordem gravada no json.
- Bake rápido (24 amostras) deixava tudo granulado; final com 128 amostras + desfoque nos mapas de luz.

## Ajustes finais de cor
- Luz quente x madeira quente saturava tudo de laranja: a luz assada é dessaturada 40% no
  shader (`saturacao_luz`), tatame tingido para "palha", piso menos laranja (tintas no json,
  sem refazer o bake).
- Lutadores escuros perto do cenário claro: luz ambiente mais quente e forte, lanternas mais
  fortes e uma luz direcional quente imitando o brilho dos painéis de papel.
- 3D em 50% da resolução (~640x360, perto dos 640x448 do PS2).

## Como refazer tudo
```bash
cd ~/Documentos/central
uv run --no-project --with pillow --with numpy python ferramentas/textura_rosto_v3.py
uv run --no-project --with pillow --with numpy python ferramentas/texturas_dojo.py
ferramentas/blender -b --factory-startup --python blender/scripts/pci_v3.py        # ~30 s
ferramentas/blender -b --factory-startup --python blender/scripts/pci_montagem.py  # ~1 min
cp exportados/pci_v5.glb jogo/assets/personagens/pci/
ferramentas/blender -b --factory-startup --python blender/scripts/cenario_dojo.py  # ~14 min (--rapido: ~1 min)
```
