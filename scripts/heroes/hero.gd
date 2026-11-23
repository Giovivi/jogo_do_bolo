class_name Hero
extends Actor
## Base dos heróis jogáveis: movimento, mira, dash, barra do especial,
## queda/reanimação e IA simples de aliado (seções 3, 5 e 6 da especificação).

signal downed(hero: Hero)
signal revived(hero: Hero)

enum AIState { FOLLOW, ATTACK, RETURN, REVIVE }

const GRAVITY := 40.0
const COYOTE_TIME := 0.12
## Abaixo desta altura o herói caiu num vão.
const FALL_LIMIT_Y := -2.5

@export var stats: HeroStats

var party_index: int = 0
var in_party: bool = true
var controlled: bool = false

var special: float = 0.0
var cooldowns: Dictionary = {}
var move_multiplier: float = 1.0
## Tempo em que o herói não pode dar dash (habilidades em uso).
var ability_lock: float = 0.0
## Movimento totalmente tomado por uma ação (dash, mergulho, planar).
var busy: bool = false

var last_combat_time: float = -100.0
var last_safe_position: Vector3 = Vector3.ZERO
var revive_progress: float = 0.0

var ai_state: AIState = AIState.FOLLOW
var _ai_replan: float = 0.0
var _ai_waypoint: Vector3 = Vector3.ZERO
var _ai_far_time: float = 0.0

var _dash_time_left: float = 0.0
var _coyote: float = 0.0
var _air_dash_used: bool = false
## Pedido de pulo deste quadro (jogador ou IA).
var _wants_jump: bool = false
var _dash_velocity: Vector3 = Vector3.ZERO
## Interrompido por ataque forte (seção 3.6). O dash cancela.
var _stun_time: float = 0.0
## Cores do efeito no ponto do acerto: golpe comum e golpe forte/especial.
var impact_color: Color = Color(1, 1, 1, 0.9)
var impact_color_strong: Color = Color(1, 1, 1, 0.9)

var _select_ring: MeshInstance3D
var _down_marker: Node3D
var _down_label: Label3D
var _time: float = 0.0


func _ready() -> void:
	add_to_group("heroes")
	collision_layer = Game.LAYER_HEROES
	collision_mask = Game.MASK_HERO
	max_health = stats.max_health
	health = max_health
	build_body(stats.color, 1.7, 0.45)
	set_bar_color(Color(0.35, 0.95, 0.45))
	_build_select_ring()
	_build_down_marker()
	last_safe_position = global_position
	_ai_waypoint = global_position


func _build_select_ring() -> void:
	_select_ring = MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = 0.65
	m.outer_radius = 0.8
	_select_ring.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_select_ring.material_override = mat
	_select_ring.position.y = 0.05
	_select_ring.visible = false
	add_child(_select_ring)


func _build_down_marker() -> void:
	_down_marker = Node3D.new()
	_down_marker.visible = false
	add_child(_down_marker)
	var ring := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = Game.rules.revive_radius - 0.1
	m.outer_radius = Game.rules.revive_radius
	ring.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position.y = 0.05
	_down_marker.add_child(ring)
	_down_label = Label3D.new()
	_down_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_down_label.no_depth_test = true
	_down_label.font_size = 48
	_down_label.pixel_size = 0.01
	_down_label.outline_size = 10
	_down_label.position.y = 2.4
	# O aviso de caído e a reanimação aparecem no retrato do HUD, não em cima do herói.
	_down_label.visible = false
	_down_marker.add_child(_down_label)


func set_controlled(value: bool) -> void:
	controlled = value
	_select_ring.visible = value
	if value:
		ai_state = AIState.FOLLOW


# ---------------------------------------------------------------- laço principal

