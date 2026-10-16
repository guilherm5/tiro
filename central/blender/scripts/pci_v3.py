# PCI v3: modelo estilo PS2 "caprichado", construído em volta das juntas reais do rig.
# Uso: ferramentas/blender -b --factory-startup --python blender/scripts/pci_v3.py
#
# Saída:
#   blender/arquivos/pci_v3.blend         objeto "PCI_v3" (malha única, sem esqueleto)
#   jogo/assets/personagens/pci/pci_atlas_1p.png, pci_atlas_2p.png  (corpo assado: cor + sombra)
#   blender/renders/pci_v3_*.png
#
# Materiais finais da malha: "corpo" (atlas assado), "rosto" (selfie projetada),
# "pele" (orelhas), e os da katana: "cabo", "metal", "bainha" (o jogo esconde cabo/metal
# das costas quando o PCI saca a espada).
# Convenções como no v2: metros, Z para cima, olhando para -Y, pose T.
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.expanduser("~/Documentos/central")
J = json.load(open(os.path.join(ROOT, "blender/juntas_pci.json")))
ROSTO_PNG = os.path.join(ROOT, "referencias/rosto_v3.png")
SAIDA_ATLAS = os.path.join(ROOT, "jogo/assets/personagens/pci")
TAM_ATLAS = 1024
random.seed(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene


def junta(nome):
    v = J[nome]
    return Vector((v[0], v[1], v[2]))


# ---------------------------------------------------------------- materiais
def no(nt, tipo, **props):
    n = nt.nodes.new(tipo)
    for k, v in props.items():
        setattr(n, k, v)
    return n


def material_procedural(nome, cor, tipo="tecido", cor2=None):
    """Material que vira textura no bake: cor base + variação + trama/listras + relevo."""
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    coord = no(nt, "ShaderNodeTexCoord")
    ruido = no(nt, "ShaderNodeTexNoise")
    ruido.inputs["Scale"].default_value = 18.0
    ruido.inputs["Detail"].default_value = 6.0
    nt.links.new(coord.outputs["Object"], ruido.inputs["Vector"])
    mistura = no(nt, "ShaderNodeMix", data_type="RGBA")
    ins = {s.identifier: s for s in mistura.inputs}
    ins["A_Color"].default_value = (*cor, 1)
    ins["B_Color"].default_value = (*(cor2 or [c * 1.4 + 0.006 for c in cor]), 1)
    rampa = no(nt, "ShaderNodeMapRange")
    rampa.inputs["From Min"].default_value = 0.35
    rampa.inputs["From Max"].default_value = 0.75
    nt.links.new(ruido.outputs["Fac"], rampa.inputs["Value"])
    fator = rampa.outputs["Result"]
    if tipo in ("faixa", "obi", "couro_listra"):
        onda = no(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
        onda.inputs["Scale"].default_value = 26.0 if tipo == "faixa" else 5.0
        onda.inputs["Distortion"].default_value = 1.5
        nt.links.new(coord.outputs["Object"], onda.inputs["Vector"])
        m2 = no(nt, "ShaderNodeMath", operation="MULTIPLY")
        nt.links.new(onda.outputs["Fac"], m2.inputs[0])
        nt.links.new(rampa.outputs["Result"], m2.inputs[1])
        fator = m2.outputs[0]
    nt.links.new(fator, ins["Factor_Float"])
    saida_cor = {s.identifier: s for s in mistura.outputs}["Result_Color"]
    nt.links.new(saida_cor, bsdf.inputs["Base Color"])
    # relevo de dobras/trama (entra no bake como sombreamento)
    relevo = no(nt, "ShaderNodeBump")
    relevo.inputs["Strength"].default_value = 0.35 if tipo != "pele" else 0.08
    rug = no(nt, "ShaderNodeTexNoise")
    rug.inputs["Scale"].default_value = 60.0 if tipo != "tecido" else 7.0
    rug.inputs["Detail"].default_value = 3.0
    nt.links.new(coord.outputs["Object"], rug.inputs["Vector"])
    nt.links.new(rug.outputs["Fac"], relevo.inputs["Height"])
    nt.links.new(relevo.outputs["Normal"], bsdf.inputs["Normal"])
    m["cor_base"] = list(cor)
    return m


def material_simples(nome, cor, rough=0.8, metal=0.0):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


PELE = (0.262, 0.127, 0.082)   # sRGB (140, 100, 81): mediana das bochechas da selfie, escurecida
M_TECIDO = material_procedural("tecido_preto", (0.02, 0.02, 0.024))
M_TECIDO2 = material_procedural("tecido_cinza", (0.05, 0.047, 0.045), "obi")
M_FAIXA = material_procedural("faixas", (0.07, 0.062, 0.052), "faixa", (0.025, 0.022, 0.02))
M_COURO = material_procedural("couro", (0.09, 0.05, 0.025), "couro_listra")
M_PELE_CORPO = material_procedural("pele_corpo", PELE, "pele", [c * 1.2 for c in PELE])
M_PELE = material_simples("pele", PELE, 0.6)
M_CABO = material_simples("cabo", (0.11, 0.08, 0.05), 0.8)
M_METAL = material_simples("metal", (0.4, 0.38, 0.33), 0.3, 1.0)
M_BAINHA = material_simples("bainha", (0.015, 0.012, 0.012), 0.25)

M_ROSTO = bpy.data.materials.new("rosto")
M_ROSTO.use_nodes = True
_tex = M_ROSTO.node_tree.nodes.new("ShaderNodeTexImage")
_tex.image = bpy.data.images.load(ROSTO_PNG)
_tex.extension = "EXTEND"
_uv = M_ROSTO.node_tree.nodes.new("ShaderNodeUVMap")
_uv.uv_map = "proj"
M_ROSTO.node_tree.links.new(_uv.outputs["UV"], _tex.inputs["Vector"])
M_ROSTO.node_tree.links.new(_tex.outputs["Color"], M_ROSTO.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
M_ROSTO.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6

CORES_2P = {"tecido_preto": (0.16, 0.012, 0.015), "tecido_cinza": (0.03, 0.02, 0.02), "faixas": (0.12, 0.04, 0.035)}


# ---------------------------------------------------------------- geometria
partes_corpo = []     # vão para o atlas assado
partes_cabeca = []    # rosto/cabelo/orelhas (textura própria)
partes_katana = []


def novo_obj(nome, bm, material, lista, liso=True):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    cena.collection.objects.link(o)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = liso
    lista.append(o)
    return o


def tubo(nome, aneis, material, lista, lados=10, tampas=(True, True)):
    """Tubo por anéis (centro, raio_largura, raio_profundidade). Ver pci_v2.py."""
    bm = bmesh.new()
    loops = []
    pts = [Vector(c) for c, _, _ in aneis]
    for i, (c, ra, rb) in enumerate(aneis):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
        u = ref.cross(d).normalized()
        v = d.cross(u).normalized()
        loops.append([bm.verts.new(Vector(c) + u * ra * math.cos(a) + v * rb * math.sin(a))
                      for a in (2 * math.pi * k / lados for k in range(lados))])
    for a, b in zip(loops, loops[1:]):
        for k in range(lados):
            bm.faces.new((a[k], a[(k + 1) % lados], b[(k + 1) % lados], b[k]))
    if tampas[0]:
        bm.faces.new(list(reversed(loops[0])))
    if tampas[1]:
        bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return novo_obj(nome, bm, material, lista)


def caixa(nome, centro, tamanho, material, lista, chanfro=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centro, rotation=rot)
    o = bpy.context.object
    o.name = nome
    o.scale = tamanho
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    if chanfro:
        mod = o.modifiers.new("chanfro", "BEVEL")
        mod.width = chanfro
        mod.segments = 2
    lista.append(o)
    return o


def elipsoide(nome, centro, raios, material, lista, seg=10, aneis=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=aneis, location=centro)
    o = bpy.context.object
    o.name = nome
    o.scale = raios
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    lista.append(o)
    return o


def faixa_superficie(nome, pontos, largura, espessura, material, lista):
    """Tira achatada seguindo uma linha (alças cruzadas, cinto)."""
    return tubo(nome, [(p, largura, espessura) for p in pontos], material, lista, lados=4)


def toro(nome, centro, raio, grossura, material, lista, eixo="Z", inclina=0.0, segmentos=(12, 4)):
    rot = {"Z": (inclina, 0, 0), "X": (0, math.pi / 2, inclina)}[eixo]
    bpy.ops.mesh.primitive_torus_add(major_radius=raio, minor_radius=grossura, major_segments=12,
                                     minor_segments=4, location=centro, rotation=rot)
    o = bpy.context.object
    o.name = nome
    o.data.materials.append(material)
    lista.append(o)
    return o


def aba(nome, y, z_topo, x0, x1, z_base, z_ponta, material, lista, grossura=0.012):
    bm = bmesh.new()
    meio = (x0 + x1) / 2
    vs = [bm.verts.new(p) for p in ((x0, y, z_topo), (x1, y, z_topo), (x1, y, z_base), (meio, y, z_ponta), (x0, y, z_base))]
    bm.faces.new(vs)
    o = novo_obj(nome, bm, material, lista, liso=False)
    o.modifiers.new("espessura", "SOLIDIFY").thickness = grossura
    return o


# ================================================================ CABEÇA
OLHO_Z = 1.695
ESC = 0.000545           # metros por pixel da selfie
CX_FOTO, CY_FOTO = 408, 285
C = Vector((0.0, -0.004, 1.675))
R = Vector((0.074, 0.097, 0.117))


def gauss(x, z, cx, cz, rx, rz):
    return math.exp(-(((x - cx) / rx) ** 2) - (((z - cz) / rz) ** 2))


bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24, location=C)
cabeca = bpy.context.object
cabeca.name = "cabeca"
cabeca.scale = R
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for v in cabeca.data.vertices:
    rel = v.co - C
    w = rel.z / R.z            # -1 queixo .. 1 topo
    frente = -rel.y / R.y      # 1 = rosto
    x, z = rel.x, v.co.z
    if w < 0:                  # mandíbula mais quadrada e larga
        rel.x *= 1.0 + 0.10 * (-w) * (1 if frente > -0.2 else 0.4)
    if frente > 0.55:          # rosto mais plano
        rel.y *= 0.94
    if rel.y > 0 and w > -0.3:  # crânio mais redondo atrás
        rel.y *= 1.06
    if rel.y > 0 and w < -0.5:  # nuca afina para o pescoço
        rel.y *= 0.82
    if frente > 0.2:
        fr = min(1.0, (frente - 0.2) / 0.5)
        empurra = 0.0
        empurra += 0.024 * gauss(x, z, 0, 1.661, 0.0125, 0.017)          # ponta do nariz
        empurra += 0.013 * gauss(x, z, 0, 1.684, 0.008, 0.016)           # dorso do nariz
        empurra += 0.008 * (gauss(x, z, 0.018, 1.656, 0.009, 0.008) + gauss(x, z, -0.018, 1.656, 0.009, 0.008))  # asas
        empurra += 0.008 * gauss(x, z, 0, 1.718, 0.045, 0.009)           # sobrancelha
        empurra -= 0.010 * (gauss(x, z, 0.031, 1.695, 0.016, 0.011) + gauss(x, z, -0.031, 1.695, 0.016, 0.011))  # órbitas
        empurra += 0.006 * (gauss(x, z, 0.05, 1.672, 0.02, 0.018) + gauss(x, z, -0.05, 1.672, 0.02, 0.018))   # maçãs
        empurra += 0.009 * gauss(x, z, 0, 1.633, 0.026, 0.009)           # lábios
        empurra -= 0.004 * gauss(x, z, 0, 1.615, 0.02, 0.006)            # sulco do queixo
        empurra += 0.014 * gauss(x, z, 0, 1.575, 0.034, 0.028)           # queixo + barba
        rel.y -= empurra * fr
    v.co = C + rel
for p in cabeca.data.polygons:
    p.use_smooth = True
cabeca.data.materials.append(M_ROSTO)
partes_cabeca.append(cabeca)


def projetar_cabeca(obj, limite_tras=0.025):
    """UV "proj", decidida por face (sem esticar entre regiões):
    - frente: projeção frontal na selfie; no cabelo, a altura é comprimida para caber na
      faixa de cachos da foto (y 30..195);
    - laterais: projeção de lado sobre um pedaço da bochecha (textura real, sem listras);
    - trás: faixa da "nuca" (cilíndrica)."""
    uv = obj.data.uv_layers.new(name="proj")
    me = obj.data
    for poly in me.polygons:
        atras = (poly.center.y - C.y) > limite_tras
        # lateral só fora da área que a foto cobre (o rosto na foto vai até |x| ≈ 7 cm)
        lado = abs(poly.normal.x) > 0.6 and abs(poly.center.x) > 0.064 and not atras
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            no_cabelo = vi in CABELO and co.z > 1.735
            if atras:
                ang = math.atan2(co.x - C.x, max(0.001, co.y - C.y))  # -pi/2..pi/2 visto de trás
                px = 865 + ang / (math.pi / 2) * 140
                py = 20 + (1.83 - co.z) / 0.28 * 960 if not no_cabelo else 20 + (TOPO_CABELO - co.z) / (TOPO_CABELO - 1.70) * 280
            elif no_cabelo:
                px = CX_FOTO + co.x / ESC * 0.92
                py = 195 - (co.z - 1.735) / (TOPO_CABELO - 1.735) * 165
            elif lado:
                base_x = 296 if co.x < 0 else 486     # bochecha esquerda/direita da foto
                px = base_x + (co.y - C.y + 0.06) / 0.12 * 30
                # só a faixa de bochecha sem feições (abaixo do olho, acima da barba), repetida na altura
                py = 318 + ((co.z - 1.5) / 0.05 * 40) % 40
            else:
                px = CX_FOTO + co.x / ESC
                py = CY_FOTO - (co.z - OLHO_Z) / ESC
            uv.data[li].uv = (px / 1024.0, 1.0 - py / 1024.0)


# Cabelo: a própria cabeça ganha o volume acima da linha do cabelo (sem vão nem emenda):
# fino nas laterais e na nuca (degradê), alto no topo (high-top de cachos).
def suave(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def linha_do_cabelo(co):
    rel = co - C
    frente = min(1.0, max(0.0, -rel.y / R.y))
    tras = min(1.0, max(0.0, rel.y / R.y))
    return (1.742 * frente + 1.700 * (1 - frente)) - 0.085 * tras


bm = bmesh.new()
bm.from_mesh(cabeca.data)
bm.normal_update()
CABELO = set()
for v in bm.verts:
    lim = linha_do_cabelo(v.co)
    if v.co.z < lim - 0.01:
        continue
    entrada = suave(lim - 0.01, lim + 0.012, v.co.z)          # nasce do couro cabeludo sem degrau
    alto = suave(1.73, 1.79, v.co.z)
    grossura = entrada * (0.004 + 0.04 * alto)
    rel_x = v.co.x - C.x
    v.co += v.normal * grossura
    v.co.x += rel_x * 0.16 * suave(1.75, 1.79, v.co.z)        # topo mais largo e "achatado"
    v.co.z += 0.012 * suave(1.765, 1.79, v.co.z - grossura)
    if grossura > 0.015:  # cachos
        v.co += Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-0.3, 1))) * 0.007
    CABELO.add(v.index)
