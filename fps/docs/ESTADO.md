# Estado do projeto

Última atualização: 15/10/2026 (Etapa 2)

## Decisões tomadas

- Falas e legendas somente em português.
- Arte: packs prontos (Fab/Epic, Megascans gratuitos, Poly Haven, ambientCG, Mixamo), buscando o
  visual do BLACK. Nenhuma compra sem aprovação do autor, item por item.
- Vida: quatro blocos de 25%. A vida regenera até o fim do bloco atual; um bloco perdido só
  volta com kit médico.
- Demo: trecho reduzido da praia com o ninho de MG42, o M1 Garand e alguns soldados de
  infantaria. As falas de Miller e Reed aparecem só como legendas, e Miller é roteirizado
  (sem IA de esquadrão por enquanto).

## Plano da demo

| Etapa | Conteúdo | Status |
|---|---|---|
| 1 | Projeto base, jogador, praia em formas cinzas, documentação | ✅ testes automáticos · ⏳ seu teste |
| 2 | M1 Garand: disparo, recuo, balanço, recarga, "ping", sons provisórios | ✅ testes automáticos · ⏳ seu teste |
| 3 | Dano, vida em blocos, HUD mínimo, EventBus | ✅ testes automáticos · ⏳ seu teste |
| 4 | Infantaria inimiga: percepção, cobertura, tiro, reações, morte | ✅ testes automáticos · ⏳ seu teste |
| 5 | Ninho de MG42 + supressão + marcador de acerto | ✅ testes automáticos · ⏳ seu teste |
| 6 | Passada visual: terreno, texturas reais, mar, céu, fumaça, artilharia, pós-processamento | ✅ testes automáticos · ⏳ seu teste |
| 7 | Narrativa: `.dlg`, legendas, gatilhos, objetivos, Miller, sons reais de armas | ✅ testes automáticos · ⏳ seu teste |
| 8 | Cartela, cutscenes (abertura, primeiro morto, encerramento), checkpoints, esquadrão | ✅ testes automáticos · ⏳ seu teste |

## Etapa 1 — como testar

- **Atalho no menu do GNOME:** aperte a tecla Super, digite "Última Linha" e clique.
  Para deixar fixo no dock: botão direito no ícone → "Fixar no painel".
  Botão direito no ícone → "Abrir no Editor do Godot" abre o editor (lá, F5 joga).
  (Instalado em `~/.local/share/applications/ultima-linha.desktop`.)
- Pelo terminal: `./jogar.sh` ou `./editor.sh`.

Você começa dentro da embarcação, de frente para a rampa. Verifique:
- [ ] O mouse olha em todas as direções, sem inverter e sem passar do limite vertical.
- [ ] WASD move o jogador, e Shift corre (só para frente).
- [ ] Ctrl ou C agacha. Embaixo de um ouriço, o jogador não levanta enquanto houver algo acima.
- [ ] Espaço pula, com um pulo curto e pesado.
- [ ] O balanço da câmera ao andar é perceptível, mas não enjoativo.
- [ ] Dá para descer a rampa, atravessar a praia, passar pela abertura do muro e chegar ao bunker.
- [ ] Esc solta o mouse, e um clique o captura de novo.

Os valores de velocidade e balanço podem ser ajustados no Inspector, selecionando o nó `Player`
na cena `demo_praia.tscn`.

## Etapa 2 — como testar

Ao descer do barco, há três alvos de madeira e algumas caixas à frente. Verifique:
- [ ] O clique esquerdo dispara (semiautomático: um tiro por clique). Há clarão, fumaça no cano,
      cápsula ejetada, a câmera dá um solavanco e a mira sobe um pouco e volta parcialmente.
- [ ] O botão direito mira pelo aparelho de mira: a câmera aproxima e a mira em cruz some.
      A massa (o pino da frente) fica no centro da tela, e é ali que a bala vai.
- [ ] No 8º tiro sai o "ping" e o pente voa. Com o pente vazio, o clique faz um estalo seco.
- [ ] R recarrega (com pente parcial, o Garand ejeta o pente e os cartuchos voltam para a reserva).
- [ ] Os alvos caem quando atingidos, e as caixas são empurradas pelos tiros.
- [ ] Os impactos mudam com a superfície: areia (poeira bege), muro e bunker (pó cinza),
      ouriços (faíscas), água (respingo claro) e madeira.
