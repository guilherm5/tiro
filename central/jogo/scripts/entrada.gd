# Entrada de um jogador: lê o teclado (ou uma fonte virtual: IA, replay), guarda o
# histórico quadro a quadro e reconhece comandos.
#
# Direções em notação numérica, relativas a quem joga (6 = para o oponente):
#   7 8 9      ub  u  uf
#   4 5 6  =   b   n  f
#   1 2 3      db  d  df
# Botões estilo Tekken: 1 = braço esquerdo, 2 = braço direito, 3 = perna esquerda, 4 = perna direita.
class_name Entrada
extends RefCounted

const HISTORICO := 40       # quadros guardados
const BUFFER := 8           # um botão vale por até 8 quadros esperando o lutador ficar livre
const JANELA_MOVIMENTO := 18
const JANELA_TOQUE_DUPLO := 14
const TOQUE_CURTO := 7      # soltar 8/2 em até 7 quadros = passo lateral
const BOTOES := {"1": 1, "2": 2, "3": 4, "4": 8}

var jogador := 1            # 1/2 = conjunto de teclas; 0 = virtual
# Fonte virtual (IA/replay): direção já relativa (numpad), botões que descem neste
# quadro e botões segurados.
var virtual_dir := 5
var virtual_botoes := 0
var virtual_segurados := 0
var gravando := false
var gravacao: Array = []              # [[dir, apertos], ...] enquanto gravando

var _dirs := PackedInt32Array()       # direção de cada quadro (mais recente no fim)
var _apertos := PackedInt32Array()    # botões que desceram em cada quadro (máscara)
var _segurados := 0
var _quadro := 0


func _init(j := 1) -> void:
	jogador = j


# frente_na_tela: +1 se "para frente" é a direita da tela para este jogador.
func atualizar(frente_na_tela: float) -> void:
	var d := 5
	var apertos := 0
	if jogador == 0:
		d = virtual_dir
		apertos = virtual_botoes
		_segurados = virtual_segurados | virtual_botoes
		virtual_botoes = 0
	else:
		var p := "p%d_" % jogador
		var x := int(Input.is_action_pressed(p + "direita")) - int(Input.is_action_pressed(p + "esquerda"))
		var y := int(Input.is_action_pressed(p + "cima")) - int(Input.is_action_pressed(p + "baixo"))
		x = x * int(sign(frente_na_tela)) if frente_na_tela != 0.0 else x
		d = 5 + x + 3 * y
		_segurados = 0
		for b in BOTOES:
			if Input.is_action_pressed(p + b):
				_segurados |= BOTOES[b]
			if Input.is_action_just_pressed(p + b):
				apertos |= BOTOES[b]
	_dirs.append(d)
	_apertos.append(apertos)
	if _dirs.size() > HISTORICO:
		_dirs.remove_at(0)
		_apertos.remove_at(0)
	if gravando:
		gravacao.append([d, apertos])
	_quadro += 1


# ---------- consultas ----------
func dir() -> int:
	return _dirs[-1] if _dirs.size() else 5


func dir_anterior(n := 1) -> int:
	return _dirs[-1 - n] if _dirs.size() > n else 5


func segurando_frente() -> bool:
	return dir() in [3, 6, 9]


func segurando_tras() -> bool:
	return dir() in [1, 4, 7]


func segurando_baixo() -> bool:
	return dir() in [1, 2, 3]


func segurando_cima() -> bool:
	return dir() in [7, 8, 9]


func segurando_botao(b: String) -> bool:
	return (_segurados & BOTOES[b]) != 0


# Há quantos quadros a direção atual está segurada.
func tempo_na_direcao(conjunto: Array) -> int:
	var n := 0
	for i in range(_dirs.size() - 1, -1, -1):
		if _dirs[i] in conjunto:
			n += 1
		else:
			break
	return n


