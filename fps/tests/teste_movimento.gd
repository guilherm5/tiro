extends SceneTree
# Teste automático — rode com tests/rodar_testes.sh. Scripts sem tipos estáticos de classes do jogo:
# com -s, eles compilam antes dos autoloads (EventBus) existirem.
# Teste automático: carrega a praia, simula andar para frente e agachar.
var player: CharacterBody3D
var frame := 0
func _initialize() -> void:
	var scene: Node = load("res://levels/demo_praia/demo_praia.tscn").instantiate()
	_sem_missao(scene)
	root.add_child(scene)
	player = scene.get_node("Player")
func _physics_process(_d: float) -> bool:
	frame += 1
	match frame:
		60: print("parado: pos=", player.global_position.snapped(Vector3.ONE*0.01), " chão=", player.is_on_floor())
		61: Input.action_press(&"move_forward")
		300: print("após 4s andando: pos=", player.global_position.snapped(Vector3.ONE*0.01), " chão=", player.is_on_floor(), " vel=", snappedf(Vector2(player.velocity.x, player.velocity.z).length(), 0.01))
		301: Input.action_press(&"sprint")
		420: print("correndo: vel=", snappedf(Vector2(player.velocity.x, player.velocity.z).length(), 0.01), " sprint=", player.is_sprinting)
		421: Input.action_release(&"sprint"); Input.action_press(&"crouch")
		520: print("agachado: vel=", snappedf(Vector2(player.velocity.x, player.velocity.z).length(), 0.01), " altura cabeça=", snappedf(player.get_node("Head").position.y, 0.01))
		521: Input.action_release(&"crouch")
		600: print("em pé: altura cabeça=", snappedf(player.get_node("Head").position.y, 0.01)); return true
	return false

# Testes de mecânica rodam sem o roteiro da missão (cartela/cutscene) e com a rampa aberta.
func _sem_missao(cena: Node) -> void:
	cena.get_node("Missao").free()
	cena.get_node("Geometria/RampaPivot").rotation.x = deg_to_rad(-106.7)