- [ ] Ao correr (Shift), a arma abaixa e não dispara.
- [ ] A arma não atravessa paredes ao encostar nos obstáculos.
- [ ] A mira em cruz abre ao andar ou atirar rápido e fecha ao agachar.

Os números da arma (recuo, dispersão, tempo de recarga etc.) ficam em `data/weapons/m1_garand.tres`
e podem ser ajustados no Inspector sem mexer em código.

## Etapa 3 — como testar

Ainda não há inimigos, então use as teclas de teste (funcionam só fora da versão final):
**F1** = levar 20 de dano de uma direção aleatória · **F2** = curar um bloco · **F3** = reiniciar.
- [ ] Ao levar dano: a câmera dá um solavanco, a borda da tela pisca em vermelho, um arco vermelho
      aponta de onde veio o tiro e toca um som de impacto.
- [ ] A barra de vida (canto inferior esquerdo) tem 4 blocos. Depois de 4 s sem dano, a vida volta
      **só até o fim do bloco atual**.
- [ ] Com a vida pela metade ou menos, a tela perde cor e escurece nas bordas, entra um batimento
      cardíaco e os sons ficam abafados.
- [ ] Os kits médicos (bolsas verdes no chão, um perto dos alvos e outro depois do muro) devolvem
      um bloco. Com a vida cheia, eles ficam no chão.
- [ ] Ao morrer, a câmera cai, a tela escurece com "VOCÊ MORREU" e a fase recomeça em 4 s.

## Etapa 4 — como testar

Há 5 soldados alemães atrás de sacos de areia entre os ouriços e o muro.
- [ ] Ao se aproximar de pé e à vista, eles **demoram um instante** para notar você (mais
      tempo de longe ou agachado). O primeiro a notar avisa os outros.
- [ ] Em combate, eles correm para trás dos sacos, se abaixam, levantam para atirar 1 ou 2
      vezes e voltam a se esconder. Um tiro seu que acerte faz o inimigo recuar e atrapalha a mira dele.
- [ ] Os tiros deles levantam poeira perto de você, e os que passam perto zumbem.
- [ ] Parado e de pé, você é atingido com frequência. Correndo ou agachado atrás de um ouriço,
      bem menos. Três tiros matam.
- [ ] Ao disparar de longe sem ser visto, eles ouvem, se abrigam e ficam olhando na sua direção.
- [ ] Um tiro na cabeça mata na hora. No corpo, são necessários dois. O corpo cai na direção do tiro.
- [ ] Se você flanquear (dar a volta), o soldado procura outra cobertura. Se você sumir de
      vista por um tempo, ele vai até onde você foi visto pela última vez.

Ajustes de dificuldade ficam em `data/enemies/fuzileiro_alemao.tres`: `spread_at_10m` (precisão),
`damage`, `notice_time` (tempo para notar), `reaction_time` e `fire_interval_*`.

## Etapa 5 — como testar

- [ ] A MG42 no bunker (à esquerda, atrás do muro) varre a praia. Ao ver você, dispara rajadas
      com traçantes. Ela gira mais devagar do que você corre: correndo de lado, você sai da linha de fogo.
- [ ] Ao se esconder atrás de um ouriço, ela continua metralhando o ouriço por alguns segundos
      (faíscas e poeira).
- [ ] Depois de 4 a 6 rajadas, ela para por cerca de 4,5 s (troca de cano). É a janela para avançar.
- [ ] Sob fogo, a visão fica turva e escura nas bordas, a câmera treme e sua mira piora. Tudo
      volta ao normal cerca de 1 s depois que o fogo para.
- [ ] Dá para matar o metralhador com tiro na cabeça pela seteira (difícil) ou flanqueando pela
      porta dos fundos do bunker.
- [ ] **Marcador de acerto:** ao acertar um inimigo, aparece um X branco na mira com um som curto.
      No abate, o X fica vermelho.

Os ajustes da MG ficam no nó `Brain` do metralhador: velocidade de giro, dano, ritmo de
rajadas e tempo da troca de cano.

## Passada visual (etapa 6) — o que observar

- Terreno com relevo: inclinação até o mar, ondulações, **crateras** escurecidas (servem de
  cobertura), encosta ao fundo e laterais elevadas que escondem o fim do mapa.
- Areia seca e molhada (escura perto da água), concreto no muro e no bunker, aço enferrujado
  nos ouriços, juta nos sacos de areia (texturas do Poly Haven, CC0).
