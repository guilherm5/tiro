# Um lutador: modelo animado + máquina de estados em quadros fixos (60/s).
#
# A luta (luta.gd) chama passo() uma vez por quadro de física, para os dois lutadores
# na mesma ordem, e depois resolve empurrões e acertos. Assim tudo é determinístico e a
# pausa de impacto (hitstop) congela os dois juntos.
#
# Golpes vêm de dados/<personagem>.json. Cada golpe tem início/ativo/recuperação em
# quadros; a animação é acelerada ou freada para que o pico do golpe caia exatamente
# nos quadros ativos. O acerto testa a posição real do osso (mão, pé, ponta da katana)
# contra o cilindro do corpo do oponente.
class_name Lutador
extends Node3D

signal nocauteado(lutador: Lutador)
signal projetil_lancado(dono: Lutador, dados: Dictionary, origem: Vector3, direcao: Vector3)

enum E {
	PARADO, ANDAR_F, ANDAR_T, AGACHADO, PRE_PULO, NO_AR, ATERRISSANDO, CORRIDA, ESQUIVA,
	PASSO, GOLPE, BLOQUEANDO, ATINGIDO, LANCADO, CAIDO, LEVANTANDO, AGARRADO, NOCAUTE, VITORIA, INTRO,
}

const RAIO_CORPO := 0.3
const RAIO_ARENA := 4.6
const GRAVIDADE := 22.0
const GRAVIDADE_LANCADO := 13.0        # quem foi lançado flutua mais (dá tempo de malabarismo)
const LIMITE_MALABARISMO := 5
const QUADROS_CAIDO := 26
const QUADROS_LEVANTAR := 44
const KATANA_PONTOS := [0.25, 0.55, 0.85]   # frações da lâmina testadas no acerto

var cor_roupa := Color(0, 0, 0, 0)
var nome_exibicao := "PCI"
var dados: Dictionary
var golpes: Dictionary = {}
var ordem_comandos: Array = []     # ids na ordem de prioridade de reconhecimento
var mov: Dictionary

var entrada: Entrada
var oponente: Lutador
var cpu := false
var ia: IA

var vida_max := 170.0
var vida := 170.0
var barra := 0.0                   # medidor de especial (0..100)
var estado := E.PARADO
var f := 0                         # quadros no estado atual
var frente := Vector3(1, 0, 0)     # direção para o oponente (plano XZ)
var vel := Vector3.ZERO            # velocidade em estados físicos (pulo, lançado)
var empurrao := 0.0
var pode_agir := false

# golpe em andamento
var golpe: Dictionary = {}
var golpe_id := ""
var golpes_dados := 0
var acertou_janela := -1           # última janela de acerto que já conectou
var golpe_conectou_algo := false
var invencivel := 0

# reação
var stun := 0
var malabarismo := 0
var combo_sofrido := 0             # golpes seguidos levados (contador do oponente)
var dano_combo := 0.0
var direcao_pulo := 0
var passo_lado := 1.0
var _queda_pendente := false
var _bloqueio_baixo := false
var _projetil_saiu := false

var modelo: Node3D
var anim: AnimationPlayer
var esqueleto: Skeleton3D
var katana_mao: Node3D
var _superficies_katana_costas: Array = []
var _material_invisivel: StandardMaterial3D
var _congelado := 0
var _anim_vel_salva := 1.0
var _ossos := {}

static var _anims_preparadas := {}


func configurar(arquivo_dados: String, jogador: int) -> void:
	dados = JSON.parse_string(FileAccess.get_file_as_string(arquivo_dados))
	nome_exibicao = dados["nome"]
	vida_max = dados["vida"]
	mov = dados["movimento"]
	for id in dados["golpes"]:
		var g: Dictionary = dados["golpes"][id].duplicate(true)
		if g.has("copia"):
			var base: Dictionary = dados["golpes"][g["copia"]].duplicate(true)
			base["comando"] = g["comando"]
			g = base
		g["id"] = id
		golpes[id] = g
	# prioridade de reconhecimento: super > especiais > dois botões > direcionais > normais
	var lista := golpes.keys().filter(func(k): return golpes[k].get("comando", "") != "")
	lista.sort_custom(func(a, b): return _prioridade(golpes[a]) > _prioridade(golpes[b]))
	ordem_comandos = lista
	entrada = Entrada.new(jogador)


