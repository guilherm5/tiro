extends Node
## Checkpoints (autoload "Checkpoints"). Ao morrer, a fase recomeça do último
## checkpoint em vez do início. O script da missão marca os checkpoints
## (`checkpoint ponto`); o MissionDirector salva e restaura o estado.
##
## Guarda: ponto do jogador, blocos do script já executados, objetivos, inimigos
## mortos e posição dos aliados. F4 (teste) apaga o checkpoint e recomeça a missão.

## Os testes automáticos (rodados com "-- --teste") usam outro arquivo e nunca tocam no
## progresso do jogador.
var SAVE_PATH := "user://progresso_teste.save" if OS.get_cmdline_user_args().has("--teste") else "user://progresso.save"

var _states := {}  # caminho da cena da fase -> estado
var _dead_enemies: Array[String] = []
## Última fase jogada (para o "Continuar" do menu).
var last_level := ""


func _ready() -> void:
	_load_from_disk()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.mission_completed.connect(func(_t: String) -> void: clear_current())


func has_state() -> bool:
	return _states.has(_level_key())


func get_state() -> Dictionary:
	return _states.get(_level_key(), {})


func save(state: Dictionary) -> void:
	state["dead_enemies"] = _dead_enemies.duplicate()
	_states[_level_key()] = state
	last_level = _level_key()
	_save_to_disk()


## Chamado pelo MissionDirector ao carregar a fase.
func begin_level() -> void:
	_dead_enemies.clear()
	if has_state():
		_dead_enemies.assign(get_state().get("dead_enemies", []))


func clear_current() -> void:
	_states.erase(_level_key())
	_save_to_disk()


## Apaga todo o progresso (Novo jogo).
func clear_all() -> void:
	_states.clear()
	last_level = ""
	_save_to_disk()


func has_saved_game() -> bool:
	return not last_level.is_empty() and _states.has(last_level)


func _save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({"states": _states, "last_level": last_level})


func _load_from_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = file.get_var()
	if data is Dictionary:
		_states = data.get("states", {})
		last_level = data.get("last_level", "")


func _on_enemy_killed(enemy: Node) -> void:
	var scene := get_tree().current_scene
	if scene:
		_dead_enemies.append(str(scene.get_path_to(enemy)))


func _level_key() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene else ""
