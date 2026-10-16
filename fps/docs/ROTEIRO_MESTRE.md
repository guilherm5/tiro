# DOCUMENTO MESTRE DO PROJETO — FPS WWII
## Título provisório: OPERAÇÃO ÚLTIMA LINHA

> Fonte oficial da narrativa. Autor: Guilherme. Alterações neste documento são decisões do autor;
> a implementação (arquivos `.dlg` em `data/dialogue/`) deve seguir este texto.

## 1. CONTEXTO DO PROJETO

Quero desenvolver um FPS narrativo single-player ambientado na Segunda Guerra Mundial, inspirado na experiência de combate de BLACK (2006), Medal of Honor e Call of Duty clássico.

O jogo será desenvolvido para PC utilizando Godot 4.

O objetivo é criar uma experiência de guerra séria, intensa, cinematográfica e humana. Não quero humor, alívio cômico, diálogos exageradamente heroicos ou uma fantasia de poder em que o protagonista elimina centenas de inimigos sem consequências.

A guerra deve parecer caótica, perigosa e imprevisível. O jogador deve sentir o peso dos disparos, o impacto das explosões, o medo de avançar sob fogo inimigo e a responsabilidade de lutar ao lado de outros soldados.

A direção audiovisual deve priorizar:
- Armas com sensação de peso, recuo, animações e sons impactantes.
- Explosões, fumaça, poeira, destroços e ambientes destruídos.
- Combates intensos alternados com momentos de silêncio e tensão.
- Companheiros que se comunicam durante as missões.
- Ordens militares curtas e contextualizadas.
- Inimigos que representam ameaças reais.
- Cutscenes cinematográficas que estabelecem o contexto narrativo.
- Consequências emocionais dos acontecimentos, sem melodrama excessivo.

As referências são apenas inspirações de tom, ritmo e experiência. Personagens, diálogos, acontecimentos e roteiro devem ser originais.

## 2. PREMISSA NARRATIVA

A história se passa na França ocupada, em junho de 1944, durante a campanha aliada na Normandia.

O protagonista pertence a uma unidade americana de infantaria encarregada de avançar para o interior, abrir rotas para os reforços e neutralizar posições alemãs que impedem o avanço aliado.

Durante uma operação de desembarque, a unidade sofre baixas e perde contato com outras forças. A missão se transforma em uma sequência de operações para recuperar informações estratégicas, manter uma rota aberta e localizar o posto de comando responsável pela resistência alemã na região.

Um informante francês chamado Marcel Duval conhece a localização de posições defensivas e das comunicações inimigas. Suas informações indicam que o major alemão Ernst Keller coordena a defesa a partir de um bunker fortificado.

A campanha terá quatro missões principais. Cada uma deverá desenvolver a história, apresentar uma experiência de combate distinta e conduzir naturalmente à seguinte.

A narrativa não deve transformar o protagonista em um super-herói. Ele é um soldado competente que depende do esquadrão, das circunstâncias e das decisões tomadas durante as operações.

## 3. PERSONAGENS PRINCIPAIS

### Cabo Daniel Hayes — protagonista
Idade: 26 anos.

Soldado americano de infantaria e personagem controlado pelo jogador. É disciplinado, observador e relativamente experiente no uso de armas, mas não é invulnerável nem excepcionalmente poderoso.

Suas falas são curtas, diretas e ligadas à situação. Ele não deve fazer discursos motivacionais nem explicar informações que os personagens já conhecem.

### Sargento Thomas Miller — líder do esquadrão
Idade: 38 anos.

Veterano responsável por comandar o grupo. É experiente, pragmático e disciplinado. Procura manter os homens vivos sem perder de vista os objetivos militares.

Não é um comandante insensível, mas também não desperdiça palavras. Suas ordens são objetivas. Sua preocupação com os soldados aparece principalmente em suas ações e decisões.

### Soldado James Reed — operador de rádio
Idade: 22 anos.

Responsável pelas comunicações com o comando. É inteligente e dedicado, mas demonstra nervosismo sob pressão. Suas falas devem transmitir tensão humana sem transformar o personagem em uma caricatura covarde ou cômica.

