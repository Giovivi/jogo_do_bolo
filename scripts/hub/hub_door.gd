class_name HubDoor
extends HubSpot
## Porta do hub: leva o grupo de uma área para outra (frente <-> saguão).

signal used_door(target: Vector3)

var target: Vector3 = Vector3.ZERO


func interact(hero: Hero) -> void:
	super.interact(hero)
	used_door.emit(target)
