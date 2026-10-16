# Monta o PCI jogável: rig do Mixamo + todas as animações da lista ANIMS num GLB só para a Godot.
# Uso: ferramentas/blender -b --factory-startup --python blender/scripts/pci_montagem.py
#
# Entrada: exportados/mixamo/pci_rig.fbx (personagem com esqueleto, T-pose)
#          exportados/mixamo/<animação>.fbx (Without Skin, mesmo esqueleto)
# Saída:   exportados/pci_v5.glb, blender/arquivos/pci_v5.blend
#
# v5: a malha é a do PCI v3 (blender/arquivos/pci_v3.blend). Os pesos do esqueleto são
# transferidos da malha antiga que veio do Mixamo (mesmo esqueleto, mesma pose T), então
# não é preciso subir o modelo novo no Mixamo.
#
# Cada animação vira uma faixa NLA com o nome do arquivo (parado, soco, ...); o
# exportador glTF transforma cada faixa numa animação com esse nome na Godot.
import os

import bpy

ROOT = os.path.expanduser("~/Documentos/central")
MIX = os.path.join(ROOT, "exportados/mixamo")
ANIMS = [
    # base
    "parado", "andar_frente", "andar_tras", "agachado", "pulo", "passo_esq", "passo_dir",
    # golpes normais (botões 1-4) e direcionais
    "jab", "soco", "chute", "chute_circular", "rasteira", "gancho", "chute_voador", "empurrao",
    # especiais
    "arremesso", "corte", "furacao", "corte_duplo",
    # defesa e reações
    "bloqueio", "dano", "dano_corpo", "lancado", "queda", "levantar", "derrota",
    # apresentação
    "reverencia", "vitoria",
]
# Peças da katana: são as únicas que usam estes materiais (ver pci_v2.py).
KATANA_MATS = {"metal", "bainha", "cabo"}
KATANA_BONE = "mixamorig:Spine2"

MODELO_NOVO = os.path.join(ROOT, "blender/arquivos/pci_v3.blend")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(MIX, "pci_rig.fbx"))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
antiga = next(o for o in bpy.data.objects if o.type == "MESH")
arm.name = "PCI_rig"

# ---------- malha nova com os pesos da antiga ----------
with bpy.data.libraries.load(MODELO_NOVO, link=False) as (origem, destino):
    destino.objects = ["PCI_v3"]
mesh = destino.objects[0]
bpy.context.scene.collection.objects.link(mesh)
if "UVMap" in mesh.data.uv_layers:
    mesh.data.uv_layers.remove(mesh.data.uv_layers["UVMap"])
for g in antiga.vertex_groups:
    mesh.vertex_groups.new(name=g.name)
dt = mesh.modifiers.new("pesos", "DATA_TRANSFER")
dt.object = antiga
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.modifier_apply(modifier="pesos")
mesh.parent = arm
mesh.matrix_parent_inverse = arm.matrix_world.inverted()
mod = mesh.modifiers.new("Armature", "ARMATURE")
mod.object = arm
bpy.data.objects.remove(antiga, do_unlink=True)
mesh.name = "PCI"
sem_peso = sum(1 for v in mesh.data.vertices if not v.groups)
print(f"PESOS transferidos: {len(mesh.data.vertices)} vértices, {sem_peso} sem peso")

# ---------- katana presa nas costas ----------
# O auto-rig do Mixamo espalhou peso da katana pela cabeça e pela coxa; aí o cabo
# entorta quando a cabeça vira. Toda a katana passa a seguir só a coluna.
mat_idx = {i for i, m in enumerate(mesh.data.materials) if m and m.name.split(".")[0] in KATANA_MATS}
kverts = {v for p in mesh.data.polygons if p.material_index in mat_idx for v in p.vertices}
groups = list(mesh.vertex_groups)
for g in groups:
    g.remove(list(kverts))
mesh.vertex_groups[KATANA_BONE].add(list(kverts), 1.0, "REPLACE")
print(f"KATANA {len(kverts)} vértices presos em {KATANA_BONE}")

# ---------- animações ----------
arm.animation_data_create()
for a in list(bpy.data.actions):  # a pose T do rig não interessa
    bpy.data.actions.remove(a)

for name in ANIMS:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(MIX, f"{name}.fbx"))
    new = set(bpy.data.objects) - before
    src = next(o for o in new if o.type == "ARMATURE")
    act = src.animation_data.action
    act.name = name
    act.use_fake_user = True
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(act.frame_range[0]), act)
    if hasattr(strip, "action_slot") and act.slots:  # ações em camadas (Blender 4.4+)
        strip.action_slot = act.slots[0]
    track.mute = False
    print(f"ANIM {name}: {int(act.frame_range[1] - act.frame_range[0])} quadros")

arm.animation_data.action = None
for d in [d for d in bpy.data.armatures if d.users == 0]:
    bpy.data.armatures.remove(d)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender/arquivos/pci_v5.blend"))
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
mesh.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=os.path.join(ROOT, "exportados/pci_v5.glb"),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,
)
print("OK")
