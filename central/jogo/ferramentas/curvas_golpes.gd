# Imprime, para cada golpe, a curva do osso que bate ao longo da animação:
# distância horizontal ao quadril (m) e altura (m), em 20 amostras.
# Uso: godot --headless --path jogo -s res://ferramentas/curvas_golpes.gd
extends SceneTree

const GOLPES := {
	"jab": ["LeftHand"], "soco": ["RightHand"], "chute": ["LeftFoot"], "chute_circular": ["RightFoot"],
	"rasteira": ["RightFoot", "LeftFoot"], "gancho": ["LeftHand", "RightHand"],
	"chute_voador": ["LeftFoot", "RightFoot"], "furacao": ["LeftFoot", "RightFoot"],
	"corte": ["RightHand"], "corte_duplo": ["RightHand"], "empurrao": ["LeftHand", "RightHand"],
	"arremesso": ["RightHand"],
}


func _initialize() -> void:
	var cena: Node3D = load("res://assets/personagens/pci/pci_v4.glb").instantiate()
	root.add_child(cena)
	await process_frame
	var ap: AnimationPlayer = cena.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = cena.find_child("Skeleton3D", true, false)
	var quadril := sk.find_bone("mixamorig_Hips")
	for nome in GOLPES:
		var anim := ap.get_animation(nome)
		ap.play(nome)
		for osso in GOLPES[nome]:
			var idx := sk.find_bone("mixamorig_" + osso)
			var dist := []
			var alt := []
			for i in 21:
				ap.seek(anim.length * i / 20.0, true)
				var q: Vector3 = sk.global_transform * sk.get_bone_global_pose(quadril).origin
				var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(idx).origin
				dist.append("%3d" % int(Vector2(p.x - q.x, p.z - q.z).length() * 100))
				alt.append("%3d" % int(p.y * 100))
			print("%-15s %-9s dist(cm) %s" % [nome, osso, " ".join(dist)])
			print("%-15s %-9s alt (cm) %s" % ["", "", " ".join(alt)])
	print("fração:                    ", " ".join(range(0, 105, 5).map(func(v): return "%3d" % v)))
	quit()
