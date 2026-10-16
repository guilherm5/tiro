"""Prepara um soldado do Sketchfab (sem esqueleto) para o auto-rig do Mixamo: junta as
partes, põe em pé com 1,80 m, de frente para -Y (frente do Mixamo) e exporta um FBX só
com a malha e os UVs (as texturas voltam depois, em montar_mixamo.py).

Uso: blender -b --factory-startup --python preparar_mixamo.py -- soldado.gltf saida.fbx
"""
import bpy, sys
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
HEIGHT = 1.8

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in scene.objects if o.type == "MESH"]
for o in meshes:
    for mod in list(o.modifiers):
        with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    o.vertex_groups.clear()
    if o.data.shape_keys:
        o.shape_key_clear()
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
for o in list(scene.objects):
    if o != soldier:
        bpy.data.objects.remove(o, do_unlink=True)


def verts():
    return [soldier.matrix_world @ v.co for v in soldier.data.vertices]


vs = verts()
min_z = min(v.z for v in vs)
height = max(v.z for v in vs) - min_z
feet = [v for v in vs if v.z - min_z < height * 0.03]
ankle = [v for v in vs if height * 0.06 < v.z - min_z < height * 0.09]
ankle_y = sum(v.y for v in ankle) / len(ankle)
toe_plus = max(v.y for v in feet) - ankle_y > ankle_y - min(v.y for v in feet)
if toe_plus:  # a ponta da bota indica a frente; o Mixamo quer a frente em -Y
    soldier.data.transform(Matrix.Rotation(3.14159265, 4, "Z"))
vs = verts()
min_z = min(v.z for v in vs)
soldier.data.transform(Matrix.Scale(HEIGHT / (max(v.z for v in vs) - min_z), 4))
vs = verts()
min_z = min(v.z for v in vs)
torso = [v for v in vs if 0.45 < (v.z - min_z) / HEIGHT < 0.6]
cx = sum(v.x for v in torso) / len(torso)
cy = sum(v.y for v in torso) / len(torso)
soldier.data.transform(Matrix.Translation(Vector((-cx, -cy, -min_z))))
print("vértices:", len(soldier.data.vertices), "materiais:", [m.name for m in soldier.data.materials])
bpy.ops.export_scene.fbx(filepath=out, use_selection=False, object_types={"MESH"},
                         path_mode="STRIP", embed_textures=False, add_leaf_bones=False)
