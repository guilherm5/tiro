# Calibração visual da katana na mão: vários PCIs lado a lado, cada um com uma
# rotação candidata, congelados no mesmo quadro de uma animação de espada.
# Uso (com janela): godot --path jogo -s res://ferramentas/calibrar_katana.gd -- --anim=corte --fracao=0.45 --saida=/caminho.png
extends SceneTree

const CANDIDATOS := [
	[0, 0, 90], [0, 0, -90], [90, 0, 0], [-90, 0, 0], [0, 90, 90], [0, -90, -90],
]


func _initialize() -> void:
	var anim_nome := "corte"
	var fracao := 0.45
	var saida := "/tmp/katana.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anim="):
			anim_nome = a.get_slice("=", 1)
		elif a.begins_with("--fracao="):
			fracao = float(a.get_slice("=", 1))
		elif a.begins_with("--saida="):
			saida = a.get_slice("=", 1)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED  # sem o filtro de PS2
	var cena := Node3D.new()
	root.add_child(cena)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	cena.add_child(env)
	var luz := DirectionalLight3D.new()
	cena.add_child(luz)
	luz.look_at_from_position(Vector3(2, 4, 4), Vector3.ZERO)
	for i in CANDIDATOS.size():
		var modelo: Node3D = load("res://assets/personagens/pci/pci_v4.glb").instantiate()
		modelo.position = Vector3((i % 3 - 1) * 2.2, (1 - i / 3) * 2.4, 0)
		modelo.rotation.y = PI / 2  # olhando para +X (direita da tela)
		cena.add_child(modelo)
		var sk: Skeleton3D = modelo.find_child("Skeleton3D", true, false)
		var apego := BoneAttachment3D.new()
		apego.bone_name = "mixamorig_RightHand"
		sk.add_child(apego)
		var comp := Node3D.new()
		comp.scale = Vector3.ONE * 100.0  # rig do Mixamo em escala 0,01
		apego.add_child(comp)
		var k: Node3D = load("res://assets/personagens/pci/katana.glb").instantiate()
		comp.add_child(k)
		var r: Array = CANDIDATOS[i]
		k.rotation_degrees = Vector3(r[0], r[1], r[2])
		k.position = Vector3(0, 0.08, 0.03)
		var ap: AnimationPlayer = modelo.find_child("AnimationPlayer", true, false)
		ap.play(anim_nome)
		ap.seek(ap.current_animation_length * fracao, true)
		ap.pause()
		var rot := Label3D.new()
		rot.text = "%d: %s" % [i, str(r)]
		rot.position = modelo.position + Vector3(0, 2.2, 0)
		rot.font_size = 48
		cena.add_child(rot)
	var cam := Camera3D.new()
	cena.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.2, 9.0), Vector3(0, 2.2, 0))
	cam.fov = 45
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(saida)
	print("CALIBRAÇÃO salva em ", saida)
	quit()
