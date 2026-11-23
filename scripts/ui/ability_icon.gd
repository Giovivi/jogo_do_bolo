class_name AbilityIcon
extends Control
## Ícone de habilidade: quadrado com recarga radial, ou redondo (especial)
## com anel que enche. A tecla aparece numa etiqueta clara embaixo.

var key_text: String = ""
var name_text: String = ""
var round_shape: bool = false
var cooldown: float = 0.0   # 0..1 do tempo que falta
var fill: float = 1.0       # só no redondo: carga do especial
var ready_glow: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var c := size * 0.5
	var b := maxf(3.0, size.x * 0.05)
	if round_shape:
		var r := size.x * 0.5
		if ready_glow:
			draw_circle(c, r + 6.0 + 3.0 * sin(_t * 6.0), Color(UIStyle.LAMP, 0.45))
		draw_circle(c + Vector2(b, b), r, UIStyle.INK)
		draw_circle(c, r, UIStyle.INK)
		draw_circle(c, r - b, UIStyle.EMPTY)
		if fill > 0.0:
			var pts := PackedVector2Array([c])
			var steps := 48
			for i in steps + 1:
				var a := -PI * 0.5 + TAU * fill * i / steps
				pts.append(c + Vector2(cos(a), sin(a)) * (r - b))
			if pts.size() >= 3:
				draw_colored_polygon(pts, UIStyle.LAMP)
		draw_circle(c, r * 0.68, UIStyle.INK)
		draw_circle(c, r * 0.68 - b * 0.8, UIStyle.NIGHT2)
	else:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(Vector2(b, b), size), UIStyle.INK)
		draw_rect(rect, UIStyle.INK)
		draw_rect(rect.grow(-b), UIStyle.NIGHT2)
		if cooldown > 0.0:
			var pts := PackedVector2Array([c])
			var steps := 40
			for i in steps + 1:
				var a := -PI * 0.5 + TAU * cooldown * i / steps
				var d := Vector2(cos(a), sin(a))
				# Projeta no quadrado para cobrir os cantos.
				var s := (size.x * 0.5 - b) / maxf(absf(d.x), absf(d.y))
				pts.append(c + d * s)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
	# Nome no meio (quebra em duas linhas se precisar).
	var words := name_text.to_upper().split(" ", false)
	var lines: Array[String] = []
	if round_shape and words.size() > 0:
		lines.append(words[0])  # no especial redondo cabe só a primeira palavra
	elif words.size() > 1:
		var half := ceili(words.size() / 2.0)
		lines.append(" ".join(words.slice(0, half)))
		lines.append(" ".join(words.slice(half)))
	else:
		lines.append(name_text.to_upper())
	var fs := int(size.x * (0.16 if round_shape else 0.19))
	var max_w := size.x * (0.6 if round_shape else 0.84)
	for l in lines:
		while fs > 8 and font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			fs -= 1
	var col := UIStyle.LAMP if round_shape else UIStyle.PAPER
	if cooldown > 0.0 or (round_shape and fill < 1.0):
		col = Color(col, 0.6)
	var total_h := fs * lines.size()
	for i in lines.size():
		var ts := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(c.x - ts.x * 0.5, c.y - total_h * 0.5 + fs * (i + 0.85))
		draw_string_outline(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, UIStyle.INK)
		draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# Tecla.
	if key_text != "":
		var kfs := int(clampf(size.x * 0.17, 12, 20))
		var kt := key_text.to_upper()
		var ks := font.get_string_size(kt, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs)
		var kr := Rect2(Vector2(c.x - ks.x * 0.5 - 6, size.y - kfs * 0.55), Vector2(ks.x + 12, kfs + 6))
		draw_rect(kr.grow(2.5), UIStyle.INK)
		draw_rect(kr, UIStyle.PAPER)
		draw_string(font, Vector2(kr.position.x + 6, kr.position.y + kfs), kt, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, UIStyle.INK)
