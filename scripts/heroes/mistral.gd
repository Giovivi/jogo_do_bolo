class_name Mistral
extends Hero
## Mistral, a senhora dos céus: controle de área com eletricidade e vento
## (documento da Vivi "Mistral — documento de conceito de personagem").
## Passiva Carga Atmosférica, Descarga Relampejante (clique), Olho do
## Furacão (Q), Investida de Vendaval (E) e Geada Absoluta (R).

## Malha da Mistral no mesmo esqueleto e animações do Fênix.
const MODEL := preload("res://art/modelos/mistral_animado.glb")
## Mão direita em relação aos pés (o jogo olha para -Z), se faltar o osso.
const HAND_REST := Vector3(-0.3, 1.1, -0.35)
## Folga lateral da mira automática do raio (m).
const AIM_SLACK := 1.3

var model: FenixModel
var arms: ArmsOverride
var orbit: MistralFX.Orbit
var sashes: MistralFX.Sashes
var eyes := MistralFX.Eyes.new()
var _hand: BoneAttachment3D
var _hips: BoneAttachment3D
## Carga Atmosférica (0 a charges_needed).
var charges: int = 0
var _arms_time: float = 0.0
var _eyes_time: float = 0.0
var _ai_target: Actor = null
var _was_dashing: bool = false
## Geada Absoluta: tempo desde o início (>= 0 durante a execução).
var _frost_time: float = -1.0
var _frost_hit: Array = []
var _frost_center := Vector3.ZERO
var _frost_outline := PackedVector3Array()
var _frost_fx: MistralFX
var _frost_decor: Array = []


func _ms() -> MistralStats:
	return stats as MistralStats


func _ready() -> void:
	super._ready()
	_use_model()
	impact_color = Color(0.4, 0.87, 0.92, 0.3)
	impact_color_strong = Color(0.55, 0.9, 1.0, 0.4)


func _use_model() -> void:
	for child in visual.get_children():
		if child is MeshInstance3D:
			child.visible = false
	model = FenixModel.new()
	model.scene = MODEL
	model.hero = self
	visual.add_child(model)
	var found := model.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		var sk := found.front() as Skeleton3D
		arms = ArmsOverride.new()
		sk.add_child(arms)
		arms.setup(sk)
		if sk.find_bone("DEF-hand.R") >= 0:
			_hand = BoneAttachment3D.new()
			_hand.bone_name = "DEF-hand.R"
			sk.add_child(_hand)
		for b in ["DEF-spine", "DEF-hips", "ORG-hips"]:
			if sk.find_bone(b) >= 0:
				_hips = BoneAttachment3D.new()
				_hips.bone_name = b
				sk.add_child(_hips)
				break
	# Olhos dourados que ficam azul-elétricos com os poderes.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			var mat := m.get_surface_override_material(i)
			if src != null and src.resource_name == "olho" and mat is StandardMaterial3D:
				eyes.mats.append(mat as StandardMaterial3D)
	orbit = MistralFX.Orbit.new()
	orbit.hero = self
	add_child(orbit)
	sashes = MistralFX.Sashes.new()
	sashes.hero = self
	sashes.anchor = _hips
	add_child(sashes)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_arms_time = maxf(0.0, _arms_time - delta)
	_eyes_time = maxf(0.0, _eyes_time - delta)
	if arms != null:
		var want := 1.0 if (_arms_time > 0.0 or _frost_time >= 0.0) and not is_dead else 0.0
		arms.weight = move_toward(arms.weight, want, delta * 9.0)
		if arms.weight <= 0.0:
			arms.pose = ArmsOverride.Pose.NONE
	var full := charges >= _ms().charges_needed
	eyes.tick(delta, 1.0 if (_eyes_time > 0.0 or _frost_time >= 0.0) else (0.45 if full else 0.0))
	if orbit != null:
		orbit.charges = 0 if is_dead or not in_party else charges
		orbit.visible = not is_dead
	_update_dash_fx()


