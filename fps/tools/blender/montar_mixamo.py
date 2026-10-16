"""Monta o .glb de um soldado com esqueleto e animações do Mixamo (sem conversão de
esqueleto: o Mixamo fez o auto-rig do próprio modelo e exportou as animações nele).

Entrada:
  - pasta com os FBX baixados do Mixamo para ESTE personagem: um deles "with skin"
    (malha + esqueleto), os outros "without skin" (só esqueleto animado); o nome do
    arquivo vira o nome da animação;
  - o modelo original (glTF do Sketchfab), de onde voltam os materiais com textura
    (o FBX enviado ao Mixamo ia só com a malha e os UVs).

Nomes em LOOPS ganham "_Loop" (o Godot repete e tira o sufixo).
Uso: blender -b --factory-startup --python montar_mixamo.py -- pasta_fbx original.gltf saida.glb
"""
import bpy, sys, re
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:]
fbx_dir, original, out_path = Path(args[0]), args[1], args[2]
MAX_TEXTURE = 2048
LOOPS = {"idle_baixo", "mira_parado", "andar", "andar_mira", "correr", "agachado", "agachado_andar_mira",
         "andar_mira_tras", "andar_mira_esq", "andar_mira_dir", "agachado_tras", "agachado_esq", "agachado_dir"}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30


def import_new(op, **kw):
    objs, acts = set(scene.objects), set(bpy.data.actions)
    op(**kw)
    return [o for o in scene.objects if o not in objs], [a for a in bpy.data.actions if a not in acts]


def base_name(name):
    return re.sub(r"\.\d{3}$", "", name)


# Materiais originais (com texturas).
objs, _ = import_new(bpy.ops.import_scene.gltf, filepath=original)
materials = {}
for o in objs:
    if o.type == "MESH":
        for m in o.data.materials:
            if m:
                materials[base_name(m.name)] = m
                m.use_fake_user = True
for o in objs:
    bpy.data.objects.remove(o, do_unlink=True)

# Personagem com pele: o único FBX com malha.
files = sorted(fbx_dir.glob("*.fbx"))
arm = mesh = None
actions = {}
for fbx in files:
    objs, acts = import_new(bpy.ops.import_scene.fbx, filepath=str(fbx), ignore_leaf_bones=True,
                            automatic_bone_orientation=False)
    has_mesh = any(o.type == "MESH" for o in objs)
    if has_mesh and arm is None:
        arm = next(o for o in objs if o.type == "ARMATURE")
        mesh = next(o for o in objs if o.type == "MESH")
        arm.name = "Esqueleto"
        mesh.name = "Soldado"
        for a in acts:
            actions[fbx.stem] = a
        continue
    for a in acts:
        actions[fbx.stem] = a
        a.use_fake_user = True
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
assert arm is not None, "nenhum FBX com malha (baixe um deles 'with skin')"

for slot in mesh.material_slots:
    original_material = materials.get(base_name(slot.material.name)) if slot.material else None
    if original_material:
        slot.material = original_material
    else:
        print("material sem textura:", slot.material.name if slot.material else None)

def fcurves(action):
    """Curvas da ação (Blender 4.4+ guarda em camadas/slots; antes, em action.fcurves)."""
    if hasattr(action, "layers") and action.layers:
        return [fc for layer in action.layers for strip in layer.strips
                for bag in strip.channelbags for fc in bag.fcurves]
    return list(action.fcurves)


def remove_drift(action):
    """Animações em ciclo que andam para a frente (sem a opção "in place" no Mixamo): tira
    o avanço linear do quadril, mantendo o balanço. O Godot é que move o personagem."""
    for fc in fcurves(action):
        if 'Hips' not in fc.data_path or not fc.data_path.endswith("location"):
            continue
        points = fc.keyframe_points
        if len(points) < 2:
            continue
        first, last = points[0].co, points[-1].co
        drift = last[1] - first[1]
        if abs(drift) < 0.1:  # metros
            continue
        span = last[0] - first[0]
        for p in points:
            p.co[1] -= drift * (p.co[0] - first[0]) / span
            p.handle_left[1] = p.co[1]
            p.handle_right[1] = p.co[1]
        print("  avanço removido:", action.name, fc.array_index, round(drift, 1))


# O FBX do Mixamo vem em centímetros (esqueleto com escala 0,01). Aplica a escala para o
# esqueleto ficar em metros (os ossos físicos do Godot não aceitam esqueleto escalado) e
# converte os deslocamentos das animações na mesma proporção.
unit = arm.scale.x
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
mesh.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for act in actions.values():
    for fc in fcurves(act):
        if fc.data_path.endswith("location"):
            for p in fc.keyframe_points:
                p.co[1] *= unit
                p.handle_left[1] *= unit
                p.handle_right[1] *= unit
print("escala aplicada:", unit)

for stem, act in actions.items():
    act.name = stem + ("_Loop" if stem in LOOPS else "")
    if stem in LOOPS:
        remove_drift(act)
    print("animação", act.name, act.frame_range[:])

for image in bpy.data.images:
    w, h = image.size
    if max(w, h) > MAX_TEXTURE:
        f = MAX_TEXTURE / max(w, h)
        image.scale(int(w * f), int(h * f))

arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.matrix_basis.identity()
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_yup=True)
print("EXPORTADO", out_path, len(actions), "animações")
