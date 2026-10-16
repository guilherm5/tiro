# Tabela de alcance: executa cada golpe do PCI contra um boneco parado em várias
# distâncias e marca onde acerta. Também testa o boneco agachado (golpe alto deve passar).
# Uso: godot --headless --fixed-fps 60 --path jogo -s res://ferramentas/teste_alcance.gd
extends SceneTree

var luta: Node3D


func _initialize() -> void:
	root.get_node("Config").modo = "treino"
	luta = load("res://cenas/luta.tscn").instantiate()
	root.add_child(luta)
	await _quadros(5)
	luta.set("_sem_intro", true)
	await _ate(func(): return luta.fase == "luta", 400)
	var p1: Lutador = luta.p1
	var p2: Lutador = luta.p2
	p1.entrada.jogador = 0
	var distancias := [0.7, 0.9, 1.1, 1.3, 1.5, 1.7, 1.9, 2.2, 2.6]
	print("golpe                 ", "  ".join(distancias.map(func(d): return "%.1f" % d)), "   agachado(0.9)")
	for id in p1.golpes:
		var g: Dictionary = p1.golpes[id]
		if g.get("comando", "") == "" and not id in ["um_dois", "um_dois_quatro"]:
			continue
		if String(g.get("comando", "")).begins_with("ar+") or g["nivel"] == "agarrao":
			continue
		var linha := "%-20s " % id
		for d in distancias:
			linha += "  %s " % ("X" if await _testar(p1, p2, id, d, 5) else ".")
		linha += "     %s" % ("acerta" if await _testar(p1, p2, id, 0.9, 2) else "passa")
		print(linha)
	quit()


func _testar(p1: Lutador, p2: Lutador, id: String, d: float, dir_boneco: int) -> bool:
	luta.boneco = 0
	p2.entrada.virtual_dir = dir_boneco
	luta.projeteis.map(func(p): p.queue_free())
	luta.projeteis.clear()
	p1.reiniciar(Vector3(-d / 2.0, 0, 0))
	p2.reiniciar(Vector3(d / 2.0, 0, 0))
	p1.frente = Vector3.RIGHT
	p2.frente = Vector3.LEFT
	p1.pode_agir = true
	p2.pode_agir = true
	luta.boneco = 1 if dir_boneco == 2 else 0
	await _quadros(12)
	var vida := p2.vida
	p1.iniciar_golpe(id)
	await _ate(func(): return p1.estado != Lutador.E.GOLPE and luta.projeteis.is_empty(), 300)
	await _quadros(2)
	var acertou := p2.vida < vida or p2.estado in [Lutador.E.ATINGIDO, Lutador.E.LANCADO, Lutador.E.CAIDO]
	await _ate(func(): return p2.livre(), 300)
	return acertou


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_quadros: int) -> void:
	for i in max_quadros:
		if cond.call():
			return
		await physics_frame
