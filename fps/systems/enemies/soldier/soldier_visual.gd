extends Node3D
## Visual PROVISÓRIO do soldado (formas simples animadas por código).
##
## Quando chegar o modelo com animações (Mixamo), troque esta cena/script por outro
## que implemente os mesmos métodos: set_crouched, set_aiming, set_aim_pitch,
## flinch, die, muzzle_flash. O resto do inimigo não muda.

const LEG_HEIGHT := 0.85

var _crouch := 0.0
var _crouch_target := 0.0
var _aim := 0.0
var _aim_target := 0.0
var _aim_pitch := 0.0
var _flinch := Spring3.new(120.0, 10.0)
var _flash_time := 0.0
var _dead := false

@onready var _legs: Node3D = $Legs
@onready var _upper: Node3D = $Upper
@onready var _rifle: Node3D = $Upper/RiflePivot
@onready var _flash: Node3D = $Upper/RiflePivot/Muzzle/Flash
@onready var _flash_light: OmniLight3D = $Upper/RiflePivot/Muzzle/Light
@onready var muzzle: Node3D = $Upper/RiflePivot/Muzzle


func _ready() -> void:
	_flash.hide()
	_flash_light.hide()


func set_crouched(value: bool) -> void:
	_crouch_target = 1.0 if value else 0.0


func set_aiming(value: bool) -> void:
	_aim_target = 1.0 if value else 0.0


## Inclinação da arma para cima/baixo ao mirar (radianos).
func set_aim_pitch(radians: float) -> void:
	_aim_pitch = clampf(radians, -0.8, 0.8)


## Tranco ao ser atingido. `local_direction`: direção do tiro no espaço do soldado.
func flinch(local_direction: Vector3) -> void:
	_flinch.velocity += Vector3(-local_direction.z * 6.0 - 3.0, 0.0, local_direction.x * 6.0)


func die(local_direction: Vector3) -> void:
	_dead = true
	set_aiming(false)
	var fall_axis := Vector3(local_direction.z, 0.0, -local_direction.x).normalized()
	if fall_axis.is_zero_approx():
		fall_axis = Vector3.RIGHT
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var target_basis := Basis(fall_axis, deg_to_rad(88.0)) * basis
	tween.tween_property(self, ^"basis", target_basis, 0.55)
	tween.tween_property(self, ^"position:y", 0.15, 0.55)
	tween.tween_property(_rifle, ^"rotation:x", deg_to_rad(-70.0), 0.4)


func muzzle_flash() -> void:
	_flash.show()
	_flash_light.show()
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_flash_time = 0.06


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.hide()
			_flash_light.hide()
	if _dead:
		return

	_crouch = move_toward(_crouch, _crouch_target, delta / 0.25)
	_aim = move_toward(_aim, _aim_target, delta / 0.3)
	var crouch := smoothstep(0.0, 1.0, _crouch)
	_legs.scale.y = lerpf(1.0, 0.5, crouch)
	_upper.position.y = LEG_HEIGHT * _legs.scale.y
	var flinch := _flinch.update(delta)
	_upper.rotation = Vector3(lerpf(0.0, 0.25, crouch), 0.0, 0.0) + flinch
	_rifle.rotation.x = lerpf(deg_to_rad(-50.0), _aim_pitch - _upper.rotation.x, smoothstep(0.0, 1.0, _aim))
