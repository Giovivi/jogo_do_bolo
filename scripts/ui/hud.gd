class_name HUD
extends CanvasLayer
## HUD A, retratos de HQ: retrato grande do herói ativo no canto de cima,
## aliados menores embaixo dele com a tecla de troca, poderes no centro de
## baixo (recarga radial e especial redondo) e objetivo no canto direito.
## Também cuida da pausa, da derrota e da tela de resultado.
## Sem números de dano e sem barra em cima dos personagens.

signal restart_requested

const ALLY_ROWS := 3

var party: Party
var level: PostoVigia

var _root: Control
var _vignette: TextureRect
# Herói ativo.
var _main_portrait: HeroPortrait
var _main_name: Label
var _main_bar: SegmentBar
var _main_special: SpecialBar
var _main_tag: Label
# Aliados.
var _ally_rows: Array[Control] = []
var _ally_keys: Array[Label] = []
var _ally_portraits: Array[HeroPortrait] = []
var _ally_bars: Array[SegmentBar] = []
var _ally_tags: Array[Label] = []
# Poderes.
var _ability_box: HBoxContainer
var _icons: Array[AbilityIcon] = []
# Textos.
var _objective: Label
var _objective_sub: Label
var _message: Label
var _prompt: Label
var _message_time: float = 0.0
# Telas por cima.
var _pause_screen: Control
var _pause_resume: Button
var _end_screen: Control
var _state: String = "playing"

## Último valor de vida visto por herói, para saber se foi golpe ou cura.
var _last_health: Dictionary = {}
var _shown_hero: Hero = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10


func setup(p: Party, l: PostoVigia) -> void:
	party = p
	level = l
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_vignette()
	_build_party()
	_build_abilities()
	_build_texts()
	_pause_screen = _build_pause()
	_root.add_child(_pause_screen)


# ---------------------------------------------------------------- montagem

func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.02, 0.02, 0.0))
	g.set_color(1, Color(0.6, 0.02, 0.02, 0.75))
	g.add_point(0.55, Color(0.6, 0.02, 0.02, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)


func _build_party() -> void:
	_main_portrait = HeroPortrait.new()
	_main_portrait.position = Vector2(30, 26)
	_main_portrait.size = Vector2(150, 150)
	_main_portrait.border_color = UIStyle.LAMP
	_root.add_child(_main_portrait)

	_main_name = UIStyle.title("", 36)
	_main_name.position = Vector2(200, 28)
	_root.add_child(_main_name)
	_main_tag = UIStyle.label("", 20, UIStyle.LAMP2, 6)
	_main_tag.position = Vector2(200, 132)
	_root.add_child(_main_tag)

	_main_bar = SegmentBar.new()
	_main_bar.position = Vector2(200, 80)
	_main_bar.size = Vector2(350, 30)
	_root.add_child(_main_bar)

	_main_special = SpecialBar.new()
	_main_special.position = Vector2(200, 118)
	_main_special.size = Vector2(340, 11)
	_root.add_child(_main_special)

	for i in ALLY_ROWS:
		var row := Control.new()
		row.position = Vector2(36, 200 + i * 92)
		row.size = Vector2(320, 80)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(row)
		_ally_rows.append(row)

		var key := _key_chip("")
		key.position = Vector2(0, 24)
		row.add_child(key)
		_ally_keys.append(key)

		var por := HeroPortrait.new()
		por.position = Vector2(44, 0)
		por.size = Vector2(80, 80)
		row.add_child(por)
		_ally_portraits.append(por)

		var bar := SegmentBar.new()
		bar.position = Vector2(140, 34)
		bar.size = Vector2(170, 16)
		bar.skew = 0.4
		row.add_child(bar)
		_ally_bars.append(bar)

		var tag := UIStyle.label("", 18, UIStyle.PAPER, 5)
		tag.position = Vector2(140, 4)
		row.add_child(tag)
		_ally_tags.append(tag)


func _key_chip(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", UIStyle.INK)
	var sb := UIStyle.panel_box(UIStyle.PAPER, 3, 3)
	sb.set_content_margin_all(2)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	l.add_theme_stylebox_override("normal", sb)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_abilities() -> void:
	_ability_box = HBoxContainer.new()
	_ability_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ability_box.add_theme_constant_override("separation", 22)
	_ability_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ability_box.offset_left = -400
	_ability_box.offset_right = 400
	_ability_box.offset_top = -170
	_ability_box.offset_bottom = -34
	_ability_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ability_box)
	for i in 5:
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(96, 136)
		var icon := AbilityIcon.new()
		icon.custom_minimum_size = Vector2(96, 96)
		holder.add_child(icon)
		_ability_box.add_child(holder)
		_icons.append(icon)


func _build_texts() -> void:
	_objective = UIStyle.title("", 28)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_objective.offset_left = -820
	_objective.offset_right = -36
	_objective.offset_top = 28
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_objective)
	_objective_sub = UIStyle.label("", 24, UIStyle.LAMP2, 6)
	_objective_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective_sub.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_objective_sub.offset_left = -820
	_objective_sub.offset_right = -36
	_objective_sub.offset_top = 70
	_root.add_child(_objective_sub)

	_message = UIStyle.label("", 26, UIStyle.PAPER, 8)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.offset_left = -480
	_message.offset_right = 480
	_message.offset_top = 150
	_root.add_child(_message)

	_prompt = UIStyle.label("", 24, UIStyle.LAMP2, 7)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -500
	_prompt.offset_right = 500
	_prompt.offset_top = -210
	_prompt.offset_bottom = -176
	_root.add_child(_prompt)


