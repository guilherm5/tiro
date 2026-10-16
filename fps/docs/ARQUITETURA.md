# Arquitetura — Operação Última Linha

Godot 4.7.2 · GDScript · Forward+ · física Jolt.
Hardware de referência: Intel Iris Xe (GPU integrada). Tudo deve rodar bem nela.

## Princípios

1. **Dados separados do código.** Armas, inimigos, falas e missões são arquivos de dados
   (`.tres` ou `.dlg`). Adicionar conteúdo não exige alterar scripts.
2. **Sistemas desacoplados.** Os sistemas se comunicam por sinais. O jogador emite `footstep`,
   e o áudio decide o que tocar. Um `EventBus` global entra quando houver o primeiro uso
   entre sistemas (etapa 3).
3. **Componentes reutilizáveis.** Vida, dano e áreas de acerto servem tanto para o jogador
   quanto para os inimigos.
4. **A narrativa pertence ao autor.** Todo texto vem de `data/dialogue/*.dlg`, escrito no
   formato do roteiro. O código nunca contém falas.

## Estrutura de pastas

```
autoload/        Sistemas globais (carregados antes de qualquer cena)
  input_setup.gd   Controles padrão (WASD, mouse etc.)
systems/         Sistemas reutilizáveis
  core/            Utilitários (Spring3: mola para animação procedural)
  player/          Controlador, efeitos de câmera, câmera da arma, passos
  weapons/         Weapon (base), WeaponData, WeaponHolder, m1_garand/ (modelo)
  combat/          HitInfo; (etapa 3) vida, dano, supressão
  enemies/         (etapa 4) inimigo base + IA por estados
  narrative/       (etapa 7) leitor .dlg, legendas, gatilhos, cutscenes
  fx/              Impacto de bala, fumaça do cano, cápsulas/pente ejetados
  ui/              HUD (mira + munição)
data/            Conteúdo editável
  weapons/         m1_garand.tres — todos os números da arma
levels/          Fases
  demo_praia/      Demo: trecho da praia (Missão 1)
  props/           Objetos de cenário (ouriço, alvo de treino, caixa)
assets/          Modelos, texturas e sons de terceiros (+ CREDITOS.md com licenças)
  audio/provisorio/  Sons sintetizados (tools/gerar_sons.py) — trocar por gravações reais
tools/           Scripts auxiliares fora do jogo
docs/            Esta documentação + roteiro mestre
```

## Jogador (`systems/player/`)

```
Player (CharacterBody3D)  gira em Y; camada física "jogador"
├─ Collision              cápsula; a altura muda ao agachar
└─ Head                   gira em X; posicionado na altura dos olhos
   └─ CameraRig           deslocamentos: balanço de passo (depois recuo e tremor)
      └─ Camera
```

- Os parâmetros (velocidades, sensibilidade, altura) estão em `@export` e podem ser ajustados
  no Inspector, sem código.
- Ao soltar o agachar, o jogador só levanta se houver espaço livre acima.
- O sinal `footstep(is_sprinting)` é emitido a cada passada (o nó `Footsteps` toca o som).
- `Camera` tem `CameraEffects`: `kick()` (solavanco que volta sozinho) e `add_trauma()` (tremor).
  Explosões e supressão vão usar `add_trauma()`.
- `add_aim_kick()` sobe a mira de verdade; `recoil_recovery` (60%) volta sozinho.

## Vida e dano (`systems/combat/`)

- `Health`: componente reutilizável (`take_damage`, `heal`, sinais `damaged`/`died`/`changed`).
  Com `regenerates`, a vida é dividida em blocos (`segment_count`) e só regenera até o fim do bloco atual.
- O jogador recebe tiros por `PlayerController.apply_hit()`. `PlayerFeedback` cuida da câmera, dos
  sons, do batimento e do filtro abafado no barramento SFX. O HUD cuida dos efeitos de tela.
