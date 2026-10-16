"""Coloca o esqueleto da Universal Animation Library (Quaternius, CC0) num modelo de
soldado sem esqueleto (ou com outro esqueleto), rodando no Blender sem janela.

Como funciona:
 1. importa a biblioteca (esqueleto em pose T + boneco + 46 animações) e o soldado;
 2. junta as partes do soldado, escala para a altura do boneco, centraliza e vira para a frente;
 3. mede a pose dos braços e pernas do soldado (pose A) e coloca o esqueleto nessa pose;
 4. copia os pesos do boneco (posado igual) para o soldado, pelo ponto mais próximo;
 5. "desfaz" a pose do soldado (volta para pose T) e prende no esqueleto original;
 6. reduz texturas acima de 2048 px (GPU integrada) e exporta .glb com todas as animações.

Uso: blender -b --factory-startup --python rig_soldado.py -- ual.gltf soldado.gltf saida.glb
"""
import bpy, sys
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
ual_path, soldier_path, out_path = args[0], args[1], args[2]
MAX_TEXTURE = 2048


def world_verts(obj):
    mw = obj.matrix_world
    return [mw @ v.co for v in obj.data.vertices]


def apply_all_modifiers(obj):
    for mod in list(obj.modifiers):
        with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
            bpy.ops.object.modifier_apply(modifier=mod.name)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# --- 1. biblioteca de animação ---------------------------------------------------
bpy.ops.import_scene.gltf(filepath=ual_path)
arm = next(o for o in scene.objects if o.type == "ARMATURE")
mannequin = next(o for o in scene.objects if o.type == "MESH")
if arm.animation_data:
    arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
lib_objects = set(scene.objects)

# --- 2. soldado ----------------------------------------------------------------------
bpy.ops.import_scene.gltf(filepath=soldier_path)
new_objects = [o for o in scene.objects if o not in lib_objects]
new_names = [o.name for o in new_objects]
meshes = [o for o in new_objects if o.type == "MESH"]
for o in meshes:
    apply_all_modifiers(o)  # se veio com esqueleto próprio, congela a forma atual
    o.vertex_groups.clear()
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
soldier = bpy.context.view_layer.objects.active
soldier.name = "Soldado"
for name in new_names:
    obj = bpy.data.objects.get(name)
    if obj is not None and obj != soldier:
        bpy.data.objects.remove(obj, do_unlink=True)

m_verts = world_verts(mannequin)
m_height = max(v.z for v in m_verts)


def forward_sign(verts, height):
    """A ponta da bota avança bem mais à frente do tornozelo do que o calcanhar para trás.
    (Comparar com o centro do corpo falha: mochila e equipamento puxam o centro para trás.)"""
    feet = [v for v in verts if v.z < height * 0.03]
    ankle = [v for v in verts if height * 0.06 < v.z < height * 0.09]
    ankle_y = sum(v.y for v in ankle) / len(ankle)
    toward_plus = max(v.y for v in feet) - ankle_y
    toward_minus = ankle_y - min(v.y for v in feet)
    return 1 if toward_plus > toward_minus else -1


s_verts = world_verts(soldier)
s_min_z = min(v.z for v in s_verts)
s_height = max(v.z for v in s_verts) - s_min_z
if forward_sign([v - Vector((0, 0, s_min_z)) for v in s_verts], s_height) != forward_sign(m_verts, m_height):
    soldier.data.transform(Matrix.Rotation(3.14159265, 4, "Z"))
s_verts = world_verts(soldier)
s_min_z = min(v.z for v in s_verts)
s_height = max(v.z for v in s_verts) - s_min_z
scale = (m_height + 0.05) / s_height  # +5 cm: capacete acima da cabeça do boneco
soldier.data.transform(Matrix.Scale(scale, 4))
s_verts = world_verts(soldier)
torso = [v for v in s_verts if 0.45 < (v.z - min(w.z for w in s_verts)) / (m_height + 0.05) < 0.6]
cx = sum(v.x for v in torso) / len(torso)
cy = sum(v.y for v in torso) / len(torso)
soldier.data.transform(Matrix.Translation(Vector((-cx, -cy, -min(v.z for v in s_verts)))))
s_verts = world_verts(soldier)
print("soldado: altura %.2f m (escala %.4f)" % (max(v.z for v in s_verts), scale))

