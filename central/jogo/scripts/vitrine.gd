# Vitrine de personagem: mostra o modelo girando com luz de três pontos.
# Para gerar imagens sem ninguém olhar a tela:
#   godot --path jogo -- --captura=/caminho/prefixo
# salva prefixo_frente.png, prefixo_tres_quartos.png e prefixo_costas.png e fecha.
extends Node3D

const MODELO := preload("res://assets/personagens/pci/pci_v5.glb")

var personagem: Node3D


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	personagem = MODELO.instantiate()
	add_child(personagem)

	_luz(Vector3(-2, 3, 3), 1.1, true)    # principal
	_luz(Vector3(3, 1.5, 2), 0.25, false)  # preenchimento
	_luz(Vector3(0.5, 2.5, -3), 1.2, false)  # contra-luz, recorta a silhueta preta

	var cam := Camera3D.new()
	cam.fov = 32
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.05, 4.6), Vector3(0, 0.93, 0))

	var captura := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captura="):
			captura = arg.trim_prefix("--captura=")
	if captura != "":
		await _capturar(captura)
		get_tree().quit()


func _luz(pos: Vector3, energia: float, sombra: bool) -> void:
	var l := DirectionalLight3D.new()
	l.light_energy = energia
	l.shadow_enabled = sombra
	add_child(l)
	l.look_at_from_position(pos, Vector3(0, 1, 0))


func _capturar(prefixo: String) -> void:
	for vista in [["frente", 0.0], ["tres_quartos", -35.0], ["costas", 180.0]]:
		personagem.rotation_degrees.y = vista[1]
		for i in 10:  # espera a GPU assentar sombras e texturas
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [prefixo, vista[0]])
		print("CAPTURA ", prefixo, "_", vista[0], ".png")


func _process(delta: float) -> void:
	if OS.get_cmdline_user_args().is_empty():
		personagem.rotate_y(delta * 0.6)
