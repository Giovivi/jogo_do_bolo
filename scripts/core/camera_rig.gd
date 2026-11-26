class_name CameraRig
extends Node3D
## Câmera de frente (seção 3.7). Ângulos, perspectiva e enquadramento vêm
## de data/regras.tres. O herói fica a ~30% da altura da tela, o foco
## segue um pouco a mira e cada sala escolhe um nível de zoom (zonas de
## câmera). O zoom aproxima a câmera, nunca muda o FOV. Desliza até o novo
## herói na troca, já levando o zoom da sala dele.
## Com Game.rules.camera_behind, vira a câmera de teste estilo GTA: baixa,
## atrás do ombro, girada pelo mouse (veja "atrás do herói" no fim).

## O que segura a câmera atrás do herói: paredes, tetos e a passarela alta
## (que é de outra camada, mas é visível e alta).
const CAMERA_MASK := Game.LAYER_WORLD | Game.LAYER_WALKWAY

## Distância da câmera no nível aberto (100%).
var distance: float = 40.0

var camera: Camera3D
var target: Node3D
var _focus: Vector3 = Vector3.ZERO
var _slide_from: Vector3 = Vector3.ZERO
var _slide_t: float = 1.0
var _shake_amount: float = 0.0
var _shake_time: float = 0.0
var _shake_total: float = 0.0
var _aim_offset: Vector3 = Vector3.ZERO

var _zone: CameraZone = null
var _zoom: float = 1.0
var _zoom_from: float = 1.0
var _zoom_to: float = 1.0
var _zoom_t: float = 1.0
var _zoom_time: float = 0.8
## As zonas nascem logo depois da câmera: a primeira entra sem transição.
var _snap_zone: bool = false

# Câmera atrás do herói (Game.rules.camera_behind).
var behind: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
## Segundos desde o último movimento do mouse.
var _since_mouse: float = 999.0
var _arm: float = 0.0


func _ready() -> void:
	# Roda pausado também, para soltar o cursor nos menus.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var r := Game.rules
	camera = Camera3D.new()
	if r.camera_perspective:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = r.camera_fov
		# Distância que enquadra a mesma altura da versão ortográfica.
		distance = r.camera_view_height / (2.0 * tan(deg_to_rad(r.camera_fov) * 0.5))
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = r.camera_view_height
		distance = 40.0
	camera.near = 0.1
	camera.far = 300.0
	camera.rotation_degrees = Vector3(-r.camera_pitch_degrees, r.camera_yaw_degrees, 0.0)
	behind = r.camera_behind
	if behind:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = r.behind_fov
		camera.near = 0.05
		_pitch = deg_to_rad(-r.behind_pitch_degrees)
		_arm = r.behind_distance
	add_child(camera)
	camera.current = true
	Game.camera = camera


func follow(new_target: Node3D, slide: bool) -> void:
	target = new_target
	if behind:
		_follow_behind(new_target, slide)
		return
	# O nível de zoom da sala do novo herói vem junto.
	var zone := _zone_at(new_target.global_position, 0.0)
	if zone != null:
		_zone = zone
	if slide:
		_slide_from = _focus
		_slide_t = 0.0
		_start_zoom(_zone_zoom(), Game.rules.camera_slide_time)
	else:
		_focus = new_target.global_position
		_slide_t = 1.0
		_zoom = _zone_zoom()
		_zoom_to = _zoom
		_zoom_t = 1.0
		_snap_zone = zone == null
		_aim_offset = Vector3.ZERO
	_place()


func _process(delta: float) -> void:
	if behind:
		_update_mouse_mode()
	if get_tree().paused:
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	if target == null or not is_instance_valid(target):
		return
	if behind:
		_process_behind(delta)
		return
	_update_zone()
	_tick_zoom(delta)
	_update_aim_offset(delta)
	var goal := target.global_position + _aim_offset
	# Altura: acompanha plataformas devagar, sem balançar a cada pulo.
	var ground_y := target.global_position.y
	if target is CharacterBody3D and not (target as CharacterBody3D).is_on_floor():
		ground_y = _focus.y
	goal.y = ground_y
	if _slide_t < 1.0:
		_slide_t = minf(1.0, _slide_t + delta / Game.rules.camera_slide_time)
		var k := 1.0 - pow(1.0 - _slide_t, 3.0)
		_focus = _slide_from.lerp(goal, k)
	else:
		var y := lerpf(_focus.y, goal.y, 1.0 - exp(-4.0 * delta))
		_focus = _focus.lerp(goal, 1.0 - exp(-14.0 * delta))
		_focus.y = y
	_place()


