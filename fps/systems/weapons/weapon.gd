class_name Weapon
extends Node3D
## Arma em primeira pessoa com disparo instantâneo (hitscan).
##
## Recebe comandos do WeaponHolder (try_fire, start_reload, is_aiming). Os números
## vêm de `data` (WeaponData). A cena da arma precisa ter:
##   Model (Node3D)               — posicionado por este script (quadril/mira/corrida/recarga)
##   ├─ Muzzle (Marker3D)         — boca do cano; filhos Flash (MeshInstance3D) e FlashLight
##   └─ Ejection (Marker3D)       — janela de ejeção (cápsulas, pente)
##   FireAudio, MechAudio, PingAudio (AudioStreamPlayer)
##
## Tudo dentro de Model é desenhado na camada visual 2 (câmera própria da arma, ver
## viewmodel_camera.gd), então a arma nunca atravessa paredes.

signal fired
signal ammo_changed(in_magazine: int, reserve: int)
signal reload_started
signal reload_finished
## Acertou um inimigo (para o marcador de acerto do HUD).
signal hit_confirmed(killed: bool, headshot: bool)

const VIEWMODEL_LAYER := 2
const BULLET_IMPACT := preload("res://systems/fx/bullet_impact.tscn")
const MUZZLE_SMOKE := preload("res://systems/fx/muzzle_smoke.tscn")

@export var data: WeaponData
## Cena da cápsula ejetada a cada disparo e do pente ejetado vazio (opcionais).
@export var casing_scene: PackedScene
@export var clip_scene: PackedScene
## Clareia os materiais do modelo importado (texturas muito escuras sob a luz do jogo).
@export var model_brightness := 1.0

@export_group("Posições do modelo")
@export var hip_position := Vector3(0.17, -0.2, -0.32)
@export var hip_rotation_degrees := Vector3(0, 2.5, 0)
@export var aim_position := Vector3(0, -0.075, -0.17)
@export var sprint_position := Vector3(0.08, -0.26, -0.26)
@export var sprint_rotation_degrees := Vector3(-14, 38, 12)
@export var reload_position := Vector3(0.1, -0.3, -0.3)
@export var reload_rotation_degrees := Vector3(18, 12, 28)

@export_group("Movimento do modelo")
@export var sway_per_pixel := 0.0004
@export var sway_max := 0.05
@export var bob_amount := 0.012

var in_magazine := 0
var reserve := 0
var is_reloading := false
## Pedido de mira vindo do holder; a mira efetiva é `aim_blend`.
var is_aiming := false
## 0 = no quadril, 1 = mirando pelo aparelho de mira.
var aim_blend := 0.0
## Dispersão atual em graus (lida pela mira do HUD).
var current_spread := 0.0
## Preenchido pelo WeaponHolder ao equipar.
var holder: WeaponHolder

var _cooldown := 0.0
var _flash_time := 0.0
var _sprint_blend := 0.0
var _reload_blend := 0.0
var _bloom := 0.0
var _look_delta := Vector2.ZERO
var _sway := Vector2.ZERO
var _bob_time := 0.0
var _breath_time := 0.0
var _kick_position := Spring3.new(170.0, 17.0)
var _kick_rotation := Spring3.new(140.0, 15.0)
var _fire_stream: AudioStream

@onready var _model: Node3D = $Model
@onready var _muzzle: Node3D = $Model/Muzzle
@onready var _ejection: Node3D = $Model/Ejection
@onready var _flash: Node3D = $Model/Muzzle/Flash
@onready var _flash_light: OmniLight3D = $Model/Muzzle/FlashLight
@onready var _fire_audio: AudioStreamPlayer = $FireAudio
@onready var _mech_audio: AudioStreamPlayer = $MechAudio
@onready var _ping_audio: AudioStreamPlayer = $PingAudio


func _ready() -> void:
	_set_layer_recursive(_model)
	if not is_equal_approx(model_brightness, 1.0):
		_brighten(_model)
	_flash.visible = false
	_flash_light.visible = false
	_fire_audio.stream = _randomized(data.sound_fire, 1.04)
	reset_ammo()


func reset_ammo() -> void:
	in_magazine = data.magazine_size
	reserve = data.starting_reserve
	ammo_changed.emit(in_magazine, reserve)


func add_look_delta(relative: Vector2) -> void:
	_look_delta += relative


func can_fire() -> bool:
	return _cooldown <= 0.0 and not is_reloading and _sprint_blend < 0.3


func try_fire() -> bool:
	if not can_fire():
		return false
	if in_magazine <= 0:
		_play(_mech_audio, data.sound_dry)
		_cooldown = 0.25
		return false

	in_magazine -= 1
	_cooldown = data.min_shot_interval
	_shoot()
	_play_fire_effects()
	EventBus.noise_emitted.emit(holder.player.global_position, data.noise_radius, holder.player)
	_apply_recoil()
	if in_magazine == 0 and data.ejects_clip_when_empty:
		_eject_clip()
	ammo_changed.emit(in_magazine, reserve)
	fired.emit()
	return true


