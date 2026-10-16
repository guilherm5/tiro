extends StaticBody3D
## Obstáculos de praia do Muro do Atlântico, gerados ao carregar (malha + colisão):
##  - ouriço tcheco: três cantoneiras de aço cruzadas, com chapa de reforço rebitada;
##  - portão belga ("Elemento C"): treliça de aço de 3 m com escoras para trás;
##  - rampa: tronco inclinado para o mar sobre um pé de apoio, com mina Teller na ponta;
##  - estaca: tronco fincado e inclinado, com mina Teller no topo;
##  - dente: "dente de dragão" de concreto (tronco de pirâmide), às vezes lascado.
## A frente (lado do mar) é +Z do nó.

@export_enum("ourico", "portao", "rampa", "estaca", "dente") var kind := "ourico"
@export var steel_material: Material
@export var wood_material: Material
@export var mine_material: Material
@export var concrete_material: Material
## Variação de tamanho e inclinação (semente própria por obstáculo).
@export var variation_seed := 0

var _rng := RandomNumberGenerator.new()
var _steel := SurfaceTool.new()
var _wood := SurfaceTool.new()
var _mine := SurfaceTool.new()
var _concrete := SurfaceTool.new()


func _ready() -> void:
	_rng.seed = variation_seed if variation_seed != 0 else hash(name)
	set_meta(&"surface", &"metal" if kind in ["ourico", "portao"] else (&"concreto" if kind == "dente" else &"madeira"))
	collision_mask = 0
	for st in [_steel, _wood, _mine, _concrete]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"ourico": _build_hedgehog()
		"portao": _build_gate()
		"rampa": _build_ramp()
		"estaca": _build_stake()
		"dente": _build_tooth()
	_commit(_steel, steel_material, "Aco")
	_commit(_concrete, concrete_material, "Concreto")
	_commit(_wood, wood_material, "Madeira")
	_commit(_mine, mine_material, "Mina")


# --- Tipos ------------------------------------------------------------------------

func _build_hedgehog() -> void:
	var length := _rng.randf_range(2.0, 2.4)
	var center := Vector3(0.0, length * 0.32, 0.0)
	# Três cantoneiras perpendiculares entre si, giradas 45° para apoiar em três pontas.
	var axes := [Vector3(1, 1, 0).normalized(), Vector3(-1, 1, 0).normalized(), Vector3(0, 1, 1).normalized()]
	var base := Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4))
	for axis: Vector3 in axes:
		var dir: Vector3 = base * axis
		_angle_iron(center - dir * length * 0.5, center + dir * length * 0.5, 0.16, 0.014)
		_collider_beam(center - dir * length * 0.5, center + dir * length * 0.5, 0.18)
	# Chapa de reforço no cruzamento, com rebites.
	_box(_steel, Transform3D(base, center), Vector3(0.34, 0.34, 0.02))
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		_box(_steel, Transform3D(base, center + base * Vector3(cos(a) * 0.12, sin(a) * 0.12, 0.015)), Vector3(0.03, 0.03, 0.02))


func _build_gate() -> void:
	var w := 3.0
	var h := _rng.randf_range(2.3, 2.6)
	var d := 2.2
	var post := 0.12
	# Face da frente: quadro, verticais e diagonais.
	for x in [-w * 0.5, -w / 6.0, w / 6.0, w * 0.5]:
		_beam(_steel, Vector3(x, 0, 0), Vector3(x, h, 0), post)
	_beam(_steel, Vector3(-w * 0.5, h, 0), Vector3(w * 0.5, h, 0), post)
	_beam(_steel, Vector3(-w * 0.5, h * 0.5, 0), Vector3(w * 0.5, h * 0.5, 0), post * 0.8)
	_beam(_steel, Vector3(-w * 0.5, 0.15, 0), Vector3(w * 0.5, 0.15, 0), post)
	for i in 3:
		var x0 := -w * 0.5 + i * w / 3.0
		_beam(_steel, Vector3(x0, 0.15, 0), Vector3(x0 + w / 3.0, h * 0.5, 0), post * 0.7)
		_beam(_steel, Vector3(x0 + w / 3.0, h * 0.5, 0), Vector3(x0, h, 0), post * 0.7)
	# Escoras para trás (o lado da terra) e trilhos de base com rodas.
	for x in [-w * 0.5, w * 0.5]:
		_beam(_steel, Vector3(x, 0.1, 0), Vector3(x, 0.1, -d), post)
		_beam(_steel, Vector3(x, h, 0), Vector3(x, 0.1, -d), post * 0.9)
		for z in [-0.2, -d + 0.2]:
			_cylinder(_steel, Vector3(x, 0.12, z), Vector3.RIGHT, 0.13, 0.08, 8)
	_beam(_steel, Vector3(-w * 0.5, 0.1, -d), Vector3(w * 0.5, 0.1, -d), post)
	_collider(Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)), Vector3(w + 0.1, h, 0.25))
	_collider(Transform3D(Basis.IDENTITY, Vector3(0, 0.3, -d * 0.5)), Vector3(w + 0.1, 0.6, d))


