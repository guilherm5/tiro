extends SceneTree
# Teste automático — rode com tests/rodar_testes.sh. Scripts sem tipos estáticos de classes do jogo:
# com -s, eles compilam antes dos autoloads (EventBus) existirem.
var scene: Node
var p
var f := 0
var log_states := []
var danos := 0
var tiros_inimigos := 0
func _initialize() -> void:
	scene = load("res://levels/demo_praia/demo_praia.tscn").instantiate()
	_sem_missao(scene)
	root.add_child(scene)
	current_scene = scene
func names() -> Array: return ["IDLE","ALERT","COMBAT","DEAD"]
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 5:
		p = scene.get_node("Player")
		p.health.max_health = 100000; p.health.current = 100000  # invulnerável no teste
		var bus: Node = root.get_node("EventBus")
		bus.player_damaged.connect(func(_a, _s): danos += 1)
		bus.enemy_killed.connect(func(e): print("  [", f, "] inimigo morto: ", e.name))
		scene.get_node("Inimigos/Metralhador").process_mode = Node.PROCESS_MODE_DISABLED  # MG tem teste próprio
		for e in scene.get_node("Inimigos").get_children().filter(func(n): return n.name.begins_with("Soldado")):
			e.brain.state_changed.connect(func(st): print("  [", f, "] ", e.name, " -> ", names()[st]))
		p.global_position = Vector3(0, 0, 70)  # na água, longe (fora do alcance de visão)
	if f == 240:
		var nav = scene.get_node("Navegacao")
		print("malha de navegação: ", nav.navigation_mesh.get_polygon_count(), " polígonos")
	if f == 100:
		print("-- jogador avança para z=25 (de pé, visível)")
		p.global_position = Vector3(0, 0, 25)
	if f == 100 + 60*12:
		var s1 = scene.get_node("Inimigos/Soldado1")
		print("após 12s: jogador levou ", danos, " tiros. Soldado1 combate=", s1.brain.combat, " agachado=", s1.is_crouched, " cobertura=", s1.brain.cover != null)
		var pos := []
		for e in scene.get_node("Inimigos").get_children().filter(func(n): return n.name.begins_with("Soldado")): pos.append(str(e.name, " ", e.global_position.snapped(Vector3.ONE*0.1), " cob=", e.brain.cover != null))
		print("  ", "\n  ".join(pos))
	if f == 100 + 60*12 + 1:
		var s1 = scene.get_node("Inimigos/Soldado1")
		var h = load("res://systems/combat/hit_info.gd").new(); h.damage = 100; h.direction = Vector3.FORWARD; h.position = s1.global_position + Vector3.UP; h.source = p
		print("-- tiro na cabeça no Soldado1")
		s1.receive_hit(h, true)
	if f == 100 + 60*12 + 2:
		var s2 = scene.get_node("Inimigos/Soldado2")
		var h = load("res://systems/combat/hit_info.gd").new(); h.damage = 100*0.4; h.direction = Vector3.FORWARD; h.position = s2.global_position + Vector3.UP; h.source = p
		print("-- tiro no corpo do Soldado2 (40 de dano)")
		s2.receive_hit(h, false)
		print("   Soldado2 vida=", s2.health.current, " vivo=", not s2.is_dead)
	if f == 100 + 60*16:
		print("fim: jogador levou ", danos, " tiros no total")
		return true
	return false

# Testes de mecânica rodam sem o roteiro da missão (cartela/cutscene) e com a rampa aberta.
func _sem_missao(cena: Node) -> void:
	cena.get_node("Missao").free()
	cena.get_node("Geometria/RampaPivot").rotation.x = deg_to_rad(-106.7)
