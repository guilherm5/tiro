# Diário do projeto

Registro do que foi feito, em ordem, com as decisões e os erros encontrados no caminho.

## 14/10/2026

### Auditoria do ambiente
- Debian 13 (trixie), kernel 6.12, Wayland. 12 threads, 31 GiB RAM, 15 GiB swap, 658 GB livres.
- GPU: só Intel Iris Xe (Raptor Lake). Sem NVIDIA. Vulkan via Mesa 25.0.7 instalado.
- Blender 5.2.2 LTS achado em `~/Downloads/blender-5.2.2-linux-x64`. Testado sem
  interface: Python interno, exportação FBX e glTF, render EEVEE e Workbench. Tudo OK.
- Unreal: não existe no disco (procurado no sistema de arquivos inteiro). Em
  `~/Documentos` havia só uma 4ª cópia do Blender.
- Disponíveis: git 2.47, python 3.13, uv, gcc, make, docker, node, dotnet.
  Faltam (não fizeram falta): git-lfs, pip3, clang, cmake.

### Estrutura
- Criada `~/Documentos/central` sem git, a pedido.
- Referência salva em `referencias/ninja_conceito.webp` (511x762) e recortada em 6 painéis
  com pillow via `uv run --with pillow` (nada instalado no sistema). Coordenadas dos recortes
  na imagem original: corpo_frente (0,0,305,763), rosto (305,0,511,235),
  rosto_mascara (305,235,511,420), costas (290,420,425,763), katana (425,420,511,620),
  faixa (425,620,511,763).

### Como transformar a referência em 3D: opções avaliadas
- Geração por IA local (TRELLIS, Hunyuan3D): exige CUDA/NVIDIA, inviável aqui.
- TripoSR na CPU: roda, mas a qualidade com uma imagem tão pequena seria baixa.
- Sites com plano grátis (Hunyuan3D web, Tripo, Meshy): exigem conta e mandam a foto
  para terceiros. Não usado.
- **Escolhido:** modelagem low-poly por script no Blender, com a foto do rosto como
  textura. Combina com o estilo PS2 e não depende de conta nem de GPU.

### Ninja v1 (descartado)
- Montado com primitivas. Três bugs até o primeiro render bom:
  1. O corte do cabelo comparava vértices como se fossem locais, mas `transform_apply`
     já tinha levado a posição para eles. Nada era cortado e o cabelo cobria o rosto.
  2. A projeção do rosto criava uma segunda camada UV; o material usava a primeira.
  3. Luz forte demais deixava a roupa preta cinza.
- Resultado: 28 mil triângulos, quase tudo em toros na resolução padrão. Silhueta de blocos.

### Ninja v2 (atual)
- Corpo feito de tubos com perfil (anéis com raio próprio): peito largo, cintura fina,
  calça bufante que afunila na perneira, mangas até o cotovelo, pele no cotovelo,
  antebraço enfaixado, mão aberta com dedos e polegar, tabi com dedão separado.
- Tabardo com abas em ponta na frente e atrás. Obi com nó e pontas.
- Bandoleira da katana cruzando do ombro direito ao quadril esquerdo, também nas costas.
- Cabelo: calota com corte degradê (alto na testa, baixo na nuca) e cachos só no topo.
- Rosto: em vez de misturar nós no material (o glTF não exporta), gerei
  `rosto_textura.png` com a borda já esfumada na cor da pele. A metade de trás da
  cabeça aponta para um canto de pele da textura, senão a nuca ganhava o rosto espelhado.
- Voltas de faixa como toros 8x4 (64 triângulos cada, antes 1.152).
- **3.260 triângulos.** Exportado em FBX (texturas embutidas, para o Mixamo) e GLB (Godot).

### Godot
- Decidido usar Godot em vez de Unreal (motivo em STATUS.md).
- Baixada a Godot 4.7.2 stable do GitHub oficial, conferida pelo SHA-512 publicado
  na release, extraída em `ferramentas/`.
- Criado `jogo/` com `project.godot`, a cena `cenas/vitrine.tscn` e `scripts/vitrine.gd`
  (luz de três pontos, modelo girando, modo de captura automática).
- Import sem interface OK: a Godot extraiu `ninja_v2_rosto_textura.png` do GLB.
- Rodou em Vulkan Forward+ na Iris Xe. Capturas em `docs/capturas/godot_v2_*.png`.
- Primeira captura com o preto cinza (luz ambiente 0,5); baixei para 0,2 e a luz
  principal de 1,6 para 1,1.

