# Katana desembainhada (vai na mão do PCI nos especiais).
# Uso: ferramentas/blender -b --factory-startup --python blender/scripts/katana.py
# Saída: exportados/katana.glb e jogo/assets/personagens/pci/katana.glb
#
# Origem = ponto de pegada no cabo; a lâmina aponta para +Z no Blender (= +Y na Godot).
# Comprimento da origem até a ponta: 0,86 m (é o "katana_comprimento" em dados/pci.json).
import os
import shutil

import bmesh
import bpy

ROOT = os.path.expanduser("~/Documentos/central")
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(nome, cor, rough, metal=0.0):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


M_LAMINA = mat("lamina", (0.8, 0.82, 0.86), 0.2, 1.0)
M_CABO = mat("cabo", (0.12, 0.09, 0.05), 0.8)
M_GUARDA = mat("metal", (0.35, 0.33, 0.3), 0.35, 1.0)

bm = bmesh.new()
camadas = []


def cilindro(r, z0, z1, lados, indice):
    geo = bmesh.ops.create_cone(bm, cap_ends=True, segments=lados, radius1=r, radius2=r, depth=z1 - z0)
    bmesh.ops.translate(bm, verts=geo["verts"], vec=(0, 0, (z0 + z1) / 2))
    for fc in {f for v in geo["verts"] for f in v.link_faces}:
        fc.material_index = indice


cilindro(0.017, -0.11, 0.13, 6, 1)   # cabo
cilindro(0.04, 0.13, 0.145, 10, 2)   # tsuba
# lâmina: seção em losango, afinando até a ponta
secao = [(0.0, 0.016), (0.004, 0.0), (0.0, -0.014), (-0.004, 0.0)]
aneis = []
for z, esc in ((0.145, 1.0), (0.5, 0.9), (0.78, 0.7)):
    aneis.append([bm.verts.new((x * 1.0, y * esc, z)) for x, y in secao])
ponta = bm.verts.new((0, 0.006, 0.86))
for a, b in zip(aneis, aneis[1:]):
    for i in range(4):
        f = bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
        f.material_index = 0
for i in range(4):
    f = bm.faces.new((aneis[-1][i], aneis[-1][(i + 1) % 4], ponta))
    f.material_index = 0
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

me = bpy.data.meshes.new("katana")
bm.to_mesh(me)
for m in (M_LAMINA, M_CABO, M_GUARDA):
    me.materials.append(m)
obj = bpy.data.objects.new("katana", me)
bpy.context.scene.collection.objects.link(obj)
obj.select_set(True)
saida = os.path.join(ROOT, "exportados/katana.glb")
bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", use_selection=True)
shutil.copy(saida, os.path.join(ROOT, "jogo/assets/personagens/pci/katana.glb"))
print("OK", len(me.polygons), "faces")