bm.to_mesh(cabeca.data)
bm.free()
TOPO_CABELO = max(v.co.z for v in cabeca.data.vertices)
for u in list(cabeca.data.uv_layers):
    cabeca.data.uv_layers.remove(u)
projetar_cabeca(cabeca)
print("CABECA verts", len(cabeca.data.vertices), "cabelo", len(CABELO), "topo", round(TOPO_CABELO, 3))

# orelhas
for s in (1, -1):
    o = elipsoide(f"orelha_{s}", (s * 0.079, 0.0, 1.668), (0.012, 0.024, 0.033), M_PELE, partes_cabeca, 8, 6)
    o.rotation_euler.z = s * 0.25

# ================================================================ CORPO
hips, sp1, sp2, pesc = junta("Hips"), junta("Spine1"), junta("Spine2"), junta("Neck")

# pescoço (pele, por baixo da gola)
tubo("pescoco", [((0, 0.004, 1.47), 0.064, 0.064), ((0, -0.002, 1.6), 0.058, 0.06)], M_PELE_CORPO, partes_corpo, 12, (False, False))

# tronco (gi): pélvis → cintura → peito → ombros
tubo("tronco", [
    ((0, 0.0, 0.86), 0.155, 0.11),
    ((0, 0.0, 0.97), 0.168, 0.12),
    ((0, 0.0, 1.08), 0.152, 0.108),
    ((0, -0.004, 1.2), 0.172, 0.118),
    ((0, -0.012, 1.31), 0.198, 0.128),
    ((0, -0.006, 1.39), 0.212, 0.12),
    ((0, 0.004, 1.455), 0.165, 0.098),
    ((0, 0.004, 1.49), 0.08, 0.07),
], M_TECIDO, partes_corpo, 14)

