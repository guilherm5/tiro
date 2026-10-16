"""Reconstrói as animações de um soldado já com esqueleto da Universal Animation Library
(saída do rig_soldado.py) e acrescenta as animações de fuzil do Mixamo.

Por que reconstruir as da UAL: o rig_soldado.py muda a pose de repouso dos ossos para
casar com a pose do modelo, e as animações copiadas da biblioteca ficam relativas ao
repouso antigo (agachar e morrer saem tortos). Aqui cada animação é refeita no espaço do
mundo: para cada osso e quadro, mede a rotação do osso de origem em relação a uma pose
de referência e aplica a mesma rotação ao osso do soldado na pose correspondente.
  - UAL -> soldado: referência = pose de repouso de cada um (ambos em pé, braços abertos).
  - Mixamo -> soldado: referência = pose T. A pose T do soldado vem da animação "A_TPose"
    da UAL, levada para o repouso do soldado.
O quadril também recebe o deslocamento, escalado pela diferença de altura.

Uso: blender -b --factory-startup --python retarget_mixamo.py -- ual.gltf soldado.glb pasta_fbx saida.glb
Os FBX ("without skin", Y Bot) viram animações "MX_<nome>"; nomes em LOOPS ganham "_Loop"
(o Godot repete essas animações automaticamente e tira o sufixo do nome).
"""
import bpy, sys, math
from pathlib import Path
from mathutils import Matrix

args = sys.argv[sys.argv.index("--") + 1:]
ual_path, soldier_path, fbx_dir, out_path = args[0], args[1], Path(args[2]), args[3]
LOOPS = {"idle_baixo", "mira_parado", "andar", "correr", "agachado_andar", "ajoelhado",
         "atirar_agachado", "atirar_em_pe"}

MIXAMO = {"Hips": "DEF-hips", "Spine": "DEF-spine.001", "Spine1": "DEF-spine.002", "Spine2": "DEF-spine.003",
          "Neck": "DEF-neck", "Head": "DEF-head"}
for side, s in (("Left", "L"), ("Right", "R")):
    MIXAMO.update({f"{side}Shoulder": f"DEF-shoulder.{s}", f"{side}Arm": f"DEF-upper_arm.{s}",
                   f"{side}ForeArm": f"DEF-forearm.{s}", f"{side}Hand": f"DEF-hand.{s}",
                   f"{side}UpLeg": f"DEF-thigh.{s}", f"{side}Leg": f"DEF-shin.{s}",
                   f"{side}Foot": f"DEF-foot.{s}", f"{side}ToeBase": f"DEF-toe.{s}"})
    for finger, ual in (("Index", "f_index"), ("Middle", "f_middle"), ("Ring", "f_ring"), ("Pinky", "f_pinky"), ("Thumb", "thumb")):
        for i in (1, 2, 3):
            MIXAMO[f"{side}Hand{finger}{i}"] = f"DEF-{ual}.0{i}.{s}"


def rot_only(m):
    return m.to_3x3().normalized()


def import_new(op, **kw):
    """Importa e devolve (armadura, objetos novos, ações novas)."""
    objs, acts = set(scene.objects), set(bpy.data.actions)
    op(**kw)
    new = [o for o in scene.objects if o not in objs]
    arm = next((o for o in new if o.type == "ARMATURE"), None)
    return arm, new, [a for a in bpy.data.actions if a not in acts]


def pose_world(arm, action):
    """Rotação de cada osso no mundo: no 1º quadro da ação, ou no repouso (action=None)."""
    if action is None:
        return {b.name: rot_only(arm.matrix_world @ b.matrix_local) for b in arm.data.bones}
    arm.animation_data.action = action
    scene.frame_set(int(action.frame_range[0]))
    return {pb.name: rot_only(arm.matrix_world @ pb.matrix) for pb in arm.pose.bones}


def facing(arm, foot, toe):
    d = arm.matrix_world @ arm.data.bones[toe].head_local - arm.matrix_world @ arm.data.bones[foot].head_local
    return math.atan2(d.y, d.x)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30  # mesma taxa das animações do Mixamo e da UAL

# Biblioteca original da UAL (fonte das animações básicas).
U, u_objs, u_actions = import_new(bpy.ops.import_scene.gltf, filepath=ual_path)
if U.animation_data is None:
    U.animation_data_create()
U_rest = pose_world(U, None)
U_tpose = pose_world(U, next(a for a in u_actions if "TPose" in a.name))

# Soldado: as animações que vieram com ele são descartadas e refeitas.
A, a_objs, a_actions = import_new(bpy.ops.import_scene.gltf, filepath=soldier_path)
for act in a_actions:
    bpy.data.actions.remove(act)
if A.animation_data is None:
    A.animation_data_create()
A.animation_data.action = None
for pb in A.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
    pb.rotation_mode = "QUATERNION"