### Soldado Frank Walker — socorrista de combate
Idade: 31 anos.

Responsável pelo atendimento dos feridos. É prático, atento e emocionalmente contido. Sabe que nem todos poderão ser salvos e não promete resultados impossíveis.

### Marcel Duval — informante francês
Civil francês que trabalha com a resistência local. Conhece as posições defensivas alemãs, as rotas de acesso e a localização do bunker de comando.

Está ferido quando é encontrado e precisa ser retirado da região. Suas informações motivam a segunda metade da campanha.

### Major Ernst Keller — antagonista
Oficial alemão responsável pela defesa de um setor estratégico. É disciplinado, calculista e determinado a cumprir suas ordens.

Não deve ser retratado como um vilão caricato. Seu confronto final com Miller deve abordar, de maneira breve e contida, a responsabilidade individual e o cumprimento de ordens durante a guerra.

## 4. MISSÃO 1 — DESEMBARQUE

### Objetivo
Atravessar a praia, neutralizar uma posição de metralhadora e alcançar o ponto de reunião.

### Contexto
Às 06h28, a unidade chega à costa da Normandia. O bombardeio não destruiu todas as defesas alemãs. A embarcação se aproxima sob fogo inimigo, e os soldados precisam atravessar uma praia exposta para alcançar uma posição de concreto que domina a faixa costeira.

### CUTSCENE DE ABERTURA — DENTRO DA EMBARCAÇÃO

O casco range e a embarcação balança violentamente. Explosões são ouvidas ao longe. Os soldados verificam suas armas e equipamentos.

MILLER: Confiram as armas. Carregadores, granadas, equipamento. Façam isso agora.

REED: O comando disse que a artilharia atingiria as posições antes da nossa chegada.

MILLER: Disse que tentaria atingir. Não é a mesma coisa.

WALKER: Temos feridos previstos no desembarque?

MILLER: Temos uma praia inteira de homens que podem precisar de você. Fique perto do grupo.

HAYES: Qual é o ponto de reunião?

MILLER: Atrás da primeira linha de obstáculos, junto ao muro de concreto. Se nos separarmos, é para lá que você vai.

Uma explosão próxima sacode a embarcação.

REED: Sargento... e se a posição ainda estiver intacta?

MILLER: Então vamos ter que lidar com ela.

O rádio chia.

RÁDIO: Unidade de desembarque, atenção... resistência pesada na faixa costeira... posições de metralhadora ainda ativas... comunicação interrompida...

MILLER: Vocês ouviram. Quando a rampa baixar, saiam imediatamente. Não parem para procurar um caminho perfeito. Usem os obstáculos e avancem.

WALKER: E se alguém cair?

MILLER: Se houver cobertura e você puder alcançá-lo, ajude. Se não houver, não transforme dois feridos em quatro.

A embarcação reduz a velocidade.

MILLER: Preparar para desembarque!

### SEQUÊNCIA DE GAMEPLAY — A PRAIA

A rampa desce. Metralhadoras disparam contra a água e a areia. O jogador assume o controle de Hayes.

MILLER: SAIAM! SAIAM DA EMBARCAÇÃO!

REED: METRALHADORA À FRENTE!

MILLER: USEM OS OBSTÁCULOS! MOVAM-SE!

O jogador avança pela água. Um soldado cai ao lado de Hayes.

SOLDADO FERIDO: Não me deixa aqui! Por favor!

Miller puxa Hayes para trás de um obstáculo.

MILLER: Hayes! Olhe para mim! A posição de metralhadora está cobrindo a praia inteira. Se ficarmos aqui, ninguém atravessa!

HAYES: Entendido.

MILLER: Reed, consegue localizar de onde vem o fogo?

REED: Da estrutura de concreto, à esquerda! Segundo andar ou uma abertura lateral!

MILLER: Walker, fique com os feridos atrás daquela barreira. Reed, mantenha o rádio funcionando. Hayes, comigo!

OBJETIVO: Neutralize a posição de metralhadora inimiga.

### FALAS CONTEXTUAIS DO COMBATE

MILLER: Não fique parado na areia! Procure cobertura!

