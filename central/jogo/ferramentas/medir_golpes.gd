# Mede as animações: deslocamento do quadril (movimento de raiz) e, nos golpes,
# qual mão/pé vai mais à frente, quando (fração da animação) e a que altura.
# Uso: godot --headless --path jogo -s res://ferramentas/medir_golpes.gd [-- arquivo.glb]
extends SceneTree

const OSSOS := ["mixamorig_LeftHand", "mixamorig_RightHand", "mixamorig_LeftFoot", "mixamorig_RightFoot"]
const GOLPES := ["jab", "soco", "chute", "chute_circular", "rasteira", "gancho", "chute_voador",
	"empurrao", "arremesso", "corte", "furacao", "corte_duplo"]


func _initialize() -> void:
	var cena: Node3D = load("res://assets/personagens/pci/pci_v4.glb").instantiate()
	root.add_child(cena)
	await process_frame
	var ap: AnimationPlayer = cena.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = cena.find_child("Skeleton3D", true, false)
	var quadril := sk.find_bone("mixamorig_Hips")
	var cabeca := sk.find_bone("mixamorig_Head")
	for nome in ap.get_animation_list():
		var anim := ap.get_animation(nome)
		ap.play(nome)
		var p0 := Vector3.ZERO
		var linha := "%-15s %.2fs" % [nome, anim.length]
		var melhor := {}
		var cab_min := 9.0
		for i in 41:
			ap.seek(anim.length * i / 40.0, true)
			var q: Vector3 = sk.global_transform * sk.get_bone_global_pose(quadril).origin
			if i == 0:
				p0 = q
			cab_min = min(cab_min, (sk.global_transform * sk.get_bone_global_pose(cabeca).origin).y)
			if nome in GOLPES:
				for o in OSSOS:
					var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(o)).origin
					var rel := p.z - q.z  # à frente do quadril
					if not melhor.has(o) or rel > melhor[o][0]:
						melhor[o] = [rel, i / 40.0, p.y, q.z - p0.z, q.y - p0.y]
			if i == 40:
				linha += "  raiz fim: frente=%.2f lado=%.2f alt=%.2f  cabeça_min=%.2f" % [q.z - p0.z, q.x - p0.x, q.y - p0.y, cab_min]
		if nome in GOLPES:
			var o_max: String = OSSOS[0]
			for o in OSSOS:
				if melhor[o][0] > melhor[o_max][0]:
					o_max = o
			var m: Array = melhor[o_max]
			linha += "\n    golpe: %s a %.2f m do quadril aos %.2f (altura %.2f; quadril já avançou %.2f, subiu %.2f)" % [o_max.trim_prefix("mixamorig_"), m[0], m[1], m[2], m[3], m[4]]
		print(linha)
	quit()