# Quadro (índice no histórico) em que o botão foi apertado dentro do buffer, ou -1.
func _aperto_recente(mascara: int, janela := BUFFER) -> int:
	for i in range(_apertos.size() - 1, max(-1, _apertos.size() - 1 - janela), -1):
		if (_apertos[i] & mascara) == mascara:
			return i
	# botões juntos (1+2) podem ter descido em quadros vizinhos
	if mascara & (mascara - 1):
		var achados := 0
		var ultimo := -1
		for i in range(_apertos.size() - 1, max(-1, _apertos.size() - 1 - janela), -1):
			if _apertos[i] & mascara:
				achados |= _apertos[i] & mascara
				ultimo = max(ultimo, i)
		if achados == mascara:
			return ultimo
	return -1


func consumir(mascara: int) -> void:
	for i in range(max(0, _apertos.size() - BUFFER - 1), _apertos.size()):
		_apertos[i] &= ~mascara


# Algum botão (qualquer) foi apertado agora ou no buffer?
func algum_aperto(janela := BUFFER) -> bool:
	for i in range(_apertos.size() - 1, max(-1, _apertos.size() - 1 - janela), -1):
		if _apertos[i]:
			return true
	return false


# ---------- comandos ----------
# Formato: "[direção|movimento|ar]+botões", ex.: "1", "1+2", "d+4", "df+2", "qcf+1", "qcf+1+2", "ar+3".
# Devolve true e consome os botões se o comando foi feito.
func comando(cmd: String, no_ar := false) -> bool:
	var partes := cmd.split("+")
	var prefixo := ""
	var botoes := partes
	if partes[0] not in BOTOES:
		prefixo = partes[0]
		botoes = partes.slice(1)
	var mascara := 0
	for b in botoes:
		mascara |= BOTOES[b]
	if prefixo == "ar" and not no_ar:
		return false
	if prefixo != "ar" and no_ar:
		return false
	var q := _aperto_recente(mascara)
	if q < 0:
		return false
	var d_no_aperto := _dirs[q]
	var ok := true
	match prefixo:
		"", "ar": ok = true
		"d": ok = d_no_aperto in [1, 2, 3]
		"df": ok = d_no_aperto == 3
		"db": ok = d_no_aperto == 1
		"f": ok = d_no_aperto == 6
		"b": ok = d_no_aperto == 4
		"u": ok = d_no_aperto in [7, 8, 9]
		"qcf": ok = _movimento([2, 3, 6], q)
		"qcb": ok = _movimento([2, 1, 4], q)
		"dp": ok = _movimento([6, 2, 3], q)
		_: ok = false
	if ok:
		consumir(mascara)
	return ok


# A sequência de direções aparece em ordem nos quadros antes do aperto (com folga).
func _movimento(seq: Array, quadro_aperto: int) -> bool:
	var alvo := seq.size() - 1
	var limite := mini(_dirs.size() - 1, quadro_aperto + 3)
	for i in range(limite, max(-1, quadro_aperto - JANELA_MOVIMENTO), -1):
		if _dirs[i] == seq[alvo]:
			alvo -= 1
			if alvo < 0:
				return true
	return false


# Toque duplo para frente (corrida) ou para trás (esquiva). Consome o padrão.
func toque_duplo(conjunto: Array) -> bool:
	# procura: entrou no conjunto agora; antes saiu; antes disso entrou (dentro da janela)
	if _dirs.size() < 3 or not (_dirs[-1] in conjunto) or (_dirs[-2] in conjunto):
		return false
	var saiu := false
	for i in range(_dirs.size() - 2, max(-1, _dirs.size() - 2 - JANELA_TOQUE_DUPLO), -1):
		if not (_dirs[i] in conjunto):
			saiu = true
		elif saiu:
			# apaga o histórico do padrão para não disparar de novo
			for k in range(i, _dirs.size() - 1):
				_dirs[k] = 5
			return true
	return false


# Soltou 8 (ou 2) para o neutro depois de segurar por pouco tempo: passo lateral.
# Precisa voltar ao 5: ↓↘→ (meia-lua) não pode virar passo lateral.
func toque_curto(conjunto: Array) -> bool:
	if _dirs.size() < 2 or _dirs[-1] != 5 or not (_dirs[-2] in conjunto):
		return false
	var n := 0
	for i in range(_dirs.size() - 2, -1, -1):
		if _dirs[i] in conjunto:
			n += 1
		else:
			break
	return n <= TOQUE_CURTO
