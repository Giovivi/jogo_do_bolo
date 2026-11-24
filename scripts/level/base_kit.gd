class_name BaseKit
extends RefCounted
## Kit visual da base militar secreta (fase 1, prancha fase1-base-secreta):
## metal escuro, frisos de LED, telas, consoles, dutos e peças chanfradas.
## Materiais realistas (PBR, sem o cel shading dos heróis), fotos do
## ambientCG (CC0, ver assets/textures/CREDITS.md).

const TELA := preload("res://shaders/tela.gdshader")
const TEX_PATH := "res://assets/textures/%s/%s_%s.jpg"
const LED := Color(0.75, 0.9, 1.0)
const LARANJA := Color(1.0, 0.45, 0.1)

static var _mats: Dictionary = {}


## Metal com foto projetada pelo mundo (sem UV).
static func metal(id: String, size: float, tint: Color, metallic: float = 0.6, rough: float = 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX_PATH % [id, id, "color"])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX_PATH % [id, id, "normal"])
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE / size
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.metallic = metallic
	m.roughness = rough
	return m


## Metal pintado liso (peças modernas, sem foto).
static func liso(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


static func luz(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * energy
	return m


static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"parede":
			m = metal("MetalPlates005", 3.0, Color(0.5, 0.53, 0.58), 0.55, 0.5)
		"parede_hex":
			m = metal("Tiles072", 1.6, Color(0.75, 0.8, 0.88), 0.4, 0.45)
		"parede_diag":
			m = metal("MetalPlates006", 2.4, Color(0.62, 0.65, 0.7), 0.55, 0.45)
		"teto":
			m = metal("MetalPlates004", 2.0, Color(0.3, 0.32, 0.36), 0.5, 0.6)
		"piso":
			m = metal("MetalPlates004", 2.0, Color(0.55, 0.57, 0.6), 0.45, 0.55)
		"peca":
			m = liso(Color(0.3, 0.33, 0.37), 0.65, 0.38)
		"peca_escura":
			m = liso(Color(0.13, 0.14, 0.16), 0.6, 0.45)
		"caixa":
			m = liso(Color(0.17, 0.19, 0.21), 0.55, 0.5)
		"caixa_clara":
			m = liso(Color(0.42, 0.45, 0.48), 0.6, 0.35)
		"plataforma":
			m = metal("MetalPlates004", 1.0, Color(0.5, 0.53, 0.58), 0.55, 0.5)
		"porta":
			m = liso(Color(0.22, 0.26, 0.28), 0.7, 0.35)
		"porta_placa":
			m = liso(Color(0.33, 0.38, 0.41), 0.7, 0.3)
		"aviso":
			m = metal("PaintedMetal016", 0.8, Color(1, 1, 1), 0.3, 0.5)
		"vao":
			m = metal("MetalPlates005", 3.0, Color(0.22, 0.23, 0.26), 0.5, 0.6)
		"fundo":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.02, 0.02, 0.025)
			m = s
		"led":
			m = luz(LED, 3.0)
		"led_fraco":
			m = luz(LED, 1.4)
		"laranja":
			m = luz(LARANJA, 2.2)
		"vermelho":
			m = luz(Color(1.0, 0.12, 0.08), 3.0)
		"amarelo":
			m = luz(Color(1.0, 0.78, 0.15), 2.0)
		"tinta_branca":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.85, 0.87, 0.9)
			s.roughness = 0.6
			m = s
		"tinta_amarela":
			var s2 := StandardMaterial3D.new()
			s2.albedo_color = Color(0.95, 0.75, 0.12)
			s2.roughness = 0.6
			m = s2
		"tinta_laranja":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.95, 0.42, 0.08)
			s.roughness = 0.6
			m = s
		_:
			if key.begins_with("tela"):
				var sm := ShaderMaterial.new()
				sm.shader = TELA
				sm.set_shader_parameter("seed", float(key.substr(4)))
				m = sm
	_mats[key] = m
	return m


static func tela_mat(i: int) -> Material:
	return mat("tela%d" % (i % 6))


# ================================================================ geometria

