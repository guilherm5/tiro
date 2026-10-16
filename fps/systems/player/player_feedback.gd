extends Node
## Sensação de levar dano: solavanco de câmera para o lado do tiro, som de impacto,
## batimento cardíaco e áudio abafado com vida baixa. Também avisa o EventBus.
##
## Os efeitos de tela (vinheta, perda de cor, indicador de direção) ficam no HUD,
## que escuta o EventBus.

## Abaixo desta fração de vida começam o batimento e o som abafado.
@export_range(0.0, 1.0) var low_health_threshold := 0.5
@export var muffled_cutoff_hz := 900.0

var _player: PlayerController
var _health: Health
var _camera: CameraEffects
var _lowpass: AudioEffectLowPassFilter

@onready var _hit_audio: AudioStreamPlayer = $HitAudio
@onready var _heartbeat: AudioStreamPlayer = $Heartbeat


func _ready() -> void:
	_player = owner as PlayerController
	# Nós buscados direto: este _ready roda antes do _ready do Player.
	_health = _player.get_node(^"Health")
	_camera = _player.get_node(^"Head/CameraRig/Camera")
	_health.damaged.connect(_on_damaged)
	_health.healed.connect(func(amount: float) -> void: EventBus.player_healed.emit(amount))
	_health.died.connect(_on_died)
	_heartbeat.finished.connect(_heartbeat.play)
	_lowpass = _get_or_add_lowpass(&"SFX")


func _process(delta: float) -> void:
	var fraction := _health.current / _health.max_health
	var danger := 0.0 if _health.is_dead else clampf(1.0 - fraction / low_health_threshold, 0.0, 1.0)

	# Batimento entra e some suavemente.
	var target_db := lerpf(-40.0, -4.0, danger) if danger > 0.0 else -60.0
	_heartbeat.volume_db = move_toward(_heartbeat.volume_db, target_db, 40.0 * delta)
	if danger > 0.0 and not _heartbeat.playing:
		_heartbeat.play()
	elif _heartbeat.volume_db <= -59.0 and _heartbeat.playing:
		_heartbeat.stop()
	_heartbeat.pitch_scale = lerpf(1.0, 1.3, danger)

	if _lowpass:
		_lowpass.cutoff_hz = 400.0 if _health.is_dead else lerpf(20000.0, muffled_cutoff_hz, danger)


func _on_damaged(amount: float, hit: HitInfo) -> void:
	_hit_audio.play()
	var source := _player.global_position - Vector3.FORWARD
	if hit:
		source = hit.position - hit.direction * 10.0
	# Solavanco para o lado de onde veio o tiro.
	var local_dir := _camera.global_basis.inverse() * (source - _camera.global_position).normalized()
	_camera.kick(Vector3(randf_range(1.0, 2.5), -local_dir.x * 3.0, -local_dir.x * 4.0))
	_camera.add_trauma(clampf(amount / 60.0, 0.15, 0.6))
	EventBus.player_damaged.emit(amount, source)


func _on_died() -> void:
	EventBus.player_died.emit()


## Filtro passa-baixa no barramento de efeitos (som abafado ao estar ferido).
func _get_or_add_lowpass(bus_name: StringName) -> AudioEffectLowPassFilter:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return null
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectLowPassFilter:
			return effect
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(bus, filter)
	return filter
