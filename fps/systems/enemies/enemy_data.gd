class_name EnemyData
extends Resource
## Parâmetros de um tipo de inimigo. Um tipo novo (ex.: oficial, sentinela) = um .tres novo.

@export var display_name := "Soldado"
@export var max_health := 100.0
## Multiplicador de dano na cabeça.
@export var headshot_multiplier := 4.0

@export_group("Percepção")
@export var sight_range := 70.0
## Abertura total do cone de visão (graus).
@export var sight_fov_degrees := 120.0
## Segundos para notar o jogador a 10 m (mais longe = mais devagar).
@export var notice_time := 0.6
## Distância em que ouve um tiro do jogador.
@export var hearing_range := 60.0

@export_group("Movimento")
@export var walk_speed := 1.8
@export var run_speed := 4.2
@export var turn_speed := 6.0

@export_group("Tiro")
@export var damage := 34.0
@export var fire_interval_min := 1.6
@export var fire_interval_max := 2.6
## Tempo entre ver o alvo e o primeiro disparo.
@export var reaction_time := 0.7
## Erro base (metros de raio no alvo a 10 m). Cresce com a distância.
@export var spread_at_10m := 0.75
## Penalidade quando o alvo corre (multiplica o erro na velocidade máxima).
@export var moving_target_penalty := 1.6
## Tempo mirando continuamente até a mira "assentar" (erro mínimo).
@export var aim_settle_time := 4.0
@export var max_range := 200.0
@export var sound_fire: AudioStream

@export_group("Cobertura")
## Raio de busca por pontos de cobertura.
@export var cover_search_radius := 25.0
## Tempo escondido entre uma saída e outra (segundos).
@export var hide_time_min := 1.2
@export var hide_time_max := 3.0
## Disparos por saída da cobertura.
@export var shots_per_peek_min := 1
@export var shots_per_peek_max := 2
