extends SceneTree
# Teste automático — rode com tests/rodar_testes.sh. Scripts sem tipos estáticos de classes do jogo:
# com -s, eles compilam antes dos autoloads (EventBus) existirem.
# Narrativa completa (tempo 4x): cartela, cutscene de abertura, rampa, objetivos, checkpoint
# + morte, torpedo Bangalore, arame, trincheira, MG, "O primeiro morto", encerramento e fim.
var scene: Node
var p
var f := 0
var t := 0
var fase := "inicio"
var falas := []
var objetivos := []
var concluidos := []
var cutscenes := []
var missao := ""
func _initialize() -> void:
	Engine.time_scale = 4.0
	root.get_node("Checkpoints").clear_all()
	_carregar()
	var dlg = root.get_node("Dialogue")
	dlg.line_started.connect(func(line, nome, _c): falas.append(nome + ": " + line.text.left(35)))
	root.get_node("Objectives").objective_added.connect(func(id, _t): objetivos.append(id))
	root.get_node("Objectives").objective_completed.connect(func(id): concluidos.append(id))
	root.get_node("EventBus").mission_completed.connect(func(tt): missao = tt)
	root.get_node("EventBus").cutscene_started.connect(func(id): cutscenes.append(id))
func _carregar() -> void:
	scene = load("res://levels/demo_praia/demo_praia.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	f = 0
func _preparar() -> void:
	p = scene.get_node("Player")
	p.health.max_health = 100000; p.health.current = 100000
	for e in scene.get_node("Inimigos").get_children(): e.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("Atmosfera/Artilharia").enabled = false
func _physics_process(_d: float) -> bool:
	f += 1; t += 1
	if f == 2 and fase == "inicio": root.get_node("Checkpoints").clear_current()
	if f == 3: _preparar()
	match fase:
		"inicio":
			if f == 600:  # cartela (~6 s) + parte da cutscene
				print("cutscene em andamento: ", cutscenes, " jogador em cinematica=", p.is_cinematic, " falas=", falas.size())
				root.get_node("Dialogue").skip_current()
			if f == 900:
				print("após pular: cinematica=", p.is_cinematic, " rampa x=", snappedf(rad_to_deg(scene.get_node("Geometria/RampaPivot").rotation.x), 1), "°")
				print("  objetivos=", objetivos, " Miller z=", snappedf(scene.get_node("Aliados/Miller").global_position.z, 0.1))
				print("  checkpoint salvo=", root.get_node("Checkpoints").has_state())
				p.global_position = Vector3(0, 0, 38)
			if f == 1900:
				print("obstáculos: objetivos=", objetivos, " checkpoint=", root.get_node("Checkpoints").get_state().get("point"))
				print("-- jogador morre (deve voltar ao checkpoint dos obstáculos)")
				p.process_mode = Node.PROCESS_MODE_INHERIT
				p.health.max_health = 100; p.health.current = 1
				var h = load("res://systems/combat/hit_info.gd").new(); h.damage = 50; h.direction = Vector3.FORWARD; h.position = p.global_position
				p.apply_hit(h)
			if f > 1900 and current_scene != null and current_scene != scene:
				scene = current_scene; f = 0; fase = "recarregado"
		"recarregado":
			if f == 200:
				print("recarregado: jogador z=", snappedf(p.global_position.z, 0.1), " objetivos ativos=", root.get_node("Objectives").current().get("id"), " cutscene repetiu=", cutscenes.count("abertura_barco") > 1)
				var itens = p.get_node("Interactor").items
				scene.get_node("Itens/Bangalore/Pegar").use(p, itens)
			if f == 300:
				print("pegou o Bangalore: objetivo=", root.get_node("Objectives").current().get("id"))
				p.global_position = Vector3(0, 1.5, -31)
				scene.get_node("Geometria/Arame/PontoBangalore").use(p, p.get_node("Interactor").items)
			if f == 900:
				print("arame: destruído=", scene.get_node("Geometria/Arame").destroyed, " objetivo=", root.get_node("Objectives").current().get("id"))
				p.global_position = Vector3(-22.5, 2.5, -59)
			if f == 1000:
				print("fundos do bunker: objetivo=", root.get_node("Objectives").current().get("id"))
				var mg = scene.get_node("Inimigos/Metralhador")
				mg.process_mode = Node.PROCESS_MODE_INHERIT
				var h = load("res://systems/combat/hit_info.gd").new(); h.damage = 100; h.direction = Vector3.FORWARD; h.position = mg.global_position
				mg.receive_hit(h, true)
			if f == 2100:
				print("MG morta: concluídos=", concluidos)
				p.global_position = Vector3(0, 2, -39)
			if f == 2400:
				print("cena do muro: cutscenes=", cutscenes)
			if missao != "" and fase == "recarregado":
				print("fim: missão='", missao, "' cutscenes=", cutscenes)
				print("  últimas falas=", falas.slice(-3))
				return true
			if f > 9000:
				print("ERRO: missão não terminou. fase=", fase, " cutscenes=", cutscenes)
				return true
	return false