# deltoides
for s in (1, -1):
    elipsoide(f"deltoide_{s}", (s * 0.2, 0.0, 1.405), (0.085, 0.075, 0.072), M_TECIDO, partes_corpo, 10, 7)

# lapelas do gi (V cruzado no peito) e gola/capuz
for s in (1, -1):
    faixa_superficie(f"lapela_{s}", [(s * -0.07, -0.085, 1.47), (s * -0.02, -0.128, 1.36), (s * 0.06, -0.13, 1.22),
                                     (s * 0.1, -0.12, 1.1)], 0.028, 0.006, M_TECIDO2, partes_corpo)
toro("gola", (0, 0.006, 1.515), 0.084, 0.036, M_TECIDO, partes_corpo, inclina=math.radians(-10), segmentos=(18, 6))
toro("gola2", (0, 0.01, 1.47), 0.108, 0.034, M_TECIDO, partes_corpo, inclina=math.radians(6), segmentos=(18, 6))
tubo("capuz", [((0, 0.07, 1.44), 0.115, 0.04), ((0, 0.09, 1.51), 0.105, 0.042), ((0, 0.085, 1.58), 0.085, 0.034)],
     M_TECIDO, partes_corpo, 10)

# braços: manga até o cotovelo com punho dobrado, pele, antebraço enfaixado, mão
ombro, cotovelo, pulso, dedos = junta("LeftArm"), junta("LeftForeArm"), junta("LeftHand"), junta("LeftHandIndex1")
Z = ombro.z
for s in (1, -1):
    tubo(f"manga_{s}", [((s * 0.17, 0, Z), 0.068, 0.072), ((s * 0.27, 0, Z), 0.07, 0.072),
                        ((s * 0.37, 0, Z), 0.063, 0.064), ((s * 0.44, 0, Z), 0.058, 0.06)], M_TECIDO, partes_corpo, 10,
         (False, True))
    toro(f"punho_manga_{s}", (s * 0.435, 0, Z), 0.058, 0.014, M_TECIDO2, partes_corpo, "X")
    tubo(f"cotovelo_{s}", [((s * 0.44, 0, Z), 0.048, 0.05), ((s * 0.51, 0, Z), 0.047, 0.049)], M_PELE_CORPO, partes_corpo, 10)
    tubo(f"antebraco_{s}", [((s * 0.5, 0, Z), 0.051, 0.053), ((s * 0.6, 0, Z), 0.047, 0.05), ((s * 0.69, 0, Z), 0.038, 0.042)],
         M_FAIXA, partes_corpo, 10)
    toro(f"bracadeira_{s}", (s * 0.505, 0, Z), 0.052, 0.008, M_COURO, partes_corpo, "X")
    # mão aberta (pose T): palma enfaixada, quatro dedos e polegar de pele
    tubo(f"palma_{s}", [((s * 0.69, 0, Z), 0.026, 0.043), ((s * 0.755, 0, Z - 0.004), 0.022, 0.047)], M_FAIXA, partes_corpo, 8)
    for k, dy in enumerate((-0.033, -0.011, 0.011, 0.031)):
        comp = (0.09, 0.1, 0.095, 0.075)[k]
        x0 = s * 0.752
        tubo(f"dedo_{s}_{k}", [((x0, dy, Z - 0.005), 0.0105, 0.01), ((x0 + s * comp * 0.55, dy, Z - 0.008), 0.0095, 0.0092),
                               ((x0 + s * comp, dy, Z - 0.013), 0.008, 0.008)], M_PELE_CORPO, partes_corpo, 6)
    tubo(f"polegar_{s}", [((s * 0.7, -0.035, Z - 0.008), 0.013, 0.013), ((s * 0.735, -0.065, Z - 0.012), 0.011, 0.011),
                          ((s * 0.76, -0.085, Z - 0.016), 0.009, 0.009)], M_PELE_CORPO, partes_corpo, 6)

