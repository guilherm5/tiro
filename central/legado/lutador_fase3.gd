# Um lutador: modelo animado + estados de luta + controle (jogador ou CPU).
#
# A luta acontece no eixo X. Cada lutador olha para o oponente; "frente" e "trás"
# são sempre relativos a ele. A colisão do golpe usa a posição real do osso que
# bate (mão no soco, pé no chute) a cada quadro da janela ativa, contra um cilindro
# em volta do corpo do oponente.
class_name Lutador
extends Node3D

signal golpe_conectou(atacante: Lutador, alvo: Lutador, ponto: Vector3, dano: float, bloqueado: bool)
signal nocauteado(lutador: Lutador)

enum Estado { PARADO, ANDANDO_FRENTE, ANDANDO_TRAS, ATACANDO, BLOQUEANDO, ATINGIDO, NOCAUTE, VITORIA }

# Números medidos nas animações do Mixamo (ferramentas/medir_golpes.gd):
# - soco: mão direita no ponto mais à frente (0,77 m) aos 45% da animação
# - chute: pé esquerdo no ponto mais à frente (1,13 m) aos 40%
# "inicio"/"fim" são frações da animação em que o golpe machuca.
const GOLPES := {
	"soco": {"osso": "mixamorig_RightHand", "dano": 8.0, "inicio": 0.30, "fim": 0.55, "velocidade": 1.5, "empurrao": 0.25},
	"chute": {"osso": "mixamorig_LeftFoot", "dano": 13.0, "inicio": 0.28, "fim": 0.50, "velocidade": 1.6, "empurrao": 0.5},
}
const BLOQUEIO_PICO := 0.38      # fração da animação "bloqueio" em que a guarda está formada
const DANO_NO_BLOQUEIO := 0.15   # fração do dano que passa pela guarda
const RAIO_CORPO := 0.32         # cilindro de colisão do corpo
const ALTURA_CORPO := Vector2(0.25, 1.85)
const VEL_FRENTE := 1.4
const VEL_TRAS := 1.1
const DISTANCIA_MINIMA := 0.75   # os corpos não se atravessam
const LIMITE_ARENA := 4.2

@export var nome_exibicao := "PCI"
@export var cpu := false
@export var jogador := 1          # qual conjunto de teclas lê quando não é CPU (p1_*, p2_*)
@export var dificuldade := 0.6   # 0..1: reação e agressividade da CPU
@export var cor_roupa := Color(0, 0, 0, 0)  # alfa 0 = cores originais

var vida_max := 100.0
var vida := 100.0
var oponente: Lutador
var estado := Estado.PARADO
var pode_agir := false           # a luta liga/desliga (introdução, fim de round)
var golpe_atual := ""
var golpes_dados := 0          # contador; a IA do oponente usa para reagir uma vez por golpe
var acertou_golpe := false
var empurrao := 0.0              # velocidade de recuo após levar golpe
var modelo: Node3D
var anim: AnimationPlayer
var esqueleto: Skeleton3D

# intenção do quadro (vem do teclado ou da IA)
var _mover := 0
var _golpe := ""
var _bloquear := false

# memória da IA
var _ia_espera := 0.0
var _ia_mover := 0
var _ia_reagiu_a := -1
var _ia_bloqueio_ate := 0.0
var _relogio := 0.0


func _ready() -> void:
	modelo = preload("res://assets/personagens/pci/pci_v3.glb").instantiate()
	add_child(modelo)
	anim = modelo.find_child("AnimationPlayer", true, false)
	esqueleto = modelo.find_child("Skeleton3D", true, false)
	for nome in ["parado", "andar_frente", "andar_tras"]:
		anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	if cor_roupa.a > 0.0:
		_pintar_roupa(cor_roupa)
	anim.play("parado")


func _pintar_roupa(cor: Color) -> void:
	# Segunda cor do mesmo lutador (espelho), como nos jogos de luta da época.
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i)
			if mat is StandardMaterial3D and mat.resource_name.begins_with("tecido"):
				var novo: StandardMaterial3D = mat.duplicate()
				novo.albedo_color = cor * (1.0 if mat.resource_name == "tecido_preto" else 1.6)
				m.set_surface_override_material(i, novo)


