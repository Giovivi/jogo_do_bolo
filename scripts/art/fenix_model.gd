class_name FenixModel
extends Node3D
## Modelo provisório do Fênix (low poly, cel shading), até o design fechar.
## Macacão de contenção cinza-escuro rasgado, número de prisioneiro no peito,
## algema dourada quebrada, fogo azul nos antebraços formando garras, olhos
## dourados, pontas do cabelo em chama e duas asas curtas de chama nas costas.

const CHARCOAL := Color("2b2d35")
const COBALT := Color("3fa9ff")
const CORE := Color("bfe9ff")
const GOLD := Color("e0b040")
const SKIN := Color(0.62, 0.47, 0.38)
const HAIR := Color(0.1, 0.09, 0.1)

@export var wings_open: bool = true

var wings: Node3D


func _ready() -> void:
	var suit := Look.surface(CHARCOAL, {"variation": 0.15, "noise_scale": 5.0, "outline": 0.025})
	var suit_dark := Look.surface(CHARCOAL.darkened(0.3), {"outline": 0.025})
	var skin := Look.surface(SKIN, {"variation": 0.05, "outline": 0.02})
	var hair := Look.surface(HAIR, {"variation": 0.1, "outline": 0.02})
	var gold := Look.surface(GOLD, {"variation": 0.1, "outline": 0.02})
	var fire := Look.glow(COBALT, 3.0)
	var core := Look.glow(CORE, 3.5)
	var eyes := Look.glow(GOLD, 3.0)

	# Pernas e botas.
	for side in [-1.0, 1.0]:
		Look.piece(self, Look.cylinder(0.1, 0.12, 0.85, 6), suit, Vector3(0.13 * side, 0.5, 0))
		Look.piece(self, Look.box(Vector3(0.18, 0.14, 0.3)), suit_dark, Vector3(0.13 * side, 0.07, -0.04))
	# Tronco (mais largo no ombro) e cinto.
	Look.piece(self, Look.cylinder(0.24, 0.17, 0.62, 6), suit, Vector3(0, 1.22, 0))
	Look.piece(self, Look.cylinder(0.18, 0.18, 0.08, 6), suit_dark, Vector3(0, 0.93, 0))
	# Rasgos no macacão (pele aparecendo).
	Look.piece(self, Look.box(Vector3(0.1, 0.06, 0.02)), skin, Vector3(0.12, 1.08, -0.18), Vector3(0, 0, 20))
	Look.piece(self, Look.box(Vector3(0.06, 0.1, 0.02)), skin, Vector3(-0.15, 0.62, -0.1), Vector3(0, 0, -15))
	# Número de prisioneiro no peito.
	Look.piece(self, Look.box(Vector3(0.16, 0.08, 0.02)), Look.surface(Color(0.82, 0.8, 0.72)), Vector3(-0.08, 1.36, -0.2))
	var num := Label3D.new()
	num.text = "V-0417"
	num.font_size = 20
	num.pixel_size = 0.0025
	num.modulate = Color(0.1, 0.1, 0.1)
	num.position = Vector3(-0.08, 1.36, -0.215)
	num.rotation_degrees = Vector3(0, 180, 0)
	add_child(num)
	# Braços: parte de cima no macacão, antebraço e mão em fogo azul com garras.
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.3 * side, 1.45, 0)
		arm.rotation_degrees = Vector3(-12, 0, 6 * side)
		add_child(arm)
		Look.piece(arm, Look.cylinder(0.07, 0.08, 0.34, 6), suit, Vector3(0, -0.17, 0))
		Look.piece(arm, Look.cylinder(0.1, 0.06, 0.34, 6), fire, Vector3(0, -0.5, 0))
		Look.piece(arm, Look.cylinder(0.05, 0.03, 0.3, 5), core, Vector3(0, -0.48, 0))
		for c in 3:
			Look.piece(arm, Look.cylinder(0.0, 0.025, 0.2, 4), core, Vector3((c - 1) * 0.04, -0.74, -0.03), Vector3(-10, 0, (c - 1) * 8))
		# Labaredas subindo do antebraço.
		for f in 3:
			Look.piece(arm, Look.cylinder(0.0, 0.04, 0.22, 4), fire, Vector3(0.06 * side, -0.38 + f * 0.08, 0.02 * f), Vector3(0, 0, 25 * side))
	# Algema dourada quebrada no pulso esquerdo.
	var cuff := Node3D.new()
	cuff.position = Vector3(-0.36, 1.12, -0.03)
	add_child(cuff)
	Look.piece(cuff, Look.cylinder(0.11, 0.11, 0.07, 8), gold, Vector3.ZERO, Vector3(-20, 0, -12))
	Look.piece(cuff, Look.box(Vector3(0.04, 0.12, 0.04)), gold, Vector3(-0.06, -0.12, 0.02), Vector3(0, 0, 30))
	# Cabeça, cabelo escuro com pontas em chama, olhos dourados.
	Look.piece(self, Look.cylinder(0.06, 0.07, 0.12, 6), skin, Vector3(0, 1.58, 0))
	Look.piece(self, Look.blob(0.16, 0.36), skin, Vector3(0, 1.76, 0))
	Look.piece(self, Look.blob(0.17, 0.22), hair, Vector3(0, 1.86, 0.03))
	for i in 5:
		var a := -0.5 + i * 0.25
		Look.piece(self, Look.cylinder(0.0, 0.05, 0.2, 4), hair, Vector3(a * 0.3, 1.94, 0.06), Vector3(40, 0, -a * 40))
		Look.piece(self, Look.cylinder(0.0, 0.03, 0.12, 4), fire, Vector3(a * 0.36, 2.04, 0.12), Vector3(50, 0, -a * 40))
	for side in [-1.0, 1.0]:
		Look.piece(self, Look.box(Vector3(0.06, 0.025, 0.02)), eyes, Vector3(0.06 * side, 1.78, -0.15))
	# Asas curtas de chama: planos triangulares emissivos.
	wings = Node3D.new()
	wings.name = "Asas"
	wings.position = Vector3(0, 1.4, 0.18)
	wings.visible = wings_open
	add_child(wings)
	for side in [-1.0, 1.0]:
		for i in 4:
			var feather := MeshInstance3D.new()
			feather.mesh = _triangle(0.95 - i * 0.16, 0.18)
			var mat := Look.glow(COBALT if i % 2 == 0 else COBALT.lerp(CORE, 0.45), 2.0)
			mat.render_priority = 1
			feather.material_override = mat
			feather.position = Vector3(0.12 * side, 0.1 - i * 0.08, 0)
			feather.rotation_degrees = Vector3(0, (0.0 if side > 0 else 180.0) - 20.0 * side, 30.0 - i * 16.0)
			wings.add_child(feather)


## Triângulo fino (comprimento ao longo de +X), visível dos dois lados.
func _triangle(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, -width * 0.5, 0), Vector3(0, width * 0.5, 0), Vector3(length, 0, 0)]
	for p in pts:
		st.set_normal(Vector3.BACK)
		st.add_vertex(p)
	for i in [2, 1, 0]:
		st.set_normal(Vector3.FORWARD)
		st.add_vertex(pts[i])
	return st.commit()