func ability_slots() -> Array:
	var s := _ms()
	return [
		["Clique", "Descarga Relampejante", cooldown_left("basic"), s.bolt_interval],
		["Q", "Olho do Furacão", cooldown_left("q"), s.q_cooldown],
		["E", "Investida de Vendaval", cooldown_left("e"), s.e_cooldown],
		["R", "Geada Absoluta", 0.0, 0.0],
		["Shift", "Dash", cooldown_left("dash"), s.dash_cooldown],
		["Passiva", "Carga Atmosférica (%d/%d)" % [charges, s.charges_needed], 0.0, 0.0],
	]


# ---------------------------------------------------------------- jogador

func _player_actions(aim: Vector3, _move: Vector3) -> void:
	if Input.is_action_pressed("attack"):
		discharge()
	if Input.is_action_just_pressed("ability_1"):
		storm(aim)
	if Input.is_action_just_pressed("ability_2"):
		gale()


func _is_acting_input() -> bool:
	return Input.is_action_pressed("attack") or Input.is_action_just_pressed("ability_1") \
			or Input.is_action_just_pressed("ability_2") or Input.is_action_just_pressed("special")


# ---------------------------------------------------------------- Carga Atmosférica

## Habilidade usada: +1 carga (até 3). Devolve se o golpe atual consumiu a
## carga completa (e já zera).
func _consume_charge() -> bool:
	if charges >= _ms().charges_needed:
		charges = 0
		return true
	return false


func _add_charge() -> void:
	var s := _ms()
	if charges < s.charges_needed:
		charges += 1
		if charges >= s.charges_needed:
			MistralFX.sparks(global_position + Vector3(0, 1.0, 0), Vector3.UP, 10, 4.0)


func _pose(p: ArmsOverride.Pose, seconds: float) -> void:
	if arms == null:
		return
	arms.pose = p
	_arms_time = seconds


## Mão direita no mundo (de onde sai o raio).
func hand_point() -> Vector3:
	if _hand != null and is_instance_valid(_hand):
		return _hand.global_position + facing * 0.08
	return global_position + visual.global_transform.basis.orthonormalized() * HAND_REST


# ---------------------------------------------------------------- Clique: Descarga Relampejante

## Raio rápido no inimigo mirado (ou o mais perto da linha de mira), que
## salta para um segundo inimigo próximo com metade do dano. Com a Carga
## completa: mais grosso e com mais um salto (ramificação adicional).
func discharge() -> bool:
	if not cooldown_ready("basic") or ability_lock > 0.0 or _frost_time >= 0.0:
		return false
	var s := _ms()
	start_cooldown("basic", s.bolt_interval)
	var from := hand_point()
	var target := _bolt_target(s.bolt_range)
	_pose(ArmsOverride.Pose.POINT, 0.3)
	_eyes_time = 0.35
	_anim("Spell_Simple_Shoot", 2.0)
	if target == null:
		# Sem alvo: o raio estala no ar na direção da mira e morre numa parede.
		var to := from + facing * s.bolt_range * 0.6
		var hit := Game.raycast_world(from, to)
		if not hit.is_empty():
			to = hit["position"]
		MistralFX.bolt(from, to, false, not hit.is_empty())
		return true
	var charged := _consume_charge()
	var jumps := s.chain_jumps_charged if charged else s.chain_jumps
	var c := Game.body_center(target)
	MistralFX.bolt(from, c, charged, true)
	var dir := c - global_position
	dir.y = 0.0
	deal_damage(target, s.bolt_damage, {"strength": Impact.STRONG if charged else Impact.WEAK, "dir": dir, "ability": false})
	# Saltos: do último atingido para o inimigo vivo mais perto ainda não atingido.
	var hit_list: Array = [target]
	var last: Actor = target
	var last_point := c
	for j in jumps:
		var next := _chain_next(last, hit_list, s.chain_radius)
		if next == null:
			break
		var nc := Game.body_center(next)
		var jumper := func() -> void:
			MistralFX.bolt(last_point, nc, charged, true, true)
		jumper.call()
		var d2 := nc - last_point
		d2.y = 0.0
		deal_damage(next, s.bolt_damage * s.chain_damage_fraction, {"strength": Impact.WEAK, "dir": d2, "ability": false})
		hit_list.append(next)
		last = next
		last_point = nc
	return true


