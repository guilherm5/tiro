extends SceneTree
# Acrescenta à fase demo_praia a vegetação e os objetos de cena e salva a cena.
# Idempotente: não duplica nós que já existem.
# Uso: godot --headless --path . -s $PWD/tools/montar_cenario.gd
const CENA := "res://levels/demo_praia/demo_praia.tscn"
var root_node: Node

func _initialize() -> void:
	var packed: PackedScene = load(CENA)
	root_node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var geo := root_node.get_node("Geometria")
	var terreno = geo.get_node("Terreno")

	if not geo.has_node("Vegetacao"):
		var v := Node3D.new(); v.name = "Vegetacao"
		v.set_script(load("res://levels/props/vegetacao.gd"))
		v.grass_shader = load("res://levels/props/grama.gdshader")
		_add(geo, v)
		geo.move_child(v, terreno.get_index() + 1)
		v.terrain = terreno

	# Bunker: concreto camuflado e detalhes (laje saliente, aba sobre a seteira, moldura
	# recuada, muros laterais). Uniões entram antes das subtrações do combinador.
	var bunker: CSGCombiner3D = geo.get_node("Bunker")
	var camo: Material = load("res://assets/materiais/concreto_camuflado.tres")
	bunker.get_node("Corpo").material = camo
	var uniao := [
		["Laje", Vector3(13.0, 0.6, 9.0), Vector3(0, 3.9, 0), 0.0],
		["Aba", Vector3(6.6, 0.3, 1.1), Vector3(0, 2.75, 4.45), 0.0],
		["MuroLateralEsq", Vector3(0.8, 2.4, 3.6), Vector3(-6.6, 1.2, 5.0), 25.0],
		["MuroLateralDir", Vector3(0.8, 2.4, 3.6), Vector3(6.6, 1.2, 5.0), -25.0],
	]
	for i in uniao.size():
		var u: Array = uniao[i]
		if bunker.has_node(u[0]): continue
		var b := CSGBox3D.new(); b.name = u[0]; b.size = u[1]; b.material = camo
		_add(bunker, b)
		bunker.move_child(b, 1 + i)
		b.position = u[2]
		b.rotation.y = deg_to_rad(u[3])
	for r in [["Moldura", Vector3(6.2, 1.5, 0.6), Vector3(0, 1.95, 4.0)], ["MolduraExterna", Vector3(7.2, 2.0, 0.3), Vector3(0, 1.95, 4.0)]]:
		if bunker.has_node(r[0]): continue
		var m := CSGBox3D.new(); m.name = r[0]; m.size = r[1]; m.operation = CSGShape3D.OPERATION_SUBTRACTION
		m.material = camo
		_add(bunker, m)
		m.position = r[2]

	# Caixotes de munição e de material perto da trincheira e da porta do bunker.
	terreno._noise.seed = 1944
	terreno._noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terreno._noise.frequency = 0.02
	var itens := geo.get_node_or_null("Objetos")
	if itens == null:
		itens = Node3D.new(); itens.name = "Objetos"
		_add(geo, itens)
	var caixote: PackedScene = load("res://assets/modelos/old_military_crate/old_military_crate.gltf")
	var municao: PackedScene = load("res://assets/modelos/ammo_box/ammo_box.gltf")
	# nome, modelo, x, z, giro
	var lista := [
		["Caixote1", caixote, -21.5, -61.6, 15.0], ["Caixote2", caixote, -22.3, -62.3, -30.0],
		["Caixote3", caixote, -33.5, -57.2, 80.0],
		["Municao1", municao, -9.0, -44.9, 10.0], ["Municao2", municao, -16.8, -48.6, 70.0],
		["Municao3", municao, -19.3, -56.0, -20.0], ["Municao4", municao, -21.0, -61.0, 40.0],
		["Municao5", municao, -31.5, -53.0, 0.0],
	]
	for o in lista:
		var n: Node3D = itens.get_node_or_null(NodePath(o[0]))
		if n == null:
			n = (o[1] as PackedScene).instantiate()
			n.name = o[0]
			_add(itens, n)
		# Dentro do bunker, o piso fica 20 cm acima da base.
		var dentro: bool = absf(o[2] - bunker.position.x) < 5.3 and absf(o[3] - bunker.position.z) < 3.3
		var y: float = bunker.position.y + 0.2 if dentro else terreno.height_at(o[2], o[3])
		n.position = Vector3(o[2], y, o[3])
		n.rotation.y = deg_to_rad(o[4])

	# Interior do bunker: posto do metralhador com mesa, telefone, lampião e munição.
	var interior := itens.get_node_or_null("BunkerInterior")
	if interior == null:
		interior = Node3D.new(); interior.name = "BunkerInterior"
		_add(itens, interior)
	interior.position = bunker.position + Vector3(0, 0.2, 0)  # piso do bunker
	var m := "res://assets/modelos/%s/%s.glb"
	# nome, cena, posição (local ao piso), giro (graus), colisão (tamanho da caixa ou ZERO)
	var objetos := [
		["Mesa", "res://assets/modelos/WoodenTable_01/WoodenTable_01.gltf", Vector3(-3.4, 0, -1.6), 90.0, Vector3(0.75, 0.55, 1.25)],
		["Banco", m % ["caixote_municao_ww2", "caixote_municao_ww2"], Vector3(-2.6, 0, -1.4), 75.0, Vector3.ZERO],
		["Telefone", m % ["telefone_campanha", "telefone_campanha"], Vector3(-3.5, 0.78, -2.0), 70.0, Vector3.ZERO],
		["Lampiao", m % ["lampiao", "lampiao"], Vector3(-3.3, 0.78, -1.0), 0.0, Vector3.ZERO],
		["Binoculo", m % ["binoculo", "binoculo"], Vector3(-3.2, 0.78, -1.7), 35.0, Vector3.ZERO],
		["Capacete", m % ["capacete_stahlhelm", "capacete_stahlhelm"], Vector3(-3.6, 0.78, -1.4), 160.0, Vector3.ZERO],
		["CaixaMG1", m % ["caixa_municao_mg42", "caixa_municao_mg42"], Vector3(1.3, 0, 2.6), 10.0, Vector3.ZERO],
		["CaixaMG2", m % ["caixa_municao_mg42", "caixa_municao_mg42"], Vector3(1.35, 0.17, 2.55), -5.0, Vector3.ZERO],
		["CaixaMG3", m % ["caixa_municao_mg42", "caixa_municao_mg42"], Vector3(-1.4, 0, 2.7), 80.0, Vector3.ZERO],
		["CaixaMG4", m % ["caixa_municao_mg42", "caixa_municao_mg42"], Vector3(1.8, 0, 2.2), 30.0, Vector3.ZERO],
		["Caixote1", m % ["caixote_municao_ww2", "caixote_municao_ww2"], Vector3(-4.7, 0, 1.2), 90.0, Vector3(0.36, 0.32, 0.8)],
		["Caixote2", m % ["caixote_municao_ww2", "caixote_municao_ww2"], Vector3(-4.7, 0.16, 1.2), 85.0, Vector3.ZERO],
		["Granadas", m % ["granada_haste", "granada_haste"], Vector3(-4.7, 0.32, 1.1), 20.0, Vector3.ZERO],
		["Caixotes", m % ["caixotes_madeira_ww2", "caixotes_madeira_ww2"], Vector3(-4.4, 0, -2.7), 0.0, Vector3(1.3, 0.9, 0.5)],
		["Caixote3", "res://assets/modelos/old_military_crate/old_military_crate.gltf", Vector3(4.5, 0, 1.4), 90.0, Vector3(0.6, 0.5, 1.0)],
		["Caixote4", "res://assets/modelos/old_military_crate/old_military_crate.gltf", Vector3(4.5, 0, 0.2), 95.0, Vector3(0.6, 0.5, 1.0)],
		["CaixaMG5", m % ["caixa_municao_mg42", "caixa_municao_mg42"], Vector3(4.5, 0.5, 1.3), 0.0, Vector3.ZERO],
	]
	var sobre_mesa := ["Telefone", "Lampiao", "Binoculo", "Capacete"]
	var topo_mesa := 0.0
	for o in objetos:
		var n: Node3D = interior.get_node_or_null(NodePath(o[0]))
		if n == null:
			n = (load(o[1]) as PackedScene).instantiate()
			n.name = o[0]
			_add(interior, n)
			var box: Vector3 = o[4]
			if box != Vector3.ZERO:
				var body := StaticBody3D.new(); body.name = "Colisao"
				body.set_meta(&"surface", &"madeira")
				_add(n, body)
				var shape := CollisionShape3D.new(); shape.name = "Forma"
				var bs := BoxShape3D.new(); bs.size = box
				shape.shape = bs
				_add(body, shape)
				shape.position.y = box.y * 0.5
		n.position = o[2]
		n.rotation.y = deg_to_rad(o[3])
		if o[0] == "Mesa":
			n.scale = Vector3(1.2, 1.35, 1.2)  # o modelo é baixo (55 cm)
			topo_mesa = _altura(n) * n.scale.y
		elif o[0] in sobre_mesa:
			n.position.y = topo_mesa
	# Fuzis encostados na parede do fundo.
	var kar: PackedScene = load("res://assets/armas/kar98k/kar98k.glb")
	for i in 3:
		var nome := "Fuzil%d" % (i + 1)
		var f: Node3D = interior.get_node_or_null(NodePath(nome))
		if f == null:
			f = kar.instantiate(); f.name = nome
			_add(interior, f)
		# Coronha no chão, cano para cima apoiado na parede (o modelo tem o cano para -Z).
		f.rotation = Vector3(deg_to_rad(72.0), deg_to_rad(5.0 * i), 0.0)
		f.position = Vector3(-0.2 + i * 0.35, 0.56, -2.95)

	# Prateleira na parede da direita, com capacete e munição.
	var prateleira: Node3D = interior.get_node_or_null("Prateleira")
	if prateleira == null:
		prateleira = Node3D.new(); prateleira.name = "Prateleira"
		_add(interior, prateleira)
		var madeira: Material = load("res://assets/materiais/madeira_tabuas.tres")
		for h in [1.0, 1.55]:
			var tabua := CSGBox3D.new(); tabua.name = "Tabua%d" % int(h * 100)
			tabua.size = Vector3(0.4, 0.05, 1.6); tabua.material = madeira
			_add(prateleira, tabua)
			tabua.position = Vector3(0, h, 0)
		for z in [-0.75, 0.75]:
			var apoio := CSGBox3D.new(); apoio.name = "Apoio%d" % int(z * 100 + 100)
			apoio.size = Vector3(0.05, 1.6, 0.05); apoio.material = madeira
			_add(prateleira, apoio)
			apoio.position = Vector3(0.15, 0.8, z)
		var cap2: Node3D = (load(m % ["capacete_stahlhelm", "capacete_stahlhelm"]) as PackedScene).instantiate()
		cap2.name = "Capacete2"; _add(prateleira, cap2); cap2.position = Vector3(0, 1.57, -0.4)
		var cx: Node3D = (load(m % ["caixa_municao_mg42", "caixa_municao_mg42"]) as PackedScene).instantiate()
		cx.name = "CaixaMG"; _add(prateleira, cx); cx.position = Vector3(0, 1.02, 0.3); cx.rotation.y = PI * 0.5
		var gr: Node3D = (load(m % ["granada_haste", "granada_haste"]) as PackedScene).instantiate()
		gr.name = "Granadas"; _add(prateleira, gr); gr.position = Vector3(0, 1.02, -0.4)
	prateleira.position = Vector3(5.05, 0, -1.6)

	# Cápsulas deflagradas no chão, em volta da MG.
	if not interior.has_node("Capsulas"):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var capsula := CylinderMesh.new()
		capsula.top_radius = 0.0055; capsula.bottom_radius = 0.006; capsula.height = 0.057; capsula.radial_segments = 6
		var latao := StandardMaterial3D.new()
		latao.albedo_color = Color(0.55, 0.42, 0.18); latao.metallic = 0.85; latao.roughness = 0.35
		capsula.material = latao
		mm.mesh = capsula
		mm.instance_count = 70
		var rng := RandomNumberGenerator.new(); rng.seed = 42
		for i in 70:
			var ang := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 1.1
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5)
			mm.set_instance_transform(i, Transform3D(b, Vector3(0.6 + cos(ang) * r, 0.006, 2.2 + sin(ang) * r * 0.6)))
		var mmi := MultiMeshInstance3D.new(); mmi.name = "Capsulas"; mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(interior, mmi)

	for velho in ["Cadeira", "SacosAreia"]:
		if interior.has_node(velho): interior.get_node(velho).free()

	# A luz do bunker sai do lampião em cima da mesa.
	var luz := geo.get_node_or_null("LuzBunker") as OmniLight3D
	if luz:
		luz.position = interior.position + Vector3(-3.3, topo_mesa + 0.5, -1.0)  # acima do lampião (o modelo faria sombra)
		luz.omni_range = 9.0
		luz.light_energy = 2.2
		luz.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		luz.shadow_bias = 0.08
		luz.shadow_normal_bias = 2.0

	# Defesas da praia: portões belgas na água funda, rampas e estacas com minas na faixa da
	# maré (os ouriços já estavam na fase). Ficam em Obstaculos (entram na navegação).
	var obstaculos := geo.get_node("Obstaculos")
	var obst_cena: PackedScene = load("res://levels/props/obstaculo_praia.tscn")
	var rng := RandomNumberGenerator.new(); rng.seed = 1944
	var defesas := []
	for x in [-44.0, -22.0, 9.0, 27.0, 46.0]:
		defesas.append(["portao", x + rng.randf_range(-3, 3), rng.randf_range(61, 68)])
	for i in 13:
		var x := -55.0 + i * 9.0 + rng.randf_range(-3, 3)
		if absf(x) < 3.0: x += 5.0  # corredor livre em frente à rampa do barco
		defesas.append(["rampa", x, rng.randf_range(45, 56)])
	for i in 16:
		var x := -58.0 + i * 7.6 + rng.randf_range(-2.5, 2.5)
		if absf(x) < 2.5: x -= 4.0
		defesas.append(["estaca", x, rng.randf_range(34, 48)])
	for i in defesas.size():
		var d: Array = defesas[i]
		var nome := "%s%02d" % [String(d[0]).capitalize(), i]
		var o: Node3D = obstaculos.get_node_or_null(NodePath(nome))
		if o == null:
			o = obst_cena.instantiate()
			o.name = nome
			o.kind = d[0]
			o.variation_seed = 100 + i
			_add(obstaculos, o)
			if d[0] == "portao":
				o.add_to_group(&"terreno_plano", true)
				o.set_meta(&"raio_plano", 2.5)
		o.position = Vector3(d[1], terreno.height_at(d[1], d[2]), d[2])
		o.rotation.y = rng.randf_range(-0.35, 0.35)

	# Barcos ao fundo: o casco de caixas vira o modelo do LCVP (a proa para a praia, -Z).
	var lcvp: PackedScene = load("res://assets/modelos/lcvp/lcvp.glb")
	for barco in root_node.get_node("Atmosfera/BarcosAoFundo").get_children():
		for velho in ["Casco", "Interior"]:
			if barco.has_node(velho): barco.get_node(velho).free()
		if not barco.has_node("Modelo"):
			var mdl: Node3D = lcvp.instantiate(); mdl.name = "Modelo"
			_add(barco, mdl)
			mdl.position = Vector3(0, -0.9, 0)
			mdl.rotation.y = PI if OS.get_environment("LCVP_GIRAR") == "1" else 0.0

	# Barco do jogador: o modelo do LCVP (sem a rampa, que é a peça animada RampaPivot)
	# no lugar do casco de caixas, que fica invisível mas continua dando a colisão.
	var emb: CSGCombiner3D = geo.get_node("Embarcacao")
	emb.visible = false
	var lcvp_jogador: Node3D = geo.get_node_or_null("EmbarcacaoModelo")
	if lcvp_jogador == null:
		lcvp_jogador = (load("res://assets/modelos/lcvp/lcvp_sem_rampa.glb") as PackedScene).instantiate()
		lcvp_jogador.name = "EmbarcacaoModelo"
		_add(geo, lcvp_jogador)
	# Proa cortada em z = -4,95 do modelo fica na dobradiça da rampa; esticado 15% para o
	# porão caber o esquadrão; o piso do porão (0,85 m) na altura do piso da cena.
	lcvp_jogador.scale = Vector3(1.0, 1.0, 1.15)
	lcvp_jogador.position = Vector3(0.0, -1.35 - 0.85, 79.5 + 4.95 * 1.15)
	# A rampa animada no tamanho da abertura da proa do modelo. A caixa dá a colisão; o
	# visual é a rampa recortada do próprio modelo, presa ao pivô (gira junto).
	var rampa: CSGBox3D = geo.get_node("RampaPivot/Rampa")
	rampa.size = Vector3(3.0, 2.05, 0.12)
	rampa.position = Vector3(0.0, 1.025, 0.0)
	rampa.visible = false
	var pivo: Node3D = geo.get_node("RampaPivot")
	var rampa_modelo: Node3D = pivo.get_node_or_null("RampaModelo")
	if rampa_modelo == null:
		rampa_modelo = (load("res://assets/modelos/lcvp/lcvp_rampa.glb") as PackedScene).instantiate()
		rampa_modelo.name = "RampaModelo"
		_add(pivo, rampa_modelo)
	# Mesma posição do casco, no espaço do pivô (o pivô fica na dobradiça, em repouso).
	rampa_modelo.transform = pivo.transform.affine_inverse() * lcvp_jogador.transform
	# A água não aparece dentro do casco: hull_min/hull_max em assets/materiais/mar.tres.

	# Esquadrão no barco: mais perto do centro (as longarinas do LCVP ficam por dentro do
	# casco de caixas antigo).
	var no_barco := {"Miller": 0.55, "Reed": -0.7, "Walker": 0.7, "Soldado1": -0.7, "Soldado2": 0.7}
	for nome in no_barco:
		var a: Node3D = root_node.get_node("Aliados/" + nome)
		a.position.x = no_barco[nome]

	# Navios de apoio no horizonte (a neblina os deixa em silhueta).
	var atmos := root_node.get_node("Atmosfera")
	var navio: PackedScene = load("res://assets/modelos/contratorpedeiro/contratorpedeiro.glb")
	for n in [["Navio1", Vector3(-160, -5.5, 520), 75.0], ["Navio2", Vector3(90, -5.5, 610), 100.0], ["Navio3", Vector3(320, -5.5, 470), 80.0]]:
		var nv: Node3D = atmos.get_node_or_null(NodePath(n[0]))
		if nv != null and nv.get_script() == null:
			nv.free(); nv = null
		if nv == null:
			nv = Node3D.new(); nv.name = n[0]
			nv.set_script(load("res://levels/props/tingir_modelo.gd"))
			_add(atmos, nv)
			var mdl: Node3D = navio.instantiate(); mdl.name = "Modelo"
			_add(nv, mdl)
		nv.tint = Color(0.3, 0.32, 0.34)
		nv.flat = true
		nv.position = n[1]; nv.rotation.y = deg_to_rad(n[2])

	# Destroços na praia: LCVPs encalhados e um Sherman destruído (com fogo), com colisão.
	var lcvp_aberto: PackedScene = load("res://assets/modelos/lcvp_aberto/lcvp_aberto.glb")
	var sherman: PackedScene = load("res://assets/modelos/sherman_destruido/sherman_destruido.glb")
	var fogo: PackedScene = load("res://systems/fx/fire.tscn")
	# nome, cena, x, z, giro, inclinação (graus), caixa de colisão, superfície
	var destrocos := [
		["LCVPEncalhado1", lcvp_aberto, -31.0, 60.0, 25.0, 6.0, Vector3(3.0, 2.2, 10.0), &"metal"],
		["LCVPEncalhado2", lcvp_aberto, 38.0, 54.0, -160.0, -4.0, Vector3(3.0, 2.2, 10.0), &"metal"],
		["Sherman", sherman, 17.0, 26.0, 35.0, 3.0, Vector3(3.0, 2.4, 6.0), &"metal"],
	]
	for d in destrocos:
		var w: Node3D = obstaculos.get_node_or_null(NodePath(d[0]))
		if w == null:
			w = StaticBody3D.new(); w.name = d[0]
			w.set_meta(&"surface", d[7])
			_add(obstaculos, w)
			var mdl: Node3D = (d[1] as PackedScene).instantiate(); mdl.name = "Modelo"
			_add(w, mdl)
			var shape := CollisionShape3D.new(); shape.name = "Forma"
			var box := BoxShape3D.new(); box.size = d[6]; shape.shape = box
			_add(w, shape)
			shape.position.y = (d[6] as Vector3).y * 0.5
			if d[0] == "Sherman":
				var f: Node3D = fogo.instantiate(); f.name = "Fogo"
				_add(w, f)
				f.position = Vector3(0, 2.1, -0.8)
		w.position = Vector3(d[2], terreno.height_at(d[2], d[3]) - 0.25, d[3])
		w.rotation = Vector3(deg_to_rad(d[5]), deg_to_rad(d[4]), 0.0)

	# Casas no alto da encosta (Vierville), de frente para o mar.
	var casa: PackedScene = load("res://assets/modelos/casa_francesa/casa_francesa.glb")
	for c in [["Casa1", 28.0, -98.0, 190.0], ["Casa2", -62.0, -104.0, 160.0], ["Casa3", 75.0, -108.0, 200.0]]:
		var h: Node3D = itens.get_node_or_null(NodePath(c[0]))
		if h != null and h.get_script() == null:
			h.free(); h = null
		if h == null:
			h = Node3D.new(); h.name = c[0]
			h.set_script(load("res://levels/props/tingir_modelo.gd"))
			_add(itens, h)
			var mdl: Node3D = casa.instantiate(); mdl.name = "Modelo"
			_add(h, mdl)
		h.tint = Color(0.62, 0.6, 0.56)  # pedra suja de fumaça e chuva
		h.position = Vector3(c[1], terreno.height_at(c[1], c[2]) - 0.3, c[2])
		h.rotation.y = deg_to_rad(c[3])

	# Capacetes americanos largados na areia, perto da água.
	var cap_m1: PackedScene = load("res://assets/modelos/capacete_m1/capacete_m1.glb")
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 6
	for i in 14:
		var nome := "CapaceteM1_%02d" % i
		var cp: Node3D = itens.get_node_or_null(NodePath(nome))
		if cp == null:
			cp = cap_m1.instantiate(); cp.name = nome
			_add(itens, cp)
		var x := rng2.randf_range(-45, 45)
		var z := rng2.randf_range(8, 42)
		cp.position = Vector3(x, terreno.height_at(x, z) - 0.03, z)
		cp.rotation = Vector3(rng2.randf_range(-0.6, 0.6), rng2.randf() * TAU, rng2.randf_range(-0.6, 0.6))

	# Destroços da praia: soldados caídos (com o fuzil ao lado), galões, bazucas, rádio e
	# caixas de munição, espalhados entre a água e o muro.
	var praia := itens.get_node_or_null("Praia")
	if praia == null:
		praia = Node3D.new(); praia.name = "Praia"
		_add(itens, praia)
	var corpo_script: Script = load("res://levels/props/corpo.gd")
	var americano: PackedScene = load("res://assets/personagens/americano/soldado_americano.glb")
	var garand: PackedScene = load("res://assets/armas/m1_garand/m1_garand.glb")
	var rng3 := RandomNumberGenerator.new(); rng3.seed = 1906
	# corpos: x, z
	var corpos := [[-6.0, 47.0], [4.5, 40.0], [-17.0, 36.0], [13.0, 33.0], [-27.0, 44.0], [24.0, 41.0], [-9.0, 22.0], [31.0, 18.0], [-36.0, 25.0]]
	for i in corpos.size():
		var nome := "Corpo%02d" % i
		var c: Node3D = praia.get_node_or_null(NodePath(nome))
		if c == null:
			c = Node3D.new(); c.name = nome
			c.set_script(corpo_script)
			_add(praia, c)
			c.model_scene = americano
			var f: Node3D = garand.instantiate(); f.name = "Fuzil"
			_add(c, f)
		var x: float = corpos[i][0]; var z: float = corpos[i][1]
		c.position = Vector3(x, terreno.height_at(x, z) + 0.02, z)
		c.rotation.y = rng3.randf() * TAU
		var fz: Node3D = c.get_node("Fuzil")
		fz.position = Vector3(rng3.randf_range(-0.9, 0.9), 0.04, rng3.randf_range(-0.9, 0.9))
		fz.rotation = Vector3(0, rng3.randf() * TAU, PI * 0.5)
	var soltos := []
	for i in 6: soltos.append(["Galao%02d" % i, "res://assets/modelos/galao/galao.glb"])
	for i in 2: soltos.append(["Bazuca%02d" % i, "res://assets/modelos/bazuca/bazuca.glb"])
	soltos.append(["Radio", "res://assets/modelos/radio_scr300/radio_scr300.glb"])
	for i in 6: soltos.append(["CaixaMun%02d" % i, "res://assets/modelos/ammo_box/ammo_box.gltf"])
	for o in soltos:
		var n: Node3D = praia.get_node_or_null(NodePath(o[0]))
		if n == null:
			n = (load(o[1]) as PackedScene).instantiate(); n.name = o[0]
			_add(praia, n)
		var x := rng3.randf_range(-40, 40)
		var z := rng3.randf_range(10, 46)
		n.position = Vector3(x, terreno.height_at(x, z) - 0.02, z)
		# Deitados de lado ou de pé, girados ao acaso.
		var deitado := rng3.randf() < 0.6 and not String(o[0]).begins_with("Bazuca")
		n.rotation = Vector3(PI * 0.5 if deitado else 0.0, rng3.randf() * TAU, 0.0)
		if deitado: n.position.y += 0.08
		if String(o[0]).begins_with("Bazuca"):
			n.rotation = Vector3(0, rng3.randf() * TAU, 0.0)

	# Sombras do sol: 2 faixas e 100 m (4 faixas a 150 m custavam ~6 ms na Iris Xe).
	var sol: DirectionalLight3D = root_node.get_node("Sol")
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sol.directional_shadow_max_distance = 100.0
	# Objetos pequenos ou distantes não projetam sombra (não aparece e custa).
	var sem_sombra := [atmos.get_node("BarcosAoFundo"), praia]
	for n in ["Navio1", "Navio2", "Navio3"]: sem_sombra.append(atmos.get_node(n))
	for n in ["Casa1", "Casa2", "Casa3"]: sem_sombra.append(itens.get_node(n))
	for i in 14: sem_sombra.append(itens.get_node("CapaceteM1_%02d" % i))
	for raiz in sem_sombra:
		raiz.set_meta(&"sem_sombra", true)
	if not root_node.has_node("DesligarSombras"):
		var ds := Node.new(); ds.name = "DesligarSombras"
		ds.set_script(load("res://levels/props/desligar_sombras.gd"))
		_add(root_node, ds)

	# Céu de tempestade e luz de manhã nublada: sol baixo e lateral, ambiente mais fraco
	# (mais contraste e volume), neblina mais densa sobre o mar, cor de película.
	var env: Environment = (root_node.get_node("WorldEnvironment") as WorldEnvironment).environment
	var ceu := (env.sky.sky_material as PanoramaSkyMaterial)
	ceu.panorama = load("res://assets/ceus/overcast_soil_puresky_4k.hdr")
	ceu.energy_multiplier = 0.85
	env.ambient_light_energy = 0.65
	env.tonemap_exposure = 1.0
	env.fog_light_color = Color(0.5, 0.53, 0.54)
	env.fog_density = 0.0045
	env.fog_height = -0.5
	env.fog_height_density = 0.06
	env.fog_aerial_perspective = 0.35
	env.adjustment_contrast = 1.18
	env.adjustment_saturation = 0.72
	var curva := Gradient.new()
	curva.set_color(0, Color(0.03, 0.035, 0.03))
	curva.set_color(1, Color(0.97, 0.97, 0.92))
	curva.add_point(0.5, Color(0.5, 0.52, 0.47))
	var lut := GradientTexture1D.new(); lut.gradient = curva
	env.adjustment_color_correction = lut
	sol.rotation_degrees = Vector3(-27.0, -62.0, 0.0)
	sol.light_color = Color(1.0, 0.93, 0.84)
	sol.light_energy = 1.35

	# Trilhas de terra subindo a encosta até as casas.
	var trilhas: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(9, -60), Vector2(13, -67), Vector2(8, -74), Vector2(15, -82), Vector2(22, -91), Vector2(27, -97)]),
		PackedVector2Array([Vector2(-46, -60), Vector2(-50, -70), Vector2(-56, -80), Vector2(-58, -92), Vector2(-61, -101)]),
	]
	terreno.paths = trilhas

	# Fundo: colinas e cercas vivas.
	if not geo.has_node("Horizonte"):
		var hz := Node3D.new(); hz.name = "Horizonte"
		hz.set_script(load("res://levels/props/horizonte.gd"))
		_add(geo, hz)
	geo.get_node("Horizonte").terrain = terreno

	# Rochas no pé da encosta e afloramentos (falésia) onde as laterais encontram o mar.
	var rochas := geo.get_node_or_null("Rochas")
	if rochas == null:
		rochas = Node3D.new(); rochas.name = "Rochas"
		rochas.set_meta(&"sem_sombra", true)
		_add(geo, rochas)
	var rocha_grande: PackedScene = load("res://assets/modelos/rock_face_01/rock_face_01.glb")
	var matacao: PackedScene = load("res://assets/modelos/namaqualand_boulder_02/namaqualand_boulder_02.glb")
	var pedras: PackedScene = load("res://assets/modelos/rock_moss_set_01/rock_moss_set_01.glb")
	var falesia: PackedScene = load("res://assets/modelos/coastal_cliff_01/coastal_cliff_01.glb")
	var rng4 := RandomNumberGenerator.new(); rng4.seed = 77
	var k := 0
	var x := -112.0
	while x < 112.0:
		x += rng4.randf_range(5.0, 11.0)
		if x > -42.0 and x < -12.0: continue  # bunker e trincheira
		if absf(x - 10.0) < 4.0 or absf(x + 47.0) < 4.0: continue  # trilhas
		var base_z: float = terreno._bluff_start(x) - rng4.randf_range(0.5, 4.0)
		var escolha := rng4.randf()
		var cena: PackedScene = rocha_grande if escolha < 0.35 else (matacao if escolha < 0.75 else pedras)
		var nome := "Rocha%02d" % k
		var r: Node3D = rochas.get_node_or_null(NodePath(nome))
		if r == null:
			r = cena.instantiate(); r.name = nome
			_add(rochas, r)
		r.position = Vector3(x, terreno.height_at(x, base_z) - 0.3, base_z)
		r.rotation = Vector3(rng4.randf_range(-0.15, 0.15), rng4.randf() * TAU, rng4.randf_range(-0.15, 0.15))
		r.scale = Vector3.ONE * rng4.randf_range(0.7, 1.5)
		k += 1
	# Falésias nas pontas da praia (as encostas laterais), em fileira ao longo de Z.
	var f := 0
	for lado in [-1.0, 1.0]:
		for z in [-50.0, -20.0, 10.0, 40.0]:
			var nome := "Falesia%d" % f
			var fl: Node3D = rochas.get_node_or_null(NodePath(nome))
			if fl == null:
				fl = falesia.instantiate(); fl.name = nome
				_add(rochas, fl)
			var fx: float = lado * (84.0 + rng4.randf_range(-3, 3))
			fl.position = Vector3(fx, terreno.height_at(fx, z) - 1.5, z)
			fl.rotation = Vector3(0, PI * 0.5 + (PI if lado > 0 else 0.0) + rng4.randf_range(-0.2, 0.2), 0)
			fl.scale = Vector3(1.15, 3.2, 1.6)
			f += 1

	# Colunas de fumaça escura ao longe (o interior em combate).
	var fumaca: PackedScene = load("res://systems/fx/fumaca_distante.tscn")
	for fd in [["FumacaLonge1", Vector3(-150, 20, -260)], ["FumacaLonge2", Vector3(60, 25, -330)], ["FumacaLonge3", Vector3(210, 18, -190)], ["FumacaLonge4", Vector3(-260, 15, -120)]]:
		if atmos.has_node(fd[0]): continue
		var fu: Node3D = fumaca.instantiate(); fu.name = fd[0]
		_add(atmos, fu)
		fu.position = fd[1]

	# Névoa de pólvora rasteira sobre a praia.
	if not atmos.has_node("NevoaRasteira"):
		var nv2 := GPUParticles3D.new(); nv2.name = "NevoaRasteira"
		nv2.set_script(load("res://systems/fx/nevoa_rasteira.gd"))
		_add(atmos, nv2)
	atmos.get_node("NevoaRasteira").position = Vector3(0, 0.6, 15)

	# Combate ao fundo: traçantes das pontas e do alto para o mar (e de volta) e aviões.
	var cf: Node3D = atmos.get_node_or_null("CombateAoFundo")
	if cf == null:
		cf = Node3D.new(); cf.name = "CombateAoFundo"
		cf.set_script(load("res://systems/fx/combate_ao_fundo.gd"))
		_add(atmos, cf)
	cf.sources = PackedVector3Array([Vector3(-98, 12, -30), Vector3(-105, 10, 5), Vector3(102, 11, -25),
		Vector3(96, 12, 10), Vector3(-70, 20, -85), Vector3(75, 20, -88)])
	cf.targets = PackedVector3Array([Vector3(-60, 0, 110), Vector3(-20, 0, 130), Vector3(30, 0, 120), Vector3(70, 0, 105),
		Vector3(-110, 0, 70), Vector3(115, 0, 75)])
	cf.plane_scene = load("res://levels/props/aviao.tscn")
	cf.plane_sound = load("res://assets/audio/ambiente/aviao_passando.mp3")

	# Marcas no chão: óleo nos destroços, sangue nos corpos, fuligem nas crateras, rastro
	# do tanque e pegadas saindo da água.
	var marcas: Node3D = geo.get_node_or_null("MarcasChao")
	if marcas == null:
		marcas = Node3D.new(); marcas.name = "MarcasChao"
		marcas.set_script(load("res://levels/props/marcas_chao.gd"))
		_add(geo, marcas)
	marcas.terrain = terreno
	var lista_m := []
	var rng5 := RandomNumberGenerator.new(); rng5.seed = 1212
	for d in [[17.0, 26.0, 5.0], [-31.0, 60.0, 4.0], [38.0, 54.0, 4.0]]:
		lista_m.append(["oleo", d[0] + rng5.randf_range(-1, 1), d[1] + rng5.randf_range(-1, 1), rng5.randf() * 360.0, Vector2(d[2], d[2])])
	for c in corpos:
		lista_m.append(["sangue", c[0] + rng5.randf_range(-0.5, 0.5), c[1] + rng5.randf_range(-0.5, 0.5), rng5.randf() * 360.0, Vector2.ONE * rng5.randf_range(1.2, 2.2)])
	for cr in terreno.craters:
		lista_m.append(["fuligem", cr.x, cr.y, rng5.randf() * 360.0, Vector2.ONE * cr.z * 2.6])
	# Rastro do tanque: da água até onde ele parou.
	var de := Vector2(9.0, 50.0); var ate := Vector2(17.0, 27.5)
	var meio := (de + ate) * 0.5; var dir := (ate - de)
	lista_m.append(["esteira", meio.x, meio.y, rad_to_deg(atan2(dir.x, dir.y)), Vector2(3.0, dir.length())])
	# Pegadas: da beira d'água subindo a praia.
	for i in 10:
		var px := rng5.randf_range(-40.0, 40.0)
		var pz := rng5.randf_range(26.0, 40.0)
		var giro := rng5.randf_range(-25.0, 25.0)
		lista_m.append(["pegadas", px, pz, giro, Vector2(0.7, rng5.randf_range(5.0, 9.0))])
	marcas.marks = lista_m
	# A água fica na camada visual 4: as marcas (camada 1) não a pintam.
	(geo.get_node("Agua") as MeshInstance3D).layers = 1 << 3

	# Muro: topo quebrado em alguns pontos (com ferragem exposta) e marcas de tiro.
	var aco: Material = load("res://assets/materiais/aco_enferrujado.tres")
	var rng6 := RandomNumberGenerator.new(); rng6.seed = 34
	for muro_nome in ["MuroEsquerdo", "MuroDireito", "MuroExtensaoEsq", "MuroExtensaoDir"]:
		var muro: CSGBox3D = geo.get_node(muro_nome)
		var largura: float = muro.size.x
		var n_quebras := int(largura / 9.0)
		for q in n_quebras:
			var nome := "Quebra%d" % q
			if muro.has_node(nome): continue
			var lx := -largura * 0.5 + (q + 0.5) * largura / n_quebras + rng6.randf_range(-2, 2)
			if absf(muro.position.x + lx) < 4.0: continue  # abertura do muro
			var corte := CSGBox3D.new(); corte.name = nome
			corte.operation = CSGShape3D.OPERATION_SUBTRACTION
			corte.size = Vector3(rng6.randf_range(0.8, 2.2), rng6.randf_range(0.5, 1.0), 1.0)
			_add(muro, corte)
			corte.position = Vector3(lx, muro.size.y * 0.5, 0)
			corte.rotation = Vector3(rng6.randf_range(-0.3, 0.3), 0, rng6.randf_range(-0.6, 0.6))
			# Vergalhões saindo da quebra.
			for v in rng6.randi_range(2, 4):
				var barra := MeshInstance3D.new(); barra.name = "%sVergalhao%d" % [nome, v]
				var cil := CylinderMesh.new(); cil.top_radius = 0.012; cil.bottom_radius = 0.012
				cil.height = rng6.randf_range(0.4, 0.9); cil.radial_segments = 5; cil.material = aco
				barra.mesh = cil
				_add(muro, barra)
				barra.position = Vector3(lx + rng6.randf_range(-0.5, 0.5), muro.size.y * 0.5 - 0.2, rng6.randf_range(-0.2, 0.2))
				barra.rotation = Vector3(rng6.randf_range(-0.5, 0.5), 0, rng6.randf_range(-0.6, 0.6))
	var parede := []
	for i in 22:
		var wx := rng6.randf_range(-74, 74)
		if absf(wx) < 3.0: continue
		parede.append(["tiros", wx, -34.2, 0.0, Vector2(rng6.randf_range(1.5, 3.0), rng6.randf_range(0.8, 1.4)), rng6.randf_range(1.4, 2.4)])
	# Fachada do bunker em volta da seteira (o bunker olha para +Z).
	var fachada_z: float = bunker.position.z + 4.45
	for i in 6:
		parede.append(["tiros", bunker.position.x + rng6.randf_range(-4.5, 4.5), fachada_z + 0.3, 0.0,
			Vector2(rng6.randf_range(1.5, 2.5), rng6.randf_range(1.0, 1.5)), bunker.position.y + rng6.randf_range(1.0, 3.2)])
	# Mapa na parede dos fundos, por dentro (a parede fica em -Z: o mapa projeta para -Z).
	parede.append(["mapa", bunker.position.x - 3.4, bunker.position.z - 2.95, 0.0, Vector2(1.3, 0.95), bunker.position.y + 1.75])
	var lista_atual: Array = marcas.marks
	marcas.marks = lista_atual + parede

	# Dentes de concreto em fileira, nas pontas da praia (longe do caminho principal).
	var d_i := 0
	for lado in [-1.0, 1.0]:
		for j in 7:
			var nome := "Dente%02d" % d_i
			var dx: float = lado * (38.0 + j * 4.5 + rng6.randf_range(-0.8, 0.8))
			var dz := -26.0 + rng6.randf_range(-1.0, 1.0)
			var dt: Node3D = obstaculos.get_node_or_null(NodePath(nome))
			if dt == null:
				dt = obst_cena.instantiate(); dt.name = nome
				dt.kind = "dente"; dt.variation_seed = 500 + d_i
				_add(obstaculos, dt)
			dt.position = Vector3(dx, terreno.height_at(dx, dz), dz)
			dt.rotation.y = rng6.randf_range(-0.3, 0.3)
			d_i += 1

	# Lâmpada pendurada no teto do bunker (fio, bocal, lâmpada e luz fraca).
	var lamp: Node3D = interior.get_node_or_null("Lampada")
	if lamp == null:
		lamp = Node3D.new(); lamp.name = "Lampada"
		lamp.set_script(load("res://levels/props/lampada_pendurada.gd"))
		_add(interior, lamp)
	lamp.position = Vector3(1.2, 2.4, 0.4)
	if not interior.has_node("PoeiraTeto"):
		var poeira := GPUParticles3D.new(); poeira.name = "PoeiraTeto"
		poeira.set_script(load("res://levels/props/poeira_teto.gd"))
		_add(interior, poeira)
	interior.get_node("PoeiraTeto").position = Vector3(0, 2.5, 0)

	var novo := PackedScene.new()
	var err := novo.pack(root_node)
	if err != OK:
		print("ERRO ao empacotar: ", err); quit(1); return
	print("salvo: ", ResourceSaver.save(novo, CENA) == OK)
	quit()

## Altura do topo dos modelos do nó (em relação à origem dele).
func _altura(n: Node3D) -> float:
	var topo := 0.0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		# Fora da árvore não há transformação global: compõe as locais até `n`.
		var xform := mesh_instance.transform
		var p := mesh_instance.get_parent()
		while p != n and p is Node3D:
			xform = (p as Node3D).transform * xform
			p = p.get_parent()
		topo = maxf(topo, (xform * mesh_instance.get_aabb()).end.y)
	return topo

func _add(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = root_node
