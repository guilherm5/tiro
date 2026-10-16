class_name PlayerController
extends CharacterBody3D
## Movimento em primeira pessoa: olhar, andar, correr, agachar e pular.
##
## Hierarquia esperada (ver player.tscn):
##   Player (este nó) — gira no eixo Y (olhar para os lados)
##   ├─ Collision     — cápsula; altura muda ao agachar
##   └─ Head          — gira no eixo X (olhar para cima/baixo); altura dos olhos
##      └─ CameraRig  — deslocamentos de câmera (balanço de passo; depois recuo e tremor)
##         └─ Camera
##
## O controlador não toca sons nem efeitos: ele emite `footstep`, e outros sistemas reagem.

## Emitido a cada passada no chão. Usado pelo sistema de áudio (passos) a partir da etapa 2.
signal footstep(is_sprinting: bool)

@export_group("Movimento")
@export var walk_speed := 3.6
@export var sprint_speed := 5.8
@export var crouch_speed := 1.8
## Quão rápido a velocidade alcança o alvo no chão (maior = mais responsivo).
@export var ground_acceleration := 11.0
## Controle no ar; baixo para o pulo ter peso.
@export var air_acceleration := 1.5
@export var jump_velocity := 4.0

@export_group("Olhar")
@export var mouse_sensitivity := 0.0022
@export_range(10.0, 89.0) var max_pitch_degrees := 85.0
## Fração do recuo da arma que a mira recupera sozinha depois do disparo.
@export_range(0.0, 1.0) var recoil_recovery := 0.6
@export var recoil_recovery_speed := 5.0

@export_group("Agachar")
@export var stand_height := 1.8
@export var crouch_height := 1.15
## Distância do topo da cápsula até os olhos.
@export var eye_offset := 0.14
@export var crouch_transition_speed := 10.0

@export_group("Balanço da câmera")
## Passadas por metro percorrido.
@export var steps_per_meter := 0.55
@export var bob_vertical := 0.035
@export var bob_horizontal := 0.022
@export var sprint_bob_multiplier := 1.6

var is_crouching := false
var is_sprinting := false
var is_dead := false
## Em cutscene: sem controle, sem arma na tela, invisível para os inimigos.
var is_cinematic := false
## Ajustados pela arma ao mirar (sensibilidade menor, passo mais lento).
var look_sensitivity_multiplier := 1.0
var speed_multiplier := 1.0
## Lentidão na água (calculada pelos passos; 1 = sem água).
var wade_multiplier := 1.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_height := 0.0
var _step_phase := 0.0
var _bob_weight := 0.0
## Recuo pendente (pitch, yaw) em radianos, aplicado ao longo de alguns quadros.
var _was_on_floor := true
var _fall_speed := 0.0
var _strafe_roll := 0.0
var _pending_kick := Vector2.ZERO
## Parte do recuo que ainda vai voltar (pitch, yaw), em radianos.
var _pending_recovery := Vector2.ZERO

@onready var _collision: CollisionShape3D = $Collision
@onready var _capsule: CapsuleShape3D = _collision.shape
@onready var _head: Node3D = $Head
@onready var _camera_rig: Node3D = $Head/CameraRig
@onready var health: Health = $Health
@onready var suppression: Suppression = $Suppression
@onready var camera: CameraEffects = $Head/CameraRig/Camera


func _ready() -> void:
	add_to_group(&"player")
	health.died.connect(_on_died)
	_current_height = stand_height
	_apply_height()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Bala passou perto (ver NearMiss): aumenta a supressão.
func suppress(amount: float) -> void:
	if not is_dead:
		suppression.add(amount)


## Chamado por tiros e estilhaços (ver HitInfo).
func apply_hit(hit: HitInfo) -> void:
	health.take_damage(hit.damage, hit)


func set_cinematic(value: bool) -> void:
	is_cinematic = value
	velocity = Vector3.ZERO
	is_sprinting = false
	var holder := $Head/CameraRig/Camera/WeaponHolder
	holder.visible = not value
	holder.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	$ViewmodelLayer.visible = not value


