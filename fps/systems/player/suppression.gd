class_name Suppression
extends Node
## Supressão: o quanto o jogador está "sob fogo" (0..1). Sobe com balas passando perto
## e cai sozinha depois de um tempo sem fogo. O HUD usa o nível para embaçar e escurecer
## a tela; a arma usa para piorar a precisão; a câmera treme a cada bala.

@export var decay_delay := 0.5
@export var decay_rate := 0.9
## Quanto a dispersão da arma aumenta com supressão máxima (1.5 = +150%).
@export var spread_penalty := 1.5

var level := 0.0

var _since_last := 0.0
var _camera: CameraEffects


func _ready() -> void:
	_camera = owner.get_node(^"Head/CameraRig/Camera")


func add(amount: float) -> void:
	level = minf(level + amount, 1.0)
	_since_last = 0.0
	_camera.add_trauma(amount * 0.4)


func _process(delta: float) -> void:
	_since_last += delta
	if _since_last > decay_delay:
		level = maxf(level - decay_rate * delta, 0.0)
