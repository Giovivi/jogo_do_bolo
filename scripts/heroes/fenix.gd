class_name Fenix
extends Hero
## Fênix: corpo a corpo rápido. Garras, Asas de Fogo, Chama Azul,
## Mergulho da Ave, Renascer, Regeneração e Planar.
## A suprema (Mergulho da Ave) termina na Forma Fênix: por form_duration s
## ele vira uma ave de fogo com outro kit (Dança das Brasas, Tempestade de
## Penas, Investida Solar) e marca os inimigos com Brasa.

var rebirth_used: bool = false

var _combo_step: int = 0
var _combo_timer: float = 0.0
var _gliding: bool = false
var _glide_dir: Vector3 = Vector3.ZERO
var _glide_travelled: float = 0.0
var model: FenixModel

## Forma Fênix: segundos que faltam (0 = forma humana).
var form_time: float = 0.0
var form: PhoenixForm
## Fogo no chão que queima inimigos: [posição, raio, dano por s, tempo que falta].
var _burns: Array = []
var _burn_tick: float = 0.0
## Investida Solar / Mergulho da Fênix em andamento.
var _rush: Dictionary = {}

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
	_tick_burns(delta)
	if form_time > 0.0 and not is_dead:
		form_time = maxf(0.0, form_time - delta)
		# A barra do especial mostra o tempo que falta da forma.
		special = stats.special_max * form_time / _fx().form_duration
		if form_time <= 0.0:
			exit_form()
	super._physics_process(delta)


# ---------------------------------------------------------------- jogador

func _player_actions(aim: Vector3, _move: Vector3) -> void:
	if in_form():
		if Input.is_action_pressed("attack"):
			ember_dance()
		if Input.is_action_just_pressed("ability_1"):
			featherstorm()
		if Input.is_action_just_pressed("ability_2"):
			solar_rush()
		return
	if Input.is_action_pressed("attack"):
		claw_attack()
	if Input.is_action_just_pressed("ability_1"):
		fire_wings()
	if Input.is_action_just_pressed("ability_2"):
		blue_flame(aim, true)


func ability_slots() -> Array:
	var s := _fx()
	if in_form():
		return [
			["Clique", "Dança das Brasas (golpe %d/3)" % (_combo_step % 3 + 1), 0.0, 0.0],
			["Q", "Tempestade de Penas", cooldown_left("fq"), s.feather_cooldown],
			["E", "Investida Solar", cooldown_left("fe"), s.rush_cooldown],
			["R", "Forma Fênix (%d s)" % ceili(form_time), 0.0, 0.0],
			["Shift", "Dash", cooldown_left("dash"), s.dash_cooldown],
			["Passiva", "Renascer: " + ("usado" if rebirth_used else "pronto"), 0.0, 0.0],
		]
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
	# A ave não volta a ser humano: continua como fênix.
	enter_form()


# ---------------------------------------------------------------- Forma Fênix

func in_form() -> bool:
	return form_time > 0.0


func enter_form() -> void:
	var s := _fx()
	form_time = s.form_duration
	special = stats.special_max
	move_multiplier = s.form_move_speed / stats.move_speed
	_combo_step = 0
	cooldowns["fq"] = 0.0
	cooldowns["fe"] = 0.0
	model.visible = false
	if form == null:
		form = PhoenixForm.new()
		form.hero = self
		visual.add_child(form)
	if controlled:
		Game.message("Forma Fênix! Clique, Q e E mudaram por %d s." % int(s.form_duration), 2.5)


func exit_form() -> void:
	form_time = 0.0
	special = 0.0
	move_multiplier = 1.0
	_combo_step = 0
	if form != null:
		form.queue_free()
		form = null
	model.visible = true
	if not is_dead:
		Game.flash_ring(global_position, 1.6, Color(0.4, 0.7, 1.0, 0.8), 0.4)


## Durante a forma, a barra do especial não enche (ela mostra o tempo).
func add_special(amount: float) -> void:
	if in_form():
		return
	super.add_special(amount)


## Acerto de golpe do combo: dano e uma Brasa.
func _form_hit(enemy: Actor, amount: float, info: Dictionary, ember := true) -> void:
	if deal_damage(enemy, amount, info) > 0.0 and ember and not enemy.is_dead:
		var m := EmberMark.of(enemy)
		m.duration = _fx().ember_duration
		m.add(1, _fx().ember_max_stacks)


