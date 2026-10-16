# Partida: arena, câmera, HUD e fluxo do round (introdução → luta → K.O. → vitória).
#
# Controles do jogador 1: A/D andam, J soco, K chute, L ou S segura bloqueio.
# Jogador 2 (mesmo teclado): setas andam, 1/2/3 do teclado numérico (ou ,/./;) soco/chute/bloqueio.
# R ou Enter recomeça depois do fim. Tab alterna CPU no P1; F2 alterna CPU no P2 (2 jogadores).
#
# Argumentos (depois de "--"):
#   --demo            os dois lutadores são CPU
#   --sair-apos=N     fecha depois de N segundos (testes)
#   --captura=PREFIXO salva PNGs em momentos-chave da luta
#   --semente=N       sorteio fixo da IA (luta reproduzível)
#   --sair-no-fim     fecha 4,5 s depois da comemoração (gravar uma luta inteira)
extends Node3D

const DURACAO_ROUND := 60.0
const X_INICIAL := 1.6

var p1: Lutador
var p2: Lutador
var camera: Camera3D
var tremida := 0.0
var tempo_restante := DURACAO_ROUND
var fase := "intro"
var tempo_fase := 0.0
var demo := false
var sair_apos := -1.0
var sair_no_fim := false
var prefixo_captura := ""
var capturas_feitas := {}
var relogio := 0.0

# HUD
var barra_p1: ProgressBar
var barra_p2: ProgressBar
var rastro_p1: ProgressBar
var rastro_p2: ProgressBar
var rotulo_tempo: Label
var rotulo_centro: Label
var rotulo_ajuda: Label


func _ready() -> void:
	_ler_argumentos()
	_criar_acoes()
	_criar_arena()
	p1 = _criar_lutador("PCI", -X_INICIAL, demo, Color(0, 0, 0, 0))
	p2 = _criar_lutador("PCI 2P", X_INICIAL, true, Color(0.30, 0.02, 0.03))
	p2.jogador = 2
	p1.oponente = p2
	p2.oponente = p1
	camera = Camera3D.new()
	camera.fov = 40
	add_child(camera)
	_criar_hud()
	_comecar_round()


func _ler_argumentos() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo":
			demo = true
		elif arg == "--sair-no-fim":
			sair_no_fim = true
		elif arg.begins_with("--sair-apos="):
			sair_apos = float(arg.get_slice("=", 1))
		elif arg.begins_with("--captura="):
			prefixo_captura = arg.get_slice("=", 1)
		elif arg.begins_with("--semente="):
			seed(int(arg.get_slice("=", 1)))


