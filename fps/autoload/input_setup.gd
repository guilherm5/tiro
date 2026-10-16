extends Node
## Registra os controles padrão do jogo.
##
## As ações ficam definidas aqui (e não no project.godot) para que a lista seja fácil
## de ler e alterar. Teclas usam o código físico, então funcionam em teclado ABNT2.
## Um futuro menu de opções pode remapear estas mesmas ações via InputMap.

const KEYS := {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"jump": [KEY_SPACE],
	&"sprint": [KEY_SHIFT],
	&"crouch": [KEY_CTRL, KEY_C],
	&"reload": [KEY_R],
	&"interact": [KEY_E],
	&"grenade": [KEY_G],
	&"pause": [KEY_ESCAPE],
}

const MOUSE_BUTTONS := {
	&"fire": MOUSE_BUTTON_LEFT,
	&"aim": MOUSE_BUTTON_RIGHT,
}


func _enter_tree() -> void:
	for action: StringName in KEYS:
		_ensure_action(action)
		for keycode: Key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

	for action: StringName in MOUSE_BUTTONS:
		_ensure_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTONS[action]
		InputMap.action_add_event(action, event)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
