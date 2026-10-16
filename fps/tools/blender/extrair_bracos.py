"""Gera o modelo de braços em primeira pessoa a partir de um soldado do Mixamo: apaga da
malha tudo que não é braço (vértices cujo osso de maior peso não é do braço, antebraço,
mão ou dedos) e exporta com o mesmo esqueleto e só a animação pedida.

Uso: blender -b --factory-startup --python extrair_bracos.py -- soldado.glb saida.glb [animação]
"""
import bpy, bmesh, sys

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
keep_anim = args[2] if len(args) > 2 else "mira_parado"
ARM_WORDS = ("Arm", "ForeArm", "Hand")  # LeftArm, LeftForeArm, LeftHand*, ... (não Shoulder)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for mesh in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    names = {g.index: g.name for g in mesh.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    deform = bm.verts.layers.deform.active
    doomed = []
    for v in bm.verts:
        weights = v[deform] if deform else {}
        if not weights:
            doomed.append(v)
            continue
        best = max(weights.items(), key=lambda kv: kv[1])[0]
        bone = names.get(best, "")
        if not any(w in bone.replace("mixamorig:", "").replace("mixamorig_", "") for w in ARM_WORDS):
            doomed.append(v)
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(mesh.data)
    bm.free()
    print("malha:", mesh.name, "vértices restantes:", len(mesh.data.vertices))
for act in list(bpy.data.actions):
    if not act.name.startswith(keep_anim):
        bpy.data.actions.remove(act)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True,
                          export_animation_mode="ACTIONS", export_yup=True)
print("EXPORTADO", out)