- Mar com ondas, cor que escurece com a profundidade e espuma na beira.
- Céu nublado real, neblina baixa sobre a praia, contraste alto e cores dessaturadas.
- Colunas de fumaça ao fundo, um barco de desembarque destruído pegando fogo na beira d'água.
- **Artilharia de ambiente:** explosões de areia e colunas d'água pela praia (nunca a menos de
  16 m de você), com tremor de tela, supressão e detritos.
- Som ambiente: ondas, vento e batalha distante. O fogo crepita.

Desempenho medido: cerca de 60 FPS em 1280x720 na Iris Xe (GPU a 13–15 ms por quadro).

## Etapa 7 — como testar (a demo inteira)

1. No barco: Miller e Reed gritam as ordens do roteiro (legendas embaixo) e o Miller sai correndo.
   O objetivo aparece no canto, com um marcador e a distância na tela.
2. Na beira d'água, o soldado ferido pede ajuda.
3. Nos ouriços: a cena do Miller ("Hayes! Olhe para mim!..."), e então o objetivo
   **"Neutralize a posição de metralhadora inimiga."** aponta para o bunker.
4. Sob fogo: falas contextuais (parado na areia, exposto, rádio do Reed, Walker com feridos), sem repetir seguidas.
5. Matando o metralhador: "A metralhadora parou!", a conversa com o rádio e o novo objetivo:
   alcançar o ponto de reunião junto ao muro.
6. No muro (só depois da MG): **MISSÃO CONCLUÍDA — DESEMBARQUE**.

**Para editar a história sem código:**
- Falas: `data/dialogue/m1_desembarque.dlg` (mesmo formato do roteiro).
- O que acontece e quando: `data/missions/m1_desembarque.missao`.
- Nomes e cores dos personagens: `data/dialogue/personagens.cfg`.
- **Dublagem:** salve `assets/audio/voz/<id_da_fala>.ogg`, por exemplo `praia_desembarque_01.ogg`
  para a 1ª fala de `[praia_desembarque]`. O jogo passa a tocar a voz sozinho.

**Textos provisórios para o autor revisar** (não estão no roteiro): o objetivo inicial "Saia da
água e alcance os obstáculos." e o objetivo final "Alcance o ponto de reunião junto ao muro de concreto.".

**Sons reais de armas:** Garand, Kar98 e MG42 agora usam gravações reais (CC0, ver `assets/CREDITOS.md`).

## Etapa 8 — como testar

1. A fase abre com tela preta e a cartela **"MISSÃO 1 — DESEMBARQUE / Normandia, junho de 1944 — 06h28"**.
2. **Cutscene na embarcação:** diálogo completo do roteiro, com cortes entre Miller, Reed, Walker e
   Hayes, explosões na água, o rádio chiando e a rampa baixando. **Espaço/Enter/Esc pula.**
   A câmera volta suavemente para o seu olhar e o controle é devolvido.
3. O esquadrão sai correndo: Miller, Reed, Walker e dois soldados se espalham pelos obstáculos.
   Um ferido pede ajuda na beira d'água. Embarcações continuam chegando ao fundo.
4. **Checkpoints:** depois da saída do barco, depois da ordem do Miller e depois da MG. Ao morrer,
   você volta ao último checkpoint, sem repetir a cutscene. Inimigos mortos continuam mortos.
5. No muro: a cena **"O primeiro morto"**, emendada na **cutscene de encerramento**
   (o esquadrão segue para o interior, a câmera se afasta) e então **MISSÃO CONCLUÍDA — DESEMBARQUE**.

Teclas de teste: **F3** = voltar ao último checkpoint · **F4** = recomeçar a missão do zero.

**Editar cutscenes:** as cenas ficam em `data/dialogue/m1_desembarque.dlg` com comandos `@camera`,
`@camera_mover`, `@tremer`, `@explosao`. As câmeras são nós em `Cutscenes/Cameras` na fase, cada
uma com o metadado `alvo` (para onde olha).

## Polimento (em andamento)

| Frente | Status |
|---|---|
| Personagens e arma reais | ✅ soldados da Wehrmacht e Panzergrenadier (inimigos, com Kar98k), Rangers americanos (aliados, com Garand) e M1 Garand detalhado em primeira pessoa, todos animados |
| Menus e opções | ✅ menu principal, pausa (Esc), opções salvas, carregamento, progresso em disco |
| Sensação de combate | ✅ recarga com sons reais, cápsulas tilintando no chão, respiração na mira, tranco ao aterrissar, inclinação ao andar de lado, mancha sob os mortos, marcas e manchas não pintam os corpos |
| Vozes provisórias | ✅ 49 falas com voz neural (Piper): Miller, Reed, Walker, Hayes, rádio com filtro e chiado |

