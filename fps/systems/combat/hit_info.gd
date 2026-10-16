class_name HitInfo
extends RefCounted
## Descreve um acerto (tiro, estilhaço). Quem pode ser atingido implementa
## `apply_hit(hit: HitInfo)`; corpos rígidos sem esse método só recebem o impulso.

var damage := 0.0
var position := Vector3.ZERO
var normal := Vector3.UP
## Direção do projétil (normalizada).
var direction := Vector3.FORWARD
var impulse := 0.0
var source: Node = null
