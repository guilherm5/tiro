class_name MenuStyle
extends RefCounted
## Estilo único dos menus (cores, botões, títulos), para todos ficarem consistentes:
## sóbrio, escuro, texto creme — nada de cores vibrantes.

const TEXT := Color(0.86, 0.83, 0.75)
const TEXT_DIM := Color(0.6, 0.58, 0.52)
const ACCENT := Color(0.93, 0.78, 0.45)
const PANEL := Color(0.05, 0.05, 0.045, 0.82)


static func title(text: String, size := 44) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", TEXT)
	return label


static func caption(text: String, size := 16, color := TEXT_DIM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override(&"font_size", 22)
	b.add_theme_color_override(&"font_color", TEXT)
	b.add_theme_color_override(&"font_hover_color", ACCENT)
	b.add_theme_color_override(&"font_focus_color", ACCENT)
	b.add_theme_color_override(&"font_pressed_color", ACCENT)
	b.add_theme_color_override(&"font_disabled_color", Color(TEXT_DIM, 0.4))
	# Sem a caixa padrão de foco: o destaque é a cor dourada e a seta.
	for state in [&"focus", &"hover", &"pressed", &"normal", &"disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var base_text := text
	b.focus_entered.connect(func() -> void: b.text = "›  " + base_text)
	b.focus_exited.connect(func() -> void: b.text = base_text)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(on_pressed)
	return b


static func panel(content: Control, padding := 32) -> PanelContainer:
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	container.add_theme_stylebox_override(&"panel", style)
	container.add_child(content)
	return container
