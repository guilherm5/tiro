extends Node3D
## Rampa da embarcação: fechada (em pé) até o evento `abrir_evento`, então desce com
## som de aço e espirro d'água. Fica aberta direto ao voltar de um checkpoint.

@export var abrir_evento := "rampa_abaixa"
@export var open_angle_degrees := -106.7
@export var open_time := 1.1

var _open := false

@onready var _audio: AudioStreamPlayer3D = $Audio


func _ready() -> void:
	EventBus.narrative_event.connect(_on_event)


func _on_event(event_name: String) -> void:
	if event_name == "checkpoint_restaurado":
		_open = true
		rotation.x = deg_to_rad(open_angle_degrees)
	elif event_name == abrir_evento and not _open:
		_open = true
		_audio.play()
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(self, ^"rotation:x", deg_to_rad(open_angle_degrees), open_time)
