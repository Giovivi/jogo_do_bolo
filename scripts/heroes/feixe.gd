class_name Feixe
extends Hero
## Feixe: distância e precisão, tudo em raio laser vermelho (prancha
## feixe-laser-drone-v2): Raio Laser, Raio Forte, Cone de Raios e Suprema
## em Círculo. Cada disparo solta um clarão estrelado do rosto.

## Tempo da volta inteira do raio da Suprema (sentido horário).
const SWEEP_TIME := 1.2
## Recuo enquanto segura o Raio Forte: cerca de 1 m em 3 s.
const LASER_RECOIL_SPEED := 0.33
## Tempo para o Raio Forte nascer fino e chegar à largura cheia.
const LASER_GROW_TIME := 0.15
## Tolerância de altura entre o raio e o centro do corpo do inimigo (m).
const BEAM_HEIGHT_TOLERANCE := 1.1
## Malha do Feixe (óculos de laser) no mesmo esqueleto e animações do Fênix.
const MODEL := preload("res://art/modelos/feixe_animado.glb")

var _laser_active: bool = false
var _laser_time: float = 0.0
var _laser_tick: float = 0.0
var _laser_ai_limit: float = 0.0
var _laser_meshes: Array[MeshInstance3D] = []
var _laser_flare: Sprite3D
var _laser_fx: FeixeFX
## Varredura da Suprema em andamento.
var _sweep_time: float = -1.0
var _sweep_yaw0: float = 0.0
var _sweep_hit: Array = []
var _sweep_meshes: Array[MeshInstance3D] = []
var _sweep_flare: Sprite3D
var _sweep_fx: FeixeFX
## Mão na têmpora (Raio Forte e Suprema).
var temple: TempleOverride
var _temple_target: float = 0.0
var _ai_target: Actor = null
var model: FenixModel


func _fb() -> FeixeStats:
	return stats as FeixeStats


func _ready() -> void:
	super._ready()
	_use_model()
	# Faísca vermelha clara no raio, vermelha forte no Q, no E e no R.
	impact_color = Color(1.0, 0.55, 0.45, 0.9)
	impact_color_strong = Color(1.0, 0.2, 0.15, 0.95)


## Troca a cápsula provisória pelo modelo 3D (a colisão continua a mesma).
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
		temple = TempleOverride.new()
		(found.front() as Skeleton3D).add_child(temple)
		temple.setup(found.front() as Skeleton3D)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if temple != null:
		var want := _temple_target if not is_dead else 0.0
		temple.weight = move_toward(temple.weight, want, delta * 7.0)
	if _laser_active:
		if is_dead or not in_party:
			stop_laser()
		else:
			_tick_laser(delta)


func ability_slots() -> Array:
	var s := _fb()
	var laser_name := "Raio Forte (%.1f s)" % laser_time_left() if _laser_active else "Raio Forte (segure)"
	return [
		["Clique", "Raio Laser", 0.0, 0.0],
		["Q", laser_name, cooldown_left("q"), s.q_cooldown],
		["E", "Cone de Raios", cooldown_left("e"), s.e_cooldown],
		["R", "Suprema em Círculo", 0.0, 0.0],
		["Shift", "Dash", cooldown_left("dash"), s.dash_cooldown],
	]


func set_controlled(value: bool) -> void:
	if not value:
		stop_laser()
	super.set_controlled(value)


# ---------------------------------------------------------------- jogador

func _player_actions(_aim: Vector3, _move: Vector3) -> void:
	if Input.is_action_pressed("attack") and not _laser_active:
		optic_shot()
	if Input.is_action_just_pressed("ability_1"):
		start_laser(0.0)
	if _laser_active and not Input.is_action_pressed("ability_1"):
		stop_laser()
	if Input.is_action_just_pressed("ability_2"):
		repulsion_pulse()


## O rosto do Feixe: de onde saem os raios e o clarão.
func _muzzle() -> Vector3:
	# Altura dos óculos do modelo.
	return global_position + facing * 0.3 + Vector3(0, 1.6, 0)


## Alvo do raio: o inimigo embaixo do cursor (jogador) ou o da IA.
func _shot_target() -> Actor:
	var t: Actor = aim_target if controlled else _ai_target
	if t != null and (not is_instance_valid(t) or t.is_dead):
		return null
	return t


