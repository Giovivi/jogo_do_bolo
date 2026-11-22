class_name CellConsole
extends Interactable
## Console da cela: inicia o destravamento de 60 s.

signal activated

var used: bool = false


func _ready() -> void:
	super._ready()
	prompt = "Destravar a cela"
	make_box(self, Vector3(1.0, 1.1, 0.6), Color(0.3, 0.35, 0.45), Vector3(0, 0.55, 0))
	make_box(self, Vector3(0.8, 0.3, 0.1), Color(0.2, 0.9, 1.0), Vector3(0, 1.0, 0.31))


func can_interact(_hero: Hero) -> bool:
	return not used


func interact(_hero: Hero) -> void:
	if used:
		return
	used = true
	activated.emit()