## Barra reta extrudada de "a" até "b" com o perfil (convexo) dado em
## (lado, cima). "cima" é o eixo dos segundos valores do perfil; "lado" é
## cima × frente. solid: colide na camada do mundo.
static func prisma(parent: Node3D, perfil: PackedVector2Array, a: Vector3, b: Vector3, cima: Vector3, m: Material, solid: bool = true) -> Node3D:
	var fwd := (b - a).normalized()
	var up := (cima - fwd * cima.dot(fwd)).normalized()
	var side := up.cross(fwd)
	var n := perfil.size()
	var p0: Array[Vector3] = []
	var p1: Array[Vector3] = []
	for v in perfil:
		p0.append(a + side * v.x + up * v.y)
		p1.append(b + side * v.x + up * v.y)
	var centro := Vector3.ZERO
	for p in p0:
		centro += p
	centro /= float(n)
	centro += (b - a) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var j := (i + 1) % n
		var nm := (p0[j] - p0[i]).cross(fwd).normalized()
		if nm.dot((p0[i] + p0[j]) * 0.5 + (b - a) * 0.5 - centro) < 0.0:
			nm = -nm
		_quad(st, p0[i], p0[j], p1[j], p1[i], nm)
	var tris := Geometry2D.triangulate_polygon(perfil)
	for k in range(0, tris.size(), 3):
		_tri(st, p0[tris[k]], p0[tris[k + 1]], p0[tris[k + 2]], -fwd)
		_tri(st, p1[tris[k]], p1[tris[k + 1]], p1[tris[k + 2]], fwd)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	if not solid:
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cs := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p in p0:
		pts.append(p)
	for p in p1:
		pts.append(p)
	cs.points = pts
	shape.shape = cs
	body.add_child(shape)
	body.add_child(mi)
	parent.add_child(body)
	return body


## Triângulo com a frente para "nm" (o Godot desenha a frente em sentido horário).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nm: Vector3) -> void:
	if (b - a).cross(c - a).dot(nm) > 0.0:
		var t := b
		b = c
		c = t
	for p in [a, b, c]:
		st.set_normal(nm)
		st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nm: Vector3) -> void:
	_tri(st, a, b, c, nm)
	_tri(st, a, c, d, nm)


## Caixa só de desenho, dada pelos cantos.
static func peca(parent: Node3D, lo: Vector3, hi: Vector3, m: Material) -> MeshInstance3D:
	return Look.piece(parent, Look.box(hi - lo), m, (lo + hi) * 0.5)


# ================================================================ peças

## Parede vista de dentro da sala: "o" = ponto da face na base (u = 0),
## "dir" = direção ao longo da parede, "nrm" = direção para dentro da sala.
## Devolve a posição no mundo de (u ao longo, s para dentro, y).
static func ponto(o: Vector3, dir: Vector3, nrm: Vector3, u: float, s: float, y: float) -> Vector3:
	return o + dir * u + nrm * s + Vector3(0, y, 0)


## Rodapé chanfrado com friso de LED em cima e faixa de LED no chão.
static func rodape(parent: Node3D, o: Vector3, dir: Vector3, nrm: Vector3, u0: float, u1: float) -> void:
	var a := ponto(o, dir, nrm, u0, 0, 0)
	var b := ponto(o, dir, nrm, u1, 0, 0)
	var perfil := _perfil_parede(dir, nrm, [Vector2(0, 0), Vector2(0.28, 0), Vector2(0.28, 0.22), Vector2(0.1, 0.45), Vector2(0, 0.45)])
	prisma(parent, perfil, a, b, Vector3.UP, mat("peca_escura"), false)
	# Friso na quina de cima do rodapé e LED embutido no chão.
	var f := _perfil_parede(dir, nrm, [Vector2(0.09, 0.44), Vector2(0.13, 0.44), Vector2(0.13, 0.47), Vector2(0.09, 0.47)])
	prisma(parent, f, a, b, Vector3.UP, mat("led_fraco"), false)
	var l := _perfil_parede(dir, nrm, [Vector2(0.4, 0.0), Vector2(0.46, 0.0), Vector2(0.46, 0.012), Vector2(0.4, 0.012)])
	prisma(parent, l, a, b, Vector3.UP, mat("led"), false)


## Sanca chanfrada entre parede e teto, com LED na beira do teto.
static func sanca(parent: Node3D, o: Vector3, dir: Vector3, nrm: Vector3, u0: float, u1: float, h: float, d: float) -> void:
	var a := ponto(o, dir, nrm, u0, 0, 0)
	var b := ponto(o, dir, nrm, u1, 0, 0)
	prisma(parent, _perfil_parede(dir, nrm, [Vector2(0, h), Vector2(d, h), Vector2(0, h - d)]), a, b, Vector3.UP, mat("peca"))
	prisma(parent, _perfil_parede(dir, nrm, [Vector2(d, h - 0.02), Vector2(d + 0.1, h - 0.02), Vector2(d + 0.1, h), Vector2(d, h)]), a, b, Vector3.UP, mat("led"), false)


