class_name HumanoidVisual
extends Node3D
## Visual de soldado animado: modelo com esqueleto do Mixamo (auto-rig feito no próprio
## modelo) e animações de fuzil do Mixamo, montado por tools/blender/montar_mixamo.py.
## API usada por inimigos e aliados:
##   set_crouched, set_aiming, set_aim_pitch, set_move_speed, flinch, die, lie_down,
##   muzzle_flash, play_throw — e expõe `muzzle`, `eyes`, `head_hitbox`.
##
## Animação: em pé ou agachado, com arma baixa ou mirando, cada um com parado/andar(/correr)
## conforme a velocidade. Tiro, reação a acerto e granada tocam por cima, só no tronco.
## Coluna, fuzil e mão esquerda são ajustados depois da animação (RiflePoseModifier).

const UPPER_BODY_KEYWORDS := ["Spine1", "Spine2", "Neck", "Head", "Shoulder", "Arm", "Hand"]
const HITBOX_SCRIPT := preload("res://systems/enemies/hitbox.gd")
const BONE_PREFIX := "mixamorig_"
## Velocidades naturais das animações (m/s, medidas pelo pé apoiado).
const WALK_ANIM_SPEED := 1.15
const AIM_WALK_ANIM_SPEED := 0.95
const CROUCH_WALK_ANIM_SPEED := 1.0
## Mirando e agachado: velocidade natural de cada direção (frente, trás, esquerda, direita).
const AIM_DIR_SPEEDS := [0.9, 1.03, 2.38, 2.72]
const CROUCH_DIR_SPEEDS := [0.98, 1.11, 1.02, 0.94]
const RUN_ANIM_SPEED := 3.5
## A partir desta velocidade o andar vira corrida.
const RUN_FROM := 2.4
## Inclinação do fuzil agachado sem mirar ("pronto baixo").
const LOW_READY_PITCH := -0.2

@export var model_scene: PackedScene
## Se preenchido, sorteia um destes modelos (variedade entre soldados do mesmo lado).
@export var model_variants: Array[PackedScene] = []
## Modelo do fuzil (cano para -Z, origem no meio). Vazio = fuzil provisório de caixas.
@export var rifle_scene: PackedScene
@export_enum("alemao", "americano", "nenhum") var helmet_style := "nenhum"
@export var helmet_color := Color(0.25, 0.27, 0.24)
## Cria a área de acerto da cabeça (inimigos).
@export var create_head_hitbox := true
@export var rifle_color := Color(0.3, 0.2, 0.12)
## Sem fuzil (ex.: metralhador, que usa a MG42 da própria cena).
@export var has_rifle := true
## Na morte, o corpo cai com física (ossos físicos); senão, toca uma animação de morte.
@export var use_ragdoll := true
## Empurrão do tiro no tronco (N·s).
@export var ragdoll_impulse := 38.0
## Clareia texturas escuras demais sob a iluminação do jogo (exceto metal/cromado;
## a pele recebe só um quarto do ajuste).
@export var model_brightness := 1.0

var muzzle: Node3D
var eyes: Node3D
var head_hitbox: AnimatableBody3D

var _model: Node3D
var _player: AnimationPlayer
var _tree: AnimationTree
var _skeleton: Skeleton3D
var _pose: RiflePoseModifier
var _head_bone := -1
var _rifle: Node3D
var _flash: Node3D
var _flash_light: OmniLight3D
var _flash_time := 0.0

var _crouch := 0.0
var _crouch_target := 0.0
var _aim := 0.0
var _aim_target := 0.0
var _pitch := 0.0
var _speed := 0.0
## Velocidade no espaço do corpo (x = direita, y = frente), para andar de lado/de costas.
var _local_velocity := Vector2.ZERO
var _dead := false
## Tempo restante da animação de granada (a mão esquerda solta o fuzil).
var _throw_time := 0.0


func _ready() -> void:
	var scene: PackedScene = model_variants.pick_random() if not model_variants.is_empty() else model_scene
	_model = scene.instantiate()
	_model.name = "Model"
	add_child(_model)
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0]
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	# Os nossos personagens olham para -Z. Se os dedos do pé apontam para +Z, gira o modelo.
	var toe := _rest_global(_bone("LeftToeBase"))
	var foot := _rest_global(_bone("LeftFoot"))
	if (global_basis.inverse() * (toe - foot)).z > 0.0:
		_model.rotation.y = PI
	# Camada visual 3 ("personagens"): marcas de bala e manchas (decals) não pintam o corpo.
	for mesh_instance in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).layers = 1 << 2
	if not is_equal_approx(model_brightness, 1.0):
		_brighten_model()
	_head_bone = _bone("Head")
	_build_tree()
	_pose = RiflePoseModifier.new()
	_pose.body = self
	_skeleton.add_child(_pose)
	_attach_head()
	if has_rifle:
		_build_rifle()
		_pose.rifle = _rifle
	else:
		muzzle = Marker3D.new()
		muzzle.name = "Muzzle"
		add_child(muzzle)
		muzzle.position = Vector3(0.0, 1.3, -0.4)
		_flash = Node3D.new()
		_flash_light = OmniLight3D.new()
		muzzle.add_child(_flash)
		muzzle.add_child(_flash_light)


