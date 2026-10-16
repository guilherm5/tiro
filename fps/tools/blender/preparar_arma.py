"""Prepara um modelo de arma baixado (glTF) para o jogo, rodando no Blender sem janela.

- junta as partes, aplica transformações, escala para o comprimento real;
- orienta o cano para -Z (frente no Godot), coronha para +Z, de pé (+Y);
- origem no meio do receptor; mede a massa de mira (ponto mais alto perto da boca) e
  a alça (ponto mais alto atrás do receptor) e grava em JSON para alinhar a mira no jogo.

Uso: blender -b --factory-startup --python preparar_arma.py -- entrada.gltf saida.glb comprimento_m
"""
import bpy, sys, json
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
src, dst, length = args[0], args[1], float(args[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(False)
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
for o in list(bpy.context.scene.objects):
    if o != obj:
        bpy.data.objects.remove(o, do_unlink=True)

def bounds(o):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return mn, mx, vs

mn, mx, vs = bounds(obj)
size = mx - mn
axis = max(range(3), key=lambda i: size[i])  # eixo mais longo = cano
print("tamanho original:", tuple(round(s, 3) for s in size), "eixo longo:", "XYZ"[axis])
# Blender: Z para cima, -Y para frente no glTF exportado vira -Z do Godot.
# Queremos: cano ao longo do eixo Y do Blender (frente = +Y Blender -> -Z Godot).
rot = Matrix.Identity(4)
if axis == 0:
    rot = Matrix.Rotation(1.5707963, 4, "Z")
elif axis == 2:
    rot = Matrix.Rotation(-1.5707963, 4, "X")
obj.data.transform(rot)
mn, mx, vs = bounds(obj)
scale = length / (mx.y - mn.y)
obj.data.transform(Matrix.Scale(scale, 4))
mn, mx, vs = bounds(obj)

# Qual ponta é a boca? A ponta mais fina (menos volume em X/Z perto da extremidade).
def thickness(end_y, sign):
    sel = [v for v in vs if sign * (v.y - end_y) >= -0.08]
    return (max(v.z for v in sel) - min(v.z for v in sel)) if sel else 99
if thickness(mx.y, 1) > thickness(mn.y, -1):
    obj.data.transform(Matrix.Rotation(3.14159265, 4, "Z"))  # boca para +Y
    mn, mx, vs = bounds(obj)
# Para cima: a coronha (traseira, -Y) é mais alta que larga; a massa fica em cima.
# Heurística: o lado com a massa de mira (pontos altos perto da boca) deve ser +Z.
front = [v for v in vs if v.y > mx.y - 0.12]
if front and (max(v.z for v in front) - (mn.z + mx.z) / 2) < ((mn.z + mx.z) / 2 - min(v.z for v in front)):
    obj.data.transform(Matrix.Rotation(3.14159265, 4, "Y"))
    mn, mx, vs = bounds(obj)

# Origem: meio do comprimento, no eixo do cano (altura média da parte da frente).
front = [v for v in vs if v.y > mx.y - 0.12]
barrel_z = sorted(v.z for v in front)[len(front) // 2]
center = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, barrel_z))
obj.data.transform(Matrix.Translation(-center))
mn, mx, vs = bounds(obj)

front = [v for v in vs if v.y > mx.y - 0.1]
front_sight = max(front, key=lambda v: v.z)
rear = [v for v in vs if -0.15 < v.y < 0.05]
rear_sight = max(rear, key=lambda v: v.z)
info = {
    "comprimento": round(mx.y - mn.y, 3),
    "boca_godot": [round(-0.0, 3), round(0.0, 3), round(-mx.y, 3)],
    "massa_godot": [round(front_sight.x, 3), round(front_sight.z, 3), round(-front_sight.y, 3)],
    "alca_godot": [round(rear_sight.x, 3), round(rear_sight.z, 3), round(-rear_sight.y, 3)],
    "limites_godot_min": [round(mn.x, 3), round(mn.z, 3), round(-mx.y, 3)],
    "limites_godot_max": [round(mx.x, 3), round(mx.z, 3), round(-mn.y, 3)],
}
print("INFO", json.dumps(info))
json.dump(info, open(dst.replace(".glb", ".json"), "w"), indent=1)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_apply=True)