func _criar_acoes() -> void:
	var mapa := {
		"p1_esquerda": [KEY_A], "p1_direita": [KEY_D],
		"p1_soco": [KEY_J], "p1_chute": [KEY_K], "p1_bloqueio": [KEY_L, KEY_S],
		"p2_esquerda": [KEY_LEFT], "p2_direita": [KEY_RIGHT],
		"p2_soco": [KEY_KP_1, KEY_COMMA], "p2_chute": [KEY_KP_2, KEY_PERIOD],
		"p2_bloqueio": [KEY_KP_3, KEY_SEMICOLON],
		"reiniciar": [KEY_R, KEY_ENTER], "alternar_cpu": [KEY_TAB], "alternar_cpu_p2": [KEY_F2],
	}
	for acao in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in mapa[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(acao, ev)


# ---------- arena: dojo à noite, low-poly ----------
func _material(cor: Color, rugosidade := 0.9, emissao := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugosidade
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	return m


func _caixa(tamanho: Vector3, pos: Vector3, mat: Material, sombra := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tamanho
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _criar_arena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.6)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Lua fria por cima e luz quente das lanternas.
	var lua := DirectionalLight3D.new()
	lua.light_color = Color(0.7, 0.75, 1.0)
	lua.light_energy = 0.9
	lua.shadow_enabled = true
	add_child(lua)
	lua.look_at_from_position(Vector3(-3, 6, 4), Vector3.ZERO)

	var madeira := _material(Color(0.32, 0.2, 0.11), 0.7)
	var madeira_escura := _material(Color(0.12, 0.07, 0.04), 0.8)
	var tatame := _material(Color(0.55, 0.5, 0.32), 0.95)
	var papel := _material(Color(0.95, 0.85, 0.6), 0.9, 0.9)
	var pedra := _material(Color(0.2, 0.2, 0.22), 1.0)

	_caixa(Vector3(16, 0.3, 8), Vector3(0, -0.15, 0), pedra)               # chão de pedra
	_caixa(Vector3(10, 0.12, 4), Vector3(0, 0.0, 0), madeira)              # tablado
	for i in range(-4, 5):                                                  # tábuas
		_caixa(Vector3(0.03, 0.125, 4), Vector3(i * 1.1, 0.0, 0), madeira_escura, false)
	_caixa(Vector3(3, 0.13, 1.6), Vector3(0, 0.005, 0), tatame, false)     # tatame no centro

	# Parede do fundo com painéis de papel (shoji) acesos por dentro.
	_caixa(Vector3(14, 4.5, 0.3), Vector3(0, 2.25, -3.2), madeira_escura)
	for i in range(-3, 4):
		_caixa(Vector3(1.5, 2.2, 0.05), Vector3(i * 1.9, 1.7, -3.03), papel, false)
		for k in 3:  # grade de madeira por cima do papel
			_caixa(Vector3(1.5, 0.04, 0.06), Vector3(i * 1.9, 0.85 + k * 0.85, -3.0), madeira_escura, false)
		_caixa(Vector3(0.04, 2.2, 0.06), Vector3(i * 1.9, 1.7, -3.0), madeira_escura, false)
	_caixa(Vector3(14, 0.35, 0.5), Vector3(0, 3.1, -3.0), madeira)          # viga

	# Pilares e lanternas.
	for x in [-5.2, 5.2]:
		_caixa(Vector3(0.35, 4.5, 0.35), Vector3(x, 2.25, -1.5), madeira)
		_caixa(Vector3(0.35, 4.5, 0.35), Vector3(x, 2.25, 1.5), madeira)
		var lanterna := _caixa(Vector3(0.35, 0.5, 0.35), Vector3(x * 0.85, 2.2, -2.4),
			_material(Color(1.0, 0.45, 0.15), 0.8, 3.0), false)
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.55, 0.25)
		luz.light_energy = 2.5
		luz.omni_range = 6.0
		luz.position = lanterna.position + Vector3(0, 0, 0.4)
		add_child(luz)


func _criar_lutador(nome: String, x: float, eh_cpu: bool, cor: Color) -> Lutador:
	var l := Lutador.new()
	l.nome_exibicao = nome
	l.cpu = eh_cpu
	l.cor_roupa = cor
	l.position = Vector3(x, 0.06, 0)
	add_child(l)
	l.golpe_conectou.connect(_ao_golpe)
	l.nocauteado.connect(_ao_nocaute)
	return l


# ---------- HUD ----------
func _barra(cor: Color, esquerda: bool) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 100
	b.value = 100
	b.custom_minimum_size = Vector2(0, 26)
	b.fill_mode = ProgressBar.FILL_END_TO_BEGIN if esquerda else ProgressBar.FILL_BEGIN_TO_END
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.1, 0.02, 0.02, 0.85)
	fundo.border_color = Color(0.9, 0.8, 0.4)
	fundo.set_border_width_all(2)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = cor
	b.add_theme_stylebox_override("background", fundo)
	b.add_theme_stylebox_override("fill", cheio)
	return b


func _rotulo(texto: String, tamanho: int) -> Label:
	var r := Label.new()
	r.text = texto
	r.add_theme_font_size_override("font_size", tamanho)
	r.add_theme_color_override("font_outline_color", Color.BLACK)
	r.add_theme_constant_override("outline_size", max(4, tamanho / 6))
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return r


