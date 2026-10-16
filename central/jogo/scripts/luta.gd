# Partida: arena, câmera, HUD, rounds (melhor de 3), acertos, agarrão, projéteis,
# super, pausa e modo treino.
#
# Ordem de cada quadro de física (60/s), sempre igual (luta reproduzível):
#   1. cada lutador lê a entrada e avança o próprio estado (Lutador.passo)
#   2. projéteis andam
#   3. corpos se empurram (não se atravessam, exceto no pulo)
#   4. acertos: golpes, agarrões e projéteis
#
# Argumentos (depois de "--"): --modo=versus|dois|treino|demo  --semente=N
#   --sair-apos=N (segundos)  --sair-no-fim  --captura=PREFIXO  --sem-intro
extends Node3D

const DADOS_PCI := "res://dados/pci.json"
const DURACAO_ROUND := 90
const SEPARACAO_INICIAL := 3.0
const NOMES_BONECO := ["PARADO", "AGACHADO", "DEFENDE TUDO", "DEFENDE BAIXO", "PULA", "CPU"]
const OPCOES_PAUSA := ["CONTINUAR", "RECOMEÇAR", "MENU PRINCIPAL"]

var p1: Lutador
var p2: Lutador
var camera: Camera3D
var projeteis: Array = []
var modo := "versus"
var fase := "intro"
var quadros_fase := 0
var round_atual := 1
var vitorias := [0, 0]
var quadros_restantes := DURACAO_ROUND * 60
var agarrao := {}
var depurar := false
var boneco := 0
var _cam_lado := 1.0
var _cam_zoom := 0.0
var _tremida := 0.0
var _sem_intro := false
var _sair_apos := -1.0
var _sair_no_fim := false
var _prefixo_captura := ""
var _capturas := {}
var _relogio := 0.0
var _hitstop := 0
var _ultimo_golpe_p1 := ""
var _regen := 0
var _desenho: ImmediateMesh
var _sons := {}
var _sombras: Array = []
var efeitos: Efeitos
var _estado_anterior := {}
var _clarao: ColorRect
var _tocadores: Array = []

# HUD
var hud: CanvasLayer
var barras := []        # vida [p1, p2]
var rastros := []
var medidores := []
var marcas_round := []  # [[bola, bola], [bola, bola]]
var nomes := []
var rotulo_tempo: Label
var rotulo_centro: Label
var rotulo_combo := []
var rotulo_aviso := []
var rotulo_treino: Label
var rotulo_ajuda: Label
var menu_pausa: VBoxContainer
var _fundo_pausa: ColorRect
var _opcao_pausa := 0


func _ready() -> void:
	modo = Config.modo
	_ler_argumentos()
	_criar_arena()
	p1 = _criar_lutador(1, Color(0, 0, 0, 0))
	p2 = _criar_lutador(2, Color(0.30, 0.02, 0.03))
	p1.oponente = p2
	p2.oponente = p1
	match modo:
		"versus":
			_ligar_cpu(p2, true)
		"treino":
			p2.entrada.jogador = 0
		"demo":
			_ligar_cpu(p1, true)
			_ligar_cpu(p2, true)
	camera = Camera3D.new()
	camera.fov = 42
	camera.far = 60
	add_child(camera)
	_desenho = ImmediateMesh.new()
	var desenho_mi := MeshInstance3D.new()
	desenho_mi.mesh = _desenho
	var md := StandardMaterial3D.new()
	md.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	md.vertex_color_use_as_albedo = true
	md.no_depth_test = true
	desenho_mi.material_override = md
	add_child(desenho_mi)
	efeitos = Efeitos.new()
	add_child(efeitos)
	_carregar_sons()
	_criar_sombras()
	_criar_hud()
	_comecar_round()


func _ler_argumentos() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modo="):
			modo = arg.get_slice("=", 1)
		elif arg == "--demo":
			modo = "demo"
		elif arg.begins_with("--semente="):
			seed(int(arg.get_slice("=", 1)))
		elif arg.begins_with("--sair-apos="):
			_sair_apos = float(arg.get_slice("=", 1))
		elif arg == "--sair-no-fim":
			_sair_no_fim = true
		elif arg.begins_with("--captura="):
			_prefixo_captura = arg.get_slice("=", 1)
		elif arg == "--sem-intro":
			_sem_intro = true


func _criar_lutador(jogador: int, cor: Color) -> Lutador:
	var l := Lutador.new()
	l.configurar(DADOS_PCI, jogador)
	l.cor_roupa = cor
	if jogador == 2:
		l.nome_exibicao += " 2P"
	add_child(l)
	l.nocauteado.connect(_ao_nocaute)
	l.projetil_lancado.connect(_ao_projetil)
	return l


