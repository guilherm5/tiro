"""Apaga a parte de um modelo além de um plano (ex.: a rampa do LCVP, que na fase é uma
peça animada à parte). O eixo segue o Blender (Z para cima; -Y do Blender vira +Z no Godot).

Uso: blender -b --factory-startup --python cortar_malha.py -- entrada.glb saida.glb eixo limite maior|menor [dupla]
  ex.: ... lcvp.glb lcvp_sem_rampa.glb y 4.95 maior dupla   (apaga y > 4.95)
Opcional depois de "dupla": altura mínima (Z do Blender) para o corte valer, ex. 0.75
(abaixo dela tudo fica na peça principal: fundo do casco).
"dupla": materiais com as duas faces (a peça recortada fica aberta; vista por dentro,
sem isso, some).
"""
import bpy, bmesh, sys

args = sys.argv[sys.argv.index("--") + 1:]
src, out, axis, limit, side = args[0], args[1], "xyz".index(args[2]), float(args[3]), args[4]
min_height = float(args[6]) if len(args) > 6 else -1e9
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
removed = 0
for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    mw = obj.matrix_world
    # Decide pela face inteira (centro dela): uma face que atravessa o plano fica toda numa
    # das peças, em vez de sumir das duas.
    def beyond(f):
        c = mw @ f.calc_center_median()
        in_part = c[axis] > limit and c.z > min_height  # a parte recortada (a rampa)
        return in_part if side == "maior" else not in_part
    doomed = [f for f in bm.faces if beyond(f)]
    removed += len(doomed)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
print("faces apagadas:", removed)
if len(args) > 5 and args[5] == "dupla":
    for mat in bpy.data.materials:
        mat.use_backface_culling = False
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
