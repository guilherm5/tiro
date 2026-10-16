# Dojo v2: salão de dojo à noite com jardim, luz "assada" (bake) em mapas de luz.
# Uso: ferramentas/blender -b --factory-startup --python blender/scripts/cenario_dojo.py [-- --rapido]
#
# Técnica de PS2: a iluminação (lanternas, painéis de papel, lua) é calculada no Cycles e
# gravada num mapa de luz por objeto (segunda UV). Na Godot, cada superfície mostra
# textura (UV1, repetida) x mapa de luz (UV2), sem luz em tempo real (barato na Iris Xe).
#
# Saída: jogo/assets/cenarios/dojo/dojo.glb, luz_<objeto>.png, texturas usadas e
#        dojo_materiais.json (qual textura e qual mapa de luz cada superfície usa).
import json
import math
import os
import shutil
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.expanduser("~/Documentos/central")
TEX = os.path.join(ROOT, "texturas")
SAIDA = os.path.join(ROOT, "jogo/assets/cenarios/dojo")
os.makedirs(SAIDA, exist_ok=True)
RAPIDO = "--rapido" in sys.argv
AMOSTRAS = 24 if RAPIDO else 128

bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene

# ---------------------------------------------------------------- materiais
# nome -> (arquivo de cor, metros por repetição, tinta RGB)
TEXTURAS = {
    "piso": ("ambientcg/WoodFloor051/WoodFloor051_1K-JPG_Color.jpg", 2.0, (0.55, 0.46, 0.4)),
    "tatame": ("ambientcg/Wicker008A/Wicker008A_1K-JPG_Color.jpg", 0.9, (0.74, 0.76, 0.52)),
    "tabua": ("ambientcg/Planks037A/Planks037A_1K-JPG_Color.jpg", 1.6, (0.8, 0.72, 0.66)),
    "madeira": ("ambientcg/Wood051/Wood051_1K-JPG_Color.jpg", 1.2, (0.9, 0.8, 0.74)),
    "reboco": ("ambientcg/Plaster001/Plaster001_1K-JPG_Color.jpg", 2.0, (0.86, 0.76, 0.6)),
    "pedra": ("ambientcg/PavingStones138/PavingStones138_1K-JPG_Color.jpg", 1.4, (0.7, 0.72, 0.75)),
    "estandarte_budo": ("gerado/estandarte_budo.png", 0, (1, 1, 1)),
    "estandarte_shinobi": ("gerado/estandarte_shinobi.png", 0, (1, 1, 1)),
    "estandarte_tamashii": ("gerado/estandarte_tamashii.png", 0, (1, 1, 1)),
    "estandarte_shin": ("gerado/estandarte_shin.png", 0, (1, 1, 1)),
}
CORES = {  # materiais sem textura (cor lisa)
    "borda": (0.035, 0.04, 0.03), "pele_taiko": (0.75, 0.68, 0.52), "corda": (0.08, 0.03, 0.02),
    "bambu": (0.18, 0.32, 0.1), "folhas": (0.03, 0.08, 0.04), "bokken": (0.55, 0.42, 0.28),
    "laca": (0.25, 0.04, 0.03),
}
EMISSIVOS = {  # nome -> (arquivo ou None, cor, força); não entram no bake, são "acesos" na Godot
    "papel": ("gerado/shoji.png", (1.0, 0.82, 0.55), 2.2),
    "lanterna": (None, (1.0, 0.55, 0.22), 6.0),
    "ceu": ("gerado/ceu.png", (1, 1, 1), 1.0),
    "lua": ("gerado/lua.png", (1, 1, 1), 1.0),
}
materiais = {}


