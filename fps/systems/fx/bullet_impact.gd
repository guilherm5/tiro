extends Node3D
## Impacto de bala: poeira, lascas, marca na superfície e som, variando por superfície.
##
## A superfície vem do metadado `surface` do objeto atingido (no Inspector:
## Metadata → surface = "concreto"). Sem metadado, vale "areia".

const MAX_ALIVE := 60
const DECAL_LIFETIME := 25.0

const SURFACES := {
	&"areia": {
		"dust": Color(0.62, 0.55, 0.42), "chips": Color(0.45, 0.4, 0.3),
		"sound": preload("res://assets/audio/provisorio/impacto_areia.wav"), "mark": true, "dust_amount": 1.0,
	},
	&"concreto": {
		"dust": Color(0.6, 0.59, 0.56), "chips": Color(0.42, 0.41, 0.39),
		"sound": preload("res://assets/audio/provisorio/impacto_concreto.wav"), "mark": true, "dust_amount": 0.8,
	},
	&"metal": {
		"dust": Color(0.35, 0.33, 0.3), "chips": Color(1.0, 0.75, 0.4),
		"sound": preload("res://assets/audio/provisorio/impacto_metal.wav"), "mark": true, "dust_amount": 0.3,
	},
	&"madeira": {
		"dust": Color(0.5, 0.42, 0.32), "chips": Color(0.4, 0.28, 0.16),
		"sound": preload("res://assets/audio/provisorio/impacto_madeira.wav"), "mark": true, "dust_amount": 0.5,
	},
	&"corpo": {
		"dust": Color(0.3, 0.06, 0.05), "chips": Color(0.25, 0.05, 0.04),
		"sound": preload("res://assets/audio/provisorio/impacto_corpo.wav"), "mark": false, "dust_amount": 0.35,
	},
	&"agua": {
		"dust": Color(0.75, 0.8, 0.82), "chips": Color(0.7, 0.78, 0.8),
		"sound": preload("res://assets/audio/provisorio/impacto_agua.wav"), "mark": false, "dust_amount": 1.4,
	},
}

static var _alive: Array[Node] = []

@onready var _dust: GPUParticles3D = $Dust
@onready var _chips: GPUParticles3D = $Chips
@onready var _mark: Decal = $Mark
@onready var _audio: AudioStreamPlayer3D = $Audio


func setup(hit_position: Vector3, normal: Vector3, surface: StringName) -> void:
	var profile: Dictionary = SURFACES.get(surface, SURFACES[&"areia"])

	# Eixo Y alinhado à normal: partículas saem da superfície e a marca é projetada nela.
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	global_transform = Transform3D(Basis(side, up, side.cross(up)), hit_position)
	_mark.rotate_object_local(Vector3.UP, randf() * TAU)

	_tint(_dust, profile.dust)
	_tint(_chips, profile.chips)
	_dust.amount_ratio = clampf(profile.dust_amount, 0.0, 1.0)
	if surface == &"agua":
		_dust.process_material.initial_velocity_min *= 2.0
		_dust.process_material.initial_velocity_max *= 2.0
		_water_ring(hit_position)
	_dust.restart()
	_chips.restart()

	_mark.visible = profile.mark
	_audio.stream = profile.sound
	_audio.pitch_scale = randf_range(0.9, 1.1)
	_audio.play()

	_register()
	get_tree().create_timer(DECAL_LIFETIME if profile.mark else 3.0).timeout.connect(queue_free)


## Anel que se abre na superfície da água e some.
func _water_ring(at: Vector3) -> void:
	if _ring_material == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.78, 0.9, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(0.85, 0.88, 0.88, 0.7),
			Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		_ring_material = StandardMaterial3D.new()
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.albedo_texture = texture
	var ring := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.6, 1.6)
	ring.mesh = quad
	ring.material_override = _ring_material.duplicate()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = at + Vector3.UP * 0.03
	ring.scale = Vector3.ONE * 0.15
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, ^"scale", Vector3.ONE, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring.material_override, ^"albedo_color:a", 0.0, 0.9)
	tween.chain().tween_callback(ring.queue_free)


static var _ring_material: StandardMaterial3D


func _tint(particles: GPUParticles3D, color: Color) -> void:
	var material: ParticleProcessMaterial = particles.process_material.duplicate()
	material.color = color
	particles.process_material = material


## Limita quantos impactos existem ao mesmo tempo (marcas antigas somem primeiro).
func _register() -> void:
	_alive.append(self)
	tree_exiting.connect(func() -> void: _alive.erase(self))
	while _alive.size() > MAX_ALIVE:
		var oldest: Node = _alive.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
