extends SceneTree
# Teste automático — rode com tests/rodar_testes.sh. Scripts sem tipos estáticos de classes do jogo:
# com -s, eles compilam antes dos autoloads (EventBus) existirem.
# Teste automático da arma: dispara o pente, confere munição, ping, acerto no alvo e recarga.
var scene: Node
var weapon
var frame := 0
var shots := 0
var pings := 0
func _initialize() -> void:
	print("")
	scene = load("res://levels/demo_praia/demo_praia.tscn").instantiate()
	_sem_missao(scene)
	root.add_child(scene)
func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		weapon = scene.get_node("Player/Head/CameraRig/Camera/WeaponHolder/M1Garand")
		weapon.get_node("PingAudio").finished.connect(func(): pass)
		weapon.holder.set_process(false); weapon.is_aiming = true
		# Mira no centro da tábua do alvo 2 (o barco é mais alto que o alvo).
		var cam = scene.get_node("Player/Head/CameraRig/Camera")
		var board = scene.get_node("Itens/Alvo2").global_position + Vector3.UP * 1.3
		var to = board - cam.global_position
		scene.get_node("Player/Head").rotation.x = atan2(to.y, -to.z)
		print("inicio: ", weapon.in_magazine, "/", weapon.reserve, " holder=", weapon.holder != null)
	elif frame > 40 and frame < 205 and frame % 20 == 0:
		if weapon.try_fire(): shots += 1; print("  dispersão=", snappedf(weapon.current_spread, 0.01))
		if weapon.get_node("PingAudio").playing: pings += 1
	elif frame == 210:
		var alvo = scene.get_node("Itens/Alvo2")
		print("disparos=", shots, " pente=", weapon.in_magazine, "/", weapon.reserve, " ping_tocou=", pings > 0)
		print("alvo2 derrubado=", not alvo.freeze, " impactos na cena=", scene.get_children().filter(func(n): return n.has_method("setup")).size(), " mira=", snappedf(weapon.aim_blend,0.01))
		print("tiro com pente vazio retorna: ", weapon.try_fire())
		weapon.start_reload()
		print("recarregando=", weapon.is_reloading)
	elif frame == 210 + 160:
		print("após recarga: ", weapon.in_magazine, "/", weapon.reserve, " recarregando=", weapon.is_reloading)
		weapon.try_fire(); weapon.try_fire()
		weapon.start_reload()
	elif frame == 210 + 330:
		print("recarga parcial (Garand ejeta o pente): ", weapon.in_magazine, "/", weapon.reserve)
		return true
	return false

# Testes de mecânica rodam sem o roteiro da missão (cartela/cutscene) e com a rampa aberta.
func _sem_missao(cena: Node) -> void:
	cena.get_node("Missao").free()
	cena.get_node("Geometria/RampaPivot").rotation.x = deg_to_rad(-106.7)
	# Alvo de treino só para este teste (não existe mais na fase).
	var alvo: Node3D = load("res://levels/props/alvo.tscn").instantiate()
	alvo.name = "Alvo2"
	var itens := cena.get_node("Itens")
	itens.add_child(alvo)
	alvo.position = Vector3(0, -1.76, 49)
