extends Node3D
## Arame farpado em concertina tripla (dois rolos embaixo, um em cima) sobre cavaletes,
## bloqueando uma passagem. Tem um ponto para plantar o torpedo Bangalore (E, segurando):
## o pavio queima `fuse_time` segundos e a explosão abre a passagem.
##
## Eventos narrativos: "bangalore_plantado" e "arame_destruido". Depois de destruído,
## refaz a malha de navegação (aliados e inimigos passam a usar a abertura).

const EXPLOSION := preload("res://systems/fx/explosion.tscn")
const FUSE_SOUND := preload("res://assets/audio/provisorio/pavio.wav")
const RATTLE := preload("res://assets/audio/provisorio/arame.wav")
const HANDLING := preload("res://assets/audio/provisorio/manuseio.wav")

## Comprimento coberto (eixo X local).
@export var length := 8.0
@export var coil_radius := 0.42
@export var fuse_time := 7.0
@export var stakes_material: Material

var destroyed := false

var _wire: MeshInstance3D
var _body: StaticBody3D
var _torpedo: Node3D
var _fuse: AudioStreamPlayer3D
var _plant: Interactable


func _ready() -> void:
	_wire = MeshInstance3D.new()
	_wire.name = "Arame"
	_wire.mesh = _build_wire()
	_wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wire)
	add_child(_build_stakes())

	_body = StaticBody3D.new()
	_body.name = "Bloqueio"
	_body.add_to_group(&"navegacao")
	_body.set_meta(&"surface", &"metal")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 2.2, coil_radius * 4.0)
	shape.shape = box
	shape.position.y = 1.1
	_body.add_child(shape)
	add_child(_body)

	_torpedo = _build_torpedo()
	_torpedo.hide()
	add_child(_torpedo)

	_fuse = AudioStreamPlayer3D.new()
	_fuse.stream = FUSE_SOUND
	_fuse.unit_size = 5.0
	_fuse.bus = &"SFX"
	_fuse.position = Vector3(0.0, 0.2, coil_radius * 2.2)
	add_child(_fuse)

	_plant = Interactable.new()
	_plant.name = "PontoBangalore"
	_plant.prompt = "Plantar o torpedo Bangalore (segure)"
	_plant.missing_prompt = "Arame farpado — é preciso um torpedo Bangalore"
	_plant.requires_item = "bangalore"
	_plant.hold_time = 3.0
	_plant.event_name = "bangalore_plantado"
	var plant_shape := CollisionShape3D.new()
	var plant_box := BoxShape3D.new()
	plant_box.size = Vector3(length * 0.6, 1.4, 0.6)
	plant_shape.shape = plant_box
	_plant.add_child(plant_shape)
	_plant.position = Vector3(0.0, 0.7, coil_radius * 2.0 + 0.3)
	add_child(_plant)
	_plant.interacted.connect(_on_planted)


func _on_planted(player: Node) -> void:
	_torpedo.show()
	OneShotSound.play(self, HANDLING, _plant.global_position, -2.0, 6.0)
	OneShotSound.play(self, RATTLE, _plant.global_position, -6.0, 6.0)
	_fuse.play()
	EventBus.noise_emitted.emit(global_position, 20.0, player)
	await get_tree().create_timer(fuse_time).timeout
	_detonate(player)


func _detonate(player: Node) -> void:
	_fuse.stop()
	destroyed = true
	var explosion := EXPLOSION.instantiate()
	explosion.damage_radius = 5.0
	explosion.max_damage = 220.0
	explosion.source = player
	get_tree().current_scene.add_child(explosion)
	explosion.detonate(global_position + Vector3.UP * 0.3)
	# O barulho atrai os alemães que guardam a trincheira.
	EventBus.noise_emitted.emit(global_position, 60.0, player)
	_wire.queue_free()
	_torpedo.queue_free()
	_body.queue_free()
	_plant.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nav := get_tree().current_scene.find_child("Navegacao", true, false) as NavigationRegion3D
	if nav:
		nav.bake_navigation_mesh(true)
	EventBus.narrative_event.emit("arame_destruido")


## Três rolos em hélice; cada volta cruza a anterior (concertina).
func _build_wire() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	var coils := [Vector2(0.0, coil_radius), Vector2(0.0, coil_radius * 2.7),
		Vector2(0.0, coil_radius)]
	var offsets_z := [-coil_radius * 0.95, 0.0, coil_radius * 0.95]
	for c in 3:
		var center_y: float = coils[c].y
		var z0: float = offsets_z[c]
		var turns := int(length / 0.22)
		var prev := Vector3.ZERO
		var steps := turns * 10
		for i in steps + 1:
			var t := float(i) / steps
			var angle := t * turns * TAU
			var r := coil_radius * (1.0 + 0.08 * sin(angle * 0.5 + c))
			var p := Vector3(-length * 0.5 + t * length + sin(angle) * 0.06,
				center_y + sin(angle) * r, z0 + cos(angle) * r)
			p += Vector3(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02))
			if i > 0:
				st.add_vertex(prev)
				st.add_vertex(p)
				# Farpas: pequenos traços a cada tanto.
				if i % 4 == 0:
					var barb := Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04))
					st.add_vertex(p - barb)
					st.add_vertex(p + barb)
			prev = p
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.19, 0.17)
	material.metallic = 0.6
	material.roughness = 0.6
	st.set_material(material)
	return st.commit()


## Cavaletes de madeira em X que seguram os rolos.
func _build_stakes() -> Node3D:
	var root := Node3D.new()
	root.name = "Cavaletes"
	var count := int(length / 2.5) + 1
	for i in count:
		var x := -length * 0.5 + i * length / (count - 1)
		for s in [-1.0, 1.0]:
			var stake := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.07, 1.6, 0.07)
			box.material = stakes_material
			stake.mesh = box
			stake.position = Vector3(x, 0.7, 0.0)
			stake.rotation.x = s * 0.55
			root.add_child(stake)
	return root


## Torpedo Bangalore plantado: tubos de aço emendados enfiados sob o arame.
func _build_torpedo() -> Node3D:
	var root := Node3D.new()
	root.name = "Torpedo"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.26, 0.2)
	material.metallic = 0.5
	material.roughness = 0.55
	var pipe := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.028
	cylinder.bottom_radius = 0.028
	cylinder.height = 3.2
	cylinder.radial_segments = 8
	cylinder.material = material
	pipe.mesh = cylinder
	pipe.rotation.x = PI * 0.5
	pipe.position = Vector3(0.3, 0.06, 0.4)
	root.add_child(pipe)
	return root
