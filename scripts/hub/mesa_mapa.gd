class_name MesaMapa
extends Node3D
## Mapa da sala dos oficiais. F na mesa: a câmera desce até ficar reta em cima
## do mapa e cada missão vira um alfinete azul. Clicar num alfinete jogável
## pede o cartão da missão; Esc volta à sala.

signal mission_chosen(id: String)

const PIN_BLUE := Color(0.25, 0.62, 1.0)
const CAM_HEIGHT := 2.0     # acima do papel
const CAM_FOV := 50.0
const MOVE_TIME := 0.9
const PICK_RADIUS := 48.0   # pixels

## Missões no mapa: posição no papel (x, z), nome, tipo e se já dá para jogar.
const MISSIONS := [
	{"id": "posto_vigia", "pos": Vector2(-0.8, 0.2), "name": "POSTO VIGIA-01", "type": "Resgate", "playable": true},
	{"id": "deposito", "pos": Vector2(0.6, -0.4), "name": "DEPÓSITO 7", "type": "Saque", "playable": false},
	{"id": "torre", "pos": Vector2(1.1, 0.5), "name": "TORRE DE RÁDIO", "type": "Sabotagem", "playable": false},
	{"id": "estacao", "pos": Vector2(-0.2, -0.6), "name": "ESTAÇÃO NORTE", "type": "Resgate", "playable": false},
]

var paper_top: Vector3
## Luz em cima da mesa: fica mais fraca com a câmera perto do papel.
var lamp: OmniLight3D
var _lamp_energy := 0.0
var _pins: Array[Dictionary] = []
var _cam: Camera3D
var _hint_layer: CanvasLayer
var _hint: Label
var _active := false
var _moving := false
var _hover := -1


func setup(top: Vector3) -> void:
	paper_top = top
	process_mode = Node.PROCESS_MODE_ALWAYS
	var needle := Look.surface(Color(0.15, 0.15, 0.15))
	for m in MISSIONS:
		var base := paper_top + Vector3(m["pos"].x, 0.0, m["pos"].y)
		Look.piece(self, Look.cylinder(0.008, 0.008, 0.16, 4), needle, base + Vector3(0, 0.08, 0))
		var playable: bool = m["playable"]
		var head_mat: Material = Look.glow(PIN_BLUE, 1.4) if playable else Look.surface(PIN_BLUE.darkened(0.5), {"outline": 0.008})
		var head := Look.piece(self, Look.blob(0.035), head_mat, base + Vector3(0, 0.17, 0))
		var label := Label3D.new()
		label.text = m["name"] + "\n" + (m["type"] if playable else "em breve")
		label.font_size = 32
		label.pixel_size = 0.0011
		label.outline_size = 10
		label.modulate = Color(1, 1, 1) if playable else Color(0.78, 0.82, 0.9, 0.85)
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = base + Vector3(0, 0.02, 0.13)
		label.visible = false
		add_child(label)
		_pins.append({"data": m, "head": head, "label": label, "base": base})

	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.far = 200.0
	add_child(_cam)

	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 20
	_hint_layer.visible = false
	add_child(_hint_layer)
	_hint = Label.new()
	_hint.text = "Clique num alfinete para ver a missão   ·   Esc volta"
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -70
	_hint.offset_bottom = -30
	_hint.offset_left = -500
	_hint.offset_right = 500
	_hint_layer.add_child(_hint)


func is_open() -> bool:
	return _active


func open() -> void:
	if _active or Game.camera == null:
		return
	_active = true
	get_tree().paused = true
	if Game.hud != null:
		Game.hud.set_hidden(true)
	_cam.fov = Game.camera.fov
	_cam.global_transform = Game.camera.global_transform
	_cam.current = true
	if lamp != null:
		_lamp_energy = lamp.light_energy
	var goal := Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), paper_top + Vector3(0, CAM_HEIGHT, 0))
	_moving = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cam, "global_transform", goal, MOVE_TIME)
	tw.tween_property(_cam, "fov", CAM_FOV, MOVE_TIME)
	if lamp != null:
		tw.tween_property(lamp, "light_energy", _lamp_energy * 0.45, MOVE_TIME)
	tw.chain().tween_callback(func() -> void:
		_moving = false
		_show_map_ui(true))


func close() -> void:
	if not _active or _moving:
		return
	_show_map_ui(false)
	_moving = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cam, "global_transform", Game.camera.global_transform, MOVE_TIME * 0.8)
	tw.tween_property(_cam, "fov", Game.camera.fov, MOVE_TIME * 0.8)
	if lamp != null:
		tw.tween_property(lamp, "light_energy", _lamp_energy, MOVE_TIME * 0.8)
	tw.chain().tween_callback(func() -> void:
		_moving = false
		_active = false
		Game.camera.current = true
		get_tree().paused = false
		if Game.hud != null:
			Game.hud.set_hidden(false))


## O cartão da missão foi fechado (Esc): volta para o mapa.
func back_from_card() -> void:
	if not _active:
		return
	get_tree().paused = true
	if Game.hud != null:
		Game.hud.set_hidden(true)
	_show_map_ui(true)


func _show_map_ui(on: bool) -> void:
	_hint_layer.visible = on
	for p in _pins:
		(p["label"] as Label3D).visible = on
	if not on:
		_set_hover(-1)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _moving or not _hint_layer.visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventMouseMotion:
		_set_hover(_pick((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := _pick((event as InputEventMouseButton).position)
		if i < 0:
			return
		get_viewport().set_input_as_handled()
		var data: Dictionary = _pins[i]["data"]
		if data["playable"]:
			_show_map_ui(false)
			mission_chosen.emit(data["id"])
		else:
			_hint.text = "%s: em breve.   ·   Esc volta" % data["name"]


func _pick(screen_pos: Vector2) -> int:
	var best := -1
	var best_d := PICK_RADIUS
	for i in _pins.size():
		var head: Node3D = _pins[i]["head"]
		var sp := _cam.unproject_position(head.global_position)
		var d := sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _set_hover(i: int) -> void:
	if i == _hover:
		return
	if _hover >= 0:
		(_pins[_hover]["head"] as Node3D).scale = Vector3.ONE
	_hover = i
	if i >= 0:
		(_pins[i]["head"] as Node3D).scale = Vector3.ONE * 1.5
		var data: Dictionary = _pins[i]["data"]
		_hint.text = ("%s · %s   ·   clique para abrir" % [data["name"], data["type"]]) if data["playable"] else ("%s: em breve   ·   Esc volta" % data["name"])
	else:
		_hint.text = "Clique num alfinete para ver a missão   ·   Esc volta"