func _bone(short_name: String) -> int:
	return _skeleton.find_bone(BONE_PREFIX + short_name)


func _rest_global(bone: int) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_rest(bone).origin


# --- API ---------------------------------------------------------------------------

func set_crouched(value: bool) -> void:
	_crouch_target = 1.0 if value else 0.0


func set_aiming(value: bool) -> void:
	_aim_target = 1.0 if value else 0.0


## Inclinação da mira (radianos; positivo = para cima).
func set_aim_pitch(radians: float) -> void:
	_pitch = clampf(radians, -0.9, 0.9)


## Velocidade horizontal (m/s), para escolher parado/andar/correr.
func set_move_speed(speed: float) -> void:
	_speed = speed


## Velocidade no espaço do corpo (x = direita, y = frente). Mirando ou agachado, escolhe
## andar para a frente, de costas ou de lado. Sem ela, considera sempre para a frente.
func set_move_velocity(local_velocity: Vector2) -> void:
	_local_velocity = local_velocity
	_speed = local_velocity.length()


func is_aiming() -> bool:
	return _aim_target > 0.5


func flinch(_local_direction: Vector3) -> void:
	if _dead:
		return
	_one_shot(&"atingido_agachado" if _crouch > 0.5 else &"atingido")


## Lançar granada.
func play_throw() -> void:
	if _dead:
		return
	_one_shot(&"granada")
	if _player.has_animation(&"granada"):
		_throw_time = _player.get_animation(&"granada").length


func die(local_direction: Vector3) -> void:
	if _dead:
		return
	_dead = true
	_pose.aim = 0.0
	_pose.hold_rifle = false
	_pose.active = false
	_tree.active = false
	_drop_rifle()
	if use_ragdoll:
		# Corpo mole a partir da pose do momento, empurrado na direção do tiro.
		_player.pause()
		var push := (global_basis * local_direction).normalized()
		push = (push + Vector3.UP * 0.15).normalized() * ragdoll_impulse
		Ragdoll.start(_skeleton, push, global_position + Vector3.UP * 1.3)
	else:
		_player.play(_death_animation(local_direction), 0.15)


## Tiro pela frente derruba para trás e vice-versa; na cabeça, animação própria.
## `local_direction` é a direção do tiro no espaço do soldado (-Z = frente dele).
func _death_animation(local_direction: Vector3) -> StringName:
	var options: Array[StringName]
	if local_direction.y > 0.3:
		options = [&"morte_cabeca"]
	elif local_direction.z > 0.5:
		options = [&"morte_frente", &"morte_fuzil"]
	elif local_direction.z < -0.5:
		options = [&"morte_costas"]
	else:
		options = [&"morte_lado", &"morte_frente"]
	options = options.filter(_player.has_animation)
	return options.pick_random() if not options.is_empty() else &"morte_lado"


## Deitado (ferido): pose final de uma animação de morte, sem animar.
func lie_down() -> void:
	_dead = true
	_tree.active = false
	_player.play(&"morte_frente" if _player.has_animation(&"morte_frente") else &"morte_lado")
	_player.seek(_player.current_animation_length, true)
	_player.pause()
	if _rifle:
		_rifle.hide()


func muzzle_flash() -> void:
	_flash.show()
	_flash_light.show()
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_flash_time = 0.06
	if not _dead and _aim > 0.5:
		_one_shot(&"agachado_atirar" if _crouch > 0.5 else &"atirar_em_pe", &"fire")