# ---------- consultas ----------
func direcao() -> float:
	# +1 se o oponente está à direita (+X).
	return 1.0 if oponente == null or oponente.position.x >= position.x else -1.0


func distancia() -> float:
	return abs(oponente.position.x - position.x)


func progresso() -> float:
	if anim.current_animation == "":
		return 1.0
	return anim.current_animation_position / anim.current_animation_length


func posicao_osso(nome: String) -> Vector3:
	return esqueleto.global_transform * esqueleto.get_bone_global_pose(esqueleto.find_bone(nome)).origin


func esta_vivo() -> bool:
	return estado != Estado.NOCAUTE


# ---------- laço principal ----------
func _physics_process(delta: float) -> void:
	_relogio += delta
	rotation.y = direcao() * PI / 2  # o modelo olha para +Z; gira para olhar o oponente
	_ler_intencao(delta)
	match estado:
		Estado.PARADO, Estado.ANDANDO_FRENTE, Estado.ANDANDO_TRAS:
			_livre(delta)
		Estado.ATACANDO:
			_atacando()
		Estado.BLOQUEANDO:
			_bloqueando()
		Estado.ATINGIDO:
			if progresso() >= 0.7:
				_mudar(Estado.PARADO)
	if empurrao > 0.0:
		_deslocar(-direcao() * empurrao * delta)
		empurrao = max(0.0, empurrao - 6.0 * delta)


func _livre(delta: float) -> void:
	if not pode_agir:
		_mudar(Estado.PARADO)
		return
	if _golpe != "":
		_iniciar_golpe(_golpe)
		return
	if _bloquear:
		_mudar(Estado.BLOQUEANDO)
		return
	if _mover > 0:
		_mudar(Estado.ANDANDO_FRENTE)
		_deslocar(direcao() * VEL_FRENTE * delta)
	elif _mover < 0:
		_mudar(Estado.ANDANDO_TRAS)
		_deslocar(-direcao() * VEL_TRAS * delta)
	else:
		_mudar(Estado.PARADO)


func _deslocar(dx: float) -> void:
	var x := clampf(position.x + dx, -LIMITE_ARENA, LIMITE_ARENA)
	# não atravessa o oponente
	if oponente and abs(oponente.position.x - x) < DISTANCIA_MINIMA and abs(oponente.position.x - x) < distancia():
		x = oponente.position.x - direcao() * DISTANCIA_MINIMA
	position.x = x


func _mudar(novo: Estado) -> void:
	if novo == estado:
		return
	estado = novo
	anim.speed_scale = 1.0
	match novo:
		Estado.PARADO: anim.play("parado", 0.15)
		Estado.ANDANDO_FRENTE: anim.play("andar_frente", 0.15)
		Estado.ANDANDO_TRAS: anim.play("andar_tras", 0.15)
		Estado.BLOQUEANDO: anim.play("bloqueio", 0.08, 1.6)
		Estado.ATINGIDO: anim.play("dano", 0.05, 1.5)
		Estado.NOCAUTE: anim.play("derrota", 0.1)
		Estado.VITORIA: anim.play("vitoria", 0.3)


# ---------- golpes ----------
func _iniciar_golpe(nome: String) -> void:
	golpe_atual = nome
	golpes_dados += 1
	acertou_golpe = false
	estado = Estado.ATACANDO
	anim.speed_scale = 1.0
	anim.play(nome, 0.06, GOLPES[nome]["velocidade"])


func _atacando() -> void:
	var g: Dictionary = GOLPES[golpe_atual]
	var p := progresso()
	if not acertou_golpe and p >= g["inicio"] and p <= g["fim"] and oponente.esta_vivo():
		var ponto := posicao_osso(g["osso"])
		if oponente.cilindro_contem(ponto):
			acertou_golpe = true
			oponente.receber_golpe(self, g, ponto)
	if p >= 0.92 or anim.current_animation != golpe_atual:
		golpe_atual = ""
		_mudar(Estado.PARADO)