def material(nome):
    if nome in materiais:
        return materiais[nome]
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    if nome in TEXTURAS or (nome in EMISSIVOS and EMISSIVOS[nome][0]):
        arq = TEXTURAS[nome][0] if nome in TEXTURAS else EMISSIVOS[nome][0]
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(TEX, arq), check_existing=True)
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "UV1"
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        tinta = nt.nodes.new("ShaderNodeMix")
        tinta.data_type = "RGBA"
        tinta.blend_type = "MULTIPLY"
        ins = {s.identifier: s for s in tinta.inputs}
        ins["Factor_Float"].default_value = 1.0
        nt.links.new(tex.outputs["Color"], ins["A_Color"])
        cor = TEXTURAS[nome][2] if nome in TEXTURAS else EMISSIVOS[nome][1]
        ins["B_Color"].default_value = (*cor, 1)
        saida = {s.identifier: s for s in tinta.outputs}["Result_Color"]
        nt.links.new(saida, bsdf.inputs["Base Color"])
        if nome in EMISSIVOS:
            nt.links.new(saida, bsdf.inputs["Emission Color"])
    else:
        cor = CORES.get(nome, EMISSIVOS.get(nome, (None, (0.5, 0.5, 0.5)))[1])
        bsdf.inputs["Base Color"].default_value = (*cor, 1)
        if nome in EMISSIVOS:
            bsdf.inputs["Emission Color"].default_value = (*cor, 1)
    if nome in EMISSIVOS:
        bsdf.inputs["Emission Strength"].default_value = EMISSIVOS[nome][2]
    materiais[nome] = m
    return m


# ---------------------------------------------------------------- geometria
grupos = {}   # nome do objeto final -> lista de objetos a juntar


def guardar(o, grupo, nome_mat):
    o.data.materials.clear()
    o.data.materials.append(material(nome_mat))
    grupos.setdefault(grupo, []).append(o)
    return o


def caixa(grupo, mat, centro, tamanho, rot_z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centro, rotation=(0, 0, rot_z))
    o = bpy.context.object
    o.scale = tamanho
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return guardar(o, grupo, mat)


def cilindro(grupo, mat, centro, raio, altura, lados=16, deitado=None):
    rot = (0, 0, 0)
    if deitado == "x":
        rot = (0, math.pi / 2, 0)
    elif deitado == "y":
        rot = (math.pi / 2, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=lados, radius=raio, depth=altura, location=centro, rotation=rot)
    o = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for p in o.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    return guardar(o, grupo, mat)


def plano(grupo, mat, centro, largura, altura, rot_z=0.0, vertical=True):
    bpy.ops.mesh.primitive_plane_add(size=1, location=centro,
                                     rotation=(math.pi / 2 if vertical else 0, 0, rot_z))
    o = bpy.context.object
    o.scale = (largura, altura, 1)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return guardar(o, grupo, mat)


L = 7.0           # meia-largura do salão
ALTURA = 4.6
# piso e arena
plano("piso", "piso", (0, 0, 0), 2 * L, 2 * L, vertical=False)
cilindro("borda", "borda", (0, 0, 0.012), 4.95, 0.024, 48)
cilindro("tatame", "tatame", (0, 0, 0.022), 4.8, 0.03, 48)

# paredes: rodapé de tábuas, reboco, painéis de papel (shoji) com treliça
ABERTURA = 2.6    # meia-largura da abertura para o jardim (parede sul, -Y)
for lado in range(4):
    ang = lado * math.pi / 2
    fora = Vector((math.sin(ang), -math.cos(ang), 0))       # 0: sul (-Y), 1: leste (+X)...
    ao_longo = Vector((math.cos(ang), math.sin(ang), 0))
    sul = lado == 0
    segmentos = [(-L, -ABERTURA), (ABERTURA, L)] if sul else [(-L, L)]
    for a, b in segmentos:
        meio = (a + b) / 2
        comp = b - a
        c = fora * (L - 0.05) + ao_longo * meio
        caixa("paredes_tabua", "tabua", c + Vector((0, 0, 0.5)), (comp, 0.1, 1.0), ang)
        caixa("paredes_reboco", "reboco", c + fora * 0.03 + Vector((0, 0, 2.8)), (comp, 0.06, 3.6), ang)
    if sul:  # verga em cima da abertura
        caixa("paredes_reboco", "reboco", fora * (L - 0.02) + Vector((0, 0, 3.9)), (2 * ABERTURA, 0.08, 1.4), ang)
        caixa("madeira", "madeira", fora * (L - 0.12) + Vector((0, 0, 3.25)), (2 * ABERTURA + 0.3, 0.22, 0.2), ang)
    # painéis de papel entre os pilares (leste e oeste ficam com os estandartes no meio)
    for k in range(-3, 4):
        x = k * 1.95
        if sul and abs(x) < ABERTURA + 0.8:
            continue
        if lado in (1, 3) and abs(x) < 2.2:
            continue
        base = fora * (L - 0.11) + ao_longo * x
        plano("papel", "papel", base + Vector((0, 0, 2.25)), 1.55, 2.2, ang)
        for q in range(5):  # treliça horizontal
            caixa("madeira", "madeira", base - fora * 0.015 + Vector((0, 0, 1.15 + q * 0.55)), (1.6, 0.04, 0.035), ang)
        for q in range(4):  # treliça vertical
            caixa("madeira", "madeira", base - fora * 0.015 + ao_longo * (-0.775 + q * 0.5167) + Vector((0, 0, 2.25)), (0.035, 0.04, 2.2), ang)