## Ponto final do raio: na direção do alvo (inclusive para cima, no drone)
## ou reto para a frente, cortado pela primeira parede.
func _beam_end(from: Vector3, length: float) -> Vector3:
	var dir := facing
	var t := _shot_target()
	if t != null:
		dir = (Game.body_center(t) - from).normalized()
	var to := from + dir * length
	var hit := Game.raycast_world(from, to)
	if not hit.is_empty():
		to = hit["position"]
	return to


## Inimigos atravessados pelo raio, do mais perto ao mais longe.
func _enemies_on_beam(from: Vector3, to: Vector3, width: float) -> Array[Actor]:
	var out: Array[Actor] = []
	var seg := to - from
	var flat_len := Vector2(seg.x, seg.z).length()
	var dists: Array[float] = []
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.flat_distance_to_segment(enemy.global_position, from, to) > width * 0.5 + enemy.body_radius:
			continue
		# Altura do raio no ponto do inimigo.
		var along: float = clampf(Game.flat_distance(from, enemy.global_position) / maxf(flat_len, 0.01), 0.0, 1.0)
		var beam_y: float = lerpf(from.y, to.y, along)
		if absf(Game.body_center(enemy).y - beam_y) > BEAM_HEIGHT_TOLERANCE + enemy.body_radius * 0.5:
			continue
		var d := Game.flat_distance(from, enemy.global_position)
		var i := 0
		while i < dists.size() and dists[i] < d:
			i += 1
		dists.insert(i, d)
		out.insert(i, enemy)
	return out


func _hit_switches(from: Vector3, to: Vector3) -> void:
	for sw in get_tree().get_nodes_in_group("switches"):
		var n := sw as Node3D
		if Game.flat_distance_to_segment(n.global_position, from, to) < 0.9:
			n.call("on_beam_hit", self)


# ---------------------------------------------------------------- básico

## Raio Laser: instantâneo, para no primeiro inimigo ou parede.
func optic_shot() -> bool:
	if not cooldown_ready("basic") or ability_lock > 0.0:
		return false
	var s := _fb()
	start_cooldown("basic", s.shot_interval)
	var from := _muzzle()
	var to := _beam_end(from, s.shot_range)
	_hit_switches(from, to)
	var victims := _enemies_on_beam(from, to, s.shot_width)
	if not victims.is_empty():
		var v: Actor = victims[0]
		var c: Vector3 = Game.body_center(v)
		to = from + (to - from).normalized() * from.distance_to(c)
		var dir := c - global_position
		dir.y = 0.0
		deal_damage(v, s.shot_damage, {"strength": Impact.WEAK, "dir": dir, "ability": false})
	Game.laser_beam(from, to, 0.05, 0.2, 0.1)
	Game.laser_flare(from, 0.9, 0.1)
	FeixeFX.shot(from, to)
	_anim("Spell_Simple_Shoot", 2.0)
	return true


# ---------------------------------------------------------------- Q: Raio Forte

## ai_limit > 0 limita a duração (usado pela IA).
func start_laser(ai_limit: float) -> bool:
	if _laser_active or not cooldown_ready("q"):
		return false
	_laser_active = true
	_laser_time = 0.0
	_laser_tick = 0.0
	_laser_ai_limit = ai_limit
	move_multiplier = _fb().laser_move_multiplier
	var from := _muzzle()
	_laser_meshes = Game.laser_beam(from, from + facing, 0.16, 0.7, 0.0)
	_laser_flare = Game.laser_flare(from, 1.7, 0.0)
	_laser_fx = FeixeFX.beam(self)
	_laser_fx.update_beam(from, from + facing * 0.1, global_position, 0.3)
	_temple_target = 1.0
	return true


func stop_laser() -> void:
	if not _laser_active:
		return
	_laser_active = false
	move_multiplier = 1.0
	for m in _laser_meshes:
		if is_instance_valid(m):
			m.queue_free()
	_laser_meshes.clear()
	if is_instance_valid(_laser_flare):
		_laser_flare.queue_free()
	_laser_flare = null
	if is_instance_valid(_laser_fx):
		_laser_fx.stop()
	_laser_fx = null
	if _sweep_time < 0.0:
		_temple_target = 0.0
	start_cooldown("q", _fb().q_cooldown)


func laser_active() -> bool:
	return _laser_active


func laser_time_left() -> float:
	return maxf(0.0, _fb().laser_max_time - _laser_time)