## Parede de cima inclinada para dentro (como a sala de controle da referência).
static func inclinada(parent: Node3D, o: Vector3, dir: Vector3, nrm: Vector3, u0: float, u1: float, y0: float, h: float, d: float) -> void:
	var a := ponto(o, dir, nrm, u0, 0, 0)
	var b := ponto(o, dir, nrm, u1, 0, 0)
	prisma(parent, _perfil_parede(dir, nrm, [Vector2(0, y0), Vector2(0, h), Vector2(d, h)]), a, b, Vector3.UP, mat("parede"))
	prisma(parent, _perfil_parede(dir, nrm, [Vector2(0, y0 - 0.06), Vector2(0.06, y0 - 0.06), Vector2(0.06, y0), Vector2(0, y0)]), a, b, Vector3.UP, mat("led"), false)


## Pilar chanfrado (de 0 a "h"), com fresta de LED vertical na frente.
static func pilar(parent: Node3D, o: Vector3, dir: Vector3, nrm: Vector3, u: float, h: float, largura: float = 0.7, prof: float = 0.32) -> void:
	var w := largura * 0.5
	var c := 0.14
	var base := ponto(o, dir, nrm, u, 0, 0)
	var perfil := PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w, prof - c), Vector2(w - c, prof), Vector2(-w + c, prof), Vector2(-w, prof - c)])
	# Extrudado para cima: "cima" do perfil = para dentro da sala.
	prisma(parent, _gira(perfil, dir, nrm), base, base + Vector3(0, h, 0), nrm, mat("peca"))
	var led := PackedVector2Array([Vector2(-0.025, prof), Vector2(0.025, prof), Vector2(0.025, prof + 0.015), Vector2(-0.025, prof + 0.015)])
	prisma(parent, _gira(led, dir, nrm), base + Vector3(0, 0.8, 0), base + Vector3(0, h - 1.2, 0), nrm, mat("led_fraco"), false)


## Tela na parede: moldura escura e o monitor aceso.
static func tela(parent: Node3D, o: Vector3, dir: Vector3, nrm: Vector3, u: float, y: float, w: float, h: float, i: int) -> void:
	var c := ponto(o, dir, nrm, u, 0.0, y)
	var moldura := Look.piece(parent, Look.box(Vector3(w + 0.16, h + 0.16, 0.1)), mat("peca_escura"), c + nrm * 0.05)
	moldura.look_at_from_position(c + nrm * 0.05, c + nrm * 2.0, Vector3.UP)
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var tela_mi := Look.piece(parent, q, tela_mat(i), c + nrm * 0.105)
	tela_mi.look_at_from_position(c + nrm * 0.105, c - nrm, Vector3.UP)


## Painel recuado de hexágonos com moldura de LED.
static func painel_hex(parent: Node3D, o: Vector3, dir: Vector3, nrm: Vector3, u0: float, u1: float, y0: float, y1: float) -> void:
	var lo := ponto(o, dir, nrm, u0, 0.0, y0)
	var hi := ponto(o, dir, nrm, u1, 0.05, y1)
	Obra.bloco(parent, lo, hi, mat("parede_hex"), false)
	for e in [[u0, u1, y0 - 0.04, y0], [u0, u1, y1, y1 + 0.04], [u0 - 0.04, u0, y0 - 0.04, y1 + 0.04], [u1, u1 + 0.04, y0 - 0.04, y1 + 0.04]]:
		peca(parent, _min3(ponto(o, dir, nrm, e[0], 0, e[2]), ponto(o, dir, nrm, e[1], 0.03, e[3])), _max3(ponto(o, dir, nrm, e[0], 0, e[2]), ponto(o, dir, nrm, e[1], 0.03, e[3])), mat("led_fraco"))