func _prioridade(g: Dictionary) -> int:
	var c: String = g["comando"]
	if g.get("super", false):
		return 100
	if g.get("especial", false):
		return 80
	if c == "1+2" or c == "3+4":
		return 60
	if not (c.split("+")[0] in Entrada.BOTOES):
		return 40
	return 10


func _ready() -> void:
	modelo = load(dados["modelo"]).instantiate()
	add_child(modelo)
	anim = modelo.find_child("AnimationPlayer", true, false)
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	esqueleto = modelo.find_child("Skeleton3D", true, false)
	for o in ["Hips", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Spine2"]:
		_ossos[o] = esqueleto.find_bone("mixamorig_" + o)
	_preparar_animacoes()
	for nome in ["parado", "andar_frente", "andar_tras", "agachado", "passo_esq", "passo_dir"]:
		anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	if cor_roupa.a > 0.0:
		_pintar_roupa(cor_roupa)
	_criar_katana()
	vida = vida_max
	_tocar("parado")


# Remove o deslocamento do quadril das animações que andam sozinhas: quem move o
# lutador é o código. Feito uma vez por modelo (as animações são compartilhadas).
func _preparar_animacoes() -> void:
	var chave: String = dados["modelo"]
	if _anims_preparadas.has(chave):
		return
	_anims_preparadas[chave] = true
	var cima_local := (esqueleto.global_transform.basis.inverse() * Vector3.UP).normalized()
	var raiz: Array = dados.get("raiz_removida", [])
	var vertical: Array = dados.get("vertical_removida", [])
	for nome in raiz + vertical:
		var a := anim.get_animation(nome)
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
				continue
			if not String(a.track_get_path(t)).ends_with(":mixamorig_Hips"):
				continue
			var v0: Vector3 = a.track_get_key_value(t, 0)
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				var delta := v - v0
				var parte_vertical := cima_local * delta.dot(cima_local)
				if nome in raiz:
					v -= delta - parte_vertical
				if nome in vertical:
					v -= parte_vertical
				a.track_set_key_value(t, k, v)


# Segunda cor (2P): o corpo usa o atlas assado na variante vermelha (modelo v3+).
# Em modelos antigos, sem atlas, tinge os materiais de tecido.
func _pintar_roupa(cor: Color) -> void:
	var atlas_2p: Texture2D = load(dados["atlas_2p"]) if dados.has("atlas_2p") and ResourceLoader.exists(dados["atlas_2p"]) else null
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i)
			if not (mat is StandardMaterial3D):
				continue
			if mat.resource_name == "corpo" and atlas_2p:
				var novo: StandardMaterial3D = mat.duplicate()
				novo.albedo_texture = atlas_2p
				m.set_surface_override_material(i, novo)
			elif mat.resource_name.begins_with("tecido"):
				var novo: StandardMaterial3D = mat.duplicate()
				novo.albedo_color = cor * (1.0 if mat.resource_name == "tecido_preto" else 1.6)
				m.set_surface_override_material(i, novo)


# Katana: a das costas faz parte da malha; a da mão é um modelo à parte preso no osso
# da mão direita. Sacar = esconder cabo e guarda das costas e mostrar a da mão.
func _criar_katana() -> void:
	_material_invisivel = StandardMaterial3D.new()
	_material_invisivel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_invisivel.albedo_color = Color(0, 0, 0, 0)
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i)
			if mat and mat.resource_name in ["cabo", "metal"]:
				_superficies_katana_costas.append([m, i])
	if not ResourceLoader.exists("res://assets/personagens/pci/katana.glb"):
		return
	var apego := BoneAttachment3D.new()
	apego.bone_name = "mixamorig_RightHand"
	esqueleto.add_child(apego)
	# O rig do Mixamo vem com escala 0,01: o compensador volta para metros.
	var compensador := Node3D.new()
	compensador.scale = Vector3.ONE / esqueleto.global_transform.basis.get_scale().x * scale.x
	apego.add_child(compensador)
	katana_mao = (load("res://assets/personagens/pci/katana.glb") as PackedScene).instantiate()
	compensador.add_child(katana_mao)
	var ajuste: Dictionary = dados.get("katana_na_mao", {})
	var p: Array = ajuste.get("pos", [0.0, 0.08, 0.03])
	var r: Array = ajuste.get("rot", [0.0, 0.0, 90.0])
	katana_mao.position = Vector3(p[0], p[1], p[2])
	katana_mao.rotation_degrees = Vector3(r[0], r[1], r[2])
	katana_mao.visible = false


