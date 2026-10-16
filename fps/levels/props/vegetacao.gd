extends Node3D
## Grama das encostas: tufos espalhados onde o terreno tem grama (BeachTerrain.grass_at),
## gerados ao carregar a fase. Ficam em blocos para a câmera descartar o que não vê.
## Dois níveis de detalhe por bloco: perto, tufos cheios; longe, tufos simples e metade
## deles; além de `draw_distance` somem (a textura do chão continua verde).

@export var terrain: BeachTerrain
@export var grass_shader: Shader
## Tufos por metro quadrado onde a grama é cheia.
@export var density := 3.2
@export var block_size := 16.0
@export var draw_distance := 45.0
## Até esta distância, tufos cheios; depois, tufos simples.
@export var near_distance := 16.0
@export var blades_per_clump := 14
@export var seed := 44

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if terrain == null:
		return
	_rng.seed = seed
	var material := ShaderMaterial.new()
	material.shader = grass_shader
	var clump := _clump_mesh(blades_per_clump, 2)
	clump.surface_set_material(0, material)
	var simple := _clump_mesh(5, 1)
	simple.surface_set_material(0, material)
	var half := Vector2(terrain.size) * 0.5
	var blocks_x := ceili(terrain.size.x / block_size)
	var blocks_z := ceili(terrain.size.y / block_size)
	var total := 0
	for bz in blocks_z:
		for bx in blocks_x:
			var origin := Vector2(-half.x + bx * block_size, -half.y + bz * block_size)
			total += _build_block(origin, clump, simple)
	print("vegetação: %d tufos" % total)


func _build_block(origin: Vector2, clump: Mesh, simple: Mesh) -> int:
	var transforms: Array[Transform3D] = []
	var customs: Array[float] = []
	var tries := int(block_size * block_size * density)
	for i in tries:
		var x := origin.x + _rng.randf() * block_size
		var z := origin.y + _rng.randf() * block_size
		var grass := terrain.grass_at(x, z)
		if grass < 0.3 or _rng.randf() > grass:
			continue
		var y := terrain.height_at(x, z)
		var scale := _rng.randf_range(0.6, 1.25) * lerpf(0.7, 1.0, grass)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, scale * _rng.randf_range(0.8, 1.3), scale))
		transforms.append(Transform3D(basis, Vector3(x, y - 0.03, z)))
		customs.append(_rng.randf())
	if transforms.is_empty():
		return 0
	_add_instances(clump, transforms, customs, 1, 0.0, near_distance)
	_add_instances(simple, transforms, customs, 2, near_distance, draw_distance)
	return transforms.size()


func _add_instances(mesh: Mesh, transforms: Array[Transform3D], customs: Array[float], step: int,
		begin: float, end: float) -> void:
	var count := ceili(transforms.size() / float(step))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in count:
		multimesh.set_instance_transform(i, transforms[i * step])
		multimesh.set_instance_custom_data(i, Color(customs[i * step], 0.0, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_begin = begin
	instance.visibility_range_end = end
	instance.visibility_range_end_margin = 6.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(instance)


## Tufo: folhas finas e curvas saindo do mesmo ponto, abertas em leque.
func _clump_mesh(blades: int, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for b in blades:
		var angle := TAU * b / blades + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var height := rng.randf_range(0.18, 0.5)
		var lean := rng.randf_range(0.1, 0.28)
		var width := rng.randf_range(0.012, 0.022) * (1.0 if segments > 1 else 2.2)
		var base := dir * rng.randf_range(0.0, 0.15)
		# Segmentos da base à ponta; a folha curva para fora.
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for k in segments + 1:
			var t := k / float(segments)
			points.append(base + dir * lean * t * t + Vector3.UP * height * t)
			widths.append(width * (1.0 - t * 0.9))
		for k in segments:
			var a0 := points[k] - side * widths[k]
			var a1 := points[k] + side * widths[k]
			var b0 := points[k + 1] - side * widths[k + 1]
			var b1 := points[k + 1] + side * widths[k + 1]
			var normal := (dir * 0.3 + Vector3.UP).normalized()
			var t0 := k / float(segments)
			var t1 := (k + 1) / float(segments)
			for v: Array in [[a0, t0], [b0, t1], [a1, t0], [a1, t0], [b0, t1], [b1, t1]]:
				st.set_normal(normal)
				st.set_uv(Vector2(0.0, v[1]))
				st.add_vertex(v[0])
	return st.commit()
