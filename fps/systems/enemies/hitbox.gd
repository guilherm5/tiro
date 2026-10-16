extends AnimatableBody3D
## Área de acerto extra (ex.: cabeça) que acompanha a pose do inimigo.
## Repassa o tiro ao inimigo dono da cena, indicando se foi na cabeça.

@export var is_head := true


func apply_hit(hit: HitInfo) -> void:
	owner.receive_hit(hit, is_head)
