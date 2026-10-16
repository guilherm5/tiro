"""Prepara um objeto de cena baixado (glTF): aplica transformações, escala para o tamanho
real (maior dimensão em metros), põe a base em y = 0 centrada, reduz texturas e exporta .glb.

Uso: blender -b --factory-startup --python preparar_objeto.py -- entrada.gltf saida.glb tamanho_m [max_textura] [fração_faces]
(fração_faces < 1 simplifica a malha, ex. 0.1 mantém 10% das faces)
"""
import bpy, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out, size = args[0], args[1], float(args[2])
max_tex = int(args[3]) if len(args) > 3 else 1024
ratio = float(args[4]) if len(args) > 4 else 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
dims = hi - lo
k = size / max(dims)
center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for o in meshes:
    o.data.transform(__import__("mathutils").Matrix.Translation(-center))
    o.data.transform(__import__("mathutils").Matrix.Scale(k, 4))
if ratio < 1.0:
    for o in meshes:
        mod = o.modifiers.new("simplificar", "DECIMATE")
        mod.ratio = ratio
        with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
            bpy.ops.object.modifier_apply(modifier=mod.name)
print("dimensões (m):", tuple(round(d * k, 3) for d in dims), "faces:", sum(len(o.data.polygons) for o in meshes))
for image in bpy.data.images:
    w, h = image.size
    if max(w, h) > max_tex:
        f = max_tex / max(w, h)
        image.scale(int(w * f), int(h * f))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_animations=False)
