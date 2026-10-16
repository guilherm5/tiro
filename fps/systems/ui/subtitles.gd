extends Control
## Legendas: nome do personagem (colorido) e fala, na parte de baixo da tela.

@onready var _label: RichTextLabel = $Label


func _ready() -> void:
	_label.text = ""
	modulate.a = 0.0
	Dialogue.line_started.connect(_on_line_started)
	Dialogue.line_finished.connect(_on_line_finished)


func _on_line_started(line: Dictionary, speaker_name: String, color: Color) -> void:
	visible = Settings.subtitles
	_label.add_theme_font_size_override(&"normal_font_size", Settings.subtitle_size)
	_label.text = "[center][color=#%s]%s:[/color] %s[/center]" % [color.to_html(false), speaker_name, line.text]
	create_tween().tween_property(self, ^"modulate:a", 1.0, 0.15)


func _on_line_finished(_line: Dictionary) -> void:
	create_tween().tween_property(self, ^"modulate:a", 0.0, 0.25)