## Alvo do raio: o inimigo embaixo do cursor ou o mais perto da linha de mira.
func _bolt_target(max_range: float) -> Actor:
	var t: Actor = aim_target if controlled else _ai_target
	if t != null and is_instance_valid(t) and not t.is_dead \
			and Game.flat_distance(global_position, t.global_position) <= max_range + t.body_radius \
			and Game.has_line_of_sight(global_position + Vector3(0, 1.0, 0), Game.body_center(t)):
		return t
	var best: Actor = null
	var best_d := INF
	var from := global_position
	var to := from + facing * max_range
	for e in Game.living_enemies():
		var enemy := e as Actor
		var side := Game.flat_distance_to_segment(enemy.global_position, from, to)
		if side > AIM_SLACK + enemy.body_radius:
			continue
		var d := Game.flat_distance(from, enemy.global_position)
		if d > max_range + enemy.body_radius:
			continue
		if not Game.has_line_of_sight(from + Vector3(0, 1.0, 0), Game.body_center(enemy)):
			continue
		var score := d + side * 3.0
		if score < best_d:
			best_d = score
			best = enemy
	return best


func _chain_next(from_enemy: Actor, exclude: Array, radius: float) -> Actor:
	var best: Actor = null
	var best_d := radius
	for e in Game.living_enemies():
		var enemy := e as Actor
		if enemy in exclude:
			continue
		var d := from_enemy.global_position.distance_to(enemy.global_position)
		if d < best_d and Game.has_line_of_sight(Game.body_center(from_enemy), Game.body_center(enemy)):
			best_d = d
			best = enemy
	return best


# ---------------------------------------------------------------- Q: Olho do Furacão

## Furacão no ponto mirado (até 10 m, antes das paredes): puxa para o
## centro e dá dano contínuo. Com Carga: maior e puxa mais forte.
func storm(aim: Vector3) -> bool:
	if not cooldown_ready("q") or ability_lock > 0.0 or _frost_time >= 0.0:
		return false
	var s := _ms()
	start_cooldown("q", s.q_cooldown)
	ability_lock = 0.2
	var charged := _consume_charge()
	var at := _storm_point(aim, s.storm_cast_range)
	var st := Storm.new()
	st.owner_hero = self
	st.radius = s.storm_radius * (s.storm_charged_radius if charged else 1.0)
	st.pull_speed = s.storm_pull_speed * (s.storm_charged_pull if charged else 1.0)
	st.pull_reach = s.storm_pull_reach
	st.heavy_pull = s.storm_heavy_pull
	st.dps = s.storm_dps
	st.duration = s.storm_duration
	var root: Node = Game.world_root if Game.world_root != null else get_parent()
	root.add_child(st)
	st.global_position = at
	st.fx = MistralFX.tornado(at, st.radius, st.duration, charged)
	_pose(ArmsOverride.Pose.POINT, 0.35)
	_eyes_time = 0.6
	_anim("Spell_Simple_Shoot", 1.4)
	MistralFX.bolt(hand_point(), at + Vector3(0, 0.4, 0), false, false, true)
	if not charged:
		_add_charge()
	if sashes != null:
		sashes.gust = 1.0
	return true