func _build_ramp() -> void:
	var length := _rng.randf_range(3.2, 4.0)
	var angle := deg_to_rad(_rng.randf_range(24.0, 32.0))
	var radius := _rng.randf_range(0.11, 0.14)
	var dir := Vector3(0, sin(angle), cos(angle))  # sobe na direção do mar
	var foot := Vector3(0, 0.05, -length * cos(angle) * 0.5)
	var top := foot + dir * length
	_cylinder(_wood, (foot + top) * 0.5, dir, radius, length, 9)
	_collider_beam(foot, top, radius * 2.0)
	# Pé de apoio vertical sob a parte alta, e uma travessa.
	var prop_at := foot + dir * length * 0.72
	_cylinder(_wood, Vector3(prop_at.x, prop_at.y * 0.5, prop_at.z), Vector3.UP, radius * 0.85, prop_at.y + 0.1, 8)
	_collider_beam(Vector3(prop_at.x, 0, prop_at.z), prop_at, radius * 1.7)
	_cylinder(_wood, prop_at + Vector3(0, -0.15, 0), Vector3.RIGHT, radius * 0.6, 0.7, 7)
	_teller_mine(top + dir * 0.02 + Vector3(0, radius * 0.6, 0), Basis(Vector3.RIGHT, -angle))


func _build_stake() -> void:
	var height := _rng.randf_range(1.8, 2.6)
	var tilt := deg_to_rad(_rng.randf_range(8.0, 22.0))
	var radius := _rng.randf_range(0.1, 0.13)
	var dir := Vector3(0, cos(tilt), sin(tilt))
	var base := Vector3(0, -0.3, 0)  # fincada na areia
	var top := base + dir * (height + 0.3)
	_cylinder(_wood, (base + top) * 0.5, dir, radius, height + 0.3, 9)
	_collider_beam(base, top, radius * 2.0)
	_teller_mine(top + dir * 0.05, Basis(Vector3.RIGHT, -tilt))


func _build_tooth() -> void:
	var base := _rng.randf_range(1.2, 1.6)
	var top := base * _rng.randf_range(0.25, 0.4)
	var height := _rng.randf_range(1.1, 1.6)
	var broken := _rng.randf() < 0.4  # um canto arrancado por explosão
	var b := base * 0.5
	var t := top * 0.5
	var lower := [Vector3(-b, -0.2, -b), Vector3(b, -0.2, -b), Vector3(b, -0.2, b), Vector3(-b, -0.2, b)]
	var upper := [Vector3(-t, height, -t), Vector3(t, height, -t), Vector3(t, height, t), Vector3(-t, height, t)]
	if broken:
		upper[2] = Vector3(t * 0.2, height * 0.7, t * 0.3)
	var inside := Vector3(0, height * 0.4, 0)
	for i in 4:
		var j := (i + 1) % 4
		_quad(_concrete, lower[i], lower[j], upper[j], upper[i], inside)
	_quad(_concrete, upper[0], upper[1], upper[2], upper[3], inside)
	_collider(Transform3D(Basis.IDENTITY, Vector3(0, height * 0.45, 0)), Vector3(base * 0.8, height, base * 0.8))


