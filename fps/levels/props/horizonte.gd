extends Node3D
## Fundo da fase: colinas ao longe em volta do lado de terra (escondem o fim do mapa) e
## árvores das cercas vivas (bocage) no alto da encosta e nas colinas. Gerado ao carregar;
## a neblina deixa tudo em silhueta. Sem sombras e com poucos triângulos.

@export var terrain: BeachTerrain
## Centro do anel de colinas e raios interno (logo após o fim do terreno) e externo.
@export var center := Vector2(0.0, -10.0)
@export var inner_radius := 128.0
@export var outer_radius := 520.0
## Ângulos cobertos (graus; 0 = +X, 90 = +Z/mar): o lado do mar fica aberto.
@export var angle_from := 170.0
@export var angle_to := 370.0
@export var hill_color := Color(0.13, 0.16, 0.11)
@export var tree_color := Color(0.07, 0.09, 0.055)
@export var tree_count := 520
@export var seed := 1944

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_noise.seed = seed
	_noise.frequency = 0.012
	_rng.seed = seed
	_build_hills()
	_build_trees()


## Altura das colinas num ponto do anel: começa na altura da borda do terreno e sobe com
## ondulações (mais altas ao longe).
func _hill_height(angle: float, radius: float) -> float:
	var dir := Vector2(cos(angle), sin(angle))
	var p := center + dir * radius
	var edge := center + dir * inner_radius
	var base := terrain.height_at(clampf(edge.x, -119.0, 119.0), clampf(edge.y, -109.0, 109.0)) if terrain else 10.0
	var t := clampf((radius - inner_radius) / (outer_radius - inner_radius), 0.0, 1.0)
	var swell := (_noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5) * lerpf(4.0, 55.0, t)
	return base - 0.5 + swell * smoothstep(0.0, 0.08, t) + t * 10.0


func _build_hills() -> void:
	var rings := 26
	var segments := 120
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a0 := deg_to_rad(angle_from)
	var a1 := deg_to_rad(angle_to)
	var points := []
	for r in rings + 1:
		var row := []
		# Anéis mais densos perto (onde se vê detalhe).
		var radius := lerpf(inner_radius, outer_radius, pow(float(r) / rings, 1.6))
		for k in segments + 1:
			var angle := lerpf(a0, a1, float(k) / segments)
			var dir := Vector2(cos(angle), sin(angle))
			var p := center + dir * radius
			row.append(Vector3(p.x, _hill_height(angle, radius), p.y))
		points.append(row)
	for r in rings:
		for k in segments:
			var a: Vector3 = points[r][k]
			var b: Vector3 = points[r][k + 1]
			var c: Vector3 = points[r + 1][k]
			var d: Vector3 = points[r + 1][k + 1]
			for tri: Array in [[a, c, b], [b, c, d]]:
				var normal: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				if normal.y < 0.0:
					normal = -normal
				for v: Vector3 in tri:
					st.set_normal(normal)
					st.add_vertex(v)
	var material := StandardMaterial3D.new()
	material.albedo_color = hill_color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Colinas"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


## Árvores: copas irregulares (esfera achatada) num MultiMesh. Fileiras de cerca viva no
## alto da encosta e manchas de bosque espalhadas nas colinas.
func _build_trees() -> void:
	var crown := _crown_mesh()
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true  # cor por árvore (MultiMesh)
	material.vertex_color_is_srgb = true
	crown.surface_set_material(0, material)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	# Cercas vivas no planalto: fileiras em ziguezague atrás das casas.
	var rows := [[-115.0, -104.0, 115.0, -107.0], [-115.0, -118.0, 115.0, -122.0], [-40.0, -104.0, -46.0, -125.0],
		[52.0, -105.0, 47.0, -128.0], [-95.0, -60.0, -112.0, -105.0], [100.0, -40.0, 112.0, -100.0]]
	for row: Array in rows:
		var from := Vector2(row[0], row[1])
		var to := Vector2(row[2], row[3])
		var count := int(from.distance_to(to) / 4.5)
		for i in count:
			var p := from.lerp(to, (i + _rng.randf()) / count) + Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5))
			_add_tree(transforms, colors, p, _rng.randf_range(3.0, 5.5))
	# Arbustos no alto e na meia encosta (menores, em grupos).
	for i in 160:
		var x := _rng.randf_range(-115.0, 115.0)
		var z := _rng.randf_range(-108.0, -68.0)
		if terrain and terrain.grass_at(x, z) < 0.5:
			continue
		if _noise.get_noise_2d(x * 2.0, z * 2.0) < -0.1:
			continue
		_add_tree(transforms, colors, Vector2(x, z), _rng.randf_range(0.6, 1.4), INF, 0.45)
	# Bosques nas colinas (na superfície do anel).
	var placed := 0
	while placed < tree_count:
		var angle := deg_to_rad(_rng.randf_range(angle_from, angle_to))
		var radius := _rng.randf_range(inner_radius + 6.0, outer_radius * 0.75)
		if _noise.get_noise_2d(cos(angle) * radius * 0.5, sin(angle) * radius * 0.5) < 0.05:
			continue  # bosques em manchas, não um tapete
		var p := center + Vector2(cos(angle), sin(angle)) * radius
		_add_tree(transforms, colors, p, _rng.randf_range(4.0, 7.0), _hill_height(angle, radius))
		placed += 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = crown
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Arvores"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## `flatten` < 1 achata (arbustos: rentes ao chão, meio enterrados).
func _add_tree(transforms: Array[Transform3D], colors: Array[Color], p: Vector2, size: float, ground := INF,
		flatten := 1.0) -> void:
	var y := ground
	if y == INF:
		y = terrain.height_at(clampf(p.x, -119.0, 119.0), clampf(p.y, -109.0, 109.0)) if terrain else 10.0
	var height := size * _rng.randf_range(0.8, 1.2) * flatten
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, height, size * _rng.randf_range(0.8, 1.1)))
	transforms.append(Transform3D(basis, Vector3(p.x, y + height * (0.85 if flatten >= 1.0 else 0.2), p.y)))
	var shade := _rng.randf_range(0.75, 1.25)
	colors.append(Color(tree_color.r * shade, tree_color.g * shade * _rng.randf_range(0.9, 1.1), tree_color.b * shade))


## Copa irregular: algumas esferas grosseiras de tamanhos diferentes, juntas numa malha.
func _crown_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var blobs := [[Vector3(0, 0, 0), 1.0], [Vector3(0.55, 0.25, 0.1), 0.7], [Vector3(-0.5, 0.15, -0.2), 0.75],
		[Vector3(0.1, 0.55, -0.35), 0.6], [Vector3(-0.15, -0.3, 0.45), 0.65]]
	for blob: Array in blobs:
		var sphere := SphereMesh.new()
		sphere.radius = blob[1]
		sphere.height = blob[1] * 1.7
		sphere.radial_segments = 7
		sphere.rings = 4
		var arrays := sphere.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for idx in indices:
			# Leve irregularidade nos vértices (contorno menos redondo).
			var v: Vector3 = verts[idx] * (1.0 + sin(verts[idx].x * 7.0 + verts[idx].z * 5.0) * 0.12) + blob[0]
			st.set_normal(normals[idx])
			st.add_vertex(v)
	return st.commit()

