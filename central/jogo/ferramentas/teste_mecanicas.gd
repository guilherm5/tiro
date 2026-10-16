# Teste das mecânicas pela entrada de verdade (buffer, comandos, combos), sem janela.
# Uso: godot --headless --fixed-fps 60 --path jogo -s res://ferramentas/teste_mecanicas.gd
# Sai com código 0 se tudo passar.
extends SceneTree

var luta: Node3D
var p1: Lutador
var p2: Lutador
var falhas := 0


func _initialize() -> void:
	root.get_node("Config").modo = "treino"
	luta = load("res://cenas/luta.tscn").instantiate()
	root.add_child(luta)
	await _quadros(3)
	luta.set("_sem_intro", true)
	await _ate(func(): return luta.fase == "luta", 400)
	p1 = luta.p1
	p2 = luta.p2
	p1.entrada.jogador = 0

	# ---- sequência 1, 2, 4 (combo de 3) ----
	await _posicionar(1.0)
	await _apertar(5, "1")
	await _quadros(14)
	await _apertar(5, "2")
	await _quadros(14)
	await _apertar(5, "4")
	await _ate(func(): return p1.livre() and p2.estado in [Lutador.E.PARADO, Lutador.E.CAIDO, Lutador.E.LEVANTANDO], 200)
	_checar(luta._ultimo_golpe_p1.begins_with("Um-dois-chute"), "1,2,4 sai como sequência (último: %s)" % luta._ultimo_golpe_p1.get_slice("\n", 0))
	_checar(_max_combo >= 3, "1,2,4 conecta 3 golpes seguidos (combo %d)" % _max_combo)

	# ---- gancho lança e o malabarismo conecta ----
	await _posicionar(0.9)
	_max_combo = 0
	await _comando("df", "2")
	await _ate(func(): return p2.estado == Lutador.E.LANCADO, 60)
	_checar(p2.estado == Lutador.E.LANCADO, "df+2 lança o oponente")
	await _ate(func(): return p1.livre(), 60)
	await _apertar(5, "1")
	await _quadros(12)
	await _apertar(5, "2")
	await _ate(func(): return p2.no_chao() and not p2.estado == Lutador.E.LANCADO, 200)
	_checar(_max_combo >= 2, "malabarismo depois do gancho (combo %d)" % _max_combo)

	# ---- rasteira: defesa alta não segura, defesa baixa segura ----
	await _posicionar(0.8)
	luta.boneco = 0
	p2.entrada.virtual_dir = 4
	var vida := p2.vida
	await _comando("d", "4")
	await _ate(func(): return p1.livre(), 120)
	_checar(p2.vida < vida, "rasteira passa pela defesa alta")
	await _ate(func(): return p2.livre(), 200)
	await _posicionar(0.8)
	luta.boneco = 3  # defende baixo
	await _quadros(5)
	vida = p2.vida
	await _comando("d", "4")
	await _ate(func(): return p1.livre(), 120)
	_checar(p2.vida == vida and p2.estado != Lutador.E.CAIDO, "defesa baixa segura a rasteira")
	luta.boneco = 0

	# ---- golpe alto passa por cima de quem está agachado ----
	await _posicionar(0.9)
	luta.boneco = 1
	await _quadros(10)
	vida = p2.vida
	await _apertar(5, "1")
	await _ate(func(): return p1.livre(), 60)
	_checar(p2.vida == vida, "jab (alto) passa por cima de quem está agachado")
	luta.boneco = 0

	# ---- agarrão e escape ----
	await _posicionar(0.8)
	vida = p2.vida
	await _apertar(5, "1+2")
	await _ate(func(): return p1.livre() and p2.estado != Lutador.E.AGARRADO, 120)
	_checar(p2.vida < vida, "1+2 agarra e derruba (%.0f -> %.0f)" % [vida, p2.vida])
	await _ate(func(): return p2.livre(), 200)
	await _posicionar(0.8)
	vida = p2.vida
	await _apertar(5, "1+2")
	await _ate(func(): return p2.estado == Lutador.E.AGARRADO, 30)
	p2.entrada.virtual_botoes = 1  # P2 aperta 1 para escapar
	await _quadros(30)
	_checar(p2.vida == vida, "apertar 1 logo no agarrão escapa")

	# ---- super precisa da barra e acerta várias vezes ----
	await _ate(func(): return p1.livre() and p2.livre(), 120)
	await _posicionar(1.2)
	luta.modo = "dois"  # fora do treino a barra não enche sozinha
	p1.barra = 0.0
	luta.set("_hitstop", 0)
	await _comando("qcf", "1+2")
	await _quadros(5)
	_checar(p1.golpe_id != "tempestade", "sem barra o super não sai")
	await _ate(func(): return p1.livre(), 120)
	await _posicionar(1.2)
	p1.barra = 100.0
	_max_combo = 0
	await _comando("qcf", "1+2")
	await _ate(func(): return p1.livre(), 300)
	_checar(_max_combo >= 2, "super com barra cheia conecta vários cortes (combo %d)" % _max_combo)
	luta.modo = "treino"

	# ---- especial por meia-lua: shuriken de longe ----
	await _ate(func(): return p2.livre(), 200)
	await _posicionar(2.4)
	vida = p2.vida
	await _comando("qcf", "1")
	await _ate(func(): return luta.projeteis.is_empty() and p1.livre(), 150)
	_checar(p2.vida < vida, "meia-lua + 1 solta shuriken que acerta de longe")

	# ---- pulo com chute no ar ----
	await _ate(func(): return p2.livre(), 200)
	await _posicionar(1.6)
	vida = p2.vida
	p1.entrada.virtual_dir = 9
	await _quadros(10)
	p1.entrada.virtual_dir = 5
	_checar(p1.estado == Lutador.E.NO_AR, "↗ pula para frente")
	await _quadros(8)
	await _apertar(5, "3")
	await _ate(func(): return p1.no_chao() and p1.livre(), 120)
	_checar(p2.vida < vida, "chute no ar acerta (%.0f -> %.0f)" % [vida, p2.vida])

	# ---- passo lateral desvia de golpe reto ----
	await _ate(func(): return p2.livre(), 200)
	await _posicionar(0.9)
	vida = p1.vida
	p2.iniciar_golpe("soco")
	p1.entrada.virtual_dir = 8
	await _quadros(2)
	p1.entrada.virtual_dir = 5
	await _ate(func(): return p2.livre(), 120)
	_checar(p1.vida == vida, "toque em ↑ dá passo lateral e o soco reto passa (z=%.2f)" % p1.position.z)

	# ---- corrida (→→) e esquiva (←←) ----
	await _posicionar(2.5)
	var x0 := p1.position.x
	for d in [6, 5, 6]:
		p1.entrada.virtual_dir = d
		await _quadros(2)
	await _quadros(16)
	p1.entrada.virtual_dir = 5
	_checar(p1.position.x > x0 + 0.6, "→→ corre (%.2f m)" % (p1.position.x - x0))

	print("TESTE ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas else 0)


var _max_combo := 0


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
		if p2:
			_max_combo = max(_max_combo, p2.combo_sofrido)


func _ate(cond: Callable, max_quadros: int) -> void:
	for i in max_quadros:
		if cond.call():
			return
		await _quadros(1)


func _posicionar(d: float) -> void:
	await _ate(func(): return p1.livre() and p2.livre(), 240)
	p1.reiniciar(Vector3(-d / 2.0, 0, 0))
	p2.reiniciar(Vector3(d / 2.0, 0, 0))
	p1.frente = Vector3.RIGHT
	p2.frente = Vector3.LEFT
	p1.pode_agir = true
	p2.pode_agir = true
	p1.entrada.virtual_dir = 5
	p2.entrada.virtual_dir = 5
	_max_combo = 0
	await _quadros(10)


func _apertar(dir: int, botoes: String) -> void:
	var m := 0
	for b in botoes.split("+"):
		m |= Entrada.BOTOES[b]
	p1.entrada.virtual_dir = dir
	p1.entrada.virtual_botoes = m
	await _quadros(1)
	p1.entrada.virtual_dir = 5


func _comando(mov: String, botoes: String) -> void:
	var seq := {"qcf": [2, 3, 6], "qcb": [2, 1, 4], "d": [2], "df": [3]}[mov] as Array
	for d in seq:
		p1.entrada.virtual_dir = d
		await _quadros(1)
	await _apertar(seq[-1], botoes)


func _checar(ok: bool, descricao: String) -> void:
	print("  [", "ok" if ok else "FALHA", "] ", descricao)
	if not ok:
		falhas += 1
