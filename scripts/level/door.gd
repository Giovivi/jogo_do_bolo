class_name Door
extends StaticBody3D
## Porta simples (abre por interruptor) ou blindada (o laser do Feixe corta).
## A blindada é uma porta de metal escuro (prancha fase1-base-secreta):
## moldura chanfrada, folha com frisos, faixas amarelas e luz vermelha de
## trancada. O corte desenha uma linha incandescente em U na folha; no fim,
## o pedaço cortado tomba para o lado de lá com faíscas e pancada.

signal opened_door

@export var blast_door: bool = false
@export var cut_time_needed: float = 1.5

var is_open: bool = false
var cut_progress: float = 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _size := Vector3.ONE
## Peças da porta blindada.
var _folha: Node3D
var _linhas: Array[MeshInstance3D] = []
var _linha_mat: StandardMaterial3D
var _lampada_mat: StandardMaterial3D
var _faiscas: GPUParticles3D
var _cortando := 0.0
## Margem do corte em relação à borda da folha (m).
const BORDA := 0.32


func setup(size: Vector3, color: Color) -> void:
	_size = size
	collision_layer = Game.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.metallic = 0.1
	if blast_door:
		_build_blindada()
	else:
		_mesh = MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = size
		_mesh.mesh = m
		_mesh.material_override = BaseKit.mat("porta")
		_mesh.position.y = size.y * 0.5
		add_child(_mesh)
		# Porta de serviço no visual da base: chapa escura com faixas de
		# aviso e frisos (desce para dentro do chão quando abre).
		var lado := 0 if size.x >= size.z else 2
		for sx: float in [-1.0, 1.0]:
			var fr := Vector3.ZERO
			fr[2 - lado] = sx * (size[2 - lado] * 0.5 + 0.01)
			var faixa := Look.piece(_mesh, Look.box(Vector3(size.x, 0.25, 0.02) if lado == 0 else Vector3(0.02, 0.25, size.z)), BaseKit.mat("aviso"), fr + Vector3(0, -0.4, 0))
			faixa.scale = Vector3(0.9, 1, 1) if lado == 0 else Vector3(1, 1, 0.9)
			for k in 3:
				Look.piece(_mesh, Look.box(Vector3(size.x * 0.7, 0.04, 0.02) if lado == 0 else Vector3(0.02, 0.04, size.z * 0.7)), BaseKit.mat("peca_escura"), fr + Vector3(0, 0.3 + k * 0.3, 0))
	if blast_door:
		add_to_group("blast_doors")
		_label = Label3D.new()
		_label.text = "porta blindada"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 40
		_label.pixel_size = 0.01
		_label.outline_size = 8
		_label.position.y = size.y + 0.5
		add_child(_label)
		# Sem texto em cima da porta: o cadeado do HUD já avisa quem abre.
		_label.visible = false


# ================================================================ modelo