func _physics_process(delta: float) -> void:
	_time += delta
	tick_visual_feedback(delta)
	_tick_cooldowns(delta)
	if not in_party:
		velocity = Vector3.ZERO
		return
	if is_dead:
		_process_downed(delta)
		return
	_process_regen(delta)
	ability_lock = maxf(0.0, ability_lock - delta)

	var move := Vector3.ZERO
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_velocity
		if _dash_time_left <= 0.0:
			_end_dash()
		move_and_slide()
		return
	if busy:
		_process_busy(delta)
		return

	if _stun_time > 0.0:
		_stun_time -= delta
		if controlled and Input.is_action_just_pressed("dash"):
			_stun_time = 0.0
			var axes := Game.screen_axes()
			var input := Input.get_vector("move_left", "move_right", "move_down", "move_up")
			try_dash(axes[1] * input.x + axes[0] * input.y)
			if _dash_time_left > 0.0:
				return
	elif controlled:
		move = _process_player(delta)
	else:
		move = _process_ai(delta)

	var kb := apply_knockback(delta)
	var on_floor := is_on_floor()
	var speed := stats.move_speed * move_multiplier
	if not on_floor:
		speed *= stats.air_speed_multiplier
	var v := move * speed + kb
	var vy := velocity.y
	if on_floor:
		_coyote = COYOTE_TIME
		_air_dash_used = false
		if vy < 0.0:
			vy = 0.0
		_on_grounded()
	else:
		_coyote -= delta
		vy -= GRAVITY * delta
	if _wants_jump and _coyote > 0.0:
		vy = sqrt(2.0 * GRAVITY * stats.jump_height)
		_coyote = 0.0
	_wants_jump = false
	v.y = vy
	v = _air_motion(v, move, on_floor, delta)
	velocity = v
	move_and_slide()
	_after_move()


## Ganchos para o Fênix planar.
func _air_motion(v: Vector3, _move: Vector3, _on_floor: bool, _delta: float) -> Vector3:
	return v


func _on_grounded() -> void:
	pass


func jump() -> void:
	_wants_jump = true


func _after_move() -> void:
	if global_position.y < FALL_LIMIT_Y:
		_fall_into_gap()
	elif is_on_floor() and not Game.gap_ahead(global_position, Vector3.FORWARD, 0.6) \
			and not Game.gap_ahead(global_position, Vector3.BACK, 0.6) \
			and not Game.gap_ahead(global_position, Vector3.LEFT, 0.6) \
			and not Game.gap_ahead(global_position, Vector3.RIGHT, 0.6):
		last_safe_position = global_position


func _fall_into_gap() -> void:
	busy = false
	collision_mask = Game.MASK_HERO
	global_position = last_safe_position
	velocity = Vector3.ZERO
	var was_inv := invulnerable
	invulnerable = false
	take_damage(Game.rules.fall_damage, null, {"push": 0.0, "color": Color(1, 0.4, 0.4)})
	invulnerable = was_inv
	if controlled:
		Game.message("Caiu no vão! Pulo (Espaço) passa vãos de 2 m; os de 4 m só o Fênix, planando.", 3.0)


## Usado por ações que tomam o movimento (o Fênix usa para planar).
func _process_busy(_delta: float) -> void:
	pass


func _tick_cooldowns(delta: float) -> void:
	for k in cooldowns.keys():
		var v: float = cooldowns[k]
		if v > 0.0:
			cooldowns[k] = maxf(0.0, v - delta)


func cooldown_ready(key: String) -> bool:
	var v: float = cooldowns.get(key, 0.0)
	return v <= 0.0


func start_cooldown(key: String, seconds: float) -> void:
	cooldowns[key] = seconds


func cooldown_left(key: String) -> float:
	var v: float = cooldowns.get(key, 0.0)
	return v


func in_combat() -> bool:
	return _time - last_combat_time < 4.0


func _process_regen(_delta: float) -> void:
	pass


# ---------------------------------------------------------------- jogador

