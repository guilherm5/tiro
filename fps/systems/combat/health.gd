class_name Health
extends Node
## Vida reutilizável (jogador, inimigos, objetos destrutíveis).
##
## Com `regenerates`, a vida é dividida em `segment_count` blocos: depois de
## `regen_delay` segundos sem dano, ela volta só até o fim do bloco atual. Um bloco
## perdido inteiro só volta com cura (kit médico).

signal damaged(amount: float, hit: HitInfo)
signal healed(amount: float)
signal changed(current: float, maximum: float)
signal died

@export var max_health := 100.0

@export_group("Regeneração")
@export var regenerates := false
@export_range(1, 10) var segment_count := 4
@export var regen_delay := 4.0
## Vida recuperada por segundo.
@export var regen_rate := 10.0

var current := 0.0
var is_dead := false

var _since_damage := 0.0


func _ready() -> void:
	current = max_health
	set_process(regenerates)


func segment_size() -> float:
	return max_health / segment_count


## Limite da regeneração: o topo do bloco em que a vida está agora.
func regen_cap() -> float:
	var size := segment_size()
	return minf(ceilf(current / size - 0.0001) * size, max_health)


func take_damage(amount: float, hit: HitInfo = null) -> void:
	if is_dead or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	_since_damage = 0.0
	damaged.emit(amount, hit)
	changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0 or current >= max_health:
		return
	var before := current
	current = minf(current + amount, max_health)
	healed.emit(current - before)
	changed.emit(current, max_health)


func is_full() -> bool:
	return current >= max_health


func _process(delta: float) -> void:
	if is_dead:
		return
	_since_damage += delta
	if _since_damage < regen_delay:
		return
	var cap := regen_cap()
	if current < cap:
		current = minf(current + regen_rate * delta, cap)
		changed.emit(current, max_health)
