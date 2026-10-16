# Teste dos controles do jogador 1, simulando o teclado.
# Uso: godot --headless --fixed-fps 60 --path jogo -s res://ferramentas/teste_controles.gd
# Sai com código 0 se tudo passar, 1 se algo falhar.
extends SceneTree

var luta: Node3D
var falhas := 0


func _initialize() -> void:
	luta = load("res://cenas/luta.tscn").instantiate()
	root.add_child(luta)
	await _quadros(5)
	var p1: Lutador = luta.p1
	var p2: Lutador = luta.p2
	p1.cpu = false
	p2.cpu = false  # P2 parado como saco de pancada nas primeiras checagens
	await _ate(func(): return luta.fase == "luta", 300)
	_checar(luta.fase == "luta", "a luta começa depois da introdução")

	# 1) andar para frente (D) aproxima
	var x0 := p1.position.x
	Input.action_press("p1_direita")
	await _ate(func(): return p1.distancia() < 1.0, 400)
	Input.action_release("p1_direita")
	_checar(p1.position.x > x0 + 0.5 and abs(p2.position.x - 1.6) < 0.01, "D anda para frente (%.2f -> %.2f) e o P2 fica parado" % [x0, p1.position.x])
	_checar(p1.distancia() >= Lutador.DISTANCIA_MINIMA - 0.01, "não atravessa o oponente")

	# 2) soco (J) acerta de perto
	var vida := p2.vida
	await _apertar("p1_soco")
	await _ate(func(): return p1.estado != Lutador.Estado.ATACANDO, 120)
	_checar(p2.vida < vida, "J soca e tira vida (%.0f -> %.0f)" % [vida, p2.vida])

	# 3) chute (K) acerta
	await _ate(func(): return p2.estado != Lutador.Estado.ATINGIDO, 120)
	Input.action_press("p1_direita")
	await _ate(func(): return p1.distancia() < 1.1, 200)
	Input.action_release("p1_direita")
	vida = p2.vida
	await _apertar("p1_chute")
	await _ate(func(): return p1.estado != Lutador.Estado.ATACANDO, 150)
	_checar(p2.vida < vida, "K chuta e tira vida (%.0f -> %.0f)" % [vida, p2.vida])

	# 4) bloqueio (L) segura o soco do P2
	await _ate(func(): return p1.estado == Lutador.Estado.PARADO and p2.estado == Lutador.Estado.PARADO, 200)
	p1.position.x = p2.position.x - 0.95
	Input.action_press("p1_bloqueio")
	await _quadros(20)
	_checar(p1.estado == Lutador.Estado.BLOQUEANDO, "L segura a guarda")
	vida = p1.vida
	p2._golpe = "soco"
	p2._iniciar_golpe("soco")
	await _ate(func(): return p2.estado != Lutador.Estado.ATACANDO, 150)
	var perdeu := vida - p1.vida
	_checar(perdeu > 0.0 and perdeu < 2.0, "guarda reduz o soco a %.1f de dano" % perdeu)
	Input.action_release("p1_bloqueio")

	# 5) andar para trás (A) afasta
	await _quadros(10)
	x0 = p1.position.x
	Input.action_press("p1_esquerda")
	await _quadros(40)
	Input.action_release("p1_esquerda")
	_checar(p1.position.x < x0 - 0.3, "A anda para trás")

	print("TESTE ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas else 0)


func _checar(ok: bool, descricao: String) -> void:
	print("  [", "ok" if ok else "FALHA", "] ", descricao)
	if not ok:
		falhas += 1


func _apertar(acao: String) -> void:
	Input.action_press(acao)
	await _quadros(2)
	Input.action_release(acao)


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_quadros: int) -> void:
	for i in max_quadros:
		if cond.call():
			return
		await physics_frame
