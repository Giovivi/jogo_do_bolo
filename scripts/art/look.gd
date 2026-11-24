class_name Look
extends RefCounted
## Materiais com cel shading e contorno de HQ. As fotos de superfície vêm do
## ambientCG (CC0, ver assets/textures/CREDITS.md) e passam pelos mesmos shaders.

const SURFACE := preload("res://shaders/toon_surface.gdshader")
const BRICK := preload("res://shaders/toon_brick.gdshader")
const TILES := preload("res://shaders/toon_tiles.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const PAPER := preload("res://shaders/map_paper.gdshader")
const TEX_PATH := "res://assets/textures/%s/%s_%s.jpg"


## Parâmetros de textura para os shaders toon (surface, brick, tiles).
## size = metros cobertos por uma repetição; tint multiplica a cor da foto.
static func tex(id: String, size: Vector2, tint: Color = Color.WHITE, extra: Dictionary = {}) -> Dictionary:
	var d := {
		"albedo_tex": load(TEX_PATH % [id, id, "color"]),
		"normal_tex": load(TEX_PATH % [id, id, "normal"]),
		"tex_amount": 1.0,
		"tex_size": size,
		"tex_tint": tint,
		# Foto inteira (realista): contraste e relevo cheios.
		"tex_contrast": 1.0,
		"normal_strength": 1.0,
	}
	d.merge(extra, true)
	return d


## Põe a foto num StandardMaterial3D (fase e paredes que somem perto do herói):
## projeção pelo mundo e luz em faixas. albedo_color continua sendo a cor
## (com alfa) usada para o esmaecimento das paredes.
static func texture_std(mat: StandardMaterial3D, id: String, size: float, tint: Color = Color.WHITE, height: float = 0.0) -> StandardMaterial3D:
	mat.albedo_texture = load(TEX_PATH % [id, id, "color"])
	mat.normal_enabled = true
	mat.normal_texture = load(TEX_PATH % [id, id, "normal"])
	mat.normal_scale = 1.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 8.0
	# Fotos 2:1 (tijolo) passam a altura em "height".
	var hgt := size if height <= 0.0 else height
	mat.uv1_scale = Vector3(1.0 / size, 1.0 / hgt, 1.0 / size)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.albedo_color = Color(tint.r, tint.g, tint.b, mat.albedo_color.a)
	return mat


static func surface(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("base_color", color)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	if opts.get("outline", 0.0) > 0.0:
		m.next_pass = outline(opts["outline"])
	return m


## Madeira de tábuas (Planks023A). A cor tinge a foto (referência: marrom padrão).
static func wood(color: Color = Color(0.42, 0.29, 0.19), outline_width: float = 0.03) -> ShaderMaterial:
	var tint := Color(color.r / 0.42, color.g / 0.29, color.b / 0.19) * 0.95
	return surface(color, tex("Planks023A", Vector2(1.5, 1.5), tint, {"outline": outline_width}))


static func foliage(color: Color) -> ShaderMaterial:
	return surface(color, {"variation": 0.3, "noise_scale": 3.0, "outline": 0.05})


static func glow(color: Color, energy: float = 2.5) -> ShaderMaterial:
	return surface(color, {"variation": 0.05, "emission_color": color, "emission_energy": energy})


## Tijolo sem musgo. Passe a foto com Look.tex(...) nas opções, ou
## "tex_amount": 0.0 para o tijolo procedural.
static func brick(opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BRICK
	var all := opts.duplicate()
	# Escola seca e arenosa: sem musgo nem hera nas paredes.
	all["moss_amount"] = 0.0
	opts = all
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	return m


static func tiles(opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TILES
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	return m


static func paper() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAPER
	return m


static func outline(width: float = 0.03) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OUTLINE
	m.set_shader_parameter("width", width)
	return m


## Peça visual simples (sem colisão).
static func piece(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Esfera facetada (low poly).
static func blob(radius: float, height: float = -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 if height < 0.0 else height
	s.radial_segments = 7
	s.rings = 4
	return s


static func cylinder(top: float, bottom: float, height: float, sides: int = 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


## Árvore low poly: tronco torto e copa de blocos facetados.
static func tree(parent: Node3D, pos: Vector3, scale: float = 1.0, seed: int = 0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var t := Node3D.new()
	t.position = pos
	parent.add_child(t)
	var bark := surface(Color(0.27, 0.2, 0.14), {"variation": 0.25, "noise_scale": 6.0, "outline": 0.04})
	piece(t, cylinder(0.22 * scale, 0.38 * scale, 3.2 * scale), bark, Vector3(0, 1.6 * scale, 0), Vector3(0, 0, rng.randf_range(-6, 6)))
	piece(t, cylinder(0.08 * scale, 0.16 * scale, 1.6 * scale), bark, Vector3(0.5 * scale, 2.9 * scale, 0), Vector3(0, 0, -40))
	var greens := [Color(0.24, 0.36, 0.18), Color(0.3, 0.44, 0.2), Color(0.2, 0.3, 0.16)]
	for i in 6:
		var r := rng.randf_range(0.9, 1.5) * scale
		var off := Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(3.4, 4.8), rng.randf_range(-1.0, 1.0)) * scale
		piece(t, blob(r, r * 1.6), foliage(greens[i % 3]), off, Vector3(0, rng.randf_range(0, 90), 0))
	# O tronco é sólido: ninguém atravessa árvore.
	_solid_cylinder(t, Vector3.ZERO, 0.4 * scale, 3.0 * scale)
	return t


static func bush(parent: Node3D, pos: Vector3, size: float, seed: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var greens := [Color(0.26, 0.38, 0.19), Color(0.36, 0.48, 0.22)]
	for i in 3:
		var r := size * rng.randf_range(0.35, 0.6)
		var off := Vector3(rng.randf_range(-0.5, 0.5) * size, r * 0.6, rng.randf_range(-0.4, 0.4) * size)
		piece(parent, blob(r, r * 1.4), foliage(greens[i % 2]), pos + off)
	# A moita também é sólida.
	_solid_cylinder(parent, pos, 0.42 * size, 0.9 * size)


## Cilindro de colisão (camada do mundo) com a base em `base`.
static func _solid_cylinder(parent: Node3D, base: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1  # Game.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	body.position = base + Vector3(0, height * 0.5, 0)
	parent.add_child(body)
