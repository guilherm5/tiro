extends Control
## Menu principal: Continuar (último checkpoint salvo), Nova campanha, Opções,
## Créditos e Sair. Fundo: imagem da praia escurecida, com o som ambiente baixo.

const FIRST_MISSION := "res://levels/demo_praia/demo_praia.tscn"
const CREDITS_FILE := "res://assets/CREDITOS.md"
const BACKGROUND := preload("res://assets/ui/fundo_menu.png")
const AMBIENCE := preload("res://assets/audio/provisorio/ambiente_praia.wav")

var _list: VBoxContainer
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.55, 0.55, 0.55)
	add_child(background)

	# Escurece mais à esquerda, onde fica o texto.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.88), Color(0, 0, 0, 0.15)])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = gradient_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 6)
	_list.add_child(MenuStyle.title("OPERAÇÃO ÚLTIMA LINHA", 52))
	_list.add_child(MenuStyle.caption("Normandia, junho de 1944", 20))
	_list.add_child(MenuStyle.caption(" ", 30))
	var continue_button := MenuStyle.button("Continuar", _continue)
	continue_button.disabled = not Checkpoints.has_saved_game()
	_list.add_child(continue_button)
	_list.add_child(MenuStyle.button("Nova campanha", _new_game))
	_list.add_child(MenuStyle.button("Opções", _open_options))
	_list.add_child(MenuStyle.button("Créditos", _open_credits))
	_list.add_child(MenuStyle.button("Sair", func() -> void: get_tree().quit()))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.add_theme_constant_override(&"margin_left", 110)
	margin.add_theme_constant_override(&"margin_top", 200)
	margin.add_child(_list)
	add_child(margin)

	var version := MenuStyle.caption("Demonstração — Missão 1", 14)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position -= Vector2(260, 40)
	add_child(version)

	var ambience := AudioStreamPlayer.new()
	ambience.stream = AMBIENCE
	ambience.volume_db = -10.0
	ambience.bus = &"Ambiente"
	add_child(ambience)
	ambience.play()

	(continue_button if not continue_button.disabled else _list.get_child(4) as Button).grab_focus()


func _continue() -> void:
	SceneLoader.change_to(Checkpoints.last_level)


func _new_game() -> void:
	Checkpoints.clear_all()
	SceneLoader.change_to(FIRST_MISSION)


func _open_options() -> void:
	_list.hide()
	var options := OptionsMenu.new()
	add_child(options)
	options.closed.connect(func() -> void:
		_list.show()
		(_list.get_child(5) as Button).grab_focus())


func _open_credits() -> void:
	_list.hide()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(760, 560)
	text.add_theme_color_override(&"default_color", MenuStyle.TEXT)
	text.add_theme_font_size_override(&"normal_font_size", 15)
	var file := FileAccess.open(CREDITS_FILE, FileAccess.READ)
	var body := file.get_as_text() if file else "Créditos indisponíveis."
	text.text = "Roteiro, história e personagens: Guilherme\n\n" + body.replace("#", "").replace("`", "")
	var box := VBoxContainer.new()
	box.add_child(MenuStyle.title("CRÉDITOS", 32))
	box.add_child(text)
	var back := MenuStyle.button("Voltar", _close_credits)
	box.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(MenuStyle.panel(box))
	_overlay.add_child(center)
	add_child(_overlay)
	back.grab_focus()


func _close_credits() -> void:
	_overlay.queue_free()
	_list.show()
	(_list.get_child(6) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _overlay and is_instance_valid(_overlay) and event.is_action_pressed(&"pause"):
		_close_credits()
