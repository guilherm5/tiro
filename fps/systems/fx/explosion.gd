class_name Explosion
extends Node3D
## Explosão (artilharia; depois granadas): clarão, coluna de areia ou água, detritos,
## som, tremor de câmera e supressão por distância, e dano em área com linha de visão.
##
## Uso: var e := EXPLOSION.instantiate(); parent.add_child(e); e.detonate(pos, on_water)

const SOUND := preload("res://assets/audio/provisorio/explosao.wav")

@export var damage_radius := 6.0
@export var max_damage := 150.0
## Queda do dano com a distância (2 = cai rápido, artilharia; 1 = linear, granada).
@export var falloff_power := 2.0
## Distância em que a explosão ainda faz a tela tremer.
@export var shake_radius := 45.0
@export var suppression_radius := 25.0

var source: Node = null

@onready var _flash: OmniLight3D = $Flash
@onready var _dirt: GPUParticles3D = $Dirt
@onready var _debris: GPUParticles3D = $Debris
@onready var _smoke: GPUParticles3D = $Smoke
@onready var _water: GPUParticles3D = $Water


func detonate(at: Vector3, on_water := false) -> void:
	global_position = at
	if on_water:
		_water.restart()
		_smoke.amount_ratio = 0.3
	else:
		_dirt.restart()
		_debris.restart()
	_smoke.restart()
	OneShotSound.play(get_parent(), SOUND, at, 6.0, 40.0, 0.12)

	var tween := create_tween()
	tween.tween_property(_flash, ^"light_energy", 0.0, 0.35).from(14.0)

	_affect_player(at, on_water)
	_apply_damage(at)
	get_tree().create_timer(9.0).timeout.connect(queue_free)


func _affect_player(at: Vector3, on_water := false) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player == null or player.is_dead:
		return
	var distance := player.global_position.distance_to(at)
	if distance < shake_radius:
		# Perto, o tranco é bem mais forte (curva quadrática).
		var closeness := 1.0 - distance / shake_radius
		player.camera.add_trauma(lerpf(0.08, 1.0, closeness * closeness))
	# Avisos para efeitos de ambiente (poeira no bunker, lâmpada, água na lente).
	if distance < 40.0:
		EventBus.narrative_event.emit("explosao_proxima")
	if on_water and distance < 18.0:
		EventBus.narrative_event.emit("agua_na_lente")
	if distance < suppression_radius:
		player.suppress(lerpf(0.35, 0.05, distance / suppression_radius))


func _apply_damage(at: Vector3) -> void:
	if max_damage <= 0.0:
		return
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = damage_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), at)
	query.collision_mask = 0b110  # jogador e inimigos
	for result in space.intersect_shape(query, 16):
		var body: Node3D = result.collider
		if not body.has_method(&"apply_hit"):
			continue
		var center := body.global_position + Vector3.UP
		# Sem dano através de paredes.
		var los := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, center, 1)
		if not space.intersect_ray(los).is_empty():
			continue
		var falloff := 1.0 - clampf(at.distance_to(center) / damage_radius, 0.0, 1.0)
		var hit := HitInfo.new()
		hit.damage = max_damage * pow(falloff, falloff_power)
		hit.position = center
		hit.direction = (center - at).normalized()
		hit.impulse = 20.0 * falloff
		hit.source = source
		body.apply_hit(hit)
