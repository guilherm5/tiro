extends Area3D
## Kit médico: ao passar por cima, recupera um bloco de vida inteiro.
## Fica no chão se a vida já estiver cheia.

@export var heal_segments := 1.0

@onready var _audio: AudioStreamPlayer3D = $Audio


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	$Mesh.rotate_y(delta * 0.8)


func _on_body_entered(body: Node3D) -> void:
	var health: Health = body.get_node_or_null(^"Health")
	if health == null or health.is_full() or health.is_dead:
		return
	health.heal(health.segment_size() * heal_segments)
	# Toca o som antes de sumir (o áudio sai da árvore junto com o kit).
	_audio.reparent(get_parent())
	_audio.play()
	_audio.finished.connect(_audio.queue_free)
	queue_free()
