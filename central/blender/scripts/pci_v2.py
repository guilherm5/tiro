# PCI v2 (o ninja): modelo low-poly estilo PS2 montado por script a partir da referência.
# Uso: ferramentas/blender -b --factory-startup --python blender/scripts/pci_v2.py
#
# Convenções (valem para todo personagem do projeto):
# - 1 unidade = 1 metro, Z para cima, personagem olhando para -Y, pés em Z=0.
# - Pose T, braços no eixo X, mãos abertas (é o que o auto-rig do Mixamo espera).
# - Direita do personagem = -X (sufixo _D), esquerda = +X (sufixo _E).
# - Saída: .blend, FBX para o Mixamo (texturas embutidas), GLB para a Godot e renders.
#
# Atenção: depois de transform_apply e nas malhas feitas com bmesh, os vértices
# estão em coordenada GLOBAL (o objeto fica na origem). Todo cálculo usa isso.
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.expanduser("~/Documentos/central")
REF = os.path.join(ROOT, "referencias")
OUT_BLEND = os.path.join(ROOT, "blender/arquivos/pci_v2.blend")
OUT_RENDER = os.path.join(ROOT, "blender/renders")
OUT_EXPORT = os.path.join(ROOT, "exportados")
for d in (OUT_RENDER, OUT_EXPORT, os.path.dirname(OUT_BLEND)):
    os.makedirs(d, exist_ok=True)

random.seed(7)  # cachos sempre no mesmo lugar entre execuções
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


SKIN = (0.2122, 0.0844, 0.0382)  # = (129, 82, 55) sRGB, a mesma da borda de rosto_textura.png
M_SKIN = mat("pele", SKIN, 0.55)
M_CLOTH = mat("tecido_preto", (0.018, 0.018, 0.02), 0.9)
M_CLOTH2 = mat("tecido_cinza", (0.035, 0.033, 0.032), 0.95)
M_WRAP = mat("faixas", (0.055, 0.048, 0.042), 0.95)
M_HAIR = mat("cabelo", (0.012, 0.009, 0.008), 0.7)
M_STEEL = mat("metal", (0.35, 0.33, 0.3), 0.35, 1.0)
M_SAYA = mat("bainha", (0.02, 0.02, 0.02), 0.4)
M_TSUKA = mat("cabo", (0.12, 0.09, 0.05), 0.8)


def face_material():
    """Rosto da referência como textura simples (exporta igual para FBX e glTF).

    referencias/rosto_textura.png já vem com a borda esfumada para a cor da pele
    (gerada por docs/PIPELINE.md, passo 2), então a projeção pode estourar a
    borda sem costura: EXTEND repete a cor da pele pelos lados e pela nuca.
    """
    m = bpy.data.materials.new("rosto")
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    bsdf = n["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.55
    tex = n.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(REF, "rosto_textura.png"))
    tex.extension = "EXTEND"
    l.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


M_FACE = face_material()