## Básico da forma: Corte Incandescente, Giro Flamejante, Mergulho da Fênix.
func ember_dance() -> bool:
	if not cooldown_ready("basic") or ability_lock > 0.0 or not _rush.is_empty():
		return false
	var s := _fx()
	var step := _combo_step % 3
	var dmg := s.form_combo_damage[step]
	_combo_step = step + 1
	_combo_timer = s.combo_reset_time
	var info := {"strength": Impact.WEAK, "dir": facing, "ability": false, "color": Color(0.4, 0.7, 1.0)}
	match step:
		0:
			start_cooldown("basic", s.form_combo_interval)
			form.hold("golpe_d", 0.25)
			var half := s.form_slash_arc_degrees * 0.5
			PhoenixFX.wing_arc(self, facing, s.form_slash_range, -half, half, 0.2, 1.0, 1.6)
			# Fogo fica no chão ao longo do arco.
			var b := Basis.looking_at(Vector3(facing.x, 0, facing.z).normalized(), Vector3.UP)
			for i in 4:
				var a := deg_to_rad(lerpf(-half * 0.8, half * 0.8, (i + 0.5) / 4.0))
				var p := global_position + b * Vector3(sin(a) * s.form_slash_range * 0.85, 0, -cos(a) * s.form_slash_range * 0.85)
				_add_burn(p, 0.8, s.form_slash_burn_dps, s.form_slash_burn_time)
			for e in Game.living_enemies():
				var enemy := e as Actor
				if Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED) \
						and Game.in_cone(global_position, facing, enemy.global_position, s.form_slash_range, s.form_slash_arc_degrees, enemy.body_radius):
					_form_hit(enemy, dmg, info)
		1:
			start_cooldown("basic", s.form_combo_interval)
			form.hold("giro", 0.3)
			var tw := create_tween()
			form.rotation.y = 0.0
			tw.tween_property(form, "rotation:y", -TAU, 0.28)
			PhoenixFX.spin(self, s.form_spin_radius, 0.28)
			for e in Game.living_enemies():
				var enemy := e as Actor
				var d := enemy.global_position - global_position
				d.y = 0.0
				if Game.flat_distance(enemy.global_position, global_position) <= s.form_spin_radius + enemy.body_radius \
						and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
					info["dir"] = d.normalized()
					_form_hit(enemy, dmg, info.duplicate())
		_:
			start_cooldown("basic", s.form_combo_interval * 1.8)
			_start_rush(facing, s.form_dive_distance, s.form_dive_time, "mergulho")
	return true


## Q da forma: leque de penas de fogo. Consome as Brasas em estouros.
func featherstorm() -> bool:
	if not cooldown_ready("fq") or ability_lock > 0.0 or not _rush.is_empty():
		return false
	var s := _fx()
	start_cooldown("fq", s.feather_cooldown)
	ability_lock = 0.25
	form.hold("leque", 0.35)
	var travel := 0.35
	PhoenixFX.feather_fan(self, facing, s.feather_count, s.feather_arc_degrees, s.feather_range, travel, s.feather_burn_time)
	var b := Basis.looking_at(Vector3(facing.x, 0, facing.z).normalized(), Vector3.UP)
	var origin := global_position
	var hits := {}
	for i in s.feather_count:
		var a := deg_to_rad(lerpf(-s.feather_arc_degrees * 0.5, s.feather_arc_degrees * 0.5, float(i) / float(maxi(1, s.feather_count - 1))))
		var r := s.feather_range * (0.85 + 0.15 * absf(sin(i * 1.7)))
		var end := origin + b * Vector3(sin(a) * r, 0, -cos(a) * r)
		_add_burn(end, 0.6, s.feather_burn_dps, s.feather_burn_time, travel)
		for e in Game.living_enemies():
			var enemy := e as Actor
			if Game.flat_distance_to_segment(enemy.global_position, origin, end) <= enemy.body_radius + 0.35 \
					and Game.vertical_ok(origin.y, enemy, Game.REACH_RANGED):
				var k := enemy.get_instance_id()
				if not hits.has(k):
					hits[k] = [enemy, 0, Game.flat_distance(origin, enemy.global_position)]
				hits[k][1] += 1
	for k in hits:
		var enemy: Actor = hits[k][0]
		var n: int = hits[k][1]
		var delay := travel * clampf(hits[k][2] / s.feather_range, 0.1, 1.0)
		get_tree().create_timer(delay).timeout.connect(_feathers_land.bind(enemy, n))
	return true