func _build_pause() -> Control:
	var s := Control.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(dim)
	UIStyle.halftone(s, 0.25)

	var t := UIStyle.title("Pausa", 120)
	t.position = Vector2(90, 70)
	s.add_child(t)

	var menu := VBoxContainer.new()
	menu.position = Vector2(90, 270)
	menu.add_theme_constant_override("separation", 6)
	s.add_child(menu)
	_pause_resume = UIStyle.menu_button("Voltar ao jogo")
	_pause_resume.pressed.connect(_toggle_pause)
	menu.add_child(_pause_resume)
	if Game.mode == "fase":
		var again := UIStyle.menu_button("Reiniciar fase")
		again.pressed.connect(func() -> void: restart_requested.emit())
		menu.add_child(again)
		var back := UIStyle.menu_button("Voltar à escola")
		back.pressed.connect(func() -> void:
			Game.mode = "hub"
			restart_requested.emit())
		menu.add_child(back)
	var quit := UIStyle.menu_button("Sair do jogo")
	quit.pressed.connect(func() -> void: get_tree().quit())
	menu.add_child(quit)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_box(UIStyle.NIGHT, 5, 8))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -680
	panel.offset_right = -90
	panel.offset_top = 150
	panel.rotation_degrees = 1.0
	s.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var where := "Posto Vigia-01" if Game.mode == "fase" else "Escola"
	col.add_child(UIStyle.title(where, 38, UIStyle.LAMP))
	var obj := UIStyle.label("", 26, UIStyle.PAPER, 0)
	obj.name = "Objetivo"
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj.custom_minimum_size = Vector2(540, 0)
	col.add_child(obj)
	var keys := UIStyle.label(
		"Clique ataque · Q e E habilidades · R especial\n" +
		"Shift dash · 1 a 4 ou Tab troca · F interage\n" +
		"Esc pausa · F5 reinicia (teste)", 21, Color(0.72, 0.76, 0.83), 0)
	col.add_child(keys)
	return s


## Página de HQ do fim da fase (resultado ou derrota).
func _build_end(won: bool, header: String, headline: String, rows: Array, rescued: String) -> Control:
	var s := Control.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(UIStyle.NIGHT, 0.92) if won else Color(0.16, 0.03, 0.04, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(bg)
	UIStyle.halftone(s, 0.3)

	var page := PanelContainer.new()
	var sb := UIStyle.panel_box(UIStyle.PAPER, 6, 12)
	sb.set_content_margin_all(0)
	page.add_theme_stylebox_override("panel", sb)
	page.set_anchors_preset(Control.PRESET_CENTER)
	page.offset_left = -640
	page.offset_right = 640
	page.offset_top = -260
	page.offset_bottom = 260
	page.rotation_degrees = -1.0
	page.pivot_offset = Vector2(640, 260)
	s.add_child(page)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	page.add_child(col)

	var strip := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = UIStyle.INK
	ssb.set_content_margin_all(16)
	ssb.content_margin_left = 34
	strip.add_theme_stylebox_override("panel", ssb)
	col.add_child(strip)
	strip.add_child(UIStyle.title(header, 56, UIStyle.LAMP if won else UIStyle.RED))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 40)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 34)
	m.add_child(body)
	col.add_child(m)

	if rescued != "":
		var por := HeroPortrait.new()
		por.custom_minimum_size = Vector2(300, 360)
		por.skew = 0.06
		por.set_hero(rescued, UIStyle.BLUE)
		body.add_child(por)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)
	var hl := Label.new()
	hl.text = headline.to_upper()
	hl.add_theme_font_size_override("font_size", 44)
	hl.add_theme_color_override("font_color", UIStyle.INK)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hl)
	for r in rows:
		var line := HBoxContainer.new()
		var a := Label.new()
		a.text = r[0]
		a.add_theme_font_size_override("font_size", 36)
		a.add_theme_color_override("font_color", UIStyle.INK)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(a)
		var v := Label.new()
		v.text = r[1]
		v.add_theme_font_size_override("font_size", 36)
		v.add_theme_color_override("font_color", UIStyle.RED if r.size() > 2 and r[2] else UIStyle.INK)
		line.add_child(v)
		right.add_child(line)
		var rule := ColorRect.new()
		rule.color = UIStyle.INK
		rule.custom_minimum_size = Vector2(0, 3)
		right.add_child(rule)

	if won:
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 16)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 20)
		right.add_child(spacer)
		right.add_child(buttons)
		var back := UIStyle.menu_button("Voltar à escola", 32)
		back.add_theme_color_override("font_color", UIStyle.INK)
		back.add_theme_constant_override("outline_size", 0)
		back.pressed.connect(func() -> void:
			Game.mode = "hub"
			restart_requested.emit())
		buttons.add_child(back)
		var again := UIStyle.menu_button("Jogar de novo", 32)
		again.add_theme_color_override("font_color", UIStyle.INK)
		again.add_theme_constant_override("outline_size", 0)
		again.pressed.connect(func() -> void:
			Game.mode = "fase"
			restart_requested.emit())
		buttons.add_child(again)
		back.call_deferred("grab_focus")
	return s