# pilares e vigas
for i in range(-2, 3):
    for lado in range(4):
        ang = lado * math.pi / 2
        fora = Vector((math.sin(ang), -math.cos(ang), 0))
        ao_longo = Vector((math.cos(ang), math.sin(ang), 0))
        x = i * 3.35
        if lado == 0 and abs(x) < 0.1:
            for s in (-1, 1):
                caixa("madeira", "madeira", fora * (L - 0.2) + ao_longo * s * (ABERTURA + 0.15) + Vector((0, 0, ALTURA / 2)), (0.32, 0.32, ALTURA), ang)
            continue
        caixa("madeira", "madeira", fora * (L - 0.2) + ao_longo * x + Vector((0, 0, ALTURA / 2)), (0.32, 0.32, ALTURA), ang)
for i in range(-2, 3):
    caixa("madeira", "madeira", (i * 3.35, 0, ALTURA - 0.15), (0.26, 2 * L, 0.3))
    caixa("madeira", "madeira", (0, i * 3.35, ALTURA - 0.4), (2 * L, 0.22, 0.24))
plano("teto", "tabua", (0, 0, ALTURA), 2 * L, 2 * L, vertical=False)

# lanternas de papel penduradas (luz quente)
POS_LANTERNAS = [(-3.4, -3.4), (3.4, -3.4), (-3.4, 3.4), (3.4, 3.4)]
for (x, y) in POS_LANTERNAS:
    cilindro("lanternas", "lanterna", (x, y, 3.35), 0.22, 0.5, 12)
    cilindro("madeira", "madeira", (x, y, 3.62), 0.2, 0.05, 12)
    cilindro("madeira", "madeira", (x, y, 3.08), 0.2, 0.05, 12)
    caixa("madeira", "madeira", (x, y, 3.95), (0.02, 0.02, 0.62))
    luz = bpy.data.lights.new("lanterna", "POINT")
    luz.energy = 220
    luz.color = (1.0, 0.62, 0.32)
    luz.shadow_soft_size = 0.3
    lo = bpy.data.objects.new("luz_lanterna", luz)
    lo.location = (x, y, 3.35)
    cena.collection.objects.link(lo)

# estandartes (kakejiku) nas paredes leste e oeste
for lado, nomes in ((1, ("estandarte_budo", "estandarte_shinobi")), (3, ("estandarte_tamashii", "estandarte_shin"))):
    ang = lado * math.pi / 2
    fora = Vector((math.sin(ang), -math.cos(ang), 0))
    ao_longo = Vector((math.cos(ang), math.sin(ang), 0))
    for k, nome in enumerate(nomes):
        pos = fora * (L - 0.14) + ao_longo * (-0.9 + k * 1.8)
        plano("estandartes", nome, pos + Vector((0, 0, 2.45)), 0.72, 2.16, ang)
        caixa("madeira", "madeira", pos - fora * 0.01 + Vector((0, 0, 3.56)), (0.86, 0.04, 0.04), ang)

# suporte de armas com bokken (parede oeste, perto do canto norte)
for s in (-1, 1):
    caixa("objetos", "madeira", (-6.55, 4.4 + s * 0.7, 0.8), (0.08, 0.08, 1.6))
for q in range(3):
    caixa("objetos", "madeira", (-6.55, 4.4, 0.55 + q * 0.45), (0.06, 1.55, 0.05))
    for b in range(3):
        caixa("objetos", "bokken", (-6.48, 4.0 + b * 0.4, 0.6 + q * 0.45), (0.03, 0.03, 0.9) if False else (0.035, 0.035, 0.035))
for b in range(4):
    caixa("objetos", "bokken", (-6.45, 3.95 + b * 0.3, 0.75), (0.035, 0.035, 1.2))
    caixa("objetos", "corda", (-6.45, 3.95 + b * 0.3, 0.32), (0.05, 0.05, 0.25))

