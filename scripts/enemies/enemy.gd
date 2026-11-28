class_name Enemy
extends Actor
## Soldado (com ou sem escudo) e drone, conforme o EnemyStats.

const GRAVITY := 25.0

@export var stats: EnemyStats

## Inimigo só age depois de notar um herói (ou ser atingido).
var active: bool = false
## Se verdadeiro, já nasce em combate (ondas da cela).
var start_active: bool = false

var _fire_timer: float = 0.0
var _windup: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0
var _target: Hero = null
var _shield: MeshInstance3D
## Reação a golpes (seção 3.6): forte interrompe, especial derruba.
var _stun: float = 0.0
var _knockdown: float = 0.0
var _sway: float = 0.0
var _sway_time: float = 0.0
## Golpe corpo a corpo: lentidão, tempo sem atordoar e "firmeza" do escudo.
var _slow_time: float = 0.0
var _stagger_immune: float = 0.0
var _poise_damage: float = 0.0
var _slow_fx: GPUParticles3D
var _recoil_tween: Tween
## Congelado (Geada Absoluta da Mistral): não anda, não atira, não é empurrado.
var _frozen: float = 0.0
## Atração externa deste quadro (Olho do Furacão), somada ao movimento.
var pull_velocity := Vector3.ZERO


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Game.LAYER_ENEMIES
	max_health = stats.max_health
	health = max_health
	flying = stats.flying
	var h := maxf(1.0, stats.body_radius * 2.0) if flying else 1.6
	build_body(stats.color, h, stats.body_radius, Color(0.95, 0.9, 0.2))
	set_bar_color(Color(0.95, 0.3, 0.3))
	if flying:
		hover_offset = stats.hover_height
		collision_mask = Game.MASK_DRONE
		for c in get_children():
			if c is Node3D:
				(c as Node3D).position.y += stats.hover_height
		body_mesh.scale = Vector3(1.4, 0.5, 1.4)
	else:
		collision_mask = Game.MASK_ENEMY
	if stats.shielded:
		_shield = MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(1.3, 1.5, 0.15)
		_shield.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.75, 0.9)
		mat.metallic = 0.5
		_shield.material_override = mat
		_shield.position = Vector3(0, 0.9, -stats.body_radius - 0.25)
		visual.add_child(_shield)
	active = start_active
	_fire_timer = randf_range(0.5, stats.fire_interval)
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	tick_visual_feedback(delta)
	if is_dead:
		return
	if _tick_hit_reaction(delta):
		_apply_motion(Vector3.ZERO, delta)
		return
	_target = _pick_target()
	if not active:
		if _target != null:
			var d := Game.flat_distance(global_position, _target.global_position)
			if d <= stats.aggro_radius and Game.has_line_of_sight(global_position, _target.global_position):
				activate()
		_apply_motion(Vector3.ZERO, delta)
		return
	if _target == null:
		_apply_motion(Vector3.ZERO, delta)
		return

	face_towards(_target.global_position)
	var dist := Game.flat_distance(global_position, _target.global_position)
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var dir := to_target.normalized()
	var move := Vector3.ZERO

	if _windup > 0.0:
		_windup -= delta
		body_mesh.scale = Vector3.ONE * 1.15 if not flying else Vector3(1.6, 0.6, 1.6)
		if _windup <= 0.0:
			body_mesh.scale = Vector3.ONE if not flying else Vector3(1.4, 0.5, 1.4)
			_fire()
	else:
		if dist > stats.keep_max_distance:
			move = dir
		elif dist < stats.keep_min_distance:
			move = -dir
		else:
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_timer = randf_range(1.2, 2.5)
				_strafe_dir = -_strafe_dir
			move = dir.cross(Vector3.UP) * _strafe_dir * 0.5
		_fire_timer -= delta
		if _fire_timer <= 0.0 and dist <= stats.fire_range and Game.has_line_of_sight(global_position, _target.global_position):
			_windup = stats.fire_windup
			_fire_timer = stats.fire_interval + randf_range(-0.2, 0.3)
	_apply_motion(move, delta)