# ---------- helpers de geometria ----------
def new_obj(name, bm, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = smooth
    return o


def tube(name, rings, material, sides=8, caps=(True, True)):
    """Tubo low-poly passando por anéis (centro, raio_a, raio_b).

    raio_a fica no eixo perpendicular ao tubo e ao Y (largura num tubo vertical,
    altura num braço); raio_b fica no eixo Y (profundidade frente/trás).
    """
    bm = bmesh.new()
    loops = []
    pts = [Vector(c) for c, _, _ in rings]
    for i, (c, ra, rb) in enumerate(rings):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = Vector((0, 1, 0)).cross(d).normalized()
        v = d.cross(u).normalized()
        loops.append([bm.verts.new(Vector(c) + u * ra * math.cos(a) + v * rb * math.sin(a))
                      for a in (2 * math.pi * k / sides for k in range(sides))])
    for a, b in zip(loops, loops[1:]):
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if caps[0]:
        bm.faces.new(list(reversed(loops[0])))
    if caps[1]:
        bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_obj(name, bm, material)


def box(name, loc, size, material, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    if bevel:
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return o


def ring(name, center, radius, thick, material, axis="Z", tilt=0.0):
    """Volta de faixa: toro bem low-poly (8x4 = 64 triângulos)."""
    rot = {"Z": (tilt, 0, 0), "X": (0, math.pi / 2, tilt)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thick,
                                     major_segments=8, minor_segments=4,
                                     location=center, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    return o


def flap(name, top_y, top_z, x0, x1, bottom_z, tip_z, material, thick=0.012):
    """Painel de pano com a barra em ponta (tabardo), com espessura."""
    bm = bmesh.new()
    mid = (x0 + x1) / 2
    vs = [bm.verts.new(p) for p in ((x0, top_y, top_z), (x1, top_y, top_z),
                                    (x1, top_y, bottom_z), (mid, top_y, tip_z), (x0, top_y, bottom_z))]
    bm.faces.new(vs)
    o = new_obj(name, bm, material, smooth=False)
    o.modifiers.new("espessura", "SOLIDIFY").thickness = thick
    return o


def project_face_uv(obj, head_c, head_r):
    """UV frontal: no recorte rosto.png (412x470) a linha do cabelo fica em y≈120,
    o queixo em y≈365 e o centro do rosto em x≈190, com ~100 px de meia largura."""
    hairline_z, chin_z = head_c.z + 0.06, head_c.z - head_r.z
    uv = obj.data.uv_layers[0] if obj.data.uv_layers else obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            co = obj.data.vertices[obj.data.loops[li].vertex_index].co
            if co.y > head_c.y + 0.01:
                # Metade de trás: sem isso a nuca ganha o rosto espelhado. O canto
                # da textura é só cor de pele.
                uv.data[li].uv = (0.02, 0.98)
                continue
            px = 190 + co.x / head_r.x * 100
            py = 120 + (hairline_z - co.z) / (hairline_z - chin_z) * 245
            uv.data[li].uv = (px / 412, 1 - py / 470)


# ---------- cabeça ----------
HEAD_C = Vector((0, -0.005, 1.665))
HEAD_R = Vector((0.092, 0.104, 0.122))
bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, location=HEAD_C)
head = bpy.context.object
head.name = "cabeca"
head.scale = HEAD_R
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for v in head.data.vertices:
    dz = v.co.z - HEAD_C.z
    if dz < 0:  # mandíbula larga e queixo para frente, como na referência
        v.co.x *= 1.0 + 0.18 * (-dz / HEAD_R.z)
        if v.co.y < HEAD_C.y - 0.04 and dz < -0.06:
            v.co.y -= 0.012
    if abs(v.co.x) > 0.07 and abs(dz) < 0.04 and v.co.y < HEAD_C.y:
        v.co.y += 0.01  # achata as têmporas para o rosto não ficar balão
head.data.materials.append(M_FACE)
for p in head.data.polygons:
    p.use_smooth = True
project_face_uv(head, HEAD_C, HEAD_R)

nose_z = HEAD_C.z + 0.06 - 140 / 245 * (0.06 + HEAD_R.z)
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.018, radius2=0.006, depth=0.03)
bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Vector((0, 0, 1)).rotation_difference(Vector((0, -0.4, 1))).to_matrix())
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, HEAD_C.y - HEAD_R.y + 0.004, nose_z))
nose = new_obj("nariz", bm, M_FACE)
project_face_uv(nose, HEAD_C, HEAD_R)

for s in (1, -1):  # orelhas
    box(f"orelha_{'E' if s > 0 else 'D'}", (s * 0.094, HEAD_C.y + 0.01, HEAD_C.z - 0.005),
        (0.014, 0.035, 0.05), M_SKIN, bevel=0.006)

# Cabelo: calota de corte degradê (curto nos lados, alto em cima) + cachos.
HAIR_C = HEAD_C + Vector((0, 0.006, 0.022))
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=HAIR_C)
hair = bpy.context.object
hair.name = "cabelo"
hair.scale = (0.098, 0.11, 0.135)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm = bmesh.new()
bm.from_mesh(hair.data)


def hair_height(co):
    """Altura da linha do cabelo: mais alta na testa, mais baixa na nuca."""
    rel = co - HAIR_C
    return -0.02 + max(0.0, -rel.y) * 0.4 - max(0.0, rel.y) * 0.6


bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co - HAIR_C).z < hair_height(v.co)], context="VERTS")
crown = [v.co.copy() for v in bm.verts if (v.co - HAIR_C).z > 0.02]
bm.to_mesh(hair.data)
bm.free()
hair.data.materials.append(M_HAIR)
for c in crown:  # cachos só no topo, o lado fica raspado (degradê)
    out = (c - HAIR_C).normalized()
    pos = c + out * 0.006 + Vector((random.uniform(-.006, .006), random.uniform(-.006, .006), 0.004))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(0.017, 0.023), location=pos,
                                          rotation=[random.uniform(0, 3) for _ in range(3)])
    curl = bpy.context.object
    curl.name = "cacho"
    curl.data.materials.append(M_HAIR)
    for p in curl.data.polygons:
        p.use_smooth = True

