class_name HubSpot
extends Interactable
## Ponto do hub que mostra um texto curto ao usar F (mapa, bancada, quarto).

signal used

@export_multiline var text: String = ""


func _ready() -> void:
	super._ready()
	interact_range = 2.2
	# Marcador discreto no chão.
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.35
	m.bottom_radius = 0.35
	m.height = 0.04
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.42, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position.y = 0.03
	add_child(mi)


func interact(_hero: Hero) -> void:
	used.emit()
	if text != "":
		Game.message(text, 6.0)
