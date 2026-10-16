extends Node3D
## Torpedo Bangalore no chão (seções de tubo de aço com carga), ao lado de um engenheiro
## morto. E pega o torpedo: o jogador passa a ter o item "bangalore" e a fase recebe o
## evento "bangalore_pego".

const HANDLING := preload("res://assets/audio/provisorio/manuseio.wav")


func _ready() -> void:
	var model := Node3D.new()
	model.name = "Modelo"
	add_child(model)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.26, 0.2)
	material.metallic = 0.5
	material.roughness = 0.55
	# Três seções de 1,5 m lado a lado, como vinham amarradas.
	for i in 3:
		var pipe := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.028
		cylinder.bottom_radius = 0.028
		cylinder.height = 1.5
		cylinder.radial_segments = 8
		cylinder.material = material
		pipe.mesh = cylinder
		pipe.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		pipe.position = Vector3((i - 1) * 0.065, 0.03 + (0.05 if i == 1 else 0.0), 0.0)
		model.add_child(pipe)
	# Ponta cônica (nariz que desliza sob o arame).
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.03
	cone.height = 0.12
	cone.material = material
	nose.mesh = cone
	nose.rotation.x = -PI * 0.5
	nose.position = Vector3(0.0, 0.08, -0.81)
	model.add_child(nose)

	var pickup := Interactable.new()
	pickup.name = "Pegar"
	pickup.prompt = "Pegar o torpedo Bangalore"
	pickup.gives_item = "bangalore"
	pickup.event_name = "bangalore_pego"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.5, 1.7)
	shape.shape = box
	pickup.add_child(shape)
	pickup.position.y = 0.2
	add_child(pickup)
	pickup.interacted.connect(func(_p: Node) -> void:
		OneShotSound.play(get_parent(), HANDLING, global_position, -2.0, 5.0)
		model.queue_free())
