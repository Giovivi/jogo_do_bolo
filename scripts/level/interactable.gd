class_name Interactable
extends Node3D
## Algo que o jogador usa com F (baú, console).

@export var interact_range: float = 1.8
@export var prompt: String = "Usar"

var enabled: bool = true


func _ready() -> void:
	add_to_group("interactables")


func can_interact(_hero: Hero) -> bool:
	return enabled


func interact(_hero: Hero) -> void:
	pass


static func make_box(parent: Node3D, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