### Nome do personagem: PCI
- O ninja se chama **PCI**, inclusive no jogo.
- Script renomeado para `blender/scripts/pci_v2.py`. O objeto dentro do FBX agora se chama
  `PCI` (é o nome que aparece no Mixamo). Saídas: `exportados/pci_v2_mixamo.fbx`,
  `exportados/pci_v2.glb`, `blender/arquivos/pci_v2.blend`, `blender/renders/pci_v2_*.png`.
- Na Godot o modelo foi para `jogo/assets/personagens/pci/`. Reimportado e conferido
  com novas capturas (`docs/capturas/pci_v2_godot_*.png`).
- As saídas antigas `ninja_v2*` foram apagadas: eram geradas pelo script e estavam
  duplicadas. Os arquivos da v1 (`ninja_v1.*`) ficam como histórico.

### Rig do Mixamo recebido
- Baixado como `~/Downloads/pci_v2_mixamo.fbx` (392 KB) e copiado para
  `exportados/mixamo/pci_rig.fbx`. O original continua em Downloads.
- Conteúdo conferido no Blender: armature com 33 ossos `mixamorig:*` (um dedo por mão,
  porque os dedos do modelo são uma peça só; basta para luta), malha `PCI` ligada à
  armature, 1.779 vértices **todos** com peso, textura do rosto embutida, nenhuma animação
  (só a pose T, como esperado).
- Teste de deformação numa pose de guarda (render `blender/renders/pci_rig_teste_*.png`):
  ombros, cotovelos e mãos ok.
- **Defeito:** a katana ficou com 26 vértices em `Spine2` mas 12 em `Head` (ponta do cabo)
  e 3 em `LeftUpLeg` (ponta da bainha). Ao virar a cabeça o cabo entorta. Corrigir na montagem:
  toda a katana com peso 1,0 em `mixamorig:Spine2`.

### Animações do Mixamo (baixadas por mim pelo Chrome)
- Extensão Claude in Chrome conectada depois do login. Abri o Mixamo numa aba própria;
  o PCI já estava carregado na conta.
- Baixadas 9 animações (FBX Binary, Without Skin, 30 fps, sem redução de keyframes),
  renomeadas e movidas para `exportados/mixamo/`:

| arquivo | animação no Mixamo | quadros |
|---|---|---|
| `parado.fbx` | Fighting Idle | 99 |
| `andar_frente.fbx` | Walking (In Place) | 31 |
| `andar_tras.fbx` | Walking Backwards (In Place, postura de guarda) | 42 |
| `soco.fbx` | Punching | 30 |
| `chute.fbx` | Mma Kick (4ª variação, chute na altura do tronco) | 48 |
| `bloqueio.fbx` | Center Block | 48 |
| `dano.fbx` | Head Hit (uma das variações) | 37 |
| `derrota.fbx` | Knocked Out (cai para trás) | 148 |
| `vitoria.fbx` | Victory (braços para cima) | 135 |

- Validação no Blender: todas com os mesmos 33 ossos do `pci_rig.fbx`, nenhuma malha,
  andar sem deslocamento do quadril (In Place ok). Só a derrota se desloca (queda), esperado.
- Erro meu no meio: o menu de gêneros da busca cobria o primeiro resultado e o clique marcou
  o filtro "Skinning Test"; o download seguinte repetiu o Center Block. A cópia repetida
  (mesmo tamanho, só IDs internos diferentes) foi apagada.
- Durante a sessão as 3 cópias do Blender em `~/Downloads` foram para a Lixeira (limpeza do
  usuário). O atalho `ferramentas/blender` agora aponta para
  `~/Documentos/blender-5.2.2-linux-x64 (4)/blender`. Testado.

### Fase 3: primeira luta jogável
- `blender/scripts/pci_montagem.py`: rig + 9 animações → `exportados/pci_v3.glb` (816 KB).
  Katana inteira (56 vértices) presa em `Spine2`. Cada animação vira faixa NLA nomeada.
- Medição das animações na Godot (`jogo/ferramentas/medir_golpes.gd`): soco = mão direita,
  0,77 m à frente aos 45%; chute = pé esquerdo, 1,13 m aos 40% (chute alto, 1,28 m).
  Primeira versão do script falhou porque `_init` roda antes da cena entrar na árvore;
  movido para `_initialize` + esperar um quadro.
- `jogo/scripts/lutador.gd` e `jogo/scripts/luta.gd` (detalhes em JOGO.md). Arena montada
  em código: dojo à noite, shoji acesos, lanternas, tatame.