func mostrar_katana(na_mao: bool) -> void:
	if katana_mao == null:
		return
	katana_mao.visible = na_mao
	for par in _superficies_katana_costas:
		(par[0] as MeshInstance3D).set_surface_override_material(par[1], _material_invisivel if na_mao else null)


# ---------- consultas ----------
func osso(nome: String) -> Vector3:
	if nome == "katana":
		return ponta_katana(0.85)
	return esqueleto.global_transform * esqueleto.get_bone_global_pose(_ossos[nome]).origin


# A lâmina do modelo da katana aponta para +Y do próprio modelo, com o cabo na origem.
func ponta_katana(fracao: float) -> Vector3:
	var base := katana_mao.global_transform
	var comprimento: float = dados.get("katana_comprimento", 0.95)
	return base.origin + base.basis.y.normalized() * comprimento * fracao


func distancia() -> float:
	var d := oponente.global_position - global_position
	return Vector2(d.x, d.z).length()


func no_chao() -> bool:
	return position.y <= 0.001


func agachado() -> bool:
	if estado == E.AGACHADO:
		return true
	if estado == E.BLOQUEANDO and _bloqueio_baixo:
		return true
	if estado == E.GOLPE and golpe.get("postura", "") == "agachado":
		return true
	return false


func esta_vivo() -> bool:
	return estado != E.NOCAUTE and vida > 0.0


func livre() -> bool:
	return estado in [E.PARADO, E.ANDAR_F, E.ANDAR_T, E.AGACHADO]


func no_ar() -> bool:
	return estado in [E.NO_AR, E.LANCADO, E.PRE_PULO] or position.y > 0.05


# Cilindro do corpo: centrado no quadril (acompanha a inclinação), do pé mais baixo à cabeça.
func cilindro() -> Array:
	var q := osso("Hips")
	var base: float = min(osso("LeftFoot").y, osso("RightFoot").y) - 0.08
	var topo: float = osso("Head").y + 0.16
	if estado == E.LANCADO:
		base = max(0.0, base - 0.9)  # no ar o corpo "pega" fácil, como nos jogos de luta
		topo = max(topo, base + 1.2)
	return [Vector2(q.x, q.z), base, topo]


# Golpe médio ou baixo sempre alcança quem está agachado (regra dos jogos de luta):
# para esses níveis o topo do corpo agachado conta como se fosse mais alto.
func contem(ponto: Vector3, raio: float, nivel := "") -> bool:
	var c := cilindro()
	var topo: float = c[2]
	if nivel in ["medio", "baixo", "aereo"] and agachado():
		topo = max(topo, 1.4)
	var plano := Vector2(ponto.x, ponto.z) - (c[0] as Vector2)
	return plano.length() <= RAIO_CORPO + raio and ponto.y >= c[1] - raio and ponto.y <= topo + raio


func frente_na_tela(camera: Camera3D) -> float:
	if camera == null:
		return 1.0
	return 1.0 if frente.dot(camera.global_transform.basis.x) >= 0.0 else -1.0


# ---------- animação ----------
func _tocar(nome: String, mistura := 0.12, velocidade := 1.0) -> void:
	anim.play(nome, mistura)
	anim.speed_scale = velocidade


func congelar(quadros: int) -> void:
	if _congelado == 0:
		_anim_vel_salva = anim.speed_scale
	_congelado = max(_congelado, quadros)
	anim.speed_scale = 0.0


func congelado() -> bool:
	return _congelado > 0


