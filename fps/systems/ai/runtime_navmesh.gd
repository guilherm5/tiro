extends NavigationRegion3D
## Gera a malha de navegação ao carregar a fase (em outra thread, ~1 s).
## Entra na malha toda colisão dos nós no grupo "navegacao" (e seus filhos).
## Assim, mudar o cenário não exige "assar" a malha manualmente no editor.

signal ready_for_navigation


func _ready() -> void:
	bake_finished.connect(ready_for_navigation.emit)
	# Espera o cenário (CSG) montar suas colisões, que acontece alguns quadros depois.
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_navigation_mesh(true)
