extends CanvasLayer
## Pausa (Esc durante o jogo): Continuar, Opções, Voltar ao checkpoint, Menu principal, Sair.

var _root: Control
var _list: VBoxContainer
var _options: OptionsMenu


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 6)
	_list.add_child(MenuStyle.title("PAUSA", 36))
	_list.add_child(MenuStyle.caption(" ", 8))
	_list.add_child(MenuStyle.button("Continuar", resume))
	_list.add_child(MenuStyle.button("Opções", _open_options))
	_list.add_child(MenuStyle.button("Voltar ao último checkpoint", _restart_checkpoint))
	_list.add_child(MenuStyle.button("Menu principal", _to_menu))
	_list.add_child(MenuStyle.button("Sair do jogo", func() -> void: get_tree().quit()))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.add_theme_constant_override(&"margin_left", 90)
	margin.add_theme_constant_override(&"margin_top", 220)
	margin.add_child(_list)
	_root.add_child(margin)
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") or _options != null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player and player.is_dead:
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		resume()
	else:
		_pause()


func _pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.show()
	(_list.get_child(2) as Button).grab_focus()


func resume() -> void:
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_options() -> void:
	_list.hide()
	_options = OptionsMenu.new()
	_root.add_child(_options)
	_options.closed.connect(func() -> void:
		_options = null
		_list.show()
		(_list.get_child(3) as Button).grab_focus())


func _restart_checkpoint() -> void:
	get_tree().paused = false
	SceneLoader.change_to(get_tree().current_scene.scene_file_path)


func _to_menu() -> void:
	SceneLoader.go_to_menu()
