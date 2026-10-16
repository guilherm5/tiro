extends AudioStreamPlayer
## Passos do jogador (sinal `footstep` do PlayerController), com som pela superfície sob
## os pés: metadado "surface" do que está embaixo (areia, concreto, madeira, metal) ou
## água, quando os pés estão abaixo do nível do mar.
##
## Também calcula a profundidade da água: na água o jogador anda mais devagar
## (`PlayerController.wade_multiplier`).

@export var sprint_volume_boost_db := 3.0
## Altura da superfície do mar (nó Geometria/Agua da fase).
@export var water_level := -1.5
## Profundidade (m) em que a lentidão é máxima.
@export var deep_water := 1.0
## Velocidade mínima na água funda (fração da normal).
@export var deep_water_speed := 0.65

const SURFACES := {
	&"concreto": ["passo_concreto_1", "passo_concreto_2", "passo_concreto_3"],
	&"metal": ["passo_concreto_1", "passo_concreto_2", "passo_concreto_3"],
	&"madeira": ["passo_madeira_1", "passo_madeira_2", "passo_madeira_3"],
	&"agua": ["passo_agua_1", "passo_agua_2", "passo_agua_3"],
}

var water_depth := 0.0
var _wet_lens := false  # água na lente ao mergulhar fundo (uma vez por entrada)

var _base_volume := 0.0
var _sand: AudioStream
var _streams := {}
var _player: PlayerController


func _ready() -> void:
	_base_volume = volume_db
	_sand = stream
	_player = owner as PlayerController
	_player.footstep.connect(_on_footstep)
	for surface: StringName in SURFACES:
		var randomizer := AudioStreamRandomizer.new()
		randomizer.random_pitch = 1.08
		for file: String in SURFACES[surface]:
			randomizer.add_stream(-1, load("res://assets/audio/provisorio/%s.wav" % file))
		_streams[surface] = randomizer


func _physics_process(_delta: float) -> void:
	water_depth = maxf(water_level - _player.global_position.y, 0.0)
	var slow := clampf(water_depth / deep_water, 0.0, 1.0)
	_player.wade_multiplier = lerpf(1.0, deep_water_speed, slow)
	if water_depth > 0.8 and not _wet_lens:
		_wet_lens = true
		EventBus.narrative_event.emit("agua_na_lente")
	elif water_depth < 0.2:
		_wet_lens = false


func _on_footstep(is_sprinting: bool) -> void:
	var surface := _surface()
	stream = _streams.get(surface, _sand)
	volume_db = _base_volume + (sprint_volume_boost_db if is_sprinting else 0.0) + (3.0 if surface == &"agua" else 0.0)
	play()


func _surface() -> StringName:
	if water_depth > 0.04:
		return &"agua"
	var from := _player.global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8, 1, [_player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return &"areia"
	var collider: Object = hit.collider
	# A trincheira tem estrado de tábuas (sem colisão própria) sobre o chão do terreno.
	var terrain := collider as BeachTerrain
	if terrain and not terrain.trench.is_empty():
		var p := _player.global_position
		var info := terrain.trench_at(p.x, p.z)
		if info.x < terrain.trench_bottom_half_width and info.y > 0.6:
			return &"madeira"
	return collider.get_meta(&"surface", &"areia")
