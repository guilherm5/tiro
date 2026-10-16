@tool
class_name CoverPoint
extends Marker3D
## Ponto de cobertura posicionado à mão na fase (atrás de muros, sacos de areia etc.).
## Inimigos escolhem pontos que os protegem do jogador quando agachados e de onde
## conseguem atirar quando de pé.
##
## Posicione o marcador no chão, logo atrás da proteção. A seta azul (eixo -Z) deve
## apontar para o lado de onde vem a ameaça.

## Altura dos olhos agachado e de pé (para testar proteção e linha de tiro).
const CROUCH_EYE := 0.9
const STAND_EYE := 1.6

var occupant: Node = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(&"cover_points")
	gizmo_extents = 0.4


func is_free_for(who: Node) -> bool:
	return occupant == null or occupant == who or not is_instance_valid(occupant)


## Protegido do alvo quando agachado?
func protects_from(target: Vector3, exclude: Array[RID]) -> bool:
	return not _clear_line(global_position + Vector3.UP * CROUCH_EYE, target, exclude)


## Dá para atirar no alvo ao ficar de pé?
func can_shoot_from(target: Vector3, exclude: Array[RID]) -> bool:
	return _clear_line(global_position + Vector3.UP * STAND_EYE, target, exclude)


func _clear_line(from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