# obi, nó e pontas
tubo("obi", [((0, 0, 0.95), 0.18, 0.135), ((0, 0, 1.03), 0.175, 0.132), ((0, 0, 1.1), 0.168, 0.126)], M_TECIDO2, partes_corpo, 16)
caixa("obi_no", (0.0, -0.142, 1.025), (0.08, 0.045, 0.07), M_TECIDO2, partes_corpo, 0.015)
caixa("obi_ponta_1", (-0.024, -0.152, 0.86), (0.045, 0.012, 0.28), M_TECIDO2, partes_corpo, 0.004, (0, math.radians(7), 0))
caixa("obi_ponta_2", (0.036, -0.15, 0.88), (0.038, 0.012, 0.24), M_TECIDO2, partes_corpo, 0.004, (0, math.radians(-10), 0))
# bolsa de kunai no quadril direito
caixa("bolsa", (-0.17, -0.04, 0.98), (0.05, 0.07, 0.09), M_COURO, partes_corpo, 0.01)
# abas do tabardo (frente e trás) em ponta
for s in (1, -1):
    aba(f"tabardo_frente_{s}", -0.143, 0.99, s * 0.006, s * 0.172, 0.72, 0.62, M_TECIDO, partes_corpo)
    aba(f"tabardo_tras_{s}", 0.141, 0.99, s * 0.006, s * 0.172, 0.7, 0.61, M_TECIDO, partes_corpo)