func show_message(text: String, seconds: float) -> void:
	if _message == null:
		return
	_message.text = text
	_message_time = seconds


# ---------------------------------------------------------------- estados

func show_defeat() -> void:
	_state = "defeat"
	_end_screen = _build_end(false, "Derrota", "Todo o grupo caiu. Voltando à escola...",
		[["Baús encontrados", "%d/%d" % [Game.chests_opened, Game.chests_total]]], "")
	_root.add_child(_end_screen)


## rescued: nome do mutante resgatado nesta fase ("" se nenhum).
func show_results(rescued: String = "", new_record: bool = false) -> void:
	_state = "results"
	var t := int(Game.run_time)
	var rows := [
		["Tempo", "%d:%02d%s" % [t / 60, t % 60, "  NOVO RECORDE" if new_record else ""], new_record],
		["Baús encontrados", "%d/%d" % [Game.chests_opened, Game.chests_total]],
	]
	var headline := "%s entrou para o grupo" % rescued if rescued != "" else "Missão cumprida"
	_end_screen = _build_end(true, "Missão cumprida · Posto Vigia-01", headline, rows, rescued)
	_root.add_child(_end_screen)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_restart"):
		restart_requested.emit()
	elif event.is_action_pressed("confirm") and _state == "results":
		Game.mode = "hub"
		restart_requested.emit()
	elif event.is_action_pressed("pause") and (_state == "playing" or _state == "paused"):
		if get_tree().paused and _state == "playing":
			return  # outra tela (cartão de missão, menu) está aberta
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	var paused := _state != "paused"
	get_tree().paused = paused
	_state = "paused" if paused else "playing"
	_pause_screen.visible = paused
	if paused:
		var obj := _pause_screen.find_child("Objetivo", true, false) as Label
		if obj != null and level != null:
			obj.text = _objective.text + ("\n" + _objective_sub.text if _objective_sub.text != "" else "")
		_pause_resume.grab_focus()


func set_hidden(hidden: bool) -> void:
	_root.visible = not hidden


# ---------------------------------------------------------------- por quadro

func _process(delta: float) -> void:
	if party == null:
		return
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time / 0.4, 0.0, 1.0)
	_update_party()
	_update_abilities()
	_update_objective()


## Detecta golpe ou cura comparando com o quadro anterior e avisa o retrato.
func _react(h: Hero, por: HeroPortrait) -> void:
	var last: float = _last_health.get(h, h.health)
	if h.health < last - 0.01:
		por.flash = 1.0
	elif h.health > last + 0.01:
		por.heal_glow = 1.0
	_last_health[h] = h.health
	var frac := h.health / maxf(h.max_health, 1.0)
	por.low = h.in_party and not h.is_dead and frac <= SegmentBar.LOW_FRACTION
	por.downed = h.is_dead
	por.revive = h.revive_progress / maxf(Game.rules.revive_time, 0.01)


