class_name OneShotSound
extends RefCounted
## Toca um som 3D num ponto do mundo e remove o player ao terminar.


static func play(parent: Node, stream: AudioStream, position: Vector3,
		volume_db := 0.0, unit_size := 10.0, pitch_range := 0.06) -> AudioStreamPlayer3D:
	if stream == null or parent == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = unit_size
	player.max_distance = 400.0
	# Sons fortes (tiros, explosões) perdem os agudos com a distância: de longe, abafados.
	if unit_size >= 12.0:
		player.attenuation_filter_cutoff_hz = 3200.0
		player.attenuation_filter_db = -30.0
	player.bus = &"SFX"
	player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	parent.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Barramento de reverberação no ponto (áreas com reverb_bus_enabled; vale a de maior
## prioridade). Vazio se não houver.
static func reverb_bus_at(world: World3D, position: Vector3) -> StringName:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var best: Area3D = null
	for result in world.direct_space_state.intersect_point(query, 8):
		var area := result.collider as Area3D
		if area and area.reverb_bus_enabled and (best == null or area.priority > best.priority):
			best = area
	return best.reverb_bus_name if best else &""


## Só a reverberação de um som não posicional (ex.: o tiro do próprio jogador), no
## barramento de eco do lugar onde ele está.
static func play_echo(parent: Node, stream: AudioStream, position: Vector3, volume_db := -4.0) -> void:
	var bus := reverb_bus_at(parent.get_viewport().world_3d, position)
	if bus.is_empty() or stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
