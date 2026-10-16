class_name ArmIK
extends RefCounted
## IK analítico de dois ossos (braço, antebraço, mão), no espaço do esqueleto.
## Usado pelos soldados (mão esquerda na telha) e pelos braços em primeira pessoa.


## Leva o pulso (origem do osso `hand`) até `target` (espaço do esqueleto), misturado por
## `weight`. A mão fica com a rotação `hand_rotation` (espaço do esqueleto) se dada;
## senão mantém a rotação que tinha antes do IK (a da animação).
static func solve(skeleton: Skeleton3D, upper: int, lower: int, hand: int, target: Vector3,
		weight: float, hand_rotation: Variant = null) -> void:
	var a_pose := skeleton.get_bone_global_pose(upper)
	var b_pose := skeleton.get_bone_global_pose(lower)
	var c_pose := skeleton.get_bone_global_pose(hand)
	var a := a_pose.origin
	var b := b_pose.origin
	var c := c_pose.origin
	var t := c.lerp(target, weight)
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var d := clampf(a.distance_to(t), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var ac := (c - a).normalized()
	var ab := (b - a).normalized()
	var ba := (a - b).normalized()
	var bc := (c - b).normalized()
	var at := (t - a).normalized()
	var ac_ab_0 := acos(clampf(ac.dot(ab), -1.0, 1.0))
	var ba_bc_0 := acos(clampf(ba.dot(bc), -1.0, 1.0))
	var ac_at_0 := acos(clampf(ac.dot(at), -1.0, 1.0))
	var ac_ab_1 := acos(clampf((l2 * l2 - l1 * l1 - d * d) / (-2.0 * l1 * d), -1.0, 1.0))
	var ba_bc_1 := acos(clampf((d * d - l1 * l1 - l2 * l2) / (-2.0 * l1 * l2), -1.0, 1.0))
	var axis0 := (c - a).cross(b - a)
	if axis0.length_squared() < 1e-8:
		return
	axis0 = axis0.normalized()
	var r0 := Quaternion(axis0, ac_ab_1 - ac_ab_0)
	var r1 := Quaternion(axis0, ba_bc_1 - ba_bc_0)
	var axis1 := (c - a).cross(t - a)
	var r2 := Quaternion(axis1.normalized(), ac_at_0) if axis1.length_squared() > 1e-8 else Quaternion.IDENTITY
	var a_rot := a_pose.basis.orthonormalized().get_rotation_quaternion()
	var b_rot := b_pose.basis.orthonormalized().get_rotation_quaternion()
	var c_rot := c_pose.basis.orthonormalized().get_rotation_quaternion()
	var new_a := r2 * r0 * a_rot
	var new_b := r2 * r0 * r1 * b_rot
	var parent := skeleton.get_bone_parent(upper)
	var parent_rot := skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(upper, parent_rot.inverse() * new_a)
	skeleton.set_bone_pose_rotation(lower, new_a.inverse() * new_b)
	var wanted: Quaternion = hand_rotation if hand_rotation != null else c_rot
	var followed := skeleton.get_bone_pose_rotation(hand)
	skeleton.set_bone_pose_rotation(hand, followed.slerp(new_b.inverse() * wanted, weight))