## Ponto do furacão: a mira, limitada ao alcance e parando antes das paredes.
func _storm_point(aim: Vector3, max_range: float) -> Vector3:
	var flat := aim - global_position
	flat.y = 0.0
	if flat.length() > max_range:
		flat = flat.normalized() * max_range
	if flat.length() < 0.5:
		flat = facing * 3.0
	var from := global_position + Vector3(0, 0.8, 0)
	var to := from + flat
	var hit := Game.raycast_world(from, to)
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		to = from + (p - from) - flat.normalized() * 0.8
	return Vector3(to.x, global_position.y, to.z)


## Lógica do furacão (o visual fica no MistralFX).
class Storm extends Node3D:
	var owner_hero: Hero
	var fx: MistralFX
	var radius: float = 2.5
	var pull_speed: float = 3.2
	var pull_reach: float = 1.6
	var heavy_pull: float = 0.4
	var dps: float = 8.0
	var duration: float = 3.0
	var _age: float = 0.0
	var _tick: float = 0.0
	var _streak: float = 0.0

	func _physics_process(delta: float) -> void:
		_age += delta
		if _age >= duration:
			queue_free()
			return
		_tick += delta
		_streak -= delta
		var hit_now := _tick >= 0.25
		var dt := _tick
		if hit_now:
			_tick = 0.0
		for e in Game.living_enemies():
			if not is_instance_valid(e):
				continue
			var enemy := e as Enemy
			if enemy == null:
				continue
			var d := enemy.global_position - global_position
			d.y = 0.0
			var dist := d.length()
			if dist > radius * pull_reach + enemy.body_radius:
				continue
			if absf(enemy.global_position.y - global_position.y) > 3.5:
				continue
			# Atração: mais forte perto da borda do furacão, some no centro.
			if dist > 0.35 and not enemy.is_frozen():
				var k := clampf(dist / radius, 0.0, 1.0)
				var st = enemy.get("stats")
				var mult := heavy_pull if (st is EnemyStats and (st as EnemyStats).shielded) else 1.0
				enemy.pull_velocity += -d.normalized() * pull_speed * mult * lerpf(0.35, 1.0, k)
				if enemy.flying:
					enemy.visual.rotation.z = sin(_age * 9.0 + float(enemy.get_instance_id() % 7)) * 0.25
				if _streak <= 0.0 and dist > radius * 0.6:
					MistralFX.pull_streak(enemy.global_position, global_position)
			if hit_now and dist <= radius + enemy.body_radius and is_instance_valid(owner_hero):
				owner_hero.deal_damage(enemy, dps * dt, {"strength": Impact.WEAK, "quiet": true, "push": 0.0, "dir": -d, "ability": true})
		if _streak <= 0.0:
			_streak = 0.3


# ---------------------------------------------------------------- E: Investida de Vendaval

## Rajada em cone de 100°: atravessa, interrompe e arremessa 3 m. Não prende
## nem agrupa: abre espaço. Com Carga: empurra 4,5 m e dá mais dano.
func gale() -> bool:
	if not cooldown_ready("e") or ability_lock > 0.0 or _frost_time >= 0.0:
		return false
	var s := _ms()
	start_cooldown("e", s.e_cooldown)
	ability_lock = 0.3
	var charged := _consume_charge()
	var push := s.gust_charged_push if charged else s.gust_push_meters
	var dmg := s.gust_charged_damage if charged else s.gust_damage
	MistralFX.gust(global_position, facing, s.gust_range, s.gust_arc_degrees, charged)
	_pose(ArmsOverride.Pose.PUSH, 0.4)
	_eyes_time = 0.6
	_anim("Punch_Cross", 1.5)
	Game.shake(0.08 if not charged else 0.14, 0.16)
	if sashes != null:
		sashes.gust = 1.0
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.in_cone(global_position, facing, enemy.global_position, s.gust_range, s.gust_arc_degrees, enemy.body_radius) \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED) \
				and Game.has_line_of_sight(global_position + Vector3(0, 1.0, 0), Game.body_center(enemy)):
			var dir := enemy.global_position - global_position
			dir.y = 0.0
			deal_damage(enemy, dmg, {"strength": Impact.STRONG, "push": push, "dir": dir, "ability": true})
			MistralFX.push_trail(enemy, dir.normalized())
	if not charged:
		_add_charge()
	return true


