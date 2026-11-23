class_name Feixe
extends Hero
## Feixe: distância e precisão, tudo em raio laser vermelho (prancha
## feixe-laser-drone-v2): Raio Laser, Raio Forte, Cone de Raios e Suprema
## em Círculo. Cada disparo solta um clarão estrelado do rosto.

## Invulnerável por este tempo ao disparar a Suprema.
const BLAST_INVULNERABLE := 0.35
## Tolerância de altura entre o raio e o centro do corpo do inimigo (m).
const BEAM_HEIGHT_TOLERANCE := 1.1

var _laser_active: bool = false
var _laser_time: float = 0.0
var _laser_tick: float = 0.0
var _laser_ai_limit: float = 0.0
var _laser_meshes: Array[MeshInstance3D] = []
var _laser_flare: Sprite3D
var _ai_target: Actor = null


func _fb() -> FeixeStats:
	return stats as FeixeStats


func _ready() -> void:
	super._ready()
	# Faísca vermelha clara no raio, vermelha forte no Q, no E e no R.
	impact_color = Color(1.0, 0.55, 0.45, 0.9)
	impact_color_strong = Color(1.0, 0.2, 0.15, 0.95)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
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
	return global_position + facing * 0.5 + Vector3(0, 1.25, 0)


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
	var from := _muzzle()
	var to := _beam_end(from, s.laser_range)
	# Porta blindada: o raio forte corta.
	var hit := Game.raycast_world(from, from + (to - from) * 1.05)
	if not hit.is_empty():
		var col: Object = hit["collider"]
		if col != null and col is Node and (col as Node).is_in_group("blast_doors"):
			col.call("cut", delta, self)
	_hit_switches(from, to)
	# Visual: raio grosso e clarão maior, fixos no rosto.
	var widths: Array[float] = [0.7, 0.16]
	for i in _laser_meshes.size():
		if is_instance_valid(_laser_meshes[i]):
			Game.place_beam(_laser_meshes[i], from, to, widths[i])
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


# ---------------------------------------------------------------- E: Cone de Raios

func repulsion_pulse() -> bool:
	if not cooldown_ready("e") or ability_lock > 0.0:
		return false
	var s := _fb()
	start_cooldown("e", s.e_cooldown)
	ability_lock = 0.25
	var from := _muzzle()
	Game.flash_cone(global_position, facing, s.pulse_range, s.pulse_arc_degrees, Color(1.0, 0.2, 0.15, 0.35), 0.3)
	# Leque de 5 raios.
	var half := deg_to_rad(s.pulse_arc_degrees) * 0.5
	for i in 5:
		var ang := -half + 2.0 * half * float(i) / 4.0
		var d := facing.rotated(Vector3.UP, ang)
		Game.laser_beam(from, from + d * s.pulse_range, 0.07, 0.3, 0.25)
	Game.laser_flare(from, 1.3, 0.15)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.in_cone(global_position, facing, enemy.global_position, s.pulse_range, s.pulse_arc_degrees, enemy.body_radius) \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			var dir := enemy.global_position - global_position
			dir.y = 0.0
			deal_damage(enemy, s.pulse_damage, {"strength": Impact.STRONG, "push": s.pulse_push_meters, "dir": dir, "ability": true})
	return true


# ---------------------------------------------------------------- R: Suprema em Círculo

## Explosão de raios em volta do Feixe, grande o bastante para pegar a sala.
func use_special(_aim: Vector3) -> bool:
	var s := _fb()
	var center := global_position
	var from := _muzzle() - facing * 0.5
	Game.flash_ring(center, s.blast_radius, Color(1.0, 0.2, 0.15, 0.45), 0.5)
	Game.flash_ring(center, s.blast_radius * 0.5, Color(1.0, 0.45, 0.35, 0.6), 0.35)
	for i in 16:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / 16.0)
		var to := from + d * s.blast_radius
		var hit := Game.raycast_world(from, to)
		if not hit.is_empty():
			to = hit["position"]
		Game.laser_beam(from, to, 0.08, 0.35, 0.4)
	Game.laser_flare(from, 3.0, 0.35)
	# Invulnerável por um instante enquanto dispara.
	invulnerable = true
	get_tree().create_timer(BLAST_INVULNERABLE).timeout.connect(_end_blast_invulnerability)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.flat_distance(enemy.global_position, center) <= s.blast_radius + enemy.body_radius \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			deal_damage(enemy, s.blast_damage, {"strength": Impact.SPECIAL, "ability": true, "color": Color(1, 0.3, 0.3)})
	return true


func _end_blast_invulnerability() -> void:
	if _dash_time_left <= 0.0 and not busy:
		invulnerable = false


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