# ---------- pescoço e gola alta ----------
tube("pescoco", [((0, 0, 1.46), .05, .05), ((0, -0.005, 1.57), .046, .048)], M_SKIN, caps=(False, False))
tube("gola", [((0, 0.005, 1.43), .14, .12), ((0, 0.0, 1.5), .1, .1), ((0, 0.005, 1.56), .075, .082),
              ((0, 0.01, 1.58), .068, .074)], M_CLOTH, sides=10, caps=(False, False))
ring("gola_dobra_1", (0, 0.004, 1.515), 0.095, 0.022, M_CLOTH, tilt=math.radians(-6))
ring("gola_dobra_2", (0, 0.008, 1.47), 0.12, 0.025, M_CLOTH, tilt=math.radians(5))

# ---------- tronco: peito largo, cintura fina ----------
tube("tronco", [((0, 0, 0.98), .16, .115), ((0, 0, 1.1), .155, .11), ((0, -0.005, 1.25), .19, .125),
                ((0, -0.005, 1.36), .215, .13), ((0, 0, 1.44), .2, .115), ((0, 0, 1.475), .13, .09)],
     M_CLOTH, sides=10)
for s in (1, -1):  # deltoides arredondados
    tube(f"ombreira_{'E' if s > 0 else 'D'}", [((s * .15, 0, 1.4), .07, .085), ((s * .22, 0, 1.405), .08, .09),
                                               ((s * .28, 0, 1.4), .07, .08)], M_CLOTH)
# Faixas cruzadas no peito: a mais grossa vai do ombro direito ao quadril esquerdo (bandoleira da katana).
box("faixa_peito_1", (0.01, -0.13, 1.26), (0.05, 0.012, 0.52), M_WRAP, rot=(0, math.radians(-36), 0))
box("faixa_peito_2", (0.0, -0.137, 1.28), (0.035, 0.012, 0.42), M_CLOTH2, rot=(0, math.radians(36), 0))
box("faixa_costas", (0.01, 0.13, 1.26), (0.05, 0.012, 0.52), M_WRAP, rot=(0, math.radians(36), 0))

# ---------- obi, tabardo e quadril ----------
tube("obi", [((0, 0, 0.97), .178, .135), ((0, 0, 1.1), .172, .13)], M_CLOTH2, sides=10)
box("obi_no", (0.0, -0.14, 1.03), (0.075, 0.04, 0.065), M_CLOTH2, bevel=0.012)
box("obi_ponta_1", (-0.022, -0.152, 0.85), (0.042, 0.01, 0.3), M_CLOTH2, rot=(0, math.radians(6), 0))
box("obi_ponta_2", (0.035, -0.15, 0.87), (0.036, 0.01, 0.26), M_CLOTH2, rot=(0, math.radians(-9), 0))
for s in (1, -1):  # duas abas em ponta na frente e duas atrás
    flap(f"tabardo_frente_{s}", -0.142, 0.99, s * 0.005, s * 0.17, 0.72, 0.63, M_CLOTH)
    flap(f"tabardo_tras_{s}", 0.14, 0.99, s * 0.005, s * 0.17, 0.7, 0.62, M_CLOTH)
tube("quadril", [((0, 0, 0.83), .17, .115), ((0, 0, 0.99), .17, .12)], M_CLOTH, sides=10)

# ---------- pernas: calça bufante presa por perneiras enfaixadas ----------
for s in (1, -1):
    sx = "E" if s > 0 else "D"
    x = s * 0.1
    tube(f"calca_{sx}", [((x, 0, 0.93), .095, .1), ((x * 1.05, 0, 0.8), .115, .115),
                         ((x * 1.1, -0.01, 0.64), .12, .115), ((x * 1.1, 0, 0.53), .085, .085),
                         ((x * 1.1, 0, 0.5), .07, .07)], M_CLOTH)
    tube(f"perneira_{sx}", [((x * 1.1, 0, 0.52), .07, .07), ((x * 1.1, 0.005, 0.38), .064, .068),
                            ((x * 1.1, 0, 0.2), .052, .055), ((x * 1.1, 0, 0.1), .05, .055)], M_WRAP)
    for i in range(5):
        ring(f"perneira_volta_{sx}_{i}", (x * 1.1, 0, 0.47 - i * 0.075), 0.066 - i * 0.003, 0.009,
             M_CLOTH2, tilt=math.radians(10 * (-1) ** i))
    # Tabi: bota com dedão separado.
    box(f"pe_{sx}", (x * 1.1, -0.035, 0.045), (0.095, 0.24, 0.09), M_CLOTH, bevel=0.025)
    box(f"dedao_{sx}", (x * 1.1 - s * 0.03, -0.165, 0.03), (0.035, 0.04, 0.05), M_CLOTH, bevel=0.012)

