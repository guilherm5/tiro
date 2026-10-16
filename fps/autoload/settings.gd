extends Node
## Configurações do jogador (autoload "Settings"), salvas em user://configuracoes.cfg.
## Quem depende delas escuta `changed` (jogador: sensibilidade/FOV; HUD: legendas).
##
## Qualidade gráfica (pensada para GPU integrada):
##   0 Baixa — resolução 3D a 67% (FSR), sem SSAO nem glow, sombras 1024
##   1 Média — resolução 3D a 85% (FSR), sem SSAO, glow ligado, sombras 2048
##   2 Alta  — resolução 3D cheia, SSAO e glow ligados, sombras 4096

signal changed

const PATH := "user://configuracoes.cfg"
const QUALITY_NAMES := ["Baixa", "Média", "Alta"]

var mouse_sensitivity := 1.0
var invert_y := false
var fov := 72.0
var volume_master := 1.0
var volume_sfx := 1.0
var volume_voice := 1.0
var volume_ambient := 0.8
var subtitles := true
var subtitle_size := 21
var fullscreen := false
var vsync := true
var quality := 1
## Vinheta, granulado e tom de película na tela de jogo.
var film_effect := true


func _ready() -> void:
	load_settings()
	apply()
	get_tree().node_added.connect(_on_node_added)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for key in _keys():
		set(key, config.get_value("jogo", key, get(key)))


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in _keys():
		config.set_value("jogo", key, get(key))
	config.save(PATH)


func apply() -> void:
	_set_bus(&"Master", volume_master)
	_set_bus(&"SFX", volume_sfx)
	_set_bus(&"Voz", volume_voice)
	_set_bus(&"Ambiente", volume_ambient)
	var window := get_window()
	if window and not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_apply_quality()
	changed.emit()


func _apply_quality() -> void:
	var viewport := get_viewport()
	var scale: float = [0.67, 0.85, 1.0][quality]
	viewport.scaling_3d_scale = scale
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][quality], true)
	var environment := viewport.world_3d.environment if viewport.world_3d else null
	if environment:
		_apply_environment(environment)


func _apply_environment(environment: Environment) -> void:
	environment.ssao_enabled = quality >= 2
	environment.glow_enabled = quality >= 1


## Fases carregadas depois também recebem a qualidade escolhida.
func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_apply_environment.call_deferred((node as WorldEnvironment).environment)


func _set_bus(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


func _keys() -> Array[String]:
	return ["mouse_sensitivity", "invert_y", "fov", "volume_master", "volume_sfx", "volume_voice",
		"volume_ambient", "subtitles", "subtitle_size", "fullscreen", "vsync", "quality", "film_effect"]
