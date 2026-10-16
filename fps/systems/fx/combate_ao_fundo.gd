extends Node3D
## Combate ao fundo (só atmosfera, sem acertar ninguém):
##  - rajadas de traçantes de pontos fixos nas encostas e nas pontas da praia em direção
##    ao mar, e de barcos de volta para a terra;
##  - aviões passando baixo de vez em quando.
## Tudo longe do jogador; os traçantes usam a mesma cena dos tiros reais.

const TRACER := preload("res://systems/fx/tracer.tscn")

## Origens (de onde atira) e alvos (para onde vai), escolhidos aos pares ao acaso.
@export var sources: PackedVector3Array = []
@export var targets: PackedVector3Array = []
@export var burst_interval := Vector2(1.5, 4.0)
@export var plane_interval := Vector2(35.0, 70.0)
@export var plane_scene: PackedScene
@export var plane_sound: AudioStream

var _burst_timer := 2.0
var _plane_timer := 20.0


func _process(delta: float) -> void:
	if sources.is_empty() or targets.is_empty():
		return
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer = randf_range(burst_interval.x, burst_interval.y)
		_burst()
	_plane_timer -= delta
	if _plane_timer <= 0.0 and plane_scene:
		_plane_timer = randf_range(plane_interval.x, plane_interval.y)
		_plane()


func _burst() -> void:
	var from := sources[randi() % sources.size()]
	var to := targets[randi() % targets.size()] + Vector3(randf_range(-8, 8), randf_range(-1, 4), randf_range(-8, 8))
	if randf() < 0.3:
		var swap := from
		from = to
		to = swap  # resposta: dos barcos para a terra
	var shots := randi_range(4, 9)
	for i in shots:
		var tracer := TRACER.instantiate()
		add_child(tracer)
		tracer.speed = 260.0
		var spread := Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), randf_range(-1.5, 1.5))
		tracer.launch(from, to + spread)
		await get_tree().create_timer(0.07).timeout
		if not is_inside_tree():
			return


func _plane() -> void:
	var plane := plane_scene.instantiate() as Node3D
	add_child(plane)
	var side := 1.0 if randf() < 0.5 else -1.0
	var z := randf_range(-40.0, 60.0)
	var height := randf_range(45.0, 70.0)
	var start := Vector3(-side * 450.0, height, z)
	var end := Vector3(side * 450.0, height + randf_range(-5, 5), z + randf_range(-60, 60))
	plane.global_position = start
	plane.look_at(end)
	if plane_sound:
		var audio := AudioStreamPlayer3D.new()
		audio.stream = plane_sound
		audio.unit_size = 60.0
		audio.max_distance = 900.0
		audio.bus = &"Ambiente"
		plane.add_child(audio)
		audio.play()
	var tween := create_tween()
	tween.tween_property(plane, ^"global_position", end, start.distance_to(end) / 85.0)
	tween.tween_callback(plane.queue_free)
