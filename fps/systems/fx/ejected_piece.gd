class_name EjectedPiece
extends Node3D
## Peça ejetada pela arma (cápsula, pente). Movimento balístico simples, sem física
## real: some antes de alguém notar que atravessa o chão.

## Som ao bater no chão (cápsula tilintando, pente).
@export var land_sound: AudioStream
## Segundos até "bater no chão" (a peça não tem física real).
@export var land_time := 0.45

var velocity := Vector3.ZERO
var lifetime := 1.0
var spin := Vector3.ZERO
var _age := 0.0
var _landed := false


func _ready() -> void:
	spin = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))


func _process(delta: float) -> void:
	velocity.y -= 9.8 * delta
	global_position += velocity * delta
	rotation += spin * delta
	lifetime -= delta
	_age += delta
	if land_sound and not _landed and _age >= land_time:
		_landed = true
		OneShotSound.play(get_parent(), land_sound, global_position, -6.0, 2.0, 0.1)
	if lifetime <= 0.0:
		queue_free()