func _ligar_cpu(l: Lutador, ligado: bool) -> void:
	l.cpu = ligado
	l.entrada.jogador = 0 if ligado else (1 if l == p1 else 2)
	l.ia = IA.new(l, Config.dificuldade) if ligado else null


# ---------- arena: salão de dojo à noite, fechado nos quatro lados ----------
func _material(cor: Color, rugosidade := 0.9, emissao := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugosidade
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	return m


func _caixa(tamanho: Vector3, pos: Vector3, mat: Material, rot_y := 0.0, sombra := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tamanho
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _disco(raio: float, altura: float, y: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = raio
	cil.bottom_radius = raio
	cil.height = altura
	cil.radial_segments = 32
	mi.mesh = cil
	mi.material_override = mat
	mi.position.y = y
	add_child(mi)


func _criar_arena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.66, 0.58)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.07, 0.1)
	env.fog_density = 0.012
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# cenário com a luz assada no Blender (cenario_dojo.py)
	var cenario := Cenario.new()
	cenario.carregar("res://assets/cenarios/dojo", "dojo")
	add_child(cenario)

	# luz em tempo real só para os lutadores: lua fria vindo do jardim e as lanternas quentes
	var lua := DirectionalLight3D.new()
	lua.light_color = Color(0.62, 0.7, 1.0)
	lua.light_energy = 0.9
	lua.shadow_enabled = false
	add_child(lua)
	lua.look_at_from_position(Vector3(-2, 7, 9), Vector3.ZERO)
	# brilho quente dos painéis de papel, vindo de cima e de frente para a câmera inicial
	var papel := DirectionalLight3D.new()
	papel.light_color = Color(1.0, 0.82, 0.62)
	papel.light_energy = 0.7
	add_child(papel)
	papel.look_at_from_position(Vector3(1, 4, -6), Vector3(0, 1, 0))
	for p in cenario.lanternas():
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.6, 0.3)
		luz.light_energy = 2.6
		luz.omni_range = 8.0
		luz.position = p
		add_child(luz)


# Sombra "bolha" sob cada lutador (como nos jogos de luta do PS2).
func _criar_sombras() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.75))
	grad.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	for l in [p1, p2]:
		var d := Decal.new()
		d.texture_albedo = tex
		d.size = Vector3(1.1, 3.0, 1.1)
		d.name = "sombra"
		add_child(d)
		_sombras.append([d, l])


func _mover_sombras() -> void:
	for par in _sombras:
		var d: Decal = par[0]
		var l: Lutador = par[1]
		var q := l.osso("Hips")
		d.position = Vector3(q.x, 0.0, q.z)
		var altura: float = max(0.0, q.y - 0.9)
		d.modulate = Color(1, 1, 1, clampf(1.0 - altura * 0.8, 0.25, 1.0))


# ---------- som ----------
func _carregar_sons() -> void:
	for nome in ["golpe_fraco", "golpe_forte", "bloqueio", "corte", "vento", "queda", "ko", "gongo", "agarrao", "shuriken", "super"]:
		var caminho := "res://assets/sons/%s.wav" % nome
		if ResourceLoader.exists(caminho):
			_sons[nome] = load(caminho)
	for i in 8:
		var a := AudioStreamPlayer.new()
		add_child(a)
		_tocadores.append(a)

func _som(nome: String, volume_db := 0.0) -> void:
	if not _sons.has(nome):
		return
	for a in _tocadores:
		var t: AudioStreamPlayer = a
		if not t.playing:
			t.stream = _sons[nome]
			t.volume_db = volume_db
			t.pitch_scale = randf_range(0.94, 1.06)
			t.play()
			return


# ---------- HUD ----------
func _barra(cor: Color, invertida: bool, altura := 22.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 100
	b.value = 100
	b.custom_minimum_size = Vector2(0, altura)
	b.fill_mode = ProgressBar.FILL_END_TO_BEGIN if invertida else ProgressBar.FILL_BEGIN_TO_END
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.1, 0.02, 0.02, 0.85)
	fundo.border_color = Color(0.9, 0.8, 0.4)
	fundo.set_border_width_all(2)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = cor
	b.add_theme_stylebox_override("background", fundo)
	b.add_theme_stylebox_override("fill", cheio)
	return b


func _rotulo(texto: String, tamanho: int, cor := Color.WHITE) -> Label:
	var r := Label.new()
	r.text = texto
	r.add_theme_font_size_override("font_size", tamanho)
	r.add_theme_color_override("font_color", cor)
	r.add_theme_color_override("font_outline_color", Color.BLACK)
	r.add_theme_constant_override("outline_size", max(4, tamanho / 6))
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return r


