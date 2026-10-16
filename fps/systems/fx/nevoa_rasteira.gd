extends GPUParticles3D
## Névoa de pólvora rasteira: grandes faixas de fumaça clara e transparente, quase no
## chão, que derivam devagar com o vento sobre a área (`extents`). Poucas partículas.

@export var extents := Vector3(90, 1.5, 45)
@export var wind := Vector3(0.6, 0.0, -0.25)
@export var particle_size := 16.0
@export var opacity := 0.16


func _ready() -> void:
	amount = 28
	lifetime = 40.0
	preprocess = 40.0
	visibility_aabb = AABB(-extents - Vector3(20, 5, 20), (extents + Vector3(20, 5, 20)) * 2.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = wind.normalized()
	process.spread = 25.0
	process.initial_velocity_min = wind.length() * 0.6
	process.initial_velocity_max = wind.length() * 1.3
	process.gravity = Vector3.ZERO
	process.scale_min = 0.7
	process.scale_max = 1.4
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(0.75, 0.74, 0.7, 0.0), Color(0.75, 0.74, 0.7, opacity),
		Color(0.7, 0.7, 0.68, opacity), Color(0.7, 0.7, 0.68, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	process_material = process
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = soft
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.proximity_fade_enabled = true
	material.proximity_fade_distance = 2.0
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = 1.0
	material.distance_fade_max_distance = 8.0
	var quad := QuadMesh.new()
	quad.size = Vector2(particle_size, particle_size * 0.45)
	quad.material = material
	draw_pass_1 = quad