REED, PELO RÁDIO: A posição continua ativa! Não consigo contato com a unidade da esquerda!

WALKER: Tenho feridos aqui! Preciso de cobertura, agora!

Se o jogador permanecer exposto:

MILLER: Hayes, saia dessa posição! Você está completamente exposto!

Após neutralizar a metralhadora:

MILLER: A metralhadora parou! Avancem para o muro!

REED: Estou recebendo alguma coisa... Comando, aqui é o soldado Reed. Solicito confirmação da rota de avanço.

RÁDIO: ...rota comprometida... unidades dispersas... prossigam para o ponto de reunião secundário...

MILLER: Você ouviu. Vamos nos reagrupar.

### CENA — O PRIMEIRO MORTO

O esquadrão alcança o muro de concreto. Walker atende um soldado gravemente ferido.

WALKER: Ele não vai conseguir continuar.

MILLER: Consegue transportá-lo?

WALKER: Não sem deixar os outros para trás.

O soldado ferido segura o braço de Walker.

SOLDADO FERIDO: Minha família... você pode escrever para eles?

WALKER: Posso.

SOLDADO FERIDO: Diga que eu tentei voltar.

Walker permanece em silêncio. O soldado perde a consciência.

REED: Sargento...

MILLER: Não agora, Reed.

REED: Eu só ia dizer que o rádio voltou.

Miller olha para Hayes.

MILLER: Você fez o que precisava fazer lá fora. Não confunda isso com ter controle sobre tudo o que acontece aqui.

MILLER: Recolham o que puderem carregar. Partimos em dois minutos.

### CUTSCENE DE ENCERRAMENTO

O esquadrão avança para longe da praia. Embarcações continuam chegando ao fundo.

REED: Comando confirmou uma posição defensiva a alguns quilômetros daqui. Há um informante escondido em uma vila próxima.

MILLER: Nome?

REED: Marcel Duval. Trabalhava com a resistência francesa. Tem informações sobre as comunicações alemãs e a defesa da região.

HAYES: E nós vamos buscá-lo?

MILLER: Vamos encontrá-lo, retirar as informações e abrir a rota para o avanço.

WALKER: E os homens que ficaram na praia?

MILLER: Se houver uma maneira de voltar por eles, nós voltaremos.

Encerramento: MISSÃO CONCLUÍDA — DESEMBARQUE.

## 5. MISSÃO 2 — PRÉDIO EM RUÍNAS

### Objetivo
Localizar Marcel Duval, recuperar suas informações e escapar do prédio.

### Contexto
Às 09h10, o esquadrão chega a uma vila francesa parcialmente destruída. O último sinal de Duval veio de um prédio próximo à praça. Há indícios de combate recente e sinais de que os alemães também estão procurando alguém.

### CUTSCENE DE ABERTURA — APROXIMAÇÃO DA VILA

REED: O último sinal de Duval veio de um prédio perto da praça.

MILLER: Ele sabia que estávamos chegando?

REED: O comando disse que sim. Não houve confirmação depois disso.

HAYES: Pode ter sido capturado.

MILLER: Pode. Ou pode estar escondido esperando que paremos de fazer barulho.

WALKER: Se estiver ferido, cada minuto importa.

MILLER: Então vamos evitar perder tempo discutindo.

O grupo se aproxima da entrada.

MILLER: Reed, fique no rádio. Walker, comigo. Hayes, cubra a entrada.

REED: E se perdermos contato?

MILLER: Recuamos para a esquina da igreja. Não entre no prédio sozinho.

### SEQUÊNCIA DE GAMEPLAY — EXPLORAÇÃO

O jogador entra no prédio. O interior é escuro, com móveis destruídos, paredes rachadas e destroços espalhados pelo chão.

WALKER: Há sangue no chão.

HAYES: Recente?

WALKER: Não sei. Mas não está completamente seco.

Um ruído vem do andar superior.

MILLER: Parados.

Após alguns segundos:

MILLER: Hayes, verifique a escada. Devagar.

HAYES: Movimento no corredor!

Dois soldados inimigos abrem fogo.

