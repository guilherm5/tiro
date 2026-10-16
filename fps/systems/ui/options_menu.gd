class_name OptionsMenu
extends Control
## Painel de opções (usado no menu principal e na pausa). Altera `Settings` na hora
## e salva ao fechar.

signal closed

var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 10)
	_rows.custom_minimum_size = Vector2(560, 0)
	_rows.add_child(MenuStyle.title("OPÇÕES", 34))

	_section("Controles")
	_slider("Sensibilidade do mouse", 0.2, 3.0, 0.05, "mouse_sensitivity", func(v: float) -> String: return "%.2fx" % v)
	_toggle("Inverter eixo vertical", "invert_y")
	_slider("Campo de visão", 60.0, 95.0, 1.0, "fov", func(v: float) -> String: return "%d°" % v)

	_section("Áudio")
	for entry in [["Volume geral", "volume_master"], ["Efeitos", "volume_sfx"], ["Vozes", "volume_voice"], ["Ambiente", "volume_ambient"]]:
		_slider(entry[0], 0.0, 1.0, 0.05, entry[1], func(v: float) -> String: return "%d%%" % roundi(v * 100.0))

	_section("Legendas")
	_toggle("Mostrar legendas", "subtitles")
	_slider("Tamanho da legenda", 16.0, 32.0, 1.0, "subtitle_size", func(v: float) -> String: return "%d" % v)

	_section("Vídeo")
	_option("Qualidade gráfica", Settings.QUALITY_NAMES, "quality")
	_toggle("Efeito de filme (granulado e vinheta)", "film_effect")
	_toggle("Tela cheia", "fullscreen")
	_toggle("Sincronia vertical (V-Sync)", "vsync")

	var back := MenuStyle.button("Voltar", _close)
	_rows.add_child(back)

	var panel := MenuStyle.panel(_rows)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)
	back.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()


func _section(text: String) -> void:
	var label := MenuStyle.caption(text.to_upper(), 14, MenuStyle.ACCENT)
	_rows.add_child(label)


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := MenuStyle.caption(text, 18, MenuStyle.TEXT)
	label.custom_minimum_size = Vector2(260, 0)
	row.add_child(label)
	_rows.add_child(row)
	return row


func _slider(text: String, min_value: float, max_value: float, step: float, key: String, fmt: Callable) -> void:
	var row := _row(text)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = Settings.get(key)
	slider.custom_minimum_size = Vector2(200, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := MenuStyle.caption(fmt.call(slider.value), 16)
	value_label.custom_minimum_size = Vector2(70, 0)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set(key, int(v) if typeof(Settings.get(key)) == TYPE_INT else v)
		value_label.text = fmt.call(v)
		Settings.apply())
	row.add_child(slider)
	row.add_child(value_label)


func _toggle(text: String, key: String) -> void:
	var row := _row(text)
	var check := CheckButton.new()
	check.button_pressed = Settings.get(key)
	check.toggled.connect(func(on: bool) -> void:
		Settings.set(key, on)
		Settings.apply())
	row.add_child(check)


func _option(text: String, options: Array, key: String) -> void:
	var row := _row(text)
	var picker := OptionButton.new()
	for option: String in options:
		picker.add_item(option)
	picker.selected = Settings.get(key)
	picker.item_selected.connect(func(index: int) -> void:
		Settings.set(key, index)
		Settings.apply())
	row.add_child(picker)
