class_name CameraZone
extends Node3D
## Zona de câmera de uma sala (seção 3.7). Colocada à mão: o retângulo
## (no chão, centrado no nó) escolhe o nível de zoom enquanto o herói
## controlado está dentro. Ajustar um nível em data/regras.tres muda
## todas as salas daquele nível.

enum Level { OPEN, MEDIUM, CLOSED }

## Tamanho da zona no chão (x, z), em metros.
@export var size: Vector2 = Vector2(10, 10)
@export var level: Level = Level.OPEN
@export var room_name: String = ""


func _ready() -> void:
	add_to_group("camera_zones")


func rect() -> Rect2:
	return Rect2(global_position.x - size.x * 0.5, global_position.z - size.y * 0.5, size.x, size.y)


## Fração da distância da câmera para este nível (aberto 100%, médio ~80%,
## fechado ~65%).
func zoom() -> float:
	return zoom_for(level)


static func zoom_for(lv: int) -> float:
	match lv:
		Level.MEDIUM:
			return Game.rules.camera_zoom_medium
		Level.CLOSED:
			return Game.rules.camera_zoom_closed
	return 1.0


static func make(parent: Node3D, x0: float, z0: float, x1: float, z1: float, lv: Level, title: String) -> CameraZone:
	var z := CameraZone.new()
	z.name = "Zona_" + title.replace(" ", "_")
	z.size = Vector2(x1 - x0, z1 - z0)
	z.level = lv
	z.room_name = title
	parent.add_child(z)
	z.position = Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	return z
