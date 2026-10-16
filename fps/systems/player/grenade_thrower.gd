class_name GrenadeThrower
extends Node
## Do jogador: G puxa o pino e lança uma granada Mk2 para onde a câmera aponta.
## A arma abaixa durante o lançamento.

signal count_changed(count: int)

@export var count := 2
@export var max_count := 4
@export var throw_speed := 15.0
@export var cooldown := 1.1
## Tempo entre apertar G e a granada sair da mão (puxar o pino, armar o braço).
@export var windup := 0.35

const PIN := preload("res://assets/audio/provisorio/pino.wav")
const WHOOSH := preload("res://assets/audio/provisorio/arremesso.wav")

var _busy := false

@onready var _player: PlayerController = get_parent()


func _ready() -> void:
	count_changed.emit.call_deferred(count)


func add(amount: int) -> void:
	count = mini(count + amount, max_count)
	count_changed.emit(count)


func _physics_process(_delta: float) -> void:
	if _busy or count <= 0 or _player.is_dead or _player.is_cinematic:
		return
	if Input.is_action_just_pressed(&"grenade"):
		_throw()


func _throw() -> void:
	_busy = true
	count -= 1
	count_changed.emit(count)
	var holder := _player.get_node(^"Head/CameraRig/Camera/WeaponHolder") as Node3D
	var camera := _player.camera
	OneShotSound.play(_player, PIN, camera.global_position, -6.0, 3.0)
	# A arma desce para fora da tela enquanto o braço lança.
	holder.process_mode = Node.PROCESS_MODE_DISABLED  # sem atirar com a mão ocupada
	var tween := create_tween()
	tween.tween_property(holder, ^"position:y", -0.35, 0.18)
	await get_tree().create_timer(windup).timeout
	if _player.is_dead:
		_busy = false
		return  # (morto: o jogador já desligou a arma)
	var forward := -camera.global_basis.z
	var grenade := Grenade.new()
	get_tree().current_scene.add_child(grenade)
	var from := camera.global_position + forward * 0.45 + camera.global_basis.x * 0.15 - Vector3.UP * 0.1
	var velocity := forward * throw_speed + Vector3.UP * 2.5 + _player.velocity * 0.6
	grenade.throw(from, velocity, _player)
	OneShotSound.play(_player, WHOOSH, from, -4.0, 4.0)
	EventBus.noise_emitted.emit(from, 8.0, _player)
	var back := create_tween()
	back.tween_interval(0.25)
	back.tween_property(holder, ^"position:y", 0.0, 0.3)
	await get_tree().create_timer(0.45).timeout
	if not _player.is_dead and not _player.is_cinematic:
		holder.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().create_timer(maxf(cooldown - 0.45, 0.0)).timeout
	_busy = false
