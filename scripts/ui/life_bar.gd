class_name LifeBar
extends Control
## Barra de vida contínua e inclinada, no estilo HQ (borda preta e sombra dura).
## Golpe: treme e deixa um rastro branco que encolhe devagar.
## Cura: a parte nova acende em azul. Pouca vida: pulsa vermelho.

const LOW_FRACTION := 0.3

var value: float = 1.0       # 0..1
var trail: float = 1.0       # rastro branco (fica acima de value e desce)
var heal_from: float = 1.0   # abaixo de value: parte que acabou de curar
var heal_glow: float = 0.0
var shake: float = 0.0
var dim: bool = false
var skew: float = 0.35
var _t: float = 0.0
var _trail_wait: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Chamado todo quadro com a fração de vida atual.
func set_value(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if v < value - 0.0001:
		trail = maxf(trail, value)
		_trail_wait = 0.35
		shake = 1.0
	elif v > value + 0.0001:
		heal_from = minf(value, heal_from) if heal_glow > 0.0 else value
		heal_glow = 1.0
		trail = v
	value = v


func _process(delta: float) -> void:
	_t += delta
	shake = maxf(0.0, shake - delta * 4.0)
	heal_glow = maxf(0.0, heal_glow - delta * 1.2)
	if _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		trail = move_toward(trail, value, delta * 0.6)
	queue_redraw()


## Paralelogramo da barra entre as frações a e b (0..1) dentro do retângulo r.
func _span(r: Rect2, k: float, a: float, b: float) -> PackedVector2Array:
	var w := r.size.x - k
	var x0 := r.position.x + w * a
	var x1 := r.position.x + w * b
	return PackedVector2Array([
		Vector2(x0 + k, r.position.y), Vector2(x1 + k, r.position.y),
		Vector2(x1, r.end.y), Vector2(x0, r.end.y)])


func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(sin(_t * 90.0) * 5.0 * shake, cos(_t * 70.0) * 2.0 * shake)
	var border := maxf(2.0, size.y * 0.13)
	var k := size.y * skew
	var outer := Rect2(off, size)
	draw_colored_polygon(_span(Rect2(off + Vector2(border, border), size), k, 0.0, 1.0), UIStyle.INK)
	draw_colored_polygon(_span(outer, k, 0.0, 1.0), UIStyle.INK)
	var inner := outer.grow(-border)
	var ik := inner.size.y * skew
	draw_colored_polygon(_span(inner, ik, 0.0, 1.0), UIStyle.EMPTY.darkened(0.2) if dim else UIStyle.EMPTY)

	var low := value > 0.0 and value <= LOW_FRACTION
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	if trail > value + 0.002:
		draw_colored_polygon(_span(inner, ik, value, trail), Color(1, 1, 1))
	if value > 0.002:
		var col := UIStyle.LIFE
		if low:
			col = UIStyle.RED.lerp(Color(1, 0.55, 0.5), pulse * 0.5)
		if dim:
			col = col.darkened(0.45)
		draw_colored_polygon(_span(inner, ik, 0.0, value), col)
		if heal_glow > 0.0 and not low and heal_from < value:
			draw_colored_polygon(_span(inner, ik, heal_from, value), UIStyle.LIFE.lerp(UIStyle.BLUE, heal_glow))
		# Brilho de cima, para dar volume.
		var top := Rect2(inner.position + Vector2(ik * 0.7, 0), Vector2(inner.size.x - ik * 0.7, inner.size.y * 0.3))
		draw_colored_polygon(_span(top, ik * 0.3, 0.0, value), Color(1, 1, 1, 0.22))
