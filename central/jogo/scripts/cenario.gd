# Cenário com luz assada: carrega o .glb exportado do Blender e monta os materiais a partir
# de <pasta>/<nome>_materiais.json (textura de cada material + mapa de luz de cada objeto).
# Ver blender/scripts/cenario_dojo.py.
class_name Cenario
extends Node3D

const SHADER_ASSADO := preload("res://shaders/luz_assada.gdshader")
const SHADER_EMISSIVO := preload("res://shaders/emissivo.gdshader")

var dados: Dictionary
var pasta := ""


func carregar(pasta_cenario: String, nome: String) -> void:
	pasta = pasta_cenario
	dados = JSON.parse_string(FileAccess.get_file_as_string(pasta.path_join(nome + "_materiais.json")))
	var cena: Node3D = load(pasta.path_join(nome + ".glb")).instantiate()
	add_child(cena)
	for mi in cena.find_children("*", "MeshInstance3D", true, false):
		_montar(mi as MeshInstance3D)


# Posições das lanternas, já em coordenadas da Godot (Y para cima).
func lanternas() -> Array:
	var r := []
	for p in dados.get("lanternas", []):
		r.append(Vector3(p[0], p[2], -p[1]))
	return r


func _montar(mi: MeshInstance3D) -> void:
	var obj := String(mi.name).get_slice(".", 0)
	var info: Dictionary = dados["objetos"].get(obj, {})
	var mapa_luz: Texture2D = null
	if info.has("luz"):
		mapa_luz = load(pasta.path_join(info["luz"]))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mi.mesh.get_surface_count():
		# o .glb vem com materiais sem nome; a ordem das superfícies é a dos materiais no json
		var nome_mat := ""
		var mat_orig := mi.mesh.surface_get_material(i)
		if mat_orig and mat_orig.resource_name != "":
			nome_mat = mat_orig.resource_name
		elif info.has("materiais") and i < info["materiais"].size():
			nome_mat = info["materiais"][i]
		mi.set_surface_override_material(i, _material(nome_mat, mapa_luz))


func _material(nome: String, mapa_luz: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var tex_info: Dictionary = dados["texturas"].get(nome, {})
	if dados["emissivos"].has(nome):
		var e: Dictionary = dados["emissivos"][nome]
		m.shader = SHADER_EMISSIVO
		var c: Array = e["cor"]
		m.set_shader_parameter("cor", Vector3(c[0], c[1], c[2]))
		m.set_shader_parameter("forca", {"papel": 0.85, "lanterna": 1.0}.get(nome, 1.0))
		if not tex_info.is_empty():
			m.set_shader_parameter("textura", load(pasta.path_join(tex_info["arquivo"])))
			m.set_shader_parameter("usa_textura", true)
		m.set_shader_parameter("transparente", nome == "lua")
		if nome == "lua":
			m.render_priority = 1
		return m
	m.shader = SHADER_ASSADO
	if mapa_luz:
		m.set_shader_parameter("luz", mapa_luz)
	if not tex_info.is_empty():
		m.set_shader_parameter("textura", load(pasta.path_join(tex_info["arquivo"])))
		var t: Array = tex_info["tinta"]
		m.set_shader_parameter("tinta", Vector3(t[0], t[1], t[2]))
	else:
		var c: Array = dados["cores"].get(nome, [0.5, 0.5, 0.5])
		m.set_shader_parameter("usa_textura", false)
		m.set_shader_parameter("cor_lisa", Vector3(c[0], c[1], c[2]))
	return m