func _bola_round() -> Panel:
	var bola := Panel.new()
	bola.custom_minimum_size = Vector2(16, 16)
	bola.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.15, 0.15, 0.15)
	st.border_color = Color(0.9, 0.8, 0.4)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	bola.add_theme_stylebox_override("panel", st)
	return bola


func _criar_hud() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var topo := HBoxContainer.new()
	topo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	topo.offset_left = 24
	topo.offset_right = -24
	topo.offset_top = 16
	topo.add_theme_constant_override("separation", 16)
	hud.add_child(topo)
	var colunas := []
	for i in 2:
		var coluna := VBoxContainer.new()
		coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pilha := Control.new()
		pilha.custom_minimum_size = Vector2(0, 22)
		var rastro := _barra(Color(1, 1, 1, 0.8), i == 0)
		var barra := _barra(Color(0.95, 0.75, 0.1), i == 0)
		for b in [rastro, barra]:
			b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pilha.add_child(b)
		barra.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		var linha := HBoxContainer.new()
		var nome := _rotulo("", 20)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var caixa_bolas := HBoxContainer.new()
		var bolas := []
		for k in Config.rounds_para_vencer:
			var bola := _bola_round()
			caixa_bolas.add_child(bola)
			bolas.append(bola)
		if i == 0:
			linha.add_child(nome)
			linha.add_child(caixa_bolas)
		else:
			linha.add_child(caixa_bolas)
			linha.add_child(nome)
		coluna.add_child(pilha)
		coluna.add_child(linha)
		colunas.append(coluna)
		barras.append(barra)
		rastros.append(rastro)
		nomes.append(nome)
		marcas_round.append(bolas)
	rotulo_tempo = _rotulo("60", 40)
	rotulo_tempo.custom_minimum_size = Vector2(70, 0)
	var retratos := []
	for i in 2:
		var moldura := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.05, 0.03, 0.02)
		st.border_color = Color(0.9, 0.75, 0.3) if i == 0 else Color(0.85, 0.2, 0.15)
		st.set_border_width_all(3)
		st.set_corner_radius_all(6)
		moldura.add_theme_stylebox_override("panel", st)
		var r := TextureRect.new()
		r.texture = load("res://assets/hud/retrato_pci.png")
		r.custom_minimum_size = Vector2(58, 58)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.flip_h = i == 1
		if i == 1:
			r.modulate = Color(1.0, 0.82, 0.8)
		moldura.add_child(r)
		retratos.append(moldura)
	topo.add_child(retratos[0])
	topo.add_child(colunas[0])
	topo.add_child(rotulo_tempo)
	topo.add_child(colunas[1])
	topo.add_child(retratos[1])

	var baixo := HBoxContainer.new()
	baixo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	baixo.offset_left = 24
	baixo.offset_right = -24
	baixo.offset_top = -48
	baixo.offset_bottom = -30
	baixo.add_theme_constant_override("separation", 360)
	hud.add_child(baixo)
	for i in 2:
		var m := _barra(Color(0.2, 0.6, 1.0), i == 0, 14)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		baixo.add_child(m)
		medidores.append(m)

	for i in 2:
		var esquerda := i == 0
		var c := _rotulo("", 30, Color(1.0, 0.9, 0.4))
		c.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if esquerda else Control.PRESET_CENTER_RIGHT)
		c.offset_left = 30 if esquerda else -320
		c.offset_right = 320 if esquerda else -30
		c.offset_top = -130
		c.offset_bottom = -40
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if esquerda else HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(c)
		rotulo_combo.append(c)
		var a := _rotulo("", 24, Color(1.0, 0.45, 0.3))
		a.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if esquerda else Control.PRESET_CENTER_RIGHT)
		a.offset_left = 30 if esquerda else -420
		a.offset_right = 420 if esquerda else -30
		a.offset_top = -30
		a.offset_bottom = 10
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if esquerda else HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(a)
		rotulo_aviso.append(a)

	rotulo_centro = _rotulo("", 64, Color(1.0, 0.85, 0.3))
	rotulo_centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rotulo_centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rotulo_centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	hud.add_child(rotulo_centro)

	rotulo_treino = _rotulo("", 16, Color(0.8, 1.0, 0.8))
	rotulo_treino.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	rotulo_treino.offset_left = 24
	rotulo_treino.offset_top = 90
	rotulo_treino.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.add_child(rotulo_treino)

	rotulo_ajuda = _rotulo("WASD mover · U I J K = botões 1 2 3 4 · segure trás para defender · Esc pausa", 14, Color(0.85, 0.85, 0.85))
	rotulo_ajuda.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	rotulo_ajuda.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rotulo_ajuda.offset_top = -24
	rotulo_ajuda.offset_bottom = -4
	hud.add_child(rotulo_ajuda)

	_clarao = ColorRect.new()
	_clarao.color = Color(1, 1, 1, 0)
	_clarao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_clarao)
	_fundo_pausa = ColorRect.new()
	_fundo_pausa.color = Color(0, 0, 0, 0.6)
	_fundo_pausa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo_pausa.visible = false
	hud.add_child(_fundo_pausa)
	menu_pausa = VBoxContainer.new()
	menu_pausa.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_pausa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_pausa.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu_pausa.visible = false
	menu_pausa.add_child(_rotulo("PAUSA", 48, Color(1.0, 0.85, 0.3)))
	for o in OPCOES_PAUSA:
		menu_pausa.add_child(_rotulo(o, 28))
	hud.add_child(menu_pausa)
	_atualizar_nomes()