func _process_player(_delta: float) -> Vector3:
	var axes := Game.screen_axes()
	var input := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	var move := axes[1] * input.x + axes[0] * input.y
	if move.length() > 1.0:
		move = move.normalized()
	var aim := Game.mouse_ground_point(global_position.y)
	face_towards(aim)

	if Input.is_action_just_pressed("jump"):
		jump()

	if Input.is_action_just_pressed("dash"):
		try_dash(move)
	if Input.is_action_just_pressed("special"):
		if special >= stats.special_max:
			if use_special(aim):
				special = 0.0
		else:
			Game.message("Especial ainda não está cheio (%d/%d)." % [int(special), int(stats.special_max)], 1.5)
	_player_actions(aim, move)
	return move


## Cada herói trata o básico e as habilidades aqui.
func _player_actions(_aim: Vector3, _move: Vector3) -> void:
	pass


## Para o HUD: [tecla, nome, segundos restantes, recarga total]
func ability_slots() -> Array:
	return []


## Retorna true se o especial foi usado.
func use_special(_aim: Vector3) -> bool:
	return false


# ---------------------------------------------------------------- dash

func try_dash(move: Vector3) -> void:
	if ability_lock > 0.0 or not cooldown_ready("dash"):
		return
	var airborne := not is_on_floor()
	if airborne and _air_dash_used:
		return
	if Game.is_over_gap(global_position):
		return # sem dash em cima de um vão
	var dir := move
	if dir.length() < 0.1:
		dir = facing
	dir.y = 0.0
	dir = dir.normalized()
	# O dash para na beirada: não atravessa vãos (isso é do planar).
	var dist := stats.dash_distance
	var step := 0.25
	var d := step
	while d <= stats.dash_distance:
		if Game.is_over_gap(global_position + dir * d):
			dist = maxf(0.0, d - 0.5)
			break
		d += step
	if dist < 0.3:
		return
	if airborne:
		_air_dash_used = true
	start_cooldown("dash", stats.dash_cooldown)
	_dash_time_left = stats.dash_time * dist / stats.dash_distance
	_dash_velocity = dir * (stats.dash_distance / stats.dash_time)
	invulnerable = true
	_on_attack_cancelled()
	visual.scale = Vector3(0.8, 0.8, 1.3)


func _end_dash() -> void:
	invulnerable = false
	visual.scale = Vector3.ONE
	velocity = Vector3.ZERO


## O dash pode cancelar o fim de um ataque básico.
func _on_attack_cancelled() -> void:
	pass


# ---------------------------------------------------------------- dano e especial

func add_special(amount: float) -> void:
	special = minf(stats.special_max, special + amount)


## Dano causado por este herói: enche a barra e conta como combate.
func deal_damage(target: Actor, amount: float, info: Dictionary = {}) -> float:
	if target == null or target.is_dead:
		return 0.0
	var dealt := target.take_damage(amount, self, info)
	if dealt > 0.0:
		_impact_spark(target, info)
		add_special(dealt * stats.special_per_damage_dealt)
		last_combat_time = _time
	return dealt


## Faísca curta no ponto do acerto, na cor do herói.
func _impact_spark(target: Actor, info: Dictionary) -> void:
	var strength := Impact.strength_of(info)
	var at := target.global_position + Vector3(0, target.hover_offset + 0.9, 0)
	var from := global_position + Vector3(0, 0.9, 0)
	var toward := from - at
	toward.y = 0.0
	if toward.length() > 0.01:
		at += toward.normalized() * target.body_radius
	var m := SphereMesh.new()
	var r := 0.22 + 0.12 * float(strength)
	m.radius = r
	m.height = r * 2.0
	var c := impact_color if strength == Impact.WEAK else impact_color_strong
	var orb := Game.flash_shape(m, Transform3D(Basis.IDENTITY, at), c, 0.14 + 0.04 * float(strength))
	if orb != null:
		orb.create_tween().tween_property(orb, "scale", Vector3.ONE * 1.8, 0.14)


