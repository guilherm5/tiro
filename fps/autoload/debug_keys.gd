extends Node
## Teclas de teste. Só funcionam rodando pelo editor ou em builds de depuração;
## somem automaticamente na versão final exportada.
##   F1 — levar 20 de dano (de uma direção aleatória)
##   F2 — curar um bloco de vida
##   F3 — reiniciar do último checkpoint
##   F4 — recomeçar a missão do zero (apaga o checkpoint)


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			_damage_player(20.0)
		KEY_F2:
			var player := _player()
			if player:
				player.health.heal(player.health.segment_size())
		KEY_F3:
			get_tree().reload_current_scene()
		KEY_F4:
			Checkpoints.clear_current()
			get_tree().reload_current_scene()


func _damage_player(amount: float) -> void:
	var player := _player()
	if player == null:
		return
	var hit := HitInfo.new()
	hit.damage = amount
	hit.position = player.global_position + Vector3.UP
	var from_angle := randf() * TAU
	hit.direction = -Vector3(sin(from_angle), 0.0, cos(from_angle))
	player.apply_hit(hit)


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController
