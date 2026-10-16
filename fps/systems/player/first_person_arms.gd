extends Node3D
## Braços em primeira pessoa: só os braços do soldado americano (mesmas mangas e mãos dos
## aliados; extraídos por tools/blender/extrair_bracos.py) segurando o fuzil da vista.
##
## Fica dentro do nó do modelo da arma (braços e arma se movem juntos: quadril, mira,
## corrida, coice, balanço). O corpo toca a pose de mira do Mixamo (dedos fechados na arma)
## com o ombro direito na soleira da coronha. Um IK leva as mãos aos pontos da arma (punho da coronha e telha), em qualquer
## pose dela (mira, quadril, corrida, recarga, coice, balanço); a rotação das mãos em
## relação à arma vem da pose de mira.

const PREFIX := "mixamorig_"
const PALM := 0.08

@export var model_scene: PackedScene
## Nó do modelo da arma (o mesmo usado na vista; cano para -Z).
@export var rifle_path: NodePath
## Meio da palma direita no punho da coronha (coordenadas do modelo da arma).
@export var right_grip := Vector3(-0.009, -0.065, 0.3)
## Soleira da coronha (coordenadas do modelo da arma) e onde fica a articulação do ombro
## direito em relação a ela.
@export var butt_point := Vector3(-0.009, -0.05, 0.53)
@export var shoulder_offset := Vector3(0.06, -0.06, 0.03)
## Camada visual da vista da arma.
@export_flags_3d_render var layer := 2

var _rifle: Node3D
var _right_in_rifle := Transform3D.IDENTITY
var _left_in_rifle := Transform3D.IDENTITY


class Hands extends SkeletonModifier3D:
	var arms: Node3D
	var bones := {}

	func _process_modification_with_delta(_delta: float) -> void:
		var skeleton := get_skeleton()
		if skeleton == null or arms == null:
			return
		var to_skeleton := skeleton.global_transform.affine_inverse()
		var rifle: Transform3D = arms._rifle.global_transform
		var right: Transform3D = to_skeleton * (rifle * arms._right_in_rifle)
		var left: Transform3D = to_skeleton * (rifle * arms._left_in_rifle)
		ArmIK.solve(skeleton, bones.arm_r, bones.forearm_r, bones.hand_r, right.origin, 1.0,
			right.basis.orthonormalized().get_rotation_quaternion())
		ArmIK.solve(skeleton, bones.arm_l, bones.forearm_l, bones.hand_l, left.origin, 1.0,
			left.basis.orthonormalized().get_rotation_quaternion())


func _ready() -> void:
	_rifle = get_node(rifle_path)
	var body := model_scene.instantiate() as Node3D
	body.name = "Corpo"
	add_child(body)
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	var toe := skeleton.get_bone_global_rest(skeleton.find_bone(PREFIX + "LeftToeBase")).origin
	var foot := skeleton.get_bone_global_rest(skeleton.find_bone(PREFIX + "LeftFoot")).origin
	if (body.global_basis * (skeleton.basis * (toe - foot))).z > 0.0:
		body.rotation.y = PI
	for mesh_instance in body.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).layers = layer
		(mesh_instance as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.play(&"mira_parado")
	player.seek(0.5, true)
	skeleton.force_update_all_bone_transforms()
	_calibrate(skeleton)

	var hands := Hands.new()
	hands.arms = self
	hands.bones = {
		arm_r = skeleton.find_bone(PREFIX + "RightArm"), forearm_r = skeleton.find_bone(PREFIX + "RightForeArm"),
		hand_r = skeleton.find_bone(PREFIX + "RightHand"),
		arm_l = skeleton.find_bone(PREFIX + "LeftArm"), forearm_l = skeleton.find_bone(PREFIX + "LeftForeArm"),
		hand_l = skeleton.find_bone(PREFIX + "LeftHand"),
	}
	skeleton.add_child(hands)


## Mãos em relação à arma, medidas na pose de mira: a linha do fuzil vai da palma direita
## à esquerda. A mão direita fica no punho da coronha; a esquerda onde a animação a põe ao
## longo dessa linha. O corpo é posto com o ombro direito junto à coronha.
func _calibrate(skeleton: Skeleton3D) -> void:
	var to_local := global_transform.affine_inverse() * skeleton.global_transform
	var hand_r := (to_local * skeleton.get_bone_global_pose(skeleton.find_bone(PREFIX + "RightHand"))).orthonormalized()
	var hand_l := (to_local * skeleton.get_bone_global_pose(skeleton.find_bone(PREFIX + "LeftHand"))).orthonormalized()
	var shoulder := to_local * skeleton.get_bone_global_pose(skeleton.find_bone(PREFIX + "RightArm"))
	var palm_r := hand_r.origin + hand_r.basis.y * PALM
	var palm_l := hand_l.origin + hand_l.basis.y * PALM
	var line := Transform3D(Basis.looking_at(palm_l - palm_r, Vector3.UP), palm_r)
	var grip := Transform3D(Basis.IDENTITY, right_grip)  # mesma linha, na arma (cano para -Z)
	_right_in_rifle = grip * (line.affine_inverse() * hand_r)
	_left_in_rifle = grip * (line.affine_inverse() * hand_l)
	var butt := _rifle.transform * butt_point  # o nó da arma é irmão deste
	transform = Transform3D(Basis.IDENTITY, butt + shoulder_offset - shoulder.origin)