## Golpe comum dá um tranquinho; ataque forte interrompe (sem
## invulnerabilidade depois do golpe).
func _react_to_hit(strength: int, dir: Vector3, _source: Node, info: Dictionary, killed: bool) -> void:
	if killed or dir.length() < 0.01:
		return
	if strength >= Impact.STRONG:
		push(dir, info.get("push", Impact.PUSH_METERS[Impact.STRONG]))
		_stun_time = Impact.HERO_STUN_STRONG
		_on_interrupted()
	else:
		push(dir, info.get("push", Impact.HERO_JOLT_METERS))


## O herói foi interrompido: cada um cancela o que estava fazendo.
func _on_interrupted() -> void:
	_on_attack_cancelled()


func _on_damaged(amount: float, _source: Node) -> void:
	add_special(amount * stats.special_per_damage_taken)
	last_combat_time = _time


func _on_health_depleted(_source: Node) -> void:
	go_down()


func go_down() -> void:
	is_dead = true
	busy = false
	invulnerable = false
	_dash_time_left = 0.0
	visual.scale = Vector3.ONE
	collision_mask = Game.MASK_HERO
	revive_progress = 0.0
	visual.rotation.x = deg_to_rad(-80.0)
	visual.position.y = 0.3
	_down_marker.visible = true
	_update_bar()
	downed.emit(self)


func revive(fraction: float) -> void:
	is_dead = false
	health = max_health * fraction
	visual.rotation.x = 0.0
	visual.position.y = 0.0
	_down_marker.visible = false
	revive_progress = 0.0
	_update_bar()
	Game.flash_ring(global_position, 1.5, Color(1, 0.9, 0.4, 0.7), 0.4)
	revived.emit(self)


func _process_downed(delta: float) -> void:
	velocity = Vector3.ZERO
	var reviving := false
	if Game.party != null:
		for h in Game.party.living_heroes():
			if h == self:
				continue
			if Game.flat_distance(h.global_position, global_position) > Game.rules.revive_radius:
				continue
			if h.controlled:
				if Input.is_action_pressed("interact"):
					reviving = true
			else:
				reviving = true
	if reviving:
		revive_progress += delta
	else:
		revive_progress = 0.0
	var pct := int(100.0 * revive_progress / Game.rules.revive_time)
	if revive_progress > 0.0:
		_down_label.text = "Reanimando %d%%" % pct
	else:
		_down_label.text = "%s caído\nsegure F perto" % stats.display_name
	if revive_progress >= Game.rules.revive_time:
		revive(Game.rules.revive_health_fraction)


# ---------------------------------------------------------------- IA de aliado

func _process_ai(delta: float) -> Vector3:
	var m := _ai_decide(delta)
	return _ai_handle_ledges(m)


## A IA pula vãos curtos e beiradas quando o líder subiu; para na beira de
## vãos que não consegue passar (o reagrupar resolve se ela ficar para trás).
func _ai_handle_ledges(m: Vector3) -> Vector3:
	if m.length() < 0.1 or not is_on_floor():
		return m
	var dir := Vector3(m.x, 0.0, m.z).normalized()
	if Game.gap_ahead(global_position, dir, 1.0):
		var land := global_position + dir * 2.4
		if not Game.is_over_gap(land) and not Game.is_over_gap(land + dir * 0.5):
			jump()
			return m
		return Vector3.ZERO
	if is_on_wall() and Game.party != null and Game.party.controlled_hero != null:
		var leader: Hero = Game.party.controlled_hero
		if leader.global_position.y > global_position.y + 0.4 or _ai_waypoint.y > global_position.y + 0.4:
			jump()
	return m