# alças cruzadas (couro): peito e costas; a do ombro direito segura a katana
faixa_superficie("alca_peito_1", [(-0.17, -0.07, 1.43), (-0.06, -0.135, 1.3), (0.08, -0.133, 1.16), (0.17, -0.1, 1.04)],
                 0.024, 0.006, M_COURO, partes_corpo)
faixa_superficie("alca_peito_2", [(0.17, -0.07, 1.43), (0.06, -0.137, 1.3), (-0.08, -0.135, 1.16), (-0.17, -0.1, 1.04)],
                 0.02, 0.006, M_COURO, partes_corpo)
faixa_superficie("alca_costas", [(-0.17, 0.07, 1.43), (-0.06, 0.128, 1.3), (0.08, 0.13, 1.16), (0.17, 0.1, 1.04)],
                 0.024, 0.006, M_COURO, partes_corpo)

# pernas: calça larga presa por perneiras enfaixadas, tabi
quadril_l, joelho, tornozelo = junta("LeftUpLeg"), junta("LeftLeg"), junta("LeftFoot")
for s in (1, -1):
    x = s * quadril_l.x
    tubo(f"calca_{s}", [((x, 0, 0.93), 0.1, 0.105), ((x * 1.04, 0, 0.8), 0.116, 0.116),
                        ((x * 1.08, -0.01, 0.64), 0.122, 0.116), ((x * 1.04, 0, 0.55), 0.09, 0.088),
                        ((x * 1.03, 0, 0.51), 0.072, 0.072)], M_TECIDO, partes_corpo, 12)
    tubo(f"perneira_{s}", [((x * 1.03, 0, 0.53), 0.071, 0.071), ((x * 1.03, 0.006, 0.4), 0.064, 0.068),
                           ((x * 1.03, 0, 0.22), 0.053, 0.056), ((x * 1.03, 0, 0.12), 0.05, 0.055)], M_FAIXA, partes_corpo, 10)
    for k in range(3):
        toro(f"amarra_{s}_{k}", (x * 1.03, 0, 0.48 - k * 0.15), 0.067 - k * 0.005, 0.008, M_COURO, partes_corpo,
             inclina=math.radians(9 * (-1) ** k))
    xp = x * 1.03
    # tabi: calcanhar → peito do pé → ponta, com o dedão separado
    tubo(f"pe_{s}", [((xp, 0.055, 0.055), 0.048, 0.042), ((xp, 0.0, 0.07), 0.058, 0.05), ((xp, -0.075, 0.05), 0.045, 0.05),
                     ((xp + s * 0.008, -0.13, 0.03), 0.028, 0.042), ((xp + s * 0.008, -0.155, 0.025), 0.02, 0.036)],
         M_TECIDO2, partes_corpo, 10)
    tubo(f"dedao_{s}", [((xp - s * 0.03, -0.11, 0.03), 0.022, 0.017), ((xp - s * 0.032, -0.165, 0.024), 0.018, 0.015)],
         M_TECIDO2, partes_corpo, 8)

