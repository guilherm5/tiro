# Registro do trabalho autônomo

Modo execução autônoma (pedido de 2026-10-15): melhorar a Missão 1 e a sensação geral
do jogo sem esperar decisões. Este arquivo diz o que foi feito, como rodar e o que vem a seguir.

## Como rodar
- Jogo: abrir o projeto no Godot 4.7.2 e apertar F5 (cena principal = menu).
- Testes: `bash tests/rodar_testes.sh` (usam `user://progresso_teste.save`, nunca o save real).
- Depois de mexer em scripts com `class_name` novo: `godot --headless --editor --quit --path .`.

## Feito

### 1. Personagens corrigidos (animações de fuzil + malha virada)
- **Causa do "personagem bugado"**: a malha dos três soldados estava de costas para o
  esqueleto (`rig_soldado.py` errava qual lado é a frente). Por isso apareciam as mãos
  "de pistola" no rosto, o agachar inclinado para trás etc.
  - `tools/blender/rig_soldado.py`: a frente agora é detectada pela bota (a ponta avança
    mais à frente do tornozelo do que o calcanhar para trás).
- **Animações de fuzil do Mixamo** (16): parado com arma baixa, mirando, andar, correr,
  agachado andando, ajoelhado, atirar (em pé e agachado), 5 mortes, reação a tiro,
  granada, recarga.
  - `tools/blender/retarget_mixamo.py` converte as animações para o esqueleto UAL, no espaço do mundo,
    e **refaz também as animações da UAL** para o repouso do soldado.
  - Uso: `blender -b --factory-startup --python tools/blender/retarget_mixamo.py -- assets/personagens/ual/AnimationLibrary_Godot_Standard.gltf <soldado_rig.glb> <pasta_fbx> <saida.glb>`
  - Fluxo completo de um soldado: `rig_soldado.py` (modelo do Sketchfab → rig) → `retarget_mixamo.py`.
- `systems/characters/humanoid_visual.gd`:
  - árvore de animação própria quando o modelo tem as animações `MX_`;
  - em pé, as animações de fuzil; agachado, as pernas e o tronco da UAL com os braços do Mixamo;
  - ao mirar, tronco e braços tocam a mira (em pé ou agachado);
  - morte escolhida pela direção do tiro;
  - o fuzil fica na palma da mão;
  - a pele recebe só um quarto do clareamento.
- Créditos do Mixamo em `assets/CREDITOS.md`.

### 2. Sistemas novos para a Missão 1 (prontos e testados, ainda fora da fase)
- **Interação (E)**: `systems/interaction/interactable.gd` + `systems/player/interactor.gd`.
  Pode exigir, dar ou gastar um item, pedir para segurar E, e dispara um evento narrativo. O HUD mostra "[E] ..." e uma barra de progresso.
- **Granadas Mk2 (G)**: `systems/weapons/grenade/grenade.gd` + `systems/player/grenade_thrower.gd`
  (2 granadas, contador no HUD). A explosão ganhou `falloff_power`.
- **IA**: foge de granadas; modo `aggressive` (avança até perto); `grenades` (joga
  granada de haste no jogador escondido). Configura-se em `EnemySoldier`.
- **Terreno**: `BeachTerrain.trench` (pontos x, z, profundidade) cava uma trincheira.
- **Peças de fase** (scripts que montam o próprio modelo):
  - `levels/props/trincheira.gd`: tábuas, estacas, estrado e sacos de areia ao longo da trincheira;
  - `levels/props/arame_farpado.gd`: concertina, ponto para plantar o Bangalore (segurar E por 3 s), pavio de 7 s,
    explosão, eventos `bangalore_plantado`/`arame_destruido` e nova malha de navegação;
  - `levels/props/bangalore_pickup.gd`: torpedo no chão (dá o item "bangalore").
- Sons novos (sintetizados): `python3 tools/gerar_sons.py granada_quique pino arremesso pavio arame manuseio`.
- Textura nova: Poly Haven `weathered_brown_planks` → `assets/materiais/madeira_tabuas.tres`.
- Teste novo: `tests/teste_granada.gd` (granada mata, interação pega e planta).

### 3. Nova Missão 1 montada na fase (pronta e testada)
- Os nós foram acrescentados por `tools/montar_m1.gd` (idempotente; `godot --headless --path . -s $PWD/tools/montar_m1.gd`):
  Trincheira, MuroExtensaoEsq/Dir, Arame, PlacaSeteira (camada física 5 "blindagem", que só as balas do jogador atingem),
  LuzBunker, Aliados/Engenheiro (deitado), Itens/Bangalore, Inimigos/Trincheira1–4 e Municiador,
  5 coberturas na trincheira, marcadores novos e o gatilho FundosBunker.