# ---------- laço por quadro ----------
func passo(camera: Camera3D) -> void:
	entrada.atualizar(frente_na_tela(camera))
	if _congelado > 0:
		_congelado -= 1
		if _congelado == 0:
			anim.speed_scale = _anim_vel_salva
		return
	if cpu and ia:
		ia.pensar()
	f += 1
	if invencivel > 0:
		invencivel -= 1
	if estado in [E.PARADO, E.ANDAR_F, E.ANDAR_T, E.AGACHADO, E.PRE_PULO, E.ATERRISSANDO, E.CORRIDA, E.ESQUIVA, E.BLOQUEANDO, E.LEVANTANDO, E.INTRO, E.VITORIA, E.ATINGIDO]:
		_mirar()
	match estado:
		E.PARADO, E.ANDAR_F, E.ANDAR_T, E.AGACHADO: _estado_livre()
		E.PRE_PULO: _estado_pre_pulo()
		E.NO_AR: _estado_no_ar()
		E.ATERRISSANDO:
			if f >= int(mov["pulo_aterrissagem"]):
				_mudar(E.PARADO)
		E.CORRIDA: _estado_desloc(float(mov["corrida_distancia"]), int(mov["corrida_quadros"]), 1.0)
		E.ESQUIVA: _estado_desloc(float(mov["esquiva_distancia"]), int(mov["esquiva_quadros"]), -1.0)
		E.PASSO: _estado_passo()
		E.GOLPE: _estado_golpe()
		E.BLOQUEANDO, E.ATINGIDO:
			if f >= stun:
				_sair_do_atordoamento()
		E.LANCADO: _fisica_ar(GRAVIDADE_LANCADO)
		E.CAIDO:
			if f >= QUADROS_CAIDO:
				_mudar(E.LEVANTANDO)
		E.LEVANTANDO:
			if f >= QUADROS_LEVANTAR:
				_mudar(E.PARADO)
		E.NOCAUTE:
			if position.y > 0.0:
				vel.y -= GRAVIDADE / 60.0
				position.y = max(0.0, position.y + vel.y / 60.0)
	_aplicar_empurrao()
	_virar_modelo()


func _sair_do_atordoamento() -> void:
	combo_sofrido = 0
	dano_combo = 0.0
	if estado == E.BLOQUEANDO and _bloqueio_baixo and entrada.segurando_baixo():
		_mudar(E.AGACHADO)
	else:
		_mudar(E.PARADO)


func _mirar() -> void:
	var d := oponente.global_position - global_position
	d.y = 0
	if d.length() > 0.01:
		frente = d.normalized()


func _virar_modelo() -> void:
	rotation.y = atan2(frente.x, frente.z)


func _mudar(novo: E) -> void:
	var anterior := estado
	estado = novo
	f = 0
	match novo:
		E.PARADO:
			if anterior != E.PARADO or anim.current_animation != "parado":
				_tocar("parado", 0.15)
			mostrar_katana(false)
		E.ANDAR_F: _tocar("andar_frente", 0.15)
		E.ANDAR_T: _tocar("andar_tras", 0.15)
		E.AGACHADO: _tocar("agachado", 0.1, 1.0)
		E.PRE_PULO: _tocar("pulo", 0.06, 1.5)
		E.CORRIDA: _tocar("andar_frente", 0.08, 2.4)
		E.ESQUIVA: _tocar("andar_tras", 0.08, 2.4)
		E.PASSO: _tocar("passo_esq" if passo_lado > 0 else "passo_dir", 0.08, 1.4)
		E.LEVANTANDO:
			_tocar("levantar", 0.1, anim.get_animation("levantar").length * 0.7 / (QUADROS_LEVANTAR / 60.0))
			anim.seek(anim.get_animation("levantar").length * 0.25, true)
			invencivel = QUADROS_LEVANTAR
		E.NOCAUTE: _tocar("derrota", 0.1)
		E.VITORIA:
			_tocar("vitoria", 0.3)
			mostrar_katana(false)
		E.INTRO: _tocar("reverencia", 0.2)


