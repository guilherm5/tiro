class_name SoldierBrain
extends Node
## Comportamento do soldado inimigo (máquina de estados).
##
##   IDLE   — de guarda, olhando em volta.
##   ALERT  — ouviu tiros ou um companheiro avisou: procura cobertura, observa, investiga.
##   COMBAT — sabe onde o jogador está:
##              TO_COVER → HIDING ⇄ PEEKING (esconde, sai, atira 1–2 vezes, volta)
##              OPEN     — sem cobertura: atira de pé e tenta achar cobertura de tempos em tempos
##              SEEKING  — perdeu o jogador de vista: vai até a última posição conhecida
##              ASSAULT  — (soldado agressivo) avança direto até perto do jogador, atirando
##   DEAD
##
## Em qualquer estado, uma granada caindo perto faz o soldado largar tudo e correr.
## Com granadas, joga uma no jogador que fica muito tempo escondido na mesma cobertura.
##
## Outros tipos de inimigo (metralhador, oficial) podem ter outro "cérebro" com o mesmo corpo.

signal state_changed(state: State)

const MELEE_SOUND := preload("res://assets/audio/provisorio/impacto_corpo.wav")

enum State { IDLE, ALERT, COMBAT, DEAD }
enum Combat { TO_COVER, HIDING, PEEKING, OPEN, SEEKING, ASSAULT }

## Raio em que este soldado avisa os companheiros ao entrar em combate.
@export var share_contact_radius := 40.0
## Avança sobre o jogador em vez de procurar cobertura (trincheiras, combate de perto).
@export var aggressive := false
## Granadas de haste que pode lançar.
@export var grenades := 0
## Distância em que o soldado agressivo para de avançar e atira.
@export var assault_stop_distance := 6.0

var state := State.IDLE
var combat := Combat.OPEN
var cover: CoverPoint

var body: EnemySoldier
var data: EnemyData
var perception: Perception

var _timer := 0.0
var _next_shot := 0.0
var _shots_left := 0
var _aim_time := 0.0
var _unseen_peeks := 0
var _alert_position := Vector3.ZERO
var _home_yaw := 0.0
var _retarget := 0.0
var _flee_time := 0.0
var _grenade_check := 0.0
var _grenade_cooldown := 8.0
var _melee_cooldown := 0.0


func setup(soldier: EnemySoldier) -> void:
	body = soldier
	data = soldier.data
	perception = soldier.perception
	perception.heard_noise.connect(_on_heard_noise)
	_home_yaw = body.rotation.y


func _physics_process(delta: float) -> void:
	if body == null or state == State.DEAD:
		return
	perception.update(delta, state != State.IDLE)
	if _update_grenade_danger(delta):
		return
	match state:
		State.IDLE:
			_update_idle(delta)
		State.ALERT:
			_update_alert(delta)
		State.COMBAT:
			_update_combat(delta)


# --- Eventos ---------------------------------------------------------------------

func on_hit(hit: HitInfo) -> void:
	if state != State.COMBAT:
		perception.awareness = 1.0
		if hit.source is Node3D:
			perception.last_known_position = (hit.source as Node3D).global_position
		_enter_combat()
		return
	# Atrapalha a mira; às vezes recua para a cobertura.
	_next_shot += 0.7
	_aim_time *= 0.5
	if cover and combat in [Combat.PEEKING, Combat.OPEN] and randf() < 0.5:
		_set_combat(Combat.HIDING)


func on_ally_contact(position: Vector3) -> void:
	if state == State.IDLE:
		perception.last_known_position = position
		perception.awareness = maxf(perception.awareness, 0.6)
		_enter_alert(position)


func on_died() -> void:
	_release_cover()
	_set_state(State.DEAD)


func _on_heard_noise(position: Vector3) -> void:
	if state == State.IDLE:
		_enter_alert(position)
	elif state == State.ALERT:
		_alert_position = position


# --- IDLE ------------------------------------------------------------------------

func _update_idle(delta: float) -> void:
	if perception.awareness >= 1.0:
		_enter_combat()
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(3.0, 6.0)
		var yaw := _home_yaw + deg_to_rad(randf_range(-35.0, 35.0))
		body.face(body.global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 10.0)


# --- ALERT -----------------------------------------------------------------------

func _enter_alert(position: Vector3) -> void:
	_alert_position = position
	_timer = 0.0
	_set_state(State.ALERT)


func _update_alert(delta: float) -> void:
	if perception.can_see_target:
		_enter_combat()
		return
	_timer += delta
	body.face(_alert_position)

	if _timer > 0.8 and cover == null and _timer < 12.0:
		var found := _find_cover(_alert_position)
		if found:
			_claim_cover(found)
			body.move_to(found.global_position, data.run_speed)
	if cover and body.has_arrived() and _timer < 12.0:
		# Na cobertura: abaixado, levantando de vez em quando para olhar.
		body.set_crouched(fmod(_timer, 4.0) < 2.5)
	if _timer >= 12.0 and _timer - delta < 12.0:
		_release_cover()
		body.set_crouched(false)
		body.move_to(_alert_position, data.walk_speed)
	if _timer > 30.0:
		_home_yaw = body.rotation.y
		_timer = 0.0
		_set_state(State.IDLE)


