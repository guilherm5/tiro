extends Node3D
## Aplica uma cor/escurecimento aos modelos filhos ao carregar (ex.: navios ao longe em
## cinza-chumbo, casas em ruínas sujas de fumaça), sem mexer no arquivo do modelo.

## Cor multiplicada sobre a cor de cada material.
@export var tint := Color(1, 1, 1)
## Se marcado, troca todos os materiais por um só, liso, da cor `tint`.
@export var flat := false


func _ready() -> void:
	var plain: StandardMaterial3D = null
	if flat:
		plain = StandardMaterial3D.new()
		plain.albedo_color = tint
		plain.roughness = 0.8
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			if plain:
				mesh_instance.set_surface_override_material(i, plain)
				continue
			var material := mesh_instance.get_active_material(i) as StandardMaterial3D
			if material:
				material = material.duplicate()
				material.albedo_color = material.albedo_color * tint
				mesh_instance.set_surface_override_material(i, material)