## Atualiza interrupção, queda e balanço. Devolve true enquanto o inimigo
## não pode agir.
func _tick_hit_reaction(delta: float) -> bool:
	_slow_time = maxf(0.0, _slow_time - delta)
	if _frozen > 0.0:
		_frozen = maxf(0.0, _frozen - delta)
		return true
	_stagger_immune = maxf(0.0, _stagger_immune - delta)
	if _slow_fx != null:
		_slow_fx.emitting = _slow_time > 0.0
	if _sway_time > 0.0:
		_sway_time = maxf(_sway_time - delta, 0.0)
		visual.rotation.z = sin(_sway_time * 28.0) * _sway * (_sway_time / 0.6)
	elif flying:
		visual.rotation.z = 0.0
	if _knockdown > 0.0:
		_knockdown -= delta
		if _knockdown <= 0.0:
			var tw := create_tween()
			tw.tween_property(visual, "rotation:x", 0.0, 0.18)
		return true
	if _stun > 0.0:
		_stun -= delta
		return true
	return false


func _apply_motion(move: Vector3, delta: float) -> void:
	var kb := apply_knockback(delta)
	var speed := stats.move_speed * (Impact.MELEE_SLOW if _slow_time > 0.0 else 1.0)
	var v := move * speed + kb + pull_velocity
	pull_velocity = Vector3.ZERO
	if _frozen > 0.0:
		v = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
	if flying:
		v.y = 0.0
	else:
		v.y = velocity.y - GRAVITY * delta
		if is_on_floor():
			v.y = -0.5
	velocity = v
	move_and_slide()


## Congela por `seconds` (a Geada Absoluta da Mistral): perde o tiro que
## estava carregando e fica parado até o gelo quebrar.
func freeze(seconds: float) -> void:
	if is_dead:
		return
	_frozen = maxf(_frozen, seconds)
	_cancel_windup()
	knockback_velocity = Vector3.ZERO


func is_frozen() -> bool:
	return _frozen > 0.0


func tick_visual_feedback(delta: float) -> void:
	super.tick_visual_feedback(delta)
	if _frozen > 0.0 and body_material != null and _flash_time <= 0.0:
		body_material.albedo_color = Color(0.72, 0.9, 1.0)
		body_material.emission_enabled = true
		body_material.emission = Color(0.25, 0.6, 0.8)


func _pick_target() -> Hero:
	if Game.party == null:
		return null
	var best: Hero = null
	var best_d := INF
	for h in Game.party.living_heroes():
		var d := Game.flat_distance(global_position, h.global_position)
		if d < best_d:
			best_d = d
			best = h
	return best


func activate() -> void:
	if active:
		return
	active = true
	Game.float_mark(global_position + Vector3(0, 0.5, 0), "!", Color(1, 0.9, 0.2))


func _fire() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var y := stats.hover_height + 0.5 if flying else 1.2
	var muzzle := global_position + facing * 0.6 + Vector3(0, y, 0)
	var aim := _target.global_position - global_position
	var p := Projectile.spawn(Game.world_root, muzzle, aim, stats.projectile_speed, stats.projectile_damage, stats.fire_range + 3.0, false, self, Color(1.0, 0.35, 0.2))
	p.info = {"strength": Impact.WEAK}


func take_damage(amount: float, source: Node = null, info: Dictionary = {}) -> float:
	if is_dead:
		return 0.0
	activate()
	if stats.shielded and not info.get("ability", false) and source is Node3D:
		var to_src := (source as Node3D).global_position - global_position
		to_src.y = 0.0
		if to_src.normalized().dot(facing) > 0.35:
			knockback_velocity = -to_src.normalized() * 1.0
			return 0.0
	if info.get("melee", false):
		_poise_damage += amount
	return super.take_damage(amount, source, info)


