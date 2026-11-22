class_name Chest
extends Interactable
## Baú. Loot fica para depois: aqui ele só conta para a tela de resultado.

@export var rare: bool = false
@export var final_chest: bool = false

var opened: bool = false
var _lid: MeshInstance3D


func _ready() -> void:
	super._ready()
	prompt = "Abrir baú"
	var color := Color(0.95, 0.75, 0.15) if rare else Color(0.55, 0.35, 0.15)
	if final_chest:
		color = Color(0.3, 0.85, 0.6)
	make_box(self, Vector3(1.2, 0.6, 0.8), color, Vector3(0, 0.3, 0))
	_lid = make_box(self, Vector3(1.25, 0.2, 0.85), color.lightened(0.25), Vector3(0, 0.7, 0))
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.8, 0.8)
	shape.shape = box
	shape.position.y = 0.4
	body.add_child(shape)
	add_child(body)


func can_interact(_hero: Hero) -> bool:
	return not opened


func interact(_hero: Hero) -> void:
	if opened:
		return
	opened = true
	Game.chests_opened += 1
	var tw := create_tween()
	tw.tween_property(_lid, "position", Vector3(0, 0.95, 0.35), 0.25)
	tw.parallel().tween_property(_lid, "rotation:x", deg_to_rad(70.0), 0.25)
	var kind := "raro" if rare else ("final" if final_chest else "comum")
	Game.message("Baú %s aberto (%d/%d)" % [kind, Game.chests_opened, Game.chests_total], 2.0)
	Game.flash_ring(global_position, 1.2, Color(1, 0.9, 0.4, 0.6), 0.4)
