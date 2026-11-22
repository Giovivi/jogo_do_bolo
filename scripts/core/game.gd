extends Node
## Autoload "Game": entradas, regras globais e utilidades compartilhadas.

const LAYER_WORLD := 1
const LAYER_HEROES := 2
const LAYER_ENEMIES := 4
const LAYER_GAPS := 8
const LAYER_WALKWAY := 16

## Heróis não colidem com o bloqueio dos vãos (os vãos são buracos de
## verdade: dá para pular, planar ou cair). Inimigos continuam bloqueados.
const MASK_HERO := LAYER_WORLD | LAYER_ENEMIES | LAYER_WALKWAY
const MASK_HERO_GLIDING := MASK_HERO

## Alcance vertical: golpes e cones curtos / tiros, laser e áreas grandes.
const REACH_MELEE := 1.5
const REACH_RANGED := 3.0
const MASK_ENEMY := LAYER_WORLD | LAYER_HEROES | LAYER_ENEMIES | LAYER_GAPS | LAYER_WALKWAY
const MASK_DRONE := LAYER_WORLD | LAYER_ENEMIES

var rules: GameRules = preload("res://data/regras.tres")

## Preenchidos pela cena principal.
var party: Party = null
var hud: Node = null
var camera: Camera3D = null
var world_root: Node3D = null

## Retângulos (x0, z0, x1, z1) dos vãos, no plano do chão.
var gaps: Array[Rect2] = []

## "hub" = a escola; "fase" = Posto Vigia-01. Sobrevive ao recarregar a cena.
var mode: String = "hub"
## Progresso da campanha (sobrevive ao recarregar a cena, some ao fechar o jogo).
var progress: Dictionary = {"feixe": false, "lab_open": false, "runs": 0}

var chests_opened: int = 0
var chests_total: int = 0
var run_time: float = 0.0
var run_finished: bool = false

var _hitstop_running: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()


func reset_run() -> void:
	party = null
	hud = null
	camera = null
	world_root = null
	gaps.clear()
	chests_opened = 0
	chests_total = 0
	run_time = 0.0
	run_finished = false
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if not run_finished and not get_tree().paused and party != null:
		run_time += delta


# ---------------------------------------------------------------- entradas

func _setup_inputs() -> void:
	_add_key("move_up", KEY_W)
	_add_key("move_down", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("move_up", KEY_UP)
	_add_key("move_down", KEY_DOWN)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_RIGHT)
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_mouse("free_action", MOUSE_BUTTON_RIGHT)
	_add_key("ability_1", KEY_Q)
	_add_key("ability_2", KEY_E)
	_add_key("special", KEY_R)
	_add_key("dash", KEY_SHIFT)
	_add_key("jump", KEY_SPACE)
	_add_key("switch_1", KEY_1)
	_add_key("switch_2", KEY_2)
	_add_key("switch_3", KEY_3)
	_add_key("switch_4", KEY_4)
	_add_key("switch_next", KEY_TAB)
	_add_key("interact", KEY_F)
	_add_key("pause", KEY_ESCAPE)
	_add_key("debug_restart", KEY_F5)
	_add_key("debug_rescue", KEY_F3)
	_add_key("confirm", KEY_ENTER)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _add_key(action: String, key: Key) -> void:
	_ensure_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	_ensure_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- mira

## Projeta o cursor no plano do chão (y = plane_y).
func mouse_ground_point(plane_y: float = 0.0) -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var mouse := camera.get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return Vector3(origin.x, plane_y, origin.z)
	var t := (plane_y - origin.y) / dir.y
	return origin + dir * t


## Direções da tela projetadas no chão (WASD relativo à tela).
func screen_axes() -> Array[Vector3]:
	var fwd := Vector3.FORWARD
	var right := Vector3.RIGHT
	if camera != null:
		var b := camera.global_transform.basis
		fwd = -b.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		right = b.x
		right.y = 0.0
		right = right.normalized()
	var out: Array[Vector3] = [fwd, right]
	return out


# ---------------------------------------------------------------- mundo

## Raio contra as paredes (camada 1). Retorna {} se não bater.
func raycast_world(from: Vector3, to: Vector3, mask: int = LAYER_WORLD) -> Dictionary:
	if world_root == null:
		return {}
	var space := world_root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.collide_with_areas = false
	return space.intersect_ray(q)


func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	var from := Vector3(a.x, a.y + 1.2, a.z)
	var to := Vector3(b.x, b.y + 1.2, b.z)
	return raycast_world(from, to).is_empty()


## O alvo está dentro do alcance vertical de quem ataca (pés em from_y)?
func vertical_ok(from_y: float, target: Actor, reach: float) -> bool:
	return absf(target.global_position.y + target.hover_offset - from_y) <= reach


