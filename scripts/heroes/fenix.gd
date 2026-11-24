class_name Fenix
extends Hero
## Fênix: corpo a corpo rápido. Garras, Asas de Fogo, Chama Azul,
## Mergulho da Ave, Renascer, Regeneração e Planar.

var rebirth_used: bool = false

var _combo_step: int = 0
var _combo_timer: float = 0.0
var _gliding: bool = false
var _glide_dir: Vector3 = Vector3.ZERO
var _glide_travelled: float = 0.0
var model: FenixModel

## Tempos da Chama Azul e do Mergulho da Ave (o mergulho em si usa dive_time).
const ABSORB_TIME := 0.55
const DIVE_CHARGE := 0.4
const DIVE_RISE := 0.3


func _ready() -> void:
	super._ready()
	_use_model()
	# Chama dourada no golpe comum, azul no forte.
	impact_color = Color(1.0, 0.8, 0.3, 0.9)
	impact_color_strong = Color(0.35, 0.65, 1.0, 0.9)


## Troca a cápsula provisória pelo modelo 3D (a colisão continua a mesma).
func _use_model() -> void:
	for child in visual.get_children():
		if child is MeshInstance3D:
			child.visible = false
	model = FenixModel.new()
	model.hero = self
	visual.add_child(model)
	model.add_hand_fire()


func _fx() -> FenixStats:
	return stats as FenixStats


func _physics_process(delta: float) -> void:
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0:
		_combo_step = 0
	super._physics_process(delta)


# ---------------------------------------------------------------- jogador

func _player_actions(aim: Vector3, _move: Vector3) -> void:
	if Input.is_action_pressed("attack"):
		claw_attack()
	if Input.is_action_just_pressed("ability_1"):
		fire_wings()
	if Input.is_action_just_pressed("ability_2"):
		blue_flame(aim, true)


func ability_slots() -> Array:
	var s := _fx()
	return [
		["Clique", "Garras (combo %d/3)" % (_combo_step % 3 + 1), 0.0, 0.0],
		["Q", "Asas de Fogo", cooldown_left("q"), s.q_cooldown],
		["E", "Chama Azul", cooldown_left("e"), s.e_cooldown],
		["R", "Mergulho da Ave", 0.0, 0.0],
		["Shift", "Dash / Planar", cooldown_left("dash"), s.dash_cooldown],
		["Passiva", "Renascer: " + ("usado" if rebirth_used else "pronto"), 0.0, 0.0],
	]


# ---------------------------------------------------------------- garras

func claw_attack() -> bool:
	if not cooldown_ready("basic") or ability_lock > 0.0:
		return false
	var s := _fx()
	var step := _combo_step % s.combo_damage.size()
	var dmg := s.combo_damage[step]
	var finisher := step == s.combo_damage.size() - 1
	start_cooldown("basic", s.combo_interval * (1.6 if finisher else 1.0))
	_combo_step = step + 1
	_combo_timer = s.combo_reset_time
	model.play_once("Sword_Attack" if finisher else ("Punch_Jab" if step % 2 == 0 else "Punch_Cross"), 1.6)
	# Fogo azul na mão que bate (esquerda no jab, direita no cruzado); no golpe
	# final as duas acendem e abre a onda de fogo no chão.
	if finisher:
		model.ignite_hands("LR", 0.55, true)
	else:
		model.ignite_hands("L" if step % 2 == 0 else "R", 0.3)
	var color := Color(1.0, 0.55, 0.2, 0.55) if not finisher else Color(1.0, 0.3, 0.1, 0.75)
	Game.flash_cone(global_position, facing, s.claw_range, s.claw_arc_degrees, color, 0.12)
	var hit_any := false
	for e in Game.living_enemies():
		var enemy := e as Actor
		# Garras alcançam até 1,5 m de altura: drones só pulando junto.
		if not Game.vertical_ok(global_position.y, enemy, Game.REACH_MELEE):
			continue
		if Game.in_cone(global_position, facing, enemy.global_position, s.claw_range, s.claw_arc_degrees, enemy.body_radius):
			var info := {
				"strength": Impact.STRONG if finisher else Impact.WEAK,
				"dir": facing,
				"ability": false,
				"melee": true,
				"combo": step,
			}
			deal_damage(enemy, dmg, info)
			hit_any = true
	return hit_any


func _on_attack_cancelled() -> void:
	_combo_step = 0


# ---------------------------------------------------------------- Q: Asas de Fogo

