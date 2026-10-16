class_name EnemySoldier
extends CharacterBody3D
## Soldado inimigo: corpo, movimento, tiro, dano e morte.
## As decisões (quando se esconder, atirar, procurar) ficam no `Brain`.
##
## Estrutura esperada (ver enemy_soldier.tscn):
##   Collision, Health, Brain, Perception, NavAgent, Visual (com Upper/HeadHitbox e
##   Upper/RiflePivot/Muzzle).

signal died

const BULLET_IMPACT := preload("res://systems/fx/bullet_impact.tscn")
const MUZZLE_SMOKE := preload("res://systems/fx/muzzle_smoke.tscn")
const BODY_FALL := preload("res://assets/audio/provisorio/queda_corpo.wav")
const BLOOD_POOL := preload("res://systems/fx/blood_pool.tscn")

## Camadas que os tiros do inimigo atingem: mundo (1) e jogador (2).
const SHOT_MASK := 0b11
const STAND_HEIGHT := 1.45
const CROUCH_HEIGHT := 0.95

@export var data: EnemyData
## Evento narrativo emitido ao morrer (ex.: "mg_morta" para o objetivo da metralhadora).
@export var death_event := ""
## Passados ao cérebro (SoldierBrain): avança em vez de se cobrir; granadas de haste.
@export var aggressive := false
@export var grenades := 0

var is_dead := false
var is_crouched := false

var _move_speed := 0.0
var _moving := false
var _face_point: Variant = null
var _last_hit_direction := Vector3.FORWARD
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var health: Health = $Health
## Cérebro (SoldierBrain, MgGunnerBrain...): precisa de setup, on_hit, on_ally_contact, on_died.
@onready var brain: Node = $Brain
@onready var perception: Perception = $Perception
@onready var visual: Node3D = $Visual
@onready var _nav: NavigationAgent3D = $NavAgent
@onready var _collision: CollisionShape3D = $Collision
@onready var _capsule: CapsuleShape3D = _collision.shape
var _head: CollisionObject3D


func _ready() -> void:
	add_to_group(&"enemies")
	# Visual animado expõe cabeça e olhos; o provisório usa nós fixos.
	if visual.get(&"head_hitbox") != null:
		_head = visual.head_hitbox
		perception.eyes = visual.eyes
	else:
		_head = $Visual/Upper/HeadHitbox
	_capsule = _capsule.duplicate()  # cada soldado agacha a própria cápsula
	_collision.shape = _capsule
	health.max_health = data.max_health
	health.current = data.max_health
	health.died.connect(_on_died)
	add_collision_exception_with(_head)
	perception.setup(data, [get_rid(), _head.get_rid()])
	if brain is SoldierBrain:
		brain.aggressive = aggressive
		brain.grenades = grenades
	brain.setup(self)


# --- Movimento -------------------------------------------------------------------

func move_to(point: Vector3, speed: float) -> void:
	_nav.target_position = point
	_move_speed = speed
	_moving = true


func stop() -> void:
	_moving = false


func has_arrived() -> bool:
	if not _moving:
		return true
	var flat := _nav.target_position - global_position
	flat.y = 0.0
	return flat.length() < 0.7 or _nav.is_navigation_finished()


## Olhar para um ponto (null = olhar para onde anda).
func face(point: Variant) -> void:
	_face_point = point


func set_aiming(value: bool) -> void:
	visual.set_aiming(value)


func set_crouched(value: bool) -> void:
	if value == is_crouched:
		return
	is_crouched = value
	visual.set_crouched(value)
	_capsule.height = CROUCH_HEIGHT if value else STAND_HEIGHT
	_collision.position.y = _capsule.height * 0.5


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var horizontal := Vector3.ZERO
	if _moving and not is_dead and not has_arrived():
		var next := _nav.get_next_path_position()
		var dir := next - global_position
		dir.y = 0.0
		if dir.length() > 0.05:
			horizontal = dir.normalized() * _move_speed
	elif _moving and has_arrived():
		_moving = false
	velocity.x = lerpf(velocity.x, horizontal.x, 1.0 - exp(-10.0 * delta))
	velocity.z = lerpf(velocity.z, horizontal.z, 1.0 - exp(-10.0 * delta))
	move_and_slide()

	if not is_dead:
		_update_facing(delta, horizontal)
		if visual.has_method(&"set_move_velocity"):
			var local := global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
			visual.set_move_velocity(Vector2(local.x, -local.z))
		elif visual.has_method(&"set_move_speed"):
			visual.set_move_speed(Vector2(velocity.x, velocity.z).length())


