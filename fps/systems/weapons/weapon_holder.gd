class_name WeaponHolder
extends Node3D
## Segura a arma equipada: lê os comandos do jogador e os repassa à arma.
## Fica como filho da câmera do jogador; a primeira arma filha é equipada ao iniciar.
## (Troca de armas e pegar armas do chão entram aqui no futuro.)

signal weapon_equipped(weapon: Weapon)
signal ammo_changed(in_magazine: int, reserve: int)
signal hit_confirmed(killed: bool, headshot: bool)

## Camadas físicas que os tiros atingem: mundo (1), inimigos (3), água (4).
@export_flags_3d_physics var hit_mask := 0b11101  # mundo, inimigos, água e blindagem (placa da seteira)

var current: Weapon
var player: PlayerController
var camera: CameraEffects

var _base_fov := 0.0
var _trigger_held := false


func _ready() -> void:
	add_to_group(&"player_weapons")
	player = owner as PlayerController
	camera = get_parent() as CameraEffects
	_base_fov = camera.fov
	for child in get_children():
		if child is Weapon:
			equip(child)
			break


func equip(weapon: Weapon) -> void:
	current = weapon
	weapon.holder = self
	weapon.ammo_changed.connect(ammo_changed.emit)
	weapon.hit_confirmed.connect(hit_confirmed.emit)
	weapon_equipped.emit(weapon)
	ammo_changed.emit(weapon.in_magazine, weapon.reserve)


func _unhandled_input(event: InputEvent) -> void:
	if current == null:
		return
	# Só aceita comandos com o mouse capturado (o clique que recaptura não dispara).
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		current.add_look_delta(event.relative)
	elif event.is_action_pressed(&"fire") and captured:
		_trigger_held = true
		current.try_fire()
	elif event.is_action_released(&"fire"):
		_trigger_held = false
	elif event.is_action_pressed(&"reload") and captured:
		current.start_reload()


func _process(_delta: float) -> void:
	if current == null:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	current.is_aiming = captured and Input.is_action_pressed(&"aim")
	if current.data.automatic and _trigger_held and captured:
		current.try_fire()

	var aim := smoothstep(0.0, 1.0, current.aim_blend)
	camera.fov = lerpf(Settings.fov, current.data.aim_fov, aim)
	player.look_sensitivity_multiplier = lerpf(1.0, current.data.aim_sensitivity_multiplier, aim)
	player.speed_multiplier = lerpf(1.0, current.data.aim_move_multiplier, aim)
