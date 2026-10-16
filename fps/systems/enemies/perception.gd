class_name Perception
extends Node
## Visão e audição de um inimigo.
##
## A visão não é instantânea: enquanto o jogador está visível, a "consciência"
## (`awareness`, 0..1) sobe — mais rápido de perto, correndo ou se o inimigo já
## está alerta; mais devagar de longe ou agachado. Em 1, o inimigo reconhece o alvo.

signal heard_noise(position: Vector3)

## Ponto dos olhos (acompanha o agachar).
@export var eyes: Node3D
## Intervalo entre checagens de linha de visão (economiza processamento).
@export var check_interval := 0.1

var data: EnemyData
var target: PlayerController
var awareness := 0.0
## Vendo o alvo agora (e já o reconheceu).
var can_see_target := false
var last_known_position := Vector3.ZERO
var time_since_seen := INF

var _visible_raw := false
var _check_timer := 0.0
var _exclude: Array[RID] = []


func setup(enemy_data: EnemyData, exclude: Array[RID]) -> void:
	data = enemy_data
	_exclude = exclude
	EventBus.noise_emitted.connect(_on_noise)


func eyes_position() -> Vector3:
	return eyes.global_position


func update(delta: float, alerted: bool) -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as PlayerController
	if target == null or target.is_dead or target.is_cinematic:
		can_see_target = false
		_visible_raw = false
		return

	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = check_interval
		_visible_raw = _check_line_of_sight(alerted)

	if _visible_raw:
		var distance := eyes_position().distance_to(target.global_position)
		var rate := 1.0 / (data.notice_time * maxf(distance / 10.0, 0.5))
		if target.is_crouching:
			rate *= 0.6
		if target.is_sprinting:
			rate *= 1.3
		if alerted:
			rate *= 3.0
		awareness = minf(awareness + rate * delta, 1.0)
		last_known_position = target.global_position
		time_since_seen = 0.0
	else:
		time_since_seen += delta
		if not alerted:
			awareness = maxf(awareness - 0.15 * delta, 0.0)

	can_see_target = _visible_raw and awareness >= 1.0


## Alvo dentro do alcance, do cone de visão e sem nada no caminho?
func _check_line_of_sight(alerted: bool) -> bool:
	var from := eyes_position()
	var head := target.camera.global_position
	if from.distance_to(head) > data.sight_range:
		return false
	var forward := -eyes.global_basis.z
	forward.y = 0.0
	var to_target := head - from
	to_target.y = 0.0
	# Já alerta, o inimigo olha em volta: cone bem mais aberto.
	var half_fov := deg_to_rad(data.sight_fov_degrees * (1.6 if alerted else 1.0)) * 0.5
	if forward.length() > 0.01 and forward.angle_to(to_target) > half_fov:
		return false
	var chest := target.global_position + Vector3.UP * (0.7 if target.is_crouching else 1.2)
	return _clear(from, head) or _clear(from, chest)


func _clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, _exclude)
	return eyes.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_noise(position: Vector3, radius: float, source: Node) -> void:
	if source == null or not source.is_in_group(&"player"):
		return
	if eyes_position().distance_to(position) <= minf(radius, data.hearing_range):
		heard_noise.emit(position)
