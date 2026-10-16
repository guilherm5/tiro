class_name CameraEffects
extends Camera3D
## Efeitos da câmera do jogador: solavanco de recuo (volta sozinho) e tremor.
##
## O tremor usa "trauma" (0..1): tiros e explosões somam trauma, que decai com o tempo.
## A intensidade é trauma², então tremores pequenos são sutis e grandes são violentos.

@export var max_shake_degrees := Vector3(2.0, 2.0, 2.5)
@export var max_shake_offset := 0.025
@export var trauma_decay := 1.8
@export var shake_frequency := 22.0

var trauma := 0.0

var _kick := Spring3.new(200.0, 20.0)
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_noise.frequency = 1.0


## Solavanco em graus: x = para cima, y = para os lados, z = inclinação.
func kick(degrees: Vector3) -> void:
	var radians := Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))
	_kick.value += radians * 0.5
	_kick.velocity += radians * 14.0


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _process(delta: float) -> void:
	_time += delta
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	var shake := trauma * trauma
	var kick := _kick.update(delta)

	rotation = kick + Vector3(
		deg_to_rad(max_shake_degrees.x) * shake * _shake_noise(0.0),
		deg_to_rad(max_shake_degrees.y) * shake * _shake_noise(100.0),
		deg_to_rad(max_shake_degrees.z) * shake * _shake_noise(200.0))
	position = Vector3(_shake_noise(300.0), _shake_noise(400.0), 0.0) * max_shake_offset * shake


func _shake_noise(seed_offset: float) -> float:
	return _noise.get_noise_2d(_time * shake_frequency, seed_offset)
