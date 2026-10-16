class_name NarrativeTrigger
extends Area3D
## Gatilho de área: quando o jogador entra, emite `event_name` no EventBus.
## O script da missão decide o que acontece (fala, objetivo...). Coloque uma
## CollisionShape3D como filha para definir a área.

@export var event_name := ""
## Emitir só na primeira entrada.
@export var once := false

var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # jogador
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player") or (once and _fired):
		return
	_fired = true
	EventBus.narrative_event.emit(event_name)
