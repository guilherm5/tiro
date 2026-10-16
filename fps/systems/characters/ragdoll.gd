class_name Ragdoll
extends RefCounted
## Corpo mole na morte: cria ossos físicos (cápsulas ligadas por juntas) no esqueleto do
## Mixamo e liga a simulação, partindo da pose atual. O tiro empurra o tronco na direção
## dele, e o corpo cai conforme o terreno (trincheira, encosta, parede).

const PREFIX := "mixamorig_"
# osso, osso-alvo (define comprimento e direção), raio (m), massa (kg), junta
const PARTS := [
	["Hips", "Spine2", 0.15, 14.0, "none"],
	["Spine2", "Neck", 0.16, 14.0, "cone"],
	["Head", "HeadTop_End", 0.1, 5.0, "cone"],
	["LeftArm", "LeftForeArm", 0.055, 2.5, "cone"],
	["LeftForeArm", "LeftHand", 0.045, 1.8, "hinge"],
	["RightArm", "RightForeArm", 0.055, 2.5, "cone"],
	["RightForeArm", "RightHand", 0.045, 1.8, "hinge"],
	["LeftUpLeg", "LeftLeg", 0.085, 8.0, "cone"],
	["LeftLeg", "LeftFoot", 0.065, 4.0, "hinge"],
	["RightUpLeg", "RightLeg", 0.085, 8.0, "cone"],
	["RightLeg", "RightFoot", 0.065, 4.0, "hinge"],
]


## Monta e liga a simulação. `impulse` (mundo, N·s) empurra o tronco.
static func start(skeleton: Skeleton3D, impulse: Vector3, hit_point: Vector3) -> PhysicalBoneSimulator3D:
	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = "Ragdoll"
	skeleton.add_child(simulator)
	var scale := skeleton.global_basis.get_scale().x  # o esqueleto do Mixamo está em centímetros
	var torso: PhysicalBone3D = null
	var bones: Array[PhysicalBone3D] = []
	for part: Array in PARTS:
		var bone := skeleton.find_bone(PREFIX + part[0])
		var target := skeleton.find_bone(PREFIX + part[1])
		if bone < 0:
			continue
		var bone_rest := skeleton.get_bone_global_rest(bone)
		var to_target := bone_rest.affine_inverse() * (skeleton.get_bone_global_rest(target).origin if target >= 0 \
			else bone_rest.origin + bone_rest.basis.y * 20.0)
		var half := to_target.length() * 0.5
		var up := Vector3.UP if not Vector3.UP.cross(to_target).is_zero_approx() else Vector3.BACK
		var body_offset := Transform3D(Basis.looking_at(to_target, up), Vector3.ZERO)
		body_offset.origin = body_offset.basis * Vector3(0.0, 0.0, -half)

		var physical := PhysicalBone3D.new()
		physical.name = part[0]
		physical.bone_name = PREFIX + part[0]
		physical.body_offset = body_offset
		physical.joint_offset = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, half))
		physical.mass = part[3]
		physical.friction = 0.9
		physical.linear_damp = 0.1
		physical.angular_damp = 1.5
		physical.collision_layer = 0
		physical.collision_mask = 1  # só o mundo
		match part[4]:
			"cone":
				physical.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
				physical.set("joint_constraints/swing_span", 45.0)
				physical.set("joint_constraints/twist_span", 25.0)
			"hinge":
				physical.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
				physical.set("joint_constraints/angular_limit_enabled", true)
				physical.set("joint_constraints/angular_limit_upper", 5.0)
				physical.set("joint_constraints/angular_limit_lower", -120.0)
			_:
				physical.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		var radius: float = part[2] / scale
		capsule.radius = radius
		capsule.height = maxf(half * 2.0, radius * 2.0 + 0.01)
		shape.shape = capsule
		shape.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)
		physical.add_child(shape)
		simulator.add_child(physical)
		bones.append(physical)
		if part[0] == "Spine2":
			torso = physical
	simulator.physical_bones_start_simulation()
	if torso:
		torso.apply_impulse(impulse * 0.7, hit_point - torso.global_position)
		for b in bones:
			if b.name == "Hips":
				b.apply_central_impulse(impulse * 0.3)
	return simulator
