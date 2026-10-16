class_name MgGunnerBrain
extends Node
## Metralhador de posição fixa (MG42 no bunker). Usa o mesmo corpo do soldado
## (EnemySoldier), mas não anda: gira a metralhadora com velocidade limitada.
##
##   SWEEP    — varre a praia devagar procurando alvos.
##   ENGAGE   — vê o jogador: rajadas na direção da arma (que persegue o alvo com atraso).
##   SUPPRESS — perdeu o jogador de vista: metralha a última posição (a cobertura dele).
##   RELOAD   — depois de algumas rajadas troca o cano/fita: silêncio de alguns segundos.
##   DEAD
##
## O atraso no giro e as pausas são o que torna possível atravessar a praia.

signal state_changed(state: State)
## Começou/terminou a troca de cano (para falas como "Ele está recarregando!").
signal reloading_changed(is_reloading: bool)

enum State { SWEEP, ENGAGE, SUPPRESS, RELOAD, DEAD }

@export_group("Metralhadora")
@export var rounds_per_second := 20.0
@export var damage := 18.0
## Dispersão do cano (graus).
@export var spread_degrees := 1.3
## Velocidade máxima de giro (graus/s). Mais baixo = mais fácil escapar correndo.
@export var traverse_degrees_per_second := 28.0
@export var max_range := 250.0
@export var tracer_every := 3
@export_group("Ritmo")
@export var burst_min := 0.9
@export var burst_max := 2.0
@export var pause_min := 0.5
@export var pause_max := 1.1
@export var bursts_before_reload_min := 4
@export var bursts_before_reload_max := 6
@export var reload_time := 4.5
## Por quanto tempo metralha a última posição depois de perder o alvo de vista.
@export var suppress_time := 3.5
@export_group("Varredura")
@export var sweep_half_angle_degrees := 35.0
@export var sweep_period := 10.0
@export var sweep_distance := 45.0
@export_group("Sons")
@export var sound_shot: AudioStream
@export var sound_tail: AudioStream

const SHOT_MASK := 0b11
const BULLET_IMPACT := preload("res://systems/fx/bullet_impact.tscn")
const TRACER := preload("res://systems/fx/tracer.tscn")

var state := State.SWEEP
var body: EnemySoldier
var perception: Perception
var gun: Node3D
var muzzle: Node3D

var _aim_dir := Vector3.FORWARD
var _home_dir := Vector3.FORWARD
var _time := 0.0
var _burst_left := 0.0
var _pause_left := 0.0
var _shot_cooldown := 0.0
var _shot_count := 0
var _bursts_left := 0
var _state_time := 0.0
var _flinch_pause := 0.0
var _alerted := false

@onready var _audio: AudioStreamPlayer3D = $"../MG42/Audio"
@onready var _flash: Node3D = $"../MG42/Muzzle/Flash"
@onready var _flash_light: OmniLight3D = $"../MG42/Muzzle/Light"


func setup(soldier: EnemySoldier) -> void:
	body = soldier
	perception = soldier.perception
	gun = soldier.get_node(^"MG42")
	muzzle = gun.get_node(^"Muzzle")
	_home_dir = -soldier.global_basis.z
	_aim_dir = _home_dir
	perception.heard_noise.connect(func(_p: Vector3) -> void: _alerted = true)
	_bursts_left = randi_range(bursts_before_reload_min, bursts_before_reload_max)
	body.set_aiming(true)
	_flash.hide()
	_flash_light.hide()


func on_hit(_hit: HitInfo) -> void:
	_alerted = true
	_flinch_pause = 0.8


func on_ally_contact(position: Vector3) -> void:
	_alerted = true
	if state == State.SWEEP:
		perception.last_known_position = position
		_set_state(State.SUPPRESS)


func on_died() -> void:
	_set_state(State.DEAD)
	_flash.hide()
	_flash_light.hide()


func _physics_process(delta: float) -> void:
	if body == null or state == State.DEAD:
		return
	_time += delta
	_state_time += delta
	_flinch_pause = maxf(_flinch_pause - delta, 0.0)
	perception.update(delta, _alerted)
	if perception.can_see_target:
		_alerted = true

	_update_state()
	_slew_toward(_desired_point(), delta)
	if state in [State.ENGAGE, State.SUPPRESS]:
		_update_firing(delta)


func _update_state() -> void:
	match state:
		State.SWEEP:
			if perception.can_see_target:
				_set_state(State.ENGAGE)
		State.ENGAGE:
			if not perception.can_see_target:
				_set_state(State.SUPPRESS)
		State.SUPPRESS:
			if perception.can_see_target:
				_set_state(State.ENGAGE)
			elif _state_time > suppress_time:
				_set_state(State.SWEEP)
		State.RELOAD:
			if _state_time > reload_time:
				_bursts_left = randi_range(bursts_before_reload_min, bursts_before_reload_max)
				reloading_changed.emit(false)
				_set_state(State.ENGAGE if perception.can_see_target else State.SWEEP)


