extends Control
## Objetivo ativo (canto superior) e marcador na tela apontando para o alvo, com a
## distância. O marcador fica na borda quando o alvo está fora da tela.

@export var marker_color := Color(0.95, 0.85, 0.55, 0.9)

@onready var _title: Label = $Panel/Title
@onready var _text: Label = $Panel/Text
@onready var _panel: Control = $Panel


func _ready() -> void:
	_panel.modulate.a = 0.0
	Objectives.objective_added.connect(func(_id: String, _t: String) -> void: _refresh(true))
	Objectives.objective_completed.connect(func(_id: String) -> void: _on_completed())
	Objectives.objectives_cleared.connect(func() -> void: _refresh(false))


func _refresh(highlight: bool) -> void:
	var current := Objectives.current()
	if current.is_empty():
		create_tween().tween_property(_panel, ^"modulate:a", 0.0, 0.6)
		return
	_title.text = "OBJETIVO"
	_text.text = current.text
	if highlight:
		var tween := create_tween()
		tween.tween_property(_panel, ^"modulate:a", 1.0, 0.4)


func _on_completed() -> void:
	_title.text = "CONCLUÍDO"
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_callback(_refresh.bind(false))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var current := Objectives.current()
	var camera := get_viewport().get_camera_3d()
	if current.is_empty() or camera == null or not is_instance_valid(current.marker) or current.marker == null:
		return
	var target: Vector3 = (current.marker as Node3D).global_position + Vector3.UP * 1.5
	# No plano exato da câmera a projeção não existe: empurra o ponto um pouco à frente.
	var depth := (camera.global_transform.affine_inverse() * target).z
	if absf(depth) < 0.01:
		target -= camera.global_basis.z * 0.02
	var behind := camera.is_position_behind(target)
	var screen := camera.unproject_position(target)
	var margin := 40.0
	var rect := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)
	if behind:
		screen = size - screen  # espelha: aponta para o lado certo
		screen.y = size.y - margin
	screen = screen.clamp(rect.position, rect.end)
	var distance := camera.global_position.distance_to(target)
	# Losango + distância.
	var r := 7.0
	var points := PackedVector2Array([screen + Vector2(0, -r), screen + Vector2(r, 0), screen + Vector2(0, r), screen + Vector2(-r, 0)])
	draw_colored_polygon(points, Color(marker_color, 0.25))
	draw_polyline(points + PackedVector2Array([points[0]]), marker_color, 2.0, true)
	var font := get_theme_default_font()
	draw_string(font, screen + Vector2(-20, 24), "%d m" % roundi(distance), HORIZONTAL_ALIGNMENT_CENTER, 40, 13, marker_color)