func add_shake(amount: float, duration: float) -> void:
	if amount >= _shake_amount * (_shake_time / maxf(_shake_total, 0.001)):
		_shake_amount = amount
		_shake_time = duration
		_shake_total = duration


# ---------------------------------------------------------------- zonas

## Zona onde o ponto está, pelo menos "inset" metros para dentro.
func _zone_at(pos: Vector3, inset: float) -> CameraZone:
	if not is_inside_tree():
		return null
	var p := Vector2(pos.x, pos.z)
	for n in get_tree().get_nodes_in_group("camera_zones"):
		var z := n as CameraZone
		if z != null and z.rect().grow(-inset).has_point(p):
			return z
	return null


func _zone_zoom() -> float:
	return _zone.zoom() if _zone != null else 1.0


## Muda de nível só depois de o herói entrar ~1 m na outra sala; em
## corredores sem zona, mantém o nível de onde veio.
func _update_zone() -> void:
	if _slide_t < 1.0:
		return
	var inset: float = Game.rules.camera_zone_hysteresis
	if _zone == null:
		inset = 0.0
	var z := _zone_at(target.global_position, inset)
	if z == null or z == _zone:
		return
	_zone = z
	if _snap_zone:
		_snap_zone = false
		_zoom = _zone_zoom()
		_zoom_to = _zoom
		_zoom_t = 1.0
		return
	if absf(_zone_zoom() - _zoom_to) > 0.001:
		_start_zoom(_zone_zoom(), Game.rules.camera_zone_transition)


func _start_zoom(to: float, seconds: float) -> void:
	_zoom_from = _zoom
	_zoom_to = to
	_zoom_time = maxf(seconds, 0.01)
	_zoom_t = 0.0


func _tick_zoom(delta: float) -> void:
	if _zoom_t >= 1.0:
		return
	_zoom_t = minf(1.0, _zoom_t + delta / _zoom_time)
	# Aceleração e freio.
	_zoom = lerpf(_zoom_from, _zoom_to, smoothstep(0.0, 1.0, _zoom_t))


# ---------------------------------------------------------------- mira

## O foco anda até camera_aim_follow metros na direção do cursor. Usa a
## posição do mouse na tela em relação ao lugar fixo do herói, para a
## câmera não "correr atrás" do próprio deslocamento.
func _update_aim_offset(delta: float) -> void:
	var want := Vector3.ZERO
	var n: float = Game.rules.camera_aim_follow
	var hero := target as Hero
	if n > 0.0 and hero != null and hero.controlled and not hero.is_dead:
		var vp := get_viewport()
		var size := vp.get_visible_rect().size
		if size.y > 1.0:
			var anchor: Vector2 = Vector2(size.x * 0.5, size.y * (1.0 - Game.rules.camera_hero_screen_fraction))
			var m: Vector2 = (vp.get_mouse_position() - anchor) / (size.y * 0.5)
			m = m.limit_length(1.0)
			var axes := Game.screen_axes()
			want = (axes[1] * m.x - axes[0] * m.y) * n
	_aim_offset = _aim_offset.lerp(want, 1.0 - exp(-3.0 * delta))


# ---------------------------------------------------------------- posição

func _place() -> void:
	var r := Game.rules
	var b := camera.global_transform.basis
	var d: float = distance * _zoom
	# Altura visível no plano do herói, para pôr o herói a ~30% de baixo.
	var view_h: float = r.camera_view_height
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		view_h = 2.0 * d * tan(deg_to_rad(camera.fov) * 0.5)
	else:
		camera.size = r.camera_view_height * _zoom
		view_h = camera.size
	var lift: Vector3 = b.y * view_h * (0.5 - r.camera_hero_screen_fraction)
	var offset := Vector3.ZERO
	if _shake_time > 0.0:
		var k := _shake_time / maxf(_shake_total, 0.001)
		offset = (b.x * randf_range(-1.0, 1.0) + b.y * randf_range(-1.0, 1.0)) * _shake_amount * k
	camera.global_position = _focus + b.z * d + lift + offset


# ---------------------------------------------------------------- atrás do herói

