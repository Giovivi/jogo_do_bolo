class_name BeamSwitch
extends Node3D
## Interruptor distante: só o tiro (ou o laser) do Feixe aciona.

signal triggered

var on: bool = false
var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("switches")
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.45
	m.bottom_radius = 0.45
	m.height = 0.9
	mi.mesh = m
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.3, 0.2)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.2, 0.1)
	mi.material_override = _mat
	add_child(mi)
	var label := Label3D.new()
	label.text = "interruptor"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.01
	label.outline_size = 8
	label.position.y = 1.0
	add_child(label)


func on_beam_hit(source: Node) -> void:
	if on:
		return
	# Só conta o tiro do Feixe controlado pelo jogador (a IA não resolve o puzzle).
	if not (source is Feixe) or not (source as Feixe).controlled:
		return
	on = true
	_mat.albedo_color = Color(0.2, 1.0, 0.4)
	_mat.emission = Color(0.1, 0.9, 0.3)
	Game.flash_ring(global_position, 1.0, Color(0.3, 1.0, 0.5, 0.8), 0.4)
	triggered.emit()