func _atualizar_nomes() -> void:
	for i in 2:
		var l: Lutador = [p1, p2][i]
		var sufixo := " (CPU)" if l.cpu else ""
		if modo == "treino" and i == 1:
			sufixo = " [%s]" % NOMES_BONECO[boneco]
		(nomes[i] as Label).text = l.nome_exibicao + sufixo


# ---------- fluxo ----------
func _comecar_round() -> void:
	var lado := SEPARACAO_INICIAL / 2.0
	p1.reiniciar(Vector3(-lado, 0, 0))
	p2.reiniciar(Vector3(lado, 0, 0))
	p1.frente = Vector3.RIGHT
	p2.frente = Vector3.LEFT
	p1.pode_agir = false
	p2.pode_agir = false
	if round_atual == 1:
		p1.barra = 0.0
		p2.barra = 0.0
	for pr in projeteis:
		(pr as Node).queue_free()
	projeteis.clear()
	agarrao = {}
	quadros_restantes = DURACAO_ROUND * 60
	for r in rastros:
		(r as ProgressBar).value = 100
	_mudar_fase("intro")
	if not _sem_intro and round_atual == 1:
		p1.apresentar()
		p2.apresentar()
	_som("gongo")
	print("LUTA round %d começou modo=%s" % [round_atual, modo])


func _mudar_fase(nova: String) -> void:
	fase = nova
	quadros_fase = 0


func _physics_process(_delta: float) -> void:
	quadros_fase += 1
	match fase:
		"intro":
			var dur := 40 if _sem_intro else (150 if round_atual == 1 else 90)
			if quadros_fase < dur - 40:
				var final := round_atual == Config.rounds_para_vencer * 2 - 1
				rotulo_centro.text = "ROUND FINAL" if final else "ROUND %d" % round_atual
			else:
				rotulo_centro.text = "LUTE!"
			if quadros_fase >= dur:
				rotulo_centro.text = ""
				for l in [p1, p2]:
					if (l as Lutador).estado == Lutador.E.INTRO:
						(l as Lutador).reiniciar((l as Lutador).position)
					(l as Lutador).pode_agir = true
				_mudar_fase("luta")
		"luta":
			if modo != "treino":
				quadros_restantes = max(0, quadros_restantes - 1)
				if quadros_restantes == 0:
					_fim_por_tempo()
		"ko":
			if quadros_fase == 50:
				Engine.time_scale = 1.0
			if quadros_fase >= 110 and _todos_parados():
				_decidir_round()
		"fim_round":
			if quadros_fase >= 150:
				round_atual += 1
				_comecar_round()
		"fim_luta":
			if _sair_no_fim and quadros_fase > 270:
				print("LUTA fim da gravação")
				get_tree().quit()
			elif modo == "demo" and quadros_fase > 300:
				_nova_luta()
	if modo == "treino":
		_controlar_boneco()
	_quadro_de_luta()


func _todos_parados() -> bool:
	for l in [p1, p2]:
		if (l as Lutador).estado in [Lutador.E.LANCADO, Lutador.E.GOLPE]:
			return false
	return true


func _quadro_de_luta() -> void:
	if _hitstop > 0:
		_hitstop -= 1
		p1.entrada.atualizar(p1.frente_na_tela(camera))  # o buffer continua ouvindo
		p2.entrada.atualizar(p2.frente_na_tela(camera))
		return
	p1.passo(camera)
	p2.passo(camera)
	for l in [p1, p2]:
		var lu: Lutador = l
		if lu.estado == Lutador.E.GOLPE and lu.f == 1:
			if lu.golpe.get("super", false):
				_ao_super(lu)
			elif not lu.golpe.has("projetil"):
				_som("corte" if lu.golpe.get("katana", false) else "vento", -12.0)
	var vivos := []
	for pr in projeteis:
		var p: Projetil = pr
		if p.passo() and not _projetil_acertou(p):
			vivos.append(p)
		else:
			p.queue_free()
	projeteis = vivos
	for l in [p1, p2]:
		var lu: Lutador = l
		var antes: int = _estado_anterior.get(lu, -1)
		if lu.estado != antes and lu.estado in [Lutador.E.CAIDO, Lutador.E.NOCAUTE]:
			efeitos.poeira(lu.osso("Hips"))
			_som("queda", -6.0)
		_estado_anterior[lu] = lu.estado
		efeitos.atualizar_rastro(lu)
	_separar_corpos()
	if fase in ["luta", "ko"]:
		_resolver_agarrao()
		_resolver_acertos(p1, p2)
		_resolver_acertos(p2, p1)
	if depurar:
		_desenhar_depuracao()


