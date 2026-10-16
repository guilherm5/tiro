extends Control
## Mira em cruz. A abertura acompanha a dispersão real da arma (o que você vê é onde
## as balas podem ir). Some ao mirar pelo aparelho de mira e ao correr.

var spread_degrees := 0.0
var opacity := 1.0

## Marcador de acerto: um X rápido no centro (branco = acerto, vermelho = abate).
@export var hit_marker_time := 0.25
@export var kill_color := Color(0.9, 0.2, 0.15, 0.95)

var _marker_time := 0.0
var _marker_color := Color.WHITE

@export var line_length := 8.0
@export var line_width := 2.0
@export var color := Color(1, 1, 1, 0.8)


func show_hit_marker(killed: bool) -> void:
	_marker_time = hit_marker_time
	_marker_color = kill_color if killed else Color(1, 1, 1, 0.9)


func _process(delta: float) -> void:
	_marker_time = maxf(_marker_time - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if _marker_time > 0.0:
		var alpha := _marker_time / hit_marker_time
		var marker_tint := Color(_marker_color, _marker_color.a * alpha)
		for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + dir.normalized() * 6.0, center + dir.normalized() * 14.0, marker_tint, 2.0, true)
	var camera := get_viewport().get_camera_3d()
	if opacity <= 0.01 or camera == null:
		return
	var pixels_per_unit := (size.y * 0.5) / tan(deg_to_rad(camera.fov * 0.5))
	var gap := maxf(4.0, tan(deg_to_rad(spread_degrees)) * pixels_per_unit)
	var tint := Color(color, color.a * opacity)
	for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + dir * gap, center + dir * (gap + line_length), tint, line_width, true)
