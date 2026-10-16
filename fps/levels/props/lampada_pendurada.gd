extends Node3D
## Lâmpada pendurada por um fio no teto: balança de leve e, quando a artilharia cai
## perto (evento "explosao_proxima" ou tremor de câmera), balança forte e pisca.

@export var cable_length := 0.5
@export var light_energy := 0.9

var _light: OmniLight3D
var _swing := Vector2.ZERO
var _velocity := Vector2.ZERO
var _flicker := 0.0
var _time := 0.0


func _ready() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.1, 0.1, 0.1)
	var cable := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.006; cylinder.bottom_radius = 0.006; cylinder.height = cable_length
	cylinder.radial_segments = 4; cylinder.material = metal
	cable.mesh = cylinder
	cable.position.y = -cable_length * 0.5
	add_child(cable)
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04; cone.bottom_radius = 0.16; cone.height = 0.12
	cone.radial_segments = 12; cone.material = metal
	shade.mesh = cone
	shade.position.y = -cable_length - 0.04
	add_child(shade)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04; sphere.height = 0.08
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.85, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.8, 0.5)
	glow.emission_energy_multiplier = 3.0
	sphere.material = glow
	bulb.mesh = sphere
	bulb.position.y = -cable_length - 0.1
	add_child(bulb)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.78, 0.5)
	_light.light_energy = light_energy
	_light.omni_range = 6.0
	_light.position.y = -cable_length - 0.14
	add_child(_light)
	EventBus.narrative_event.connect(_on_event)


func _on_event(event_name: String) -> void:
	if event_name == "explosao_proxima":
		shake(1.0)


## Empurrão (explosão perto): balança e pisca.
func shake(strength: float) -> void:
	_velocity += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 2.5 * strength
	_flicker = 0.6 * strength


func _process(delta: float) -> void:
	_time += delta
	# Pêndulo amortecido + leve deriva.
	var accel := -_swing * 9.8 / cable_length - _velocity * 0.6
	_velocity += accel * delta
	_swing += _velocity * delta
	_swing += Vector2(sin(_time * 0.7), cos(_time * 0.5)) * 0.0004
	rotation = Vector3(_swing.y, 0.0, _swing.x)
	_flicker = maxf(_flicker - delta, 0.0)
	_light.light_energy = light_energy * (randf_range(0.0, 1.0) if _flicker > 0.0 and randf() < 0.5 else 1.0)
