extends Node
## Objetivos da missão (autoload "Objectives"). O HUD mostra o objetivo ativo e um
## marcador na tela, para o jogador entender o que fazer sem depender das falas.

signal objective_added(id: String, text: String)
signal objective_completed(id: String)
signal objectives_cleared

## id -> {text, marker (Node3D ou null), done}
var _objectives := {}
var _order: Array[String] = []
## Concluídos antes de aparecerem (ex.: MG destruída antes da fala do Miller).
var _completed_early := {}


func add(id: String, text: String, marker: Node3D = null) -> void:
	if _objectives.has(id):
		return
	_objectives[id] = {"text": text, "marker": marker, "done": false}
	_order.append(id)
	objective_added.emit(id, text)
	if _completed_early.has(id):
		complete(id)


func complete(id: String) -> void:
	if not _objectives.has(id):
		_completed_early[id] = true
		return
	if _objectives[id].done:
		return
	_objectives[id].done = true
	objective_completed.emit(id)


func is_completed(id: String) -> bool:
	return _completed_early.has(id) or (_objectives.has(id) and _objectives[id].done)


## O objetivo ativo mais recente (o que aparece no HUD), ou {} se não houver.
func current() -> Dictionary:
	for i in range(_order.size() - 1, -1, -1):
		var o: Dictionary = _objectives[_order[i]]
		if not o.done:
			return o.merged({"id": _order[i]})
	return {}


## Estado para checkpoint: [{id, text, marker (caminho), done}].
func snapshot() -> Array:
	var scene := get_tree().current_scene
	var out := []
	for id in _order:
		var o: Dictionary = _objectives[id]
		var marker_path := ""
		if is_instance_valid(o.marker):
			marker_path = str(scene.get_path_to(o.marker))
		out.append({"id": id, "text": o.text, "marker": marker_path, "done": o.done})
	return out


func restore(state: Array) -> void:
	clear()
	var scene := get_tree().current_scene
	for o: Dictionary in state:
		var marker: Node3D = scene.get_node_or_null(o.marker) as Node3D if not o.marker.is_empty() else null
		add(o.id, o.text, marker)
		if o.done:
			complete(o.id)


func clear() -> void:
	_objectives.clear()
	_order.clear()
	_completed_early.clear()
	objectives_cleared.emit()