## Eixos locais: x = espessura, z = largura, y = altura. Cada face tem o
## mesmo desenho (frente = +x, o lado de onde o Feixe corta).
func _build_blindada() -> void:
	var t := _size.x
	var w := _size.z * 0.5
	var h := _size.y
	var escuro := BaseKit.mat("porta")
	var claro := BaseKit.mat("porta_placa")
	var moldura := BaseKit.mat("peca")
	var tf := 0.36
	# Moldura (fica no lugar): laterais, verga e cantos de cima chanfrados.
	BaseKit.peca(self, Vector3(-t * 0.5, 0, -w), Vector3(t * 0.5, h, -w + BORDA), moldura)
	BaseKit.peca(self, Vector3(-t * 0.5, 0, w - BORDA), Vector3(t * 0.5, h, w), moldura)
	BaseKit.peca(self, Vector3(-t * 0.5, h - BORDA, -w + BORDA), Vector3(t * 0.5, h, w - BORDA), moldura)
	for sz: float in [-1.0, 1.0]:
		var c0 := Vector3(-t * 0.5, h - BORDA, sz * (w - BORDA))
		var tri := PackedVector2Array([Vector2(0, 0), Vector2(0, -0.45), Vector2(-0.45, 0)])
		# Triângulo no canto de cima, extrudado ao longo de x.
		var perf := PackedVector2Array()
		for p in tri:
			perf.append(Vector2(p.x * -sz, p.y))
		BaseKit.prisma(self, perf, c0, c0 + Vector3(t, 0, 0), Vector3.UP, moldura, false)
		# Faixas amarelas na moldura, dos dois lados (como na referência).
		for sx: float in [-1.0, 1.0]:
			for k in 5:
				var y := h * 0.42 + k * 0.13
				var zc := sz * (w - BORDA * 0.5)
				BaseKit.peca(self, Vector3(sx * t * 0.5 - 0.005, y, zc - 0.11), Vector3(sx * t * 0.5 + 0.005, y + 0.06, zc + 0.11), BaseKit.mat("amarelo"))
	# Folha que será cortada: gira em volta da quina de baixo do lado de lá.
	_folha = Node3D.new()
	_folha.name = "Folha"
	_folha.position = Vector3(-tf * 0.5, 0, 0)
	add_child(_folha)
	var fw := w - BORDA
	var fh := h - BORDA
	BaseKit.peca(_folha, Vector3(0, 0, -fw), Vector3(tf, fh, fw), escuro)
	# Placas em relevo dos dois lados: duas metades chanfradas e a faixa
	# do meio, com a emenda vertical escura no centro.
	for sx: float in [-1.0, 1.0]:
		var face := tf if sx > 0.0 else 0.0
		var a := Vector3(face, 0, 0)
		var b := a + Vector3(0.04 * sx, 0, 0)
		for sz: float in [-1.0, 1.0]:
			var z0 := 0.06
			var z1 := fw - 0.16
			var y0 := 0.2
			var y1 := fh - 0.2
			var ch := 0.35
			var poly := [Vector2(z0, y0), Vector2(z1 - ch, y0), Vector2(z1, y0 + ch), Vector2(z1, y1 - ch), Vector2(z1 - ch, y1), Vector2(z0, y1)]
			var perfil := PackedVector2Array()
			# lado do prisma (cima = UP, frente = ±x) = UP × (±x) = ∓z.
			for p in poly:
				perfil.append(Vector2(p.x * sz * -sx, p.y))
			BaseKit.prisma(_folha, perfil, a, b, Vector3.UP, claro, false)
			# Frisos chanfrados (recortes) em cada metade.
			var g0 := Vector3(face + 0.045 * sx, 0, 0)
			var g1 := g0 + Vector3(0.01 * sx, 0, 0)
			for yy: float in [fh * 0.3, fh * 0.7]:
				var gp := PackedVector2Array()
				for p in [Vector2(0.25, yy - 0.025), Vector2(z1 - 0.3, yy - 0.025), Vector2(z1 - 0.3, yy + 0.025), Vector2(0.25, yy + 0.025)]:
					gp.append(Vector2(p.x * sz * -sx, p.y))
				BaseKit.prisma(_folha, gp, g0, g1, Vector3.UP, BaseKit.mat("peca_escura"), false)
		# Faixa horizontal do meio, amarela e preta.
		BaseKit.peca(_folha, Vector3(minf(face, face + 0.05 * sx), fh * 0.47, -fw + 0.12), Vector3(maxf(face, face + 0.05 * sx), fh * 0.53, fw - 0.12), BaseKit.mat("aviso"))
	# Luz vermelha de trancada em cima, dos dois lados.
	_lampada_mat = BaseKit.luz(Color(1.0, 0.12, 0.08), 3.0)
	for sx: float in [-1.0, 1.0]:
		BaseKit.peca(self, Vector3(sx * t * 0.5 - 0.04, h - BORDA * 0.5 - 0.06, -0.35), Vector3(sx * t * 0.5 + 0.04, h - BORDA * 0.5 + 0.06, 0.35), _lampada_mat)
	# Linha do corte (U: sobe pela esquerda, cruza em cima, desce pela direita),
	# na face de onde o Feixe corta.
	_linha_mat = BaseKit.luz(Color(1.0, 0.55, 0.15), 4.0)
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = _linha_mat
		mi.visible = false
		add_child(mi)
		_linhas.append(mi)
	_faiscas = _make_faiscas()
	add_child(_faiscas)


