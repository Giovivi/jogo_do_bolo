class_name InteractBalloon
extends Control
## Balão de HQ que flutua em cima do objeto que dá para usar.
## "press": [F] ABRIR · "locked": só o cadeado (o herói atual não consegue)
## "hold": F dentro de um anel que enche + texto (ex.: REVIVER).
## A posição do controle é a ponta do rabinho do balão.

const H := 34.0
const FONT_SIZE := 19

var mode: String = "press"
var verb: String = ""
var progress: float = 0.0   # 0..1, só no "hold"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var txt := verb.to_upper()
	var tw := 0.0 if mode == "locked" or txt == "" else font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var icon_w := 26.0
	var pad := 5.0
	var w := pad + icon_w + (8.0 + tw + 6.0 if tw > 0.0 else pad)
	var tail := 11.0
	var box := Rect2(Vector2(-w * 0.5, -H - tail), Vector2(w, H))
	var paper := UIStyle.PAPER if mode != "locked" else Color(0.6, 0.59, 0.55)
	# Sombra, borda e papel.
	draw_rect(Rect2(box.position + Vector2(4, 4), box.size), UIStyle.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, box.end.y - 1), Vector2(8, box.end.y - 1), Vector2(0, 0)]), UIStyle.INK)
	draw_rect(box, UIStyle.INK)
	draw_rect(box.grow(-3), paper)
	# Ícone.
	var ic := Rect2(Vector2(box.position.x + pad, box.position.y + (H - icon_w) * 0.5), Vector2(icon_w, icon_w))
	var c := ic.get_center()
	match mode:
		"press":
			draw_rect(ic, UIStyle.INK)
			_center_text(font, "F", c, 18, UIStyle.PAPER)
		"locked":
			_draw_lock(c)
		"hold":
			draw_circle(c, icon_w * 0.5, Color(0.23, 0.26, 0.32))
			if progress > 0.0:
				var pts := PackedVector2Array([c])
				for i in 33:
					var a := -PI * 0.5 + TAU * progress * i / 32.0
					pts.append(c + Vector2(cos(a), sin(a)) * icon_w * 0.5)
				draw_colored_polygon(pts, UIStyle.LAMP)
			draw_circle(c, icon_w * 0.34, UIStyle.INK)
			_center_text(font, "F", c, 14, UIStyle.PAPER)
	if tw > 0.0:
		var pos := Vector2(ic.end.x + 8.0, box.position.y + H * 0.5 + FONT_SIZE * 0.36)
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIStyle.INK)


func _center_text(font: Font, t: String, c: Vector2, fs: int, col: Color) -> void:
	var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_lock(c: Vector2) -> void:
	var body := Rect2(c + Vector2(-9, -2), Vector2(18, 13))
	draw_arc(c + Vector2(0, -3), 6.0, PI, TAU, 16, UIStyle.INK, 3.5)
	draw_line(c + Vector2(-6, -3), c + Vector2(-6, -1), UIStyle.INK, 3.5)
	draw_line(c + Vector2(6, -3), c + Vector2(6, -1), UIStyle.INK, 3.5)
	draw_rect(body, UIStyle.INK)
	draw_rect(body.grow(-2), Color(0.95, 0.75, 0.3))
	draw_circle(body.get_center() + Vector2(0, -1), 2.0, UIStyle.INK)
