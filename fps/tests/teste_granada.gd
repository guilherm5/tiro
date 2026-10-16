extends SceneTree
# Teste automático — rode com tests/rodar_testes.sh. Scripts sem tipos estáticos de classes do jogo:
# com -s, eles compilam antes dos autoloads (EventBus) existirem.
# Granada: G lança, quica, explode no tempo e mata o inimigo perto. Interação: E pega um
# item (toque) e outro exige o item e segurar E.
var scene: Node
var p
var f := 0
var alvo
var mortos := 0
var eventos := []
var pegar
var plantar
func _initialize() -> void:
	scene = load("res://levels/demo_praia/demo_praia.tscn").instantiate()
	_sem_missao(scene)
	root.add_child(scene)
	current_scene = scene
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 5:
		p = scene.get_node("Player")
		p.health.max_health = 100000; p.health.current = 100000
		for e in scene.get_node("Inimigos").get_children():
			e.process_mode = Node.PROCESS_MODE_DISABLED
		alvo = scene.get_node("Inimigos/Soldado3")
		alvo.process_mode = Node.PROCESS_MODE_INHERIT
		alvo.brain.process_mode = Node.PROCESS_MODE_DISABLED
		root.get_node("EventBus").enemy_killed.connect(func(_e): mortos += 1)
		root.get_node("EventBus").narrative_event.connect(func(n): eventos.append(n))
		# Jogador a 12 m do inimigo, olhando para ele.
		p.global_position = alvo.global_position + Vector3(0, 0.3, 12)
		p.look_at(Vector3(alvo.global_position.x, p.global_position.y, alvo.global_position.z))
		p.get_node("Head").rotation.x = deg_to_rad(-14)
		print("granadas no início: ", p.get_node("GrenadeThrower").count)
	if f == 10:
		Input.action_press("grenade")
	if f == 11:
		Input.action_release("grenade")
	if f > 11 and get_nodes_in_group_safe("grenades").size() > 0:
		var gr = get_nodes_in_group_safe("grenades")[0]
		if gr.time_left() < 0.017: print("explodiu em ", gr.global_position.snapped(Vector3.ONE * 0.1), " dist ao alvo ", snappedf(gr.global_position.distance_to(alvo.global_position), 0.1))
	if f == 60:
		var g = get_nodes_in_group_safe("grenades")
		print("granada no ar: ", g.size(), "  restantes: ", p.get_node("GrenadeThrower").count)
	if f == 60 * 6:
		print("inimigo morto pela granada: ", mortos >= 1, "  granadas no mundo: ", get_nodes_in_group_safe("grenades").size())
		_teste_interacao()
	if f == 60 * 6 + 3:
		Input.action_press("interact")
	if f == 60 * 6 + 7:
		Input.action_release("interact")
		print("pegou item: ", p.get_node("Interactor").items.has("teste"), "  aviso: '", p.get_node("Interactor").prompt_text, "'")
		p.global_position = plantar.global_position + Vector3(0, 0, 1.5)
		p.look_at(Vector3(plantar.global_position.x, p.global_position.y, plantar.global_position.z))
	if f == 60 * 6 + 8:
		print("aviso para plantar: '", p.get_node("Interactor").prompt_text, "'")
		Input.action_press("interact")
	if f == 60 * 6 + 60:
		print("  segurando 1 s: progresso=", snappedf(p.get_node("Interactor").progress, 0.01))
	if f == 60 * 6 + 60 * 3:
		Input.action_release("interact")
		print("plantou: ", eventos.has("teste_plantado"), "  item gasto: ", not p.get_node("Interactor").items.has("teste"))
		quit()
	return false
func get_nodes_in_group_safe(g: String) -> Array:
	return root.get_tree().get_nodes_in_group(g)
func _teste_interacao() -> void:
	var it = load("res://systems/interaction/interactable.gd")
	pegar = it.new(); pegar.prompt = "Pegar"; pegar.gives_item = "teste"
	plantar = it.new(); plantar.prompt = "Plantar"; plantar.requires_item = "teste"; plantar.missing_prompt = "Precisa do item"
	plantar.hold_time = 2.0; plantar.event_name = "teste_plantado"
	for a in [pegar, plantar]:
		var forma := CollisionShape3D.new(); var esfera := SphereShape3D.new(); esfera.radius = 0.4; forma.shape = esfera
		a.add_child(forma); scene.add_child(a)
	pegar.global_position = p.global_position + Vector3(0, 1.0, -1.2)
	plantar.global_position = p.global_position + Vector3(4, 1.0, 0)
	p.rotation = Vector3.ZERO; p.get_node("Head").rotation.x = deg_to_rad(-20)
func _sem_missao(cena: Node) -> void:
	cena.get_node("Missao").free()
	cena.get_node("Geometria/RampaPivot").rotation.x = deg_to_rad(-106.7)
