class_name Interactor
extends Node
## Do jogador: acha o Interactable para onde a câmera aponta e usa com E (tocar ou
## segurar). Guarda os itens carregados (ex.: "bangalore") e informa o HUD.

signal items_changed(items: Dictionary)

@export var reach := 2.2

var items := {}
## Interactable sob a mira (ou null) e o texto a mostrar.
var current: Interactable
var prompt_text := ""
## 0..1 enquanto segura E num interactable com hold_time.
var progress := 0.0

var _held := 0.0

@onready var _player: PlayerController = get_parent()


func _physics_process(delta: float) -> void:
	current = null
	prompt_text = ""
	if _player.is_dead or _player.is_cinematic:
		_held = 0.0
		progress = 0.0
		return
	current = _find()
	if current:
		prompt_text = current.get_prompt(items)
	if current == null or not current.can_use(items):
		_held = 0.0
		progress = 0.0
		return
	if current.hold_time <= 0.0:
		progress = 0.0
		if Input.is_action_just_pressed(&"interact"):
			_use()
		return
	if Input.is_action_pressed(&"interact"):
		_held += delta
		progress = clampf(_held / current.hold_time, 0.0, 1.0)
		if _held >= current.hold_time:
			_use()
	else:
		_held = 0.0
		progress = 0.0


func give(item: String) -> void:
	items[item] = true
	items_changed.emit(items)


func _use() -> void:
	_held = 0.0
	progress = 0.0
	current.use(_player, items)
	items_changed.emit(items)


func _find() -> Interactable:
	var camera := _player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to, Interactable.LAYER | 1, [_player.get_rid()])
	query.collide_with_areas = true
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	var found := hit.collider as Interactable if not hit.is_empty() else null
	return found if found else _nearby()


## Ajuda: se nada está bem na mira, aceita um interactable muito perto e à frente
## (pegar algo no chão sem precisar mirar exatamente).
func _nearby() -> Interactable:
	var camera := _player.camera
	var forward := -camera.global_basis.z
	var best: Interactable = null
	var best_dot := 0.8
	for node in get_tree().get_nodes_in_group(&"interactables"):
		var it := node as Interactable
		if it == null or not it.enabled:
			continue
		var to_it := it.global_position - camera.global_position
		if to_it.length() > reach + 0.4:
			continue
		var d := forward.dot(to_it.normalized())
		if d > best_dot:
			best_dot = d
			best = it
	return best