# ================================================================ KATANA nas costas
topo = Vector((-0.2, 0.17, 1.62))
base = Vector((0.25, 0.17, 0.8))
eixo = (base - topo).normalized()
tsuba = topo + eixo * 0.26
tubo("katana_cabo", [(topo, 0.017, 0.017), (tsuba, 0.017, 0.017)], M_CABO, partes_katana, 8)
tubo("katana_kashira", [(topo - eixo * 0.012, 0.019, 0.019), (topo + eixo * 0.008, 0.019, 0.019)], M_METAL, partes_katana, 8)
tubo("katana_tsuba", [(tsuba - eixo * 0.006, 0.044, 0.044), (tsuba + eixo * 0.006, 0.044, 0.044)], M_METAL, partes_katana, 12)
tubo("katana_bainha", [(tsuba + eixo * 0.006, 0.021, 0.016), (base - eixo * 0.02, 0.017, 0.013), (base, 0.012, 0.01)],
     M_BAINHA, partes_katana, 8)
for k in range(2):  # voltas do cordão (sageo) na bainha
    p = tsuba + eixo * (0.06 + k * 0.03)
    tubo(f"sageo_{k}", [(p - eixo * 0.006, 0.024, 0.02), (p + eixo * 0.006, 0.024, 0.02)], M_CABO, partes_katana, 8)

