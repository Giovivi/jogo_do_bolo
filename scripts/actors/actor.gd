class_name Actor
extends CharacterBody3D
## Base de heróis e inimigos: vida, dano, recuo e piscar branco.

signal damaged(amount: float)
signal died
## Reação a um golpe recebido (Impact.WEAK/STRONG/SPECIAL), para o HUD.
signal hit_reacted(strength: int)


var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false
var flying: bool = false
## Altura do corpo acima da posição (drones voam acima do próprio nó).
var hover_offset: float = 0.0
var body_radius: float = 0.45
var invulnerable: bool = false
var body_color: Color = Color.WHITE

var knockback_velocity: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD

var visual: Node3D
var body_mesh: MeshInstance3D
var body_material: StandardMaterial3D
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _flash_time: float = 0.0
var _blob: MeshInstance3D

static var _blob_tex: GradientTexture2D


func build_body(color: Color, height: float = 1.6, radius: float = 0.45, nose_color: Color = Color(0.1, 0.1, 0.1)) -> void:
	body_color = color
	body_radius = radius
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	body_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	body_mesh.mesh = capsule
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = color
	body_mesh.material_override = body_material
	body_mesh.position.y = height * 0.5
	visual.add_child(body_mesh)

	# "Nariz" que mostra para onde o ator está olhando.
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.22, 0.22, 0.5)
	nose.mesh = nose_mesh
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = nose_color
	nose.material_override = nose_mat
	nose.position = Vector3(0, height * 0.7, -radius - 0.1)
	visual.add_child(nose)

	var shape := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = radius
	cap_shape.height = height
	shape.shape = cap_shape
	shape.position.y = height * 0.5
	add_child(shape)

	# Sem barra de vida em cima dos personagens: a vida fica só no HUD.
	_build_blob_shadow(radius)


## Sombra redonda sempre no chão embaixo do ator, até no ar: é o que mostra
## a altura do pulo na câmera baixa.
func _build_blob_shadow(radius: float) -> void:
	_blob = MeshInstance3D.new()
	var m := PlaneMesh.new()
	m.size = Vector2(radius * 2.4, radius * 2.4)
	_blob.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _blob_texture()
	_blob.material_override = mat
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blob.top_level = true
	add_child(_blob)


static func _blob_texture() -> GradientTexture2D:
	if _blob_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.7, Color(1, 1, 1, 0.9))
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(1.0, 0.5)
	return _blob_tex


func _update_blob_shadow() -> void:
	if _blob == null:
		return
	if is_dead and not (self is Hero):
		_blob.visible = false
		return
	var top := global_position + Vector3(0, hover_offset + 0.5, 0)
	var hit := Game.raycast_world(top, top + Vector3(0, -30, 0), Game.LAYER_WORLD | Game.LAYER_WALKWAY)
	if hit.is_empty():
		_blob.visible = false
		return
	var p: Vector3 = hit["position"]
	_blob.visible = true
	_blob.global_position = p + Vector3(0, 0.03, 0)


func _build_health_bar(y: float) -> void:
	_bar_root = Node3D.new()
	_bar_root.position.y = y
	_bar_root.rotation.y = deg_to_rad(Game.rules.camera_yaw_degrees)
	add_child(_bar_root)
	var bg := MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(1.2, 0.12, 0.05)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bg_mat
	_bar_root.add_child(bg)
	_bar_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(1.2, 0.14, 0.07)
	_bar_fill.mesh = fill_mesh
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.3, 0.9, 0.35)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_fill.material_override = fill_mat
	_bar_root.add_child(_bar_fill)
	_update_bar()


func set_bar_color(c: Color) -> void:
	if _bar_fill != null:
		(_bar_fill.material_override as StandardMaterial3D).albedo_color = c


func _update_bar() -> void:
	if _bar_fill == null:
		return
	var f := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	_bar_fill.scale.x = maxf(f, 0.001)
	_bar_fill.position.x = -0.6 * (1.0 - f)
	_bar_root.visible = not is_dead


func face_towards(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.05:
		facing = d.normalized()
		if visual != null:
			visual.rotation.y = atan2(-facing.x, -facing.z)


## info: "strength" (Impact.WEAK/STRONG/SPECIAL), "push" (metros, opcional),
## "dir" (Vector3), "ability" (bool), "color" (Color)
func take_damage(amount: float, source: Node = null, info: Dictionary = {}) -> float:
	if is_dead or invulnerable or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, health)
	health -= amount
	var strength := Impact.strength_of(info)
	var dir: Vector3 = info.get("dir", Vector3.ZERO)
	if dir == Vector3.ZERO and source is Node3D:
		dir = global_position - (source as Node3D).global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	var killed := health <= 0.0
	# Quem apanha pisca em vermelho.
	_flash_time = 0.12
	_react_to_hit(strength, dir, source, info, killed)
	# "quiet": reação completa no alvo, mas sem pausa e tremor (raio contínuo).
	var feedback_strength: int = Impact.WEAK if info.get("quiet", false) else strength
	Game.impact_feedback(feedback_strength, source, self, killed, info)
	damaged.emit(amount)
	hit_reacted.emit(strength)
	_on_damaged(amount, source)
	if killed:
		health = 0.0
		_on_health_depleted(source)
	_update_bar()
	return dealt


## Reação padrão: empurrão de acordo com a força (ou "push" em metros).
func _react_to_hit(strength: int, dir: Vector3, _source: Node, info: Dictionary, _killed: bool) -> void:
	var meters: float = info.get("push", Impact.PUSH_METERS[clampi(strength, 0, 2)])
	push(dir, meters)


## Empurra "meters" metros na direção dada, sem encurtar um empurrão maior
## que já esteja em andamento (ex.: laser fraco logo depois do Pulso).
func push(dir: Vector3, meters: float) -> void:
	if dir.length() < 0.01 or meters <= 0.0:
		return
	var speed := Impact.push_speed(meters)
	if speed > knockback_velocity.length():
		knockback_velocity = dir * speed


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(max_health, health + amount)
	_update_bar()


func _on_damaged(_amount: float, _source: Node) -> void:
	pass


func _on_health_depleted(_source: Node) -> void:
	is_dead = true
	died.emit()


func tick_visual_feedback(delta: float) -> void:
	_update_blob_shadow()
	if body_material == null:
		return
	if _flash_time > 0.0:
		_flash_time -= delta
		body_material.albedo_color = Color(1.0, 0.25, 0.2)
		body_material.emission_enabled = true
		body_material.emission = Color(0.9, 0.1, 0.05)
	else:
		body_material.albedo_color = body_color
		body_material.emission_enabled = false


func apply_knockback(delta: float) -> Vector3:
	var kb := knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 30.0 * delta)
	return kb
