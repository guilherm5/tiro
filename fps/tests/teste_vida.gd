extends SceneTree
# Teste automático — rode com tests/rodar_testes.sh. Scripts sem tipos estáticos de classes do jogo:
# com -s, eles compilam antes dos autoloads (EventBus) existirem.
var scene: Node
var p
var f := 0
var eventos := []
func _initialize() -> void:
	scene = load("res://levels/demo_praia/demo_praia.tscn").instantiate()
	_sem_missao(scene)
	root.add_child(scene)
	current_scene = scene
func hit(amount: float) -> void:
	var h := HitInfo.new(); h.damage = amount; h.position = p.global_position + Vector3.UP; h.direction = Vector3.BACK
	p.apply_hit(h)
func v() -> String: return str(snappedf(p.health.current, 0.1))
func _physics_process(_d: float) -> bool:
	f += 1
	match f:
		10:
			p = scene.get_node("Player")
			scene.get_node("Inimigos").process_mode = Node.PROCESS_MODE_DISABLED  # só o sistema de vida
			var bus: Node = root.get_node("EventBus")
			bus.player_damaged.connect(func(a, _s): eventos.append("dano %d" % a))
			bus.player_died.connect(func(): eventos.append("morreu"))
			hit(30); print("após 30 de dano: ", v())
		70: print("1s depois (sem regenerar ainda): ", v())
		400: print("5.5s depois (regenera até o topo do bloco = 75): ", v())
		401: hit(60); print("após mais 60: ", v())
		700: print("regenerou só até 25: ", v())
		701:
			p.global_position = scene.get_node("Itens/KitMedico1").global_position + Vector3.UP * 0.2
		720: print("pegou kit médico: ", v(), "  kit ainda existe: ", scene.has_node("Itens/KitMedico1"))
		1000: print("regenerou até 50: ", v())
		1001: hit(500); print("morto=", p.is_dead, " eventos=", eventos)
		1060: print("tela de morte visível=", scene.get_node("HUD/DeathScreen").visible)
		1320: print("cena reiniciada=", current_scene != scene); return true
	return false

# Testes de mecânica rodam sem o roteiro da missão (cartela/cutscene) e com a rampa aberta.
func _sem_missao(cena: Node) -> void:
	cena.get_node("Missao").free()
	cena.get_node("Geometria/RampaPivot").rotation.x = deg_to_rad(-106.7)
