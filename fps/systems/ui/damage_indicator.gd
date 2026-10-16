extends Control
## Arcos vermelhos ao redor do centro da tela apontando de onde veio cada tiro.
## Cada indicador some em `lifetime` segundos e acompanha o giro da câmera.

@export var lifetime := 1.6
@export var radius := 140.0
@export var arc_degrees := 40.0
@export var color := Color(0.75, 0.05, 0.02, 0.85)

var _indicators: Array[Dictionary] = []


func _ready() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)


func _on_player_damaged(_amount: float, source_position: Vector3) -> void:
	_indicators.append({"source": source_position, "time": lifetime})


func _process(delta: float) -> void:
	for indicator in _indicators:
		indicator.time -= delta
	_indicators = _indicators.filter(func(i: Dictionary) -> bool: return i.time > 0.0)
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var center := size * 0.5
	for indicator in _indicators:
		var to_source: Vector3 = camera.global_basis.inverse() * (indicator.source - camera.global_position)
		# Ângulo no plano horizontal da câmera: 0 = à frente (topo da tela).
		var angle := atan2(to_source.x, -to_source.z) - PI * 0.5
		var alpha: float = clampf(indicator.time / lifetime, 0.0, 1.0)
		var half := deg_to_rad(arc_degrees) * 0.5
		draw_arc(center, radius, angle - half, angle + half, 24, Color(color, color.a * alpha), 6.0, true)
