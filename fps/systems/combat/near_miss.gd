class_name NearMiss
extends RefCounted
## Balas inimigas que passam perto do jogador: zumbido no ponto mais próximo e
## supressão proporcional à distância. Usado por todos os atiradores inimigos.

const WHIZ := preload("res://assets/audio/provisorio/bala_passando.wav")
## Distância (m) da cabeça em que a bala ainda assusta.
const RADIUS := 3.0
## Intervalo mínimo entre zumbidos (rajadas não viram um ruído contínuo).
const WHIZ_INTERVAL_MS := 90

static var _last_whiz_ms := 0


## `from`→`to`: trajeto da bala (termina no impacto, se houve).
static func check(parent: Node, from: Vector3, to: Vector3, target: PlayerController) -> void:
	if target == null or target.is_dead:
		return
	var head := target.camera.global_position
	var closest := Geometry3D.get_closest_point_to_segment(head, from, to)
	var distance := closest.distance_to(head)
	if distance > RADIUS:
		return
	target.suppress(lerpf(0.12, 0.03, distance / RADIUS))
	var now := Time.get_ticks_msec()
	if distance < 2.5 and now - _last_whiz_ms > WHIZ_INTERVAL_MS:
		_last_whiz_ms = now
		OneShotSound.play(parent, WHIZ, closest, 0.0, 3.0, 0.15)
