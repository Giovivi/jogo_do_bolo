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


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Game.LAYER_ENEMIES
	max_health = stats.max_health
	health = max_health
	flying = stats.flying
	var h := 1.0 if flying else 1.6
	build_body(stats.color, h, stats.body_radius, Color(0.95, 0.9, 0.2))
	set_bar_color(Color(0.95, 0.3, 0.3))
	if flying:
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


func _apply_motion(move: Vector3, delta: float) -> void:
	var kb := apply_knockback(delta)
	var v := move * stats.move_speed + kb
	if flying:
		v.y = 0.0
	else:
		v.y = velocity.y - GRAVITY * delta
		if is_on_floor():
			v.y = -0.5
	velocity = v
	move_and_slide()


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
	Game.damage_number(global_position + Vector3(0, 0.5, 0), "!", Color(1, 0.9, 0.2))


func _fire() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var y := stats.hover_height + 0.5 if flying else 1.2
	var muzzle := global_position + facing * 0.6 + Vector3(0, y, 0)
	var aim := _target.global_position - global_position
	var p := Projectile.spawn(Game.world_root, muzzle, aim, stats.projectile_speed, stats.projectile_damage, stats.fire_range + 3.0, false, self, Color(1.0, 0.35, 0.2))
	p.info = {"knockback": 1.0}


func take_damage(amount: float, source: Node = null, info: Dictionary = {}) -> float:
	if is_dead:
		return 0.0
	activate()
	if stats.shielded and not info.get("ability", false) and source is Node3D:
		var to_src := (source as Node3D).global_position - global_position
		to_src.y = 0.0
		if to_src.normalized().dot(facing) > 0.35:
			Game.damage_number(global_position, "bloqueado", Color(0.7, 0.85, 1.0))
			knockback_velocity = -to_src.normalized() * 1.0
			return 0.0
	return super.take_damage(amount, source, info)


func _on_health_depleted(_source: Node) -> void:
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	died.emit()
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.25)
	tw.tween_callback(queue_free)
