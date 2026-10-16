# O jogo: como jogar, como funciona, como testar

## Jogar

```bash
~/Documentos/central/jogar.sh          # menu principal
~/Documentos/central/jogar.sh treino   # direto no treino
~/Documentos/central/jogar.sh demo     # CPU contra CPU
```

Menu: **VS CPU**, **2 JOGADORES** (mesmo teclado), **TREINO**, **DEMONSTRAÇÃO**,
dificuldade (fácil/normal/difícil), filtro de PS2 (liga/desliga, também no **F3**) e a
lista de **GOLPES**.

### Teclas

| | Jogador 1 | Jogador 2 |
|---|---|---|
| mover | W A S D | setas |
| botão 1 (braço esquerdo) | U | 4 do numérico ou O |
| botão 2 (braço direito) | I | 5 do numérico ou P |
| botão 3 (perna esquerda) | J | 1 do numérico ou L |
| botão 4 (perna direita) | K | 2 do numérico ou Ç |

Os botões ficam no formato losango do controle do Tekken (U I em cima, J K embaixo).
**Esc** pausa. **F1** mostra as caixas de colisão. **F3** liga/desliga o filtro de PS2.
No treino: **F5** troca o comportamento do boneco, **F6** recomeça.

### Movimentação (direções relativas ao oponente: → = para ele)

| Ação | Comando |
|---|---|
| andar | → / ← |
| **defender** (estilo Street Fighter) | segurar ← (em pé: alto, médio e aéreo) |
| defender baixo | segurar ↙ (baixo e médio; aéreo pega) |
| agachar (golpe alto passa por cima) | ↓ |
| pular (para cima, frente, trás) | ↑ / ↗ / ↖ |
| corrida curta / esquiva para trás | →→ / ←← |
| **passo lateral** (luta 3D) | toque rápido em ↑ (para o fundo) ou ↓ (para a frente da tela) |

### Golpes do PCI

| Golpe | Comando | Nível | Observação |
|---|---|---|---|
| Jab | 1 | alto | rápido (10 quadros), seguro no bloqueio |
| Um-dois | 1, 2 | alto | sequência |
| Um-dois-chute | 1, 2, 4 | médio | fecha a sequência e derruba |
| Direto | 2 | alto | cancela em especial se conectar |
| Chute alto | 3 | alto | |
| Chute circular | 4 | médio | |
| Rasteira | ↓+3 ou ↓+4 | **baixo** | derruba; muito punível (−16) |
| Gancho | ↘+2 | médio | **lança** para malabarismo |
| Agarrão | 1+2 | agarrão | vence quem só defende; escape: apertar 1 ou 2 logo |
| Chute voador | no ar: 3 ou 4 | aéreo | tem que defender em pé |
| Shuriken | ↓↘→ + 1 | médio | projétil (passo lateral desvia) |
| Corte relâmpago | ↓↘→ + 2 | médio | **saca a katana**, avança e derruba |
| Voadora do corvo | ↓↙← + 3 ou 4 | aéreo | avança 2 m, derruba |
| **Tempestade de aço** | ↓↘→ + 1+2 | médio | **super**: precisa da barra azul cheia; 3 cortes |

### Música

O rock da luta é gerado por `ferramentas/gerar_rock.py`. Para tocar as suas músicas, ponha
arquivos `.mp3`, `.ogg` ou `.wav` em `~/Documentos/central/musica/` (tocam em ordem
aleatória, no lugar da trilha gerada). Volume em MÚSICA no menu.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `jogo/dados/pci.json` | **tudo do PCI**: vida, movimentação, cada golpe com quadros, dano, nível, vantagem, cancelamentos |
| `jogo/scripts/lutador.gd` | máquina de estados em quadros, golpes, colisão, defesa, reações, katana |
| `jogo/scripts/entrada.gd` | teclado ou fonte virtual (IA/testes), histórico, buffer, meia-lua, toque duplo |
| `jogo/scripts/ia.gd` | CPU: reage, defende, pune, faz malabarismo, anti-aéreo |
| `jogo/scripts/luta.gd` | partida: arena, câmera 3D, HUD, rounds, acertos, agarrão, projéteis, super, pausa, treino |
| `jogo/scripts/menu.gd` | tela de título e menu |
| `jogo/scripts/config.gd` | autoload: modo, dificuldade, filtro de PS2, mapa de teclas |
| `jogo/scripts/projetil.gd` | shuriken |
| `jogo/assets/personagens/pci/pci_v5.glb` | PCI v3 (malha nova) com 28 animações; `pci_atlas_1p/2p.png` = corpo assado |
| `jogo/assets/cenarios/dojo/` | dojo: `dojo.glb`, mapas de luz `luz_*.png`, texturas, `dojo_materiais.json` |
| `jogo/scripts/cenario.gd` + `shaders/` | monta o cenário com luz assada (textura x mapa de luz) |
| `jogo/scripts/efeitos.gd` | faíscas, bloqueio, poeira, rastro da katana |
| `jogo/assets/personagens/pci/katana.glb` | katana desembainhada (vai na mão nos especiais) |
| `jogo/assets/sons/` | sons e música, todos sintetizados por `ferramentas/gerar_sons.py` |

