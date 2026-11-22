class_name MainMenu
extends CanvasLayer
## Menu inicial "capa de HQ": título grande inclinado com faixa vermelha e
## menu à esquerda; a frente da escola, à noite, fica à mostra à direita.
## Aparece uma vez por sessão, por cima da escola, com o jogo pausado.

signal closed

static var shown: bool = false

var _first: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	shown = true
	# Pausa só depois que a câmera chega na escola, para a capa ter fundo.
	get_tree().create_timer(0.5, true).timeout.connect(func() -> void:
		if is_inside_tree():
			get_tree().paused = true)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Escurece o lado esquerdo e deixa a escola aparecer à direita.
	var g := Gradient.new()
	g.set_color(0, Color(0.024, 0.04, 0.07, 0.95))
	g.set_color(1, Color(0.024, 0.04, 0.07, 0.15))
	g.add_point(0.4, Color(0.024, 0.04, 0.07, 0.9))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 4
	var shade := TextureRect.new()
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var dots := UIStyle.halftone(root, 0.35)
	dots.anchor_right = 0.45

	var cover := Control.new()
	cover.position = Vector2(90, 70)
	cover.rotation_degrees = -4.0
	root.add_child(cover)
	var issue := UIStyle.title("Edição nº 1", 40, UIStyle.LAMP)
	cover.add_child(issue)
	var t1 := UIStyle.title("Projeto", 140)
	t1.position = Vector2(0, 40)
	cover.add_child(t1)
	var t2 := UIStyle.title("Mutantes", 140)
	t2.position = Vector2(0, 170)
	cover.add_child(t2)
	var strip := Panel.new()
	var sb := UIStyle.panel_box(UIStyle.RED, 3, 4)
	strip.add_theme_stylebox_override("panel", sb)
	strip.position = Vector2(6, 350)
	strip.size = Vector2(560, 14)
	cover.add_child(strip)

	var menu := VBoxContainer.new()
	menu.position = Vector2(90, 470)
	menu.add_theme_constant_override("separation", 6)
	root.add_child(menu)
	var cont := UIStyle.menu_button("Continuar", 40)
	cont.disabled = true  # ainda não há jogo salvo
	cont.tooltip_text = "Ainda não há jogo salvo"
	menu.add_child(cont)
	_first = UIStyle.menu_button("Novo jogo", 40)
	_first.pressed.connect(_start)
	menu.add_child(_first)
	var opts := UIStyle.menu_button("Opções", 40)
	opts.disabled = true
	opts.tooltip_text = "Em breve"
	menu.add_child(opts)
	var quit := UIStyle.menu_button("Sair", 40)
	quit.pressed.connect(func() -> void: get_tree().quit())
	menu.add_child(quit)
	_first.call_deferred("grab_focus")


func _start() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
