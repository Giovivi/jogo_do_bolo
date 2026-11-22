class_name Feixe
extends Hero
## Feixe: distância e precisão. Tiro Óptico, Laser Contínuo,
## Pulso de Repulsão e Rajada Máxima.

var _laser_active: bool = false
var _laser_time: float = 0.0
var _laser_tick: float = 0.0
var _laser_ai_limit: float = 0.0
var _laser_mesh: MeshInstance3D


func _fb() -> FeixeStats:
	return stats as FeixeStats


func _ready() -> void:
	super._ready()
	# Faísca ciano no tiro e no laser, vermelha no pulso e na rajada.
	impact_color = Color(0.5, 0.9, 1.0, 0.9)
	impact_color_strong = Color(1.0, 0.3, 0.3, 0.9)
	_laser_mesh = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.25, 0.25, 1.0)
	_laser_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mesh.material_override = mat
	_laser_mesh.top_level = true
	_laser_mesh.visible = false
	add_child(_laser_mesh)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _laser_active:
		if is_dead or not in_party:
			stop_laser()
		else:
			_tick_laser(delta)


func ability_slots() -> Array:
	var s := _fb()
	var laser_name := "Laser (%.1f s)" % laser_time_left() if _laser_active else "Laser Contínuo (segure)"
	return [
		["Clique", "Tiro Óptico", 0.0, 0.0],
		["Q", laser_name, cooldown_left("q"), s.q_cooldown],
		["E", "Pulso de Repulsão", cooldown_left("e"), s.e_cooldown],
		["R", "Rajada Máxima", 0.0, 0.0],
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


func _muzzle() -> Vector3:
	return global_position + facing * 0.6 + Vector3(0, 1.2, 0)


# ---------------------------------------------------------------- básico

func optic_shot() -> bool:
	if not cooldown_ready("basic") or ability_lock > 0.0:
		return false
	var s := _fb()
	start_cooldown("basic", s.shot_interval)
	var p := Projectile.spawn(Game.world_root, _muzzle(), facing, s.shot_speed, s.shot_damage, s.shot_range, true, self, Color(0.5, 0.85, 1.0), true)
	p.info = {"strength": Impact.WEAK, "ability": false}
	return true


# ---------------------------------------------------------------- Q: Laser Contínuo

## ai_limit > 0 limita a duração (usado pela IA).
func start_laser(ai_limit: float) -> bool:
	if _laser_active or not cooldown_ready("q"):
		return false
	_laser_active = true
	_laser_time = 0.0
	_laser_tick = 0.0
	_laser_ai_limit = ai_limit
	move_multiplier = _fb().laser_move_multiplier
	_laser_mesh.visible = true
	return true


func stop_laser() -> void:
	if not _laser_active:
		return
	_laser_active = false
	move_multiplier = 1.0
	_laser_mesh.visible = false
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
	var to := from + facing * s.laser_range
	var hit := Game.raycast_world(from, to)
	if not hit.is_empty():
		to = hit["position"]
		var col: Object = hit["collider"]
		if col != null and col is Node and (col as Node).is_in_group("blast_doors"):
			col.call("cut", delta, self)
	# Interruptores também respondem ao laser.
	for sw in get_tree().get_nodes_in_group("switches"):
		var n := sw as Node3D
		if Game.flat_distance_to_segment(n.global_position, from, to) < 0.9:
			n.call("on_beam_hit", self)
	# Visual do feixe.
	var length := from.distance_to(to)
	_laser_mesh.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP) * Basis.from_scale(Vector3(1, 1, maxf(length, 0.1))), (from + to) * 0.5)
	# Dano em pulsos de 0,25 s para não poluir os números.
	_laser_tick += delta
	if _laser_tick >= 0.25:
		var dmg := s.laser_dps * _laser_tick
		_laser_tick = 0.0
		for e in Game.living_enemies():
			var enemy := e as Actor
			if Game.flat_distance_to_segment(enemy.global_position, from, to) <= s.laser_width * 0.5 + enemy.body_radius \
					and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
				deal_damage(enemy, dmg, {"strength": Impact.WEAK, "push": 0.0, "dir": facing, "ability": true, "color": Color(1, 0.4, 0.4)})


# ---------------------------------------------------------------- E: Pulso de Repulsão

func repulsion_pulse() -> bool:
	if not cooldown_ready("e") or ability_lock > 0.0:
		return false
	var s := _fb()
	start_cooldown("e", s.e_cooldown)
	ability_lock = 0.25
	Game.flash_cone(global_position, facing, s.pulse_range, s.pulse_arc_degrees, Color(0.4, 0.7, 1.0, 0.6), 0.3)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.in_cone(global_position, facing, enemy.global_position, s.pulse_range, s.pulse_arc_degrees, enemy.body_radius) \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_MELEE):
			var dir := enemy.global_position - global_position
			dir.y = 0.0
			deal_damage(enemy, s.pulse_damage, {"strength": Impact.STRONG, "push": s.pulse_push_meters, "dir": dir, "ability": true})
	return true


# ---------------------------------------------------------------- R: Rajada Máxima

func use_special(_aim: Vector3) -> bool:
	var s := _fb()
	var from := global_position
	var to := from + facing * s.blast_length
	Game.flash_line(from, to, s.blast_width, Color(1.0, 0.25, 0.25, 0.85), 0.45)
	# Invulnerável por um instante enquanto dispara.
	invulnerable = true
	get_tree().create_timer(BLAST_INVULNERABLE).timeout.connect(_end_blast_invulnerability)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.flat_distance_to_segment(enemy.global_position, from, to) <= s.blast_width * 0.5 + enemy.body_radius \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			deal_damage(enemy, s.blast_damage, {"strength": Impact.SPECIAL, "dir": facing, "ability": true, "color": Color(1, 0.3, 0.3)})
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
	face_towards(target.global_position)
	var d := Game.flat_distance(global_position, target.global_position)
	if cooldown_ready("e") and d <= 3.5:
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
