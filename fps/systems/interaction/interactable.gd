class_name Interactable
extends Area3D
## Algo que o jogador usa com E (olhando para ele, a até ~2 m): pegar um item,
## plantar uma carga, abrir uma porta. O jogador encontra estas áreas pela camada
## física 6 ("interacao").
##
## Pode exigir um item (ex.: plantar o Bangalore exige "bangalore"), dar um item,
## exigir segurar E por um tempo e avisar o script da missão com um evento narrativo.

signal interacted(player: Node)

const LAYER := 1 << 5

## Texto mostrado na tela: "[E] <prompt>".
@export var prompt := "Usar"
## Segundos segurando E (0 = um toque).
@export var hold_time := 0.0
## Item que o jogador precisa ter. Sem ele, mostra `missing_prompt` e não deixa usar.
@export var requires_item := ""
@export var missing_prompt := ""
## O item exigido é gasto ao usar.
@export var consumes_item := true
## Item recebido ao usar.
@export var gives_item := ""
## Evento narrativo emitido ao usar (para o .missao).
@export var event_name := ""
## Desliga depois do primeiro uso.
@export var one_shot := true
## Nós escondidos/removidos ao usar (ex.: o torpedo no chão).
@export var remove_on_use: Array[NodePath] = []
@export var enabled := true


func _ready() -> void:
	add_to_group(&"interactables")
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


## Texto atual para a tela (vazio = nada a mostrar).
func get_prompt(items: Dictionary) -> String:
	if not enabled:
		return ""
	if not requires_item.is_empty() and not items.has(requires_item):
		return missing_prompt
	return prompt


func can_use(items: Dictionary) -> bool:
	return enabled and (requires_item.is_empty() or items.has(requires_item))


func use(player: Node, items: Dictionary) -> void:
	if not can_use(items):
		return
	if not requires_item.is_empty() and consumes_item:
		items.erase(requires_item)
	if not gives_item.is_empty():
		items[gives_item] = true
	for path in remove_on_use:
		var node := get_node_or_null(path)
		if node:
			node.queue_free()
	if one_shot:
		enabled = false
	interacted.emit(player)
	if not event_name.is_empty():
		EventBus.narrative_event.emit(event_name)