# taiko em pé no suporte (canto nordeste)
cilindro("objetos", "laca", (5.4, 5.0, 0.9), 0.5, 0.65, 20, "x")
for s in (-1, 1):
    cilindro("objetos", "pele_taiko", (5.4 + s * 0.33, 5.0, 0.9), 0.46, 0.02, 20, "x")
    caixa("objetos", "madeira", (5.4 + s * 0.38, 5.0, 0.4), (0.08, 0.6, 0.08))
caixa("objetos", "madeira", (5.4, 5.0, 0.12), (0.9, 0.7, 0.08))

# jardim visto pela abertura (sul): varanda, pedras, lanterna de pedra, bambus, cerca, céu e lua
caixa("jardim", "tabua", (0, -8.0, -0.08), (2 * ABERTURA + 1.5, 2.0, 0.16))
plano("jardim", "pedra", (0, -14.5, -0.25), 30, 13, vertical=False)
for k, h in enumerate((0.35, 0.18, 0.5, 0.22, 0.4)):  # base da lanterna de pedra (toro)
    pass
cilindro("jardim", "pedra", (2.6, -11.5, 0.3), 0.18, 1.1, 8)
caixa("jardim", "pedra", (2.6, -11.5, 0.95), (0.55, 0.55, 0.12))
caixa("jardim", "pedra", (2.6, -11.5, 1.2), (0.38, 0.38, 0.38))
caixa("jardim", "pedra", (2.6, -11.5, 1.45), (0.7, 0.7, 0.1))
luz = bpy.data.lights.new("toro", "POINT")
luz.energy = 120
luz.color = (1.0, 0.6, 0.3)
lo = bpy.data.objects.new("luz_toro", luz)
lo.location = (2.6, -11.5, 1.2)
cena.collection.objects.link(lo)
caixa("lanternas", "lanterna", (2.6, -11.5, 1.2), (0.2, 0.2, 0.2))
for k in range(9):
    x = -7.5 + (k % 3) * 0.7 + (k // 3) * 0.25
    y = -12.0 - (k // 3) * 0.9
    cilindro("jardim", "bambu", (x, y, 2.6), 0.07, 5.6, 8)
for k in range(6):
    x = -11 + k * 4.4
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.6, radius2=0, depth=5.0, location=(x, -18.5, 2.3))
    guardar(bpy.context.object, "jardim", "folhas")
caixa("jardim", "tabua", (0, -20.5, 1.0), (30, 0.2, 2.5))
# céu: meio cilindro do lado sul + lua
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=26, depth=30, location=(0, 0, 8))
ceu = bpy.context.object
bm = bmesh.new()
bm.from_mesh(ceu.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y > -2 or len(f.verts) != 4], context="FACES")
bmesh.ops.reverse_faces(bm, faces=bm.faces)
bm.to_mesh(ceu.data)
bm.free()
guardar(ceu, "ceu", "ceu")
plano("lua", "lua", (-5.0, -24.5, 11.0), 5.0, 5.0, 0.0)
sol = bpy.data.lights.new("lua", "SUN")
sol.energy = 0.9
sol.color = (0.62, 0.7, 1.0)
sol.angle = math.radians(2)
so = bpy.data.objects.new("luz_lua", sol)
so.rotation_euler = (math.radians(55), 0, math.radians(-12))  # vem do sul, de cima, pela abertura
cena.collection.objects.link(so)

mundo = bpy.data.worlds.new("noite")
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.025, 0.05, 1)
mundo.node_tree.nodes["Background"].inputs[1].default_value = 0.6
cena.world = mundo


# ---------------------------------------------------------------- junta, UVs e bake
def uv_caixa(o, nome_uv="UV1"):
    """UV1 repetida em metros: cada face projeta no eixo mais perpendicular a ela."""
    uv = o.data.uv_layers.new(name=nome_uv)
    for poly in o.data.polygons:
        n = poly.normal
        eixo = max(range(3), key=lambda i: abs(n[i]))
        mat = poly.material_index
        tam = 1.0
        nome_m = o.data.materials[mat].name if o.data.materials else ""
        if nome_m in TEXTURAS and TEXTURAS[nome_m][1] > 0:
            tam = TEXTURAS[nome_m][1]
        for li in poly.loop_indices:
            co = o.data.vertices[o.data.loops[li].vertex_index].co
            if eixo == 0:
                u, v = co.y, co.z
            elif eixo == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            uv.data[li].uv = (u / tam, v / tam)


