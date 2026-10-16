class_name WeaponData
extends Resource
## Parâmetros de uma arma. Uma arma nova = um .tres em data/weapons/ + uma cena de modelo.

@export var display_name := "Arma"

@export_group("Disparo")
@export var damage := 100.0
@export var max_range := 300.0
## Intervalo mínimo entre disparos (segundos).
@export var min_shot_interval := 0.12
## Automática dispara enquanto o gatilho estiver pressionado.
@export var automatic := false
## Empurrão aplicado a objetos físicos atingidos.
@export var impact_impulse := 6.0
## Distância em que inimigos ouvem o disparo.
@export var noise_radius := 70.0

@export_group("Munição")
@export var magazine_size := 8
@export var starting_reserve := 48
@export var reload_time := 2.2
## M1 Garand: o pente é ejetado (com o "ping") ao disparar o último cartucho.
@export var ejects_clip_when_empty := false

@export_group("Precisão (graus)")
@export var spread_hip := 1.6
@export var spread_aim := 0.12
## Dispersão extra andando (multiplicada pela velocidade relativa).
@export var spread_moving := 1.8
## Abertura somada a cada disparo; volta em `spread_recovery` graus/s.
@export var spread_per_shot := 0.9
@export var spread_recovery := 4.0

@export_group("Recuo")
## Quanto a mira realmente sobe — o jogador precisa compensar.
@export var aim_kick_pitch := 1.1
@export var aim_kick_yaw := 0.35
## Solavanco visual da câmera (volta sozinho).
@export var view_kick_pitch := 3.0
@export var view_kick_roll := 1.2
## Tremor da câmera por disparo (0..1).
@export var camera_trauma := 0.22
## Recuo do modelo da arma.
@export var model_kick_back := 0.07
@export var model_kick_rotation_degrees := 7.0

@export_group("Mira")
@export var aim_fov := 52.0
@export var aim_time := 0.22
@export var aim_sensitivity_multiplier := 0.7
@export var aim_move_multiplier := 0.65

@export_group("Sons")
@export var sound_fire: AudioStream
@export var sound_dry: AudioStream
@export var sound_reload_insert: AudioStream
@export var sound_reload_end: AudioStream
@export var sound_clip_eject: AudioStream
