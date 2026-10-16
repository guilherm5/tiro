extends Node
## Detecta situações de combate e avisa o EventBus, para o script da missão tocar as
## falas contextuais do roteiro:
##   jogador_parado        — parado em pé, em campo aberto, por alguns segundos sob fogo
##   jogador_exposto       — sob fogo pesado (supressão alta) por um tempo
##   combate_periodico / combate_periodico_2 — de tempos em tempos enquanto há combate
## Só funciona enquanto `active` (o script da missão ou a fase desligam no fim).

@export var active := true
@export var still_time := 5.0
@export var exposed_time := 2.5
@export var periodic_min := 22.0
@export var periodic_max := 38.0

var _still := 0.0
var _exposed := 0.0
var _periodic := 0.0
var _toggle := false
var _in_combat_time := 0.0


func _ready() -> void:
	_periodic = randf_range(periodic_min, periodic_max)
	EventBus.mission_completed.connect(func(_t: String) -> void: active = false)
	EventBus.player_died.connect(func() -> void: active = false)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if not active or player == null or player.is_dead or player.is_cinematic:
		return
	var under_fire := player.suppression.level > 0.05
	_in_combat_time = _in_combat_time + delta if under_fire else maxf(_in_combat_time - delta * 0.2, 0.0)

	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed < 0.3 and not player.is_crouching and _in_combat_time > 0.0:
		_still += delta
	else:
		_still = 0.0
	if _still > still_time:
		_still = -10.0  # não repete logo em seguida
		EventBus.narrative_event.emit("jogador_parado")

	_exposed = _exposed + delta if player.suppression.level > 0.45 else 0.0
	if _exposed > exposed_time:
		_exposed = -12.0
		EventBus.narrative_event.emit("jogador_exposto")

	if _in_combat_time > 0.0:
		_periodic -= delta
		if _periodic <= 0.0:
			_periodic = randf_range(periodic_min, periodic_max)
			_toggle = not _toggle
			EventBus.narrative_event.emit("combate_periodico" if _toggle else "combate_periodico_2")