## Como a luta funciona

**Quadros fixos.** Tudo roda a 60 quadros por segundo. A cada quadro, na mesma ordem:
os dois lutadores leem a entrada e avançam, os projéteis andam, os corpos se empurram,
e por fim os acertos são resolvidos. Mesma semente = mesma luta.

**Golpe como dado.** Cada golpe em `pci.json` tem `inicio`, `ativo` e `recuperacao` em
quadros, `dano`, `nivel` (alto/médio/baixo/aéreo/agarrão), `vantagem_acerto` e
`vantagem_bloqueio` (de onde sai o tempo de atordoamento), `empurra`, `efeito`
(`lancar`, `queda`), `cancela` (sequências e cancelamento em especial), `avanco`,
`katana`, `projetil`, `janelas` (golpe de vários acertos). O `trecho` diz que pedaço da
animação usar: `[começo, pico_início, pico_fim, fim]` em fração da animação. O código
acelera ou freia a animação para o pico cair exatamente nos quadros ativos.

**Acerto de verdade.** Nos quadros ativos, a posição real do osso que bate (mão, pé ou 3
pontos da lâmina da katana) é testada contra o corpo do oponente: um cilindro centrado
no quadril, do pé mais baixo até a cabeça. Por isso agachar faz golpe alto passar por
cima e o passo lateral faz golpe reto errar, sem regra especial. Duas regras de jogo de
luta por cima da geometria: golpe **alto** nunca pega quem está agachado; golpe
**médio/baixo** sempre alcança quem está agachado.

**Defesa (Street Fighter).** Segurar ← no momento do impacto defende alto, médio e aéreo;
↙ defende baixo e médio. Com o oponente atacando perto, segurar ← para no lugar em guarda
em vez de andar para trás.

**Combos.** Sequências (1 → 2 → 4) por janela de cancelamento; normais que conectam
cancelam em especial; o gancho lança e o oponente fica "flutuando" (gravidade menor) para
o malabarismo, com limite de 5 acertos. Dano cai 12% por golpe do combo (mínimo 40%).
Golpe no começo de outro golpe = **contra-ataque** (+25% de dano e mais atordoamento).

**Buffer.** Um botão apertado até 8 quadros antes de o lutador ficar livre ainda sai.

**Barra de especial.** Enche ao bater (70% do dano) e ao apanhar (40%). Cheia, libera a
Tempestade de aço: o oponente congela, a câmera aproxima, e são 3 cortes.

**IA.** Usa a mesma entrada do jogador (faz meia-lua de verdade). Vê o golpe do oponente
começar e, depois do tempo de reação do nível, decide uma vez se defende (alto, baixo ou
agacha). Pune golpes muito negativos que bloqueou (gancho para combo se for −14 ou pior),
faz malabarismo, anti-aéreo contra pulo, agarra quem só defende, usa shuriken de longe.

**Rounds.** Melhor de 3, 90 segundos, K.O. em câmera lenta, "PERFEITO!" se vencer sem
perder vida.

## Testes (rodam sem janela, mais rápido que o tempo real)

```bash
cd ~/Documentos/central/jogo
G=../ferramentas/Godot_v4.7.2-stable_linux.x86_64

$G --headless --fixed-fps 60 -s res://ferramentas/teste_mecanicas.gd   # 16 checagens de mecânica
$G --headless --fixed-fps 60 -s res://ferramentas/teste_alcance.gd     # tabela de alcance de cada golpe
$G --headless --fixed-fps 60 res://cenas/luta.tscn -- --modo=demo --semente=4 --sair-apos=240   # luta inteira
$G --headless -s res://ferramentas/medir_golpes.gd      # deslocamento de raiz de cada animação
$G --headless -s res://ferramentas/curvas_golpes.gd     # curva de mão/pé de cada golpe (para ajustar janelas)
$G -s res://ferramentas/calibrar_katana.gd -- --anim=corte --fracao=0.45 --saida=/tmp/k.png   # orientação da katana
```

`teste_mecanicas.gd` cobre: sequência 1-2-4, lançamento + malabarismo, rasteira contra
defesa alta e baixa, golpe alto contra agachado, agarrão e escape, super exige barra e
conecta vários cortes, shuriken pela meia-lua, pulo + chute no ar, passo lateral desviando
de soco reto, corrida.

Argumentos da luta (depois de `--`): `--modo=versus|dois|treino|demo`, `--semente=N`,
`--sair-apos=N`, `--sair-no-fim`, `--captura=PREFIXO`, `--sem-intro`.

## Adicionar ou ajustar um golpe

1. Animação nova: baixar do Mixamo (Without Skin), pôr em `exportados/mixamo/`, incluir na
   lista `ANIMS` de `blender/scripts/pci_montagem.py`, rodar o script e copiar o GLB.
2. Se a animação anda sozinha, pôr o nome em `raiz_removida` no `pci.json`.
3. Rodar `curvas_golpes.gd` para ver em que fração da animação a mão/pé está estendida.
4. Criar a entrada em `golpes` no `pci.json` (o menu lê a lista de lá).
5. Conferir com `teste_alcance.gd` e jogar no treino com F1 (caixas) ligado.