func start_reload() -> void:
	if is_reloading or reserve <= 0 or in_magazine >= data.magazine_size:
		return
	if data.ejects_clip_when_empty and in_magazine > 0:
		# Garand: o pente parcial é ejetado; os cartuchos voltam para a reserva.
		reserve += in_magazine
		in_magazine = 0
		_eject_clip()
		ammo_changed.emit(in_magazine, reserve)

	is_reloading = true
	reload_started.emit()
	var t := data.reload_time
	var tween := create_tween()
	tween.tween_property(self, ^"_reload_blend", 1.0, t * 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(t * 0.2)
	tween.tween_callback(_play.bind(_mech_audio, data.sound_reload_insert))
	tween.tween_callback(_kick_model.bind(Vector3(0, -0.02, 0), Vector3(-0.15, 0, 0)))
	tween.tween_interval(t * 0.35)
	tween.tween_callback(_play.bind(_mech_audio, data.sound_reload_end))
	tween.tween_callback(_kick_model.bind(Vector3(0, 0, 0.02), Vector3(0.1, 0, 0)))
	tween.tween_callback(_finish_reload)
	tween.tween_property(self, ^"_reload_blend", 0.0, t * 0.15).set_trans(Tween.TRANS_SINE)


func _finish_reload() -> void:
	var taken := mini(data.magazine_size - in_magazine, reserve)
	in_magazine += taken
	reserve -= taken
	is_reloading = false
	ammo_changed.emit(in_magazine, reserve)
	reload_finished.emit()


func _process(delta: float) -> void:
	if holder == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_flash(delta)

	var player := holder.player
	var sprinting := player.is_sprinting and not is_reloading
	_sprint_blend = move_toward(_sprint_blend, 1.0 if sprinting else 0.0, delta / 0.2)
	var wants_aim := is_aiming and not sprinting and not is_reloading
	aim_blend = move_toward(aim_blend, 1.0 if wants_aim else 0.0, delta / data.aim_time)

	_update_spread(delta, player)
	_update_model_pose(delta, player)


func _update_spread(delta: float, player: PlayerController) -> void:
	_bloom = move_toward(_bloom, 0.0, data.spread_recovery * delta)
	var spread := lerpf(data.spread_hip, data.spread_aim, aim_blend)
	var move_factor := clampf(Vector2(player.velocity.x, player.velocity.z).length() / player.walk_speed, 0.0, 1.6)
	spread += data.spread_moving * move_factor * lerpf(1.0, 0.4, aim_blend)
	if player.is_crouching:
		spread *= 0.7
	if not player.is_on_floor():
		spread += 4.0
	spread *= 1.0 + player.suppression.level * player.suppression.spread_penalty
	current_spread = spread + _bloom


func _update_model_pose(delta: float, player: PlayerController) -> void:
	var aim := smoothstep(0.0, 1.0, aim_blend)
	var sprint := smoothstep(0.0, 1.0, _sprint_blend)
	var reload := smoothstep(0.0, 1.0, _reload_blend)

	var pos := hip_position.lerp(aim_position, aim)
	var rot := hip_rotation_degrees.lerp(Vector3.ZERO, aim)
	pos = pos.lerp(sprint_position, sprint)
	rot = rot.lerp(sprint_rotation_degrees, sprint)
	pos = pos.lerp(reload_position, reload)
	rot = rot.lerp(reload_rotation_degrees, reload)

	# Balanço por movimento do mouse: a arma "atrasa" em relação ao olhar.
	var sway_target := (-_look_delta * sway_per_pixel).limit_length(sway_max) * lerpf(1.0, 0.3, aim)
	_look_delta = Vector2.ZERO
	_sway = _sway.lerp(sway_target, 1.0 - exp(-10.0 * delta))

	# Balanço de passos.
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor():
		_bob_time += delta * speed * 1.8
	var bob_weight := clampf(speed / player.walk_speed, 0.0, 1.6) * lerpf(1.0, 0.15, aim)
	var bob := Vector3(sin(_bob_time) * bob_amount, -absf(cos(_bob_time)) * bob_amount * 0.8, 0.0) * bob_weight

	# Respiração ao mirar: oscilação lenta e pequena (a arma "vive" na mão).
	_breath_time += delta
	var breath := Vector3(sin(_breath_time * 0.9) * 0.0012, sin(_breath_time * 1.7) * 0.0009, 0.0) * aim
	pos += breath
	var kick_pos := _kick_position.update(delta)
	var kick_rot := _kick_rotation.update(delta)

	_model.position = pos + bob + Vector3(_sway.x, -_sway.y, 0.0) * 0.5 + kick_pos
	_model.rotation = Vector3(
		deg_to_rad(rot.x) - _sway.y + kick_rot.x,
		deg_to_rad(rot.y) + _sway.x * 1.5 + kick_rot.y,
		deg_to_rad(rot.z) + _sway.x + kick_rot.z)


func _shoot() -> void:
	var camera := holder.camera
	var origin := camera.global_position
	var direction := _apply_spread(-camera.global_basis.z, current_spread)
	_bloom += data.spread_per_shot

	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * data.max_range, holder.hit_mask, [holder.player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var info := HitInfo.new()
	info.damage = data.damage
	info.position = hit.position
	info.normal = hit.normal
	info.direction = direction
	info.impulse = data.impact_impulse
	info.source = holder.player

	var collider: Object = hit.collider
	var enemy := _enemy_from(collider)
	var was_alive := enemy != null and not enemy.is_dead
	if collider.has_method(&"apply_hit"):
		collider.apply_hit(info)
		if was_alive:
			hit_confirmed.emit(enemy.is_dead, collider != enemy)
	elif collider is RigidBody3D:
		collider.apply_impulse(direction * data.impact_impulse, info.position - collider.global_position)

	var impact := BULLET_IMPACT.instantiate()
	_fx_parent().add_child(impact)
	impact.setup(hit.position, hit.normal, collider.get_meta(&"surface", &"areia"))


## O inimigo dono do colisor atingido (corpo ou área da cabeça), se houver.
func _enemy_from(collider: Object) -> EnemySoldier:
	if collider is EnemySoldier:
		return collider
	if collider is Node and (collider as Node).owner is EnemySoldier:
		return (collider as Node).owner
	return null


func _apply_spread(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction
	var axis := direction.cross(Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT).normalized()
	# sqrt() distribui os tiros uniformemente dentro do cone, não concentrados no centro.
	var angle := deg_to_rad(degrees) * sqrt(randf())
	return direction.rotated(axis, angle).rotated(direction, randf() * TAU).normalized()


func _apply_recoil() -> void:
	var aim_factor := lerpf(1.0, 0.75, aim_blend)
	holder.player.add_aim_kick(data.aim_kick_pitch * aim_factor, randf_range(-1.0, 1.0) * data.aim_kick_yaw)
	holder.camera.kick(Vector3(
		data.view_kick_pitch * aim_factor,
		randf_range(-0.4, 0.4),
		randf_range(-1.0, 1.0) * data.view_kick_roll))
	holder.camera.add_trauma(data.camera_trauma)
	_kick_model(
		Vector3(randf_range(-0.004, 0.004), 0.008, data.model_kick_back * lerpf(1.0, 0.6, aim_blend)),
		Vector3(deg_to_rad(data.model_kick_rotation_degrees) * lerpf(1.0, 0.4, aim_blend),
			randf_range(-0.02, 0.02), randf_range(-0.04, 0.04)))


func _kick_model(position_offset: Vector3, rotation_offset: Vector3) -> void:
	_kick_position.value += position_offset
	_kick_rotation.value += rotation_offset


func _play_fire_effects() -> void:
	_fire_audio.play()
	OneShotSound.play_echo(self, _fire_audio.stream, global_position, -11.0)  # o som já tem a cauda gravada
	_flash.visible = true
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_flash_light.visible = true
	_flash_time = 0.05

	var smoke := MUZZLE_SMOKE.instantiate()
	_fx_parent().add_child(smoke)
	smoke.global_transform = _muzzle.global_transform

	if casing_scene:
		_spawn_ejected(casing_scene, Vector3(1.8, 1.6, 0.3), 1.2)


func _eject_clip() -> void:
	_play(_ping_audio, data.sound_clip_eject)
	if clip_scene:
		_spawn_ejected(clip_scene, Vector3(0.3, 3.2, 0.2), 1.6)


func _spawn_ejected(scene: PackedScene, local_velocity: Vector3, lifetime: float) -> void:
	var piece: EjectedPiece = scene.instantiate()
	_fx_parent().add_child(piece)
	piece.global_transform = _ejection.global_transform
	var jitter := Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))
	piece.velocity = _ejection.global_basis * (local_velocity + jitter) + holder.player.velocity
	piece.lifetime = lifetime


## Efeitos soltos no mundo (fumaça, impactos, cápsulas) vão para a fase onde o jogador está.
func _fx_parent() -> Node:
	return holder.player.get_parent()


func _update_flash(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time -= delta
	if _flash_time <= 0.0:
		_flash.visible = false
		_flash_light.visible = false


func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	player.stream = _randomized(stream, 1.05)
	player.play()


func _randomized(stream: AudioStream, pitch: float) -> AudioStream:
	if stream == null:
		return null
	var randomizer := AudioStreamRandomizer.new()
	randomizer.add_stream(-1, stream)
	randomizer.random_pitch = pitch
	randomizer.random_volume_offset_db = 1.0
	return randomizer


func _brighten(node: Node) -> void:
	if node.name == &"Bracos":
		return  # os braços usam a iluminação normal dos personagens
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i) as StandardMaterial3D
			# Só materiais não metálicos (madeira); o metal já reflete a luz.
			if material and material.metallic < 0.5:
				material = material.duplicate()
				material.albedo_color = material.albedo_color * model_brightness
				mesh_instance.set_surface_override_material(i, material)
	for child in node.get_children():
		_brighten(child)


func _set_layer_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		node.layers = 1 << (VIEWMODEL_LAYER - 1)
	elif node is Light3D:
		# Luzes da arma (clarão) iluminam o mundo e a própria arma.
		node.layers |= 1 << (VIEWMODEL_LAYER - 1)
	for child in node.get_children():
		_set_layer_recursive(child)
