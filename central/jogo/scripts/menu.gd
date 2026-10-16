# Tela de título e menu principal. O PCI fica de fundo, em 3D, na pose de luta.
extends Node3D

const OPCOES := ["VS CPU", "2 JOGADORES", "TREINO", "DEMONSTRAÇÃO", "DIFICULDADE", "MÚSICA", "FILTRO PS2", "GOLPES", "SAIR"]
const SETAS := {"f": "→", "b": "←", "u": "↑", "d": "↓", "df": "↘", "db": "↙", "uf": "↗", "ub": "↖",
	"qcf": "↓↘→", "qcb": "↓↙←", "dp": "→↓↘", "ar": "no ar:"}

var _opcao := 0
var _rotulos: Array = []
var _painel_golpes: Label
var _modelo: Node3D
var _titulo_piscando := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_montar_cena()
	_montar_interface()
	_pintar()


func _montar_cena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.66, 0.62)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.07, 0.1)
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	if ResourceLoader.exists("res://assets/cenarios/dojo/dojo.glb"):
		var cenario := Cenario.new()
		cenario.carregar("res://assets/cenarios/dojo", "dojo")
		add_child(cenario)
	for dados_luz in [[Vector3(-2, 3, 4), Color(1.0, 0.85, 0.7), 1.0], [Vector3(2, 2, -2), Color(0.45, 0.55, 1.0), 1.4]]:
		var l := DirectionalLight3D.new()
		l.light_color = dados_luz[1]
		l.light_energy = dados_luz[2]
		add_child(l)
		l.look_at_from_position(dados_luz[0], Vector3(0, 1, 0))
	_modelo = load("res://assets/personagens/pci/pci_v5.glb").instantiate()
	_modelo.position = Vector3(0.9, 0.05, 0)
	add_child(_modelo)
	var anim: AnimationPlayer = _modelo.find_child("AnimationPlayer", true, false)
	anim.get_animation("parado").loop_mode = Animation.LOOP_LINEAR
	anim.play("parado")
	var cam := Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.35, 4.2), Vector3(0, 1.05, 0))


func _rotulo(texto: String, tamanho: int, cor := Color.WHITE) -> Label:
	var r := Label.new()
	r.text = texto
	r.add_theme_font_size_override("font_size", tamanho)
	r.add_theme_color_override("font_color", cor)
	r.add_theme_color_override("font_outline_color", Color.BLACK)
	r.add_theme_constant_override("outline_size", max(4, tamanho / 6))
	return r


func _montar_interface() -> void:
	var camada := CanvasLayer.new()
	add_child(camada)
	var coluna := VBoxContainer.new()
	coluna.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	coluna.offset_left = 80
	coluna.offset_top = -300
	coluna.add_theme_constant_override("separation", 6)
	camada.add_child(coluna)
	coluna.add_child(_rotulo("CENTRAL", 72, Color(1.0, 0.8, 0.25)))
	coluna.add_child(_rotulo("torneio de luta  ·  estrelando PCI", 18, Color(0.85, 0.85, 0.85)))
	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 24)
	coluna.add_child(espaco)
	for o in OPCOES:
		var r := _rotulo(o, 28)
		coluna.add_child(r)
		_rotulos.append(r)
	var ajuda := _rotulo("W/S escolhe · A/D muda · Enter confirma", 16, Color(0.7, 0.7, 0.7))
	ajuda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ajuda.offset_left = 80
	ajuda.offset_top = -40
	camada.add_child(ajuda)
	_painel_golpes = _rotulo("", 17, Color(0.9, 0.95, 1.0))
	_painel_golpes.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_painel_golpes.offset_left = -560
	_painel_golpes.offset_top = -260
	_painel_golpes.visible = false
	camada.add_child(_painel_golpes)
	_painel_golpes.text = _lista_golpes()


func _comando_bonito(cmd: String) -> String:
	var partes := cmd.split("+")
	if partes[0] in SETAS:
		return SETAS[partes[0]] + " " + "+".join(partes.slice(1))
	return cmd


func _lista_golpes() -> String:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/pci.json"))
	var linhas := ["GOLPES DO PCI", "botões: 1 = U   2 = I   3 = J   4 = K", ""]
	var vistos := {}
	for id in dados["golpes"]:
		var g: Dictionary = dados["golpes"][id]
		var cmd: String = g.get("comando", "")
		var nome: String = g.get("nome", id)
		if g.has("copia"):
			nome = dados["golpes"][g["copia"]]["nome"]
		if cmd == "":
			continue
		var chave := nome
		if vistos.has(chave):
			vistos[chave] += " / " + _comando_bonito(cmd)
			continue
		vistos[chave] = _comando_bonito(cmd)
	for nome in vistos:
		linhas.append("%-20s %s" % [nome, vistos[nome]])
	linhas.append("1, 2 (sequência)     1 → 2 → 4")
	linhas.append("")
	linhas.append("segure ← defende · ↙ defende baixo")
	linhas.append("→→ corrida · ←← esquiva · toque ↑/↓ passo lateral")
	linhas.append("Tempestade de aço precisa da barra azul cheia")
	return "\n".join(linhas)


func _pintar() -> void:
	for i in OPCOES.size():
		var texto: String = OPCOES[i]
		match texto:
			"DIFICULDADE": texto = "DIFICULDADE: < %s >" % Config.NOMES_DIFICULDADE[Config.dificuldade]
			"FILTRO PS2": texto = "FILTRO PS2: < %s >" % ("LIGADO" if Config.filtro_ps2 else "DESLIGADO")
			"MÚSICA": texto = "MÚSICA: < %s >" % ("DESLIGADA" if Config.volume_musica == 0 else "▮".repeat(Config.volume_musica))
		var r: Label = _rotulos[i]
		r.text = ("▶ " if i == _opcao else "   ") + texto
		r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if i == _opcao else Color.WHITE)
	_painel_golpes.visible = OPCOES[_opcao] == "GOLPES"


func _process(delta: float) -> void:
	_modelo.rotation.y = sin(Time.get_ticks_msec() / 1500.0) * 0.5 - 0.4


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("menu_cima"):
		_opcao = (_opcao + OPCOES.size() - 1) % OPCOES.size()
	elif ev.is_action_pressed("menu_baixo"):
		_opcao = (_opcao + 1) % OPCOES.size()
	elif ev.is_action_pressed("menu_esquerda") or ev.is_action_pressed("menu_direita"):
		var passo := -1 if ev.is_action_pressed("menu_esquerda") else 1
		match OPCOES[_opcao]:
			"DIFICULDADE": Config.dificuldade = clampi(Config.dificuldade + passo, 0, 2)
			"MÚSICA":
				Config.volume_musica = clampi(Config.volume_musica + passo, 0, 10)
				Config.aplicar_volume()
			"FILTRO PS2":
				Config.filtro_ps2 = not Config.filtro_ps2
				Config.aplicar_filtro()
	elif ev.is_action_pressed("menu_ok"):
		match OPCOES[_opcao]:
			"VS CPU": _jogar("versus")
			"2 JOGADORES": _jogar("dois")
			"TREINO": _jogar("treino")
			"DEMONSTRAÇÃO": _jogar("demo")
			"FILTRO PS2":
				Config.filtro_ps2 = not Config.filtro_ps2
				Config.aplicar_filtro()
			"SAIR": get_tree().quit()
	else:
		return
	_pintar()


func _jogar(modo: String) -> void:
	Config.modo = modo
	get_tree().change_scene_to_file("res://cenas/luta.tscn")