func cilindro_contem(ponto: Vector3) -> bool:
	var plano := Vector2(ponto.x - global_position.x, ponto.z - global_position.z)
	var altura := ponto.y - global_position.y
	return plano.length() <= RAIO_CORPO and altura >= ALTURA_CORPO.x and altura <= ALTURA_CORPO.y


func receber_golpe(atacante: Lutador, g: Dictionary, ponto: Vector3) -> void:
	var bloqueou := estado == Estado.BLOQUEANDO
	var dano: float = g["dano"] * (DANO_NO_BLOQUEIO if bloqueou else 1.0)
	vida = max(0.0, vida - dano)
	empurrao = g["empurrao"] * (2.5 if bloqueou else 4.0)
	golpe_conectou.emit(atacante, self, ponto, dano, bloqueou)
	if vida <= 0.0:
		golpe_atual = ""
		_mudar(Estado.NOCAUTE)
		nocauteado.emit(self)
	elif not bloqueou:
		golpe_atual = ""
		estado = Estado.PARADO  # força o _mudar mesmo se já estava atingido
		_mudar(Estado.ATINGIDO)
		anim.seek(0.0, true)  # play() não reinicia uma animação que já está tocando


func _bloqueando() -> void:
	if not _bloquear or not pode_agir:
		_mudar(Estado.PARADO)
		return
	if progresso() >= BLOQUEIO_PICO:
		anim.speed_scale = 0.0  # segura a guarda


func comemorar() -> void:
	if esta_vivo():
		pode_agir = false
		_mudar(Estado.VITORIA)


func reiniciar(x: float) -> void:
	vida = vida_max
	position = Vector3(x, 0, 0)
	empurrao = 0.0
	golpe_atual = ""
	estado = Estado.VITORIA  # força o _mudar a tocar "parado"
	_mudar(Estado.PARADO)


# ---------- controle ----------
func _ler_intencao(delta: float) -> void:
	_mover = 0
	_golpe = ""
	_bloquear = false
	if not pode_agir or oponente == null:
		return
	if cpu:
		_pensar_cpu(delta)
		return
	var p := "p%d_" % jogador
	var eixo := Input.get_axis(p + "esquerda", p + "direita")
	_mover = int(sign(eixo * direcao()))
	_bloquear = Input.is_action_pressed(p + "bloqueio")
	if Input.is_action_just_pressed(p + "soco"):
		_golpe = "soco"
	elif Input.is_action_just_pressed(p + "chute"):
		_golpe = "chute"


func _pensar_cpu(delta: float) -> void:
	var d := distancia()
	# Reação: vê o golpe do oponente começando e decide uma vez por golpe se bloqueia.
	if oponente.estado == Estado.ATACANDO and d < 1.7 and _ia_reagiu_a != oponente.golpes_dados:
		_ia_reagiu_a = oponente.golpes_dados
		if randf() < 0.15 + 0.45 * dificuldade:
			_ia_bloqueio_ate = _relogio + 0.55
	if _relogio < _ia_bloqueio_ate:
		_bloquear = true
		return

	_ia_espera -= delta
	if _ia_espera > 0.0:
		_mover = _ia_mover
		return
	_ia_espera = randf_range(0.18, 0.55) * (1.4 - dificuldade * 0.6)
	_ia_mover = 0
	var r := randf()
	if d > 1.45:  # longe: aproxima
		_ia_mover = 1 if r < 0.85 else 0
	elif d > 1.0:  # distância de chute
		if r < 0.35 + 0.25 * dificuldade:
			_golpe = "chute"
		elif r < 0.75:
			_ia_mover = 1
		elif r < 0.85:
			_ia_mover = -1
	else:  # colado: soco
		if r < 0.40 + 0.25 * dificuldade:
			_golpe = "soco"
		elif r < 0.60:
			_golpe = "chute"
		elif r < 0.85:
			_ia_mover = -1
	_mover = _ia_mover
