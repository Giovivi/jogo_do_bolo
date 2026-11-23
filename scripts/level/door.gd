class_name Door
extends StaticBody3D
## Porta simples (abre por interruptor) ou blindada (o laser do Feixe corta).

signal opened_door

@export var blast_door: bool = false
@export var cut_time_needed: float = 1.5

var is_open: bool = false
var cut_progress: float = 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D


func setup(size: Vector3, color: Color) -> void:
	collision_layer = Game.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	_mesh = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	_mesh.mesh = m
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.metallic = 0.6 if blast_door else 0.1
	_mesh.material_override = _mat
	_mesh.position.y = size.y * 0.5
	add_child(_mesh)
	if blast_door:
		add_to_group("blast_doors")
		_label = Label3D.new()
		_label.text = "porta blindada"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 40
		_label.pixel_size = 0.01
		_label.outline_size = 8
		_label.position.y = size.y + 0.5
		add_child(_label)
		# Sem texto em cima da porta: o cadeado do HUD já avisa quem abre.
		_label.visible = false


## Chamado pelo laser do Feixe enquanto o feixe toca a porta.
func cut(delta: float, source: Node) -> void:
	if is_open or not blast_door or not (source is Feixe):
		return
	cut_progress += delta
	var f := clampf(cut_progress / cut_time_needed, 0.0, 1.0)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.4, 0.1) * f
	# Mostra o progresso só enquanto corta.
	_label.text = "cortando %d%%" % int(f * 100.0)
	_label.visible = true
	_label.modulate = Color(1.0, 0.6, 0.3)
	if cut_progress >= cut_time_needed:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	collision_layer = 0
	if _label != null:
		_label.visible = false
	var tw := create_tween()
	tw.tween_property(_mesh, "position:y", -3.5, 0.6)
	tw.tween_callback(_mesh.hide)
	opened_door.emit()
