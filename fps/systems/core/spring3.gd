class_name Spring3
extends RefCounted
## Mola amortecida para animações procedurais (recuo da arma, solavanco da câmera).
## Desloque `value` ou some em `velocity`; `update()` puxa de volta para zero.

var value := Vector3.ZERO
var velocity := Vector3.ZERO
var stiffness: float
var damping: float


func _init(spring_stiffness: float, spring_damping: float) -> void:
	stiffness = spring_stiffness
	damping = spring_damping


func update(delta: float) -> Vector3:
	# Passos pequenos: com um quadro longo (travada, alt-tab) a mola não "explode".
	var remaining := minf(delta, 0.25)
	while remaining > 0.0:
		var step := minf(remaining, 1.0 / 120.0)
		velocity += (-value * stiffness - velocity * damping) * step
		value += velocity * step
		remaining -= step
	return value