func _separar_corpos() -> void:
	if p1.position.y > 0.6 or p2.position.y > 0.6:
		return  # pulando por cima: passa (troca de lado)
	var d := Vector2(p2.position.x - p1.position.x, p2.position.z - p1.position.z)
	var minimo := 0.62
	if d.length() >= minimo:
		return
	var dir := d.normalized() if d.length() > 0.001 else Vector2(1, 0)
	var falta := (minimo - d.length()) / 2.0
	p1._deslocar(Vector3(-dir.x, 0, -dir.y) * falta)
	p2._deslocar(Vector3(dir.x, 0, dir.y) * falta)
	# encostado na parede, quem está solto anda o resto
	var d2 := Vector2(p2.position.x - p1.position.x, p2.position.z - p1.position.z)
	if d2.length() < minimo - 0.01:
		var resto := minimo - d2.length()
		if p1.na_parede():
			p2._deslocar(Vector3(dir.x, 0, dir.y) * resto)
		else:
			p1._deslocar(Vector3(-dir.x, 0, -dir.y) * resto)


func _resolver_acertos(a: Lutador, v: Lutador) -> void:
	if a.golpe.is_empty():
		return
	var g := a.golpe
	if a.agarrao_ativo() and agarrao.is_empty():
		var pode := v.no_chao() and not v.agachado() and v.estado in [Lutador.E.PARADO, Lutador.E.ANDAR_F, Lutador.E.ANDAR_T, Lutador.E.BLOQUEANDO]
		if pode and a.distancia() <= float(g.get("alcance", 0.9)) and v.invencivel == 0:
			a.acertou_janela = 0
			a.golpe_conectou_algo = true
			v.agarrado_por(a)
			agarrao = {"a": a, "v": v, "f": 0}
			_som("agarrao")
			print("LUTA %s agarrou %s" % [a.nome_exibicao, v.nome_exibicao])
		return
	for ponto in a.pontos_ativos():
		if not v.contem(ponto, float(g.get("raio", 0.12)), g["nivel"]):
			continue
		var janela := a.janela_atual()
		var r := v.receber(a, g)
		if r == "nada":
			return
		a.acertou_janela = janela
		a.golpe_conectou_algo = true
		if r == "bloqueou":
			a.barra = min(100.0, a.barra + 2.0)
			v.barra = min(100.0, v.barra + 4.0)
			_faisca(ponto, true)
			_som("bloqueio", -4.0)
			_hitstop = 5
			_registrar(a, v, g, 0.0, true, false)
			return
		var contra := v.em_preparo()
		var escala: float = max(0.4, 1.0 - 0.12 * v.combo_sofrido)
		var dano: float = float(g["dano"]) * escala * (1.25 if contra else 1.0)
		var efeito: String = g.get("efeito", "")
		if g.has("janelas") and a.ultima_janela():
			efeito = g.get("efeito_final", efeito)
		v.aplicar_acerto(a, g, dano, contra, efeito)
		a.barra = min(100.0, a.barra + dano * 0.7)
		v.barra = min(100.0, v.barra + dano * 0.4)
		var forte := dano >= 13.0 or efeito != ""
		_faisca(ponto, false, forte)
		_som("corte" if g.get("katana", false) else ("golpe_forte" if forte else "golpe_fraco"))
		_hitstop = 10 if forte else 7
		_tremida = 0.25 if forte else 0.12
		if contra:
			_aviso(a, "CONTRA-ATAQUE!")
		_registrar(a, v, g, dano, false, contra)
		return


func _resolver_agarrao() -> void:
	if agarrao.is_empty():
		return
	var a: Lutador = agarrao["a"]
	var v: Lutador = agarrao["v"]
	agarrao["f"] = int(agarrao["f"]) + 1
	var fq: int = agarrao["f"]
	if fq <= 12 and v.escapou_agarrao():
		print("LUTA %s escapou do agarrão" % v.nome_exibicao)
		_aviso(v, "ESCAPOU!")
		v.soltar_escape()
		a.empurrao = 2.0
		agarrao = {}
		return
	if fq >= 18:
		var dano := 22.0
		if a.golpes.has("agarrao"):
			dano = float(a.golpes["agarrao"]["dano"])
		v.combo_sofrido = 0
		v.soltar_agarrao(a, dano)
		a.barra = min(100.0, a.barra + 10.0)
		_som("queda")
		_tremida = 0.3
		_registrar(a, v, a.golpes.get("agarrao", {}), dano, false, false)
		agarrao = {}