func _criar_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var topo := HBoxContainer.new()
	topo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	topo.offset_left = 30
	topo.offset_right = -30
	topo.offset_top = 20
	topo.add_theme_constant_override("separation", 20)
	hud.add_child(topo)
	var lados := []
	for i in 2:
		var coluna := VBoxContainer.new()
		coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pilha := Control.new()  # rastro branco atrás da barra (dano recente)
		pilha.custom_minimum_size = Vector2(0, 26)
		var rastro := _barra(Color(1, 1, 1, 0.8), i == 0)
		var barra := _barra(Color(0.95, 0.75, 0.1), i == 0)
		for b in [rastro, barra]:
			b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pilha.add_child(b)
		barra.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		var nome := _rotulo("", 22)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		coluna.add_child(pilha)
		coluna.add_child(nome)
		lados.append([coluna, barra, rastro, nome])
	rotulo_tempo = _rotulo("60", 44)
	rotulo_tempo.custom_minimum_size = Vector2(80, 0)
	topo.add_child(lados[0][0])
	topo.add_child(rotulo_tempo)
	topo.add_child(lados[1][0])
	barra_p1 = lados[0][1]
	rastro_p1 = lados[0][2]
	barra_p2 = lados[1][1]
	rastro_p2 = lados[1][2]
	_atualizar_nomes()

	rotulo_centro = _rotulo("", 72)
	rotulo_centro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	rotulo_centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rotulo_centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rotulo_centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	hud.add_child(rotulo_centro)

	rotulo_ajuda = _rotulo("P1: A/D andar · J soco · K chute · L bloqueio    |    Tab: CPU no P1 · F2: 2 jogadores", 16)
	rotulo_ajuda.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	rotulo_ajuda.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rotulo_ajuda.offset_top = -40
	hud.add_child(rotulo_ajuda)


# ---------- fluxo do round ----------
func _comecar_round() -> void:
	p1.reiniciar(-X_INICIAL)
	p2.reiniciar(X_INICIAL)
	p1.pode_agir = false
	p2.pode_agir = false
	tempo_restante = DURACAO_ROUND
	rastro_p1.value = 100
	rastro_p2.value = 100
	_mudar_fase("intro")
	print("LUTA round começou demo=", demo)


func _mudar_fase(f: String) -> void:
	fase = f
	tempo_fase = 0.0


func _process(delta: float) -> void:
	relogio += delta
	tempo_fase += delta
	match fase:
		"intro":
			rotulo_centro.text = "ROUND 1" if tempo_fase < 1.3 else "LUTE!"
			if tempo_fase >= 2.0:
				rotulo_centro.text = ""
				p1.pode_agir = true
				p2.pode_agir = true
				_mudar_fase("luta")
		"luta":
			tempo_restante = max(0.0, tempo_restante - delta)
			if tempo_restante <= 0.0:
				_fim_por_tempo()
		"ko":
			if tempo_fase >= 1.6:
				var vencedor := p1 if p1.esta_vivo() else p2
				vencedor.comemorar()
				rotulo_centro.text = "%s VENCE!" % vencedor.nome_exibicao
				_mudar_fase("vitoria")
		"vitoria":
			if sair_no_fim and tempo_fase > 4.5:
				print("LUTA fim da gravação: vida p1=%.0f p2=%.0f" % [p1.vida, p2.vida])
				get_tree().quit()
			elif Input.is_action_just_pressed("reiniciar") or (demo and tempo_fase > 5.0):
				_comecar_round()
	if Input.is_action_just_pressed("alternar_cpu"):
		p1.cpu = not p1.cpu
		_atualizar_nomes()
	if Input.is_action_just_pressed("alternar_cpu_p2"):
		p2.cpu = not p2.cpu
		_atualizar_nomes()

	barra_p1.value = p1.vida
	barra_p2.value = p2.vida
	rastro_p1.value = move_toward(rastro_p1.value, p1.vida, 25.0 * delta)
	rastro_p2.value = move_toward(rastro_p2.value, p2.vida, 25.0 * delta)
	rotulo_tempo.text = str(ceili(tempo_restante))
	_atualizar_camera(delta)
	_capturas()
	if sair_apos > 0.0 and relogio >= sair_apos:
		print("LUTA fim do teste: vida p1=%.0f p2=%.0f fase=%s" % [p1.vida, p2.vida, fase])
		get_tree().quit()


