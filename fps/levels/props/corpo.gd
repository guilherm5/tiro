extends Node3D
## Soldado caído na praia: o modelo na pose final de uma animação de morte, parado
## (sem física nem lógica). A animação é sorteada se não for escolhida. A pose vira uma
## malha estática ao carregar (sem esqueleto deformando a malha a cada quadro).

@export var model_scene: PackedScene
@export var death_animation := &""

const DEATHS: Array[StringName] = [&"morte_frente", &"morte_costas", &"morte_lado", &"morte_fuzil", &"morte_cabeca"]


func _ready() -> void:
	var model := model_scene.instantiate() as Node3D
	model.name = "Modelo"
	add_child(model)
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var toe := skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_LeftToeBase")).origin
	var foot := skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_LeftFoot")).origin
	if (skeleton.basis * (toe - foot)).z > 0.0:
		model.rotation.y = PI
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var anim := death_animation
	if anim == &"" or not player.has_animation(anim):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(name)
		anim = DEATHS[rng.randi() % DEATHS.size()]
	player.play(anim)
	player.seek(player.current_animation_length, true)
	player.pause()
	# Sem tela (testes) não há renderização para congelar a pose.
	if DisplayServer.get_name() == "headless":
		return
	# O esqueleto só fica registrado na malha depois de alguns quadros.
	for attempt in 5:
		await get_tree().process_frame
		if _bake(model):
			return


## Troca as malhas deformadas pelo esqueleto por cópias estáticas na pose atual.
## Falso se ainda não deu (o modelo fica como está).
func _bake(model: Node3D) -> bool:
	var baked: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var skinned := node as MeshInstance3D
		if skinned.skin == null or skinned.skeleton.is_empty() or not skinned.is_visible_in_tree():
			continue
		var mesh := skinned.bake_mesh_from_current_skeleton_pose()
		if mesh == null:
			for done in baked:
				done.queue_free()
			return false
		var still := MeshInstance3D.new()
		still.mesh = mesh
		still.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mesh.get_surface_count():
			still.set_surface_override_material(i, skinned.get_active_material(i))
		add_child(still)
		still.global_transform = skinned.global_transform
		baked.append(still)
	model.queue_free()
	return true