# --- COMBAT ----------------------------------------------------------------------

func _enter_combat() -> void:
	_set_state(State.COMBAT)
	_share_contact()
	_choose_position()


func _choose_position() -> void:
	if aggressive:
		_release_cover()
		_set_combat(Combat.ASSAULT)
		return
	var found := _find_cover(perception.last_known_position)
	if found:
		_claim_cover(found)
		body.set_crouched(false)
		body.move_to(found.global_position, data.run_speed)
		_set_combat(Combat.TO_COVER)
	else:
		_release_cover()
		_set_combat(Combat.OPEN)


func _set_combat(value: Combat) -> void:
	combat = value
	_timer = 0.0
	match combat:
		Combat.TO_COVER:
			body.face(null)
			body.set_aiming(false)
		Combat.HIDING:
			body.stop()
			body.set_crouched(true)
			body.set_aiming(false)
			_timer = randf_range(data.hide_time_min, data.hide_time_max)
		Combat.PEEKING:
			body.set_crouched(false)
			body.set_aiming(true)
			_shots_left = randi_range(data.shots_per_peek_min, data.shots_per_peek_max)
			_next_shot = data.reaction_time * randf_range(0.8, 1.4)
		Combat.OPEN:
			body.stop()
			body.set_crouched(false)
			body.set_aiming(true)
			_next_shot = data.reaction_time * randf_range(0.8, 1.4)
			_retarget = 3.0
		Combat.SEEKING:
			_release_cover()
			body.set_crouched(false)
			body.set_aiming(true)
			body.move_to(perception.last_known_position, data.walk_speed)
		Combat.ASSAULT:
			body.set_crouched(false)
			body.set_aiming(true)
			_next_shot = data.reaction_time * randf_range(0.6, 1.0)
			_retarget = 0.0


func _update_combat(delta: float) -> void:
	var target := perception.target
	if target == null or target.is_dead:
		body.set_aiming(false)
		return

	_grenade_cooldown -= delta
	if grenades > 0 and _grenade_cooldown <= 0.0 and combat in [Combat.HIDING, Combat.PEEKING, Combat.OPEN]:
		_try_throw_grenade(target)

	match combat:
		Combat.TO_COVER:
			if body.has_arrived():
				_set_combat(Combat.HIDING)

		Combat.ASSAULT:
			# Avança até perto; lá, para e atira. Volta a avançar se o jogador recua.
			var distance := body.global_position.distance_to(target.global_position)
			_melee_cooldown -= delta
			if distance < 1.8:
				body.stop()
				body.face(target.global_position)
				if _melee_cooldown <= 0.0 and body.is_facing(target.global_position, 35.0):
					_melee(target)
				return
			_retarget -= delta
			if _retarget <= 0.0:
				_retarget = 1.0
				var close := distance <= assault_stop_distance and perception.can_see_target
				if close or distance < 2.5:
					body.stop()
				else:
					body.move_to(perception.last_known_position, data.run_speed)
			_engage(delta, target)

		Combat.HIDING:
			if cover == null:
				_choose_position()
				return
			body.face(perception.last_known_position)
			_timer -= delta
			if _timer <= 0.0:
				var head := perception.last_known_position + Vector3.UP * 1.5
				if not cover.protects_from(head, []):
					_choose_position()  # o jogador flanqueou: procurar outra cobertura
				else:
					_set_combat(Combat.PEEKING)

		Combat.PEEKING:
			if _engage(delta, target):
				if _shots_left <= 0:
					_unseen_peeks = 0
					_set_combat(Combat.HIDING)
			elif _timer > 2.0:
				_unseen_peeks += 1
				_set_combat(Combat.SEEKING if _unseen_peeks >= 3 else Combat.HIDING)

		Combat.OPEN:
			_engage(delta, target)
			_retarget -= delta
			if _retarget <= 0.0:
				_retarget = 3.0
				var found := _find_cover(perception.last_known_position)
				if found:
					_choose_position()
					return
			if perception.time_since_seen > 3.0:
				_set_combat(Combat.SEEKING)

		Combat.SEEKING:
			body.face(perception.last_known_position)
			if perception.can_see_target:
				_unseen_peeks = 0
				_choose_position()
			elif body.has_arrived():
				_alert_position = perception.last_known_position
				perception.awareness = 0.5
				_timer = 12.0  # pula direto para a fase de investigar/voltar à guarda
				_set_state(State.ALERT)


## Mira e atira quando possível. Devolve se está vendo o alvo.
func _engage(delta: float, target: PlayerController) -> bool:
	body.face(perception.last_known_position)
	if not perception.can_see_target:
		_aim_time = maxf(_aim_time - delta * 2.0, 0.0)
		_timer += delta
		return false
	_timer = 0.0
	_aim_time += delta
	_next_shot -= delta
	if _next_shot <= 0.0 and body.is_facing(target.global_position):
		body.fire_at(target, _aim_time)
		_shots_left -= 1
		_next_shot = randf_range(data.fire_interval_min, data.fire_interval_max)
	return true