# --- Atualização -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.hide()
			_flash_light.hide()
	if _dead:
		return
	_crouch = move_toward(_crouch, _crouch_target, delta / 0.3)
	_aim = move_toward(_aim, _aim_target, delta / 0.25)
	var aim := smoothstep(0.0, 1.0, _aim)
	var crouch_w := smoothstep(0.0, 1.0, _crouch)
	# Velocidade natural do passo no modo atual; acima dela a animação acelera.
	var natural := lerpf(lerpf(WALK_ANIM_SPEED, AIM_WALK_ANIM_SPEED, aim), CROUCH_WALK_ANIM_SPEED, crouch_w)
	var running := clampf((_speed - RUN_FROM) / (RUN_ANIM_SPEED - RUN_FROM), 0.0, 1.0) * (1.0 - aim) * (1.0 - crouch_w)
	var walk_pos := minf(_speed, natural)
	_tree.set("parameters/loco/blend_position", lerpf(minf(_speed, WALK_ANIM_SPEED), RUN_ANIM_SPEED, running))
	# Mirando/agachado: direção no espaço 2D (entra aos poucos a partir de parado) e ritmo
	# pela velocidade natural daquela direção.
	var direction := _local_velocity.normalized() if _local_velocity.length() > 0.05 else Vector2(0, 1)
	var amount := clampf(_speed / 0.4, 0.0, 1.0)
	for node: String in ["loco_aim", "crouch", "crouch_aim"]:
		_tree.set("parameters/%s/blend_position" % node, direction * amount)
	var aim_natural := _direction_speed(direction, AIM_DIR_SPEEDS)
	var crouch_natural := _direction_speed(direction, CROUCH_DIR_SPEEDS)
	var pace_2d := _speed / lerpf(aim_natural, crouch_natural, crouch_w)
	var pace_1d := lerpf(maxf(_speed / natural, 1.0), maxf(_speed / RUN_ANIM_SPEED, 0.85), running)
	var pace := lerpf(pace_1d, pace_2d, maxf(aim, crouch_w))
	_tree.set("parameters/pace/scale", clampf(pace, 0.6, 1.9) if walk_pos > 0.05 else 1.0)
	_tree.set("parameters/stand/blend_amount", aim)
	_tree.set("parameters/low/blend_amount", aim)
	_tree.set("parameters/body/blend_amount", smoothstep(0.0, 1.0, _crouch))
	# Agachado sem mirar: a mesma pose ajoelhada de tiro, com o fuzil abaixado.
	_pose.aim = maxf(aim, crouch_w)
	_pose.pitch = lerpf(lerpf(_pitch, LOW_READY_PITCH, crouch_w), _pitch, aim)
	_pose.spine_share = 1.0
	_throw_time = maxf(_throw_time - delta, 0.0)
	_pose.left_hand = move_toward(_pose.left_hand, 0.0 if _throw_time > 0.3 else 1.0, delta / 0.2)
	_update_eyes()


## Velocidade natural na direção (x = direita, y = frente), misturando as das quatro
## animações (frente, trás, esquerda, direita) pelo peso de cada eixo.
func _direction_speed(direction: Vector2, speeds: Array) -> float:
	var forward_back: float = speeds[0] if direction.y >= 0.0 else speeds[1]
	var sideways: float = speeds[3] if direction.x >= 0.0 else speeds[2]
	var wx := absf(direction.x)
	var wy := absf(direction.y)
	return (forward_back * wy + sideways * wx) / maxf(wx + wy, 0.001)


## Olhos na cabeça animada, mas orientados como o corpo (a percepção usa -Z como frente).
func _update_eyes() -> void:
	var head := _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone)
	eyes.global_transform = Transform3D(global_basis, head.origin + Vector3.UP * 0.08 - global_basis.z * 0.08)


# --- Montagem ----------------------------------------------------------------------

func _brighten_model() -> void:
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i) as StandardMaterial3D
			var lower := material.resource_name.to_lower() if material else ""
			if material and not lower.contains("metal") and not lower.contains("chrome"):
				# A pele já é clara: clareá-la por inteiro deixa o rosto branco demais.
				var factor := lerpf(1.0, model_brightness, 0.25) if lower.contains("skin") else model_brightness
				material = material.duplicate()
				material.albedo_color = material.albedo_color * factor
				mesh_instance.set_surface_override_material(i, material)


