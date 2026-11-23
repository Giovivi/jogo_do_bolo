class_name FenixModel
extends Node3D
## Modelo 3D do Fênix (forma humana): casaco de penas azul com fogo nas
## costas, cabelo curto penteado de lado. Feito no Blender (art/modelos).
## Pose em A, ainda sem esqueleto: a animação vem depois, pelo Mixamo.

const MODEL := preload("res://art/modelos/fenix_humano.glb")

## Altura do modelo exportado (m) e altura que ele deve ter no jogo.
const MODEL_HEIGHT := 1.8
@export var height: float = 1.8


func _ready() -> void:
	var m := MODEL.instantiate() as Node3D
	# O glb olha para +Z; os atores do jogo olham para -Z.
	m.rotation_degrees.y = 180.0
	m.scale = Vector3.ONE * (height / MODEL_HEIGHT)
	add_child(m)
	_fix_materials(m)


## Penas e casaco usam a cor por vértice; o fogo fica sem sombra para brilhar.
func _fix_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var mat_name := src.resource_name
			if mat_name == "fogo":
				var fire := StandardMaterial3D.new()
				fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				fire.vertex_color_use_as_albedo = true
				fire.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(i, fire)
			elif mat_name == "penas" and src is StandardMaterial3D:
				var feathers := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				feathers.vertex_color_use_as_albedo = true
				feathers.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(i, feathers)
	for child in node.get_children():
		_fix_materials(child)
