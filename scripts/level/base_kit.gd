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