# ---------- estados ----------
func _estado_livre() -> void:
	if not pode_agir:
		if estado != E.PARADO:
			_mudar(E.PARADO)
		return
	if _tentar_golpe():
		return
	var d := entrada.dir()
	if entrada.toque_duplo([6]):
		_mudar(E.CORRIDA)
		return
	if entrada.toque_duplo([4]):
		_mudar(E.ESQUIVA)
		return
	# passo lateral para a frente da tela: toque curto para baixo
	if estado == E.AGACHADO and entrada.toque_curto([1, 2, 3]):
		passo_lado = -1.0
		_mudar(E.PASSO)
		return
	if d in [7, 8, 9]:
		direcao_pulo = (1 if d == 9 else (-1 if d == 7 else 0))
		_mudar(E.PRE_PULO)
		return
	if d in [1, 2, 3]:
		if estado != E.AGACHADO:
			_mudar(E.AGACHADO)
		return
	if d == 6:
		if estado != E.ANDAR_F:
			_mudar(E.ANDAR_F)
		_deslocar(frente * float(mov["andar_frente"]) / 60.0)
	elif d == 4:
		# segurando trás com o oponente atacando perto: fica na guarda em vez de fugir
		if oponente.estado == E.GOLPE and distancia() < 2.2:
			if anim.current_animation != "bloqueio":
				estado = E.PARADO
				_tocar("bloqueio", 0.06, 1.6)
			elif anim.current_animation_position >= anim.current_animation_length * 0.38:
				anim.speed_scale = 0.0
			return
		if estado != E.ANDAR_T:
			_mudar(E.ANDAR_T)
		_deslocar(-frente * float(mov["andar_tras"]) / 60.0)
	elif estado != E.PARADO or anim.current_animation != "parado":
		estado = E.ANDAR_F
		_mudar(E.PARADO)


func _estado_pre_pulo() -> void:
	# Soltou o "cima" logo: era passo lateral para o fundo da tela.
	if entrada.dir() == 5 and f <= Entrada.TOQUE_CURTO:
		passo_lado = 1.0
		_mudar(E.PASSO)
		return
	if f >= int(mov["pulo_preparo"]):
		var duracao := float(mov["pulo_quadros"]) / 60.0
		vel = frente * float(mov["pulo_velocidade"]) * direcao_pulo
		vel.y = 4.0 * float(mov["pulo_altura"]) / duracao
		_mudar(E.NO_AR)
		_tocar("pulo", 0.05, anim.get_animation("pulo").length * 0.75 / duracao)
		anim.seek(anim.get_animation("pulo").length * 0.25, true)


func _estado_no_ar() -> void:
	if pode_agir and _tentar_golpe(true):
		return
	_fisica_ar(_gravidade_pulo())


func _gravidade_pulo() -> float:
	var duracao := float(mov["pulo_quadros"]) / 60.0
	return 8.0 * float(mov["pulo_altura"]) / (duracao * duracao)


func _fisica_ar(g: float) -> void:
	vel.y -= g / 60.0
	_deslocar(Vector3(vel.x, 0, vel.z) / 60.0)
	position.y += vel.y / 60.0
	if position.y <= 0.0 and vel.y < 0.0:
		position.y = 0.0
		vel = Vector3.ZERO
		_aterrissar()


func _aterrissar() -> void:
	if estado == E.LANCADO or _queda_pendente:
		_queda_pendente = false
		golpe = {}
		if vida <= 0.0:
			_mudar(E.NOCAUTE)
			anim.seek(anim.current_animation_length * 0.45, true)
			return
		_mudar(E.CAIDO)
		_tocar("queda", 0.1, 1.0)
		anim.seek(anim.current_animation_length * 0.6, true)
		malabarismo = 0
		return
	golpe = {}
	_mudar(E.ATERRISSANDO)
	_tocar("parado", 0.1)


func _estado_desloc(distancia_total: float, quadros: int, sentido: float) -> void:
	if f <= quadros:
		var t := float(f) / quadros
		_deslocar(frente * sentido * distancia_total * 2.0 * (1.0 - t) / quadros)  # começa rápido e freia
	else:
		_mudar(E.PARADO)


