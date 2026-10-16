extends Node
## Eventos globais do jogo. Sistemas emitem e escutam aqui sem precisarem se conhecer
## (ex.: o HUD e, futuramente, as falas reagem ao dano sem depender do jogador).
##
## Adicione sinais aqui só quando algum sistema realmente precisar deles.

## O jogador levou dano. `source_position` é de onde veio (para o indicador de direção).
signal player_damaged(amount: float, source_position: Vector3)
signal player_healed(amount: float)
signal player_died

## Barulho que inimigos podem ouvir (tiros do jogador etc.). `radius` em metros.
signal noise_emitted(position: Vector3, radius: float, source: Node)

## Um inimigo morreu (objetivos e falas de combate vão escutar isto).
signal enemy_killed(enemy: Node)

## Acontecimento narrativo com nome (gatilho de área, morte importante, @evento de
## diálogo...). O script da missão (data/missions/*.missao) reage a eles.
signal narrative_event(event_name: String)
signal mission_completed(title: String)
signal cutscene_started(id: String)
signal cutscene_finished(id: String)
