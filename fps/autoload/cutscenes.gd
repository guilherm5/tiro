extends Node
## Cutscenes (autoload "Cutscenes"): toca uma cena do .dlg com câmera cinematográfica.
##
## Uso (pelo script da missão): `cutscene id` → await Cutscenes.play(id)
## Durante a cena: o jogador não se move, a arma e o HUD somem, aparecem as faixas
## pretas e as legendas continuam.
## Ao terminar, a câmera desliza até o olhar do jogador e o controle volta.
## Pular: Espaço ou Enter (Esc abre a pausa).
##
## Comandos no .dlg (dentro da cena):
##   @camera NOME            corta para a câmera NOME
##   @camera_mover NOME 3    desliza até a câmera NOME em 3 s
##   @tremer 0.6             tremor (0..1)
##   @explosao NOME [agua]   explosão no ponto NOME (só efeito, sem dano)
## As câmeras são Marker3D em "Cutscenes/Cameras" da fase. Cada uma olha para o
## metadado `alvo` (Vector3); sem ele, usa a própria rotação.

signal started(id: String)
signal finished(id: String)

const EXPLOSION := preload("res://systems/fx/explosion.tscn")

@export var blend_back_time := 0.9

var is_playing := false

var _camera: Camera3D
var _cameras_root: Node3D
var _sway_time := 0.0
var _trauma := 0.0
var _base_transform := Transform3D.IDENTITY
var _noise := FastNoiseLite.new()
var _current_id := ""


func _ready() -> void:
	_noise.frequency = 1.0
	Dialogue.command.connect(_on_command)


## `keep_cinematic`: não devolve o controle no fim (ex.: cena final da missão).
func play(id: String, keep_cinematic := false) -> void:
	var level := get_tree().current_scene
	_cameras_root = level.get_node_or_null(^"Cutscenes/Cameras") as Node3D
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	is_playing = true
	_current_id = id
	if player:
		player.set_cinematic(true)
	# Reaproveita a câmera se a cena anterior terminou sem devolver o controle.
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 60.0
		_camera.near = 0.05
		level.add_child(_camera)
		if player:
			_camera.global_transform = player.camera.global_transform
			_base_transform = _camera.global_transform
	_camera.current = true
	EventBus.cutscene_started.emit(id)
	started.emit(id)

	Dialogue.play(id)
	while true:
		var done: String = await Dialogue.sequence_finished
		if done == id:
			break

	if keep_cinematic:
		is_playing = false
		EventBus.cutscene_finished.emit(id)
		finished.emit(id)
		return
	# Volta suavemente para o olhar do jogador.
	if player:
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void:
			_base_transform = _base_transform.interpolate_with(player.camera.global_transform, t),
			0.0, 1.0, blend_back_time).set_trans(Tween.TRANS_SINE)
		await tween.finished
		player.camera.current = true
		player.set_cinematic(false)
	_camera.queue_free()
	_camera = null
	is_playing = false
	EventBus.cutscene_finished.emit(id)
	finished.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
	if get_tree().paused:
		return
	if event.is_action_pressed(&"jump") \
			or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER):
		get_viewport().set_input_as_handled()
		Dialogue.skip_current()


func _process(delta: float) -> void:
	if _camera == null:
		return
	_sway_time += delta
	_trauma = maxf(_trauma - delta * 1.2, 0.0)
	# Balanço leve (câmera na mão / barco) + tremor.
	var sway := Vector3(sin(_sway_time * 0.7) * 0.6, sin(_sway_time * 0.5) * 0.5, sin(_sway_time * 0.9) * 0.8)
	var shake := _trauma * _trauma
	var rot := Vector3(
		deg_to_rad(sway.x + _noise.get_noise_2d(_sway_time * 20.0, 0.0) * 4.0 * shake),
		deg_to_rad(sway.y + _noise.get_noise_2d(_sway_time * 20.0, 50.0) * 4.0 * shake),
		deg_to_rad(sway.z + _noise.get_noise_2d(_sway_time * 20.0, 90.0) * 3.0 * shake))
	_camera.global_transform = _base_transform * Transform3D(Basis.from_euler(rot), Vector3.ZERO)


func _on_command(command_name: String, args: PackedStringArray) -> void:
	match command_name:
		"camera":
			var t: Variant = _camera_transform(args[0])
			if t != null:
				_base_transform = t
		"camera_mover":
			var t: Variant = _camera_transform(args[0])
			if t != null:
				var from := _base_transform
				var to: Transform3D = t
				var tween := create_tween()
				tween.tween_method(func(k: float) -> void: _base_transform = from.interpolate_with(to, k),
					0.0, 1.0, float(args[1]) if args.size() > 1 else 2.0).set_trans(Tween.TRANS_SINE)
		"tremer":
			_trauma = minf(_trauma + (float(args[0]) if args.size() > 0 else 0.5), 1.0)
		"explosao":
			var point := _find_point(args[0])
			if point:
				var explosion: Explosion = EXPLOSION.instantiate()
				explosion.max_damage = 0.0
				get_tree().current_scene.add_child(explosion)
				explosion.detonate(point.global_position, args.size() > 1 and args[1] == "agua")
				_trauma = minf(_trauma + 0.5, 1.0)


func _camera_transform(camera_name: String) -> Variant:
	var marker := _find_point(camera_name)
	if marker == null:
		return null
	if marker.has_meta(&"alvo"):
		var target: Vector3 = marker.get_meta(&"alvo")
		return Transform3D.IDENTITY.looking_at(target - marker.global_position, Vector3.UP).translated(marker.global_position)
	return marker.global_transform


func _find_point(point_name: String) -> Node3D:
	if _cameras_root == null:
		push_warning("A fase não tem o nó Cutscenes/Cameras")
		return null
	var node := _cameras_root.find_child(point_name, true, false) as Node3D
	if node == null:
		push_warning("Câmera/ponto de cutscene não encontrado: %s" % point_name)
	return node