MILLER: Cobertura! Não avance pelo meio!

WALKER: Estou vendo a escada! Não deixem ninguém descer por trás!

Após o combate:

REED, PELO RÁDIO: Sargento, estou captando uma transmissão alemã. Eles estão procurando alguém na vila.

MILLER: Conseguimos identificar quem?

REED: Não. Mas repetem a palavra "prisioneiro".

HAYES: Duval.

MILLER: É provável. Continuem procurando.

### CENA — ENCONTRO COM DUVAL

O jogador chega a um cômodo parcialmente desabado. Atrás de uma estante, um homem ferido aponta uma pistola para a porta.

DUVAL: Não se aproxime!

MILLER: Exército americano. Abaixe a arma.

DUVAL: Como vou saber que não são eles?

HAYES: Se fôssemos alemães, já teríamos entrado atirando.

Duval observa os uniformes e abaixa lentamente a pistola.

DUVAL: Pensei que não viriam.

MILLER: Temos uma rota de extração. Consegue andar?

DUVAL: Consigo. Mas não temos tempo. Eles sabem que estou aqui.

REED, PELO RÁDIO: Sargento, movimento na rua. Vários homens se aproximando do prédio.

MILLER: Duval, as informações. Agora.

Duval entrega um envelope dobrado, sujo de sangue.

DUVAL: Posições de artilharia, postos de comunicação e uma instalação de comando. O oficial responsável pela defesa coordena tudo a partir de um bunker fora da vila.

MILLER: Nome?

DUVAL: Major Ernst Keller. Ele mudou o posto de comando depois do último bombardeio. Os mapas que vocês receberam estão desatualizados.

HAYES: Onde fica o bunker?

DUVAL: Ao norte, depois da estrada de pedra. Há uma entrada principal e uma passagem de serviço. A passagem pode estar bloqueada.

Disparos atingem a parede.

MILLER: Conversamos depois. Vamos sair daqui!

### SEQUÊNCIA DE GAMEPLAY — RETIRADA

REED: A entrada desabou! Não temos mais caminho por onde viemos!

MILLER: Duval, a passagem de serviço!

DUVAL: Pela cozinha. Desce até um depósito. De lá, dá para sair para o beco.

WALKER: Ele mal consegue ficar em pé.

MILLER: Então não o deixem para trás.

O jogador cobre a retirada do grupo.

DUVAL: A resistência ainda tem homens escondidos na região. Se chegarmos até a estrada, posso indicar onde estão.

MILLER: Primeiro vamos chegar à estrada.

O grupo alcança o beco. Uma explosão derruba parte da parede atrás deles.

REED: Sargento! Estou recebendo o comando. Eles confirmaram as coordenadas do bunker.

MILLER: E os reforços?

REED: Estão atrasados. Há resistência alemã na estrada.

MILLER: Claro que há.

### CUTSCENE DE ENCERRAMENTO

O grupo se abriga em uma casa abandonada. Walker atende Duval. Miller examina o mapa.

DUVAL: Se Keller continuar coordenando a defesa, vocês vão perder homens a cada quilômetro.

MILLER: Então vamos tirar Keller do comando.

HAYES: O que sabemos sobre a posição?

DUVAL: O bunker foi construído para resistir a bombardeios. A entrada é estreita. Há trincheiras e posições defensivas ao redor.

REED: O comando quer que mantenhamos a estrada aberta até a chegada dos reforços.

MILLER: Quanto tempo?

REED: Não deram um horário.

Miller dobra o mapa.

MILLER: Então vamos preparar uma posição e esperar o mínimo possível.

DUVAL: Se vocês falharem, Keller vai saber que os mapas dele estão nas mãos dos americanos.

MILLER: Ele já sabe. A diferença é que agora nós também sabemos onde encontrá-lo.

Encerramento: MISSÃO CONCLUÍDA — PRÉDIO EM RUÍNAS.

## 6. MISSÃO 3 — TRINCHEIRA

### Objetivo
Defender a posição, manter o rádio operacional e resistir até a chegada dos reforços.

