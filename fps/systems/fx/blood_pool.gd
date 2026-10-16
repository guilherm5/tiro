extends Decal
## Mancha escura que se espalha devagar no chão sob um soldado morto. Discreta: o tom
## do jogo é sério, não sangrento.

@export var final_size := 1.3
@export var grow_time := 5.0


func _ready() -> void:
	size = Vector3(0.2, 1.0, 0.2)
	rotate_y(randf() * TAU)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"size", Vector3(final_size, 1.0, final_size * randf_range(0.7, 1.0)), grow_time)
