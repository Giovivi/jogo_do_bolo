class_name HUD
extends CanvasLayer
## HUD do protótipo, montado por código: grupo, habilidades, objetivo,
## mensagens, pausa, derrota e resultado.

signal restart_requested

var party: Party
var level: PostoVigia

var _slot_labels: Array[Label] = []
var _slot_bars: Array[ProgressBar] = []
var _slot_special: Array[ProgressBar] = []
var _ability_box: HBoxContainer
var _ability_labels: Array[Label] = []
var _special_bar: ProgressBar
var _special_label: Label
var _objective: Label
var _message: Label
var _prompt: Label
var _overlay: ColorRect
var _overlay_label: Label
var _message_time: float = 0.0
var _state: String = "playing"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10


func setup(p: Party, l: PostoVigia) -> void:
	party = p
	level = l
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Grupo (canto superior esquerdo).
	var party_box := VBoxContainer.new()
	party_box.position = Vector2(16, 16)
	party_box.custom_minimum_size = Vector2(300, 0)
	root.add_child(party_box)
	for i in Party.MAX_SLOTS:
		var l1 := _label("", 16)
		party_box.add_child(l1)
		_slot_labels.append(l1)
		var bar := _bar(Color(0.3, 0.9, 0.4), Vector2(300, 12))
		party_box.add_child(bar)
		_slot_bars.append(bar)
		var sp := _bar(Color(1.0, 0.75, 0.2), Vector2(300, 5))
		party_box.add_child(sp)
		_slot_special.append(sp)

	# Objetivo (canto superior direito).
	_objective = _label("", 17)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_objective, Control.PRESET_TOP_RIGHT, -620, 16, -20, 96)
	root.add_child(_objective)

	# Mensagem central.
	_message = _label("", 22)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_message, Control.PRESET_CENTER_TOP, -500, 90, 500, 150)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message)

	# Barra de habilidades (embaixo, no centro).
	var bottom := VBoxContainer.new()
	_place(bottom, Control.PRESET_CENTER_BOTTOM, -450, -160, 450, -16)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	_prompt = _label("", 18)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(1, 0.95, 0.6)
	bottom.add_child(_prompt)
	_special_label = _label("", 15)
	_special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_special_label)
	_special_bar = _bar(Color(1.0, 0.75, 0.2), Vector2(900, 10))
	bottom.add_child(_special_bar)
	_ability_box = HBoxContainer.new()
	_ability_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ability_box.add_theme_constant_override("separation", 10)
	bottom.add_child(_ability_box)
	for i in 6:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(140, 56)
		var al := _label("", 14)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(al)
		_ability_box.add_child(panel)
		_ability_labels.append(al)

	# Ajuda (canto inferior esquerdo).
	var help := _label("WASD mover · Mouse mirar · Clique básico · Q/E habilidades · R especial\nShift dash · 1-4/Tab trocar · F interagir/reanimar · Esc pausa\nF2 números de dano · F3 (teste) soltar o Feixe · F5 reiniciar", 13)
	help.modulate = Color(1, 1, 1, 0.7)
	_place(help, Control.PRESET_BOTTOM_LEFT, 16, -70, 600, -12)
	root.add_child(help)

	# Sobreposição (pausa, derrota, resultado).
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.65)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	root.add_child(_overlay)
	_overlay_label = _label("", 30)
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(_overlay_label)


func _place(c: Control, preset: Control.LayoutPreset, left: float, top: float, right: float, bottom: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(color: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_size
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.001
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func show_message(text: String, seconds: float) -> void:
	if _message == null:
		return
	_message.text = text
	_message_time = seconds


# ---------------------------------------------------------------- estados

func show_defeat() -> void:
	_state = "defeat"
	_overlay.visible = true
	_overlay_label.text = "DERROTA\n\nTodo o grupo caiu.\nVoltando à base (a fase reinicia)..."


func show_results() -> void:
	_state = "results"
	_overlay.visible = true
	var t := int(Game.run_time)
	_overlay_label.text = "POSTO VIGIA-01 CONCLUÍDO\n\nTempo: %d:%02d\nBaús encontrados: %d/%d\n\nEnter ou F5 para jogar de novo" % [t / 60, t % 60, Game.chests_opened, Game.chests_total]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_restart"):
		restart_requested.emit()
	elif event.is_action_pressed("debug_numbers"):
		Game.rules.damage_numbers = not Game.rules.damage_numbers
		show_message("Números de dano: %s" % ("ligados" if Game.rules.damage_numbers else "desligados"), 1.5)
	elif event.is_action_pressed("confirm") and _state == "results":
		restart_requested.emit()
	elif event.is_action_pressed("pause") and (_state == "playing" or _state == "paused"):
		_toggle_pause()


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_state = "paused" if paused else "playing"
	_overlay.visible = paused
	_overlay_label.text = "PAUSA\n\nEsc para voltar · F5 para reiniciar"


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


func _update_party() -> void:
	for i in Party.MAX_SLOTS:
		var l := _slot_labels[i]
		var bar := _slot_bars[i]
		var sp := _slot_special[i]
		if i >= party.heroes.size():
			l.text = "%d  — vazio —" % (i + 1)
			l.modulate = Color(1, 1, 1, 0.35)
			bar.visible = false
			sp.visible = false
			continue
		var h := party.heroes[i]
		bar.visible = true
		sp.visible = true
		bar.value = h.health / h.max_health
		sp.value = h.special / h.stats.special_max
		var tag := ""
		if not h.in_party:
			tag = "  (preso na cela)"
		elif h.is_dead:
			tag = "  CAÍDO"
		elif h == party.controlled_hero:
			tag = "  ◀ você"
		l.text = "%d  %s  %d/%d%s" % [i + 1, h.stats.display_name, int(ceil(h.health)), int(h.max_health), tag]
		l.modulate = Color(1, 1, 1, 1) if h.in_party else Color(1, 1, 1, 0.45)


func _update_abilities() -> void:
	var h := party.controlled_hero
	if h == null:
		return
	var slots := h.ability_slots()
	for i in _ability_labels.size():
		var al := _ability_labels[i]
		var panel := al.get_parent() as Control
		if i >= slots.size():
			panel.visible = false
			continue
		panel.visible = true
		var s: Array = slots[i]
		var remaining: float = s[2]
		var line := "%s\n%s" % [s[0], s[1]]
		if s[0] == "R":
			line = "R\n%s" % s[1] if h.special >= h.stats.special_max else "R\n%s (%d%%)" % [s[1], int(100.0 * h.special / h.stats.special_max)]
		if remaining > 0.0:
			line += "\n%.1f s" % remaining
			al.modulate = Color(1, 1, 1, 0.45)
		else:
			al.modulate = Color(1, 1, 1, 1)
		al.text = line
	_special_bar.value = h.special / h.stats.special_max
	var full := h.special >= h.stats.special_max
	_special_label.text = "ESPECIAL PRONTO: aperte R" if full else "Especial %d/%d" % [int(h.special), int(h.stats.special_max)]
	_special_label.modulate = Color(1, 0.85, 0.3) if full else Color(1, 1, 1, 0.8)
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
	_objective.text = "%s\nBaús %d/%d · %d:%02d" % [level.objective_text(), Game.chests_opened, Game.chests_total, t / 60, t % 60]
