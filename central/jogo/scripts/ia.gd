# CPU: decide e "aperta" comandos pela mesma Entrada que o jogador usa (fonte virtual).
# Não trapaceia: só vê o que um jogador veria (estado e quadro do golpe do oponente,
# com um atraso de reação) e precisa fazer a meia-lua para soltar especial.
class_name IA
extends RefCounted

var eu: Lutador
var nivel := 1                      # 0 fácil, 1 normal, 2 difícil
var _fila: Array = []               # [[direção, botões], ...] para os próximos quadros
var _dir := 5                       # direção segurada quando a fila está vazia
var _dir_ate := 0
var _proxima_decisao := 0
var _reagiu_a := -1
var _quadro := 0

# por nível: atraso de reação (quadros), chance de defender, de punir, agressividade
const REACAO := [24, 16, 11]
const DEFESA := [0.25, 0.5, 0.75]
const PUNICAO := [0.15, 0.5, 0.85]
const AGRESSAO := [0.35, 0.55, 0.7]
const DEFESA_BAIXA := [0.1, 0.4, 0.75]


func _init(lutador: Lutador, dificuldade: int) -> void:
	eu = lutador
	nivel = clampi(dificuldade, 0, 2)


func _apertar(botoes: String, dir := 5) -> void:
	var m := 0
	for b in botoes.split("+"):
		m |= Entrada.BOTOES[b]
	_fila.append([dir, m])


func _comando(cmd: String) -> void:
	var partes := cmd.split("+")
	var pre := partes[0]
	var botoes := "+".join(partes.slice(1)) if not (pre in Entrada.BOTOES) else cmd
	match pre:
		"qcf":
			_fila.append_array([[2, 0], [3, 0], [6, 0]])
			_apertar(botoes, 6)
		"qcb":
			_fila.append_array([[2, 0], [1, 0], [4, 0]])
			_apertar(botoes, 4)
		"d": _apertar(botoes, 2)
		"df": _apertar(botoes, 3)
		"ar": _apertar(botoes, 5)
		_: _apertar(botoes, 5)


func _segurar(dir: int, quadros: int) -> void:
	_dir = dir
	_dir_ate = _quadro + quadros


func pensar() -> void:
	_quadro += 1
	var e := eu.entrada
	var op := eu.oponente
	if _quadro >= _dir_ate:
		_dir = 5
	# Fila de comandos tem prioridade (meia-lua em andamento etc.)
	if not _fila.is_empty():
		var passo: Array = _fila.pop_front()
		e.virtual_dir = passo[0]
		e.virtual_botoes = passo[1]
		return
	e.virtual_dir = _dir
	if not eu.pode_agir:
		return
	var d := eu.distancia()

	# 1) Defesa: viu o golpe começar (depois do tempo de reação) e ainda dá tempo.
	if op.estado == Lutador.E.GOLPE and op.golpes_dados != _reagiu_a and d < 3.0:
		var g: Dictionary = op.golpe
		if not g.is_empty() and op.f >= REACAO[nivel] * 0.5 and op.f < int(g["inicio"]):
			_reagiu_a = op.golpes_dados
			if randf() < DEFESA[nivel]:
				var nv: String = g["nivel"]
				var baixo: bool = nv == "baixo" and randf() < DEFESA_BAIXA[nivel]
				if nv == "alto" and randf() < 0.3:
					_segurar(2, int(g["inicio"]) + int(g["ativo"]) + 4)  # abaixa e deixa passar
				else:
					_segurar(1 if baixo else 4, int(g["inicio"]) + int(g["ativo"]) + 10)
				e.virtual_dir = _dir
				return
	if _dir in [1, 4, 2] and _quadro < _dir_ate:
		return

	# 2) Punição: bloqueei um golpe que deixa o oponente muito vulnerável.
	if eu.estado == Lutador.E.BLOQUEANDO and op.estado == Lutador.E.GOLPE and not op.golpe.is_empty():
		var vb := int(op.golpe["vantagem_bloqueio"])
		if eu.f >= eu.stun - 2 and randf() < PUNICAO[nivel]:
			if vb <= -14 and d < 1.3:
				_comando("df+2")  # gancho lança: dá combo
			elif vb <= -10 and d < 1.2:
				_comando("1")
				_comando("2")
			return

	# 3) Malabarismo: oponente no ar e eu livre.
	if op.estado == Lutador.E.LANCADO and eu.livre():
		if d < 1.3:
			if op.position.y > 0.5:
				_comando("1")
				_fila.append_array([[5, 0], [5, 0], [5, 0], [5, 0], [5, 0], [5, 0]])
				_comando("2")
			else:
				_comando("4")
		else:
			_segurar(6, 6)
		return

	# 4) Anti-aéreo: oponente pulando para cima de mim.
	if op.estado in [Lutador.E.NO_AR, Lutador.E.PRE_PULO] and d < 2.0 and eu.livre() and randf() < DEFESA[nivel] * 0.6:
		_comando("df+2")
		return

	if _quadro < _proxima_decisao or not eu.livre():
		return
	_proxima_decisao = _quadro + randi_range(8, 22) + (2 - nivel) * 6
	_decidir_neutro(d)


func _decidir_neutro(d: float) -> void:
	var op := eu.oponente
	var r := randf()
	var agressao: float = AGRESSAO[nivel]
	if eu.barra >= 100.0 and d < 2.0 and r < 0.5:
		_comando("qcf+1+2")
		return
	if d > 2.6:
		if r < 0.2:
			_comando("qcf+1")            # shuriken de longe
		elif r < 0.35:
			_fila.append_array([[6, 0], [5, 0], [6, 0]])  # corrida
		else:
			_segurar(6, randi_range(15, 35))
	elif d > 1.35:
		if r < 0.15 * agressao + 0.05:
			_comando("qcb+3")            # voadora cobre distância
		elif r < 0.22:
			_comando("qcf+2")            # corte avança
		elif r < 0.75:
			_segurar(6, randi_range(8, 20))
		elif r < 0.85:
			_fila.append([8, 0])         # passo lateral
		else:
			_segurar(4, randi_range(8, 16))
	else:
		var op_defende := op.estado == Lutador.E.BLOQUEANDO or op.entrada.segurando_tras()
		if op_defende and r < 0.25:
			_comando("1+2")              # agarra quem só defende
		elif r < agressao * 0.35:
			_comando("1")
			if randf() < 0.6:
				_fila.append_array([[5, 0], [5, 0], [5, 0], [5, 0]])
				_comando("2")
				if randf() < 0.4:
					_fila.append_array([[5, 0], [5, 0], [5, 0], [5, 0], [5, 0], [5, 0]])
					_comando("4")
		elif r < agressao * 0.55:
			_comando(["3", "4", "d+4"][randi() % 3])
		elif r < agressao * 0.7:
			_comando("df+2")
		elif r < agressao * 0.76:
			_comando("qcf+2")
		elif r < 0.85:
			_segurar(4, randi_range(10, 24))   # recua (e defende no caminho)
		elif r < 0.92:
			_fila.append([2, 0])         # passo lateral para a frente da tela
		else:
			_segurar(1, randi_range(10, 20))   # defesa baixa
