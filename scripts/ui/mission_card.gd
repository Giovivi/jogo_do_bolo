class_name MissionCard
extends CanvasLayer
## Cartão de missão aberto pela mesa do mapa: nome, tipo, mutante preso,
## baús achados, melhor tempo e a equipe (4 lugares) num só cartão.
## "Partir" começa a missão; Esc fecha e volta à escola.

signal depart
signal closed

const MISSION_NAME := "Posto Vigia-01"
const MISSION_TYPE := "Resgate"
const CHESTS_TOTAL := 8

var party: Party


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	get_tree().paused = true

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var card := PanelContainer.new()
	var sb := UIStyle.panel_box(UIStyle.PAPER, 6, 10)
	sb.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -380
	card.offset_right = 380
	card.offset_top = -370
	card.offset_bottom = 370
	card.pivot_offset = Vector2(380, 370)
	card.rotation_degrees = -1.5
	root.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	# Cabeçalho preto com nome e tipo.
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = UIStyle.INK
	hsb.set_content_margin_all(16)
	hsb.content_margin_left = 28
	hsb.content_margin_right = 28
	head.add_theme_stylebox_override("panel", hsb)
	col.add_child(head)
	var hrow := HBoxContainer.new()
	head.add_child(hrow)
	var name_l := UIStyle.title(MISSION_NAME, 50, UIStyle.PAPER)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(name_l)
	var chip := Label.new()
	chip.text = MISSION_TYPE.to_upper()
	chip.add_theme_font_size_override("font_size", 24)
	chip.add_theme_color_override("font_color", UIStyle.INK)
	var csb := UIStyle.panel_box(UIStyle.LAMP, 3, 0)
	csb.set_content_margin_all(4)
	csb.content_margin_left = 14
	csb.content_margin_right = 14
	csb.skew = Vector2(0.15, 0)
	chip.add_theme_stylebox_override("normal", csb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(chip)

	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 28)
	col.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	body.add_child(inner)

	# Mutante preso e números da missão.
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 26)
	inner.add_child(info)
	var rescued: bool = Game.progress.get("feixe", false)
	var sil := HeroPortrait.new()
	sil.custom_minimum_size = Vector2(190, 220)
	sil.skew = 0.0
	sil.set_hero("Feixe" if rescued else "?", UIStyle.BLUE)
	info.add_child(sil)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	info.add_child(lines)
	var best_t: float = Game.progress.get("best_time", -1.0)
	var best_c: int = Game.progress.get("best_chests", 0)
	lines.add_child(_line("Mutante preso: ", "resgatado" if rescued else "desconhecido"))
	lines.add_child(_line("Baús achados: ", "%d de %d" % [best_c, CHESTS_TOTAL]))
	lines.add_child(_line("Melhor tempo: ", "—" if best_t < 0.0 else "%d:%02d" % [int(best_t) / 60, int(best_t) % 60]))
	var guards := Label.new()
	guards.text = "Guardas: soldados e drones"
	guards.add_theme_font_size_override("font_size", 26)
	guards.add_theme_color_override("font_color", Color(0.48, 0.16, 0.14))
	lines.add_child(guards)

	# Equipe.
	var eq := Label.new()
	eq.text = "EQUIPE"
	eq.add_theme_font_size_override("font_size", 32)
	eq.add_theme_color_override("font_color", UIStyle.INK)
	inner.add_child(eq)
	var team := HBoxContainer.new()
	team.add_theme_constant_override("separation", 18)
	inner.add_child(team)
	var members: Array[Hero] = []
	if party != null:
		for h in party.heroes:
			if h.in_party:
				members.append(h)
	for i in 4:
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 4)
		var por := HeroPortrait.new()
		por.custom_minimum_size = Vector2(150, 150)
		var cap := Label.new()
		cap.add_theme_font_size_override("font_size", 22)
		cap.add_theme_color_override("font_color", UIStyle.INK)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i < members.size():
			por.set_hero(members[i].stats.display_name, members[i].stats.color)
			if i == 0:
				por.border_color = UIStyle.LAMP
			cap.text = members[i].stats.display_name.to_upper()
		else:
			por.set_locked()
			cap.text = "VAGO"
			cap.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		slot.add_child(por)
		slot.add_child(cap)
		team.add_child(slot)

	var foot := HBoxContainer.new()
	inner.add_child(foot)
	var esc := Label.new()
	esc.text = "Esc volta à escola"
	esc.add_theme_font_size_override("font_size", 22)
	esc.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	esc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(esc)
	var go := UIStyle.menu_button("Partir", 40)
	go.add_theme_stylebox_override("normal", go.get_theme_stylebox("focus"))
	go.add_theme_color_override("font_color", UIStyle.INK)
	go.add_theme_constant_override("outline_size", 0)
	go.pressed.connect(_depart)
	foot.add_child(go)
	go.call_deferred("grab_focus")


func _line(a: String, b: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(440, 0)
	r.add_theme_font_size_override("normal_font_size", 28)
	r.add_theme_font_size_override("bold_font_size", 28)
	r.add_theme_color_override("default_color", UIStyle.INK)
	r.text = "%s[b]%s[/b]" % [a, b]
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _depart() -> void:
	depart.emit()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
