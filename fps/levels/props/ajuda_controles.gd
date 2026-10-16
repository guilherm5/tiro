extends CanvasLayer
## Ajuda de controles: aparece no começo da fase e some sozinha.

@export var visible_time := 25.0


func _ready() -> void:
	await get_tree().create_timer(visible_time).timeout
	var label := get_node_or_null(^"Texto") as CanvasItem
	if label:
		create_tween().tween_property(label, ^"modulate:a", 0.0, 2.0)
