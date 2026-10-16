class_name ArtilleryDirector
extends Node3D
## Artilharia de ambiente: explosões aleatórias numa área da fase, para a praia parecer
## viva e perigosa. Nunca cai perto demais do jogador (é atmosfera, não armadilha).
## Explosões perto o bastante fazem a tela tremer e suprimem.

const EXPLOSION := preload("res://systems/fx/explosion.tscn")

## Área (em coordenadas do mundo, plano XZ) onde as granadas caem.
@export var area := Rect2(-60, -20, 120, 120)
@export var interval_min := 3.0
@export var interval_max := 8.0
@export var min_distance_to_player := 16.0
## Altura da água: explosões com o chão abaixo disso viram colunas d'água.
@export var water_level := -1.5
@export var enabled := true

var _timer := 2.0


func _process(delta: float) -> void:
	if not enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(interval_min, interval_max)
	_fire_one()


func _fire_one() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	for attempt in 8:
		var point := Vector3(randf_range(area.position.x, area.end.x), 50.0,
			randf_range(area.position.y, area.end.y))
		if player and Vector2(point.x, point.z).distance_to(
				Vector2(player.global_position.x, player.global_position.z)) < min_distance_to_player:
			continue
		var ground: Variant = _ground_at(point)
		if ground == null:
			continue
		var on_water: bool = (ground as Vector3).y < water_level
		var at: Vector3 = ground
		if on_water:
			at.y = water_level
		var explosion: Explosion = EXPLOSION.instantiate()
		explosion.max_damage = 0.0  # atmosfera; o dano das granadas de verdade fica ativo
		get_parent().add_child(explosion)
		explosion.detonate(at, on_water)
		return


func _ground_at(point: Vector3) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 100.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return null if hit.is_empty() else hit.position
