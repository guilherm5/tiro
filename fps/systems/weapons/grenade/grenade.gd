class_name Grenade
extends RigidBody3D
## Granada de fragmentação Mk2 (ou de haste alemã, com `german = true`): quica, rola e
## explode quando o pavio acaba. Monta o próprio modelo e colisão (sem cena).
##
## Uso: var g := Grenade.new(); parent.add_child(g); g.throw(origem, velocidade, quem_lançou)

const EXPLOSION := preload("res://systems/fx/explosion.tscn")
const BOUNCE := preload("res://assets/audio/provisorio/granada_quique.wav")

## Segundos entre soltar a alavanca e explodir (Mk2: 4–5 s).
@export var fuse := 4.0
@export var damage_radius := 8.0
@export var max_damage := 180.0
@export var german := false

## Quem lançou (o dano conta como dele).
var thrower: Node
var _time := 0.0
var _last_bounce := 0.0
var _exploded := false


func _init() -> void:
	mass = 0.6
	collision_layer = 0
	collision_mask = 1
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	linear_damp = 0.15
	angular_damp = 1.5
	var material := PhysicsMaterial.new()
	material.bounce = 0.25
	material.friction = 0.8
	physics_material_override = material


func _ready() -> void:
	add_to_group(&"grenades")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.045
	shape.shape = sphere
	add_child(shape)
	add_child(_build_model())
	body_entered.connect(_on_body_entered)


func throw(from: Vector3, velocity: Vector3, by: Node) -> void:
	global_position = from
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-12, 12), randf_range(-6, 6), randf_range(-12, 12))
	thrower = by


## Segundos até explodir (para a IA fugir).
func time_left() -> float:
	return fuse - _time


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= fuse and not _exploded:
		_explode()


func _on_body_entered(_body: Node) -> void:
	var speed := linear_velocity.length()
	if speed > 1.2 and _time - _last_bounce > 0.12:
		_last_bounce = _time
		OneShotSound.play(get_parent(), BOUNCE, global_position, linear_to_db(clampf(speed / 8.0, 0.15, 1.0)), 6.0, 0.15)


func _explode() -> void:
	_exploded = true
	var explosion := EXPLOSION.instantiate()
	explosion.damage_radius = damage_radius
	explosion.max_damage = max_damage
	explosion.falloff_power = 1.0
	explosion.source = thrower
	get_parent().add_child(explosion)
	var on_water := global_position.y < -1.3
	explosion.detonate(global_position + Vector3.UP * 0.05, on_water)
	queue_free()


func _build_model() -> Node3D:
	var root := Node3D.new()
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.25, 0.28, 0.2) if not german else Color(0.3, 0.32, 0.3)
	body_material.roughness = 0.75
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.45, 0.43, 0.38)
	metal.metallic = 0.7
	metal.roughness = 0.45
	if german:
		# Stielhandgranate: lata no topo de um cabo de madeira.
		var head := MeshInstance3D.new()
		var can := CylinderMesh.new()
		can.top_radius = 0.035
		can.bottom_radius = 0.035
		can.height = 0.1
		can.material = body_material
		head.mesh = can
		head.position.y = 0.17
		root.add_child(head)
		var handle := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.014
		stick.bottom_radius = 0.014
		stick.height = 0.26
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.45, 0.32, 0.18)
		stick.material = wood
		handle.mesh = stick
		root.add_child(handle)
	else:
		# Mk2 "abacaxi": corpo oval e espoleta com alavanca.
		var egg := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.03
		sphere.height = 0.085
		sphere.radial_segments = 10
		sphere.rings = 6
		sphere.material = body_material
		egg.mesh = sphere
		root.add_child(egg)
		var fuze := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.018, 0.035, 0.022)
		box.material = metal
		fuze.mesh = box
		fuze.position = Vector3(0.0, 0.05, 0.0)
		root.add_child(fuze)
	for child in root.get_children():
		(child as MeshInstance3D).layers = 1
	return root
