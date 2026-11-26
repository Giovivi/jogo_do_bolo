class_name Chest
extends Interactable
## Baú. Loot fica para depois: aqui ele só conta para a tela de resultado.
## A frente (fechadura) fica virada para +Z, o lado da câmera, e a tampa
## gira na dobradiça de trás: abre mostrando o interior para o jogador.
## Madeira e ferragens são fotos do ambientCG (CC0, ver assets/textures/CREDITS.md).

@export var rare: bool = false
@export var final_chest: bool = false
## Foto da madeira (ambientCG).
var wood_id := "Planks037A"

const SIZE := Vector3(1.2, 0.6, 0.8)
const LID_H := 0.22
## Ângulo da tampa aberta (gira para trás, em volta da dobradiça).
const OPEN_DEG := -105.0

var opened: bool = false
var _hinge: Node3D
var _glow: OmniLight3D
var _inner: MeshInstance3D


func _ready() -> void:
	super._ready()
	prompt = "Abrir baú"
	var wood_tint := Color(1.0, 0.92, 0.82)
	var trim_tint := Color(0.55, 0.57, 0.62)  # ferro
	var glow := Color(1.0, 0.8, 0.35)
	if rare:
		trim_tint = Color(1.0, 0.78, 0.3)  # dourado
	if final_chest:
		wood_tint = Color(0.8, 0.88, 0.9)
		trim_tint = Color(0.35, 0.95, 0.75)  # verde da missão
		glow = Color(0.4, 1.0, 0.75)
	var wood := _mat(wood_id, 0.9, wood_tint)
	var trim := _mat("MetalPlates014", 0.6, trim_tint)
	var w := SIZE.x
	var d := SIZE.z
	var h := SIZE.y

	# Corpo.
	_piece(self, Vector3(w, h, d), wood, Vector3(0, h * 0.5, 0))
	# Interior escuro (aparece com a tampa aberta).
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.06, 0.04, 0.03)
	_inner = _piece(self, Vector3(w - 0.12, 0.02, d - 0.12), dark, Vector3(0, h + 0.005, 0))
	# Ferragens do corpo: cinta de baixo, duas cintas verticais e fechadura na frente.
	_piece(self, Vector3(w + 0.04, 0.08, d + 0.04), trim, Vector3(0, 0.04, 0))
	for x in [-w * 0.33, w * 0.33]:
		_piece(self, Vector3(0.1, h + 0.01, d + 0.05), trim, Vector3(x, h * 0.5, 0))
	_piece(self, Vector3(0.22, 0.26, 0.04), trim, Vector3(0, h - 0.1, d * 0.5 + 0.02))
	var hole := StandardMaterial3D.new()
	hole.albedo_color = Color(0.05, 0.04, 0.03)
	_piece(self, Vector3(0.05, 0.09, 0.02), hole, Vector3(0, h - 0.13, d * 0.5 + 0.045))

	# Tampa: dobradiça na borda de trás, em cima do corpo.
	_hinge = Node3D.new()
	_hinge.position = Vector3(0, h, -d * 0.5)
	add_child(_hinge)
	var lid_d := d + 0.04
	_piece(_hinge, Vector3(w + 0.04, LID_H, lid_d), wood, Vector3(0, LID_H * 0.5, lid_d * 0.5 - 0.02))
	for x in [-w * 0.33, w * 0.33]:
		_piece(_hinge, Vector3(0.1, LID_H + 0.02, lid_d + 0.02), trim, Vector3(x, LID_H * 0.5, lid_d * 0.5 - 0.02))
	# Lingueta da fechadura presa na frente da tampa.
	_piece(_hinge, Vector3(0.14, 0.14, 0.04), trim, Vector3(0, 0.02, lid_d - 0.0))

	# Brilho que acende dentro ao abrir.
	_glow = OmniLight3D.new()
	_glow.light_color = glow
	_glow.light_energy = 0.0
	_glow.omni_range = 2.2
	_glow.position = Vector3(0, h + 0.25, 0.1)
	add_child(_glow)

	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h + LID_H, d)
	shape.shape = box
	shape.position.y = (h + LID_H) * 0.5
	body.add_child(shape)
	add_child(body)


func can_interact(_hero: Hero) -> bool:
	return not opened


func interact(_hero: Hero) -> void:
	if opened:
		return
	opened = true
	Game.chests_opened += 1
	open_lid(true)
	var kind := "raro" if rare else ("final" if final_chest else "comum")
	Game.message("Baú %s aberto (%d/%d)" % [kind, Game.chests_opened, Game.chests_total], 2.0)
	Game.flash_ring(global_position, 1.2, Color(1, 0.9, 0.4, 0.6), 0.4)


## Abre a tampa para trás (animada ou direto, usado também nas pranchas).
func open_lid(animate: bool) -> void:
	var target := deg_to_rad(OPEN_DEG)
	if not animate:
		_hinge.rotation.x = target
		_glow.light_energy = 1.6
		return
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation:x", deg_to_rad(10.0), 0.08)  # tranco
	tw.tween_property(_hinge, "rotation:x", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_glow, "light_energy", 1.6, 0.3)


## Foto do ambientCG presa ao objeto (triplanar local): não "escorrega"
## quando a tampa gira.
static func _mat(id: String, size: float, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	Look.texture_std(m, id, size, tint)
	m.uv1_world_triplanar = false
	return m


static func _piece(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