### Contexto
Às 14h40, o esquadrão chega a uma linha de trincheiras que protege uma estrada estratégica. A posição está danificada e os reforços aliados estão atrasados. Se os alemães retomarem a estrada, o avanço será comprometido.

### CUTSCENE DE ABERTURA — PREPARAÇÃO

MILLER: Esta estrada é a única rota utilizável para os veículos que vêm do sul. Se os alemães a retomarem, os reforços não chegam.

REED: O comando disse que enviaria uma companhia.

MILLER: O comando disse muita coisa hoje.

WALKER: Temos munição suficiente?

MILLER: Para manter a posição, se ninguém desperdiçar disparos.

Reed tenta estabelecer contato pelo rádio.

REED: Comando, aqui é a unidade de Miller. Estamos na posição defensiva designada. Solicito confirmação do reforço.

RÁDIO: ...unidade em deslocamento... resistência na estrada... mantenham a posição...

REED: Quanto tempo?

O rádio apresenta estática.

HAYES: Isso significa quanto tempo?

REED: Significa que não sabem.

MILLER: Então trabalharemos com o que temos.

### PRIMEIRO ATAQUE

Um observador aliado identifica movimento próximo à linha das árvores.

OBSERVADOR: Movimento na linha das árvores!

MILLER: Todos aos postos!

REED: Contato confirmado! Grupo inimigo avançando pela estrada!

MILLER: Hayes, cubra a aproximação. Walker, fique no abrigo central. Reed, mantenha o rádio aberto!

Durante o combate:

MILLER: Espere até conseguir identificar o alvo!

WALKER: Ferido na seção norte! Preciso de ajuda!

HAYES: Estou indo!

MILLER: Hayes, mantenha a linha! Walker consegue cuidar dele!

Após repelir o primeiro ataque:

REED: O comando confirmou que os reforços ainda estão a caminho.

MILLER: Alguma estimativa?

REED: Negativo.

MILLER: Continue tentando.

### SEGUNDO ATAQUE

Uma explosão atinge a extremidade da trincheira. A antena do rádio cai.

REED: Perdemos a antena!

MILLER: Consegue reparar?

REED: Preciso chegar ao suporte externo. Está no meio da linha de tiro.

MILLER: Então espere uma oportunidade. Não vou mandar você morrer por um rádio.

Disparos de metralhadora atingem os sacos de areia.

OBSERVADOR: Veículos na estrada! Eles estão tentando contornar a posição!

MILLER: Hayes, comigo! Vamos impedir que cheguem à lateral!

Após o combate, Reed consegue restabelecer parcialmente a comunicação.

REED: Consegui restabelecer parte do contato!

RÁDIO: ...unidade Miller... situação?

MILLER: Posição sob ataque. Precisamos de reforços imediatamente.

RÁDIO: ...atraso... estrada bloqueada... não podemos confirmar chegada...

O sinal desaparece.

HAYES: Eles não vêm.

MILLER: Não sabemos disso.

HAYES: E se não vierem?

MILLER: Então decidiremos o que fazer quando não houver mais alternativas.

### TERCEIRO ATAQUE — A POSIÇÃO QUASE CAI

O inimigo inicia um ataque coordenado. A munição está escassa e parte da trincheira foi destruída.

REED: Estão avançando pelos dois lados!

MILLER: Mantenham o centro! Não deixem que entrem na trincheira!

WALKER: Tenho dois feridos e não consigo transportá-los!

MILLER: Mantenha-os protegidos!

Uma explosão derruba um soldado aliado perto de Hayes.

MILLER: Hayes! Preciso que você segure aquela passagem!

REED: Não temos mais contato com o comando!

MILLER: Continue tentando!

REED: Sargento, não temos como segurar isso indefinidamente!

MILLER: Eu sei!

O jogador repele os últimos inimigos que penetraram na linha defensiva.

### CENA — CHEGADA DOS REFORÇOS

O som de motores cresce ao longe. Veículos aliados aparecem na estrada.

REED: Estou recebendo um sinal.

MILLER: O quê?

REED: Veículos aliados. Estão na estrada.

MILLER: Hayes, verifique a lateral. Não quero descobrir que ainda há alguém esperando por nós lá fora.

