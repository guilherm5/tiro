extends Node
## Ao carregar a fase: tira a sombra de tudo que está dentro de nós marcados com o
## metadado "sem_sombra" (objetos pequenos ou distantes, onde a sombra não aparece).


func _ready() -> void:
	await get_tree().process_frame  # depois que os modelos instanciados estão prontos
	var count := 0
	var level := owner if owner else get_parent()
	for node in level.find_children("*", "Node3D", true, false):
		if node.has_meta(&"sem_sombra"):
			for geometry in node.find_children("*", "GeometryInstance3D", true, false):
				(geometry as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				count += 1
	print_verbose("sem sombra: %d malhas" % count)