func _make_faiscas() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.6
	p.emitting = false
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(1, 0.6, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.7, 0.3) * 4.0
	q.material = m
	p.draw_pass_1 = q
	return p


## Desenha a linha incandescente até a fração f do caminho do corte e
## devolve a ponta (onde saem as faíscas), em coordenadas locais.
func _desenha_corte(f: float) -> Vector3:
	var x := 0.36 * 0.5 + 0.05
	var fw := _size.z * 0.5 - BORDA
	var fh := _size.y - BORDA
	var segs := [[Vector3(x, 0, -fw), Vector3(x, fh, -fw)], [Vector3(x, fh, -fw), Vector3(x, fh, fw)], [Vector3(x, fh, fw), Vector3(x, 0, fw)]]
	var total := fh * 2.0 + fw * 2.0
	var resta := f * total
	var ponta: Vector3 = segs[0][0]
	for k in 3:
		var a: Vector3 = segs[k][0]
		var b: Vector3 = segs[k][1]
		var L := a.distance_to(b)
		var feito := clampf(resta, 0.0, L)
		resta -= L
		var mi := _linhas[k]
		mi.visible = feito > 0.01
		if not mi.visible:
			continue
		var fim := a + (b - a).normalized() * feito
		var bm := mi.mesh as BoxMesh
		var d := fim - a
		bm.size = Vector3(0.03, maxf(absf(d.y), 0.06), maxf(absf(d.z), 0.06))
		mi.position = (a + fim) * 0.5
		ponta = fim
	return ponta


func _process(delta: float) -> void:
	if _faiscas == null:
		return
	_cortando = maxf(0.0, _cortando - delta)
	if _cortando <= 0.0 and _faiscas.emitting and not is_open:
		_faiscas.emitting = false
	if not is_open and cut_progress > 0.0:
		# A linha esfria devagar se o Feixe parar de cortar.
		_linha_mat.albedo_color = Color(1.0, 0.55, 0.15) * (4.0 if _cortando > 0.0 else 2.0)


## Chamado pelo laser do Feixe enquanto o feixe toca a porta.
func cut(delta: float, source: Node) -> void:
	if is_open or not blast_door or not (source is Feixe):
		return
	cut_progress += delta
	var f := clampf(cut_progress / cut_time_needed, 0.0, 1.0)
	var ponta := _desenha_corte(f)
	_cortando = 0.15
	_faiscas.position = ponta
	_faiscas.emitting = true
	# Mostra o progresso só enquanto corta.
	_label.text = "cortando %d%%" % int(f * 100.0)
	_label.visible = true
	_label.modulate = Color(1.0, 0.6, 0.3)
	if cut_progress >= cut_time_needed:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	collision_layer = 0
	if _label != null:
		_label.visible = false
	if _folha != null:
		_derrubar()
		opened_door.emit()
		return
	var tw := create_tween()
	tw.tween_property(_mesh, "position:y", -3.5, 0.6)
	tw.tween_callback(_mesh.hide)
	opened_door.emit()


## O pedaço cortado tomba para o lado de lá (-x local) e bate no chão.
func _derrubar() -> void:
	_desenha_corte(1.0)
	_lampada_mat.albedo_color = Color(0.2, 1.0, 0.4) * 2.5
	var tw := create_tween()
	tw.tween_property(_folha, "rotation:z", PI * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_pancada)
	tw.tween_property(_folha, "rotation:z", PI * 0.5 - 0.07, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(_folha, "rotation:z", PI * 0.5, 0.1).set_ease(Tween.EASE_IN)
	tw.tween_property(_linha_mat, "albedo_color", Color(0.4, 0.1, 0.02), 1.5)


func _pancada() -> void:
	_faiscas.position = Vector3(-_size.y * 0.6, 0.1, 0)
	_faiscas.amount = 120
	_faiscas.one_shot = true
	_faiscas.restart()
	_faiscas.emitting = true
	var cam := get_viewport().get_camera_3d()
	var n: Node = cam
	while n != null and not n.has_method("add_shake"):
		n = n.get_parent()
	if n != null and Game.rules.get("screen_shake") != false:
		n.add_shake(0.35, 0.3)