# ================================================================ BAKE do corpo (atlas)
bpy.ops.object.select_all(action="DESELECT")
for o in partes_corpo:
    o.select_set(True)
bpy.context.view_layer.objects.active = partes_corpo[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
corpo = bpy.context.object
corpo.name = "corpo"
uv_atlas = corpo.data.uv_layers.new(name="atlas")
corpo.data.uv_layers.active = uv_atlas
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006)
bpy.ops.object.mode_set(mode="OBJECT")

mundo = bpy.data.worlds.new("bake")
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
mundo.node_tree.nodes["Background"].inputs[1].default_value = 1.0
cena.world = mundo
cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = 48
cena.render.bake.margin = 6


def assar(nome_imagem):
    img = bpy.data.images.new(nome_imagem, TAM_ATLAS, TAM_ATLAS)
    for slot in corpo.material_slots:
        nt = slot.material.node_tree
        alvo = nt.nodes.get("alvo_bake") or nt.nodes.new("ShaderNodeTexImage")
        alvo.name = "alvo_bake"
        alvo.image = img
        nt.nodes.active = alvo
    bpy.ops.object.select_all(action="DESELECT")
    corpo.select_set(True)
    bpy.context.view_layer.objects.active = corpo
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"DIRECT", "INDIRECT", "COLOR"}, use_clear=True)
    img.filepath_raw = os.path.join(SAIDA_ATLAS, nome_imagem + ".png")
    img.file_format = "PNG"
    img.save()
    print("ATLAS", nome_imagem)
    return img