func fire_wings() -> bool:
	if not cooldown_ready("q") or ability_lock > 0.0:
		return false
	var s := _fx()
	start_cooldown("q", s.q_cooldown)
	ability_lock = 0.3
	model.play_once("Spell_Simple_Shoot", 1.4)
	# Asas de fogo abrem das costas e batem para a frente soltando o cone.
	FenixFX.wings(self, facing, s.wings_range, s.wings_arc_degrees)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.in_cone(global_position, facing, enemy.global_position, s.wings_range, s.wings_arc_degrees, enemy.body_radius) \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			deal_damage(enemy, s.wings_damage, {"strength": Impact.STRONG, "dir": facing, "ability": true, "color": Color(1, 0.6, 0.2)})
	return true


# ---------------------------------------------------------------- E: Chama Azul

func blue_flame(aim: Vector3, use_mouse: bool, forced_target: Hero = null) -> bool:
	if not cooldown_ready("e"):
		return false
	var s := _fx()
	var target: Hero = forced_target
	if target == null and use_mouse and Game.party != null and Game.rules.camera_behind and not Game.rules.behind_reticle:
		# Câmera atrás: o aliado mais perto na frente do Fênix.
		var allies: Array = []
		for h in Game.party.living_heroes():
			if h != self:
				allies.append(h)
		target = Game.front_pick(global_position, facing, 10.0, allies) as Hero
	elif target == null and use_mouse and Game.party != null:
		var best_d := s.heal_pick_radius
		for h in Game.party.living_heroes():
			if h == self:
				continue
			var d := Game.flat_distance(h.global_position, aim)
			if d < best_d:
				best_d = d
				target = h
	if target == null:
		target = self
	start_cooldown("e", s.e_cooldown)
	# Suga o fogo em volta para dentro do peito; a cura sai no fim.
	ability_lock = ABSORB_TIME
	model.play_once("Spell_Simple_Shoot", 0.7)
	FenixFX.absorb(self, ABSORB_TIME)
	get_tree().create_timer(ABSORB_TIME).timeout.connect(_finish_blue_flame.bind(target, s.heal_amount))
	return true


func _finish_blue_flame(target: Hero, amount: float) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return
	target.heal(amount)
	if target != self:
		FenixFX.heal_link(self, target)


# ---------------------------------------------------------------- R: Mergulho da Ave