Após o jogador verificar a posição:

HAYES: Está limpa.

MILLER: Muito bem. Reúnam o equipamento. Vamos nos juntar aos reforços.

WALKER: E os feridos?

MILLER: Serão evacuados primeiro.

REED: O comando enviou novas ordens. A unidade deve avançar para o bunker assim que possível.

Miller olha para Hayes.

MILLER: Você ouviu. Ainda não acabou.

### CUTSCENE DE ENCERRAMENTO

Os veículos aliados passam pela estrada. Soldados transportam feridos. Hayes observa a trincheira danificada.

REED: O comando confirmou a localização final de Keller.

MILLER: Então não temos mais motivo para esperar.

WALKER: Temos homens exaustos, munição limitada e feridos.

MILLER: Eu sei. Vamos nos reorganizar, reabastecer o que for possível e seguir com o grupo de assalto.

HAYES: E se o bunker estiver mais protegido do que Duval disse?

MILLER: Vai estar.

HAYES: Então por que continuar?

MILLER: A questão não é se vai ser difícil. A questão é o que acontece se deixarmos Keller continuar comandando aquela defesa.

Encerramento: MISSÃO CONCLUÍDA — TRINCHEIRA.

## 7. MISSÃO 4 — BUNKER FINAL

### Objetivo
Infiltrar-se no bunker, interromper as comunicações, localizar Keller e concluir a operação.

### Contexto
Às 18h15, o esquadrão se aproxima do bunker alemão. A posição é fortificada, com trincheiras, concreto reforçado e acessos protegidos. O grupo precisa entrar pela passagem de serviço, desativar as comunicações e capturar o major Keller.

### CUTSCENE DE ABERTURA — PREPARAÇÃO PARA O ASSALTO

MILLER: Duval confirmou a localização. A entrada principal está protegida. A passagem de serviço fica no lado norte.

REED: O bunker ainda transmite ordens. O comando acredita que Keller está lá dentro.

WALKER: Quantos homens estão na defesa?

MILLER: Não sabemos.

HAYES: Qual é o plano?

MILLER: Entramos pela passagem de serviço. Reed procura a sala de comunicações. Precisamos interromper a coordenação deles. Depois localizamos Keller.

REED: E se o acesso estiver bloqueado?

MILLER: Encontramos outra maneira.

WALKER: E se não houver outra maneira?

Miller ajusta o capacete.

MILLER: Então não vamos desperdiçar tempo discutindo isso aqui.

MILLER: Não se afastem. Lá dentro, se perdermos contato, seguimos o plano. Se encontrarem resistência, não avancem sozinhos. Entendido?

HAYES: Entendido.

REED: Entendido.

WALKER: Vamos terminar isso.

### SEQUÊNCIA DE GAMEPLAY — ENTRADA

O jogador avança pela passagem de serviço, parcialmente bloqueada por destroços. O interior é escuro, com lâmpadas de emergência e sons de ventilação.

REED: As paredes são grossas. Se o rádio parar de funcionar, não conseguirei falar com o comando daqui.

MILLER: Você só precisa nos manter informados enquanto puder.

Uma voz alemã é ouvida do outro lado de uma porta.

SOLDADO ALEMÃO: ...a posição externa não respondeu. O major quer uma confirmação imediata.

Miller sinaliza para o grupo esperar. Dois soldados inimigos passam pelo corredor.

MILLER, BAIXO: Deixem passar.

Após os soldados se afastarem:

HAYES: Eles não sabem que estamos aqui.

MILLER: Ainda não.

O jogador avança. Uma porta se abre e começa um combate.

MILLER: CONTATO! CUBRAM A ENTRADA!

REED: Estou vendo uma sala de comunicações no mapa! Deve estar no corredor inferior!

MILLER: Então é para lá que vamos!

### CENA — SALA DE COMUNICAÇÕES

O grupo alcança uma sala com equipamentos de rádio, mapas e telefones de campanha. Um operador inimigo tenta destruir documentos.

MILLER: Afaste-se do equipamento!

OPERADOR ALEMÃO: Não atirem. Eu não sou soldado de combate.