## Coronhada: dano alto de perto, empurra a câmera do jogador.
func _melee(target: PlayerController) -> void:
	_melee_cooldown = 1.6
	if body.visual.has_method(&"flinch"):
		body.visual.flinch(Vector3.FORWARD)  # tranco do corpo no golpe
	await get_tree().create_timer(0.25).timeout
	if state == State.DEAD or target.is_dead:
		return
	if body.global_position.distance_to(target.global_position) > 2.1:
		return
	var hit := HitInfo.new()
	hit.damage = 34.0
	hit.position = target.global_position + Vector3.UP * 1.3
	hit.direction = (target.global_position - body.global_position).normalized()
	hit.impulse = 6.0
	hit.source = body
	target.apply_hit(hit)
	target.camera.add_trauma(0.55)
	OneShotSound.play(body, MELEE_SOUND, hit.position, 0.0, 6.0)


# --- Granadas --------------------------------------------------------------------

## Granada (de qualquer lado) caindo perto: corre para longe dela. Devolve true
## enquanto está fugindo (o resto do comportamento espera).
func _update_grenade_danger(delta: float) -> bool:
	if _flee_time > 0.0:
		_flee_time -= delta
		if _flee_time <= 0.0 and state == State.COMBAT:
			_choose_position()
		return _flee_time > 0.0
	_grenade_check -= delta
	if _grenade_check > 0.0:
		return false
	_grenade_check = 0.2
	for node in get_tree().get_nodes_in_group(&"grenades"):
		var grenade := node as Grenade
		if grenade == null or grenade.thrower == body or grenade.time_left() < 0.4:
			continue
		var away := body.global_position - grenade.global_position
		away.y = 0.0
		if away.length() > 7.0:
			continue
		var dir := away.normalized() if away.length() > 0.1 else -body.global_basis.z
		var map := body.get_world_3d().navigation_map
		var safe := NavigationServer3D.map_get_closest_point(map, body.global_position + dir * 9.0)
		_release_cover()
		body.set_crouched(false)
		body.set_aiming(false)
		body.move_to(safe, data.run_speed * 1.15)
		_flee_time = minf(grenade.time_left() + 0.6, 4.0)
		if state != State.COMBAT:
			perception.awareness = 1.0
			_set_state(State.COMBAT)
		return true
	return false


## Joga uma granada de haste na última posição do jogador se ele está escondido há um
## tempo, nem perto nem longe demais, e o arremesso não bate num obstáculo logo à frente.
func _try_throw_grenade(target: PlayerController) -> void:
	if perception.time_since_seen < 3.5 or perception.time_since_seen > 15.0:
		return
	var to := perception.last_known_position
	var distance := body.global_position.distance_to(to)
	if distance < 9.0 or distance > 26.0:
		return
	_grenade_cooldown = randf_range(14.0, 20.0)
	grenades -= 1
	body.stop()
	body.face(to)
	body.set_crouched(false)
	if body.visual.has_method(&"play_throw"):
		body.visual.play_throw()
	await get_tree().create_timer(0.75).timeout
	if state == State.DEAD or not is_instance_valid(body):
		return
	var from := body.global_position + Vector3.UP * 1.7 - body.global_basis.z * 0.3
	var flight := clampf(distance / 13.0, 0.9, 1.9)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var aim := to + Vector3(randf_range(-1.5, 1.5), 0.2, randf_range(-1.5, 1.5))
	var velocity := (aim - from - 0.5 * Vector3.DOWN * gravity * flight * flight) / flight
	var grenade := Grenade.new()
	grenade.german = true
	grenade.fuse = 4.5
	grenade.max_damage = 150.0
	body.get_tree().current_scene.add_child(grenade)
	grenade.throw(from, velocity, body)
	EventBus.narrative_event.emit("granada_inimiga")


# --- Cobertura -------------------------------------------------------------------

func _find_cover(threat: Vector3) -> CoverPoint:
	var head := threat + Vector3.UP * 1.5
	var best: CoverPoint = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"cover_points"):
		var point := node as CoverPoint
		if not point.is_free_for(body):
			continue
		var distance := point.global_position.distance_to(body.global_position)
		if distance > data.cover_search_radius or point.global_position.distance_to(threat) < 6.0:
			continue
		if not point.protects_from(head, []):
			continue
		# Prefere pontos próximos e de onde dá para atirar.
		var score := distance + (0.0 if point.can_shoot_from(head, []) else 20.0)
		if score < best_score:
			best_score = score
			best = point
	return best


func _claim_cover(point: CoverPoint) -> void:
	_release_cover()
	cover = point
	cover.occupant = body


func _release_cover() -> void:
	if cover and cover.occupant == body:
		cover.occupant = null
	cover = null


func _share_contact() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var ally := node as EnemySoldier
		if ally == body or ally.is_dead:
			continue
		if ally.global_position.distance_to(body.global_position) <= share_contact_radius:
			ally.brain.on_ally_contact(perception.last_known_position)


func _set_state(value: State) -> void:
	if state == value:
		return
	state = value
	state_changed.emit(state)