func _projetil_acertou(p: Projetil) -> bool:
	var v: Lutador = p.dono.oponente
	if not v.contem(p.global_position, 0.12, p.golpe["nivel"]):
		return false
	var r := v.receber(p.dono, p.golpe)
	if r == "nada":
		return false
	if r == "bloqueou":
		_faisca(p.global_position, true)
		_som("bloqueio", -4.0)
		_registrar(p.dono, v, p.golpe, 0.0, true, false)
		return true
	var dano: float = float(p.golpe["dano"]) * max(0.4, 1.0 - 0.12 * v.combo_sofrido)
	v.aplicar_acerto(p.dono, p.golpe, dano, false, "")
	p.dono.barra = min(100.0, p.dono.barra + dano * 0.7)
	_faisca(p.global_position, false)
	_som("golpe_fraco")
	_hitstop = 6
	_registrar(p.dono, v, p.golpe, dano, false, false)
	return true


func _registrar(a: Lutador, v: Lutador, g: Dictionary, dano: float, bloqueado: bool, contra: bool) -> void:
	print("LUTA t=%.2f %s %s com %s em %s: dano %.1f%s (vida %.0f, combo %d)" % [
		_relogio, a.nome_exibicao, "bloqueado" if bloqueado else "acertou", g.get("nome", "?"),
		v.nome_exibicao, dano, " CONTRA" if contra else "", v.vida, v.combo_sofrido])
	if a == p1:
		_ultimo_golpe_p1 = _ficha(g, bloqueado)
	var lado := 0 if a == p1 else 1
	if not bloqueado and v.combo_sofrido >= 2:
		var r: Label = rotulo_combo[lado]
		r.text = "%d HITS!\n%d de dano" % [v.combo_sofrido, int(v.dano_combo)]
		r.modulate.a = 1.0


func _ficha(g: Dictionary, bloqueado: bool) -> String:
	if g.is_empty():
		return ""
	var cmd: String = g.get("comando", "")
	return "%s (%s)  início %df · ativo %df · recuperação %df\nno acerto %+d · no bloqueio %+d · dano %d · %s%s" % [
		g.get("nome", "?"), cmd if cmd != "" else "sequência",
		int(g["inicio"]), int(g["ativo"]), int(g["recuperacao"]),
		int(g["vantagem_acerto"]), int(g["vantagem_bloqueio"]), int(g["dano"]), g["nivel"],
		"  [BLOQUEADO]" if bloqueado else ""]


func _aviso(l: Lutador, texto: String) -> void:
	var r: Label = rotulo_aviso[0 if l == p1 else 1]
	r.text = texto
	r.modulate.a = 1.0


func _ao_projetil(dono: Lutador, g: Dictionary, origem: Vector3, direcao: Vector3) -> void:
	var p := Projetil.new(dono, g, origem, direcao)
	add_child(p)
	projeteis.append(p)
	_som("shuriken")


func _ao_super(l: Lutador) -> void:
	l.oponente.congelar(40)
	_aviso(l, String(l.golpe.get("nome", "SUPER")).to_upper() + "!")
	_cam_zoom = 1.0
	_som("super")
	print("LUTA %s soltou o super" % l.nome_exibicao)


func _ao_nocaute(l: Lutador) -> void:
	if fase != "luta":
		return
	print("LUTA t=%.2f K.O.! %s caiu" % [_relogio, l.nome_exibicao])
	p1.pode_agir = false
	p2.pode_agir = false
	rotulo_centro.text = "K.O.!"
	_tremida = 0.4
	_clarao.color = Color(1, 1, 1, 0.85)
	create_tween().tween_property(_clarao, "color:a", 0.0, 0.5)
	_som("ko")
	Engine.time_scale = 0.35
	_mudar_fase("ko")


func _pintar_bola(i: int, k: int, cor: Color) -> void:
	var bola: Panel = marcas_round[i][k]
	var st: StyleBoxFlat = bola.get_theme_stylebox("panel").duplicate()
	st.bg_color = cor
	bola.add_theme_stylebox_override("panel", st)