- `EventBus` (autoload) leva `player_damaged`, `player_healed`, `player_died` e `enemy_killed`
  para quem precisar ouvir (HUD, e depois falas e objetivos).
- `DebugKeys` (autoload) tem as teclas de teste F1, F2 e F3, que são removidas na versão exportada.

## Inimigos (`systems/enemies/`, `systems/ai/`)

```
EnemySoldier (CharacterBody3D, camada "inimigos")  corpo: andar, virar, atirar, dano, morte
├─ Health
├─ Perception      visão (cone + linha de visada + "consciência" que sobe aos poucos) e audição
├─ Brain           SoldierBrain: IDLE → ALERT → COMBAT (cobertura/sair para atirar/procurar) → DEAD
├─ NavAgent        navegação pela malha da fase
└─ Visual          PROVISÓRIO (formas + animação por código). API: set_crouched, set_aiming,
                   set_aim_pitch, flinch, die, muzzle_flash. Trocar por modelo animado sem mexer no resto.
   └─ Upper/HeadHitbox   área da cabeça (dano × headshot_multiplier)
```

- **Tipo novo de inimigo:** crie um `EnemyData` em `data/enemies/`. Para um comportamento
  diferente (ex.: metralhador), crie outro "cérebro" e reaproveite o corpo.
- **Tiros inimigos** são raios reais com erro em metros, que cresce com a distância e com o alvo
  correndo e diminui com o tempo mirando. Por isso a cobertura protege de verdade.
- **Cobertura:** `CoverPoint` (Marker3D) posicionados à mão na fase. O inimigo escolhe um ponto
  que o protege agachado e, de preferência, de onde consegue atirar em pé.
- **Navegação:** `runtime_navmesh.gd` gera a malha ao abrir a fase a partir das colisões dos nós
  no grupo `navegacao`. Ao adicionar cenário que bloqueia passagem, coloque-o nesse grupo.
- **Avisos:** ao entrar em combate, o soldado avisa os companheiros num raio de 40 m. Os tiros
  do jogador emitem `EventBus.noise_emitted`, que os inimigos ouvem.

### Metralhador (`systems/enemies/mg_gunner/`)

`mg_gunner.tscn` **herda** a cena do soldado e só troca o cérebro (`MgGunnerBrain`), os dados e
a arma (MG42). O cérebro fica parado, gira a arma com velocidade limitada e alterna entre
varredura, rajadas, supressão da última posição e troca de cano (sinal `reloading_changed`,
que as falas vão usar).

### Supressão (`systems/combat/near_miss.gd`, `systems/player/suppression.gd`)

Todo tiro inimigo chama `NearMiss.check()`: se a bala passa a até 3 m da cabeça, toca o zumbido
e soma supressão ao jogador. A supressão (0 a 1) embaça e escurece a tela (HUD), treme a câmera e
aumenta a dispersão da arma.

## Personagens animados (`systems/characters/humanoid_visual.gd`)

Inimigos e aliados usam o boneco da Universal Animation Library (CC0) com uma AnimationTree
montada por código. As pernas tocam parado, andar, correr ou agachado conforme a velocidade. O
tronco e os braços tocam a pose de mira (cima, meio ou baixo, conforme a inclinação) ou a de arma
baixa. Também há reação a impacto (cabeça ou peito) e animação de morte; o fuzil cai com física.
A API é a mesma do visual antigo (`set_crouched`, `set_aiming`, `set_aim_pitch`, `set_move_speed`,
`flinch`, `die`, `lie_down`, `muzzle_flash`), então a lógica dos personagens não mudou.
Para trocar o modelo, use outro `model_scene` com o mesmo esqueleto (ossos `DEF-*`).

