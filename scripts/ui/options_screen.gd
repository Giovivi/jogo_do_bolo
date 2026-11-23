class_name OptionsScreen
extends Control
## Tela de Opções (abre pelo menu inicial e pela pausa). Vale na hora e fica
## até fechar o jogo.
## - Câmera segue a mira: 0 a 3 m, passos de 0,5 m (Game.rules.camera_aim_follow)
## - Tremor da câmera: liga/desliga (Game.rules.screen_shake)
## - Tipo de câmera: de cima ou atrás do herói (Game.rules.camera_behind);
##   trocar recarrega a cena, porque o corte das paredes muda.
## - Retícula: liga/desliga (Game.rules.behind_reticle)

signal closed

const AIM_PROPERTY := "camera_aim_follow"
const SHAKE_PROPERTY := "screen_shake"
const BEHIND_PROPERTY := "camera_behind"
const RETICLE_PROPERTY := "behind_reticle"

## Guardados aqui também, para a tela abrir com o último valor escolhido
## mesmo antes de a câmera dinâmica existir na versão em uso.
static var aim_follow: float = 1.5
static var shake_on: bool = true
static var behind_on: bool = true
static var reticle_on: bool = false

var _value_label: Label
var _slider: HSlider
var _on_btn: Button
var _off_btn: Button
var _back: Button
var _top_btn: Button
var _behind_btn: Button
var _behind_at_open: bool = true
var _ret_on_btn: Button
var _ret_off_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_read_current()

	var dim := ColorRect.new()
	dim.color = Color(0.016, 0.03, 0.06, 0.95)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	UIStyle.halftone(self, 0.22)

	var t := UIStyle.title("Opções", 110)
	t.position = Vector2(90, 60)
	add_child(t)

	var panel := PanelContainer.new()
	var sb := UIStyle.panel_box(UIStyle.NIGHT, 5, 9)
	sb.set_content_margin_all(34)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(90, 200)
	panel.custom_minimum_size = Vector2(920, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	panel.add_child(col)
	col.add_child(UIStyle.title("Câmera", 30, UIStyle.LAMP))

	# Câmera segue a mira.
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 30)
	col.add_child(row1)
	row1.add_child(_item_label("Câmera segue a mira", "quanto a câmera anda na direção do cursor"))
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 3.0
	_slider.step = 0.5
	_slider.value = aim_follow
	_slider.custom_minimum_size = Vector2(340, 40)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(_slider)
	_slider.value_changed.connect(_on_aim_changed)
	row1.add_child(_slider)
	_value_label = UIStyle.label("", 32, UIStyle.PAPER, 6)
	_value_label.custom_minimum_size = Vector2(100, 0)
	_value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(_value_label)

	# Tremor da câmera.
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 30)
	col.add_child(row2)
	row2.add_child(_item_label("Tremor da câmera", "nos golpes fortes"))
	var tog := HBoxContainer.new()
	tog.add_theme_constant_override("separation", 0)
	tog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(tog)
	_on_btn = _toggle_button("Ligado")
	_on_btn.pressed.connect(func() -> void: _set_shake(true))
	tog.add_child(_on_btn)
	_off_btn = _toggle_button("Desligado")
	_off_btn.pressed.connect(func() -> void: _set_shake(false))
	tog.add_child(_off_btn)

	# Tipo de câmera (teste).
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 30)
	col.add_child(row3)
	row3.add_child(_item_label("Tipo de câmera", "trocar recomeça a sala atual"))
	var tog3 := HBoxContainer.new()
	tog3.add_theme_constant_override("separation", 0)
	tog3.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row3.add_child(tog3)
	_top_btn = _toggle_button("De cima")
	_top_btn.pressed.connect(func() -> void: _set_behind(false))
	tog3.add_child(_top_btn)
	_behind_btn = _toggle_button("Atrás")
	_behind_btn.pressed.connect(func() -> void: _set_behind(true))
	tog3.add_child(_behind_btn)

	# Retícula (só na câmera atrás).
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 30)
	col.add_child(row4)
	row4.add_child(_item_label("Retícula", "câmera atrás: ataque vai para o centro da tela"))
	var tog4 := HBoxContainer.new()
	tog4.add_theme_constant_override("separation", 0)
	tog4.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row4.add_child(tog4)
	_ret_on_btn = _toggle_button("Ligada")
	_ret_on_btn.pressed.connect(func() -> void: _set_reticle(true))
	tog4.add_child(_ret_on_btn)
	_ret_off_btn = _toggle_button("Desligada")
	_ret_off_btn.pressed.connect(func() -> void: _set_reticle(false))
	tog4.add_child(_ret_off_btn)

	_back = UIStyle.menu_button("Voltar", 38)
	_back.position = Vector2(90, 790)
	_back.pressed.connect(_close)
	add_child(_back)

	_on_aim_changed(aim_follow)
	_set_shake(shake_on)
	_behind_at_open = behind_on
	_set_behind(behind_on)
	_set_reticle(reticle_on)
	_slider.call_deferred("grab_focus")