func _decidir_round() -> void:
	var vencedor: Lutador = null
	if p1.vida > p2.vida:
		vencedor = p1
	elif p2.vida > p1.vida:
		vencedor = p2
	if vencedor:
		var i := 0 if vencedor == p1 else 1
		vitorias[i] += 1
		_pintar_bola(i, vitorias[i] - 1, Color(1.0, 0.8, 0.2))
		vencedor.comemorar()
		var perfeito := vencedor.vida >= vencedor.vida_max
		rotulo_centro.text = ("PERFEITO!\n" if perfeito else "") + "%s VENCE O ROUND" % vencedor.nome_exibicao
	else:
		rotulo_centro.text = "EMPATE"
	print("LUTA fim do round %d: vitórias %d x %d" % [round_atual, vitorias[0], vitorias[1]])
	if vitorias[0] >= Config.rounds_para_vencer or vitorias[1] >= Config.rounds_para_vencer:
		var campeao := p1 if vitorias[0] > vitorias[1] else p2
		rotulo_centro.text = "%s VENCE A LUTA!" % campeao.nome_exibicao
		print("LUTA fim da luta: %s venceu %d x %d" % [campeao.nome_exibicao, vitorias[0], vitorias[1]])
		_mudar_fase("fim_luta")
	else:
		_mudar_fase("fim_round")


func _fim_por_tempo() -> void:
	p1.pode_agir = false
	p2.pode_agir = false
	rotulo_centro.text = "TEMPO!"
	print("LUTA tempo esgotado")
	_mudar_fase("ko")


func _nova_luta() -> void:
	vitorias = [0, 0]
	round_atual = 1
	for i in 2:
		for k in Config.rounds_para_vencer:
			_pintar_bola(i, k, Color(0.15, 0.15, 0.15))
	_comecar_round()


# ---------- treino ----------
func _controlar_boneco() -> void:
	if p2.cpu:
		return
	var e := p2.entrada
	match boneco:
		0: e.virtual_dir = 5
		1: e.virtual_dir = 2
		2:
			var baixo: bool = p1.estado == Lutador.E.GOLPE and p1.golpe.get("nivel", "") == "baixo"
			e.virtual_dir = 1 if baixo else 4
		3: e.virtual_dir = 1
		4: e.virtual_dir = 8 if (quadros_fase % 90) < 10 else 5
	# vida volta quando ninguém está em combo
	if p2.combo_sofrido == 0 and p1.livre() and p2.livre():
		_regen += 1
		if _regen > 60:
			p2.vida = p2.vida_max
			p1.vida = p1.vida_max
	else:
		_regen = 0
	p1.barra = 100.0


func _unhandled_input(ev: InputEvent) -> void:
	if menu_pausa.visible:
		if ev.is_action_pressed("menu_cima"):
			_opcao_pausa = (_opcao_pausa + OPCOES_PAUSA.size() - 1) % OPCOES_PAUSA.size()
		elif ev.is_action_pressed("menu_baixo"):
			_opcao_pausa = (_opcao_pausa + 1) % OPCOES_PAUSA.size()
		elif ev.is_action_pressed("menu_ok"):
			_escolher_pausa()
			return
		elif ev.is_action_pressed("pausa"):
			_pausar(false)
			return
		_pintar_pausa()
		return
	if ev.is_action_pressed("pausa"):
		_pausar(true)
	elif ev.is_action_pressed("depurar"):
		depurar = not depurar
		_desenho.clear_surfaces()
	elif ev.is_action_pressed("treino_boneco") and modo == "treino":
		boneco = (boneco + 1) % NOMES_BONECO.size()
		_ligar_cpu(p2, boneco == NOMES_BONECO.size() - 1)
		_atualizar_nomes()
	elif ev.is_action_pressed("treino_reset") and modo == "treino":
		_comecar_round()


func _pausar(sim: bool) -> void:
	get_tree().paused = sim
	menu_pausa.visible = sim
	_fundo_pausa.visible = sim
	_opcao_pausa = 0
	_pintar_pausa()


func _pintar_pausa() -> void:
	for i in OPCOES_PAUSA.size():
		var r: Label = menu_pausa.get_child(i + 1)
		r.text = ("> %s <" if i == _opcao_pausa else "%s") % OPCOES_PAUSA[i]
		r.modulate = Color(1, 0.85, 0.3) if i == _opcao_pausa else Color.WHITE


func _escolher_pausa() -> void:
	_pausar(false)
	match _opcao_pausa:
		1:
			_nova_luta()
		2:
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file("res://cenas/menu.tscn")


# ---------- efeitos e câmera ----------
func _faisca(ponto: Vector3, bloqueado: bool, forte := false) -> void:
	efeitos.acerto(ponto, bloqueado, forte)