# --- 3. pose do esqueleto igual à do soldado ------------------------------------------
aw = arm.matrix_world


def bone_head(name):
    return aw @ arm.data.bones[name].head_local


def pose_chain(bone_name, from_point, to_point):
    """Gira o osso (e seus filhos) em torno da articulação para apontar de from para to."""
    head = bone_head(bone_name)
    rot = (from_point - head).rotation_difference(to_point - head).to_matrix().to_4x4()
    pb = arm.pose.bones[bone_name]
    world = Matrix.Translation(head) @ rot @ Matrix.Translation(-head) @ aw @ pb.bone.matrix_local
    pb.matrix = aw.inverted() @ world
    bpy.context.view_layer.update()


band = lambda verts, lo, hi: [v for v in verts if lo * m_height < v.z < hi * m_height]
for side, sign in (("L", 1), ("R", -1)):
    m_tip = max(band(m_verts, 0.3, 0.95), key=lambda v: sign * v.x)
    s_tip = max(band(s_verts, 0.3, 0.95), key=lambda v: sign * v.x)
    pose_chain("DEF-upper_arm." + side, m_tip, s_tip)
    m_foot = [v for v in m_verts if v.z < 0.08 * m_height and sign * v.x > 0]
    s_foot = [v for v in s_verts if v.z < 0.08 * m_height and sign * v.x > 0]
    centroid = lambda vs: sum(vs, Vector()) / len(vs)
    pose_chain("DEF-thigh." + side, centroid(m_foot), centroid(s_foot))
    print("lado %s: mão do boneco %s -> do soldado %s" % (side, tuple(round(c, 2) for c in m_tip), tuple(round(c, 2) for c in s_tip)))

# --- 4. pesos: boneco posado -> soldado ----------------------------------------------
posed = mannequin.copy()
posed.data = mannequin.data.copy()
scene.collection.objects.link(posed)
apply_all_modifiers(posed)
transfer = soldier.modifiers.new("pesos", "DATA_TRANSFER")
transfer.object = posed
transfer.use_vert_data = True
transfer.data_types_verts = {"VGROUP_WEIGHTS"}
transfer.vert_mapping = "POLYINTERP_NEAREST"
transfer.layers_vgroup_select_src = "ALL"
transfer.layers_vgroup_select_dst = "NAME"
with bpy.context.temp_override(object=soldier, active_object=soldier, selected_objects=[soldier]):
    bpy.ops.object.datalayout_transfer(modifier="pesos")
    bpy.ops.object.modifier_apply(modifier="pesos")

# --- 5. desfaz a pose (volta para T) e prende no esqueleto ---------------------------
deform = {pb.name: aw @ pb.matrix @ pb.bone.matrix_local.inverted() @ aw.inverted() for pb in arm.pose.bones}
names = {g.index: g.name for g in soldier.vertex_groups}
sw, swi = soldier.matrix_world, soldier.matrix_world.inverted()
for v in soldier.data.vertices:
    total = Matrix(((0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0)))
    weight_sum = 0.0
    for g in v.groups:
        name = names.get(g.group)
        if name in deform and g.weight > 0.0:
            total += deform[name] * g.weight
            weight_sum += g.weight
    if weight_sum > 0.0:
        v.co = swi @ ((total * (1.0 / weight_sum)).inverted() @ (sw @ v.co))
for pb in arm.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
modifier = soldier.modifiers.new("Armature", "ARMATURE")
modifier.object = arm
soldier.parent = arm
soldier.matrix_parent_inverse = aw.inverted()

bpy.data.objects.remove(posed, do_unlink=True)
bpy.data.objects.remove(mannequin, do_unlink=True)

# --- 6. texturas e exportação ----------------------------------------------------------
for image in bpy.data.images:
    w, h = image.size
    if max(w, h) > MAX_TEXTURE:
        f = MAX_TEXTURE / max(w, h)
        image.scale(int(w * f), int(h * f))
        print("textura reduzida:", image.name, w, "->", int(w * f))
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
soldier.select_set(True)
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_yup=True)
print("EXPORTADO", out_path)