**Colocar um modelo novo de soldado no jogo:** `tools/blender/rig_soldado.py` (Blender sem janela)
pega um modelo em pose A/T sem esqueleto e entrega um `.glb` com o esqueleto da biblioteca e as
46 animações. Ele junta as partes, escala, mede a pose, copia os pesos do boneco e desfaz a pose.
Armas: `tools/blender/preparar_arma.py` (escala, cano para -Z e posição da massa de mira).
O visual detecta sozinho para onde o modelo olha. `model_brightness` clareia texturas escuras, e
`model_variants` sorteia modelos entre os soldados do mesmo lado. O fuzil fica na mão direita,
apontando para a esquerda.

## Armas (`systems/weapons/`)

```
Camera
└─ WeaponHolder        lê o input (atirar/mirar/recarregar) e repassa à arma equipada
   └─ M1Garand         Weapon + WeaponData (data/weapons/m1_garand.tres)
      └─ Model         posições de quadril/mira/corrida/recarga animadas por código
```

- **Nova arma:** crie um `.tres` de `WeaponData` e uma cena com a estrutura de `m1_garand.tscn`
  (`Model`, `Muzzle`, `Ejection`, áudios). Nenhum script muda.
- Disparo instantâneo (hitscan) a partir do centro da tela, com dispersão em cone
  (`current_spread`, que a mira do HUD desenha).
- Quem pode ser atingido implementa `apply_hit(hit: HitInfo)`. Corpos rígidos sem esse
  método recebem só o impulso.
- **Superfícies:** o objeto atingido define `metadata/surface` como `areia`, `concreto`, `metal`,
  `madeira` ou `agua`. Isso escolhe a poeira, a marca e o som (`systems/fx/bullet_impact.gd`).
- **Câmera da arma:** o modelo é desenhado na camada visual 2 por uma segunda câmera
  (`ViewmodelLayer` no jogador), por cima do mundo, então a arma não atravessa paredes.
  **Toda luz que deve iluminar a arma precisa estar nas camadas 1 e 2** (o sol da fase usa `layers = 3`).

## Narrativa (`systems/narrative/`, autoloads `Dialogue` e `Objectives`)

```
data/dialogue/*.dlg        falas no formato do roteiro → DialogueParser
data/missions/*.missao     "quando EVENTO → ações" → MissionDirector (nó Missao na fase)
EventBus.narrative_event   eventos com nome: inicio, area_*, mg_morta, @evento das falas,
                           jogador_parado / jogador_exposto / combate_periodico*
```

- `Dialogue.play(id)`: cena em fila, com prioridade. `Dialogue.bark(id)`: fala contextual
  (só com silêncio, com intervalo, sem repetir a mesma). Uma fala por vez, com pausa.
  Dublagem opcional em `assets/audio/voz/<id_da_fala>.ogg`.
- `Objectives`: `add`/`complete`. O HUD mostra o objetivo e o marcador. Concluir antes de o
  objetivo aparecer também funciona (ex.: MG destruída antes da ordem).
- `NarrativeTrigger` (Area3D): emite um evento quando o jogador entra. `EnemySoldier.death_event`
  emite um evento quando ele morre. `combat_situations.gd` detecta situações para as falas contextuais.
- `AllyNpc` (Miller): corre até os pontos (`mover MILLER ponto`), abaixa e atira "de efeito".
  Usa o mesmo visual provisório dos soldados.
- **Cutscenes** (autoload `Cutscenes`): `play(id, keep_cinematic)` toca uma cena do `.dlg` com
  câmera própria (`@camera`, `@camera_mover`, `@tremer`, `@explosao`). Durante a cena, o jogador
  fica em `is_cinematic` (sem controle e invisível para os inimigos) e o HUD mostra faixas pretas.
  Ela pode ser pulada. Cenas emendadas com "final" reaproveitam a câmera.
- **Checkpoints** (autoload): `checkpoint ponto` no `.missao` salva o ponto, os blocos já executados,
  os objetivos, os inimigos mortos e os aliados. A morte recarrega a cena e o MissionDirector
  restaura tudo (e emite `checkpoint_restaurado`).