func _estado_passo() -> void:
	var quadros := int(mov["passo_quadros"])
	if f > quadros:
		_mudar(E.PARADO)
		return
	# gira em volta do oponente (arco) sem mudar a distância
	var centro := oponente.global_position
	var rel := global_position - centro
	rel.y = 0
	var raio := rel.length()
	if raio < 0.1:
		return
	var t := float(f) / quadros
	var fatia := 2.0 * (1.0 - t) / quadros  # rápido no começo, freia no fim (soma = 1)
	rel = rel.rotated(Vector3.UP, float(mov["passo_distancia"]) / raio * fatia * passo_lado)
	position.x = centro.x + rel.x
	position.z = centro.z + rel.z


# ---------- golpes ----------
func _tentar_golpe(no_ar := false) -> bool:
	for id in ordem_comandos:
		var g: Dictionary = golpes[id]
		var cmd: String = g["comando"]
		if no_ar != cmd.begins_with("ar+"):
			continue
		if g.get("super", false) and barra < float(g.get("custo", 100)):
			continue
		if entrada.comando(cmd, no_ar):
			iniciar_golpe(id)
			return true
	return false


func iniciar_golpe(id: String) -> void:
	golpe = golpes[id]
	golpe_id = id
	golpes_dados += 1
	acertou_janela = -1
	golpe_conectou_algo = false
	_projetil_saiu = false
	estado = E.GOLPE
	f = 0
	if golpe.get("super", false):
		barra -= float(golpe.get("custo", 100))
	invencivel = int(golpe.get("invencivel", 0))
	mostrar_katana(golpe.get("katana", false))
	_tocar(golpe["anim"], 0.05)
	anim.seek(float(golpe["trecho"][0]) * anim.current_animation_length, true)
	_ajustar_velocidade_golpe()


func total_golpe(g: Dictionary) -> int:
	return int(g["inicio"]) + int(g["ativo"]) + int(g["recuperacao"])


# A animação anda em três ritmos (preparo, ativo, recuperação) para o pico cair nos quadros ativos.
func _ajustar_velocidade_golpe() -> void:
	var t: Array = golpe["trecho"]
	var dur := anim.get_animation(golpe["anim"]).length
	var ini := int(golpe["inicio"])
	var ati := int(golpe["ativo"])
	var v := 1.0
	if f < ini:
		v = (float(t[1]) - float(t[0])) * dur / (ini / 60.0)
	elif f < ini + ati:
		v = (float(t[2]) - float(t[1])) * dur / (ati / 60.0)
	else:
		v = (float(t[3]) - float(t[2])) * dur / (max(1, int(golpe["recuperacao"])) / 60.0)
	anim.speed_scale = max(0.01, v)


func _estado_golpe() -> void:
	var g := golpe
	var ini := int(g["inicio"])
	var ati := int(g["ativo"])
	if f == ini or f == ini + ati:
		_ajustar_velocidade_golpe()
		if f == ini:  # sincroniza o pico da animação com o primeiro quadro ativo
			anim.seek(float(g["trecho"][1]) * anim.get_animation(g["anim"]).length, true)
	var avanco := float(g.get("avanco", 0.0))
	var varios_acertos := g.has("janelas")
	if avanco > 0.0 and f <= ini + ati and (varios_acertos or not golpe_conectou_algo):
		_deslocar(frente * avanco / (ini + ati))
	if g.get("postura", "") == "ar":
		if g.has("altura"):
			var tt := clampf(float(f) / (ini + ati), 0.0, 1.0)
			position.y = float(g["altura"]) * 4.0 * tt * (1.0 - tt)
		else:
			_fisica_ar(_gravidade_pulo())
			if estado != E.GOLPE:
				return
	if g.has("projetil") and f == ini and not _projetil_saiu:
		_projetil_saiu = true
		# sai do peito para a frente (a mão do arremesso fica de lado e o projétil passaria paralelo)
		var origem := osso("Spine2") + frente * 0.35
		origem.y = osso("Spine2").y
		projetil_lancado.emit(self, g, origem, frente)
	var total := total_golpe(g)
	if g.has("cancela") and pode_agir:
		var jan: Array = g.get("janela_cancelar", [ini, total])
		if f >= int(jan[0]) and f <= int(jan[1]):
			for cmd in g["cancela"]:
				if cmd == "especial":
					if golpe_conectou_algo and _tentar_especial():
						return
				elif entrada.comando(cmd):
					iniciar_golpe(g["cancela"][cmd])
					return
	if f >= total:
		if g.get("postura", "") == "ar" and position.y > 0.0 and not g.has("altura"):
			golpe = {}
			estado = E.NO_AR
			f = 0
			_tocar("pulo", 0.1)
			return
		position.y = 0.0
		golpe = {}
		_mudar(E.PARADO)


