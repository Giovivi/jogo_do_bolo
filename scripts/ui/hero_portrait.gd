class_name HeroPortrait
extends Control
## Retrato de HQ inclinado. Sem imagem, mostra o nome sobre a cor do herói.
## Reage: pisca branco no golpe, brilha azul na cura, fica vermelho com pouca
## vida e cinza com anel de reanimação quando cai.

var texture: Texture2D
var hero_name: String = ""
var base_color: Color = UIStyle.NIGHT2
var border_color: Color = UIStyle.INK
var locked: bool = false
var skew: float = 0.1

var flash: float = 0.0      # 0..1, branco do golpe
var heal_glow: float = 0.0  # 0..1, azul da cura
var low: bool = false
var downed: bool = false
var revive: float = 0.0     # 0..1, anel de reanimação
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hero(h_name: String, color: Color) -> void:
	hero_name = h_name
	base_color = color
	texture = UIStyle.portrait_for(h_name)
	locked = false
	queue_redraw()


func set_locked() -> void:
	hero_name = ""
	texture = null
	locked = true
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	flash = maxf(0.0, flash - delta * 4.0)
	heal_glow = maxf(0.0, heal_glow - delta * 1.5)
	queue_redraw()


func _quad(r: Rect2) -> PackedVector2Array:
	var k := r.size.y * skew
	return PackedVector2Array([
		r.position + Vector2(k, 0), r.position + Vector2(r.size.x, 0),
		r.position + Vector2(r.size.x - k, r.size.y), r.position + Vector2(0, r.size.y)])


func _draw() -> void:
	var b := maxf(3.0, size.x * 0.035)
	var full := Rect2(Vector2.ZERO, size)
	# Brilho atrás (cura ou pouca vida).
	if heal_glow > 0.0:
		draw_colored_polygon(_quad(full.grow(8.0 * heal_glow)), Color(UIStyle.BLUE, 0.6 * heal_glow))
	if low and not downed:
		var p := 0.5 + 0.5 * sin(_t * 8.0)
		draw_colored_polygon(_quad(full.grow(4.0 + 4.0 * p)), Color(UIStyle.RED, 0.35 + 0.35 * p))
	# Sombra dura e borda.
	draw_colored_polygon(_quad(Rect2(Vector2(b * 1.6, b * 1.6), size)), UIStyle.INK)
	var bc := border_color
	if low and not downed:
		bc = UIStyle.RED
	draw_colored_polygon(_quad(full), bc)
	var inner := full.grow(-b)
	var pts := _quad(inner)
	if locked:
		draw_colored_polygon(pts, Color(0.07, 0.1, 0.16))
		for i in range(-6, 12):
			var x := inner.position.x + i * size.x * 0.12
			draw_line(Vector2(x, inner.end.y), Vector2(x + inner.size.y, inner.position.y), Color(1, 1, 1, 0.04), size.x * 0.04)
	elif texture != null:
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append(Vector2((p.x - inner.position.x) / inner.size.x, (p.y - inner.position.y) / inner.size.y))
		var tint := Color(0.42, 0.42, 0.46) if downed else Color.WHITE
		draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uvs, texture)
	else:
		var c := base_color.darkened(0.55)
		if downed:
			c = Color(0.18, 0.19, 0.22)
		draw_colored_polygon(pts, c)
		var font := ThemeDB.fallback_font
		var fs := int(inner.size.y * 0.24)
		var txt := hero_name.to_upper()
		while fs > 8 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > inner.size.x * 0.8:
			fs -= 1
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := inner.get_center() + Vector2(-ts.x * 0.5, fs * 0.35)
		var glow := Color(0.5, 0.5, 0.55) if downed else base_color.lightened(0.45)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 5), UIStyle.INK)
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glow)
	if downed:
		draw_colored_polygon(pts, Color(0, 0, 0, 0.35))
	if flash > 0.0:
		draw_colored_polygon(pts, Color(1, 1, 1, 0.75 * flash))
	# Anel de reanimação.
	if downed:
		var c := size * 0.5
		var r := size.x * 0.62
		draw_arc(c, r, 0, TAU, 48, UIStyle.EMPTY, size.x * 0.09)
		if revive > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * revive, 48, UIStyle.LAMP, size.x * 0.09)
