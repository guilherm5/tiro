extends GPUParticles3D
## Partículas de disparo único que se removem sozinhas ao terminar (fumaça do cano etc.).


func _ready() -> void:
	finished.connect(queue_free)
	restart()