func _tentar_especial() -> bool:
	for id in ordem_comandos:
		var g: Dictionary = golpes[id]
		if not g.get("especial", false):
			continue
		if g.get("super", false) and barra < float(g.get("custo", 100)):
			continue
		if entrada.comando(g["comando"]):
			iniciar_golpe(id)
			return true
	return false


# Pontos que machucam neste quadro ([] fora da janela ativa ou se a janela já conectou).
func pontos_ativos() -> Array:
	if estado != E.GOLPE or golpe.is_empty() or golpe.has("projetil") or golpe["nivel"] == "agarrao":
		return []
	var janela := janela_atual()
	if janela < 0 or janela <= acertou_janela:
		return []
	var pts := []
	for o in golpe.get("ossos", []):
		if o == "katana":
			if katana_mao and katana_mao.visible:
				for fr in KATANA_PONTOS:
					pts.append(ponta_katana(fr))
		else:
			pts.append(osso(o))
	return pts


func janela_atual() -> int:
	if golpe.is_empty():
		return -1
	if golpe.has("janelas"):
		var jans: Array = golpe["janelas"]
		for i in jans.size():
			if f >= int(jans[i][0]) and f <= int(jans[i][1]):
				return i
		return -1
	var ini := int(golpe["inicio"])
	if f >= ini and f < ini + int(golpe["ativo"]):
		return 0
	return -1


func agarrao_ativo() -> bool:
	return estado == E.GOLPE and golpe.get("nivel", "") == "agarrao" and janela_atual() == 0 and acertou_janela < 0


func ultima_janela() -> bool:
	if golpe.has("janelas"):
		return acertou_janela >= (golpe["janelas"] as Array).size() - 1
	return true


func em_preparo() -> bool:
	return estado == E.GOLPE and not golpe.is_empty() and f < int(golpe["inicio"])


# ---------- defesa e reação ----------
# "nada" (imune ou passou por cima), "bloqueou" ou "acertou" (o dano vem em aplicar_acerto).
func receber(atacante: Lutador, g: Dictionary) -> String:
	if invencivel > 0 or estado in [E.CAIDO, E.LEVANTANDO, E.NOCAUTE, E.AGARRADO]:
		return "nada"
	var nivel: String = g["nivel"]
	if nivel == "alto" and agachado():
		return "nada"  # golpe alto passa por cima de quem está agachado
	if estado == E.LANCADO and malabarismo >= LIMITE_MALABARISMO:
		return "nada"
	if _consegue_bloquear(atacante, nivel):
		_bloqueio_baixo = entrada.dir() == 1
		estado = E.BLOQUEANDO
		f = 0
		stun = max(4, int(g["ativo"]) + int(g["recuperacao"]) + int(g["vantagem_bloqueio"]))
		_tocar("agachado" if _bloqueio_baixo else "bloqueio", 0.04, 1.6)
		empurrao = float(g.get("empurra", 0.3)) * 2.2
		vida = max(1.0, vida - float(g["dano"]) * float(g.get("raspao", 0.0)))
		return "bloqueou"
	return "acertou"


func _consegue_bloquear(atacante: Lutador, nivel: String) -> bool:
	if nivel == "agarrao":
		return false
	if not (estado in [E.PARADO, E.ANDAR_T, E.AGACHADO, E.BLOQUEANDO]):
		return false
	var para_atacante := atacante.global_position - global_position
	para_atacante.y = 0
	if frente.dot(para_atacante.normalized()) < 0.2:
		return false  # pelas costas não dá
	var d := entrada.dir()
	if d == 4:
		return nivel in ["alto", "medio", "aereo"]
	if d == 1:
		return nivel in ["baixo", "medio"]
	return false


