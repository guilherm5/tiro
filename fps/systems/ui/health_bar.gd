extends Control
## Vida em blocos (um retângulo por bloco). O bloco parcial mostra quanto ainda
## pode regenerar; blocos perdidos ficam vazios até um kit médico.

@export var segment_gap := 4.0
@export var fill_color := Color(0.85, 0.82, 0.74, 0.9)
@export var low_color := Color(0.8, 0.22, 0.15, 0.95)
@export var empty_color := Color(0.0, 0.0, 0.0, 0.35)

var health: Health


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if health == null:
		return
	var count := health.segment_count
	var width := (size.x - segment_gap * (count - 1)) / count
	var segment := health.segment_size()
	var is_low := health.current <= segment
	for i in count:
		var rect := Rect2(i * (width + segment_gap), 0.0, width, size.y)
		draw_rect(rect, empty_color)
		var fill := clampf((health.current - i * segment) / segment, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(rect.position, Vector2(width * fill, size.y)), low_color if is_low else fill_color)