func _on_died() -> void:
	is_dead = true
	is_sprinting = false
	velocity = Vector3(0.0, velocity.y, 0.0)
	$Head/CameraRig/Camera/WeaponHolder.hide()
	$Head/CameraRig/Camera/WeaponHolder.process_mode = Node.PROCESS_MODE_DISABLED
	# Queda: a câmera desce até o chão e tomba de lado.
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_head, ^"position:y", 0.25, 0.9)
	tween.tween_property(_head, ^"rotation:z", deg_to_rad(75.0), 0.9)
	tween.tween_property(_head, ^"rotation:x", deg_to_rad(-10.0), 0.9)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or is_cinematic:
		return
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := mouse_sensitivity * Settings.mouse_sensitivity * look_sensitivity_multiplier
		var vertical: float = event.relative.y * (-1.0 if Settings.invert_y else 1.0)
		_rotate_view(-event.relative.x * sensitivity, -vertical * sensitivity)


## Recuo da arma: a mira sobe de verdade e o jogador precisa compensar.
func add_aim_kick(pitch_degrees: float, yaw_degrees: float) -> void:
	var kick := Vector2(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees))
	_pending_kick += kick
	_pending_recovery += kick * recoil_recovery


func _process(delta: float) -> void:
	if not _pending_kick.is_zero_approx():
		var step := _pending_kick * (1.0 - exp(-30.0 * delta))
		_pending_kick -= step
		_rotate_view(step.y, step.x)
	elif not _pending_recovery.is_zero_approx():
		# Só recupera depois que o solavanco terminou.
		var back := _pending_recovery * (1.0 - exp(-recoil_recovery_speed * delta))
		_pending_recovery -= back
		_rotate_view(-back.y, -back.x)


func _rotate_view(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	_head.rotation.x = clampf(_head.rotation.x + pitch,
		-deg_to_rad(max_pitch_degrees), deg_to_rad(max_pitch_degrees))


func _physics_process(delta: float) -> void:
	if is_dead or is_cinematic:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		return
	_update_crouch(delta)

	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# Só corre andando para frente, em pé e no chão.
	is_sprinting = Input.is_action_pressed(&"sprint") and input_dir.y < -0.5 \
			and not is_crouching and is_on_floor()

	var target_speed := walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed
	target_speed *= speed_multiplier * wade_multiplier

	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.lerp(wish_dir * target_speed, 1.0 - exp(-accel * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(&"jump") and not is_crouching:
		velocity.y = jump_velocity

	if not is_on_floor():
		_fall_speed = maxf(_fall_speed, -velocity.y)
	move_and_slide()
	_update_landing()
	_update_head_bob(delta)
	# Inclinação leve ao andar de lado (sensação de peso).
	_strafe_roll = lerpf(_strafe_roll, -input_dir.x * deg_to_rad(1.2), 1.0 - exp(-6.0 * delta))
	_camera_rig.rotation.z = _strafe_roll


func _update_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _fall_speed > 3.0:
		var impact := clampf((_fall_speed - 3.0) / 5.0, 0.2, 1.0)
		camera.kick(Vector3(-3.0 * impact, 0.0, randf_range(-1.0, 1.0) * impact))
		footstep.emit(true)
	if on_floor:
		_fall_speed = 0.0
	_was_on_floor = on_floor


func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed(&"crouch")
	# Não levanta se houver algo acima (ex.: embaixo de um obstáculo).
	if is_crouching and not wants_crouch and not _can_stand():
		wants_crouch = true
	is_crouching = wants_crouch

	var target := crouch_height if is_crouching else stand_height
	_current_height = lerpf(_current_height, target, 1.0 - exp(-crouch_transition_speed * delta))
	_apply_height()


func _apply_height() -> void:
	_capsule.height = _current_height
	_collision.position.y = _current_height * 0.5
	_head.position.y = _current_height - eye_offset


func _can_stand() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = _capsule.radius
	shape.height = stand_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# Levemente acima do chão para não colidir com o próprio piso.
	query.transform = global_transform.translated(Vector3.UP * (stand_height * 0.5 + 0.05))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_head_bob(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and speed > 0.5
	_bob_weight = lerpf(_bob_weight, 1.0 if moving else 0.0, 1.0 - exp(-8.0 * delta))

	if moving:
		var previous_phase := _step_phase
		_step_phase += speed * steps_per_meter * delta * TAU * 0.5
		# Uma passada a cada meio ciclo (pé esquerdo, pé direito).
		if floori(_step_phase / PI) != floori(previous_phase / PI):
			footstep.emit(is_sprinting)

	var amount := _bob_weight * (sprint_bob_multiplier if is_sprinting else 1.0)
	_camera_rig.position = Vector3(
		cos(_step_phase) * bob_horizontal * amount,
		-absf(sin(_step_phase)) * bob_vertical * amount,
		0.0)