## Console de controle (serve de cobertura): base, tampo inclinado com tela
## e dois monitores atrás. pos = centro da base no chão; frente = para onde
## o operador olha (o monitor fica do lado de lá).
static func console(parent: Node3D, pos: Vector3, frente: Vector3, largura: float, i: int) -> void:
	var fw := Vector3(frente.x, 0, frente.z).normalized()
	var side := Vector3.UP.cross(fw)
	var a := pos - side * largura * 0.5
	var b := pos + side * largura * 0.5
	# Perfil (lado = -frente/para trás..., cima): visto de lado.
	var p := PackedVector2Array([Vector2(-0.45, 0), Vector2(0.45, 0), Vector2(0.45, 1.25), Vector2(0.1, 1.25), Vector2(-0.5, 0.95), Vector2(-0.5, 0.15)])
	# "lado" do prisma = cima × (b - a) = para trás do operador (-fw).
	prisma(parent, p, a, b, Vector3.UP, mat("peca_escura"))
	# Tela no tampo inclinado.
	var meio := pos + fw * 0.2 + Vector3(0, 1.1, 0)
	var q := QuadMesh.new()
	q.size = Vector2(largura - 0.3, 0.55)
	var t := Look.piece(parent, q, tela_mat(i), meio)
	var nrm_t := (fw * 0.3 + Vector3.UP * 0.6).normalized()
	t.look_at_from_position(meio + nrm_t * 0.012, meio - nrm_t, Vector3.UP if absf(nrm_t.y) < 0.99 else fw)
	# Monitores atrás, virados para o operador.
	for k in [-1, 1]:
		var mc: Vector3 = pos - fw * 0.25 + side * k * largura * 0.24 + Vector3(0, 1.75, 0)
		var mw := largura * 0.44
		var mo := Look.piece(parent, Look.box(Vector3(mw + 0.08, 0.6, 0.06)), mat("peca_escura"), mc)
		mo.look_at_from_position(mc, mc + fw, Vector3.UP)
		var qm := QuadMesh.new()
		qm.size = Vector2(mw, 0.52)
		var tm := Look.piece(parent, qm, tela_mat(i + 2 + k), mc + fw * 0.035)
		tm.look_at_from_position(mc + fw * 0.035, mc - fw, Vector3.UP)
		peca(parent, mc - Vector3(0.03, 0.6, 0.03) - fw * 0.05, mc + Vector3(0.03, -0.3, 0.03) - fw * 0.05, mat("peca"))
	# Botões acesos na beira.
	for k in 5:
		var bp := pos + fw * 0.42 + side * (k - 2) * 0.18 + Vector3(0, 0.98, 0)
		Look.piece(parent, Look.box(Vector3(0.08, 0.02, 0.05)), mat("laranja" if k % 2 == 0 else "led"), bp)


## Armário de servidores com luzes piscando e friso de LED.
static func armario(parent: Node3D, pos: Vector3, frente: Vector3, i: int) -> void:
	var fw := Vector3(frente.x, 0, frente.z).normalized()
	var side := Vector3.UP.cross(fw)
	var a := pos - side * 0.55
	var b := pos + side * 0.55
	var p := PackedVector2Array([Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0.4, 2.4), Vector2(-0.25, 2.4), Vector2(-0.4, 2.25)])
	prisma(parent, p, a, b, Vector3.UP, mat("peca_escura"))
	for r in 9:
		for k in 4:
			if (r * 7 + k * 3 + i) % 4 == 0:
				continue
			var lp := pos + fw * 0.41 + side * (k - 1.5) * 0.18 + Vector3(0, 0.4 + r * 0.2, 0)
			Look.piece(parent, Look.box(Vector3(0.05, 0.03, 0.01)), mat("laranja" if (r + k + i) % 5 == 0 else "led"), lp).look_at_from_position(lp, lp + fw, Vector3.UP)
	var fr := pos + fw * 0.41 + side * 0.5 + Vector3(0, 1.2, 0)
	Look.piece(parent, Look.box(Vector3(0.03, 2.0, 0.01)), mat("led_fraco"), fr).look_at_from_position(fr, fr + fw, Vector3.UP)