func is_over_gap(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	for r in gaps:
		if r.has_point(p):
			return true
	return false


## Há um vão logo à frente (até "ahead" metros) na direção dada?
func gap_ahead(pos: Vector3, dir: Vector3, ahead: float = 1.4) -> bool:
	if dir.length() < 0.01:
		return false
	var d := dir.normalized()
	var steps := 6
	for i in range(1, steps + 1):
		var probe := pos + d * (ahead * float(i) / float(steps))
		if is_over_gap(probe):
			return true
	return false


# ---------------------------------------------------------------- feedback

## Pausa no acerto. Sem argumento usa a duração padrão das regras.
func hitstop(seconds: float = -1.0) -> void:
	var t := rules.hitstop_seconds if seconds < 0.0 else seconds
	if _hitstop_running or t <= 0.0:
		return
	_hitstop_running = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(t, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_running = false


## Tremor de câmera (respeita a opção screen_shake das regras).
func shake(amount: float, duration: float) -> void:
	if not rules.screen_shake or amount <= 0.0 or party == null or party.camera_rig == null:
		return
	party.camera_rig.add_shake(amount, duration)


## Pausa e tremor de um acerto (seção 3.6). Só o que o herói controlado
## faz, ou sofre, mexe com o tempo e a câmera; a IA nunca.
func impact_feedback(strength: int, source: Node, target: Node, killed: bool) -> void:
	var s := clampi(strength, 0, 2)
	if Impact.from_player(source):
		var frames: int = Impact.HITSTOP_FRAMES[s]
		if killed:
			frames = maxi(frames, Impact.KILL_HITSTOP_FRAMES)
		if frames > 0:
			hitstop(float(frames) / 60.0)
		var sh: Array = Impact.SHAKE[s]
		shake(sh[0], sh[1])
	elif target is Hero and (target as Hero).controlled and s >= Impact.STRONG:
		var light: Array = Impact.SHAKE[Impact.STRONG]
		shake(light[0], light[1])


## Marca flutuante curta (ex.: "!" do inimigo que avistou o grupo).
## O jogo não mostra números de dano nem de cura: a vida reage só na HUD.
func float_mark(pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	if world_root == null:
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.outline_size = 10
	label.font_size = 56
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	world_root.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.3, 0.3), 2.2, randf_range(-0.3, 0.3))
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", label.global_position + Vector3(0, 1.2, 0), 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)


func message(text: String, seconds: float = 3.0) -> void:
	if hud != null and hud.has_method("show_message"):
		hud.show_message(text, seconds)


## Efeito visual simples: um volume que aparece e some.
func flash_shape(mesh: Mesh, xform: Transform3D, color: Color, duration: float = 0.25) -> MeshInstance3D:
	if world_root == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mi)
	mi.global_transform = xform
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(mi.queue_free)
	return mi


func flash_ring(center: Vector3, radius: float, color: Color, duration: float = 0.3) -> void:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.1
	flash_shape(m, Transform3D(Basis.IDENTITY, Vector3(center.x, center.y + 0.1, center.z)), color, duration)


## Cone/arco achatado no chão, apontando para "dir".
func flash_cone(origin: Vector3, dir: Vector3, length: float, arc_degrees: float, color: Color, duration: float = 0.25) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 12
	var half := deg_to_rad(arc_degrees) * 0.5
	for i in segs:
		var a0 := -half + (2.0 * half) * float(i) / float(segs)
		var a1 := -half + (2.0 * half) * float(i + 1) / float(segs)
		im.surface_add_vertex(Vector3.ZERO)
		im.surface_add_vertex(Vector3(sin(a0), 0, -cos(a0)) * length)
		im.surface_add_vertex(Vector3(sin(a1), 0, -cos(a1)) * length)
	im.surface_end()
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	var basis := Basis.looking_at(flat, Vector3.UP)
	flash_shape(im, Transform3D(basis, Vector3(origin.x, 0.15, origin.z)), color, duration)


## Faixa reta no chão de "from" até "to".
func flash_line(from: Vector3, to: Vector3, width: float, color: Color, duration: float = 0.2, height: float = 1.1) -> void:
	var flat_from := Vector3(from.x, height, from.z)
	var flat_to := Vector3(to.x, height, to.z)
	var length := flat_from.distance_to(flat_to)
	if length < 0.01:
		return
	var m := BoxMesh.new()
	m.size = Vector3(width, 0.25, length)
	var basis := Basis.looking_at((flat_to - flat_from).normalized(), Vector3.UP)
	flash_shape(m, Transform3D(basis, (flat_from + flat_to) * 0.5), color, duration)


# ---------------------------------------------------------------- consultas

func living_enemies() -> Array[Node]:
	var out: Array[Node] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_dead:
			out.append(e)
	return out


## Distância no plano do chão.
func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


## Distância de um ponto a um segmento, no plano do chão.
func flat_distance_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p2.distance_to(a2)
	var t := clampf((p2 - a2).dot(ab) / len2, 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


## O alvo está dentro do cone (no plano do chão)?
func in_cone(origin: Vector3, dir: Vector3, target: Vector3, length: float, arc_degrees: float, extra_radius: float = 0.0) -> bool:
	var to := Vector2(target.x - origin.x, target.z - origin.z)
	var dist := to.length()
	if dist > length + extra_radius:
		return false
	if dist < 0.6:
		return true
	var d2 := Vector2(dir.x, dir.z).normalized()
	var angle := absf(d2.angle_to(to))
	return angle <= deg_to_rad(arc_degrees) * 0.5 + atan2(extra_radius, dist)