func _anim(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name if _player.has_animation(animation_name) else &"idle_baixo"
	return node


func _blend_space(points: Array) -> AnimationNodeBlendSpace1D:
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 6.0
	for point: Array in points:
		space.add_blend_point(_anim(point[0]), point[1], -1, point[0])
	return space


## Parado no centro; frente, trás, esquerda e direita a 1 de distância (x = direita,
## y = frente): a posição é só a direção; o ritmo vem do nó "pace". Sem a animação de uma
## direção, usa a de andar para a frente.
func _blend_space_2d(idle: StringName, forward: StringName, back: StringName, left: StringName,
		right: StringName, _speeds: Array) -> AnimationNodeBlendSpace2D:
	var space := AnimationNodeBlendSpace2D.new()
	space.min_space = Vector2(-1.5, -1.5)
	space.max_space = Vector2(1.5, 1.5)
	space.add_blend_point(_anim(idle), Vector2.ZERO, -1, idle)
	space.add_blend_point(_anim(forward), Vector2(0, 1), -1, forward)
	for point: Array in [[back, Vector2(0, -1)], [left, Vector2(-1, 0)], [right, Vector2(1, 0)]]:
		var anim: StringName = point[0] if _player.has_animation(point[0]) else forward
		space.add_blend_point(_anim(anim), point[1], -1, point[0])
	return space


func _build_tree() -> void:
	var tree := AnimationNodeBlendTree.new()
	tree.add_node(&"loco", _blend_space([[&"idle_baixo", 0.0], [&"andar", WALK_ANIM_SPEED], [&"correr", RUN_ANIM_SPEED]]))
	tree.add_node(&"loco_aim", _blend_space_2d(&"mira_parado", &"andar_mira", &"andar_mira_tras", &"andar_mira_esq",
		&"andar_mira_dir", AIM_DIR_SPEEDS))
	tree.add_node(&"crouch", _blend_space_2d(&"agachado", &"agachado_andar_mira", &"agachado_tras", &"agachado_esq",
		&"agachado_dir", CROUCH_DIR_SPEEDS))
	tree.add_node(&"crouch_aim", _blend_space_2d(&"agachado", &"agachado_andar_mira", &"agachado_tras", &"agachado_esq",
		&"agachado_dir", CROUCH_DIR_SPEEDS))
	tree.add_node(&"stand", AnimationNodeBlend2.new())
	tree.add_node(&"low", AnimationNodeBlend2.new())
	tree.add_node(&"body", AnimationNodeBlend2.new())
	tree.connect_node(&"stand", 0, &"loco")
	tree.connect_node(&"stand", 1, &"loco_aim")
	tree.connect_node(&"low", 0, &"crouch")
	tree.connect_node(&"low", 1, &"crouch_aim")
	tree.connect_node(&"body", 0, &"stand")
	tree.connect_node(&"body", 1, &"low")
	# Ritmo dos passos acompanha a velocidade real (senão os pés escorregam).
	tree.add_node(&"pace", AnimationNodeTimeScale.new())
	tree.connect_node(&"pace", 0, &"body")

	# Tiro (coice curto) e ações (acerto, granada): só no tronco, por cima da locomoção.
	var fire := AnimationNodeOneShot.new()
	fire.fadein_time = 0.03
	fire.fadeout_time = 0.12
	fire.filter_enabled = true
	_filter_bones(fire, UPPER_BODY_KEYWORDS)
	tree.add_node(&"fire", fire)
	tree.add_node(&"fire_anim", _anim(&"atirar_em_pe"))
	tree.connect_node(&"fire", 0, &"pace")
	tree.connect_node(&"fire", 1, &"fire_anim")

	var action := AnimationNodeOneShot.new()
	action.fadein_time = 0.1
	action.fadeout_time = 0.25
	action.filter_enabled = true
	_filter_bones(action, UPPER_BODY_KEYWORDS)
	tree.add_node(&"action", action)
	tree.add_node(&"action_anim", _anim(&"atingido"))
	tree.connect_node(&"action", 0, &"fire")
	tree.connect_node(&"action", 1, &"action_anim")
	tree.connect_node(&"output", 0, &"action")

	_tree = AnimationTree.new()
	_tree.tree_root = tree
	_model.add_child(_tree)
	_tree.root_node = _tree.get_path_to(_model)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.active = true


## Dispara um one-shot ("action" ou "fire") com a animação dada, se o modelo a tiver.
func _one_shot(animation_name: StringName, node := &"action") -> void:
	if not _player.has_animation(animation_name):
		return
	var root := _tree.tree_root as AnimationNodeBlendTree
	(root.get_node(StringName(node + "_anim")) as AnimationNodeAnimation).animation = animation_name
	_tree.set("parameters/%s/request" % node, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Liga no filtro do nó os ossos cujo nome contém uma das palavras.
func _filter_bones(node: AnimationNode, keywords: Array) -> void:
	var skeleton_path := str(_model.get_path_to(_skeleton))
	for i in _skeleton.get_bone_count():
		var bone := _skeleton.get_bone_name(i)
		for keyword: String in keywords:
			if bone.contains(keyword):
				node.set_filter_path(NodePath("%s:%s" % [skeleton_path, bone]), true)
				break


func _attach_head() -> void:
	var head := BoneAttachment3D.new()
	head.bone_name = BONE_PREFIX + "Head"
	_skeleton.add_child(head)

	eyes = Marker3D.new()
	eyes.name = "Eyes"
	add_child(eyes)
	eyes.top_level = true

	if helmet_style != "nenhum":
		head.add_child(_make_helmet())

	if create_head_hitbox:
		head_hitbox = AnimatableBody3D.new()
		head_hitbox.name = "HeadHitbox"
		head_hitbox.collision_layer = 4
		head_hitbox.collision_mask = 0
		head_hitbox.set_script(HITBOX_SCRIPT)
		head_hitbox.set_meta(&"surface", &"corpo")
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.14
		shape.shape = sphere
		head_hitbox.add_child(shape)
		# Fica fora do esqueleto e segue a cabeça (o esqueleto pode ter escala).
		head_hitbox.top_level = true
		add_child(head_hitbox)
		head_hitbox.owner = owner  # hitbox.gd chama owner.receive_hit()
		var follow := RemoteTransform3D.new()
		follow.update_scale = false
		head.add_child(follow)
		follow.position = Vector3(0.0, 0.1 / _skeleton.global_basis.get_scale().x, 0.0)  # ~10 cm acima do osso
		follow.remote_path = follow.get_path_to(head_hitbox)


func _make_helmet() -> Node3D:
	var root := Node3D.new()
	root.name = "Capacete"
	var unit := 1.0 / _skeleton.global_basis.get_scale().x
	root.position = Vector3(0.0, 0.16 * unit, 0.0)
	root.scale = Vector3.ONE * unit
	var material := StandardMaterial3D.new()
	material.albedo_color = helmet_color
	material.roughness = 0.6
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.22 if helmet_style == "alemao" else 0.19
	sphere.is_hemisphere = true
	sphere.material = material
	dome.mesh = sphere
	root.add_child(dome)
	return root


func _build_rifle() -> void:
	_rifle = Node3D.new()
	_rifle.name = "Fuzil"
	add_child(_rifle)
	_rifle.top_level = true
	var wood := StandardMaterial3D.new()
	wood.albedo_color = rifle_color
	wood.roughness = 0.7
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.12, 0.12)
	metal.metallic = 0.6
	metal.roughness = 0.5
	if rifle_scene:
		var model := rifle_scene.instantiate() as Node3D
		_rifle.add_child(model)
		model.position = Vector3(0.0, 0.0, -0.25)  # empunhadura na mão; coronha 30 cm atrás
		for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
			(mesh_instance as MeshInstance3D).layers = 1 << 2
	else:
		_add_box(_rifle, Vector3(0.05, 0.09, 0.75), Vector3(0.0, -0.02, -0.25), wood)
		_add_box(_rifle, Vector3(0.025, 0.025, 0.45), Vector3(0.0, 0.02, -0.75), metal)
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	_rifle.add_child(muzzle)
	muzzle.position = Vector3(0.0, 0.02, -0.8)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color(1, 0.95, 0.8, 1), Color(1, 0.6, 0.2, 0.7), Color(1, 0.4, 0.1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var flash_material := StandardMaterial3D.new()
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_texture = texture
	flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = flash_material
	var flash_mesh := MeshInstance3D.new()
	flash_mesh.mesh = quad
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle.add_child(flash_mesh)
	_flash = flash_mesh
	_flash_light = OmniLight3D.new()
	_flash_light.layers = 3
	_flash_light.light_color = Color(1, 0.72, 0.4)
	_flash_light.light_energy = 3.0
	_flash_light.omni_range = 6.0
	muzzle.add_child(_flash_light)
	_flash.hide()
	_flash_light.hide()


func _add_box(parent: Node3D, size: Vector3, offset: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box
	mesh_instance.position = offset
	parent.add_child(mesh_instance)


## Na morte, o fuzil cai no chão com física.
func _drop_rifle() -> void:
	if _rifle == null:
		return
	var body := RigidBody3D.new()
	body.mass = 4.0
	body.collision_layer = 0
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.06, 0.09, 1.1)
	shape.shape = box
	shape.position = Vector3(0.0, 0.0, -0.45)
	body.add_child(shape)
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	scene.add_child(body)
	body.global_transform = _rifle.global_transform
	_rifle.top_level = false
	_rifle.reparent(body, true)
	_rifle.transform = Transform3D.IDENTITY
	body.apply_impulse(Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5)))
	set_process(true)