- Ajustes depois do primeiro teste CPU x CPU: a IA bloqueava ~60% dos golpes e a luta ia
  até o tempo acabar. Chance de bloqueio de 58% para 42%, dano 7/12 → 8/13.
  Depois disso: 6 de 6 lutas acabaram em K.O. (23–46 s), 3 vitórias para cada lado.
- Teste de controles (`teste_controles.gd`) achou um bug: com a CPU desligada, o P2 lia as
  teclas do P1 e andava junto. Controles separados por jogador; P2 ganhou teclas próprias
  (2 jogadores no mesmo teclado, F2). Teste passa (8 checagens).
- Vídeo de uma luta inteira gravado com o Movie Maker da Godot (30 fps, sem perder quadro)
  e convertido para MP4 com o ffmpeg do pacote `imageio-ffmpeg` (via `uv run`, nada instalado
  no sistema): `docs/videos/luta_demo.mp4`, 46 s, K.O. aos 39 s.
- Primeira gravação: o corpo caído saía do quadro na vitória (a animação de derrota joga o
  corpo ~1 m para trás). A câmera passou a seguir o quadril de cada lutador.
- `jogar.sh` na raiz abre o jogo.

## 14/10/2026 (noite): fases A a H

Decisões do Guilherme: bloqueio estilo Street Fighter (segurar trás), luta 3D com passo
lateral (Tekken), 4 botões estilo Tekken, só teclado.

### Animações novas (19, baixadas por mim pelo Chrome)
jab (Lead Jab), chute_circular (Roundhouse Kick), agachado (Crouching Idle), rasteira
(Leg Sweep), pulo (Jumping Up), chute_voador (Flying Kick), furacao (Hurricane Kick),
passo_esq/passo_dir (Left/Right Strafe, In Place), queda (Knocked Down), levantar (Getting
Up), gancho (Uppercut), lancado (Receiving An Uppercut), dano_corpo (Stomach Hit),
arremesso (Frisbee Throw), empurrao (Push), corte (Stable Sword Outward Slash),
corte_duplo (Great Sword Slash), reverencia (Quick Formal Bow).
- Buscar pela URL (`#/?query=...`) evita o menu de gêneros que atrapalhou da outra vez.
- O "Hurricane Kick" veio com os ossos parados (só o quadril anda): fora do jogo por ora.
- `pci_montagem.py` agora gera `pci_v4.glb` com 28 animações.

### Fase A: fundação
- Reescrita completa (versões anteriores em `central/legado/`).
- `entrada.gd`: histórico de 40 quadros, buffer de 8, meia-lua, toque duplo, toque curto.
  A IA e os testes usam a mesma entrada por uma fonte virtual.
- `lutador.gd`: lógica em quadros; golpes lidos de `dados/pci.json`; a animação corre em
  três ritmos (preparo/ativo/recuperação) para o pico cair nos quadros ativos.
- Movimento de raiz: as animações que andam sozinhas têm o deslocamento do quadril removido
  em tempo de carga; quem move o lutador é o código.
- Medição das animações relativa ao quadril (`medir_golpes.gd`, `curvas_golpes.gd`): a
  medida absoluta enganava (o chute voador "alcançava 2,57 m" porque o corpo andava junto).

### Fases B a E: movimentação, ataque/defesa, combos, especiais
- Pulo em 3 direções, agachar, corrida, esquiva, passo lateral (arco em volta do oponente),
  troca de lado ao pular por cima, arena circular.
- Níveis alto/médio/baixo/aéreo/agarrão; defesa em pé e agachada; agarrão com escape.
- Sequência 1-2-4, cancelamento em especial, lançamento + malabarismo, escala de dano,
  contra-ataque, contador de combo.
- Especiais por meia-lua: shuriken (projétil), corte com a katana (saca da bainha), voadora;
  super com barra (congela o oponente, zoom, 3 cortes).
- Katana na mão: modelo separado (`katana.py`), preso ao osso da mão. Dois problemas
  achados: (1) o rig do Mixamo tem escala 0,01, então a espada saía 100x menor; resolvido
  com um nó compensador. (2) A orientação certa (0, 0, −90) foi escolhida renderizando 6
  candidatas lado a lado (`calibrar_katana.gd`).