func _read_current() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	if AIM_PROPERTY in game.rules:
		aim_follow = float(game.rules.get(AIM_PROPERTY))
	if SHAKE_PROPERTY in game.rules:
		shake_on = bool(game.rules.get(SHAKE_PROPERTY))
	if BEHIND_PROPERTY in game.rules:
		behind_on = bool(game.rules.get(BEHIND_PROPERTY))
	if RETICLE_PROPERTY in game.rules:
		reticle_on = bool(game.rules.get(RETICLE_PROPERTY))


## Aplica os valores guardados (chamado ao montar a cena, caso o jogo recarregue).
static func apply_saved() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var game := tree.root.get_node_or_null("Game") if tree != null else null
	if game == null:
		return
	if AIM_PROPERTY in game.rules:
		game.rules.set(AIM_PROPERTY, aim_follow)
	if SHAKE_PROPERTY in game.rules:
		game.rules.set(SHAKE_PROPERTY, shake_on)
	if BEHIND_PROPERTY in game.rules:
		game.rules.set(BEHIND_PROPERTY, behind_on)
	if RETICLE_PROPERTY in game.rules:
		game.rules.set(RETICLE_PROPERTY, reticle_on)


func _item_label(title_text: String, hint: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 0)
	box.add_child(UIStyle.label(title_text, 32, UIStyle.PAPER, 6))
	box.add_child(UIStyle.label(hint, 19, Color(0.6, 0.65, 0.72), 0))
	return box


func _toggle_button(text: String) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 26)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, UIStyle.PAPER)
	b.add_theme_color_override("font_pressed_color", UIStyle.INK)
	b.add_theme_color_override("font_hover_pressed_color", UIStyle.INK)
	var off := UIStyle.panel_box(UIStyle.NIGHT2, 4, 0)
	off.set_content_margin_all(6)
	off.content_margin_left = 20
	off.content_margin_right = 20
	off.skew = Vector2(0.15, 0)
	var on := off.duplicate() as StyleBoxFlat
	on.bg_color = UIStyle.LAMP
	var hover := off.duplicate() as StyleBoxFlat
	hover.border_color = UIStyle.LAMP
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b


func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = UIStyle.EMPTY
	track.border_color = UIStyle.INK
	track.set_border_width_all(4)
	track.content_margin_top = 11
	track.content_margin_bottom = 11
	track.skew = Vector2(0.3, 0)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = UIStyle.LAMP
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(22, 38, false, Image.FORMAT_RGBA8)
	img.fill(UIStyle.INK)
	img.fill_rect(Rect2i(4, 4, 14, 30), UIStyle.PAPER)
	var knob := ImageTexture.create_from_image(img)
	var img2 := img.duplicate() as Image
	img2.fill_rect(Rect2i(4, 4, 14, 30), UIStyle.LAMP2)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", ImageTexture.create_from_image(img2))


func _on_aim_changed(v: float) -> void:
	aim_follow = v
	_value_label.text = ("%.1f m" % v).replace(".", ",")
	apply_saved()


func _set_shake(on: bool) -> void:
	shake_on = on
	_on_btn.set_pressed_no_signal(on)
	_off_btn.set_pressed_no_signal(not on)
	apply_saved()


func _set_behind(on: bool) -> void:
	behind_on = on
	_top_btn.set_pressed_no_signal(not on)
	_behind_btn.set_pressed_no_signal(on)
	apply_saved()


func _set_reticle(on: bool) -> void:
	reticle_on = on
	_ret_on_btn.set_pressed_no_signal(on)
	_ret_off_btn.set_pressed_no_signal(not on)
	apply_saved()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
	if behind_on != _behind_at_open:
		# Câmera e paredes montam de outro jeito: recomeça a cena.
		var tree := get_tree()
		tree.paused = false
		tree.reload_current_scene.call_deferred()