atlas_1p = assar("pci_atlas_1p")
# variante 2P: só as cores dos tecidos mudam
for slot in corpo.material_slots:
    m = slot.material
    if m.name in CORES_2P:
        mix = next(n for n in m.node_tree.nodes if n.type == "MIX")
        ins = {s.identifier: s for s in mix.inputs}
        c = CORES_2P[m.name]
        ins["A_Color"].default_value = (*c, 1)
        ins["B_Color"].default_value = (*[v * 1.4 + 0.006 for v in c], 1)
assar("pci_atlas_2p")

# troca os materiais do corpo por um só, com o atlas 1P
M_CORPO = bpy.data.materials.new("corpo")
M_CORPO.use_nodes = True
t = M_CORPO.node_tree.nodes.new("ShaderNodeTexImage")
t.image = atlas_1p
uvn = M_CORPO.node_tree.nodes.new("ShaderNodeUVMap")
uvn.uv_map = "atlas"
M_CORPO.node_tree.links.new(uvn.outputs["UV"], t.inputs["Vector"])
M_CORPO.node_tree.links.new(t.outputs["Color"], M_CORPO.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
M_CORPO.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
corpo.data.materials.clear()
corpo.data.materials.append(M_CORPO)

# ================================================================ junta tudo numa malha
# Cada parte tem uma camada UV só ("atlas" no corpo, "proj" na cabeça, nenhuma na katana);
# para juntar, todas recebem as duas camadas com o mesmo nome, nessa ordem.
for o in partes_cabeca + partes_katana + [corpo]:
    nomes = [u.name for u in o.data.uv_layers]
    for nome in ("atlas", "proj"):
        if nome not in nomes:
            o.data.uv_layers.new(name=nome)
bpy.ops.object.select_all(action="DESELECT")
for o in partes_cabeca + partes_katana + [corpo]:
    o.select_set(True)
bpy.context.view_layer.objects.active = corpo
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
pci = bpy.context.object
pci.name = "PCI_v3"
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
tri = sum(len(p.vertices) - 2 for p in pci.data.polygons)
print(f"TRIANGULOS {tri}  materiais {[m.name for m in pci.data.materials]}  uv {[u.name for u in pci.data.uv_layers]}")

# ================================================================ renders de conferência (EEVEE)
cena.render.engine = "BLENDER_EEVEE"
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.06, 1)
mundo.node_tree.nodes["Background"].inputs[1].default_value = 1.0


def luz(nome, loc, energia, tam=1.5):
    d = bpy.data.lights.new(nome, "AREA")
    d.energy = energia
    d.size = tam
    o = bpy.data.objects.new(nome, d)
    o.location = loc
    cena.collection.objects.link(o)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (Vector((0, 0, 1.2)) - Vector(loc)).to_track_quat("-Z", "Y")


luz("chave", (-1.5, -2.5, 2.6), 160)
luz("preench", (2.0, -2.0, 1.5), 50, 2.0)
luz("recorte", (0.5, 2.5, 2.4), 180)
cd = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cd)
cena.collection.objects.link(cam)
cena.camera = cam
cena.render.resolution_x = 900
cena.render.resolution_y = 1100
RENDERS = os.path.join(ROOT, "blender/renders")


def foto(nome, loc, alvo, lente):
    cd.lens = lente
    cam.location = loc
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y")
    cena.render.filepath = os.path.join(RENDERS, nome)
    bpy.ops.render.render(write_still=True)


foto("pci_v3_frente.png", (0, -5.0, 1.0), (0, 0, 0.95), 75)
foto("pci_v3_costas.png", (0, 5.0, 1.0), (0, 0, 0.95), 75)
foto("pci_v3_tres_quartos.png", (-3.0, -3.8, 1.3), (0, 0, 0.95), 70)
foto("pci_v3_rosto.png", (0.25, -1.1, 1.7), (0, 0, 1.68), 85)
foto("pci_v3_rosto_lado.png", (-1.1, -0.45, 1.7), (0, 0, 1.68), 85)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender/arquivos/pci_v3.blend"))
print("OK")