MILLER: Afaste-se da mesa. Agora.

Reed examina os equipamentos.

REED: Temos transmissões ativas para várias posições. Eles estão coordenando a defesa por aqui.

HAYES: Consegue interromper tudo?

REED: Posso desligar o equipamento principal, mas não sei quanto tempo vai levar para eles perceberem.

MILLER: Faça isso.

Reed desliga o equipamento principal.

REED: Pronto. O sinal principal caiu.

Um telefone começa a tocar.

MILLER: Não atenda.

O telefone continua tocando até parar.

REED: O comando vai perceber que a comunicação foi interrompida.

MILLER: Era esse o objetivo.

Disparos ecoam no corredor.

MILLER: Hayes, cubra a porta. Reed, terminou?

REED: Terminei.

MILLER: Então vamos encontrar Keller.

### SEQUÊNCIA DE GAMEPLAY — CORREDOR FINAL

O grupo avança por um corredor estreito. Há documentos espalhados e soldados alemães abandonando posições internas.

WALKER: Estão recuando.

MILLER: Alguns estão. Outros vão tentar nos impedir.

HAYES: Estamos perto?

REED: Segundo o mapa, a sala de comando fica no fim do corredor.

Uma explosão distante faz a estrutura tremer.

WALKER: O bunker está desabando?

MILLER: Não sei. Continuem avançando.

O grupo encontra uma porta de aço parcialmente aberta. Vozes são ouvidas do outro lado.

KELLER: A comunicação externa foi perdida?

OFICIAL ALEMÃO: Sim, major. Não temos confirmação das posições ao norte.

KELLER: E as unidades na estrada?

OFICIAL ALEMÃO: Sem contato.

KELLER: Então a defesa já foi comprometida.

Pausa.

KELLER: Preparem os documentos restantes para destruição. Ninguém sai daqui com os mapas.

Miller sinaliza para Hayes.

MILLER, BAIXO: Quando entrarmos, fique atento. Não sabemos quantos estão naquela sala.

O jogador entra. Após o combate, Keller permanece junto a uma mesa, com uma pistola ao alcance da mão.

### CENA — CONFRONTO COM KELLER

Keller levanta lentamente as mãos. Miller aponta a arma para ele.

MILLER: Major Ernst Keller?

KELLER: Você já sabe a resposta.

MILLER: Afaste-se da mesa.

Keller obedece.

KELLER: Vocês chegaram tarde demais.

HAYES: Para quê?

KELLER: Para impedir que esta região se torne um campo de batalha ainda maior.

MILLER: Você poderia ter se rendido.

KELLER: E você acredita que isso teria mudado alguma coisa?

MILLER: Teria mudado o que acontece agora.

Keller olha para os mapas destruídos.

KELLER: Recebi ordens para manter esta posição. Cumpri minhas ordens.

MILLER: E quantos homens morreram por causa delas?

KELLER: Quantos morreram para que vocês chegassem até aqui?

Miller permanece em silêncio por alguns segundos.

KELLER: Você não é diferente de mim, sargento. Também recebeu ordens.

MILLER: Talvez. Mas eu ainda posso decidir o que faço depois delas.

Miller se aproxima e retira a pistola de Keller da mesa.

MILLER: Hayes, revistá-lo. Reed, verifique os documentos. Walker, mantenha a entrada protegida.

Keller é desarmado e colocado sob custódia.

### CENA — ÚLTIMA TRANSMISSÃO

Reed encontra um rádio ainda funcional e tenta estabelecer contato.

REED: Comando, aqui é Reed, unidade de Miller. O posto de comando inimigo foi neutralizado. Keller está sob custódia. Solicito confirmação.

Após alguns segundos, uma voz responde.

RÁDIO: Unidade Miller, recebemos sua transmissão. Confirme a situação.

REED: A sala de comunicações foi desativada. As posições inimigas perderam coordenação. Temos documentos e mapas para recolher.

RÁDIO: Entendido. Mantenham a posição. Uma equipe está a caminho.

Reed abaixa o rádio.

WALKER: Acabou?

REED: Para nós, acho que sim.

Miller observa os documentos espalhados pela sala.

