# Ninja v1: blockout low-poly estilo PS2, montado por script a partir da referência.
# Uso: blender -b --factory-startup --python ninja_v1.py
# Personagem em pose T (exigência do auto-rig do Mixamo), olhando para -Y, 1,80 m.
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.expanduser("~/Documentos/central")
REF = os.path.join(ROOT, "referencias")
OUT_BLEND = os.path.join(ROOT, "blender/arquivos/ninja_v1.blend")
OUT_RENDER = os.path.join(ROOT, "blender/renders")
os.makedirs(OUT_RENDER, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- materiais ----------
def mat(name, color, rough=0.8, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


SKIN = (0.20, 0.10, 0.06)
M_SKIN = mat("pele", SKIN, 0.55)
M_CLOTH = mat("tecido_preto", (0.018, 0.018, 0.02), 0.9)
M_CLOTH2 = mat("tecido_cinza", (0.035, 0.033, 0.032), 0.95)
M_WRAP = mat("faixas", (0.055, 0.048, 0.042), 0.95)
M_HAIR = mat("cabelo", (0.012, 0.009, 0.008), 0.7)
M_STEEL = mat("metal", (0.35, 0.33, 0.3), 0.35, 1.0)
M_SAYA = mat("bainha", (0.02, 0.02, 0.02), 0.4)
M_TSUKA = mat("cabo", (0.12, 0.09, 0.05), 0.8)


def face_material():
    """Rosto da referência projetado de frente, misturado à cor da pele pelos lados."""
    m = bpy.data.materials.new("rosto")
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    bsdf = n["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.55
    tex = n.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(REF, "rosto.png"))
    tex.extension = "EXTEND"
    geo = n.new("ShaderNodeNewGeometry")
    sep = n.new("ShaderNodeSeparateXYZ")
    l.new(geo.outputs["Normal"], sep.inputs[0])
    neg = n.new("ShaderNodeMath")
    neg.operation = "MULTIPLY"
    neg.inputs[1].default_value = -1
    l.new(sep.outputs["Y"], neg.inputs[0])
    rng = n.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = 0.15
    rng.inputs["From Max"].default_value = 0.55
    l.new(neg.outputs[0], rng.inputs["Value"])
    mix = n.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    ins = {s.identifier: s for s in mix.inputs}
    l.new(rng.outputs["Result"], ins["Factor_Float"])
    ins["A_Color"].default_value = (*SKIN, 1)
    l.new(tex.outputs["Color"], ins["B_Color"])
    out = {s.identifier: s for s in mix.outputs}["Result_Color"]
    l.new(out, bsdf.inputs["Base Color"])
    return m


M_FACE = face_material()


# ---------- helpers de geometria ----------
def finish(obj, material, name, bevel=0.0, subsurf=0, smooth=True):
    obj.name = name
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    if subsurf:
        obj.modifiers.new("sub", "SUBSURF").levels = subsurf
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def box(name, loc, size, material, bevel=0.01, subsurf=0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, material, name, bevel, subsurf, smooth=subsurf > 0)


def limb(name, a, b, r1, r2, material, verts=8):
    """Tronco de cone entre dois pontos (membros, bainha, etc.)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2,
                                    depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    return finish(o, material, name)


def sphere(name, loc, scale, material, seg=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, material, name)


# ---------- cabeça ----------
HEAD_C = Vector((0, 0, 1.66))
HEAD_R = Vector((0.095, 0.105, 0.125))
head = sphere("cabeca", HEAD_C, HEAD_R, M_FACE, seg=16, rings=12)
# Mandíbula mais larga e queixo projetado, como na referência.
for v in head.data.vertices:
    dz = v.co.z - HEAD_C.z
    if dz < 0:
        v.co.x *= 1.0 + 0.15 * (-dz / HEAD_R.z)
    if v.co.y < -0.05 and dz < -0.06:
        v.co.y -= 0.01

# UV: projeção frontal só da parte do rosto da foto. No recorte rosto.png (412x470)
# a linha do cabelo fica em y≈120, o queixo em y≈365 e o rosto vai de x≈95 a x≈285.
W, H = 412, 470
HAIRLINE_Z = HEAD_C.z + 0.06
CHIN_Z = HEAD_C.z - HEAD_R.z


def project_face_uv(obj):
    # A primitiva já nasce com uma camada UV, que é a que o material usa: sobrescreve ela.
    uv = obj.data.uv_layers[0] if obj.data.uv_layers else obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            # transform_apply já levou posição e escala para os vértices: co é global.
            co = obj.data.vertices[obj.data.loops[li].vertex_index].co
            px = 190 + co.x / HEAD_R.x * 100
            py = 120 + (HAIRLINE_Z - co.z) / (HAIRLINE_Z - CHIN_Z) * 245
            uv.data[li].uv = (px / W, 1 - py / H)


project_face_uv(head)
# Nariz no ponto do nariz da foto (y≈260), com a mesma textura projetada.
nose = sphere("nariz", (0, -0.1, HAIRLINE_Z - 140 / 245 * (HAIRLINE_Z - CHIN_Z)), (0.017, 0.02, 0.026), M_FACE, 8, 6)
project_face_uv(nose)

# Cabelo: calota cacheada com corte degradê (linha do cabelo mais alta na frente).
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=1, location=HEAD_C + Vector((0, 0.005, 0.02)))
hair = bpy.context.object
hair.scale = (0.103, 0.112, 0.128)
bpy.ops.object.transform_apply(scale=True)
bm = bmesh.new()
bm.from_mesh(hair.data)
HAIR_C = HEAD_C + Vector((0, 0.005, 0.02))


def below_hairline(co):
    rel = co - HAIR_C  # vértices estão em coordenada global depois do transform_apply
    return rel.z < -0.02 + max(0.0, -rel.y) * 0.75 - max(0.0, rel.y) * 0.25


cut = [v for v in bm.verts if below_hairline(v.co)]
bmesh.ops.delete(bm, geom=cut, context="VERTS")
bm.to_mesh(hair.data)
bm.free()
tex = bpy.data.textures.new("cachos", "CLOUDS")
tex.noise_scale = 0.12
disp = hair.modifiers.new("cachos", "DISPLACE")
disp.texture = tex
disp.strength = 0.022
disp.mid_level = 0.3
finish(hair, M_HAIR, "cabelo")

# ---------- pescoço / gola / tronco ----------
limb("pescoco", (0, 0, 1.47), (0, 0, 1.56), 0.055, 0.05, M_SKIN)
bpy.ops.mesh.primitive_torus_add(major_radius=0.085, minor_radius=0.04, location=(0, 0.005, 1.5))
finish(bpy.context.object, M_CLOTH, "gola")
bpy.ops.mesh.primitive_torus_add(major_radius=0.1, minor_radius=0.035, location=(0, 0.01, 1.46))
finish(bpy.context.object, M_CLOTH, "gola2")

# Tronco: cubo afinando na cintura.
torso = box("tronco", (0, 0, 1.24), (0.4, 0.22, 0.42), M_CLOTH, bevel=0, subsurf=1)
for v in torso.data.vertices:
    t = (v.co.z - 1.03) / 0.42  # 0 na cintura, 1 nos ombros
    v.co.x *= 0.78 + 0.22 * t
    v.co.y *= 0.85 + 0.15 * t

# Faixas cruzadas no peito (cinto da katana passa no ombro direito).
box("faixa_peito_1", (0, -0.118, 1.28), (0.045, 0.012, 0.5), M_WRAP, rot=(0, math.radians(-38), 0))
box("faixa_peito_2", (0, -0.124, 1.28), (0.035, 0.012, 0.42), M_CLOTH2, rot=(0, math.radians(38), 0))

# Obi: faixa larga na cintura com nó e pontas caindo na frente.
limb("obi", (0, 0, 0.98), (0, 0, 1.1), 0.175, 0.17, M_CLOTH2, verts=12)
box("obi_no", (0.0, -0.17, 1.03), (0.07, 0.04, 0.06), M_CLOTH2, bevel=0.015)
box("obi_ponta_1", (-0.02, -0.17, 0.86), (0.04, 0.01, 0.28), M_CLOTH2, rot=(0, math.radians(6), 0))
box("obi_ponta_2", (0.035, -0.168, 0.88), (0.035, 0.01, 0.24), M_CLOTH2, rot=(0, math.radians(-8), 0))

# Saia/tabardo em pontas na frente e atrás.
for side, y in (("frente", -0.155), ("tras", 0.155)):
    box(f"tabardo_{side}", (0, y, 0.82), (0.34, 0.012, 0.3), M_CLOTH)

# ---------- braços (pose T) ----------
for s in (1, -1):
    sx = "D" if s < 0 else "E"  # personagem olha para -Y: direita dele é -X
    limb(f"ombro_{sx}", (s * 0.17, 0, 1.4), (s * 0.27, 0, 1.4), 0.075, 0.068, M_CLOTH)
    limb(f"braco_{sx}", (s * 0.26, 0, 1.4), (s * 0.48, 0, 1.4), 0.065, 0.052, M_CLOTH)
    limb(f"antebraco_{sx}", (s * 0.48, 0, 1.4), (s * 0.7, 0, 1.4), 0.05, 0.042, M_WRAP)
    for i in range(4):  # voltas das faixas
        x = 0.51 + i * 0.05
        bpy.ops.mesh.primitive_torus_add(major_radius=0.047 - i * 0.002, minor_radius=0.008,
                                         location=(s * x, 0, 1.4), rotation=(0, math.radians(90), 0))
        finish(bpy.context.object, M_CLOTH2, f"volta_{sx}_{i}")
    box(f"mao_{sx}", (s * 0.77, -0.005, 1.395), (0.1, 0.045, 0.085), M_WRAP, bevel=0.015)
    box(f"dedao_{sx}", (s * 0.735, -0.04, 1.39), (0.04, 0.025, 0.03), M_WRAP, bevel=0.008)

# ---------- pernas ----------
for s in (1, -1):
    sx = "D" if s < 0 else "E"
    limb(f"coxa_{sx}", (s * 0.1, 0, 0.98), (s * 0.11, 0, 0.6), 0.1, 0.095, M_CLOTH)  # calça larga
    limb(f"canela_{sx}", (s * 0.11, 0, 0.6), (s * 0.11, 0, 0.12), 0.065, 0.05, M_WRAP)
    for i in range(6):
        z = 0.55 - i * 0.075
        bpy.ops.mesh.primitive_torus_add(major_radius=0.065 - i * 0.002, minor_radius=0.01,
                                         location=(s * 0.11, 0, z), rotation=(math.radians(8 * (-1) ** i), 0, 0))
        finish(bpy.context.object, M_CLOTH2, f"perneira_{sx}_{i}")
    box(f"pe_{sx}", (s * 0.11, -0.04, 0.05), (0.1, 0.25, 0.1), M_CLOTH, bevel=0.03)

# ---------- katana nas costas: cabo no ombro direito, ponta no quadril esquerdo ----------
top = Vector((-0.2, 0.17, 1.62))
bottom = Vector((0.24, 0.17, 0.82))
axis = (bottom - top).normalized()
tsuba = top + axis * 0.26
limb("katana_cabo", top, tsuba, 0.017, 0.017, M_TSUKA)
limb("katana_kashira", top - axis * 0.012, top + axis * 0.01, 0.019, 0.019, M_STEEL)
limb("katana_tsuba", tsuba - axis * 0.006, tsuba + axis * 0.006, 0.042, 0.042, M_STEEL, verts=12)
limb("katana_bainha", tsuba + axis * 0.006, bottom, 0.02, 0.017, M_SAYA)

# Junta tudo de um personagem num objeto só (o Mixamo aceita uma malha).
parts = [o for o in scene.objects if o.type == "MESH"]
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = head
bpy.ops.object.convert(target="MESH")  # aplica modificadores
bpy.ops.object.join()
ninja = bpy.context.object
ninja.name = "Ninja"
tris = sum(len(p.vertices) - 2 for p in ninja.data.polygons)
print("TRIANGULOS", tris)

# ---------- cena de render ----------
world = bpy.data.worlds.new("mundo")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.02, 0.022, 1)
scene.world = world


def light(name, loc, energy, size=1.0):
    d = bpy.data.lights.new(name, "AREA")
    d.energy = energy
    d.size = size
    o = bpy.data.objects.new(name, d)
    o.location = loc
    scene.collection.objects.link(o)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (Vector((0, 0, 1.1)) - Vector(loc)).to_track_quat("-Z", "Y")


light("key", (-1.5, -2.5, 2.5), 120, 1.5)
light("fill", (2.0, -2.0, 1.4), 30, 2.0)
light("rim", (0.5, 2.5, 2.4), 150, 1.0)

cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 1100


def shot(fname, loc, target, lens):
    cam_d.lens = lens
    cam.location = loc
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y")
    scene.render.filepath = os.path.join(OUT_RENDER, fname)
    bpy.ops.render.render(write_still=True)


shot("v1_frente.png", (0, -5.0, 1.0), (0, 0, 0.95), 75)
shot("v1_costas.png", (0, 5.0, 1.0), (0, 0, 0.95), 75)
shot("v1_tres_quartos.png", (-3.0, -3.8, 1.3), (0, 0, 0.95), 70)
shot("v1_rosto.png", (0.35, -1.3, 1.68), (0, 0, 1.63), 85)

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("OK", OUT_BLEND)