func _atualizar_nomes() -> void:
	for par in [[barra_p1, p1], [barra_p2, p2]]:
		var coluna := (par[0] as Control).get_parent().get_parent() as VBoxContainer
		var l: Lutador = par[1]
		(coluna.get_child(1) as Label).text = l.nome_exibicao + (" (CPU)" if l.cpu else "")


func _fim_por_tempo() -> void:
	p1.pode_agir = false
	p2.pode_agir = false
	if is_equal_approx(p1.vida, p2.vida):
		rotulo_centro.text = "EMPATE"
		_mudar_fase("vitoria")
		return
	var vencedor := p1 if p1.vida > p2.vida else p2
	vencedor.comemorar()
	rotulo_centro.text = "TEMPO! %s VENCE" % vencedor.nome_exibicao
	print("LUTA tempo esgotado, vence ", vencedor.nome_exibicao)
	_mudar_fase("vitoria")


func _ao_golpe(atacante: Lutador, alvo: Lutador, ponto: Vector3, dano: float, bloqueado: bool) -> void:
	print("LUTA t=%.2f %s acertou %s em %s: dano %.1f%s (vida %.0f)" % [
		relogio, atacante.nome_exibicao, atacante.golpe_atual, alvo.nome_exibicao,
		dano, " BLOQUEADO" if bloqueado else "", alvo.vida])
	_faisca(ponto, bloqueado)
	if not bloqueado:
		tremida = 0.12 if atacante.golpe_atual == "soco" else 0.2
		_pausa_de_impacto(0.06 if atacante.golpe_atual == "soco" else 0.09)


func _ao_nocaute(l: Lutador) -> void:
	print("LUTA t=%.2f K.O.! %s caiu" % [relogio, l.nome_exibicao])
	p1.pode_agir = false
	p2.pode_agir = false
	rotulo_centro.text = "K.O.!"
	tremida = 0.35
	_pausa_de_impacto(0.25)
	_mudar_fase("ko")


# Congela a luta por um instante no impacto (o "peso" do golpe nos jogos de luta).
func _pausa_de_impacto(segundos: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(segundos, true, false, true).timeout
	Engine.time_scale = 1.0


func _faisca(ponto: Vector3, bloqueado: bool) -> void:
	var mi := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.12
	esfera.height = 0.24
	esfera.radial_segments = 8
	esfera.rings = 4
	mi.mesh = esfera
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.5, 0.8, 1.0) if bloqueado else Color(1.0, 0.85, 0.4)
	mi.material_override = m
	mi.position = ponto
	add_child(mi)
	var t := create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.18)
	t.tween_property(m, "albedo_color:a", 0.0, 0.18)
	t.chain().tween_callback(mi.queue_free)


func _atualizar_camera(delta: float) -> void:
	# Segue o quadril de cada um, não a posição do nó: na derrota o corpo cai ~1 m para trás.
	var x1 := p1.posicao_osso("mixamorig_Hips").x
	var x2 := p2.posicao_osso("mixamorig_Hips").x
	var meio := (x1 + x2) * 0.5
	var abertura: float = abs(x1 - x2) + 0.6
	var alvo := Vector3(meio, 1.45, 3.6 + abertura * 0.45)
	if camera.position == Vector3.ZERO:
		camera.position = alvo
	camera.position = camera.position.lerp(alvo, min(1.0, delta * 4.0))
	camera.look_at(Vector3(camera.position.x, 1.0, 0))
	if tremida > 0.0:
		tremida = max(0.0, tremida - delta)
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * tremida * 0.15


func _capturas() -> void:
	if prefixo_captura == "":
		return
	# Momentos fixos do teste: introdução, meio da luta, fim.
	for marco in [1.0, 6.0, 12.0, 20.0]:
		if relogio >= marco and not capturas_feitas.has(marco):
			capturas_feitas[marco] = true
			_salvar_tela("%s_t%02d.png" % [prefixo_captura, int(marco)])
	if fase == "vitoria" and tempo_fase > 1.5 and not capturas_feitas.has("vitoria"):
		capturas_feitas["vitoria"] = true
		_salvar_tela("%s_vitoria.png" % prefixo_captura)


func _salvar_tela(caminho: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(caminho)
		print("LUTA captura ", caminho)