## Duto redondo no teto, com abraçadeiras e suportes.
static func duto(parent: Node3D, a: Vector3, b: Vector3, r: float, teto_y: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 16
	var mi := Look.piece(parent, cyl, mat("peca"), (a + b) * 0.5)
	mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.9 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var n := int(a.distance_to(b) / 3.0)
	for k in range(1, n + 1):
		var p := a.lerp(b, float(k) / float(n + 1))
		var anel := CylinderMesh.new()
		anel.top_radius = r + 0.04
		anel.bottom_radius = r + 0.04
		anel.height = 0.12
		anel.radial_segments = 16
		var am := Look.piece(parent, anel, mat("peca_escura"), p)
		am.look_at_from_position(p, b, Vector3.UP)
		am.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		peca(parent, p + Vector3(-0.04, 0, -0.04), Vector3(p.x + 0.04, teto_y, p.z + 0.04), mat("peca_escura"))


## Luminária linear do teto (barra acesa com caixa escura).
static func linear(parent: Node3D, a: Vector3, b: Vector3, teto_y: float) -> void:
	var d := (b - a)
	var ao_x := absf(d.x) > absf(d.z)
	var lo := Vector3(minf(a.x, b.x), teto_y - 0.12, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), teto_y, maxf(a.z, b.z))
	if ao_x:
		lo.z -= 0.12
		hi.z += 0.12
	else:
		lo.x -= 0.12
		hi.x += 0.12
	peca(parent, lo, hi, mat("peca_escura"))
	var lo2 := lo + Vector3(0.0 if ao_x else 0.05, -0.02, 0.05 if ao_x else 0.0)
	var hi2 := Vector3(hi.x - (0.0 if ao_x else 0.05), lo.y, hi.z - (0.05 if ao_x else 0.0))
	peca(parent, lo2, hi2, mat("led"))


static func _perfil_parede(dir: Vector3, nrm: Vector3, pts: Array) -> PackedVector2Array:
	# O prisma usa lado = cima × frente; com frente = dir e cima = UP, o lado
	# é UP × dir. Se ele apontar para fora da sala, espelha o perfil.
	var lado := Vector3.UP.cross(dir)
	var sgn := 1.0 if lado.dot(nrm) > 0.0 else -1.0
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * sgn, p.y))
	return out


static func _gira(pts: PackedVector2Array, dir: Vector3, nrm: Vector3) -> PackedVector2Array:
	# Prisma vertical com cima = nrm: lado = nrm × UP. Ajusta para lado = dir.
	var lado := nrm.cross(Vector3.UP)
	var sgn := 1.0 if lado.dot(dir) > 0.0 else -1.0
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * sgn, p.y))
	return out


static func _min3(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))


static func _max3(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))


# ================================================================ estruturas (prancha v2)

## Caixa de carga militar (no lugar dos blocos verdes): metal escuro com
## quinas chanfradas, faixa laranja, tampa e alças. Colide do tamanho dela.
static func caixa_carga(parent: Node3D, centro_chao: Vector3, tam: Vector3) -> void:
	var c := 0.12
	var hx := tam.x * 0.5
	var hz := tam.z * 0.5
	var perfil := PackedVector2Array([Vector2(-hx + c, -hz), Vector2(hx - c, -hz), Vector2(hx, -hz + c), Vector2(hx, hz - c), Vector2(hx - c, hz), Vector2(-hx + c, hz), Vector2(-hx, hz - c), Vector2(-hx, -hz + c)])
	# Extrudado para cima com cima = +z: lado = z × y = -x; espelha x.
	var p2 := PackedVector2Array()
	for p in perfil:
		p2.append(Vector2(-p.x, p.y))
	var a := centro_chao
	prisma(parent, p2, a, a + Vector3(0, tam.y, 0), Vector3.BACK, mat("caixa"))
	# Faixa laranja no meio e tampa mais clara.
	var cinta := PackedVector2Array()
	for p in p2:
		cinta.append(p * Vector2((hx + 0.015) / hx, (hz + 0.015) / hz))
	prisma(parent, cinta, a + Vector3(0, tam.y * 0.55, 0), a + Vector3(0, tam.y * 0.55 + 0.1, 0), Vector3.BACK, mat("tinta_laranja"), false)
	var tampa := PackedVector2Array()
	for p in p2:
		tampa.append(p * Vector2((hx - 0.08) / hx, (hz - 0.08) / hz))
	prisma(parent, tampa, a + Vector3(0, tam.y, 0), a + Vector3(0, tam.y + 0.04, 0), Vector3.BACK, mat("peca"), false)
	# Alças nas faces menores.
	for s: float in [-1.0, 1.0]:
		if tam.x <= tam.z:
			peca(parent, a + Vector3(s * hx - 0.03, tam.y * 0.75, -0.2), a + Vector3(s * hx + 0.03, tam.y * 0.82, 0.2), mat("peca"))
		else:
			peca(parent, a + Vector3(-0.2, tam.y * 0.75, s * hz - 0.03), a + Vector3(0.2, tam.y * 0.82, s * hz + 0.03), mat("peca"))


