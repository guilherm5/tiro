extends GPUParticles3D
## Poeira e areia caindo do teto (bunker) quando a artilharia cai perto: uma rajada a
## cada evento "explosao_proxima". Só aparece enquanto o jogador está perto.

@export var extents := Vector3(5.0, 0.05, 3.2)
@export var player_range := 14.0


func _ready() -> void:
	one_shot = true
	emitting = false
	amount = 70
	lifetime = 2.4
	explosiveness = 0.75
	visibility_aabb = AABB(-extents - Vector3(1, 3, 1), (extents + Vector3(1, 3, 1)) * 2.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.DOWN
	process.spread = 8.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.5
	process.gravity = Vector3(0, -2.5, 0)
	process.damping_min = 0.6
	process.damping_max = 1.2
	process.scale_min = 0.4
	process.scale_max = 1.6
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0.62, 0.58, 0.5, 0.7), Color(0.62, 0.58, 0.5, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = soft
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	material.albedo_texture = texture
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	quad.material = material
	draw_pass_1 = quad
	EventBus.narrative_event.connect(_on_event)


func _on_event(event_name: String) -> void:
	if event_name != "explosao_proxima":
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player and player.global_position.distance_to(global_position) < player_range:
		restart()
