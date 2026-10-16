extends Node3D
## Embarcação de fundo (atmosfera): avança devagar em direção à praia e recomeça
## lá atrás. "Embarcações continuam chegando ao fundo."

@export var speed := 2.2
@export var start_z := 150.0
@export var end_z := 92.0

var _bob := randf() * 10.0


func _ready() -> void:
	position.z = randf_range(end_z, start_z)


func _process(delta: float) -> void:
	_bob += delta
	position.z -= speed * delta
	position.y = -1.6 + sin(_bob * 1.3) * 0.12
	rotation.z = sin(_bob * 0.9) * 0.03
	if position.z < end_z:
		position.z = start_z