def tirar_ruido(img, raio=2):
    """Mapa de luz é suave por natureza: um desfoque gaussiano separável tira o granulado
    do path tracing sem precisar de mais amostras. Pixels vazios (fora das ilhas) não entram."""
    import numpy as np
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    peso = (px[..., 3:4] > 0).astype(np.float32)
    x = np.arange(-3 * raio, 3 * raio + 1)
    k = np.exp(-(x ** 2) / (2 * raio * raio))
    k /= k.sum()

    def borra(a):
        for eixo in (0, 1):
            a = np.apply_along_axis(lambda v: np.convolve(v, k, mode="same"), eixo, a)
        return a

    soma = borra(px[..., :3] * peso)
    pb = borra(peso)
    rgb = np.where(pb > 1e-4, soma / np.maximum(pb, 1e-4), px[..., :3])
    px[..., :3] = rgb
    img.pixels[:] = px.ravel()


objetos_finais = {}
for grupo, lista in grupos.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in lista:
        o.select_set(True)
    bpy.context.view_layer.objects.active = lista[0]
    if len(lista) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = grupo
    for u in list(o.data.uv_layers):
        if u.name != "UVMap":
            continue
        # planos de estandarte, céu e lua usam a UV original (a imagem inteira na face)
        if grupo in ("estandartes", "lua", "ceu", "papel"):
            u.name = "UV1"
        else:
            o.data.uv_layers.remove(u)
    if "UV1" not in o.data.uv_layers:
        uv_caixa(o)
    objetos_finais[grupo] = o

NAO_ASSAR = {"papel", "lanternas", "ceu", "lua"}
TAMANHO_LUZ = {"piso": 2048, "madeira": 2048, "jardim": 1024, "paredes_reboco": 1024, "paredes_tabua": 1024,
               "teto": 1024, "tatame": 1024, "objetos": 512, "estandartes": 512, "borda": 512}
cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = AMOSTRAS
cena.render.bake.margin = 8
mapa = {"objetos": {}}
for grupo, o in objetos_finais.items():
    entrada = {"materiais": [m.name for m in o.data.materials]}
    if grupo not in NAO_ASSAR:
        luz_uv = o.data.uv_layers.new(name="luz")
        o.data.uv_layers.active = luz_uv
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
        bpy.ops.object.mode_set(mode="OBJECT")
        tam = TAMANHO_LUZ.get(grupo, 1024) // (2 if RAPIDO else 1)
        img = bpy.data.images.new("luz_" + grupo, tam, tam)
        for m in o.data.materials:
            nt = m.node_tree
            alvo = nt.nodes.get("alvo") or nt.nodes.new("ShaderNodeTexImage")
            alvo.name = "alvo"
            alvo.image = img
            nt.nodes.active = alvo
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"DIRECT", "INDIRECT"}, use_clear=True)
        tirar_ruido(img, raio=max(2, tam // 384))
        img.filepath_raw = os.path.join(SAIDA, "luz_%s.png" % grupo)
        img.file_format = "PNG"
        img.save()
        entrada["luz"] = "luz_%s.png" % grupo
        print("BAKE", grupo, tam)
    mapa["objetos"][grupo] = entrada

# texturas usadas, copiadas para dentro do projeto do jogo
mapa["texturas"] = {}
for nome, (arq, tam, tinta) in list(TEXTURAS.items()) + [(k, (v[0], 0, v[1])) for k, v in EMISSIVOS.items() if v[0]]:
    destino = nome + os.path.splitext(arq)[1]
    shutil.copy(os.path.join(TEX, arq), os.path.join(SAIDA, destino))
    mapa["texturas"][nome] = {"arquivo": destino, "tinta": list(tinta)}
mapa["cores"] = {k: list(v) for k, v in CORES.items()}
mapa["emissivos"] = {k: {"cor": list(v[1]), "forca": v[2]} for k, v in EMISSIVOS.items()}
mapa["lanternas"] = [list(p) + [3.35] for p in POS_LANTERNAS] + [[2.6, -11.5, 1.2]]
json.dump(mapa, open(os.path.join(SAIDA, "dojo_materiais.json"), "w"), indent=1, ensure_ascii=False)

# exporta só a geometria (os materiais são montados na Godot a partir do json)
for o in bpy.data.objects:
    o.select_set(o.type == "MESH")
bpy.ops.export_scene.gltf(filepath=os.path.join(SAIDA, "dojo.glb"), export_format="GLB", use_selection=True,
                          export_materials="PLACEHOLDER", export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender/arquivos/dojo_v2.blend"))
print("OK", len(objetos_finais), "objetos")