func _feathers_land(enemy: Actor, n: int) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	var s := _fx()
	var dmg := s.feather_damage * n
	if n >= s.feather_multi_hits:
		dmg += s.feather_multi_bonus
	var dir := enemy.global_position - global_position
	dir.y = 0.0
	var stacks := EmberMark.stacks_of(enemy)
	var at := enemy.global_position
	deal_damage(enemy, dmg, {"strength": Impact.STRONG if n >= s.feather_multi_hits else Impact.WEAK, "dir": dir.normalized(), "ability": true, "color": Color(0.4, 0.7, 1.0)})
	# Brasas acumuladas estouram em volta do inimigo (mesmo se a pena matou).
	if stacks <= 0:
		return
	EmberMark.of(enemy).clear()
	PhoenixFX.ember_pop(at, stacks)
	for e in Game.living_enemies():
		var other := e as Actor
		if Game.flat_distance(other.global_position, at) <= s.ember_pop_radius + other.body_radius:
			var d := other.global_position - at
			d.y = 0.0
			deal_damage(other, s.ember_pop_damage * stacks, {"strength": Impact.STRONG, "dir": d.normalized() if d.length() > 0.01 else dir.normalized(), "ability": true, "color": Color(1.0, 0.7, 0.25)})


## E da forma: dispara para a frente atravessando inimigos e explode no fim.
func solar_rush() -> bool:
	if not cooldown_ready("fe") or ability_lock > 0.0 or not _rush.is_empty():
		return false
	var s := _fx()
	start_cooldown("fe", s.rush_cooldown)
	_start_rush(facing, s.rush_distance, s.rush_time, "investida")
	return true


## Avanço em linha reta atravessando inimigos (para nas paredes).
func _start_rush(dir: Vector3, distance: float, time: float, kind: String) -> void:
	dir.y = 0.0
	dir = dir.normalized()
	var from := global_position
	var to := from + dir * distance
	var hit := Game.raycast_world(from + Vector3.UP * 0.8, to + Vector3.UP * 0.8)
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		to = Vector3(p.x, from.y, p.z) - dir * 0.6
	_rush = {"from": from, "to": to, "time": time, "t": 0.0, "kind": kind, "hit": {}, "embers": 0}
	busy = true
	invulnerable = true
	# Atravessa inimigos; continua batendo nas paredes.
	collision_mask = Game.LAYER_WORLD | Game.LAYER_WALKWAY
	ability_lock = time + 0.1
	facing = dir
	form.set_pose("mergulho")
	if kind == "investida":
		PhoenixFX.rush_streak(from, to, time + 0.3)


func _process_busy(delta: float) -> void:
	if _rush.is_empty():
		return
	var s := _fx()
	var prev := global_position
	_rush["t"] += delta
	var k := clampf(_rush["t"] / _rush["time"], 0.0, 1.0)
	var target: Vector3 = (_rush["from"] as Vector3).lerp(_rush["to"], k)
	velocity = (target - global_position) / maxf(delta, 0.001)
	velocity.y = 0.0
	move_and_slide()
	var investida: bool = _rush["kind"] == "investida"
	# Rastro de fogo e dano em quem foi atravessado.
	_add_burn(global_position, 0.7 if investida else 0.55, s.rush_burn_dps if investida else s.form_slash_burn_dps, s.rush_burn_time if investida else 1.5)
	for e in Game.living_enemies():
		var enemy := e as Actor
		var id := enemy.get_instance_id()
		if (_rush["hit"] as Dictionary).has(id):
			continue
		if Game.flat_distance_to_segment(enemy.global_position, prev, global_position) <= enemy.body_radius + 0.6 \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			_rush["hit"][id] = true
			var info := {"strength": Impact.WEAK, "dir": facing, "ability": investida, "color": Color(0.4, 0.7, 1.0)}
			if investida:
				_rush["embers"] += EmberMark.stacks_of(enemy)
				deal_damage(enemy, s.rush_pass_damage, info)
			else:
				_form_hit(enemy, s.form_combo_damage[2], info)
	if k >= 1.0:
		_end_rush()