func _process(delta: float) -> void:
	_relogio += delta
	_atualizar_camera(delta)
	_mover_sombras()
	for i in 2:
		var l: Lutador = [p1, p2][i]
		var barra: ProgressBar = barras[i]
		var rastro: ProgressBar = rastros[i]
		var medidor: ProgressBar = medidores[i]
		barra.value = l.vida / l.vida_max * 100.0
		rastro.value = move_toward(rastro.value, barra.value, 30.0 * delta)
		medidor.value = l.barra
		var st: StyleBoxFlat = medidor.get_theme_stylebox("fill")
		st.bg_color = Color(1.0, 0.9, 0.3) if l.barra >= 100.0 and int(_relogio * 6) % 2 == 0 else Color(0.2, 0.6, 1.0)
		for r in [rotulo_combo[i], rotulo_aviso[i]]:
			(r as Label).modulate.a = max(0.0, (r as Label).modulate.a - delta * 0.6)
	rotulo_tempo.text = "--" if modo == "treino" else str(ceili(quadros_restantes / 60.0))
	if modo == "treino":
		rotulo_treino.text = "TREINO · F5 boneco [%s] · F6 recomeçar · F1 caixas\n%s" % [NOMES_BONECO[boneco], _ultimo_golpe_p1]
	_capturar()
	if _sair_apos > 0.0 and _relogio >= _sair_apos:
		print("LUTA fim do teste: vida p1=%.0f p2=%.0f vitórias %d x %d fase=%s" % [p1.vida, p2.vida, vitorias[0], vitorias[1], fase])
		Engine.time_scale = 1.0
		get_tree().quit()


# Câmera lateral que gira junto com a linha entre os lutadores (luta 3D).
func _atualizar_camera(delta: float) -> void:
	var a := p1.osso("Hips")
	var b := p2.osso("Hips")
	var meio := (a + b) * 0.5
	var eixo := Vector3(b.x - a.x, 0, b.z - a.z)
	var sep := eixo.length()
	eixo = eixo.normalized() if sep > 0.01 else Vector3.RIGHT
	var perp := Vector3(-eixo.z, 0, eixo.x) * _cam_lado
	# fica do mesmo lado da linha da luta: se a linha girou demais, troca o lado escolhido
	var atual := camera.position - meio
	atual.y = 0
	if atual.length() > 0.5 and perp.dot(atual.normalized()) < -0.2:
		_cam_lado = -_cam_lado
		perp = -perp
	_cam_zoom = move_toward(_cam_zoom, 0.0, delta * 0.8)
	# alguém no ar: a câmera sobe e se afasta para não cortar o pulo
	var altura: float = max(p1.position.y, p2.position.y)
	var dist: float = (3.1 + sep * 0.55 + altura * 1.2) * (1.0 - 0.35 * _cam_zoom)
	var alvo := Vector3(meio.x, 0, meio.z) + perp * dist + Vector3(0, 1.45 + altura * 0.5 - 0.2 * _cam_zoom, 0)
	if camera.position == Vector3.ZERO:
		camera.position = alvo
	camera.position = camera.position.lerp(alvo, min(1.0, delta * 5.0))
	camera.look_at(Vector3(meio.x, 1.0 + altura * 0.5, meio.z))
	if _tremida > 0.0:
		_tremida = max(0.0, _tremida - delta)
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _tremida * 0.12


func _desenhar_depuracao() -> void:
	_desenho.clear_surfaces()
	_desenho.surface_begin(Mesh.PRIMITIVE_LINES)
	for l in [p1, p2]:
		var lu: Lutador = l
		var c := lu.cilindro()
		var centro: Vector2 = c[0]
		for altura in [c[1], c[2]]:
			for k in 16:
				var a0 := k * TAU / 16
				var a1 := (k + 1) * TAU / 16
				_desenho.surface_set_color(Color(0.2, 1.0, 0.3))
				_desenho.surface_add_vertex(Vector3(centro.x + cos(a0) * Lutador.RAIO_CORPO, altura, centro.y + sin(a0) * Lutador.RAIO_CORPO))
				_desenho.surface_set_color(Color(0.2, 1.0, 0.3))
				_desenho.surface_add_vertex(Vector3(centro.x + cos(a1) * Lutador.RAIO_CORPO, altura, centro.y + sin(a1) * Lutador.RAIO_CORPO))
		for p in lu.pontos_ativos():
			var pt: Vector3 = p
			for eixo in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
				_desenho.surface_set_color(Color(1.0, 0.2, 0.2))
				_desenho.surface_add_vertex(pt - eixo * 0.12)
				_desenho.surface_set_color(Color(1.0, 0.2, 0.2))
				_desenho.surface_add_vertex(pt + eixo * 0.12)
	_desenho.surface_end()


func _capturar() -> void:
	if _prefixo_captura == "":
		return
	for marco in [2.0, 8.0, 14.0, 20.0, 26.0]:
		if _relogio >= marco and not _capturas.has(marco):
			_capturas[marco] = true
			get_viewport().get_texture().get_image().save_png("%s_t%02d.png" % [_prefixo_captura, int(marco)])
			print("LUTA captura ", marco)
