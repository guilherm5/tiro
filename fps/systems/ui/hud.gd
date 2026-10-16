extends CanvasLayer
## HUD: mira, munição, vida em blocos, efeitos de ferimento e tela de morte.
## Encontra o jogador pelos grupos "player" e "player_weapons".
## (Objetivos e legendas entram na etapa 7.)

## Abaixo desta fração de vida a tela perde cor e escurece nas bordas.
@export_range(0.0, 1.0) var low_health_threshold := 0.5
@export var restart_delay := 4.0

var _holder: WeaponHolder
var _player: PlayerController
var _flash := 0.0
var _letterbox_tween: Tween
var _waiting_for_menu := false
var _interactor: Interactor
var _prompt: Label
var _prompt_bar: ProgressBar
var _grenades: Label

@onready var _crosshair: Control = $Crosshair
@onready var _ammo: Label = $Ammo
@onready var _health_bar: Control = $HealthBar
@onready var _overlay: ColorRect = $DamageOverlay
@onready var _death_screen: Control = $DeathScreen


func _ready() -> void:
	add_to_group(&"hud")
	_build_film_layer()
	_build_lens_layer()
	_death_screen.hide()
	$Letterbox.hide()
	_cover_start()
	EventBus.cutscene_started.connect(func(_id: String) -> void: _set_cinematic(true))
	EventBus.cutscene_finished.connect(func(_id: String) -> void: _set_cinematic(false))
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_player_died)
	EventBus.mission_completed.connect(_on_mission_completed)
	$MissionComplete.hide()
	_build_prompt()
	# Espera um quadro para o jogador (e a arma) estarem prontos, em qualquer ordem de cena.
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group(&"player")
	if _player:
		_health_bar.health = _player.health
		_interactor = _player.get_node_or_null(^"Interactor")
		var thrower := _player.get_node_or_null(^"GrenadeThrower") as GrenadeThrower
		if thrower:
			thrower.count_changed.connect(_on_grenades_changed)
			_on_grenades_changed(thrower.count)
	_holder = get_tree().get_first_node_in_group(&"player_weapons")
	if _holder:
		_holder.ammo_changed.connect(_on_ammo_changed)
		_holder.hit_confirmed.connect(_on_hit_confirmed)
		if _holder.current:
			_on_ammo_changed(_holder.current.in_magazine, _holder.current.reserve)


func _process(delta: float) -> void:
	_update_damage_overlay(delta)
	_update_prompt()
	if _holder == null or _holder.current == null or _player.is_dead:
		_crosshair.opacity = 0.0
		return
	var weapon := _holder.current
	_crosshair.spread_degrees = weapon.current_spread
	var hidden_by_aim := smoothstep(0.0, 0.5, weapon.aim_blend)
	_crosshair.opacity = 0.0 if _player.is_sprinting else 1.0 - hidden_by_aim


## "[E] Pegar o torpedo" no centro da tela, com barra quando é preciso segurar.
func _build_prompt() -> void:
	_prompt = MenuStyle.caption("", 20, Color(0.95, 0.92, 0.85))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = 60
	_prompt.offset_bottom = 90
	_prompt.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override(&"shadow_offset_x", 2)
	_prompt.add_theme_constant_override(&"shadow_offset_y", 2)
	add_child(_prompt)
	_prompt_bar = ProgressBar.new()
	_prompt_bar.show_percentage = false
	_prompt_bar.max_value = 1.0
	_prompt_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt_bar.offset_left = -90
	_prompt_bar.offset_right = 90
	_prompt_bar.offset_top = 96
	_prompt_bar.offset_bottom = 104
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.85, 0.7)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	_prompt_bar.add_theme_stylebox_override(&"fill", fill)
	_prompt_bar.add_theme_stylebox_override(&"background", back)
	add_child(_prompt_bar)
	_grenades = MenuStyle.caption("", 18)
	_grenades.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_grenades.offset_left = -260
	_grenades.offset_right = -40
	_grenades.offset_top = -96
	_grenades.offset_bottom = -72
	_grenades.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_grenades)


func _update_prompt() -> void:
	var text := ""
	var progress := 0.0
	if _interactor and not _player.is_dead and not _player.is_cinematic:
		text = _interactor.prompt_text
		progress = _interactor.progress
	_prompt.text = "[E]  " + text if not text.is_empty() else ""
	_prompt_bar.visible = progress > 0.0
	_prompt_bar.value = progress


func _on_grenades_changed(count: int) -> void:
	_grenades.text = "Granadas  %d   [G]" % count if count > 0 else ""


func _update_damage_overlay(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 2.0)
	var danger := 0.0
	if _player:
		var fraction := _player.health.current / _player.health.max_health
		danger = 1.0 if _player.is_dead else clampf(1.0 - fraction / low_health_threshold, 0.0, 1.0)
	var suppressed := 0.0
	if _player and not _player.is_dead:
		suppressed = _player.suppression.level
	var material := _overlay.material as ShaderMaterial
	material.set_shader_parameter(&"desaturation", maxf(danger * 0.85, suppressed * 0.15))
	material.set_shader_parameter(&"vignette", maxf(danger, suppressed * 0.35))
	material.set_shader_parameter(&"flash", _flash)
	material.set_shader_parameter(&"blur", suppressed * 0.6)
	_overlay.visible = danger > 0.0 or _flash > 0.0 or suppressed > 0.0


func _on_player_damaged(amount: float, _source: Vector3) -> void:
	_flash = clampf(_flash + amount / 40.0, 0.0, 1.0)