# ---------------------------------------------------------------- R: Geada Absoluta

## Braços erguidos e névoa fria (frost_charge_time); depois o gelo corre pelo
## chão até 12 m e cristais brotam sob cada inimigo que a borda alcança:
## 100 de dano e congelados 3 s. Paredes bloqueiam. Parada e invulnerável
## durante a execução (1,5 s).
func use_special(_aim: Vector3) -> bool:
	if _frost_time >= 0.0:
		return false
	var s := _ms()
	busy = true
	invulnerable = true
	velocity = Vector3.ZERO
	ability_lock = s.frost_cast_time + 0.1
	_frost_time = 0.0
	_frost_hit.clear()
	_frost_center = global_position
	_frost_outline = _reach_outline(s.frost_radius)
	_pose(ArmsOverride.Pose.RAISE, s.frost_cast_time)
	MistralFX.frost_charge(self, s.frost_charge_time)
	_frost_fx = null
	_frost_decor = _decor_points(s.frost_radius)
	if sashes != null:
		sashes.gust = 1.0
	return true


## Contorno do alcance cortado pelas paredes (como a R do Feixe).
func _reach_outline(radius: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var from := global_position + Vector3(0, 0.8, 0)
	var n := 96
	for i in n:
		var a := TAU * float(i) / float(n)
		var d := Vector3(sin(a), 0, cos(a))
		var hit := Game.raycast_world(from, from + d * radius)
		var r := radius
		if not hit.is_empty():
			r = Vector2(hit["position"].x - from.x, hit["position"].z - from.z).length()
		out.append(d * r)
	return out


## Pontos soltos dentro do gelo para cristais de enfeite (só onde o gelo chega).
func _decor_points(radius: float) -> Array:
	var out: Array = []
	var n := _frost_outline.size()
	for i in 18:
		var a := randf() * TAU
		var idx := int(a / TAU * float(n)) % n
		var lim := _frost_outline[idx].length()
		var r := randf_range(1.8, minf(radius, lim) - 0.6)
		if r < 1.8:
			continue
		out.append([Vector3(sin(a) * r, 0, cos(a) * r), r, randf_range(0.45, 0.85)])
	return out


## Distância que a borda do gelo já alcançou (igual ao MistralFX.frost_floor).
func _frost_front(t: float) -> float:
	var s := _ms()
	var spread := s.frost_cast_time - s.frost_charge_time
	var k := clampf(t / spread, 0.0, 1.0)
	return s.frost_radius * (1.0 - pow(1.0 - k, 1.7)) + 0.6


func _process_busy(delta: float) -> void:
	if _frost_time < 0.0:
		return
	var s := _ms()
	_frost_time += delta
	velocity = Vector3.ZERO
	if _frost_time < s.frost_charge_time:
		return
	var spread := s.frost_cast_time - s.frost_charge_time
	var t := _frost_time - s.frost_charge_time
	if _frost_fx == null:
		_frost_fx = MistralFX.frost_floor(_frost_center, s.frost_radius, _frost_outline, spread, s.frost_freeze_time)
		Game.shake(0.12, 0.3)
	var front := _frost_front(t)
	# Cristais de enfeite pelo chão, quando a borda passa.
	for d in _frost_decor.duplicate():
		if float(d[1]) <= front:
			_frost_decor.erase(d)
			MistralFX.crystal_cluster(_frost_center + (d[0] as Vector3), d[2], s.frost_freeze_time * 0.6)
	# Inimigos: cristais brotam embaixo quando a borda chega.
	for e in Game.living_enemies():
		var enemy := e as Actor
		if enemy in _frost_hit:
			continue
		var dist := Game.flat_distance(enemy.global_position, _frost_center)
		if dist > s.frost_radius + enemy.body_radius or not Game.vertical_ok(_frost_center.y, enemy, Game.REACH_RANGED):
			continue
		if dist > front and t < spread:
			continue
		_frost_hit.append(enemy)
		var c := Game.body_center(enemy)
		if not Game.raycast_world(_frost_center + Vector3(0, 0.8, 0), c).is_empty():
			continue # atrás de parede
		var st = enemy.get("stats")
		var heavy: bool = st is EnemyStats and (st as EnemyStats).shielded
		var freeze_t := s.frost_freeze_time * (s.frost_heavy_fraction if heavy else 1.0)
		var ground := Vector3(enemy.global_position.x, _frost_center.y, enemy.global_position.z)
		var size := 1.3 if enemy.flying else 1.0
		var cluster := MistralFX.crystal_cluster(ground, size, freeze_t, true)
		var d := enemy.global_position - _frost_center
		d.y = 0.0
		deal_damage(enemy, s.frost_damage, {"strength": Impact.STRONG, "push": 0.0, "ability": true, "dir": d, "color": Color(0.7, 0.95, 1.0)})
		if enemy.is_dead:
			# Quem morre estoura o gelo logo.
			cluster.get_tree().create_timer(0.35).timeout.connect(cluster.shatter)
		elif enemy is Enemy:
			(enemy as Enemy).freeze(freeze_t)
	if t >= spread:
		_end_frost()


func _end_frost() -> void:
	_frost_time = -1.0
	busy = false
	_frost_fx = null
	if _dash_time_left <= 0.0:
		invulnerable = false
	_add_charge()


# ---------------------------------------------------------------- dash

func _update_dash_fx() -> void:
	var dashing := _dash_time_left > 0.0
	if dashing and not _was_dashing:
		MistralFX.dash_gust(global_position, facing)
		if sashes != null:
			sashes.gust = 1.0
	_was_dashing = dashing


# ---------------------------------------------------------------- IA

## Fica entre 6 e 9 m. Raio no inimigo mais perto; furacão quando 2+
## inimigos estão juntos; rajada quando alguém chega a menos de 3,5 m.
## Não usa a R.
func _ai_combat(target: Actor, delta: float) -> Vector3:
	var s := _ms()
	_ai_target = target
	face_towards(target.global_position)
	var d := Game.flat_distance(global_position, target.global_position)
	if cooldown_ready("e") and d < 3.5:
		gale()
	if cooldown_ready("q"):
		var spot := _ai_cluster_point(s.storm_cast_range)
		if spot != Vector3.INF:
			storm(spot)
	discharge()
	var away := global_position - target.global_position
	away.y = 0.0
	if d < 5.0:
		return away.normalized() * 0.8
	if d > 10.0:
		return navigate_to(target.global_position, delta)
	return Vector3.ZERO


## Centro de um grupo de 2+ inimigos ao alcance, ou Vector3.INF.
func _ai_cluster_point(max_range: float) -> Vector3:
	var enemies := Game.living_enemies()
	for e in enemies:
		var a := e as Actor
		if Game.flat_distance(global_position, a.global_position) > max_range:
			continue
		var sum := a.global_position
		var n := 1
		for o in enemies:
			if o != e and a.global_position.distance_to((o as Node3D).global_position) < 3.0:
				sum += (o as Node3D).global_position
				n += 1
		if n >= 2:
			return sum / float(n)
	return Vector3.INF


func go_down() -> void:
	if _frost_time >= 0.0:
		_frost_time = -1.0
	super.go_down()
	visual.rotation.x = 0.0
	visual.position.y = 0.0


func _on_damaged(amount: float, source: Node) -> void:
	super._on_damaged(amount, source)
	if not is_dead and _frost_time < 0.0:
		_anim("Hit_Chest", 1.5)


func _anim(anim_name: String, speed: float) -> void:
	if model != null:
		model.play_once(anim_name, speed)
