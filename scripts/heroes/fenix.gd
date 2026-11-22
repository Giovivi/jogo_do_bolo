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
	var color := Color(1.0, 0.55, 0.2, 0.55) if not finisher else Color(1.0, 0.3, 0.1, 0.75)
	Game.flash_cone(global_position, facing, s.claw_range, s.claw_arc_degrees, color, 0.12)
	var hit_any := false
	for e in Game.living_enemies():
		var enemy := e as Actor
		if enemy.flying:
			continue # garras não alcançam drones
		if Game.in_cone(global_position, facing, enemy.global_position, s.claw_range, s.claw_arc_degrees, enemy.body_radius):
			var info := {
				"knockback": s.finisher_knockback if finisher else 1.5,
				"dir": facing,
				"heavy": finisher,
				"ability": false,
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
	ability_lock = 0.25
	Game.flash_cone(global_position, facing, s.wings_range, s.wings_arc_degrees, Color(1.0, 0.35, 0.05, 0.7), 0.35)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.in_cone(global_position, facing, enemy.global_position, s.wings_range, s.wings_arc_degrees, enemy.body_radius):
			deal_damage(enemy, s.wings_damage, {"knockback": 3.0, "dir": facing, "ability": true, "heavy": true, "color": Color(1, 0.6, 0.2)})
	return true


# ---------------------------------------------------------------- E: Chama Azul

func blue_flame(aim: Vector3, use_mouse: bool, forced_target: Hero = null) -> bool:
	if not cooldown_ready("e"):
		return false
	var s := _fx()
	var target: Hero = forced_target
	if target == null and use_mouse and Game.party != null:
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
	ability_lock = 0.2
	target.heal(s.heal_amount)
	Game.flash_ring(target.global_position, 1.2, Color(0.3, 0.6, 1.0, 0.7), 0.5)
	Game.damage_number(target.global_position, "+%d" % int(s.heal_amount), Color(0.4, 0.8, 1.0))
	if target != self:
		Game.flash_line(global_position, target.global_position, 0.25, Color(0.3, 0.6, 1.0, 0.6), 0.3)
	return true


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
	busy = true
	invulnerable = true
	ability_lock = s.dive_time + 0.1
	var start := global_position
	var tw := create_tween()
	tw.tween_method(_dive_step.bind(start, dest), 0.0, 1.0, s.dive_time)
	tw.tween_callback(_dive_land)
	return true


func _dive_step(t: float, start: Vector3, dest: Vector3) -> void:
	var pos := start.lerp(dest, t)
	pos.y = start.y + sin(t * PI) * 4.0
	global_position = pos


func _dive_land() -> void:
	var s := _fx()
	busy = false
	invulnerable = false
	global_position.y = 0.05
	Game.flash_ring(global_position, s.dive_radius, Color(1.0, 0.4, 0.1, 0.8), 0.5)
	Game.hitstop()
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.flat_distance(enemy.global_position, global_position) <= s.dive_radius + enemy.body_radius:
			deal_damage(enemy, s.dive_damage, {"knockback": 8.0, "ability": true, "color": Color(1, 0.5, 0.1)})
	if Game.is_over_gap(global_position):
		_fall_into_gap()


# ---------------------------------------------------------------- passivas

func _on_health_depleted(_source: Node) -> void:
	if not rebirth_used:
		rebirth_used = true
		var s := _fx()
		health = max_health * s.rebirth_health_fraction
		_update_bar()
		Game.flash_ring(global_position, s.rebirth_radius, Color(1.0, 0.6, 0.1, 0.85), 0.6)
		Game.message("Renascer! O Fênix volta com metade da vida (1x por fase).", 2.5)
		Game.hitstop()
		for e in Game.living_enemies():
			var enemy := e as Actor
			if Game.flat_distance(enemy.global_position, global_position) <= s.rebirth_radius + enemy.body_radius:
				deal_damage(enemy, s.rebirth_damage, {"knockback": 7.0, "ability": true, "color": Color(1, 0.5, 0.1)})
		return
	go_down()


func _process_regen(delta: float) -> void:
	var s := _fx()
	if health < max_health and _time - last_combat_time >= s.regen_delay:
		heal(s.regen_per_second * delta)


# ---------------------------------------------------------------- planar

func try_dash(move: Vector3) -> void:
	var dir := move if move.length() > 0.1 else facing
	dir.y = 0.0
	if Game.gap_ahead(global_position, dir, 1.5):
		_start_glide(dir.normalized())
		return
	super.try_dash(move)


func _start_glide(dir: Vector3) -> void:
	_gliding = true
	busy = true
	_glide_dir = dir
	_glide_travelled = 0.0
	collision_mask = Game.MASK_HERO_GLIDING
	visual.scale = Vector3(1.5, 0.6, 1.0)


func _process_busy(delta: float) -> void:
	if not _gliding:
		return
	var s := _fx()
	var holding := Input.is_action_pressed("dash") if controlled else true
	var step := s.glide_speed * delta
	velocity = _glide_dir * s.glide_speed
	move_and_slide()
	_glide_travelled += step
	var over_gap := Game.is_over_gap(global_position)
	var done := (not holding) or _glide_travelled >= s.glide_max_distance or (not over_gap and _glide_travelled > 1.5)
	if done:
		_gliding = false
		busy = false
		collision_mask = Game.MASK_HERO
		visual.scale = Vector3.ONE
		if Game.is_over_gap(global_position):
			_fall_into_gap()
		else:
			last_safe_position = global_position


func go_down() -> void:
	_gliding = false
	super.go_down()


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