## A fase começa com a tela preta (sem "piscar" o cenário antes da cartela). Se a
## missão não pedir cartela logo (ex.: voltou de um checkpoint), a tela clareia.
func _cover_start() -> void:
	var card: Control = $TitleCard
	card.get_node(^"Titulo").text = ""
	card.get_node(^"Subtitulo").text = ""
	card.show()
	await get_tree().create_timer(1.6).timeout
	if card.get_node(^"Titulo").text.is_empty():
		var tween := create_tween()
		tween.tween_property(card, ^"modulate:a", 0.0, 0.8)
		tween.tween_callback(card.hide)


## Tela de título (ex.: "MISSÃO 1 — DESEMBARQUE"). Espera terminar.
func show_title_card(title: String, subtitle: String) -> void:
	var card: Control = $TitleCard
	card.get_node(^"Titulo").text = title
	card.get_node(^"Subtitulo").text = subtitle
	card.modulate.a = 1.0
	card.get_node(^"Titulo").modulate.a = 0.0
	card.get_node(^"Subtitulo").modulate.a = 0.0
	card.show()
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(card.get_node(^"Titulo"), ^"modulate:a", 1.0, 1.2)
	tween.tween_property(card.get_node(^"Subtitulo"), ^"modulate:a", 1.0, 1.0)
	tween.tween_interval(2.8)
	tween.tween_property(card, ^"modulate:a", 0.0, 1.4)
	await tween.finished
	card.hide()


## Em cutscene: some com mira, munição, vida, objetivo e ajuda; entram as faixas pretas.
func _set_cinematic(value: bool) -> void:
	for path in [^"Crosshair", ^"Ammo", ^"HealthBar", ^"Objective", ^"DamageIndicator"]:
		get_node(path).visible = not value
	_grenades.visible = not value
	var scene := get_tree().current_scene
	var help := scene.get_node_or_null(^"AjudaControles") if scene else null
	if help:
		help.visible = not value
	var bars: Control = $Letterbox
	if _letterbox_tween:
		_letterbox_tween.kill()
	bars.show()
	_letterbox_tween = create_tween()
	_letterbox_tween.tween_property(bars, ^"modulate:a", 1.0 if value else 0.0, 0.6)
	if not value:
		_letterbox_tween.tween_callback(bars.hide)


func _on_hit_confirmed(killed: bool, _headshot: bool) -> void:
	_crosshair.show_hit_marker(killed)
	$HitMarkerAudio.play()


func _on_ammo_changed(in_magazine: int, reserve: int) -> void:
	_ammo.text = "%d  |  %d" % [in_magazine, reserve]
	_ammo.modulate = Color(1, 0.45, 0.35) if in_magazine == 0 else Color.WHITE


func _on_mission_completed(title: String) -> void:
	var card: Control = $MissionComplete
	card.get_node(^"Texto").text = "MISSÃO CONCLUÍDA — %s" % title if not title.is_empty() else "MISSÃO CONCLUÍDA"
	card.modulate.a = 0.0
	card.show()
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(card, ^"modulate:a", 1.0, 2.0)
	tween.tween_interval(3.0)
	tween.tween_callback(func() -> void:
		var hint := MenuStyle.caption("Pressione Enter para voltar ao menu", 16)
		hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		hint.position += Vector2(-150, -90)
		card.add_child(hint)
		_waiting_for_menu = true)


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for_menu and (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"jump")):
		_waiting_for_menu = false
		SceneLoader.go_to_menu()


func _on_player_died() -> void:
	Dialogue.stop_all()
	_ammo.hide()
	_health_bar.hide()
	_grenades.hide()
	_death_screen.modulate.a = 0.0
	_death_screen.show()
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(_death_screen, ^"modulate:a", 1.0, 1.5)
	tween.tween_interval(restart_delay - 2.3)
	# Sem checkpoints por enquanto: recomeça a fase (checkpoints entram na etapa 8).
	tween.tween_callback(get_tree().reload_current_scene)


## Camada de "filme" (vinheta, granulado, tom) logo acima do mundo e da arma (camada 0,
## depois da vista da arma na árvore) e abaixo do HUD. Liga/desliga pelas configurações.
func _build_film_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Filme"
	layer.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://systems/fx/filme.gdshader")
	rect.material = material
	layer.add_child(rect)
	add_child(layer)
	var update := func() -> void: layer.visible = Settings.film_effect
	update.call()
	Settings.changed.connect(update)


var _lens: ColorRect
var _lens_amount := 0.0


## Gotas d'água na lente (ao entrar na água funda ou com explosão na água perto).
func _build_lens_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Lente"
	layer.layer = 0
	_lens = ColorRect.new()
	_lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://systems/fx/lente_molhada.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.028
	noise.cellular_jitter = 0.9
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	material.set_shader_parameter(&"drops", texture)
	_lens.material = material
	_lens.hide()
	layer.add_child(_lens)
	add_child(layer)
	move_child(layer, 0)  # antes do filme: as gotas também ganham granulado
	EventBus.narrative_event.connect(func(event_name: String) -> void:
		if event_name == "agua_na_lente":
			_lens_amount = 1.0)


func _physics_process(delta: float) -> void:
	if _lens == null:
		return
	if _lens_amount > 0.0:
		_lens_amount = maxf(_lens_amount - delta / 3.5, 0.0)
		var material := _lens.material as ShaderMaterial
		material.set_shader_parameter(&"amount", _lens_amount)
		material.set_shader_parameter(&"slide", 1.0 - _lens_amount)
	_lens.visible = _lens_amount > 0.0