## Quadrilátero com a normal apontando para fora do sólido (centro `inside`). Os dois
## sentidos de giro são emitidos: só o que fica de frente aparece (não importa a ordem).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside := Vector3(0, 0.6, 0)) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c + d) * 0.25 - inside) < 0.0:
		normal = -normal
	for v: Vector3 in [a, b, c, a, c, d, a, c, b, a, d, c]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)


## Mina Teller 42: disco de 32 cm com o detonador no centro, presa ao topo do obstáculo.
func _teller_mine(at: Vector3, basis: Basis) -> void:
	_cylinder(_mine, at + basis * Vector3(0, 0.045, 0), basis.y, 0.16, 0.09, 14)
	_cylinder(_mine, at + basis * Vector3(0, 0.1, 0), basis.y, 0.05, 0.03, 10)
	_cylinder(_mine, at + basis * Vector3(0.17, 0.045, 0), basis.x, 0.025, 0.06, 6)  # alça


# --- Peças --------------------------------------------------------------------------

## Cantoneira (perfil em L) de `a` até `b`: duas chapas em ângulo reto.
func _angle_iron(a: Vector3, b: Vector3, flange: float, thick: float) -> void:
	var dir := (b - a).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	var center := (a + b) * 0.5
	var length := a.distance_to(b)
	_box(_steel, Transform3D(basis, center + basis * Vector3(flange * 0.5, 0, 0)), Vector3(flange, thick, length))
	_box(_steel, Transform3D(basis, center + basis * Vector3(0, flange * 0.5, 0)), Vector3(thick, flange, length))


## Viga de seção quadrada de `a` até `b`.
func _beam(st: SurfaceTool, a: Vector3, b: Vector3, size: float) -> void:
	var dir := (b - a).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	_box(st, Transform3D(basis, (a + b) * 0.5), Vector3(size, size, a.distance_to(b) + size))


## Cilindro com eixo `axis`, centrado em `center`.
func _cylinder(st: SurfaceTool, center: Vector3, axis: Vector3, radius: float, length: float, sides: int) -> void:
	var basis := Basis.looking_at(axis.normalized(), Vector3.UP if absf(axis.normalized().y) < 0.95 else Vector3.RIGHT)
	var half := length * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var n0 := basis * Vector3(cos(a0), sin(a0), 0)
		var n1 := basis * Vector3(cos(a1), sin(a1), 0)
		var p00 := center + n0 * radius - basis.z * half
		var p01 := center + n0 * radius + basis.z * half
		var p10 := center + n1 * radius - basis.z * half
		var p11 := center + n1 * radius + basis.z * half
		var u0 := float(i) / sides
		var u1 := float(i + 1) / sides
		for v: Array in [[p00, n0, Vector2(u0, 0)], [p10, n1, Vector2(u1, 0)], [p01, n0, Vector2(u0, length)],
				[p01, n0, Vector2(u0, length)], [p10, n1, Vector2(u1, 0)], [p11, n1, Vector2(u1, length)]]:
			st.set_normal(v[1]); st.set_uv(v[2]); st.add_vertex(v[0])
		for cap: float in [-1.0, 1.0]:
			var c := center + basis.z * half * cap
			var tri := [c, center + n0 * radius + basis.z * half * cap, center + n1 * radius + basis.z * half * cap]
			if cap < 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for p: Vector3 in tri:
				st.set_normal(basis.z * cap); st.set_uv(Vector2(p.x, p.z)); st.add_vertex(p)


## Caixa (6 faces) com normais e UV, já transformada.
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


func _collider(xform: Transform3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xform
	add_child(shape)


func _collider_beam(a: Vector3, b: Vector3, thickness: float) -> void:
	var dir := (b - a).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	_collider(Transform3D(basis, (a + b) * 0.5), Vector3(thickness, thickness, a.distance_to(b)))


func _commit(st: SurfaceTool, material: Material, mesh_name: String) -> void:
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return
	mesh.surface_set_material(0, material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
