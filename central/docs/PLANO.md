# Plano de ação: de "luta que funciona" para "jogo jogável"

Escrito em 14/10/2026, depois da primeira partida do Guilherme.

**Andamento (14/10, noite):** fases A a H implementadas e testadas; ver STATUS.md e o
DIARIO.md. Falta da G: modelo v3 do PCI e efeitos visuais melhores. Próxima: fase I.

## Ponto de partida

O que o Guilherme sentiu: fluido, golpes justos, nenhuma animação estranha.
O que o registro da partida mostrou:
- vitória por K.O. em 26 s, 16 acertos contra 8;
- 13 dos 16 acertos foram **soco**: o soco é seguro demais (rápido, alcança, não deixa brecha);
- a CPU bloqueia pouco e nunca pune.

Diagnóstico: hoje um golpe é "uma animação que causa dano entre 30% e 55%". Jogo de
luta de verdade é feito de **dados de quadro** (início, ativos, recuperação, vantagem no
acerto e no bloqueio), **níveis de golpe** (alto, médio, baixo) e **regras de cancelamento**.
Combo, punição e escolha entre golpe seguro e arriscado saem disso. Pulo, agachamento e
combos precisam dessa base; sem ela viram remendo.

## Fases

Cada fase termina com algo jogável e com teste automático. Animações novas saem do
Mixamo (baixo pelo Chrome, como as 9 atuais).

### Fase A — Fundação (pré-requisito de todo o resto)
- **Lógica em quadros fixos (60/s)**, não em porcentagem da animação. A animação passa a
  acompanhar a lógica, e não o contrário.
- **Golpes como dados** (um arquivo por golpe): animação, quadros de início/ativos/recuperação,
  dano, nível (alto/médio/baixo), quadros de atordoamento no acerto e no bloqueio, empurrão,
  em quais golpes pode cancelar. Golpe novo = arquivo novo, sem mexer em código.
- **Buffer de comandos**: um botão apertado alguns quadros antes do fim do golpe anterior
  ainda sai. É o que faz o jogo "responder" e é obrigatório para combo e especial.
- **Controle (gamepad)**, além do teclado.
- **Modo de depuração**: mostra as caixas de colisão, os dados de quadro e os comandos na tela.
- **Gravação de comandos (replay)**: grava uma sequência de botões e reproduz idêntica.
  Cada mecânica nova ganha um replay como teste.
- Rebalancear soco e chute com os dados de quadro (soco rápido mas curto e fraco; chute lento
  com mais alcance e mais brecha).

### Fase B — Movimentação
- **Pulo** para cima, para frente e para trás, com arco de verdade, aterrissagem e quadros
  vulneráveis ao pousar.
- **Agachar**: abaixa a caixa do corpo (golpes altos passam por cima), anda agachado ou não.
- **Corrida curta e esquiva para trás** (toque duplo ←← / →→).
- **Troca de lado**: pular por cima do adversário vira o personagem.
- **Caixas de empurrão** separadas das de dano (corpos não se sobrepõem nem no pulo).
- Ajuste fino de velocidade, aceleração e transições entre animações.

### Fase C — Ataque e defesa
- **Botões**: fraco e forte para soco e chute (4 botões, padrão da época).
- **Golpes agachados** (rasteira = baixo, tem que defender agachado) e **golpes no ar**
  (alto, tem que defender em pé) → o jogo de adivinhação alto/baixo.
- **Agarrão** (vence quem está bloqueando) e escape de agarrão.
- **Queda e levantar**: alguns golpes derrubam; o caído levanta com leve invencibilidade.
- **Dano de raspão** no bloqueio, já existe; ajustar com os novos golpes.
- **Variedade de reação**: atingido no rosto, no corpo, agachado, no ar.

### Fase D — Combos
- **Cadeias**: fraco → fraco → forte.
- **Cancelamento**: golpe normal cancela em especial.
- **Malabarismo** (juggle) com limite, para não virar combo infinito.
- **Escala de dano**: cada golpe do combo tira um pouco menos.
- **Contador de combo** na tela ("3 HITS!").

### Fase E — Golpes especiais (com a katana)
- **Comandos**: meia-lua (↓↘→ + botão), Z (→↓↘ + botão), carregar (← segurado, depois →).
- **Katana sai das costas** para a mão durante o especial e volta depois.
- Especiais planejados para o PCI (nomes provisórios): corte em avanço, corte anti-aéreo
  subindo, uma estrela ninja (projétil).
- **Barra de especial**: enche ao bater e apanhar; gasta num **super** com câmera e zoom.

### Fase F — Estrutura de jogo
- **Melhor de 3 rounds**, com placar de rounds.
- **Tela de título**, **pausa**, **opções** (volume, remapear controles, dificuldade).
- **Modo treino**: CPU parada/bloqueando/pulando, vida infinita, dados de quadro na tela.
- **Seleção de personagem** (pronta para quando houver o segundo lutador).

### Fase G — Apresentação
- **Som**: impactos (fraco/forte/bloqueio), passos, pulo, katana, K.O., locutor
  ("Round 1", "Lute!", "K.O."). Fontes grátis com licença CC0 ou gerados por mim.
- **Música** de fundo (CC0).
- **Efeitos**: rastro do golpe, faíscas melhores, câmera lenta no K.O., poeira na queda.
- **Filtro de PS2**: resolução interna baixa, textura sem filtro, leve tremido de vértice.
- **Modelo do PCI v3**: cabelo, mãos, rosto em resolução maior.

### Fase H — CPU mais esperta
- Usa os dados de quadro: pune golpe bloqueado, defende baixo contra rasteira,
  anti-aéreo contra pulo, agarra quem bloqueia demais.
- **Níveis de dificuldade** de verdade (tempo de reação, taxa de erro, leitura de padrão).

### Fase I — Segundo lutador
- Valida que o pipeline (modelo → Mixamo → montagem → arquivos de golpe) funciona para
  qualquer personagem, sem código específico de um lutador.

## Ordem recomendada

A → B → C → D → E, depois F, G e H em paralelo conforme o gosto, e I por último.
A e B juntos já mudam bastante a sensação: pulo, agachamento e o buffer de comandos são
o que mais se sente na mão.

## Decisões tomadas (14/10)

1. Bloqueio: segurar para trás, estilo Street Fighter.
2. Luta 3D com passo lateral (Tekken).
3. 4 botões estilo Tekken (um por membro).
4. Só teclado por enquanto.