func _tick_laser(delta: float) -> void:
	var s := _fb()
	_laser_time += delta
	var limit := s.laser_max_time
	if _laser_ai_limit > 0.0:
		limit = minf(limit, _laser_ai_limit)
	if _laser_time >= limit:
		stop_laser()
		return
	# Tranco do raio: escorrega um pouco para trás (para nas paredes).
	if not busy and is_on_floor():
		move_and_collide(-facing * LASER_RECOIL_SPEED * delta)
	var from := _muzzle()
	var to := _beam_end(from, s.laser_range)
	_cut_blast_doors(from, to, delta)
	_hit_switches(from, to)
	# Visual: nasce fino e curto e chega à largura cheia; depois pulsa de leve.
	var grow := clampf(_laser_time / LASER_GROW_TIME, 0.0, 1.0)
	var pulse := 1.0 + 0.08 * sin(_laser_time * 35.0)
	var shown := from.lerp(to, grow)
	var widths: Array[float] = [0.7 * grow * pulse, 0.16 * maxf(grow, 0.4)]
	for i in _laser_meshes.size():
		if is_instance_valid(_laser_meshes[i]):
			Game.place_beam(_laser_meshes[i], from, shown, widths[i])
	if is_instance_valid(_laser_fx):
		_laser_fx.update_beam(from, shown, global_position, grow)
	if is_instance_valid(_laser_flare):
		_laser_flare.global_position = from
		_laser_flare.scale = Vector3.ONE * (1.0 + 0.12 * sin(_laser_time * 40.0))
	# Dano em pulsos de 0,25 s. Atravessa todos os inimigos da linha.
	_laser_tick += delta
	if _laser_tick >= 0.25:
		var dmg := s.laser_dps * _laser_tick
		_laser_tick = 0.0
		for enemy in _enemies_on_beam(from, to, s.laser_width):
			# Forte: interrompe o inimigo. "quiet" evita pausa a cada pulso.
			deal_damage(enemy, dmg, {"strength": Impact.STRONG, "push": 0.3, "quiet": true, "dir": facing, "ability": true, "color": Color(1, 0.4, 0.4)})


## Porta blindada: o raio forte corta se passar por ela (com folga de
## ~1 m), mesmo que a ponta do raio pare no batente da parede.
func _cut_blast_doors(from: Vector3, to: Vector3, delta: float) -> void:
	var far := from + (to - from).normalized() * (from.distance_to(to) + 1.0)
	for d in get_tree().get_nodes_in_group("blast_doors"):
		var door := d as Door
		if door == null or door.is_open:
			continue
		if absf(door.global_position.y - global_position.y) > 2.0:
			continue
		if Game.flat_distance_to_segment(door.global_position, from, far) <= 1.6:
			door.cut(delta, self)


# ---------------------------------------------------------------- E: Cone de Raios

func repulsion_pulse() -> bool:
	if not cooldown_ready("e") or ability_lock > 0.0:
		return false
	var s := _fb()
	start_cooldown("e", s.e_cooldown)
	ability_lock = 0.25
	var from := _muzzle()
	FeixeFX.cone(self, from, facing, s.pulse_range, s.pulse_arc_degrees)
	Game.laser_flare(from, 1.6, 0.25)
	Game.shake(0.12, 0.2)
	_anim("Punch_Cross", 1.6)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.in_cone(global_position, facing, enemy.global_position, s.pulse_range, s.pulse_arc_degrees, enemy.body_radius) \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			var dir := enemy.global_position - global_position
			dir.y = 0.0
			deal_damage(enemy, s.pulse_damage, {"strength": Impact.STRONG, "push": s.pulse_push_meters, "dir": dir, "ability": true})
	return true


# ---------------------------------------------------------------- R: Suprema em Círculo

## Mão na têmpora, um raio de 14 m corre em volta no sentido horário e o
## corpo vira junto: a volta inteira em SWEEP_TIME s. Cada inimigo no alcance
## leva o dano quando o raio passa por ele; o chão fica vermelho e apaga.
func use_special(_aim: Vector3) -> bool:
	if _sweep_time >= 0.0:
		return false
	stop_laser()
	busy = true
	invulnerable = true
	velocity = Vector3.ZERO
	ability_lock = SWEEP_TIME + 0.1
	_sweep_time = 0.0
	_sweep_yaw0 = atan2(-facing.x, -facing.z)
	_visual_yaw = _sweep_yaw0
	_sweep_hit.clear()
	_temple_target = 1.0
	var from := _muzzle()
	_sweep_meshes = Game.laser_beam(from, from + facing, 0.22, 0.85, 0.0)
	_sweep_flare = Game.laser_flare(from, 2.2, 0.0)
	_sweep_fx = FeixeFX.sweep(self, _fb().blast_radius)
	Game.laser_flare(from, 3.0, 0.3)
	return true


