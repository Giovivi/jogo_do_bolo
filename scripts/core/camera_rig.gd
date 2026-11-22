class_name CameraRig
extends Node3D
## Câmera fixa (isométrica ortográfica por padrão). Ângulos, perspectiva e
## enquadramento vêm de data/regras.tres. Desliza até o novo herói na troca.

var distance: float = 40.0

var camera: Camera3D
var target: Node3D
var _focus: Vector3 = Vector3.ZERO
var _slide_from: Vector3 = Vector3.ZERO
var _slide_t: float = 1.0
var _shake_amount: float = 0.0
var _shake_time: float = 0.0
var _shake_total: float = 0.0


func _ready() -> void:
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
	add_child(camera)
	camera.current = true
	Game.camera = camera


func follow(new_target: Node3D, slide: bool) -> void:
	target = new_target
	if slide:
		_slide_from = _focus
		_slide_t = 0.0
	else:
		_focus = new_target.global_position
		_slide_t = 1.0
	_place()


func _process(delta: float) -> void:
	_shake_time = maxf(0.0, _shake_time - delta)
	if target == null or not is_instance_valid(target):
		return
	var goal := target.global_position
	# Altura: acompanha plataformas devagar, sem balançar a cada pulo.
	var ground_y := goal.y
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


func _place() -> void:
	var offset := Vector3.ZERO
	if _shake_time > 0.0:
		var k := _shake_time / maxf(_shake_total, 0.001)
		var b := camera.global_transform.basis
		offset = (b.x * randf_range(-1.0, 1.0) + b.y * randf_range(-1.0, 1.0)) * _shake_amount * k
	camera.global_position = _focus + camera.global_transform.basis.z * distance + offset