func _react_to_hit(strength: int, dir: Vector3, source: Node, info: Dictionary, killed: bool) -> void:
	super._react_to_hit(strength, dir, source, info, killed)
	if killed:
		return
	if info.get("melee", false):
		if flying:
			_sway = 0.35 if strength >= Impact.STRONG else 0.2
			_sway_time = 0.6
		_react_to_melee(strength >= Impact.STRONG)
		return
	if flying:
		# Drone não cai: é jogado para trás e balança.
		_sway = 0.35 if strength >= Impact.STRONG else 0.15
		_sway_time = 0.6
		if strength >= Impact.STRONG:
			_cancel_windup()
			_stun = maxf(_stun, Impact.STUN_STRONG)
		return
	if strength >= Impact.SPECIAL:
		_cancel_windup()
		_knockdown = Impact.KNOCKDOWN_SPECIAL
		_stun = 0.0
		var tw := create_tween()
		tw.tween_property(visual, "rotation:x", deg_to_rad(-80.0), 0.12)
	elif strength >= Impact.STRONG:
		_cancel_windup()
		_stun = maxf(_stun, Impact.STUN_STRONG)


## Golpe corpo a corpo: o inimigo sente o soco. Fica lento sempre; atordoa
## (perde o tiro carregado e dá um tranco para trás) se puder: o de escudo
## só depois de quebrar a firmeza, e ninguém logo depois de um golpe final.
func _react_to_melee(finisher: bool) -> void:
	_slow_time = Impact.MELEE_SLOW_TIME
	_ensure_slow_fx()
	var heavy := 1 if finisher else 0
	if _stagger_immune > 0.0:
		return
	if stats.shielded:
		if _poise_damage < Impact.SHIELD_POISE:
			return
		_poise_damage = 0.0
	var stun: float = Impact.MELEE_STUN[heavy]
	if flying:
		stun *= Impact.DRONE_STUN_MULTIPLIER
	_cancel_windup()
	_stun = maxf(_stun, stun)
	if finisher:
		_stagger_immune = stun + Impact.MELEE_STAGGER_IMMUNE
	if not flying and _knockdown <= 0.0:
		# Tranco: inclina para trás em 2 quadros e volta em 0,15 s.
		if _recoil_tween != null and _recoil_tween.is_valid():
			_recoil_tween.kill()
		_recoil_tween = create_tween()
		_recoil_tween.tween_property(visual, "rotation:x", deg_to_rad(Impact.MELEE_RECOIL_DEGREES[heavy]), 0.033)
		_recoil_tween.tween_property(visual, "rotation:x", 0.0, 0.15).set_delay(maxf(0.0, stun - 0.18))


## Chama azul nos pés enquanto o inimigo está lento.
func _ensure_slow_fx() -> void:
	if _slow_fx != null:
		return
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.45
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.42)
	var m := HandFire._additive(HandFire._flame_texture())
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = stats.body_radius + 0.05
	pm.emission_ring_inner_radius = stats.body_radius - 0.1
	pm.emission_ring_height = 0.05
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 1.5, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(0.6, 0.8, 1.0, 0.7), Color(0.2, 0.45, 1.0, 0.5), Color(0.05, 0.1, 0.6, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	add_child(p)
	p.position = Vector3(0, hover_offset + 0.05, 0)
	_slow_fx = p


func _cancel_windup() -> void:
	if _windup > 0.0:
		_windup = 0.0
		body_mesh.scale = Vector3.ONE if not flying else Vector3(1.4, 0.5, 1.4)
		_fire_timer = maxf(_fire_timer, 0.6)


func _on_health_depleted(_source: Node) -> void:
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	died.emit()
	# Explosão curta ao morrer.
	var c := global_position + Vector3(0, hover_offset, 0)
	Game.flash_ring(c, 1.4, Color(1.0, 0.6, 0.2, 0.8), 0.3)
	var burst := SphereMesh.new()
	burst.radius = 0.9
	burst.height = 1.8
	var orb := Game.flash_shape(burst, Transform3D(Basis.IDENTITY, c + Vector3(0, 0.8, 0)), Color(1.0, 0.85, 0.4, 0.85), 0.22)
	if orb != null:
		orb.create_tween().tween_property(orb, "scale", Vector3.ONE * 1.8, 0.22)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.25)
	tw.tween_callback(queue_free)
