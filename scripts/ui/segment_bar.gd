class_name SegmentBar
extends Control
## Barra de vida em gomos inclinados, no estilo HQ.
## Golpe: treme e deixa um rastro branco que encolhe devagar.
## Cura: os gomos novos acendem em azul. Pouca vida: pulsa vermelho.

const LOW_FRACTION := 0.3

var segments: int = 10
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


func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(sin(_t * 90.0) * 5.0 * shake, cos(_t * 70.0) * 2.0 * shake)
	var gap := maxf(2.0, size.x * 0.008)
	var k := size.y * skew
	var w := (size.x - k - gap * (segments - 1)) / segments
	var low := value > 0.0 and value <= LOW_FRACTION
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	var border := maxf(2.0, size.y * 0.1)
	for i in segments:
		var x0 := off.x + i * (w + gap)
		var r := Rect2(Vector2(x0, off.y), Vector2(w, size.y))
		var pts := PackedVector2Array([
			r.position + Vector2(k, 0), r.position + Vector2(k + w, 0),
			r.position + Vector2(w, size.y), r.position + Vector2(0, size.y)])
		# Sombra e borda.
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(border, border))
		draw_colored_polygon(sh, UIStyle.INK)
		draw_colored_polygon(pts, UIStyle.INK)
		var inner := PackedVector2Array([
			pts[0] + Vector2(border * 0.7, border), pts[1] + Vector2(-border, border),
			pts[2] + Vector2(-border * 0.7, -border), pts[3] + Vector2(border, -border)])
		var lo := float(i) / segments
		var hi := float(i + 1) / segments
		var col := UIStyle.EMPTY
		var mid := (lo + hi) * 0.5
		if value >= hi - 0.0001 or (value > lo and value >= mid):
			col = UIStyle.LIFE
			if low:
				col = UIStyle.RED.lerp(Color(1, 0.55, 0.5), pulse * 0.5)
			elif heal_glow > 0.0 and mid > heal_from:
				col = UIStyle.LIFE.lerp(UIStyle.BLUE, heal_glow)
		elif trail > lo and trail >= mid:
			col = Color(1, 1, 1)
		if dim:
			col = col.darkened(0.45)
		draw_colored_polygon(inner, col)
		# Parte do gomo parcialmente cheio (para frações pequenas).
		if col == UIStyle.EMPTY and value > lo and value < mid:
			var f := (value - lo) / (hi - lo)
			var part := PackedVector2Array([inner[0], inner[0].lerp(inner[1], f), inner[3].lerp(inner[2], f), inner[3]])
			draw_colored_polygon(part, UIStyle.RED if low else UIStyle.LIFE)