MILLER: Não. Só terminamos o que viemos fazer.

HAYES: E agora?

MILLER: Agora saímos daqui.

### CUTSCENE FINAL — O FIM DA OPERAÇÃO

O esquadrão deixa o bunker ao entardecer. O céu está coberto de fumaça. Veículos aliados avançam pela estrada. Não há música triunfal, apenas vento, motores e disparos distantes.

Walker caminha com dificuldade. Reed carrega o rádio danificado. Miller para por um instante e olha para Hayes.

MILLER: Quantos carregadores ainda tem?

HAYES: Dois.

MILLER: Guarde-os. Não sabemos o que vem depois.

Hayes observa os veículos que passam.

HAYES: Achei que, quando terminasse, eu sentiria alguma coisa diferente.

MILLER: Diferente como?

HAYES: Não sei. Alívio, talvez.

Miller olha para a estrada.

MILLER: Talvez você sinta quando conseguir dormir.

Os dois permanecem em silêncio.

REED: Sargento... o comando está chamando. Quer saber se podemos continuar avançando amanhã.

Miller fecha os olhos por um instante.

MILLER: Diga que recebemos a mensagem.

REED: E depois?

MILLER: Depois vamos descansar enquanto ainda podemos.

A câmera se afasta lentamente, mostrando os soldados caminhando pela estrada, pequenos diante da paisagem destruída.

TELA PRETA.

TEXTO NA TELA:

FRANÇA, JUNHO DE 1944.

O avanço aliado continuou nos dias seguintes. Para os homens que lutaram na Normandia, a tomada de uma posição nunca significou o fim da guerra.

FIM.

## 8. REGRAS DE IMPLEMENTAÇÃO NARRATIVA

Este documento é a referência narrativa do projeto. Ao implementar o jogo no Godot 4, siga estas regras:

1. Não altere os acontecimentos centrais, as motivações dos personagens ou os resultados das quatro missões sem minha autorização.
2. Preserve o tom sério, militar, cinematográfico e humano.
3. As falas de combate devem ser curtas e contextualizadas. Não reproduza continuamente uma mesma frase durante o gameplay.
4. Separe as cutscenes das falas contextuais, das ordens de combate e dos diálogos opcionais.
5. As cutscenes precisam permitir transições claras entre a cena narrativa e o controle do jogador.
6. Organize os diálogos em dados ou recursos separados dos scripts de gameplay sempre que possível, para facilitar futuras alterações no roteiro.
7. Crie um sistema que permita associar falas a eventos específicos, como início de missão, entrada em uma área, avistamento de inimigos, conclusão de objetivos e encerramento de combate.
8. Evite reproduzir simultaneamente falas de vários personagens de maneira incompreensível. Priorize as informações importantes e permita pequenas pausas entre as linhas.
9. Não é necessário implementar dublagem real imediatamente. Na primeira versão, use legendas e áudio temporário ou placeholders, mantendo a possibilidade de adicionar dublagem depois.
10. Não invente novas missões ou personagens principais sem discutir comigo.
11. O jogador deve conseguir compreender os objetivos sem depender exclusivamente dos diálogos.
12. A narrativa deve ser transmitida tanto pelas falas quanto pelo ambiente, pelo comportamento dos personagens e pelas consequências do combate.

## 9. DIRETRIZES PARA O DESENVOLVIMENTO

Não tente construir as quatro missões completas de uma só vez.

Desenvolva primeiro uma pequena demonstração jogável que inclua movimentação em primeira pessoa, arma funcional, inimigos, combate, áudio, efeitos visuais e um objetivo simples inspirado no desembarque.

Use sistemas modulares e reutilizáveis para jogador, armas, inimigos, inteligência artificial, áudio, interface, diálogos, objetivos, cutscenes e gerenciamento de missões.

Trabalhe em etapas pequenas. Depois de cada etapa, explique como executar e testar o resultado no Godot. Não considere uma funcionalidade concluída apenas porque o código foi escrito: precisamos verificar o comportamento no jogo.

Mantenha documentação curta da arquitetura, dos arquivos criados e dos próximos passos.