func _update_party() -> void:
	var active := party.controlled_hero
	if active == null:
		return
	if active != _shown_hero:
		# Troca de personagem: a barra pula para o valor novo, sem animar.
		_shown_hero = active
		_main_portrait.set_hero(active.stats.display_name, active.stats.color)
		_main_bar.value = active.health / active.max_health
		_main_bar.trail = _main_bar.value
		_main_bar.heal_glow = 0.0
	_main_name.text = active.stats.display_name.to_upper()
	_main_bar.set_value(active.health / active.max_health)
	_main_special.value = active.special / active.stats.special_max
	_react(active, _main_portrait)
	_main_tag.text = "CAÍDO" if active.is_dead else ""
	var frac := active.health / maxf(active.max_health, 1.0)
	var target := 0.0
	if not active.is_dead and frac <= SegmentBar.LOW_FRACTION:
		target = 0.55 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
	_vignette.modulate.a = move_toward(_vignette.modulate.a, target, 0.05)

	var others: Array[Hero] = []
	for h in party.heroes:
		if h != active:
			others.append(h)
	for i in ALLY_ROWS:
		var key := _ally_keys[i]
		var por := _ally_portraits[i]
		var bar := _ally_bars[i]
		var tag := _ally_tags[i]
		var row := _ally_rows[i]
		if i < others.size():
			var h := others[i]
			row.modulate.a = 1.0 if h.in_party else 0.55
			key.text = str(h.party_index + 1)
			if por.hero_name != h.stats.display_name:
				por.set_hero(h.stats.display_name, h.stats.color)
				bar.value = h.health / h.max_health
				bar.trail = bar.value
			bar.visible = true
			bar.set_value(h.health / h.max_health)
			bar.dim = not h.in_party
			_react(h, por)
			if not h.in_party:
				tag.text = "PRESO NA CELA"
			elif h.is_dead:
				tag.text = "CAÍDO · SEGURE F"
			else:
				tag.text = h.stats.display_name.to_upper()
		else:
			row.modulate.a = 0.45
			key.text = str(_free_slot_number(i, others.size()))
			if not por.locked:
				por.set_locked()
			bar.visible = false
			tag.text = ""


func _free_slot_number(row: int, used_rows: int) -> int:
	return party.heroes.size() + (row - used_rows) + 1


func _short(s: String) -> String:
	var i := s.find(" (")
	return s.substr(0, i) if i >= 0 else s


func _update_abilities() -> void:
	var h := party.controlled_hero
	if h == null:
		return
	var slots := h.ability_slots()
	var shown := 0
	for s in slots:
		if shown >= _icons.size():
			break
		if s[0] == "Passiva":
			continue
		var icon := _icons[shown]
		var holder := icon.get_parent() as Control
		holder.visible = true
		icon.key_text = s[0]
		icon.name_text = _short(s[1])
		var total: float = s[3]
		var left: float = s[2]
		icon.cooldown = clampf(left / total, 0.0, 1.0) if total > 0.0 and left > 0.0 else 0.0
		icon.round_shape = s[0] == "R"
		var size := 96.0
		if icon.round_shape:
			size = 130.0
			icon.fill = clampf(h.special / h.stats.special_max, 0.0, 1.0)
			icon.ready_glow = icon.fill >= 1.0
		elif s[0] == "Shift":
			size = 80.0
		icon.custom_minimum_size = Vector2(size, size)
		holder.custom_minimum_size = Vector2(size, 136)
		shown += 1
	for i in range(shown, _icons.size()):
		(_icons[i].get_parent() as Control).visible = false

	var prompt := ""
	if party.current_interactable != null:
		prompt = "F: %s" % party.current_interactable.prompt
	for other in party.heroes:
		if other.in_party and other.is_dead and Game.flat_distance(other.global_position, h.global_position) <= Game.rules.revive_radius:
			prompt = "Segure F: reanimar %s" % other.stats.display_name
	if party.switch_cooldown > 0.0:
		prompt += ("   " if prompt != "" else "") + "Troca: %.1f s" % party.switch_cooldown
	_prompt.text = prompt


func _update_objective() -> void:
	var t := int(Game.run_time)
	_objective.text = level.objective_text().to_upper()
	if Game.chests_total == 0:
		_objective_sub.text = ""
	else:
		_objective_sub.text = "Baús %d/%d · %d:%02d" % [Game.chests_opened, Game.chests_total, t / 60, t % 60]


## Barra fina do especial, inclinada como a de vida.
class SpecialBar extends Control:
	var value: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var k := size.y * 0.8
		var b := 2.0
		var full := PackedVector2Array([Vector2(k, 0), Vector2(size.x, 0), Vector2(size.x - k, size.y), Vector2(0, size.y)])
		var sh := PackedVector2Array()
		for p in full:
			sh.append(p + Vector2(b + 1, b + 1))
		draw_colored_polygon(sh, UIStyle.INK)
		draw_colored_polygon(full, UIStyle.INK)
		var w := (size.x - k) * clampf(value, 0.0, 1.0)
		if w > 1.0:
			var f := PackedVector2Array([Vector2(k + b, b), Vector2(k + w - b, b), Vector2(w - b, size.y - b), Vector2(b, size.y - b)])
			var col := UIStyle.LAMP if value < 1.0 else UIStyle.LAMP2
			draw_colored_polygon(f, col)
