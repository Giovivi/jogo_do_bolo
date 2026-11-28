class_name UIStyle
extends RefCounted
## Cores e peças comuns da interface no estilo HQ (clima Lanterna):
## painéis com borda preta grossa e sombra dura, títulos com contorno.

const INK := Color(0.043, 0.059, 0.09)
const NIGHT := Color(0.06, 0.106, 0.172)
const NIGHT2 := Color(0.086, 0.149, 0.239)
const LAMP := Color(0.949, 0.698, 0.361)
const LAMP2 := Color(1.0, 0.847, 0.604)
const PAPER := Color(0.937, 0.902, 0.824)
const RED := Color(0.878, 0.255, 0.227)
const BLUE := Color(0.31, 0.765, 1.0)
const LIFE := Color(0.914, 0.89, 0.816)
const EMPTY := Color(0.16, 0.19, 0.247)
const MUTE := Color(0.49, 0.54, 0.63)

const PORTRAITS := {
	"Fênix": "res://art/retratos/fenix.png",
	"Mistral": "res://art/retratos/mistral.png",
}


static func portrait_for(hero_name: String) -> Texture2D:
	var path: String = PORTRAITS.get(hero_name, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func panel_box(fill: Color = NIGHT, border: int = 5, shadow: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(border)
	sb.shadow_color = INK
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(shadow, shadow)
	if shadow > 0:
		sb.shadow_size = 1
	sb.set_content_margin_all(18)
	return sb


static func label(text: String, size: int, color: Color = PAPER, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", maxi(2, size / 12))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 12))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size: int, color: Color = PAPER) -> Label:
	var l := label(text, size, color, maxi(8, size / 7))
	l.uppercase = true
	return l


## Botão de menu: texto grande; em foco vira etiqueta cor de lâmpada com borda preta.
static func menu_button(text: String, size: int = 34) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(PAPER, 0.35))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	var on := panel_box(LAMP, 4, 6)
	on.set_content_margin_all(10)
	on.content_margin_left = 24
	on.content_margin_right = 24
	on.skew = Vector2(0.15, 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_stylebox_override("focus", on)
	b.add_theme_stylebox_override("pressed", on)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


## Fundo de pontinhos de retícula (meio-tom) desenhado por código.
static func halftone(parent: Control, alpha: float = 0.3) -> Control:
	var h := Halftone.new()
	h.alpha = alpha
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	return h


class Halftone extends Control:
	var alpha: float = 0.3
	func _draw() -> void:
		var step := 9.0
		var c := Color(0, 0, 0, alpha)
		var y := 0.0
		var row := 0
		while y < size.y:
			var x := step * 0.5 if row % 2 == 1 else 0.0
			while x < size.x:
				draw_circle(Vector2(x, y), 1.6, c)
				x += step
			y += step
			row += 1