- `data/missions/m1_desembarque.missao`: bangalore → arame → trincheira → mg (por dentro) → muro.
  Falas contextuais novas: troca de cano da MG (`mg_recarregando`) e granada inimiga.
- `data/dialogue/m1_desembarque.dlg`: 14 falas novas, com vozes Piper geradas.
- Navegação: raio do agente 0,35 m, inclinação máxima de 45°; a trincheira é mais larga, com talude suave (senão as quinas
  quebravam a malha), e as paredes da trincheira entram na navegação.
- IA de assalto: para a 2,5 m e dá coronhada a menos de 1,8 m (34 de dano).
- Interior do bunker com material de concreto escuro (`concreto_interior.tres`).
- Testes: `teste_narrativa` percorre a missão nova inteira; `teste_mg42` confere a chapa (tiro de frente não mata) e o tiro
  por dentro (mata). Toda a bateria passa.

### 4. Visual, áudio e desempenho
- **Menos fumaça e neblina**:
  - neblina com metade da densidade (0,0035) e névoa baixa 0,03;
  - colunas de fumaça mais ralas (24 partículas, alfa 0,55), e a que ficava atrás do bunker foi afastada;
  - fumaça de cano, de explosão e poeira de impacto mais curtas e transparentes.
- **Água**: menos reflexo em ângulo rasante; espuma em manchas (antes, um lençol branco na parte rasa).
- **Reverberação**: barramentos "Eco" (praia) e "Bunker" (sala de concreto), enviados pelas áreas `Acustica/*` da fase.
  O tiro do jogador ganha eco do lugar (`OneShotSound.play_echo`). Sons fortes perdem agudos com a distância.
- **Passos por superfície** (areia, concreto, madeira na trincheira, água) e **lentidão na água**
  (até 65% da velocidade a 1 m de profundidade). Sons sintéticos novos em `tools/gerar_sons.py`.
- **Desempenho** medido nesta Iris Xe a 720p: 60 fps estáveis, GPU entre 7 e 9 ms em todos os pontos
  (barco, praia, muro, trincheira, bunker).

### 5. Segunda rodada (pedido de 2026-10-16: personagens, tiro e cenário)
- **Personagens refeitos com o auto-rig do Mixamo.** A conversão das animações para o
  esqueleto da UAL deixava mãos abertas, mão esquerda fora do fuzil e poses tortas. Agora:
  - cada soldado (alemão, panzergrenadier, americano) foi enviado ao Mixamo, que criou o
    esqueleto no próprio modelo; as 17 animações de fuzil saem já nesse esqueleto;
  - `tools/blender/preparar_mixamo.py` (modelo do Sketchfab → FBX para o Mixamo) e
    `tools/blender/montar_mixamo.py` (FBX baixados + texturas originais → .glb; tira o avanço
    do quadril das animações em ciclo);
  - `systems/characters/humanoid_visual.gd` reescrito para o esqueleto do Mixamo;
  - `systems/characters/rifle_pose_modifier.gd` (novo): depois da animação, curva a coluna
    para a mira, põe o fuzil na mão direita e, mirando, leva a mão esquerda à telha (IK);
  - `rig_soldado.py` e `retarget_mixamo.py` ficaram obsoletos (o fluxo novo não os usa).
  - O personagem que já estava na conta do Mixamo (pci_v2_mixamo) foi restaurado no fim.
- **Tiros novos**, montados em camadas a partir de gravações reais (Freesound, CC0) por
  `tools/preparar_tiros.py`: estalo + corpo + grave + mecanismo + cauda de eco em estéreo
  para o Garand do jogador; versões mono para aliados (Garand) e inimigos (Mauser 98k de
  verdade); MG42 com o estalo do Mauser (mesmo cartucho) a 20 tiros/s. O eco extra do
  tiro do jogador baixou (o som já traz a cauda).