func aplicar_acerto(atacante: Lutador, g: Dictionary, dano: float, contra: bool, efeito: String) -> void:
	vida = max(0.0, vida - dano)
	combo_sofrido += 1
	dano_combo += dano
	golpe = {}
	mostrar_katana(false)
	var estava_no_ar := estado == E.LANCADO or position.y > 0.05
	if vida <= 0.0:
		if estava_no_ar or efeito in ["lancar", "queda"]:
			_lancar(atacante, 4.0)
			_queda_pendente = true
		else:
			_mudar(E.NOCAUTE)
		nocauteado.emit(self)
		return
	if efeito == "lancar" or estava_no_ar:
		var forca: float = 5.2 if (efeito == "lancar" and not estava_no_ar) else maxf(1.4, 3.2 - malabarismo * 0.5)
		_lancar(atacante, forca)
		return
	if efeito == "queda":
		_lancar(atacante, 2.8)
		_queda_pendente = true
		return
	estado = E.ATINGIDO
	f = 0
	stun = max(8, int(g["ativo"]) + int(g["recuperacao"]) + int(g["vantagem_acerto"]) + (6 if contra else 0))
	_tocar("dano" if g["nivel"] == "alto" else "dano_corpo", 0.04, 1.5)
	anim.seek(0.0, true)
	empurrao = float(g.get("empurra", 0.3)) * 3.0


func _lancar(atacante: Lutador, forca_vertical: float) -> void:
	if estado != E.LANCADO:
		malabarismo = 0
	malabarismo += 1
	estado = E.LANCADO
	f = 0
	vel = atacante.frente * (0.45 if malabarismo == 1 else 0.8)  # recua pouco: fica no alcance do malabarismo
	vel.y = forca_vertical
	position.y = max(position.y, 0.02)
	_tocar("lancado", 0.04, 1.2)
	anim.seek(0.1, true)


func agarrado_por(_atacante: Lutador) -> void:
	golpe = {}
	estado = E.AGARRADO
	f = 0
	_tocar("dano_corpo", 0.05, 0.8)


func escapou_agarrao() -> bool:
	return entrada.comando("1") or entrada.comando("2")


func soltar_escape() -> void:
	estado = E.ATINGIDO
	_mudar(E.PARADO)
	empurrao = 2.0


func soltar_agarrao(atacante: Lutador, dano: float) -> void:
	vida = max(0.0, vida - dano)
	_lancar(atacante, 3.2)
	_queda_pendente = true
	vel = atacante.frente * 3.0 + Vector3(0, 3.2, 0)
	if vida <= 0.0:
		nocauteado.emit(self)


func _aplicar_empurrao() -> void:
	if empurrao > 0.0:
		_deslocar(-frente * empurrao / 60.0)
		empurrao = max(0.0, empurrao - 9.0 / 60.0)


# Move no plano, preso ao círculo da arena.
func _deslocar(d: Vector3) -> void:
	var p := Vector2(position.x + d.x, position.z + d.z)
	if p.length() > RAIO_ARENA:
		p = p * (RAIO_ARENA / p.length())
	position.x = p.x
	position.z = p.y


func na_parede() -> bool:
	return Vector2(position.x, position.z).length() >= RAIO_ARENA - 0.05


# ---------- round ----------
func comemorar() -> void:
	if esta_vivo():
		pode_agir = false
		golpe = {}
		position.y = 0.0
		_mudar(E.VITORIA)


func apresentar() -> void:
	_mudar(E.INTRO)


func reiniciar(pos: Vector3) -> void:
	vida = vida_max
	position = pos
	vel = Vector3.ZERO
	empurrao = 0.0
	golpe = {}
	malabarismo = 0
	combo_sofrido = 0
	dano_combo = 0.0
	invencivel = 0
	_congelado = 0
	_queda_pendente = false
	mostrar_katana(false)
	estado = E.VITORIA
	_mudar(E.PARADO)
	_tocar("parado", 0.0)
