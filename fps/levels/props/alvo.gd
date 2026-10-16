extends RigidBody3D
## Alvo de treino (só para testes): fica parado até levar um tiro, então cai.


func apply_hit(hit: HitInfo) -> void:
	freeze = false
	# Aplicado no quadro seguinte, depois que o corpo deixa de estar congelado.
	(func() -> void:
		apply_impulse(hit.direction * hit.impulse * 3.0, hit.position - global_position)
	).call_deferred()
