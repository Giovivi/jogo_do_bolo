class_name Projectile
extends Node3D
## Projétil simples. O acerto é calculado no plano do chão, então tiros
## de heróis alcançam drones e tiros de inimigos podem ser desviados com dash.

var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var damage: float = 5.0
var max_range: float = 15.0
var from_hero: bool = true
var source: Node = null
var hits_switches: bool = false
var radius: float = 0.25
var info: Dictionary = {}
## Altura de referência de quem atirou (pés), para o alcance vertical.
var ref_y: float = 0.0

var _travelled: float = 0.0


static func spawn(parent: Node, pos: Vector3, dir: Vector3, p_speed: float, p_damage: float, p_range: float, p_from_hero: bool, p_source: Node, color: Color, p_hits_switches: bool = false) -> Projectile:
	var p := Projectile.new()
	p.direction = Vector3(dir.x, 0.0, dir.z).normalized()
	p.speed = p_speed
	p.damage = p_damage
	p.max_range = p_range
	p.from_hero = p_from_hero
	p.source = p_source
	p.hits_switches = p_hits_switches
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.18 if p_from_hero else 0.26
	m.height = m.radius * 2.0
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	p.add_child(mi)
	parent.add_child(p)
	p.global_position = pos
	p.ref_y = pos.y - 1.2
	return p


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var from := global_position
	var to := from + direction * step
	# Interruptores (só tiros do Feixe acionam).
	if hits_switches:
		for sw in get_tree().get_nodes_in_group("switches"):
			var n := sw as Node3D
			if Game.flat_distance_to_segment(n.global_position, from, to) < 0.9:
				n.call("on_beam_hit", source)
				queue_free()
				return
	var hit := Game.raycast_world(from, to)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		to = hp
	if _check_targets(from, to):
		queue_free()
		return
	if not hit.is_empty():
		queue_free()
		return
	global_position = to
	_travelled += step
	if _travelled >= max_range:
		queue_free()


func _check_targets(from: Vector3, to: Vector3) -> bool:
	var targets: Array = []
	if from_hero:
		targets = Game.living_enemies()
	elif Game.party != null:
		targets = Game.party.living_heroes()
	for t in targets:
		var a := t as Actor
		if a == null or a.is_dead:
			continue
		if not Game.vertical_ok(ref_y, a, Game.REACH_RANGED):
			continue
		if Game.flat_distance_to_segment(a.global_position, from, to) <= a.body_radius + radius:
			if a.invulnerable:
				continue
			var hit_info := info.duplicate()
			hit_info["dir"] = direction
			if source != null and is_instance_valid(source) and source is Hero:
				(source as Hero).deal_damage(a, damage, hit_info)
			else:
				a.take_damage(damage, self, hit_info)
			return true
	return false
