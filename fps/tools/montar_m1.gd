extends SceneTree
# Acrescenta à fase demo_praia os elementos da nova Missão 1 e salva a cena.
# Rodar uma vez (idempotente: não duplica nós que já existem).
const CENA := "res://levels/demo_praia/demo_praia.tscn"
const TRINCHEIRA := [Vector3(1, -40, 0), Vector3(0, -42.5, 1.1), Vector3(-6, -45, 1.1), Vector3(-11, -43.5, 1.1),
	Vector3(-15, -47, 1.1), Vector3(-18.5, -49, 1.1), Vector3(-18.5, -57, 1.1), Vector3(-21, -60, 1.0),
	Vector3(-25, -60, 0.6), Vector3(-25, -57.6, 0.0)]
var root_node: Node
var terreno

func _initialize() -> void:
	var packed: PackedScene = load(CENA)
	root_node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	terreno = root_node.get_node("Geometria/Terreno")
	terreno.trench = PackedVector3Array(TRINCHEIRA)
	# Mesmo ruído que o terreno usa em _build (sem o achatamento: erro de poucos cm).
	terreno._noise.seed = 1944
	terreno._noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terreno._noise.frequency = 0.02
	var geo := root_node.get_node("Geometria")

	# Revestimento da trincheira (logo depois do terreno: precisa das alturas dele).
	if not geo.has_node("Trincheira"):
		var t := Node3D.new(); t.name = "Trincheira"
		t.set_script(load("res://levels/props/trincheira.gd"))
		t.planks_material = load("res://assets/materiais/madeira_tabuas.tres")
		t.sandbag_material = load("res://assets/materiais/juta_sacos.tres")
		_add(geo, t)
		geo.move_child(t, terreno.get_index() + 1)
		t.terrain = terreno

	# Muros prolongados até as encostas (antes dava para contornar pelas pontas).
	for lado in [-1, 1]:
		var nome := "MuroExtensao" + ("Esq" if lado < 0 else "Dir")
		if geo.has_node(nome): continue
		var muro := CSGBox3D.new(); muro.name = nome
		muro.use_collision = true
		muro.size = Vector3(42, 1.8, 0.7)
		muro.material = load("res://assets/materiais/concreto_bunker.tres")
		muro.set_meta(&"surface", &"concreto")
		_add(geo, muro, ["navegacao", "terreno_plano"])
		muro.position = Vector3(lado * 55.5, 1.92, -35)

	# Arame farpado na frente da abertura do muro.
	if not geo.has_node("Arame"):
		var arame := Node3D.new(); arame.name = "Arame"
		arame.set_script(load("res://levels/props/arame_farpado.gd"))
		arame.stakes_material = load("res://assets/materiais/madeira_tabuas.tres")
		_add(geo, arame)
		arame.position = Vector3(0, _h(0, -33.3), -33.3)

	# Placa de aço na seteira: só as balas do jogador batem nela (camada 5).
	var bunker := geo.get_node("Bunker")
	if not geo.has_node("PlacaSeteira"):
		var placa := StaticBody3D.new(); placa.name = "PlacaSeteira"
		placa.collision_layer = 16
		placa.collision_mask = 0
		placa.set_meta(&"surface", &"metal")
		_add(geo, placa)
		placa.position = bunker.position + Vector3(0, 1.95, 3.86)
		var forma := CollisionShape3D.new(); forma.name = "Forma"
		var caixa := BoxShape3D.new(); caixa.size = Vector3(5.0, 0.62, 0.08)
		forma.shape = caixa
		_add(placa, forma)
		# Visual: chapa com uma fenda estreita para o cano.
		var aco: Material = load("res://assets/materiais/aco_enferrujado.tres")
		var chapa := CSGCombiner3D.new(); chapa.name = "Chapa"
		_add(placa, chapa)
		var corpo := CSGBox3D.new(); corpo.name = "Corpo"; corpo.size = Vector3(5.0, 0.62, 0.06); corpo.material = aco
		_add(chapa, corpo)
		var fenda := CSGBox3D.new(); fenda.name = "Fenda"; fenda.operation = CSGShape3D.OPERATION_SUBTRACTION
		fenda.size = Vector3(1.3, 0.16, 0.3)
		_add(chapa, fenda)
		fenda.position = Vector3(0, -0.06, 0)

	# Luz fraca dentro do bunker (lampião).
	if not geo.has_node("LuzBunker"):
		var luz := OmniLight3D.new(); luz.name = "LuzBunker"
		luz.light_color = Color(1.0, 0.7, 0.4)
		luz.light_energy = 0.9
		luz.omni_range = 6.5
		luz.shadow_enabled = true
		_add(geo, luz)
		luz.position = bunker.position + Vector3(-2.5, 2.5, -1.5)

	# Engenheiro morto com o torpedo Bangalore.
	var aliados := root_node.get_node("Aliados")
	if not aliados.has_node("Engenheiro"):
		var eng: Node3D = load("res://systems/allies/ally_npc.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		eng.name = "Engenheiro"
		eng.ally_id = "ENGENHEIRO"
		eng.lying = true
		_add(aliados, eng)
		eng.position = Vector3(5.5, _h(5.5, -16) + 0.05, -16)
		eng.rotation.y = deg_to_rad(150)
	var itens := root_node.get_node("Itens")
	if not itens.has_node("Bangalore"):
		var b := Node3D.new(); b.name = "Bangalore"
		b.set_script(load("res://levels/props/bangalore_pickup.gd"))
		_add(itens, b)
		b.position = Vector3(6.6, _h(6.6, -15.2) + 0.02, -15.2)
		b.rotation.y = deg_to_rad(20)

	# Inimigos da trincheira e do bunker.
	var inimigos := root_node.get_node("Inimigos")
	var soldado: PackedScene = load("res://systems/enemies/soldier/enemy_soldier.tscn")
	# nome, x, z, olha para (x, z), agressivo, granadas
	var lista := [
		["Trincheira1", -7.5, -44.6, Vector2(0, -40), true, 0],
		["Trincheira2", -14.0, -46.4, Vector2(0, -40), false, 1],
		["Trincheira3", -18.5, -53.0, Vector2(-18.5, -45), false, 0],
		["Trincheira4", -22.5, -60.0, Vector2(-18.5, -55), true, 0],
	]
	for e in lista:
		if inimigos.has_node(e[0]): continue
		var s: Node3D = soldado.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		s.name = e[0]; s.aggressive = e[4]; s.grenades = e[5]
		_add(inimigos, s)
		var y := _h(e[1], e[2]) + 0.1
		s.position = Vector3(e[1], y, e[2])
		_face(s, e[3])
	if not inimigos.has_node("Municiador"):
		var m: Node3D = soldado.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		m.name = "Municiador"
		_add(inimigos, m)
		m.position = Vector3(-31.0, 2.0, -53.6)
		_face(m, Vector2(-25, -57))

	# Pontos de cobertura na trincheira (baixos: só protegem agachado).
	var cob := root_node.get_node("Coberturas")
	var pontos_cob := [[-5.0, -44.3], [-10.0, -43.9], [-15.6, -47.4], [-18.5, -51.0], [-18.5, -55.5]]
	for i in pontos_cob.size():
		var nome := "CoberturaTrinch%d" % (i + 1)
		if cob.has_node(nome): continue
		var c := Marker3D.new(); c.name = nome
		c.set_script(load("res://systems/ai/cover_point.gd"))
		_add(cob, c)
		c.position = Vector3(pontos_cob[i][0], _h(pontos_cob[i][0], pontos_cob[i][1]) + 0.3, pontos_cob[i][1])
		_face(c, Vector2(0, -38))

	# Marcadores da missão.
	var pts := root_node.get_node("Missao/Pontos")
	var marcadores := {
		"bangalore": Vector3(6.6, 0, -15.2), "arame": Vector3(0, 0, -32.6),
		"checkpoint_bangalore": Vector3(4.5, 0, -14.0), "checkpoint_arame": Vector3(0.5, 0, -38.5),
		"trincheira_fim": Vector3(-24.0, 0, -59.0), "porta_bunker": Vector3(-25.0, 0, -57.0),
		"checkpoint_bunker": Vector3(-23.0, 0, -60.0),
		"miller_arame": Vector3(-3.0, 0, -31.0), "reed_arame": Vector3(4.0, 0, -30.0),
		"walker_arame": Vector3(8.0, 0, -24.0), "soldado1_arame": Vector3(-6.0, 0, -29.0),
		"soldado2_arame": Vector3(10.0, 0, -27.0),
		"miller_trincheira": Vector3(-2.0, 0, -42.5), "reed_trincheira": Vector3(1.0, 0, -40.5),
	}
	for nome in marcadores:
		if pts.has_node(nome): continue
		var mk := Marker3D.new(); mk.name = nome
		_add(pts, mk)
		var p: Vector3 = marcadores[nome]
		mk.position = Vector3(p.x, _h(p.x, p.z) + 0.1, p.z)

	var novo := PackedScene.new()
	var err := novo.pack(root_node)
	if err != OK:
		print("ERRO ao empacotar: ", err); quit(1); return
	err = ResourceSaver.save(novo, CENA)
	print("salvo: ", err == OK)
	quit()

func _h(x: float, z: float) -> float:
	return terreno.height_at(x, z)

func _add(parent: Node, node: Node, groups: Array = []) -> void:
	parent.add_child(node)
	node.owner = root_node
	for g in groups:
		node.add_to_group(g, true)

## Gira o nó para que o -Z dele aponte para (x, z).
func _face(n: Node3D, alvo: Vector2) -> void:
	var d := alvo - Vector2(n.position.x, n.position.z)
	n.rotation.y = atan2(-d.x, -d.y)
