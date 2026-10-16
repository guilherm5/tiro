@tool
class_name BeachTerrain
extends StaticBody3D
## Terreno de praia gerado por código: inclinação até o mar, ondulações, crateras de
## artilharia e encostas nas bordas (escondem o fim do mapa). Gera malha e colisão
## ao abrir a cena — no editor também (marque "Reconstruir" para atualizar).
##
## Cor dos vértices para o shader: R = queimado (crateras), G = grama, B = terra revolvida
## (trincheira e trilhas). Rocha exposta sai da inclinação, no shader.
##
## Objetos no grupo "terreno_plano" ficam em chão sem ondulação (sacos de areia, muros,
## bunker, ouriços). Raio: metadado "raio_plano" ou, para caixas CSG, o maior lado / 2.

@export var size := Vector2i(240, 220)
@export var slope_degrees := 2.0
@export_group("Relevo")
@export var ripple_height := 0.09
@export var undulation_height := 0.22
## A partir deste Z (para dentro), o terreno sobe em uma encosta.
@export var bluff_start_z := -60.0
@export var bluff_height := 14.0
@export var bluff_length := 25.0
## Quanto o pé da encosta recua (para dentro) ao longo de X, em metros (ruído).
@export var bluff_variation := 7.0
## A partir desta distância do centro (X), as laterais sobem.
@export var side_start_x := 70.0
@export var side_height := 8.0
@export_group("Crateras")
## x, z, raio, profundidade.
@export var craters: Array[Vector4] = [
	Vector4(8, 30, 3.2, 0.9), Vector4(-18, 12, 3.5, 1.0), Vector4(24, 4, 3.0, 0.8),
	Vector4(-6, -2, 2.8, 0.8), Vector4(-30, 35, 3.5, 1.0), Vector4(2, 40, 3.0, 0.7),
	Vector4(38, -12, 3.2, 0.9), Vector4(-40, -10, 3.0, 0.8),
]
@export_group("Trilhas")
## Trilhas de terra batida: cada uma é uma linha de pontos (x, z).
@export var paths: Array[PackedVector2Array] = []
@export var path_half_width := 0.9
@export_group("Trincheira")
## Caminho da trincheira: pontos (x, z, profundidade). Vazio = sem trincheira.
@export var trench := PackedVector3Array()
## Meia largura do fundo plano.
@export var trench_bottom_half_width := 0.8
## Largura do talude (do fundo até a borda).
@export var trench_wall_width := 1.0
@export_group("")
@export var material: Material
@export var rebuild := false:
	set(value):
		if value and is_inside_tree():
			_build()

var _noise := FastNoiseLite.new()
var _flat: Array[Vector3] = []  # x, z, raio


func _ready() -> void:
	_build()


func height_at(x: float, z: float) -> float:
	var h := -tan(deg_to_rad(slope_degrees)) * z
	var detail := ripple_height * _noise.get_noise_2d(x * 4.0, z * 4.0) \
		+ undulation_height * _noise.get_noise_2d(x * 0.6 + 300.0, z * 0.6)
	h += detail * _flatten_mask(x, z)
	h += _bluff(x, z)
	h += side_height * smoothstep(side_start_x, side_start_x + 30.0, absf(x))
	for crater in craters:
		h += _crater_offset(Vector2(x, z), crater)
	if not trench.is_empty():
		var info := trench_at(x, z)
		h -= info.y * (1.0 - smoothstep(trench_bottom_half_width, trench_bottom_half_width + trench_wall_width, info.x))
	return h