func _desired_point() -> Vector3:
	var target := perception.target
	match state:
		State.ENGAGE:
			return target.global_position + Vector3.UP * (0.7 if target.is_crouching else 1.2)
		State.SUPPRESS, State.RELOAD:
			# Metralha a última posição com uma variação (rasga a cobertura).
			var jitter := Vector3(sin(_time * 3.1), sin(_time * 4.7) * 0.4 + 0.3, cos(_time * 2.3)) * 1.2
			return perception.last_known_position + Vector3.UP * 0.8 + jitter
	var angle := deg_to_rad(sweep_half_angle_degrees) * sin(_time * TAU / sweep_period)
	var dir := _home_dir.rotated(Vector3.UP, angle)
	return muzzle.global_position + dir * sweep_distance + Vector3.DOWN * 3.0


## Gira a arma em direção ao ponto, limitado pela velocidade de giro.
func _slew_toward(point: Vector3, delta: float) -> void:
	var wanted := (point - muzzle.global_position).normalized()
	var max_step := deg_to_rad(traverse_degrees_per_second) * delta
	var angle := _aim_dir.angle_to(wanted)
	if angle > 0.0001:
		_aim_dir = _aim_dir.slerp(wanted, minf(1.0, max_step / angle)).normalized()
	body.face(body.global_position + Vector3(_aim_dir.x, 0.0, _aim_dir.z) * 20.0)
	var pitch := asin(clampf(_aim_dir.y, -1.0, 1.0))
	gun.rotation.x = pitch
	body.visual.set_aim_pitch(pitch)


func _update_firing(delta: float) -> void:
	_shot_cooldown -= delta
	if _flinch_pause > 0.0:
		return
	if _burst_left > 0.0:
		_burst_left -= delta
		while _shot_cooldown <= 0.0:
			_shot_cooldown += 1.0 / rounds_per_second
			_fire_one()
		if _burst_left <= 0.0:
			_end_burst()
	else:
		_pause_left -= delta
		_flash.hide()
		_flash_light.hide()
		if _pause_left <= 0.0:
			_burst_left = randf_range(burst_min, burst_max)
			_shot_cooldown = 0.0


func _end_burst() -> void:
	_pause_left = randf_range(pause_min, pause_max)
	_flash.hide()
	_flash_light.hide()
	OneShotSound.play(_fx_parent(), sound_tail, muzzle.global_position, -4.0, 30.0)
	_bursts_left -= 1
	if _bursts_left <= 0:
		reloading_changed.emit(true)
		EventBus.narrative_event.emit("mg_recarregando")
		_set_state(State.RELOAD)


func _fire_one() -> void:
	var from := muzzle.global_position
	var axis := _aim_dir.cross(Vector3.UP).normalized()
	var dir := _aim_dir.rotated(axis, deg_to_rad(spread_degrees) * sqrt(randf()))
	dir = dir.rotated(_aim_dir, randf() * TAU).normalized()
	var to := from + dir * max_range

	var query := PhysicsRayQueryParameters3D.create(from, to, SHOT_MASK, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	var target := perception.target
	var hit_player := false
	if not hit.is_empty():
		to = hit.position
		var collider: Object = hit.collider
		hit_player = collider == target
		if collider.has_method(&"apply_hit"):
			var info := HitInfo.new()
			info.damage = damage
			info.position = hit.position
			info.normal = hit.normal
			info.direction = dir
			info.impulse = 4.0
			info.source = body
			collider.apply_hit(info)
		if not hit_player:
			var impact := BULLET_IMPACT.instantiate()
			_fx_parent().add_child(impact)
			impact.setup(hit.position, hit.normal, collider.get_meta(&"surface", &"areia"))
	if not hit_player:
		NearMiss.check(_fx_parent(), from, to, target)

	_shot_count += 1
	if _shot_count % tracer_every == 0:
		var tracer := TRACER.instantiate()
		_fx_parent().add_child(tracer)
		tracer.launch(from, to)

	_audio.play()
	_flash.visible = not _flash.visible or randf() < 0.5
	_flash.scale = Vector3.ONE * randf_range(0.7, 1.3)
	_flash_light.visible = true


func _fx_parent() -> Node:
	var scene := get_tree().current_scene
	return scene if scene else body.get_parent()


func _set_state(value: State) -> void:
	if state == value:
		return
	state = value
	_state_time = 0.0
	if state != State.ENGAGE and state != State.SUPPRESS:
		_burst_left = 0.0
	state_changed.emit(state)