# ---------- braços: manga até o cotovelo, pele, antebraço enfaixado, mão aberta ----------
SH_Z = 1.4
for s in (1, -1):
    sx = "E" if s > 0 else "D"
    tube(f"manga_{sx}", [((s * .2, 0, SH_Z), .075, .08), ((s * .33, 0, SH_Z), .07, .072),
                         ((s * .45, 0, SH_Z), .066, .066)], M_CLOTH, caps=(False, True))
    tube(f"cotovelo_{sx}", [((s * .44, 0, SH_Z), .05, .052), ((s * .5, 0, SH_Z), .047, .049)], M_SKIN)
    tube(f"antebraco_{sx}", [((s * .49, 0, SH_Z), .052, .054), ((s * .62, 0, SH_Z), .047, .05),
                             ((s * .71, 0, SH_Z), .038, .042)], M_WRAP)
    for i in range(3):
        ring(f"antebraco_volta_{sx}_{i}", (s * (0.53 + i * 0.06), 0, SH_Z), 0.05 - i * 0.004, 0.008,
             M_CLOTH2, axis="X", tilt=math.radians(12 * (-1) ** i))
    # Palma achatada (pouca altura, mais profundidade), dedos juntos e polegar para frente.
    tube(f"palma_{sx}", [((s * .7, 0, SH_Z), .03, .042), ((s * .79, 0, SH_Z - .005), .022, .048)], M_WRAP, sides=6)
    tube(f"dedos_{sx}", [((s * .79, 0, SH_Z - .005), .018, .044), ((s * .875, 0, SH_Z - .01), .012, .036)],
         M_SKIN, sides=6)
    tube(f"polegar_{sx}", [((s * .73, -0.035, SH_Z - .01), .013, .014), ((s * .78, -0.075, SH_Z - .015), .01, .011)],
         M_SKIN, sides=5)

# ---------- katana nas costas: cabo no ombro direito, ponta no quadril esquerdo ----------
top = Vector((-0.2, 0.17, 1.62))
bottom = Vector((0.25, 0.17, 0.8))
axis = (bottom - top).normalized()
tsuba = top + axis * 0.26
tube("katana_cabo", [(top, .017, .017), (tsuba, .017, .017)], M_TSUKA, sides=6)
tube("katana_kashira", [(top - axis * 0.012, .019, .019), (top + axis * 0.008, .019, .019)], M_STEEL, sides=6)
tube("katana_tsuba", [(tsuba - axis * 0.006, .042, .042), (tsuba + axis * 0.006, .042, .042)], M_STEEL, sides=10)
tube("katana_bainha", [(tsuba + axis * 0.006, .02, .016), (bottom, .016, .013)], M_SAYA, sides=6)

# ---------- junta tudo numa malha só (o Mixamo aceita um objeto) ----------
parts = [o for o in scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = head
bpy.ops.object.convert(target="MESH")  # aplica bevel/solidify
bpy.ops.object.join()
ninja = bpy.context.object
ninja.name = "PCI"
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
tris = sum(len(p.vertices) - 2 for p in ninja.data.polygons)
dims = ninja.dimensions
print(f"TRIANGULOS {tris}  DIMENSOES {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m")

# ---------- exportação ----------
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_EXPORT, "pci_v2_mixamo.fbx"), use_selection=True,
                         path_mode="COPY", embed_textures=True, apply_unit_scale=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_EXPORT, "pci_v2.glb"), use_selection=True,
                          export_format="GLB")

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


shot("pci_v2_frente.png", (0, -5.0, 1.0), (0, 0, 0.95), 75)
shot("pci_v2_costas.png", (0, 5.0, 1.0), (0, 0, 0.95), 75)
shot("pci_v2_tres_quartos.png", (-3.0, -3.8, 1.3), (0, 0, 0.95), 70)
shot("pci_v2_rosto.png", (0.35, -1.3, 1.68), (0, 0, 1.63), 85)

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("OK", OUT_BLEND)
