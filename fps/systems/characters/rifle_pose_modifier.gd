class_name RiflePoseModifier
extends SkeletonModifier3D
## Ajustes de pose depois da animação, na ordem certa dentro do mesmo quadro:
##  1. inclina a coluna para a mira subir ou descer (`pitch`);
##  2. põe o fuzil na mão direita: arma baixa, o cano aponta para a mão esquerda; mirando,
##     segue a direção da mira;
##  3. mirando, leva a mão esquerda até a telha do fuzil (IK de dois ossos), já que as
##     animações foram feitas para uma arma com outras medidas (ArmIK).

const PREFIX := "mixamorig_"
const SPINE := ["Spine", "Spine1", "Spine2"]
## Distância da empunhadura até onde a mão esquerda segura (telha), ao longo do cano.
const FOREND := 0.34
## Meio da palma em relação ao pulso (origem do osso da mão), ao longo dos dedos.
const PALM := 0.08

## Inclinação da mira em radianos (positivo = para cima).
var pitch := 0.0
## Quanto da inclinação vai para a coluna (o resto só gira o fuzil).
var spine_share := 1.0
## Quanto o soldado está mirando (0..1).
var aim := 0.0
## Personagem (frente = -Z), para a direção da mira e o eixo da inclinação.
var body: Node3D
## Nó do fuzil (top_level). Nulo = sem fuzil.
var rifle: Node3D
## Se falso, o fuzil fica parado (ex.: caiu no chão).
var hold_rifle := true
## Mão esquerda na telha (0 = solta, ex.: lançando granada).
var left_hand := 1.0

## Fuzil em relação à mão direita, para quando as mãos se separam (granada, susto).
var _rifle_in_hand := Transform3D.IDENTITY

var _spine: PackedInt32Array = []
var _arm_l := -1
var _forearm_l := -1
var _hand_l := -1
var _hand_r := -1


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or body == null:
		return
	if _hand_r < 0:
		for bone_name: String in SPINE:
			_spine.append(skeleton.find_bone(PREFIX + bone_name))
		_arm_l = skeleton.find_bone(PREFIX + "LeftArm")
		_forearm_l = skeleton.find_bone(PREFIX + "LeftForeArm")
		_hand_l = skeleton.find_bone(PREFIX + "LeftHand")
		_hand_r = skeleton.find_bone(PREFIX + "RightHand")
		if _hand_r < 0 or _spine.has(-1):
			push_error("RiflePoseModifier: esqueleto sem os ossos do Mixamo")
			body = null
			return
	if not is_zero_approx(pitch * aim * spine_share):
		_bend_spine(skeleton, pitch * aim * spine_share)
	if rifle and hold_rifle:
		_place_rifle(skeleton)
		if aim * left_hand > 0.01:
			var grip := rifle.global_transform
			var forend := grip.origin - grip.basis.z * FOREND - grip.basis.y * 0.05
			var hand := _global(skeleton, _hand_l)
			var wrist_target := forend - hand.basis.y * PALM
			ArmIK.solve(skeleton, _arm_l, _forearm_l, _hand_l, skeleton.global_transform.affine_inverse() * wrist_target, aim * left_hand)


func _bend_spine(skeleton: Skeleton3D, angle: float) -> void:
	var axis := (skeleton.global_basis.inverse() * body.global_basis.x).normalized()
	var step := angle / _spine.size()
	for id in _spine:
		var parent := skeleton.get_bone_parent(id)
		var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
		var local_axis := (parent_basis.inverse() * axis).normalized()
		skeleton.set_bone_pose_rotation(id, Quaternion(local_axis, step) * skeleton.get_bone_pose_rotation(id))


func _place_rifle(skeleton: Skeleton3D) -> void:
	var hand := _global(skeleton, _hand_r)
	var right_palm := hand.origin + hand.basis.y * PALM
	var left := _global(skeleton, _hand_l)
	var between := left.origin + left.basis.y * PALM - right_palm
	var distance := between.length()
	var aim_dir := (-body.global_basis.z).rotated(body.global_basis.x, pitch)
	if (distance > 0.15 and distance < 0.75) or aim > 0.01:
		var dir := between.normalized().slerp(aim_dir, aim) if distance > 0.05 else aim_dir
		var xform := Transform3D(Basis.looking_at(dir, Vector3.UP), right_palm)
		rifle.global_transform = xform
		_rifle_in_hand = hand.affine_inverse() * xform
	else:
		rifle.global_transform = hand * _rifle_in_hand


## Pose global (mundo) do osso, sem escala.
func _global(skeleton: Skeleton3D, bone: int) -> Transform3D:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).orthonormalized()
