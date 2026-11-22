class_name CameraRig
extends Node3D
## Câmera isométrica ortográfica fixa (45° de giro, ~30° de inclinação).
## Desliza até o novo herói em ~0,25 s na troca.

const DISTANCE := 40.0
const ORTHO_SIZE := 15.0

var camera: Camera3D
var target: Node3D
var _focus: Vector3 = Vector3.ZERO
var _slide_from: Vector3 = Vector3.ZERO
var _slide_t: float = 1.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ORTHO_SIZE
	camera.near = 0.1
	camera.far = 200.0
	camera.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
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
	if target == null or not is_instance_valid(target):
		return
	var goal := target.global_position
	goal.y = 0.0
	if _slide_t < 1.0:
		_slide_t = minf(1.0, _slide_t + delta / Game.rules.camera_slide_time)
		var k := 1.0 - pow(1.0 - _slide_t, 3.0)
		_focus = _slide_from.lerp(goal, k)
	else:
		_focus = _focus.lerp(goal, 1.0 - exp(-14.0 * delta))
	_place()


func _place() -> void:
	camera.global_position = _focus + camera.global_transform.basis.z * DISTANCE
