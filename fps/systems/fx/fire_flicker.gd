extends OmniLight3D
## Luz de fogo tremulando (intensidade e leve deslocamento).

@export var base_energy := 2.5
@export var variation := 0.9
@export var speed := 9.0

var _noise := FastNoiseLite.new()
var _time := randf() * 100.0
var _origin := Vector3.ZERO


func _ready() -> void:
	_noise.frequency = 1.0
	_origin = position


func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = base_energy + _noise.get_noise_1d(_time) * variation * 2.0
	position = _origin + Vector3(_noise.get_noise_1d(_time + 50.0), _noise.get_noise_1d(_time + 90.0), 0.0) * 0.15