func _update_facing(delta: float, moving_dir: Vector3) -> void:
	var look := Vector3.ZERO
	if _face_point != null:
		look = (_face_point as Vector3) - global_position
	# Correndo, ou se deslocando para longe da direção do alvo sem mirar: olha para onde
	# vai. Mirando, anda de lado ou de costas (animações direcionais) olhando o alvo.
	var flat_move := Vector2(moving_dir.x, moving_dir.z)
	var flat_look := Vector2(look.x, look.z)
	if flat_move.length() > 0.1 and (look == Vector3.ZERO or flat_move.length() > data.walk_speed * 1.3 \
			or (absf(flat_move.angle_to(flat_look)) > deg_to_rad(65.0) and not visual.is_aiming())):
		look = moving_dir
	look.y = 0.0
	if look.length() < 0.05:
		return
	var target_yaw := atan2(-look.x, -look.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-data.turn_speed * delta))
	if _face_point != null:
		var to := (_face_point as Vector3) - perception.eyes_position()
		visual.set_aim_pitch(atan2(to.y, Vector2(to.x, to.z).length()))


## Está virado (quase) para o ponto? Evita atirar de costas.
func is_facing(point: Vector3, tolerance_degrees := 20.0) -> bool:
	var to := point - global_position
	to.y = 0.0
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.angle_to(to) < deg_to_rad(tolerance_degrees)


# --- Tiro ------------------------------------------------------------------------

## Dispara contra o alvo. `aim_time`: há quanto tempo mira continuamente
## (quanto mais tempo, mais preciso).
func fire_at(target: PlayerController, aim_time: float) -> void:
	var eyes := perception.eyes_position()
	var aim_point := target.global_position + Vector3.UP * (0.8 if target.is_crouching else 1.3)
	var distance := eyes.distance_to(aim_point)

	var error := data.spread_at_10m * maxf(distance, 4.0) / 10.0
	error *= lerpf(1.5, 0.55, clampf(aim_time / data.aim_settle_time, 0.0, 1.0))
	var target_speed := Vector2(target.velocity.x, target.velocity.z).length()
	error *= lerpf(1.0, data.moving_target_penalty, clampf(target_speed / 5.8, 0.0, 1.0))

	var to := (aim_point - eyes).normalized()
	var side := to.cross(Vector3.UP).normalized()
	var up := side.cross(to)
	var angle := randf() * TAU
	var point := aim_point + (side * cos(angle) + up * sin(angle)) * error * sqrt(randf())
	var direction := (point - eyes).normalized()
	var end := eyes + direction * data.max_range

	var query := PhysicsRayQueryParameters3D.create(eyes, end, SHOT_MASK, [get_rid(), _head.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_player := false
	if not hit.is_empty():
		end = hit.position
		var info := HitInfo.new()
		info.damage = data.damage
		info.position = hit.position
		info.normal = hit.normal
		info.direction = direction
		info.impulse = 5.0
		info.source = self
		var collider: Object = hit.collider
		hit_player = collider == target
		if collider.has_method(&"apply_hit"):
			collider.apply_hit(info)
		if not hit_player:
			var impact := BULLET_IMPACT.instantiate()
			_fx_parent().add_child(impact)
			impact.setup(hit.position, hit.normal, collider.get_meta(&"surface", &"areia"))

	if not hit_player:
		NearMiss.check(_fx_parent(), eyes, end, target)
	_play_fire_effects()


func _play_fire_effects() -> void:
	visual.muzzle_flash()
	var smoke := MUZZLE_SMOKE.instantiate()
	_fx_parent().add_child(smoke)
	smoke.global_transform = visual.muzzle.global_transform
	OneShotSound.play(_fx_parent(), data.sound_fire, visual.muzzle.global_position, 2.0, 25.0)


## Efeitos soltos (impactos, fumaça, sons) vão para a raiz da fase.
func _fx_parent() -> Node:
	var scene := get_tree().current_scene
	return scene if scene else get_parent()


# --- Dano e morte ----------------------------------------------------------------

## Tiro no corpo (a cápsula principal).
func apply_hit(hit: HitInfo) -> void:
	receive_hit(hit, false)


func receive_hit(hit: HitInfo, headshot: bool) -> void:
	if is_dead:
		return
	_last_hit_direction = hit.direction
	health.take_damage(hit.damage * (data.headshot_multiplier if headshot else 1.0), hit)
	if not is_dead:
		visual.flinch(global_basis.inverse() * hit.direction)
		brain.on_hit(hit)


func _on_died() -> void:
	is_dead = true
	_moving = false
	brain.on_died()
	collision_layer = 0
	_head.collision_layer = 0
	visual.die(global_basis.inverse() * _last_hit_direction)
	get_tree().create_timer(0.5).timeout.connect(
		func() -> void: OneShotSound.play(_fx_parent(), BODY_FALL, global_position, -2.0, 8.0))
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		var pool := BLOOD_POOL.instantiate()
		_fx_parent().add_child(pool)
		pool.global_position = global_position + global_basis.z * 0.6 + Vector3.UP * 0.2)
	died.emit()
	EventBus.enemy_killed.emit(self)
	if not death_event.is_empty():
		EventBus.narrative_event.emit(death_event)