## Ângulo (yaw) que põe a câmera atrás de quem olha para "dir".
static func _yaw_behind(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _hero_facing(t: Node3D) -> Vector3:
	var a := t as Actor
	if a != null and a.facing.length() > 0.1:
		return a.facing
	return -t.global_transform.basis.z


func _follow_behind(new_target: Node3D, slide: bool) -> void:
	if slide:
		_slide_from = _focus
		_slide_t = 0.0
	else:
		_focus = new_target.global_position
		_slide_t = 1.0
		_yaw = _yaw_behind(_hero_facing(new_target))
		_pitch = deg_to_rad(-Game.rules.behind_pitch_degrees)
	_place_behind(1.0)


## Cursor preso (e escondido) durante o jogo; solto nos menus e pausa.
func _update_mouse_mode() -> void:
	var want := Input.MOUSE_MODE_VISIBLE
	if not get_tree().paused and get_window().has_focus():
		want = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _exit_tree() -> void:
	if behind:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## O mouse gira a câmera em volta do herói.
func _unhandled_input(event: InputEvent) -> void:
	if not behind or get_tree().paused:
		return
	var mm := event as InputEventMouseMotion
	if mm != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := deg_to_rad(Game.rules.behind_mouse_sensitivity)
		_yaw -= mm.relative.x * k
		_pitch = clampf(_pitch - mm.relative.y * k, deg_to_rad(-60.0), deg_to_rad(25.0))
		_since_mouse = 0.0


## Para testes e pranchas: gira a câmera como se o mouse tivesse girado.
func orbit_by(yaw_degrees: float, pitch_degrees: float = 0.0) -> void:
	_yaw += deg_to_rad(yaw_degrees)
	_pitch += deg_to_rad(pitch_degrees)
	_since_mouse = 0.0


func _process_behind(delta: float) -> void:
	var r := Game.rules
	_since_mouse += delta

	var goal := target.global_position
	var ground_y := goal.y
	if target is CharacterBody3D and not (target as CharacterBody3D).is_on_floor():
		ground_y = _focus.y
	goal.y = ground_y
	if _slide_t < 1.0:
		_slide_t = minf(1.0, _slide_t + delta / r.camera_slide_time)
		var k := 1.0 - pow(1.0 - _slide_t, 3.0)
		_focus = _slide_from.lerp(goal, k)
	else:
		var y := lerpf(_focus.y, goal.y, 1.0 - exp(-6.0 * delta))
		_focus = _focus.lerp(goal, 1.0 - exp(-16.0 * delta))
		_focus.y = y

	# Andando sem mexer o mouse: volta devagar para trás do herói.
	if _since_mouse >= r.behind_return_delay and _moving():
		var f := 1.0 - exp(-r.behind_return_speed * delta)
		_yaw += angle_difference(_yaw, _yaw_behind(_hero_facing(target))) * f
		_pitch = lerpf(_pitch, deg_to_rad(-r.behind_pitch_degrees), f)
	_place_behind(delta)


func _moving() -> bool:
	var b := target as CharacterBody3D
	if b == null:
		return false
	return Vector2(b.velocity.x, b.velocity.z).length() > 0.5


func _place_behind(delta: float) -> void:
	var r := Game.rules
	var pivot := _focus + Vector3.UP * r.behind_pivot_height
	var basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var back := basis.z
	# Por cima do ombro direito, sem enfiar o ombro na parede ao lado.
	var side := r.behind_shoulder
	var side_hit := Game.raycast_world(pivot, pivot + basis.x * (side + 0.3), CAMERA_MASK)
	if not side_hit.is_empty():
		side = maxf(0.0, pivot.distance_to(side_hit["position"]) - 0.3)
	pivot += basis.x * side
	# Parede atrás: a câmera chega mais perto do herói (entra rápido, sai devagar).
	var want := r.behind_distance
	var hit := Game.raycast_world(pivot, pivot + back * (want + 0.3), CAMERA_MASK)
	if not hit.is_empty():
		want = maxf(0.6, pivot.distance_to(hit["position"]) - 0.3)
	if want < _arm or delta >= 1.0:
		_arm = want
	else:
		_arm = lerpf(_arm, want, 1.0 - exp(-3.0 * delta))
	var offset := Vector3.ZERO
	if _shake_time > 0.0:
		var k := _shake_time / maxf(_shake_total, 0.001)
		offset = (basis.x * randf_range(-1.0, 1.0) + basis.y * randf_range(-1.0, 1.0)) * _shake_amount * k * 0.5
	camera.global_transform = Transform3D(basis, pivot + back * _arm + offset)
