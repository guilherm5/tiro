extends Node3D
## Traçante: um risco luminoso que viaja do cano até o ponto de impacto.

@export var speed := 450.0

var _target := Vector3.ZERO
var _remaining := 0.0


func launch(from: Vector3, to: Vector3) -> void:
	global_position = from
	_target = to
	_remaining = from.distance_to(to)
	if _remaining < 0.5:
		queue_free()
		return
	look_at(to)


func _process(delta: float) -> void:
	var step := speed * delta
	if step >= _remaining:
		queue_free()
		return
	_remaining -= step
	global_position = global_position.move_toward(_target, step)
