extends Node
## Gerenciador de falas (autoload "Dialogue").
##
## Carrega todos os .dlg de data/dialogue/ e toca:
##   play(id)       — sequência fixa; entra na fila e tem prioridade.
##   bark(id)       — fala contextual; só toca se ninguém estiver falando e o grupo
##                    não tiver falado há pouco. Nunca repete a mesma fala em seguida.
## Uma fala por vez, com pausa entre elas (regras 3 e 8 do roteiro).
##
## Dublagem: se existir assets/audio/voz/<id_da_fala>.ogg (ou .wav), toca e usa a
## duração do áudio. Senão, a legenda fica na tela pelo tempo de leitura.

signal line_started(line: Dictionary, speaker_name: String, color: Color)
signal line_finished(line: Dictionary)
signal sequence_finished(id: String)
## Comando de cutscene vindo do .dlg (@camera, @tremer, @explosao...).
signal command(command_name: String, args: PackedStringArray)

const RADIO_STATIC := preload("res://assets/audio/provisorio/estatica_radio.wav")

const DIALOGUE_DIR := "res://data/dialogue/"
const CHARACTERS_FILE := "res://data/dialogue/personagens.cfg"
const VOICE_DIR := "res://assets/audio/voz/"

## Segundos por caractere de leitura e mínimo por fala.
@export var reading_speed := 0.055
@export var min_line_time := 1.6
@export var gap_between_lines := 0.35
@export var bark_cooldown := 8.0

var _data := {}
var _characters := ConfigFile.new()
var _queue: Array[String] = []
var _busy := false
var _last_bark_time := {}
var _last_bark_line := {}
var _voice: AudioStreamPlayer
var _static: AudioStreamPlayer
var _skip := false


func _ready() -> void:
	_characters.load(CHARACTERS_FILE)
	for file in DirAccess.get_files_at(DIALOGUE_DIR):
		if file.ends_with(".dlg"):
			_data.merge(DialogueParser.parse_file(DIALOGUE_DIR + file))
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Voz"
	add_child(_voice)
	_static = AudioStreamPlayer.new()
	_static.stream = RADIO_STATIC
	_static.volume_db = -10.0
	_static.bus = &"Voz"
	add_child(_static)


func has_entry(id: String) -> bool:
	return _data.has(id)


func is_busy() -> bool:
	return _busy


func play(id: String) -> void:
	if not _data.has(id):
		push_warning("Fala/cena não encontrada: %s" % id)
		return
	_queue.append(id)
	if not _busy:
		_run_queue()


func bark(id: String) -> void:
	if _busy or not _data.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_bark_time.get(id, -INF)) < bark_cooldown:
		return
	var lines: Array = _data[id].items.filter(func(i: Dictionary) -> bool: return i.type == "line")
	if lines.is_empty():
		return
	var choice: Dictionary = lines.pick_random()
	if lines.size() > 1:
		while choice.id == _last_bark_line.get(id, ""):
			choice = lines.pick_random()
	_last_bark_time[id] = now
	_last_bark_line[id] = choice.id
	_busy = true
	await _say(choice)
	_busy = false
	if not _queue.is_empty():
		_run_queue()


## Para tudo (ex.: morte do jogador, troca de fase).
func stop_all() -> void:
	_queue.clear()
	_voice.stop()


## Pula a sequência em andamento (ex.: o jogador pulou a cutscene). Ela termina
## normalmente (sequence_finished), só que sem as falas restantes.
func skip_current() -> void:
	if _busy:
		_skip = true
		_voice.stop()


func display_name(speaker: String) -> String:
	return _characters.get_value(speaker, "nome", speaker.capitalize())


func speaker_color(speaker: String) -> Color:
	return _characters.get_value(speaker, "cor", Color(0.9, 0.88, 0.8))


func _run_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		_skip = false
		for item: Dictionary in _data[id].items:
			if _skip:
				break
			match item.type:
				"line":
					await _say(item)
				"pause":
					await _wait(item.seconds)
				"event":
					EventBus.narrative_event.emit(item.name)
				"command":
					command.emit(item.name, item.args)
		_skip = false
		sequence_finished.emit(id)
	_busy = false


func _say(line: Dictionary) -> void:
	var shown_name := display_name(line.speaker)
	if not line.tag.is_empty():
		shown_name += " (%s)" % line.tag.to_lower()
	line_started.emit(line, shown_name, speaker_color(line.speaker))
	if line.speaker == "RÁDIO" or line.tag.to_upper().contains("RÁDIO"):
		_static.play()
	var duration := maxf(min_line_time, line.text.length() * reading_speed)
	var stream := _find_voice(line.id)
	if stream:
		_voice.stream = stream
		_voice.play()
		duration = maxf(stream.get_length(), 0.5)
	await _wait(duration)
	line_finished.emit(line)
	await _wait(gap_between_lines)


## Espera que termina antes se a sequência for pulada.
func _wait(seconds: float) -> void:
	var remaining := seconds
	var last := Time.get_ticks_msec()
	while remaining > 0.0 and not _skip:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if not get_tree().paused:
			remaining -= (now - last) / 1000.0 * Engine.time_scale
		last = now


func _find_voice(line_id: String) -> AudioStream:
	for ext: String in [".ogg", ".wav", ".mp3"]:
		var path := VOICE_DIR + line_id + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null
