class_name MissionDirector
extends Node
## Executa o script da missão (.missao): "quando acontecer X, faça Y".
## O script fica em data/missions/ e pode ser editado sem tocar em código.
##
## Formato:
##   [quando evento]               bloco executado uma vez quando o evento acontece
##   [quando evento se objetivo]   ...só se o objetivo já tiver sido concluído
##   [sempre evento]               executa toda vez (falas contextuais)
##
##   dialogo id                    toca uma cena do .dlg (entra na fila)
##   aguardar_dialogo              espera as falas em andamento terminarem
##   fala id                       fala contextual (só se ninguém estiver falando)
##   objetivo id "texto" [marcador]  novo objetivo (marcador = nó em Missao/Pontos)
##   concluir id                   conclui um objetivo
##   mover ALIADO ponto            aliado corre até um ponto (Missao/Pontos)
##   esperar segundos
##   evento nome                   dispara outro evento
##   missao_concluida "TÍTULO"
##   cartela "TÍTULO" "subtítulo"  tela de título (espera terminar)
##   cutscene id [final]           cena com câmera (espera); "final" não devolve o controle
##   checkpoint ponto              salva; ao morrer, recomeça aqui
##   posicionar ALIADO ponto       teletransporta um aliado (antes de uma cutscene)
##   posicionar_jogador ponto
##
## Eventos vêm de: "inicio" (início da fase), gatilhos de área, mortes com
## `death_event`, @evento nos diálogos e o detector de situações de combate.

signal mission_completed(title: String)

@export_file("*.missao") var script_path := ""
## Nó com os Marker3D usados como marcadores e destinos.
@export var points: Node3D
@export var start_delay := 0.3

var _blocks: Array[Dictionary] = []
var _done := {}


func _ready() -> void:
	Objectives.clear()
	_blocks = _parse(script_path)
	EventBus.narrative_event.connect(_on_event)
	Checkpoints.begin_level()
	if Checkpoints.has_state():
		# Espera a fase montar (colisões, navegação) antes de reposicionar tudo.
		await get_tree().physics_frame
		await get_tree().physics_frame
		_restore(Checkpoints.get_state())
		return
	await get_tree().create_timer(start_delay).timeout
	EventBus.narrative_event.emit("inicio")


func _on_event(event_name: String) -> void:
	for i in _blocks.size():
		var block := _blocks[i]
		if block.event != event_name:
			continue
		if not block.repeat and _done.has(i):
			continue
		if not block.condition.is_empty() and not Objectives.is_completed(block.condition):
			continue
		_done[i] = true
		_run(block.actions)


func _run(actions: Array) -> void:
	for action: PackedStringArray in actions:
		var args := action.slice(1)
		match action[0]:
			"dialogo":
				Dialogue.play(args[0])
			"aguardar_dialogo":
				while Dialogue.is_busy():
					await get_tree().process_frame
			"fala":
				Dialogue.bark(args[0])
			"objetivo":
				var marker: Node3D = _point(args[2]) if args.size() > 2 else null
				Objectives.add(args[0], args[1], marker)
			"concluir":
				Objectives.complete(args[0])
			"mover":
				_move_ally(args[0], args[1])
			"esperar":
				await get_tree().create_timer(float(args[0])).timeout
			"evento":
				EventBus.narrative_event.emit(args[0])
			"cartela":
				var hud := get_tree().get_first_node_in_group(&"hud")
				if hud:
					await hud.show_title_card(args[0], args[1] if args.size() > 1 else "")
			"cutscene":
				await Cutscenes.play(args[0], args.size() > 1 and args[1] == "final")
			"checkpoint":
				_save_checkpoint(args[0])
			"posicionar":
				var ally := _ally(args[0])
				var target := _point(args[1])
				if ally and target:
					ally.teleport_to(target)
			"posicionar_jogador":
				var target := _point(args[0])
				var player := get_tree().get_first_node_in_group(&"player") as Node3D
				if player and target:
					player.global_position = target.global_position
					player.rotation.y = target.global_rotation.y
			"missao_concluida":
				mission_completed.emit(args[0] if args.size() > 0 else "")
				EventBus.mission_completed.emit(args[0] if args.size() > 0 else "")
			_:
				push_warning("Ação desconhecida no script da missão: %s" % action[0])


func _point(point_name: String) -> Node3D:
	var node := points.get_node_or_null(point_name) as Node3D if points else null
	if node == null:
		push_warning("Ponto não encontrado em Missao/Pontos: %s" % point_name)
	return node


func _move_ally(ally_id: String, point_name: String) -> void:
	var target := _point(point_name)
	var ally := _ally(ally_id)
	if target and ally:
		ally.go_to(target)


func _ally(ally_id: String) -> Node:
	for ally in get_tree().get_nodes_in_group(&"aliados"):
		if ally.ally_id == ally_id:
			return ally
	push_warning("Aliado não encontrado: %s" % ally_id)
	return null


# --- Checkpoints -----------------------------------------------------------------

func _save_checkpoint(point_name: String) -> void:
	var allies := {}
	for ally in get_tree().get_nodes_in_group(&"aliados"):
		allies[ally.ally_id] = {"position": ally.global_position, "rotation": ally.rotation.y,
			"target": str(get_tree().current_scene.get_path_to(ally.current_target)) if ally.current_target else ""}
	Checkpoints.save({
		"point": point_name,
		"done": _done.keys(),
		"objectives": Objectives.snapshot(),
		"allies": allies,
	})


func _restore(state: Dictionary) -> void:
	for i in state.get("done", []):
		_done[i] = true
	Objectives.restore(state.get("objectives", []))
	var scene := get_tree().current_scene
	for path: String in state.get("dead_enemies", []):
		var enemy := scene.get_node_or_null(path)
		if enemy:
			enemy.queue_free()
	for ally in get_tree().get_nodes_in_group(&"aliados"):
		var saved: Dictionary = state.get("allies", {}).get(ally.ally_id, {})
		if not saved.is_empty():
			ally.global_position = saved.position
			ally.rotation.y = saved.rotation
			var target := scene.get_node_or_null(saved.target) as Node3D if not saved.target.is_empty() else null
			if target:
				ally.teleport_to(target)
	var point := _point(state.get("point", ""))
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if point and player:
		player.global_position = point.global_position
		player.rotation.y = point.global_rotation.y
	EventBus.narrative_event.emit("checkpoint_restaurado")


func _parse(path: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Script de missão não encontrado: %s" % path)
		return blocks
	var current: Dictionary = {}
	for raw in file.get_as_text().split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			var head := line.substr(1, line.length() - 2).split(" ", false)
			current = {
				"repeat": head[0] == "sempre",
				"event": head[1] if head.size() > 1 else "",
				"condition": head[3] if head.size() > 3 and head[2] == "se" else "",
				"actions": [],
			}
			blocks.append(current)
		elif not current.is_empty():
			current.actions.append(_tokenize(line))
	return blocks


## Divide por espaços, mantendo "textos entre aspas" juntos.
static func _tokenize(line: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	var buffer := ""
	var quoted := false
	for c in line:
		if c == "\"":
			quoted = not quoted
		elif c == " " and not quoted:
			if not buffer.is_empty():
				tokens.append(buffer)
			buffer = ""
		else:
			buffer += c
	if not buffer.is_empty():
		tokens.append(buffer)
	return tokens