func _end_rush() -> void:
	var s := _fx()
	var kind: String = _rush["kind"]
	var embers: int = _rush["embers"]
	var hit_ids: Dictionary = _rush["hit"]
	_rush = {}
	busy = false
	invulnerable = false
	collision_mask = Game.MASK_HERO
	velocity = Vector3.ZERO
	var at := global_position
	if kind == "investida":
		form.hold("abrir", 0.45)
		var bonus := minf(s.rush_bonus_max, s.rush_bonus_per_ember * embers)
		PhoenixFX.solar_nova(at, s.rush_blast_radius, embers > 0)
		for e in Game.living_enemies():
			var enemy := e as Actor
			if Game.flat_distance(enemy.global_position, at) <= s.rush_blast_radius + enemy.body_radius \
					and Game.vertical_ok(at.y, enemy, Game.REACH_RANGED):
				var d := enemy.global_position - at
				d.y = 0.0
				deal_damage(enemy, s.rush_blast_damage + bonus, {"strength": Impact.SPECIAL, "dir": d.normalized() if d.length() > 0.01 else facing, "ability": true, "color": Color(1.0, 0.6, 0.2)})
	else:
		form.set_pose("voo")
		PhoenixFX.small_burst(at, s.form_dive_burst_radius)
		for e in Game.living_enemies():
			var enemy := e as Actor
			if Game.flat_distance(enemy.global_position, at) <= s.form_dive_burst_radius + enemy.body_radius \
					and Game.vertical_ok(at.y, enemy, Game.REACH_RANGED):
				var d := enemy.global_position - at
				d.y = 0.0
				# Quem já levou o mergulho não ganha outra Brasa na explosão.
				_form_hit(enemy, s.form_dive_burst_damage, {"strength": Impact.STRONG, "dir": d.normalized() if d.length() > 0.01 else facing, "ability": false, "color": Color(0.4, 0.7, 1.0)}, not hit_ids.has(enemy.get_instance_id()))


## Fogo no chão: queima inimigos em cima, de meio em meio segundo.
func _add_burn(at: Vector3, radius: float, dps: float, seconds: float, delay := 0.0) -> void:
	if delay <= 0.0:
		# Um pedaço de fogo por vez no mesmo lugar (o rastro chama todo quadro).
		for b in _burns:
			if Game.flat_distance(b[0], at) < radius * 0.8:
				b[3] = maxf(b[3], seconds)
				return
		PhoenixFX.fire_patch(at, radius * 1.8, seconds, 0.0)
	_burns.append([at, radius, dps, seconds + delay])


func _tick_burns(delta: float) -> void:
	if _burns.is_empty():
		return
	for b in _burns:
		b[3] -= delta
	_burns = _burns.filter(func(b): return b[3] > 0.0)
	_burn_tick -= delta
	if _burn_tick > 0.0:
		return
	_burn_tick = 0.5
	var burned := {}
	for b in _burns:
		for e in Game.living_enemies():
			var enemy := e as Actor
			var id := enemy.get_instance_id()
			if burned.has(id) or enemy.flying:
				continue
			if Game.flat_distance(enemy.global_position, b[0]) <= b[1] + enemy.body_radius:
				burned[id] = true
				deal_damage(enemy, b[2] * 0.5, {"strength": Impact.WEAK, "push": 0.0, "quiet": true, "color": Color(0.4, 0.7, 1.0)})


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
	# A fênix paira: em cima de um vão, não cai.
	if in_form():
		if not on_floor and v.y < 0.0 and Game.is_over_gap(global_position):
			v.y = 0.0
		return v
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
	if not _rush.is_empty():
		_rush = {}
		collision_mask = Game.MASK_HERO
	if in_form():
		exit_form()
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
	if in_form():
		return _ai_form_combat(target, delta)
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


## IA na Forma Fênix (se o jogador trocar de herói no meio da forma).
func _ai_form_combat(target: Actor, delta: float) -> Vector3:
	var s := _fx()
	face_towards(target.global_position)
	var d := Game.flat_distance(global_position, target.global_position)
	if cooldown_ready("fq") and d <= s.feather_range * 0.8:
		featherstorm()
	elif cooldown_ready("fe") and d >= 3.0 and d <= s.rush_distance * 0.8:
		solar_rush()
	if d > s.form_slash_range * 0.8:
		return navigate_to(target.global_position, delta)
	ember_dance()
	return Vector3.ZERO