**Menu principal:** Continuar (último checkpoint, também depois de fechar o jogo) · Nova campanha ·
Opções · Créditos · Sair.
**Pausa (Esc):** Continuar · Opções · Voltar ao último checkpoint · Menu principal · Sair.
**Opções** (salvas em `user://configuracoes.cfg`): sensibilidade, inverter Y, campo de visão,
volumes (geral, efeitos, vozes, ambiente), legendas (liga/desliga, tamanho), qualidade gráfica
(Baixa/Média/Alta), tela cheia e V-Sync. Para pular cutscenes: Espaço ou Enter.

**Vozes:** para regenerar depois de mudar o roteiro, rode
`python3 -I tools/gerar_vozes.py <pasta do piper> <pasta das vozes>`. Só gera as falas novas;
`--todas` refaz tudo. O Piper e as vozes não ficam no projeto (cerca de 270 MB): baixe de novo
pelos links em `assets/CREDITOS.md`. Para trocar por dublagem real, salve
`assets/audio/voz/<id>.ogg` com o mesmo nome.

Também no polimento: removidos os alvos e caixas de treino da praia; a ajuda de controles some
sozinha; a seteira do bunker foi ajustada à altura do novo atirador.

## Missão 1 reestruturada (trabalho autônomo, 15–16/10)

Detalhes em `AUTONOMOUS_WORK_LOG.md`. O que mudou para quem joga:

1. Barco, desembarque e obstáculos continuam iguais.
2. A seteira do bunker tem uma **chapa de aço**: não dá para matar a MG42 de frente.
3. **Torpedo Bangalore**: pegue (E) com o engenheiro morto perto da cratera, leve até o
   **arame farpado** da abertura do muro e plante (segure E por 3 s). Aproveite as **trocas
   de cano** da MG (Reed avisa). O pavio queima 7 s: afaste-se.
4. **Trincheira** atrás do muro até os fundos do bunker, com 4 alemães. Um deles avança e dá
   coronhada; outro joga granada de haste se você ficar escondido muito tempo.
5. **Bunker pela porta dos fundos**, escuro, com o municiador guardando a entrada.
6. Volte ao muro: "O primeiro morto" e o encerramento.

Novos controles: **E** interage, **G** lança granada (2 por missão). Os inimigos fogem das granadas.
Personagens corrigidos: esqueleto feito pelo próprio Mixamo em cada soldado e animações de fuzil
sem conversão; a mão esquerda segura a telha ao mirar.

**Segunda rodada (2026-10-16)** — o que observar:
- soldados: mãos fechadas no fuzil, mira no ombro, agachado ajoelhado com o fuzil pronto;
- tiros: gravações reais em camadas (Garand do jogador em estéreo, Mauser dos alemães, MG42);
- cenário: areia fina, grama nas encostas, água sem manchas, bunker camuflado e com laje e
  muros laterais, e por dentro mesa com lampião, telefone, munição, fuzis e caixotes.

## Testes automáticos

`./tests/rodar_testes.sh` roda os testes de movimento, arma, granada/interação, vida, IA, MG42 e narrativa sem abrir janela.
Rode depois de qualquer mudança.

## Limitações conhecidas (intencionais nesta etapa)

- Passos, granada e Bangalore ainda usam sons sintéticos (os tiros já são gravações reais).
- Os soldados ainda não falam (gritos em alemão entram com o sistema de falas, na etapa 7).
- As bordas do mapa ficam visíveis à distância; o cenário final vai escondê-las.

## Próximos passos

- Modelos de soldados (Mixamo) e do M1 Garand (Fab): precisam de login. O autor conecta o
  Chrome (`/chrome`) ou baixa os arquivos indicados.
- Menu de opções com qualidade gráfica (escala de resolução, sombras, SSAO) para a Iris Xe.
- Etapa 7: narrativa (falas, legendas, gatilhos, objetivos, Miller).
- Assets: o autor vai conectar a extensão do Chrome para o Claude navegar no Fab e no Mixamo.
  Prioridade: M1 Garand em primeira pessoa, com braços e animações.