A_mw = A.matrix_world.copy()
A_mw_inv = A_mw.inverted()
A_mw_rot_inv = rot_only(A_mw).inverted()
A_rest = pose_world(A, None)
# Pose T do soldado = a rotação que leva o repouso da UAL à pose T, aplicada ao repouso dele.
A_tpose = {n: (U_tpose[n] @ U_rest[n].inverted() @ A_rest[n]) if n in U_rest else A_rest[n] for n in A_rest}
A_hips_h = (A_mw @ A.data.bones["DEF-hips"].head_local).z
A_face = facing(A, "DEF-foot.L", "DEF-toe.L")

order = []  # ossos do soldado, pais antes dos filhos
def walk(bone):
    order.append(bone)
    for c in bone.children:
        walk(c)
for b in A.data.bones:
    if b.parent is None:
        walk(b)


def bake(src, src_action, src_ref, tgt_ref, bone_map, name):
    """Grava em `name` a animação `src_action` do esqueleto `src` no soldado.
    bone_map: osso do soldado -> osso de origem."""
    src.animation_data.action = src_action
    S_mw = src.matrix_world.copy()
    S_hips_rest = S_mw @ src.data.bones[bone_map["DEF-hips"]].head_local
    ratio = A_hips_h / max(S_hips_rest.z, 0.01)
    turn = Matrix.Rotation(A_face - facing(src, bone_map["DEF-foot.L"], bone_map["DEF-toe.L"]), 3, "Z")
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    A.animation_data.action = action
    f0, f1 = (int(round(v)) for v in src_action.frame_range)
    for frame in range(f0, f1 + 1):
        scene.frame_set(frame)
        desired_arm = {}
        for bone in order:
            pb = A.pose.bones[bone.name]
            parent = bone.parent
            if parent is not None:
                chain = desired_arm[parent.name] @ parent.matrix_local.inverted() @ bone.matrix_local
            else:
                chain = bone.matrix_local.copy()
            src_name = bone_map.get(bone.name)
            if src_name is not None and src_name in src.pose.bones:
                spb = src.pose.bones[src_name]
                delta = rot_only(S_mw @ spb.matrix) @ src_ref[src_name].inverted()
                delta = turn @ delta @ turn.inverted()
                rot_arm = A_mw_rot_inv @ (delta @ tgt_ref[bone.name])
                head = chain.to_translation()
                if bone.name == "DEF-hips":
                    offset = turn @ ((S_mw @ spb.matrix.to_translation() - S_hips_rest) * ratio)
                    head = A_mw_inv @ (A_mw @ head + offset)
                desired = Matrix.Translation(head) @ rot_arm.to_4x4()
            else:
                desired = chain
            desired_arm[bone.name] = desired
            pb.matrix_basis = chain.inverted() @ desired
            pb.keyframe_insert("rotation_quaternion", frame=frame - f0)
            if bone.name == "DEF-hips":
                pb.keyframe_insert("location", frame=frame - f0)
    return action


made = []
# 1) Animações da UAL, refeitas para o repouso do soldado (mesmos nomes de osso).
ual_map = {b.name: b.name for b in A.data.bones if b.name.startswith("DEF-") and b.name in U.data.bones}
for act in u_actions:
    made.append(bake(U, act, U_rest, A_rest, ual_map, "NOVA_" + act.name))

# 2) Animações de fuzil do Mixamo.
for fbx in sorted(fbx_dir.glob("*.fbx")):
    stem = fbx.stem.removeprefix("mx_")
    M, m_objs, m_actions = import_new(bpy.ops.import_scene.fbx, filepath=str(fbx),
                                      automatic_bone_orientation=False, ignore_leaf_bones=True)
    if M is None or M.animation_data is None or M.animation_data.action is None:
        print("SEM ANIMAÇÃO:", fbx.name)
        continue
    prefix = next(b.name.split("Hips")[0] for b in M.data.bones if b.name.endswith("Hips"))
    mx_map = {v: prefix + k for k, v in MIXAMO.items()}
    name = f"MX_{stem}" + ("_Loop" if stem in LOOPS else "")
    made.append(bake(M, M.animation_data.action, pose_world(M, None), A_tpose, mx_map, name))
    for o in m_objs:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in m_actions:
        bpy.data.actions.remove(a)

# Remove a biblioteca de origem e dá às ações refeitas os nomes originais.
for o in u_objs:
    bpy.data.objects.remove(o, do_unlink=True)
for a in u_actions:
    bpy.data.actions.remove(a)
for a in made:
    if a.name.startswith("NOVA_"):
        a.name = a.name.removeprefix("NOVA_")

A.animation_data.action = None
for pb in A.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
bpy.ops.object.select_all(action="DESELECT")
for o in scene.objects:
    o.select_set(o.type in ("ARMATURE", "MESH"))
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB" if out_path.endswith(".glb") else "GLTF_SEPARATE",
                          use_selection=True, export_animations=True, export_animation_mode="ACTIONS", export_yup=True)
print("EXPORTADO", out_path, len(made), "animações")