## Bancada de trabalho (ref. laboratório): tampo com a quina da frente
## chanfrada, gaveteiro, monitor e cadeira. "frente" = onde fica a cadeira.
static func bancada(parent: Node3D, pos: Vector3, frente: Vector3, largura: float, i: int) -> void:
	var fw := Vector3(frente.x, 0, frente.z).normalized()
	var side := Vector3.UP.cross(fw)
	var a := pos - side * largura * 0.5
	var b := pos + side * largura * 0.5
	# Perfil de lado (x+ = para trás): tampo grosso com a frente chanfrada.
	var tampo := PackedVector2Array([Vector2(-0.45, 0.82), Vector2(0.45, 0.82), Vector2(0.45, 0.95), Vector2(-0.35, 0.95), Vector2(-0.45, 0.9)])
	prisma(parent, tampo, a, b, Vector3.UP, mat("peca"), false)
	# Base fechada (painel de fundo) e gaveteiro de um lado: colide.
	var base := PackedVector2Array([Vector2(0.1, 0.0), Vector2(0.45, 0.0), Vector2(0.45, 0.82), Vector2(0.1, 0.82)])
	prisma(parent, base, a, b, Vector3.UP, mat("peca_escura"))
	var g0 := b - side * 0.6
	prisma(parent, PackedVector2Array([Vector2(-0.4, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.82), Vector2(-0.4, 0.82)]), g0, b, Vector3.UP, mat("peca_escura"))
	# Friso de LED na frente do tampo.
	prisma(parent, PackedVector2Array([Vector2(-0.46, 0.86), Vector2(-0.44, 0.86), Vector2(-0.44, 0.89), Vector2(-0.46, 0.89)]), a, b, Vector3.UP, mat("led_fraco"), false)
	# Monitor.
	var mc: Vector3 = pos + fw * 0.05 - side * largura * 0.12 + Vector3(0, 1.3, 0)
	var mo := Look.piece(parent, Look.box(Vector3(0.95, 0.58, 0.05)), mat("peca_escura"), mc)
	mo.look_at_from_position(mc, mc + fw, Vector3.UP)
	var q := QuadMesh.new()
	q.size = Vector2(0.88, 0.5)
	var t := Look.piece(parent, q, tela_mat(i), mc + fw * 0.03)
	t.look_at_from_position(mc + fw * 0.03, mc - fw, Vector3.UP)
	peca(parent, mc - Vector3(0.03, 0.4, 0.03), mc + Vector3(0.03, -0.25, 0.03), mat("peca"))
	cadeira(parent, pos + fw * 0.75 - side * largura * 0.12, -fw)


## Cadeira de escritório simples (só desenho).
static func cadeira(parent: Node3D, pos: Vector3, olha: Vector3) -> void:
	var fw := olha.normalized()
	var m := mat("peca_escura")
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 0.45
	Look.piece(parent, cyl, mat("peca"), pos + Vector3(0, 0.25, 0))
	var pe := CylinderMesh.new()
	pe.top_radius = 0.3
	pe.bottom_radius = 0.32
	pe.height = 0.05
	pe.radial_segments = 5
	Look.piece(parent, pe, mat("peca"), pos + Vector3(0, 0.04, 0))
	var assento := Look.piece(parent, Look.box(Vector3(0.5, 0.1, 0.5)), m, pos + Vector3(0, 0.52, 0))
	assento.look_at_from_position(assento.position, assento.position + fw, Vector3.UP)
	var cp: Vector3 = pos - fw * 0.24 + Vector3(0, 0.9, 0)
	var costas := Look.piece(parent, Look.box(Vector3(0.46, 0.65, 0.08)), m, cp)
	costas.look_at_from_position(cp, cp + fw, Vector3.UP)
	costas.rotate_object_local(Vector3.RIGHT, -0.15)


