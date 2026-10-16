# Efeitos visuais da luta: faíscas de acerto, anel de bloqueio, poeira de queda e o rastro
# da katana. Tudo leve (partículas na CPU, poucos polígonos), pensado para a Iris Xe.
class_name Efeitos
extends Node3D

var _textura_brilho: GradientTexture2D
var _rastros := {}   # Lutador -> {"malha": ImmediateMesh, "pontos": Array}


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_textura_brilho = GradientTexture2D.new()
	_textura_brilho.gradient = g
	_textura_brilho.fill = GradientTexture2D.FILL_RADIAL
	_textura_brilho.fill_from = Vector2(0.5, 0.5)
	_textura_brilho.fill_to = Vector2(0.5, 0.0)
	_textura_brilho.width = 64
	_textura_brilho.height = 64


func _material_aditivo(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _textura_brilho
	m.albedo_color = cor
	m.no_depth_test = true
	return m


# Acerto: clarão em estrela + faíscas. Bloqueio: clarão azul em anel, sem faíscas.
func acerto(ponto: Vector3, bloqueado: bool, forte: bool) -> void:
	var cor := Color(0.45, 0.75, 1.0) if bloqueado else Color(1.0, 0.75, 0.3)
	for k in (1 if bloqueado else 2):  # dois quads cruzados viram uma "estrela"
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.9, 0.18) if k == 0 and not bloqueado else Vector2(0.55, 0.55)
		q.mesh = qm
		var mat := _material_aditivo(cor * (1.6 if forte else 1.2))
		q.material_override = mat
		q.position = ponto
		q.rotation.z = randf() * PI
		add_child(q)
		var t := create_tween().set_parallel(true)
		t.tween_property(q, "scale", Vector3.ONE * (2.4 if forte else 1.7), 0.14)
		t.tween_property(mat, "albedo_color:a", 0.0, 0.16)
		t.chain().tween_callback(q.queue_free)
	if bloqueado:
		return
	var p := CPUParticles3D.new()
	p.position = ponto
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18 if forte else 10
	p.lifetime = 0.35
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5 if forte else 3.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	var qm2 := QuadMesh.new()
	qm2.size = Vector2(0.5, 0.5)
	p.mesh = qm2
	p.material_override = _material_aditivo(Color(1.0, 0.65, 0.25) * 1.5)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


# Poeira no chão (queda, aterrissagem pesada).
func poeira(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = Vector3(pos.x, 0.05, pos.z)
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 14
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, -0.6, 0)
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.5
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.6))
	curva.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = curva
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.6)
	p.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _textura_brilho
	m.albedo_color = Color(0.55, 0.47, 0.38, 0.35)
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	var cores := Gradient.new()
	cores.set_color(0, Color(1, 1, 1, 1))
	cores.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = cores
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


# Rastro da katana: fita entre a base e a ponta da lâmina nos últimos quadros do corte.
func atualizar_rastro(l: Lutador) -> void:
	if not _rastros.has(l):
		var mi := MeshInstance3D.new()
		var malha := ImmediateMesh.new()
		mi.mesh = malha
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_rastros[l] = {"malha": malha, "pontos": []}
	var r: Dictionary = _rastros[l]
	var pontos: Array = r["pontos"]
	var ativo := l.katana_mao != null and l.katana_mao.visible and l.estado == Lutador.E.GOLPE
	if ativo:
		pontos.push_front([l.ponta_katana(0.2), l.ponta_katana(1.0)])
		if pontos.size() > 9:
			pontos.pop_back()
	elif not pontos.is_empty():
		pontos.pop_back()
	var malha: ImmediateMesh = r["malha"]
	malha.clear_surfaces()
	if pontos.size() < 2:
		return
	malha.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pontos.size():
		var a := 1.0 - float(i) / pontos.size()
		var cor := Color(0.75, 0.85, 1.0, 0.7 * a)
		malha.surface_set_color(cor * Color(1, 1, 1, 0.3))
		malha.surface_add_vertex(pontos[i][0])
		malha.surface_set_color(cor)
		malha.surface_add_vertex(pontos[i][1])
	malha.surface_end()