func use_special(aim: Vector3) -> bool:
	var s := _fx()
	var to := aim - global_position
	to.y = 0.0
	if to.length() > s.dive_max_distance:
		to = to.normalized() * s.dive_max_distance
	var dest := global_position + to
	# Não atravessa paredes: para antes delas.
	var hit := Game.raycast_world(global_position + Vector3.UP, dest + Vector3.UP)
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		var back := (global_position - p)
		back.y = 0.0
		dest = Vector3(p.x, global_position.y, p.z) + back.normalized() * 0.8
	# Pousa na altura do chão de destino (plataforma, chão ou vão).
	# O raio nasce pouco acima da plataforma mais alta (2 m), abaixo do teto.
	var down := Game.raycast_world(Vector3(dest.x, global_position.y + 2.6, dest.z), dest + Vector3(0, -6, 0), Game.LAYER_WORLD | Game.LAYER_WALKWAY)
	if not down.is_empty():
		var g: Vector3 = down["position"]
		dest.y = g.y + 0.05
	busy = true
	invulnerable = true
	velocity = Vector3.ZERO
	ability_lock = DIVE_CHARGE + DIVE_RISE + s.dive_time + 0.15
	# 1. Carga: agacha fazendo força, o fogo junta nos pés.
	model.play_once("Jump_Start", 0.0)
	FenixFX.charge(self, DIVE_CHARGE)
	var tw := create_tween()
	tw.tween_interval(DIVE_CHARGE)
	# 2. Salto: o corpo sobe e sai da tela; a coluna de fogo fica para trás.
	tw.tween_callback(func() -> void:
		model.play_once("Jump_Start", 1.8)
		FenixFX.launch(global_position))
	tw.tween_property(visual, "position:y", 14.0, DIVE_RISE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# 3. Volta como fênix de fogo mergulhando no alvo (a câmera desliza junto).
	tw.tween_callback(func() -> void:
		visual.visible = false
		visual.position.y = 0.0
		global_position = dest
		FenixFX.phoenix(dest, s.dive_time))
	tw.tween_interval(s.dive_time)
	# 4. Impacto.
	tw.tween_callback(_dive_land)
	return true


func _dive_land() -> void:
	var s := _fx()
	busy = false
	invulnerable = false
	velocity = Vector3.ZERO
	visual.visible = true
	visual.position.y = 0.0
	model.play_once("Jump_Land", 1.3)
	FenixFX.impact(global_position, s.dive_radius)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.flat_distance(enemy.global_position, global_position) <= s.dive_radius + enemy.body_radius \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			var dir := enemy.global_position - global_position
			dir.y = 0.0
			deal_damage(enemy, s.dive_damage, {"strength": Impact.SPECIAL, "ability": true, "dir": dir, "color": Color(1, 0.5, 0.1)})


# ---------------------------------------------------------------- passivas

func _on_health_depleted(_source: Node) -> void:
	if not rebirth_used:
		rebirth_used = true
		var s := _fx()
		health = max_health * s.rebirth_health_fraction
		_update_bar()
		Game.flash_ring(global_position, s.rebirth_radius, Color(1.0, 0.6, 0.1, 0.85), 0.6)
		Game.message("Renascer! O Fênix volta com metade da vida (1x por fase).", 2.5)
		for e in Game.living_enemies():
			var enemy := e as Actor
			if Game.flat_distance(enemy.global_position, global_position) <= s.rebirth_radius + enemy.body_radius \
					and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
				deal_damage(enemy, s.rebirth_damage, {"strength": Impact.SPECIAL, "ability": true, "color": Color(1, 0.5, 0.1)})
		return
	go_down()


func _process_regen(delta: float) -> void:
	var s := _fx()
	if health < max_health and _time - last_combat_time >= s.regen_delay:
		heal(s.regen_per_second * delta)


# ---------------------------------------------------------------- planar

## No ar, caindo, segurar Espaço faz o Fênix planar: cai devagar e anda
## até glide_max_distance metros. Termina ao soltar, ao acabar a distância
## ou ao pousar.
func _air_motion(v: Vector3, move: Vector3, on_floor: bool, delta: float) -> Vector3:
	var s := _fx()
	var holding := controlled and Input.is_action_pressed("jump")
	if _gliding and (on_floor or not holding or _glide_travelled >= s.glide_max_distance):
		_end_glide()
	elif not _gliding and not on_floor and holding and v.y < 0.0 and _glide_travelled < s.glide_max_distance:
		_gliding = true
		_glide_dir = move if move.length() > 0.1 else facing
		_glide_dir.y = 0.0
		_glide_dir = _glide_dir.normalized()
		model.play_once("Jump", 0.6)
	if _gliding:
		if move.length() > 0.1:
			_glide_dir = _glide_dir.lerp(Vector3(move.x, 0.0, move.z).normalized(), clampf(4.0 * delta, 0.0, 1.0)).normalized()
		v.x = _glide_dir.x * s.glide_speed
		v.z = _glide_dir.z * s.glide_speed
		v.y = maxf(v.y, -s.glide_fall_speed)
		_glide_travelled += s.glide_speed * delta
	return v


func _end_glide() -> void:
	_gliding = false
	visual.scale = Vector3.ONE


## A distância do planar só volta ao pousar (um planar por pulo).
func _on_grounded() -> void:
	_glide_travelled = 0.0
	if _gliding:
		_end_glide()


func is_gliding() -> bool:
	return _gliding


func go_down() -> void:
	_end_glide()
	super.go_down()
	# O modelo tem animação de queda: não precisa deitar a cápsula.
	visual.rotation.x = 0.0
	visual.position.y = 0.0


func _on_damaged(amount: float, source: Node) -> void:
	super._on_damaged(amount, source)
	if not is_dead:
		model.play_once("Hit_Chest", 1.5)


# ---------------------------------------------------------------- IA

func _ai_combat(target: Actor, delta: float) -> Vector3:
	var s := _fx()
	# Cura quem estiver mais ferido.
	if cooldown_ready("e") and Game.party != null:
		var hurt: Hero = null
		var lowest := 0.6
		for h in Game.party.living_heroes():
			var f: float = h.health / h.max_health
			if f < lowest:
				lowest = f
				hurt = h
		if hurt != null:
			blue_flame(Vector3.ZERO, false, hurt)
	face_towards(target.global_position)
	var d := Game.flat_distance(global_position, target.global_position)
	if cooldown_ready("q") and d <= s.wings_range * 0.8:
		fire_wings()
	if target.flying:
		# Garras não alcançam drones: chega perto para usar as Asas de Fogo.
		if d > s.wings_range * 0.7:
			return navigate_to(target.global_position, delta)
		return Vector3.ZERO
	if d > s.claw_range * 0.8:
		return navigate_to(target.global_position, delta)
	claw_attack()
	return Vector3.ZERO