func _ai_decide(delta: float) -> Vector3:
	var party := Game.party
	if party == null:
		return Vector3.ZERO
	var leader: Hero = party.controlled_hero
	if leader == null or leader == self:
		return Vector3.ZERO
	var rules := Game.rules
	var dist_leader := Game.flat_distance(global_position, leader.global_position)

	# Reagrupar se ficar muito para trás (por exemplo, do outro lado de um vão).
	if dist_leader > rules.ai_regroup_distance:
		_ai_far_time += delta
		if _ai_far_time > 2.5:
			_ai_far_time = 0.0
			global_position = party.point_behind_leader()
			velocity = Vector3.ZERO
			return Vector3.ZERO
	else:
		_ai_far_time = 0.0

	var downed_ally: Hero = party.downed_ally_to_revive(self)
	if downed_ally != null:
		ai_state = AIState.REVIVE
		if Game.flat_distance(global_position, downed_ally.global_position) > rules.revive_radius * 0.6:
			var m := navigate_to(downed_ally.global_position, delta)
			_face_move(m)
			return m
		face_towards(downed_ally.global_position)
		return Vector3.ZERO

	if dist_leader > rules.ai_leash_radius:
		ai_state = AIState.RETURN
	elif ai_state == AIState.RETURN and dist_leader < rules.ai_follow_max:
		ai_state = AIState.FOLLOW
	elif ai_state == AIState.REVIVE:
		ai_state = AIState.FOLLOW

	var target: Actor = null
	if ai_state != AIState.RETURN:
		target = _nearest_enemy(rules.ai_engage_radius)
		ai_state = AIState.ATTACK if target != null else AIState.FOLLOW

	match ai_state:
		AIState.ATTACK:
			return _separate(_ai_combat(target, delta))
		AIState.RETURN:
			var m := navigate_to(leader.global_position, delta)
			_face_move(m)
			return m
		_:
			if dist_leader > rules.ai_follow_max:
				var m := navigate_to(leader.global_position, delta)
				_face_move(m)
				return _separate(m)
			if dist_leader < rules.ai_follow_min:
				var away := global_position - leader.global_position
				away.y = 0.0
				return away.normalized() * 0.5
			return _separate(Vector3.ZERO)


## Cada herói define como luta quando controlado pela IA.
func _ai_combat(_target: Actor, _delta: float) -> Vector3:
	return Vector3.ZERO


func _nearest_enemy(radius: float) -> Actor:
	var best: Actor = null
	var best_d := radius
	for e in Game.living_enemies():
		var enemy := e as Actor
		if enemy == null or not enemy.get("active"):
			continue
		var d := Game.flat_distance(global_position, enemy.global_position)
		if d < best_d and Game.has_line_of_sight(global_position, enemy.global_position):
			best = enemy
			best_d = d
	return best


func _face_move(m: Vector3) -> void:
	if m.length() > 0.1:
		face_towards(global_position + m)


func _separate(m: Vector3) -> Vector3:
	var push := Vector3.ZERO
	if Game.party == null:
		return m
	for h in Game.party.living_heroes():
		if h == self:
			continue
		var d := global_position - h.global_position
		d.y = 0.0
		var l := d.length()
		if l < 1.4 and l > 0.01:
			push += d.normalized() * (1.4 - l)
	return m + push


## Caminho simples: em linha reta se der para ver o alvo; senão segue a
## trilha de pegadas do herói controlado.
func navigate_to(target: Vector3, delta: float) -> Vector3:
	_ai_replan -= delta
	if _ai_replan <= 0.0:
		_ai_replan = 0.25
		_ai_waypoint = _pick_waypoint(target)
	var d := _ai_waypoint - global_position
	d.y = 0.0
	if d.length() < 0.3:
		_ai_replan = 0.0
		return Vector3.ZERO
	return d.normalized()


func _clear_path(a: Vector3, b: Vector3) -> bool:
	var from := Vector3(a.x, 0.8, a.z)
	var to := Vector3(b.x, 0.8, b.z)
	return Game.raycast_world(from, to, Game.LAYER_WORLD | Game.LAYER_GAPS | Game.LAYER_WALKWAY).is_empty()


func _pick_waypoint(target: Vector3) -> Vector3:
	if _clear_path(global_position, target):
		return target
	var crumbs: Array[Vector3] = Game.party.breadcrumbs
	for i in range(crumbs.size() - 1, -1, -1):
		var c := crumbs[i]
		if _clear_path(global_position, c):
			return c
	var best := target
	var best_d := INF
	for c in crumbs:
		var d := global_position.distance_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best
