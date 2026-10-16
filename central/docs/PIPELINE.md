# Pipeline: da referência ao personagem na Godot

Todos os comandos rodam a partir de `~/Documentos/central`.

```
referência (.webp)
   │ 1. recorte dos painéis (pillow)
   ▼
referencias/*.png ──► 2. rosto_textura.png (rosto com borda esfumada na cor da pele)
   │
   ▼ 3. blender/scripts/pci_v2.py (Blender sem interface)
   ├─► blender/arquivos/pci_v2.blend
   ├─► blender/renders/pci_v2_*.png            (conferência visual)
   ├─► exportados/pci_v2_mixamo.fbx ──► 4. Mixamo (manual) ──► FBX com esqueleto + animações
   └─► exportados/pci_v2.glb ──► 5. jogo/assets/... ──► Godot
```

## 1. Recortes da referência

A referência é uma prancha com vários painéis. Os recortes saem com o dobro do tamanho:
`corpo_frente`, `rosto`, `rosto_mascara`, `costas`, `katana`, `faixa`. As coordenadas dos
painéis estão no histórico (DIARIO.md, 14/10). Só precisa refazer se a imagem mudar.

## 2. Textura do rosto

`referencias/rosto_textura.png` = `rosto.png` com uma elipse esfumada em volta do rosto
e o resto pintado na cor da pele. A cor da pele é a média das bochechas e da testa,
escurecida 18% porque as bochechas estão com luz direta: **sRGB (129, 82, 55)**.
O material `pele` do Blender usa exatamente essa cor, em linear, para não ter costura.

Por que existe: o glTF não exporta mistura de nós de material. Com a borda já
esfumada na imagem, o material do rosto fica só "textura → cor base" e exporta igual
para FBX e glTF.

## 3. Modelo no Blender

```bash
ferramentas/blender -b --factory-startup --python blender/scripts/pci_v2.py
```

Leva ~30 s. Imprime `TRIANGULOS ...  DIMENSOES ...` e regrava tudo da lista acima.
O script é determinístico (cachos com semente fixa).

Convenções que todo personagem novo deve seguir (estão no topo do script):
1 unidade = 1 m, Z para cima, olhando para -Y, pés em Z=0, pose T, mãos abertas,
direita do personagem = -X (sufixo `_D`).

Armadilha que já custou duas rodadas: depois de `transform_apply` e nas malhas feitas
com bmesh, os vértices estão em coordenada **global**. E as primitivas do Blender já
nascem com uma camada UV: a projeção do rosto precisa sobrescrever essa, não criar outra.

## 4. Esqueleto e animações (Mixamo)

Precisa de conta Adobe (grátis). O upload e o auto-rig são manuais. Os downloads das
animações podem ser feitos por mim pelo Chrome (extensão Claude in Chrome), com você logado.

Armadilhas da interface: o menu de gêneros que abre ao digitar na busca cobre o primeiro
resultado da grade (clicar ali marca um filtro); feche-o clicando no título do visualizador.
O diálogo de download lembra as últimas opções. Escape apaga a busca.


1. Entre em https://www.mixamo.com e clique em **Upload Character**.
2. Envie `exportados/pci_v2_mixamo.fbx`.
3. Na tela de marcadores, posicione: queixo, pulsos, cotovelos, joelhos e virilha.
   Esqueleto: **Standard Skeleton (65)**.
4. Confira a prévia e avance.
5. Baixe primeiro o personagem sem animação: FBX Binary, **T-pose**, *With Skin*.
   Salve como `exportados/mixamo/pci_rig.fbx`.
6. Para cada animação abaixo, baixe FBX Binary, **Without Skin**, 30 fps,
   e salve em `exportados/mixamo/` com o nome da lista:

| arquivo | busca no Mixamo |
|---|---|
| `parado.fbx` | Fighting Idle (ou Bouncing Fight Idle) |
| `andar_frente.fbx` | Walking (marque *In Place*) |
| `andar_tras.fbx` | Walking Backwards (*In Place*) |
| `soco.fbx` | Punching (ou Lead Jab) |
| `chute.fbx` | Mma Kick (ou Roundhouse Kick) |
| `bloqueio.fbx` | Center Block |
| `dano.fbx` | Head Hit (ou Hit Reaction) |
| `derrota.fbx` | Knocked Out (ou Dying) |
| `vitoria.fbx` | Victory (ou Fist Pump) |

## 4b. Montagem (rig + animações → GLB)

```bash
ferramentas/blender -b --factory-startup --python blender/scripts/pci_montagem.py
cp exportados/pci_v4.glb jogo/assets/personagens/pci/
```

Importa o rig e as 9 animações, prende a katana inteira em `mixamorig:Spine2` (o auto-rig
tinha espalhado peso dela na cabeça e na coxa), cria uma faixa NLA por animação e exporta
`exportados/pci_v4.glb` (28 animações). Cada faixa vira uma animação com o mesmo nome na Godot.

A katana desembainhada é um modelo à parte: `blender/scripts/katana.py` gera
`katana.glb` direto em `jogo/assets/personagens/pci/`.
Para adicionar um golpe: baixe o FBX, ponha o nome na lista `ANIMS` do script, rode de
novo e meça com `jogo/ferramentas/medir_golpes.gd`.

## 5. Godot

Como jogar, arquitetura da luta e testes: [JOGO.md](JOGO.md).

```bash
cd jogo
../ferramentas/Godot_v4.7.2-stable_linux.x86_64 --headless --import   # importa assets novos
../ferramentas/Godot_v4.7.2-stable_linux.x86_64                        # roda a vitrine (gira o modelo)
../ferramentas/Godot_v4.7.2-stable_linux.x86_64 -e                     # abre o editor
```

Captura automática, sem ninguém olhando a tela (abre uma janela por ~5 s):

```bash
../ferramentas/Godot_v4.7.2-stable_linux.x86_64 --resolution 900x1100 -- --captura=$HOME/Documentos/central/docs/capturas/pci_v2_godot
```

Para atualizar o modelo no jogo: copie o novo `exportados/pci_vX.glb` para
`jogo/assets/personagens/pci/` e ajuste o `preload` em `jogo/scripts/vitrine.gd`.
