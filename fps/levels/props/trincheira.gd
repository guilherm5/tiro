extends Node3D
## Revestimento da trincheira cavada pelo terreno (BeachTerrain.trench): paredes de
## tábuas com estacas, estrado no fundo e sacos de areia no parapeito. Tudo é gerado ao
## carregar a fase, seguindo o caminho do terreno, em três malhas (uma por material)
## para custar poucas chamadas de desenho. As paredes têm colisão (e entram na
## navegação pelo grupo "navegacao").

@export var terrain: BeachTerrain
@export var planks_material: Material
@export var sandbag_material: Material
## Distância do eixo até a parede de tábuas.
@export var wall_offset := 1.0
## Quanto a parede passa do nível do chão (vira parapeito).
@export var wall_above_ground := 0.3
@export var panel_length := 1.6

var _planks := SurfaceTool.new()
var _bags := SurfaceTool.new()
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if terrain == null or terrain.trench.size() < 2:
		return
	_rng.seed = 6
	_planks.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bags.begin(Mesh.PRIMITIVE_TRIANGLES)
	_body = StaticBody3D.new()
	_body.name = "Colisao"
	_body.set_meta(&"surface", &"madeira")
	_body.add_to_group(&"navegacao")  # o caminho da IA respeita as paredes
	add_child(_body)
	var path := terrain.trench
	for i in path.size() - 1:
		var prev := Vector2(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y).normalized() if i > 0 else Vector2.ZERO
		var next := Vector2(path[i + 2].x - path[i + 1].x, path[i + 2].y - path[i + 1].y).normalized() \
			if i + 2 < path.size() else Vector2.ZERO
		_build_segment(path[i], path[i + 1], prev, next)
	_add_mesh(_planks, planks_material, "Tabuas")
	_add_mesh(_bags, sandbag_material, "Sacos")


func _build_segment(a3: Vector3, b3: Vector3, prev_dir: Vector2, next_dir: Vector2) -> void:
	var a := Vector2(a3.x, a3.y)
	var b := Vector2(b3.x, b3.y)
	var length := a.distance_to(b)
	if length < 0.1:
		return
	var dir := (b - a) / length
	var side := Vector2(-dir.y, dir.x)
	var yaw := atan2(-dir.x, -dir.y)  # -Z do painel ao longo do segmento
	var basis := Basis(Vector3.UP, yaw)
	for s: float in [-1.0, 1.0]:
		# Nas quinas, a parede de fora da curva se prolonga para fechar o canto e a de
		# dentro recua (senão as duas atravessam o corredor e trancam a passagem).
		var start := -_corner_extension(prev_dir, dir, s) if prev_dir != Vector2.ZERO else 0.0
		var finish := length + (_corner_extension(dir, next_dir, s) if next_dir != Vector2.ZERO else 0.0)
		var panels := maxi(1, ceili((finish - start) / panel_length))
		var step := (finish - start) / panels
		for k in panels:
			var t0 := start + k * step
			var mid := a + dir * (t0 + step * 0.5)
			var depth := lerpf(a3.z, b3.z, clampf((t0 + step * 0.5) / length, 0.0, 1.0))
			if depth < 0.6:
				continue  # rampas de entrada e saída: sem parede
			var floor_y := terrain.height_at(mid.x, mid.y)
			var edge := mid + side * s * (wall_offset + 1.6)
			var top := terrain.height_at(edge.x, edge.y) + wall_above_ground
			var height := top - floor_y + 0.15
			var center := mid + side * s * wall_offset
			var wall_pos := Vector3(center.x, floor_y - 0.15 + height * 0.5, center.y)
			_box(_planks, Transform3D(basis, wall_pos), Vector3(0.07, height, step + 0.02))
			_collider(Transform3D(basis, wall_pos), Vector3(0.12, height, step + 0.02))
			var post := mid + side * s * (wall_offset - 0.06) - dir * step * 0.5
			_box(_planks, Transform3D(basis, Vector3(post.x, floor_y - 0.1 + (height + 0.15) * 0.5, post.y)),
				Vector3(0.11, height + 0.15, 0.11))
			_sandbags(mid + side * s * (wall_offset + 0.45), dir, step, top - 0.08, yaw)
	# Estrado: ripas atravessadas no fundo (só no trecho do próprio segmento).
	var n := int(length / 0.34)
	for j in n:
		var t := (j + 0.5) * length / n
		var depth := lerpf(a3.z, b3.z, t / length)
		if depth < 0.6:
			continue
		var p := a + dir * t
		_box(_planks, Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), Vector3(p.x, terrain.height_at(p.x, p.y) + 0.03, p.y)),
			Vector3(0.09, 0.04, wall_offset * 2.0 - 0.12))


## Quanto a parede do lado `s` passa da quina (positivo) ou recua (negativo).
## A curva vai para o lado esquerdo (+1) se `to` gira no sentido anti-horário a partir de `from`.
func _corner_extension(from: Vector2, to: Vector2, s: float) -> float:
	var turn := signf(from.cross(to))
	if is_zero_approx(turn):
		return 0.0
	var half_angle := absf(from.angle_to(to)) * 0.5
	var amount := wall_offset * tan(half_angle) + 0.05
	return -amount if s == turn else amount


func _sandbags(center: Vector2, dir: Vector2, length: float, base_y: float, yaw: float) -> void:
	for row in 2:
		var count := int(length / 0.52)
		for k in count:
			var along := (k + 0.5 + (0.5 if row == 1 else 0.0)) * length / count - length * 0.5
			if absf(along) > length * 0.5:
				continue
			var p := center + dir * along
			var basis := Basis(Vector3.UP, yaw + _rng.randf_range(-0.12, 0.12)) \
				* Basis(Vector3.FORWARD, _rng.randf_range(-0.06, 0.06))
			_box(_bags, Transform3D(basis, Vector3(p.x, base_y + 0.09 + row * 0.17, p.y)),
				Vector3(0.34, 0.17, 0.5) * _rng.randf_range(0.92, 1.08))


func _collider(xform: Transform3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xform
	_body.add_child(shape)


## Caixa (6 faces) com normais e UV, já transformada, na malha dada.
func _box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)],
		[Vector3.LEFT, Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3.UP, Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3.DOWN, Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)],
		[Vector3.BACK, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.FORWARD, Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)],
	]
	for f in faces:
		var normal: Vector3 = (xform.basis * (f[0] as Vector3)).normalized()
		var v: Array[Vector3] = []
		for c in range(1, 5):
			v.append(xform * (f[c] as Vector3))
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(normal)
			st.set_uv(Vector2(v[idx].x + v[idx].z, v[idx].y))
			st.add_vertex(v[idx])


func _add_mesh(st: SurfaceTool, material: Material, mesh_name: String) -> void:
	st.set_material(material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = st.commit()
	add_child(mesh_instance)