## Distância até o eixo da trincheira (x) e a profundidade nesse trecho (y).
func trench_at(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var best := Vector2(INF, 0.0)
	for i in trench.size() - 1:
		var a := Vector2(trench[i].x, trench[i].y)
		var b := Vector2(trench[i + 1].x, trench[i + 1].y)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best.x:
			best = Vector2(d, lerpf(trench[i].z, trench[i + 1].z, t))
	return best


## 0..1: quanto o chão está queimado (crateras escurecidas).
func scorch_at(x: float, z: float) -> float:
	var s := 0.0
	for crater in craters:
		var d := Vector2(x, z).distance_to(Vector2(crater.x, crater.y))
		s = maxf(s, 1.0 - smoothstep(crater.z * 0.6, crater.z * 1.8, d))
	return s


## 0..1: quanto o chão tem grama (encostas do fundo e das laterais, fora da praia).
## Encosta do fundo: o pé recua irregularmente ao longo de X (nunca avança sobre a praia);
## sobe íngreme no primeiro terço (barranco) e suaviza até o alto, com um degrau no meio.
func _bluff(x: float, z: float) -> float:
	var start := _bluff_start(x)
	var t := clampf((start - z) / bluff_length, 0.0, 1.0)
	var steep := smoothstep(0.0, 0.35, t)
	var gentle := smoothstep(0.3, 1.0, t)
	var step := smoothstep(0.42, 0.5, t) - smoothstep(0.5, 0.6, t) * 0.5
	return bluff_height * (steep * 0.62 + gentle * 0.38 + step * 0.04)


func _bluff_start(x: float) -> float:
	var n := _noise.get_noise_2d(x * 0.9, 777.0) * 0.6 + _noise.get_noise_2d(x * 3.0, 333.0) * 0.4
	return bluff_start_z - (n * 0.5 + 0.5) * bluff_variation


func grass_at(x: float, z: float) -> float:
	var breakup := _noise.get_noise_2d(x * 3.0 + 50.0, z * 3.0) * 4.0
	var bluff := smoothstep(_bluff_start(x) + 2.0, _bluff_start(x) - 5.0, z + breakup)
	var sides := smoothstep(side_start_x - 2.0, side_start_x + 8.0, absf(x) + breakup)
	var grass := maxf(bluff, sides) * (1.0 - dirt_at(x, z))
	return clampf(grass * _flatten_mask(x, z), 0.0, 1.0)


## 0..1: terra revolvida (paredes e fundo da trincheira).
func dirt_at(x: float, z: float) -> float:
	var dirt := 0.0
	if not trench.is_empty():
		var info := trench_at(x, z)
		dirt = 1.0 - smoothstep(trench_bottom_half_width + trench_wall_width, trench_bottom_half_width + trench_wall_width + 1.5, info.x)
	if not paths.is_empty():
		var wobble := _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.4
		dirt = maxf(dirt, 1.0 - smoothstep(path_half_width * 0.6, path_half_width + 0.5, _path_distance(x, z) + wobble))
	return dirt


func _path_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for line in paths:
		for i in line.size() - 1:
			var a := line[i]
			var ab := line[i + 1] - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


func _crater_offset(p: Vector2, crater: Vector4) -> float:
	var d := p.distance_to(Vector2(crater.x, crater.y)) / crater.z
	var bowl := -crater.w * (1.0 - d * d) if d < 1.0 else 0.0
	var rim := crater.w * 0.35 * exp(-pow((d - 1.0) * 3.0, 2.0))
	return bowl + rim


func _flatten_mask(x: float, z: float) -> float:
	var mask := 1.0
	for f in _flat:
		var d := Vector2(x, z).distance_to(Vector2(f.x, f.y))
		mask = minf(mask, smoothstep(f.z, f.z + 2.0, d))
	return mask


func _collect_flat_areas() -> void:
	_flat.clear()
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(&"terreno_plano"):
		var n := node as Node3D
		if n == null:
			continue
		var radius := 2.0
		if n.has_meta(&"raio_plano"):
			radius = n.get_meta(&"raio_plano")
		elif n is CSGBox3D:
			var s: Vector3 = (n as CSGBox3D).size
			radius = maxf(s.x, s.z) * 0.5 + 0.5
		_flat.append(Vector3(n.global_position.x, n.global_position.z, radius))


func _build() -> void:
	_noise.seed = 1944
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.02
	_collect_flat_areas()

	var w := size.x + 1
	var d := size.y + 1
	var x0 := -size.x * 0.5
	var z0 := -size.y * 0.5
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for iz in d:
		for ix in w:
			heights[iz * w + ix] = height_at(x0 + ix, z0 + iz)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	vertices.resize(w * d)
	normals.resize(w * d)
	uvs.resize(w * d)
	colors.resize(w * d)
	for iz in d:
		for ix in w:
			var i := iz * w + ix
			var x := x0 + ix
			var z := z0 + iz
			vertices[i] = Vector3(x, heights[i], z)
			var hl := heights[iz * w + maxi(ix - 1, 0)]
			var hr := heights[iz * w + mini(ix + 1, w - 1)]
			var hd := heights[maxi(iz - 1, 0) * w + ix]
			var hu := heights[mini(iz + 1, d - 1) * w + ix]
			normals[i] = Vector3(hl - hr, 2.0, hd - hu).normalized()
			uvs[i] = Vector2(x, z)
			colors[i] = Color(scorch_at(x, z), grass_at(x, z), dirt_at(x, z))

	var indices := PackedInt32Array()
	indices.resize((w - 1) * (d - 1) * 6)
	var k := 0
	for iz in d - 1:
		for ix in w - 1:
			var a := iz * w + ix
			var b := a + 1
			var c := a + w
			var e := c + 1
			indices[k] = a; indices[k + 1] = b; indices[k + 2] = c
			indices[k + 3] = b; indices[k + 4] = e; indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)

	var mesh_instance := get_node_or_null(^"Mesh") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		add_child(mesh_instance)
	mesh_instance.mesh = mesh

	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = heights
	var collision := get_node_or_null(^"Shape") as CollisionShape3D
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = "Shape"
		add_child(collision)
	collision.shape = shape