### Bugs que os testes pegaram
- Erros de tipo do GDScript (`max()`/`min()`/`get()` devolvem tipo genérico).
- Meia-lua ↓↘→ virava passo lateral (soltar ↓ rápido); agora passo lateral exige voltar ao neutro.
- Malabarismo não conectava: o lançado era jogado 1,4 m/s para trás e saía do alcance do jab
  (medido quadro a quadro: mão a 0,65–0,89 m, alcance 0,42 m). Recuo menor e lançado "flutua".
- Golpe médio passava por cima de quem estava agachado (geometria real); regra de jogo de luta aplicada.
- Shuriken errava de perto: o arremesso solta pela lateral; agora sai do peito.
- Super acertava 1 vez: janelas desalinhadas com a lâmina (medido quadro a quadro) e a
  katana virada para trás. Janelas refeitas: 19–26, 44–51, 63–71.
- Câmera cortava quem estava no ar; marcadores de round ovais.

### Equilíbrio (lutas CPU x CPU)
- Corte relâmpago dominava (15–22 acertos por luta): menos avanço, mais punível, CPU usa menos.
- Rounds acabavam no tempo: vida 170 → 140 e round de 60 → 90 s. Depois: todos os rounds em K.O.

### Fases F, G, H
- Menu com o PCI em 3D, modos VS CPU / 2 jogadores / treino / demonstração, dificuldade,
  lista de golpes lida do `pci.json`. Pausa (Esc). Melhor de 3 com marcadores. Treino com
  boneco configurável (F5), vida que volta, ficha de quadros do último golpe, caixas (F1).
- Som: 11 efeitos + música (taiko e flauta pentatônica, 29 s em loop), tudo sintetizado
  por `ferramentas/gerar_sons.py` (numpy via `uv run`). Nenhum arquivo de terceiros.
- Filtro de PS2: a primeira versão reduzia o jogo inteiro a 640x360 e estourou a interface;
  agora só o 3D é desenhado a 45% e ampliado.
- IA com 3 níveis (reação 24/16/11 quadros, defesa, punição, agressividade).

### Testes
- `teste_mecanicas.gd`: 16 checagens, todas passando.
- `teste_alcance.gd`: tabela de alcance de cada golpe.

### Música nova (pedido do Guilherme: "a música é bem paia")
- Trilha de rock sintetizada (`ferramentas/gerar_rock.py`): bateria, guitarra em power chords
  distorcida (duas "guitarras" levemente desafinadas), baixo; 150 BPM, mi menor, 25,6 s em loop.
  A trilha de taiko antiga continua gerável como `musica_taiko.wav`, sem uso.
- Música agora toca pelo `Config` (não reinicia entre menu e luta), volume padrão mais baixo
  e ajustável no menu (MÚSICA 0–10).
- Pasta `central/musica/`: qualquer .mp3/.ogg/.wav colocado lá toca no lugar da trilha gerada
  (ordem aleatória). Não baixo música com direitos autorais; essa pasta é para os arquivos do
  próprio Guilherme, uso local.
- Partida do Guilherme (versus, normal): perdeu o round 1 por K.O. aos 42 s, 5 acertos (só
  chutes: 4 chute alto, 3 circular, 1 rasteira) contra 14 da CPU, 5 deles de shuriken de longe.

## 14–15/10/2026: repaginada gráfica (estilo PS2)

Detalhes, problemas encontrados e como refazer: [REPAGINADA.md](REPAGINADA.md). Resumo:
- **PCI v3** (`pci_v3.py`): cabeça modelada com nariz, sobrancelha, órbitas, maçãs, lábios e
  queixo; rosto da selfie nova projetado de frente; cabelo high-top como volume da própria
  cabeça; corpo construído em volta das juntas do rig; 5.580 triângulos; tecido, faixas e
  couro com textura procedural e oclusão assadas num atlas 1024 (1P preto, 2P vermelho).
- **Sem Mixamo de novo**: pesos transferidos da malha antiga (`pci_montagem.py`, v5).
- **Dojo v2** (`cenario_dojo.py`): salão fechado com jardim noturno, texturas CC0 do
  ambientCG, estandartes com kanji gerados, taiko, suporte de bokken, lanternas; luz das
  lanternas, papel e lua assada em mapas de luz (Cycles), mostrada por um shader "luz
  assada" na Godot (nenhuma luz em tempo real no cenário).
- **Efeitos** (`efeitos.gd`): estrela + faíscas no acerto, anel azul no bloqueio, poeira na
  queda, rastro da katana, clarão no K.O.; sombra bolha sob os lutadores.
- **HUD** com retratos do PCI; menu com o dojo de fundo.