## Armário alto de parede com o fundo inclinado e luz embaixo (ref. lab).
## o/dir/nrm: parede (ver ponto()); u0..u1 ao longo; y0 = fundo.
static func armario_parede(parent: Node3D, o: Vector3, dir: Vector3, nrm: Vector3, u0: float, u1: float, y0: float) -> void:
	var a := ponto(o, dir, nrm, u0, 0, 0)
	var b := ponto(o, dir, nrm, u1, 0, 0)
	prisma(parent, _perfil_parede(dir, nrm, [Vector2(0, y0 - 0.25), Vector2(0.25, y0), Vector2(0.55, y0), Vector2(0.55, y0 + 1.1), Vector2(0.45, y0 + 1.2), Vector2(0, y0 + 1.2)]), a, b, Vector3.UP, mat("caixa_clara"))
	# Divisão das portas e luz embaixo.
	var meio := (u0 + u1) * 0.5
	peca(parent, _min3(ponto(o, dir, nrm, meio - 0.01, 0.55, y0 + 0.05), ponto(o, dir, nrm, meio + 0.01, 0.56, y0 + 1.1)), _max3(ponto(o, dir, nrm, meio - 0.01, 0.55, y0 + 0.05), ponto(o, dir, nrm, meio + 0.01, 0.56, y0 + 1.1)), mat("peca_escura"))
	prisma(parent, _perfil_parede(dir, nrm, [Vector2(0.27, y0 - 0.01), Vector2(0.5, y0 - 0.01), Vector2(0.5, y0), Vector2(0.27, y0)]), a, b, Vector3.UP, mat("led"), false)


