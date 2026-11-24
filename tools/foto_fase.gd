extends SceneTree
## Fotos da fase para pranchas. Uso:
## godot -s res://tools/foto_fase.gd -- <saida_dir> <nome:px,py,pz:tx,ty,tz[:fov]> ...
## (precisa de janela: rode com xvfb-run).

var _frames := 0
var _main: Node
var _cam: Camera3D
var _shots: Array = []
var _out := ""
var _i := 0
var _wait := 0
var _extra := 0


func _initialize() -> void:
	MainMenu.shown = true
	root.get_node("Game").mode = "fase"
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	for a in args.slice(1):
		var p: PackedStringArray = a.split(":")
		var pos := p[1].split_floats(",")
		var tgt := p[2].split_floats(",")
		_shots.append([p[0], Vector3(pos[0], pos[1], pos[2]), Vector3(tgt[0], tgt[1], tgt[2]), float(p[3]) if p.size() > 3 else 70.0])
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		for n in root.find_children("*", "", true, false):
			if n.get_class() == "CharacterBody3D" and n.get_script() != null and str(n.get_script().resource_path).contains("enem"):
				n.queue_free()
		for n in root.find_children("*", "CanvasLayer", true, false):
			n.visible = false
		for n in root.find_children("*", "Control", true, false):
			if n is Control:
				n.visible = false
		_cam = Camera3D.new()
		root.add_child(_cam)
		_cam.current = true
		get_root().get_tree().paused = false
	if _frames < 8:
		return false
	if _wait == 0:
		if _i >= _shots.size():
			return true
		var s: Array = _shots[_i]
		_cam.fov = s[3]
		_cam.position = s[1]
		_cam.look_at(s[2])
		_cam.current = true
		_wait = 1
		var porta: Node = root.find_child("PortaBlindada", true, false)
		if porta != null and "corte" in s[0]:
			porta._desenha_corte(0.62)
			porta._faiscas.position = porta._desenha_corte(0.62)
			porta._faiscas.emitting = true
			porta._cortando = 10.0
		if porta != null and "tombada" in s[0]:
			porta.open()
			_extra = 70
		return false
	_wait += 1
	if _wait < 6 + _extra:
		return false
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, _shots[_i][0]])
	print("foto ", _shots[_i][0])
	_i += 1
	_wait = 0
	_extra = 0
	return false