- **Cenário**:
  - terreno em camadas: areia fina seca, areia molhada, grama nas encostas, terra com pedras
    na trincheira e nos trechos íngremes (cores do vértice calculadas pelo `BeachTerrain`);
  - grama 3D nas encostas (`levels/props/vegetacao.gd` + `grama.gdshader`), com balanço
    de vento e dois níveis de detalhe;
  - água sem as manchas brancas (ondulações pequenas, espuma só na beira);
  - concreto envelhecido (`levels/props/concreto.gdshader`): escorridos, base úmida e
    camuflagem no bunker;
  - bunker detalhado: laje saliente, aba sobre a seteira, moldura recuada, muros laterais;
  - interior do bunker equipado: mesa com lampião (a luz sai dele), telefone de campanha,
    binóculo e capacete, caixas de munição da MG42, caixotes, granadas de haste, fuzis
    encostados, prateleira e cápsulas no chão; caixotes de munição na trincheira.
  - Tudo acrescentado por `tools/montar_cenario.gd` (idempotente).
  - Modelos: `tools/baixar_sketchfab.py` (CC BY; token só por variável de ambiente) e
    `tools/baixar_polyhaven.py`; reduzidos por `tools/blender/preparar_objeto.py`.
- **Desempenho**: 60 fps em todos os pontos medidos, GPU entre 7 e 9 ms (o terreno só lê
  cada camada onde ela aparece; a grama some a 45 m).
- Toda a bateria de testes passa.

### 6. Terceira rodada (2026-10-16: arma, braços, mortes, movimento, defesas, cenário)
- **Mira do Garand alinhada**: o cano do modelo está 1 cm fora do centro e a linha de mira
  subia 0,7°; o modelo foi reposicionado para o furo da alça e a massa caírem no eixo da
  câmera (a massa aparece dentro do anel). A arma ficou mais perto do olho ao mirar.
- **Braços em primeira pessoa** (`systems/player/first_person_arms.gd`): só os braços do
  soldado americano (`tools/blender/extrair_bracos.py`), presos ao modelo da arma (o
  ombro direito na soleira da coronha); IK leva as mãos ao punho e à telha em qualquer pose.
  IK compartilhado em `systems/characters/arm_ik.gd`.
- **Mortes com corpo mole** (`systems/characters/ragdoll.gd`): na morte o esqueleto vira
  ossos físicos com juntas, empurrado na direção do tiro. Para isso os modelos passaram a
  ser exportados em metros (`montar_mixamo.py` aplica a escala do Mixamo).
- **Movimento dos NPCs**: o ritmo dos passos acompanha a velocidade (velocidades naturais
  das animações medidas pelo pé apoiado); quem se desloca para longe da direção do alvo ou
  corre olha para onde vai (antes deslizava de lado/de costas com o andar para a frente).
- **Defesas da praia** (`levels/props/obstaculo_praia.gd`): ouriços de cantoneira com chapa
  rebitada, portões belgas na água, rampas de tronco e estacas com minas Teller.
- **Cenário**: LCVPs reais (o barco do jogador, os que chegam ao fundo e dois encalhados),
  Sherman destruído em chamas, contratorpedeiros em silhueta no horizonte, casas em ruínas
  no alto da encosta, capacetes M1 largados na areia. Modelos do Sketchfab (CC BY), lista em
  `assets/CREDITOS_SKETCHFAB.md`; tudo montado por `tools/montar_cenario.gd`.

### 7. Quarta rodada (2026-10-16: rampa, destroços, animações direcionais)
- **Rampa do barco**: a rampa do próprio modelo do LCVP (recortada por
  `tools/blender/cortar_malha.py`) presa ao pivô animado; a caixa antiga só dá a colisão.
- **Destroços na praia**: soldados caídos (`levels/props/corpo.gd`: pose final de uma
  animação de morte) com o fuzil ao lado, galões, bazucas, rádio SCR-300 e caixas de
  munição (Sketchfab CC BY).
- **Água rasa** sem manchas: franja de espuma suave e ondulação mais calma no raso.
- **Animações direcionais** (andar de costas e de lado, em pé mirando e agachado) para os
  três soldados: o FBX com o esqueleto do próprio Mixamo foi reenviado (o site reaproveita
  o esqueleto, sem novo auto-rig) e só as 6 animações novas foram baixadas. Mirando ou
  agachado, a locomoção é um espaço 2D (direção no corpo), com o ritmo pela velocidade
  natural de cada direção; o inimigo mirando anda de lado e recua olhando o alvo.
  O personagem da conta do Mixamo foi restaurado no fim.

## Próximos passos (em ordem)
1. Gritos em alemão dos inimigos ("Granate!", "Achtung!"): precisa de uma voz alemã no Piper.
2. Detalhes do bunker por fora (o volume ainda é um bloco liso) e sacos de areia com textura mais convincente.
3. Sons reais para passos, granada e Bangalore (hoje sintéticos).
4. Missão 2 (Prédio em ruínas), quando o autor aprovar a Missão 1 nova.