- **Cartela de título:** `cartela "TÍTULO" "subtítulo"` no `.missao` (HUD).
- Testes de mecânica removem o nó `Missao` (`_sem_missao`) para não depender da cutscene.
- **Exportação:** `.dlg`, `.missao` e `.cfg` não são recursos do Godot. Ao exportar, inclua
  `*.dlg, *.missao, *.cfg` em "Filtros para exportar arquivos que não são recursos".

## Menus, opções e progresso

- `Settings` (autoload): configurações salvas em `user://configuracoes.cfg`. Aplica volumes por
  barramento, janela, escala 3D com FSR, atlas de sombras, SSAO e glow conforme a qualidade. Emite `changed`.
- `SceneLoader` (autoload): troca de cena com tela de carregamento (carrega em outra thread).
- `Checkpoints` grava o progresso em `user://progresso.save`, usado pelo "Continuar".
- `levels/menu/menu_principal.tscn` é a cena inicial do jogo. A pausa (`systems/ui/pause_menu.gd`)
  fica no HUD de cada fase. `MenuStyle` define o visual de todos os menus.
- Exportação: incluir também `assets/CREDITOS.md` nos arquivos que não são recursos (tela de créditos).

## Cenário e atmosfera

- **Terreno** (`levels/terrain/beach_terrain.gd`): gerado por código ao abrir a cena (também no
  editor). Gera malha e colisão (HeightMapShape3D) com inclinação, ondulações, crateras e encostas,
  editáveis no Inspector. Objetos no grupo `terreno_plano` ficam em chão sem ondulação.
  Shader `terrain.gdshader`: mistura areia seca e molhada pela altura e escurece as crateras.
- **Mar** (`water.gdshader`): ondas no vértice, cor por profundidade e espuma na beira
  (usa a profundidade da cena).
- **Explosões** (`systems/fx/explosion.tscn`): areia ou água, clarão, detritos, som, tremor e
  supressão por distância, e dano em área com linha de visão (pronto para granadas).
  `ArtilleryDirector` gera explosões de ambiente longe do jogador (sem dano).
- **Fumaça e fogo:** `smoke_column.tscn` e `fire.tscn` (partículas, luz tremulando e som).
- **Materiais** em `assets/materiais/`, com texturas do Poly Haven baixadas por
  `tools/baixar_polyhaven.py`. Créditos e licenças em `assets/CREDITOS.md`.
- **Pós-processamento** (WorldEnvironment da fase): tonemap AgX, contraste alto, saturação baixa,
  neblina baixa, SSAO e glow.

## Camadas de física

| # | Nome | Quem usa |
|---|------|----------|
| 1 | mundo | cenário (areia, muros, obstáculos) |
| 2 | jogador | Player |
| 3 | inimigos | (etapa 4) |
| 4 | agua | superfície da água: só os tiros colidem, o jogador atravessa |

Camadas **visuais**: 1 = mundo, 2 = modelo da arma em primeira pessoa.

## Áudio

Barramentos (`default_bus_layout.tres`): `SFX`, `Voz`, `Ambiente` e `Musica`, todos indo para o `Master`.
Os sons atuais são provisórios e sintetizados. Para trocar, basta substituir o `.wav` mantendo o
nome, ou apontar o `WeaponData` para outro arquivo.

## Convenções

- Nomes de nós e de arquivos de conteúdo em português (`MuroEsquerdo`, `ourico_tcheco.tscn`).
  Scripts e código em inglês (`player_controller.gd`), seguindo o padrão da API do Godot.
- Comentários em português.
- Atenção ao editar `.tscn` à mão: `Transform3D(...)` lista a base **por linhas**, não por colunas.

## Testes automáticos

Durante o desenvolvimento, o Claude roda testes pelo terminal (Godot sem janela) para validar o
movimento e capturar imagens antes de entregar cada etapa. Esses testes não substituem o seu
teste jogando.
