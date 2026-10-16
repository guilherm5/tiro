class_name AllyNpc
extends CharacterBody3D
## Aliado roteirizado (ex.: Miller). Não tem IA de combate de verdade: corre até os
## pontos que o script da missão manda (`mover MILLER ponto`), abaixa ao chegar e
## atira na direção do inimigo vivo mais próximo — para a cena ter vida. É invulnerável
## e não acerta ninguém (o combate é do jogador).

@export var ally_id := "MILLER"
@export var run_speed := 4.6
@export var fire_interval_min := 1.8
@export var fire_interval_max := 3.5
@export var engage_range := 90.0
@export var sound_fire: AudioStream
## Não atira (ex.: socorrista, soldados no barco durante a cutscene).
@export var passive := false
## Começa abaixado (sentado no barco, ajoelhado).
@export var start_crouched := false
## Deitado no chão (ferido). Não se move nem atira.
@export var lying := false

var current_target: Node3D:
	get:
		return _target

var _target: Node3D
var _moving := false
var _fire_timer := 2.0
var _active := true
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _nav: NavigationAgent3D = $NavAgent
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"aliados")
	EventBus.mission_completed.connect(func(_t: String) -> void: _active = false)
	_visual.set_crouched(start_crouched)
	if lying:
		passive = true
		if _visual.has_method(&"lie_down"):
			_visual.lie_down()
		else:
			_visual.rotation = Vector3(deg_to_rad(-88.0), 0.0, 0.0)
			_visual.position.y = 0.2
		set_physics_process(false)


## Coloca o aliado direto no ponto (antes de cutscenes, ao carregar checkpoint).
func teleport_to(point: Node3D) -> void:
	_target = point
	global_position = point.global_position
	_moving = false
	_arrive()


func go_to(point: Node3D) -> void:
	_target = point
	_nav.target_position = point.global_position
	_moving = true
	_visual.set_crouched(false)
	_visual.set_aiming(false)


func _physics_process(delta: float) -> void:
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	var horizontal := Vector3.ZERO
	if _moving:
		var flat := _nav.target_position - global_position
		flat.y = 0.0
		if flat.length() < 0.8 or _nav.is_navigation_finished():
			_arrive()
		else:
			var dir := _nav.get_next_path_position() - global_position
			dir.y = 0.0
			if dir.length() > 0.05:
				horizontal = dir.normalized() * run_speed
				_face(dir, delta)
	velocity.x = lerpf(velocity.x, horizontal.x, 1.0 - exp(-10.0 * delta))
	velocity.z = lerpf(velocity.z, horizontal.z, 1.0 - exp(-10.0 * delta))
	move_and_slide()
	if _visual.has_method(&"set_move_speed"):
		_visual.set_move_speed(Vector2(velocity.x, velocity.z).length())
	if not _moving:
		_update_combat(delta)


func _arrive() -> void:
	_moving = false
	_visual.set_crouched(_target == null or not _target.get_meta(&"em_pe", false))
	if _target:
		var forward := -_target.global_basis.z
		rotation.y = atan2(-forward.x, -forward.z)


func _update_combat(delta: float) -> void:
	var enemy: Node3D = null if passive else _nearest_enemy()
	if enemy == null or not _active or Cutscenes.is_playing:
		_visual.set_aiming(false)
		return
	var to := enemy.global_position - global_position
	_face(to, delta)
	_fire_timer -= delta
	# Levanta para atirar e volta a se abaixar.
	var peeking := _fire_timer < 0.6
	_visual.set_crouched(not peeking)
	_visual.set_aiming(peeking)
	_visual.set_aim_pitch(atan2(to.y, Vector2(to.x, to.z).length()))
	if _fire_timer <= 0.0:
		_fire_timer = randf_range(fire_interval_min, fire_interval_max)
		_visual.muzzle_flash()
		OneShotSound.play(get_parent(), sound_fire, _visual.muzzle.global_position, -2.0, 15.0)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance := engage_range
	for node in get_tree().get_nodes_in_group(&"enemies"):
		if node.is_dead:
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_distance:
			best_distance = d
			best = node
	return best


func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-8.0 * delta))
