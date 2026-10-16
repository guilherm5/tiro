extends SceneTree
# Teste automático — rode com tests/rodar_testes.sh. Scripts sem tipos estáticos de classes do jogo:
# com -s, eles compilam antes dos autoloads (EventBus) existirem.
# MG42: vê o jogador, atira em rajadas, acerta, suprime, troca o cano; a seteira blindada
# segura o tiro de frente e o tiro na cabeça por dentro do bunker mata.
var scene: Node
var p
var mg
var f := 0
var danos := 0
var max_supressao := 0.0
var recargas := 0
var estados := []
var acertos_confirmados := []
func _initialize() -> void:
	scene = load("res://levels/demo_praia/demo_praia.tscn").instantiate()
	_sem_missao(scene)
	root.add_child(scene)
	current_scene = scene
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 5:
		p = scene.get_node("Player")
		p.health.max_health = 100000; p.health.current = 100000
		mg = scene.get_node("Inimigos/Metralhador")
		for e in scene.get_node("Inimigos").get_children():
			if e != mg: e.process_mode = Node.PROCESS_MODE_DISABLED  # só a MG neste teste
		root.get_node("EventBus").player_damaged.connect(func(_a, _s): danos += 1)
		mg.brain.reloading_changed.connect(func(r): if r: recargas += 1)
		mg.brain.state_changed.connect(func(s): estados.append(["SWEEP","ENGAGE","SUPPRESS","RELOAD","DEAD"][s]))
		p.get_node("Head/CameraRig/Camera/WeaponHolder").hit_confirmed.connect(func(k, h): acertos_confirmados.append([k, h]))
		p.global_position = Vector3(-10, 0, 15)
	if f > 5:
		max_supressao = maxf(max_supressao, p.suppression.level)
	if f == 5 + 60 * 20:
		print("MG42 em 20s: estados=", estados)
		print("  jogador atingido ", danos, " vezes; supressão máxima=", snappedf(max_supressao, 0.01), "; trocas de cano=", recargas)
		# atira na cabeça do metralhador com a arma do jogador (mirando direto)
		var cam = p.get_node("Head/CameraRig/Camera")
		var head = mg.visual.head_hitbox.global_position
		p.look_at(Vector3(head.x, p.global_position.y, head.z))
		var weapon = p.get_node("Head/CameraRig/Camera/WeaponHolder/M1Garand")
		weapon.holder.set_process(false); weapon.is_aiming = true; weapon.aim_blend = 1.0
		p.suppression.level = 0.0
		var dir = (head - cam.global_position).normalized()
		p.get_node("Head").rotation.x = asin(dir.y)
	if f == 5 + 60 * 20 + 3:
		var weapon = p.get_node("Head/CameraRig/Camera/WeaponHolder/M1Garand")
		weapon.current_spread = 0.0; weapon._bloom = 0.0
		weapon.data.spread_aim = 0.0; weapon.data.spread_hip = 0.0; weapon.data.spread_moving = 0.0
	if f == 5 + 60 * 20 + 6:
		var weapon = p.get_node("Head/CameraRig/Camera/WeaponHolder/M1Garand")
		# Mira de novo no instante do disparo (a cabeça animada se move).
		var cam2 = p.get_node("Head/CameraRig/Camera")
		cam2.rotation = Vector3.ZERO
		var head2 = mg.visual.head_hitbox.global_position
		p.look_at(Vector3(head2.x, p.global_position.y, head2.z))
		var to2 = head2 - cam2.global_position
		p.get_node("Head").rotation.x = atan2(to2.y, Vector2(to2.x, to2.z).length())
		weapon.current_spread = 0.0
		weapon._shoot()
	if f == 5 + 60 * 21:
		print("  tiro de frente (seteira blindada): metralhador morto=", mg.is_dead, " (esperado: false)")
		# Por dentro, pela porta dos fundos.
		p.global_position = Vector3(-25.0, 2.1, -54.8)
		mg.brain.process_mode = Node.PROCESS_MODE_DISABLED
	if f == 5 + 60 * 21 + 3:
		var weapon = p.get_node("Head/CameraRig/Camera/WeaponHolder/M1Garand")
		var cam2 = p.get_node("Head/CameraRig/Camera")
		cam2.rotation = Vector3.ZERO
		var head2 = mg.visual.head_hitbox.global_position
		p.look_at(Vector3(head2.x, p.global_position.y, head2.z))
	if f == 5 + 60 * 21 + 5:
		var weapon = p.get_node("Head/CameraRig/Camera/WeaponHolder/M1Garand")
		var cam2 = p.get_node("Head/CameraRig/Camera")
		var head2 = mg.visual.head_hitbox.global_position
		var to2 = head2 - cam2.global_position
		p.get_node("Head").rotation.x = atan2(to2.y, Vector2(to2.x, to2.z).length())
		weapon.current_spread = 0.0
		weapon._shoot()
	if f == 5 + 60 * 22:
		print("  tiro na cabeça por dentro: metralhador morto=", mg.is_dead, " marcador de acerto=", acertos_confirmados)
		return true
	return false

# Testes de mecânica rodam sem o roteiro da missão (cartela/cutscene) e com a rampa aberta.
func _sem_missao(cena: Node) -> void:
	cena.get_node("Missao").free()
	cena.get_node("Geometria/RampaPivot").rotation.x = deg_to_rad(-106.7)