## Tanque de gás em pé (hangar), com anéis e válvula.
static func tanque(parent: Node3D, pos: Vector3, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position.y = h * 0.5
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.8
	cyl.bottom_radius = r
	cyl.height = h
	cyl.radial_segments = 20
	Look.piece(body, cyl, mat("caixa_clara"), Vector3(0, h * 0.5, 0))
	for y: float in [0.25, h * 0.5, h - 0.4]:
		var an := CylinderMesh.new()
		an.top_radius = r + 0.03
		an.bottom_radius = r + 0.03
		an.height = 0.1
		an.radial_segments = 20
		Look.piece(body, an, mat("tinta_laranja") if y == h * 0.5 else mat("peca_escura"), Vector3(0, y, 0))
	peca(body, Vector3(-0.06, h, -0.06), Vector3(0.06, h + 0.25, 0.06), mat("peca"))


## Estante industrial com caixas (depósito): colunas, prateleiras e caixas.
static func estante(parent: Node3D, pos: Vector3, frente: Vector3, largura: float, h: float, i: int) -> void:
	var fw := Vector3(frente.x, 0, frente.z).normalized()
	var side := Vector3.UP.cross(fw)
	var prof := 0.9
	var lo := pos - side * largura * 0.5 - fw * prof * 0.5
	# Colisão única do volume inteiro (é alta: a câmera desvia).
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(largura, h, prof) if absf(side.x) > 0.5 else Vector3(prof, h, largura)
	cs.shape = bs
	cs.position = pos + Vector3(0, h * 0.5, 0)
	body.add_child(cs)
	parent.add_child(body)
	for k in [0.0, 1.0]:
		for f in [0.0, 1.0]:
			var cp: Vector3 = lo + side * (largura * k) + fw * (prof * f)
			peca(parent, cp + Vector3(-0.05, 0, -0.05), cp + Vector3(0.05, h, 0.05), mat("tinta_laranja"))
	var niveis := int(h / 1.2)
	for n in niveis + 1:
		var y := 0.15 + n * (h - 0.2) / niveis
		peca(parent, _min3(lo + Vector3(0, y, 0), lo + side * largura + fw * prof + Vector3(0, y + 0.06, 0)), _max3(lo + Vector3(0, y, 0), lo + side * largura + fw * prof + Vector3(0, y + 0.06, 0)), mat("peca"))
		if n == niveis:
			break
		var x := 0.15
		var j := 0
		while x < largura - 0.6:
			var w := 0.5 + 0.35 * float((i + n * 3 + j) % 3)
			if x + w > largura - 0.1:
				break
			var ch := 0.45 + 0.15 * float((i + j + n) % 2)
			var c0: Vector3 = lo + side * x + fw * 0.12 + Vector3(0, y + 0.06, 0)
			var c1: Vector3 = lo + side * (x + w) + fw * (prof - 0.12) + Vector3(0, y + 0.06 + ch, 0)
			peca(parent, _min3(c0, c1), _max3(c0, c1), mat("caixa") if (i + j + n) % 3 != 0 else mat("caixa_clara"))
			x += w + 0.1
			j += 1


## Treliça do teto para as salas de parede inclinada: viga reta com mãos
## francesas diagonais que encostam no começo da parte inclinada.
static func trelica(parent: Node3D, a: Vector3, b: Vector3, h: float, d: float) -> void:
	# a, b: pontos no chão nas faces das paredes opostas (viga entre eles).
	var dir := (b - a).normalized()
	var y := h - 0.9
	var pa := a + dir * d + Vector3(0, y, 0)
	var pb := b - dir * d + Vector3(0, y, 0)
	var perfil := PackedVector2Array([Vector2(-0.14, -0.22), Vector2(0.14, -0.22), Vector2(0.14, 0.22), Vector2(-0.14, 0.22)])
	prisma(parent, perfil, pa, pb, Vector3.UP, mat("peca_escura"))
	for s in [[a, dir], [b, -dir]]:
		var base: Vector3 = s[0]
		var dd: Vector3 = s[1]
		var p0: Vector3 = base + dd * 0.35 + Vector3(0, h - 2.6, 0)
		var p1: Vector3 = base + dd * (d + 1.4) + Vector3(0, y - 0.1, 0)
		prisma(parent, PackedVector2Array([Vector2(-0.1, -0.1), Vector2(0.1, -0.1), Vector2(0.1, 0.1), Vector2(-0.1, 0.1)]), p0, p1, Vector3.UP, mat("peca"), false)
		# Luz embutida na viga.
	peca(parent, _min3(pa + Vector3(0, -0.23, 0) + Vector3.UP.cross(dir) * 0.04, pb + Vector3(0, -0.22, 0) - Vector3.UP.cross(dir) * 0.04), _max3(pa + Vector3(0, -0.23, 0) + Vector3.UP.cross(dir) * 0.04, pb + Vector3(0, -0.22, 0) - Vector3.UP.cross(dir) * 0.04), mat("led_fraco"))


## Marcação de pouso de drones no piso (círculo e "H" amarelos).
static func heliponto(parent: Node3D, c: Vector3, r: float) -> void:
	var n := 40
	for k in n:
		var a0 := TAU * k / n
		var p := c + Vector3(cos(a0), 0, sin(a0)) * r + Vector3(0, 0.004, 0)
		var seg := Look.piece(parent, Look.box(Vector3(TAU * r / n + 0.02, 0.008, 0.22)), mat("tinta_amarela"), p)
		seg.rotation.y = -a0 + PI * 0.5
	for e in [[Vector3(-1.1, 0, -1.4), Vector3(-0.75, 0.008, 1.4)], [Vector3(0.75, 0, -1.4), Vector3(1.1, 0.008, 1.4)], [Vector3(-0.75, 0, -0.18), Vector3(0.75, 0.008, 0.18)]]:
		peca(parent, c + e[0] + Vector3(0, 0.004, 0), c + e[1] + Vector3(0, 0.004, 0), mat("tinta_amarela"))


## Ponte rolante do hangar: dois trilhos nas paredes compridas e a viga
## móvel atravessada, com o carrinho e o gancho.
static func ponte_rolante(parent: Node3D, r: Rect2, h: float) -> void:
	var y := h - 1.9
	for z: float in [r.position.y + 0.9, r.end.y - 0.9]:
		peca(parent, Vector3(r.position.x + 1.0, y, z - 0.18), Vector3(r.end.x - 1.0, y + 0.35, z + 0.18), mat("tinta_amarela"))
	var x := r.get_center().x + 2.0
	peca(parent, Vector3(x - 0.3, y + 0.35, r.position.y + 0.75), Vector3(x + 0.3, y + 0.85, r.end.y - 0.75), mat("tinta_amarela"))
	peca(parent, Vector3(x - 0.45, y + 0.0, -0.5 + r.get_center().y), Vector3(x + 0.45, y + 0.35, 0.5 + r.get_center().y), mat("peca_escura"))
	peca(parent, Vector3(x - 0.02, y - 1.8, r.get_center().y - 0.02), Vector3(x + 0.02, y, r.get_center().y + 0.02), mat("peca"))
	peca(parent, Vector3(x - 0.18, y - 2.0, r.get_center().y - 0.08), Vector3(x + 0.18, y - 1.8, r.get_center().y + 0.08), mat("tinta_laranja"))