func _process_busy(delta: float) -> void:
	if _sweep_time >= 0.0:
		_tick_sweep(delta)


func _tick_sweep(delta: float) -> void:
	var s := _fb()
	_sweep_time += delta
	var k := clampf(_sweep_time / SWEEP_TIME, 0.0, 1.0)
	# Começa e termina um pouco mais devagar; horário visto de cima = yaw caindo.
	var turned := TAU * (k - sin(TAU * k) * 0.06)
	var yaw := _sweep_yaw0 - turned
	facing = Vector3(-sin(yaw), 0.0, -cos(yaw))
	_visual_yaw = yaw
	visual.rotation.y = yaw
	var from := _muzzle()
	var to := from + facing * s.blast_radius
	var hit := Game.raycast_world(from, to)
	if not hit.is_empty():
		to = hit["position"]
	var widths: Array[float] = [0.85 * (1.0 + 0.08 * sin(_sweep_time * 40.0)), 0.22]
	for i in _sweep_meshes.size():
		if is_instance_valid(_sweep_meshes[i]):
			Game.place_beam(_sweep_meshes[i], from, to, widths[i])
	if is_instance_valid(_sweep_flare):
		_sweep_flare.global_position = from
	if is_instance_valid(_sweep_fx):
		_sweep_fx.sweep_to(from, to, yaw, global_position)
	Game.shake(0.06, 0.1)
	# Dano em quem o raio já alcançou nesta volta (mesmo alcance de antes).
	for e in Game.living_enemies():
		var enemy := e as Actor
		if enemy in _sweep_hit:
			continue
		if Game.flat_distance(enemy.global_position, global_position) > s.blast_radius + enemy.body_radius \
				or not Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			continue
		var d := enemy.global_position - global_position
		var enemy_yaw := atan2(-d.x, -d.z)
		if fposmod(_sweep_yaw0 - enemy_yaw, TAU) <= turned + 0.05 or k >= 1.0:
			_sweep_hit.append(enemy)
			d.y = 0.0
			deal_damage(enemy, s.blast_damage, {"strength": Impact.SPECIAL, "ability": true, "dir": d, "color": Color(1, 0.3, 0.3)})
	if k >= 1.0:
		_end_sweep()


func _end_sweep() -> void:
	_sweep_time = -1.0
	busy = false
	_temple_target = 0.0
	if _dash_time_left <= 0.0:
		invulnerable = false
	for m in _sweep_meshes:
		if is_instance_valid(m):
			var mat := m.material_override as StandardMaterial3D
			var tw := m.create_tween()
			tw.tween_property(mat, "albedo_color:a", 0.0, 0.15)
			tw.tween_callback(m.queue_free)
	_sweep_meshes.clear()
	if is_instance_valid(_sweep_flare):
		_sweep_flare.queue_free()
	_sweep_flare = null
	if is_instance_valid(_sweep_fx):
		_sweep_fx.end_sweep()
	_sweep_fx = null


func _on_interrupted() -> void:
	stop_laser()
	super._on_interrupted()


# ---------------------------------------------------------------- IA

func _ai_combat(target: Actor, delta: float) -> Vector3:
	var s := _fb()
	_ai_target = target
	face_towards(target.global_position)
	var d := Game.flat_distance(global_position, target.global_position)
	if cooldown_ready("e") and d <= 5.0:
		repulsion_pulse()
	if not _laser_active and cooldown_ready("q") and d <= s.laser_range * 0.8:
		start_laser(1.5)
	if not _laser_active:
		optic_shot()
	var away := global_position - target.global_position
	away.y = 0.0
	if d < 5.0:
		return away.normalized() * 0.8
	if d > 11.0:
		return navigate_to(target.global_position, delta)
	return Vector3.ZERO


func go_down() -> void:
	stop_laser()
	super.go_down()
	# O modelo tem animação de queda: não precisa deitar a cápsula.
	visual.rotation.x = 0.0
	visual.position.y = 0.0


func _on_damaged(amount: float, source: Node) -> void:
	super._on_damaged(amount, source)
	if not is_dead:
		_anim("Hit_Chest", 1.5)


func _anim(anim_name: String, speed: float) -> void:
	if model != null:
		model.play_once(anim_name, speed)
