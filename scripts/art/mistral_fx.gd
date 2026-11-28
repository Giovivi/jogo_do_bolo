class_name MistralFX
extends FenixFX
## Efeitos da Mistral (documento "Mistral, a senhora dos céus" da Vivi).
## Três linguagens que não se misturam no kit normal: eletricidade (raios
## ramificados, núcleo branco-azulado, clarões curtos), vento (espirais
## translúcidas, poeira e folhas) e, só na suprema, gelo (cristais
## facetados, névoa fria, rachaduras no chão e fragmentos luminosos).
## Paleta: azul-marinho #12243C, oceano #247D9B, turquesa #65DDEB,
## branco-gelo #DDF8FF e dourado #E9B85B.

const NAVY := Color(0.071, 0.141, 0.235)      # #12243C
const OCEAN := Color(0.141, 0.49, 0.608)      # #247D9B
const TURQ := Color(0.396, 0.867, 0.922)      # #65DDEB
const ICE := Color(0.867, 0.973, 1.0)         # #DDF8FF
const GOLDEN := Color(0.914, 0.722, 0.357)    # #E9B85B
const ELECTRIC := Color(0.55, 0.85, 1.0)

const ELECTRIC_SPARK_RAMP := [
	[0.0, Color(1.0, 1.0, 1.0, 1.0)],
	[0.35, Color(0.6, 0.92, 1.0, 0.95)],
	[1.0, Color(0.15, 0.45, 1.0, 0.0)],
]
const MIST_RAMP := [
	[0.0, Color(0.85, 0.95, 1.0, 0.0)],
	[0.25, Color(0.8, 0.93, 1.0, 0.16)],
	[0.7, Color(0.6, 0.82, 0.95, 0.1)],
	[1.0, Color(0.5, 0.7, 0.9, 0.0)],
]
const SHARD_RAMP := [
	[0.0, Color(1.0, 1.0, 1.0, 1.0)],
	[0.4, Color(0.7, 0.95, 1.0, 0.9)],
	[1.0, Color(0.3, 0.75, 0.95, 0.0)],
]

## Funil do furacão: faixas de vento que correm em volta e sobem.
const FUNNEL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.4, 0.87, 0.92, 1.0);
uniform float speed = 1.4;
uniform float alpha = 1.0;
uniform float bands = 3.0;
uniform float seed = 0.0;
void fragment() {
	vec2 uv = UV;
	float n = texture(noise_tex, vec2(uv.x * bands - TIME * speed + uv.y * 0.9 + seed, uv.y * 0.55 - TIME * 0.35)).r;
	float n2 = texture(noise_tex, vec2(uv.x * bands * 2.0 - TIME * speed * 1.6 + seed * 1.7, uv.y * 1.3 - TIME * 0.6)).r;
	float streak = smoothstep(0.5, 0.78, n) + 0.55 * smoothstep(0.6, 0.85, n2);
	float fade = smoothstep(0.0, 0.18, uv.y) * (1.0 - smoothstep(0.72, 1.0, uv.y));
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = tint.rgb * (0.9 + streak * 0.8);
	ALPHA = clamp(tint.a * fade * (streak * 0.75 + rim * 0.35 + 0.04) * alpha, 0.0, 1.0);
}
"""

## Onda de vento da Investida de Vendaval: faixas correndo para fora.
const GUST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.86, 0.97, 1.0, 1.0);
uniform float alpha = 1.0;
uniform float seed = 0.0;
void fragment() {
	vec2 uv = UV;
	float n = texture(noise_tex, vec2(uv.x * 0.6 + seed, uv.y * 4.0 + seed * 0.3)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 1.2 + seed * 2.0, uv.y * 9.0)).r;
	float streak = smoothstep(0.55, 0.7, n) * 0.8 + smoothstep(0.6, 0.72, n2) * 0.6;
	float edge = smoothstep(0.0, 0.25, uv.x) * (1.0 - smoothstep(0.75, 1.0, uv.x));
	float vfade = smoothstep(0.0, 0.2, uv.y) * (1.0 - smoothstep(0.55, 1.0, uv.y));
	ALBEDO = tint.rgb * (0.8 + streak);
	ALPHA = clamp(tint.a * edge * vfade * (0.05 + streak * 0.7) * alpha, 0.0, 1.0);
}
"""

## Gelo no chão: preenchimento claro (mistura normal, não soma luz, para não
## clarear a sala toda), rachaduras e a borda brilhante que avança.
const FROST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D crack_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 center = vec3(0.0);
uniform float front = 0.0;
uniform float radius = 12.0;
uniform float alpha = 1.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 d = wpos.xz - center.xz;
	float r = length(d);
	float wob = (texture(noise_tex, wpos.xz * 0.08).r - 0.5) * 1.4;
	float inside = 1.0 - smoothstep(front - 0.4, front + 0.2, r + wob);
	float cracks = texture(crack_tex, wpos.xz * 0.16).r;
	float fine = texture(crack_tex, wpos.xz * 0.47 + vec2(3.1, 7.7)).r;
	float cloud = texture(noise_tex, wpos.xz * 0.22).r;
	float ring = (1.0 - smoothstep(0.0, 0.9, abs(r + wob - front))) * step(r, radius + 0.5);
	float circles = smoothstep(0.75, 1.0, sin((r - front) * 2.4) * 0.5 + 0.5) * 0.25;
	float outer = 1.0 - smoothstep(radius - 0.8, radius + 0.3, r);
	vec3 frost = mix(vec3(0.32, 0.62, 0.84), vec3(0.7, 0.9, 1.0), cloud);
	frost = mix(frost, vec3(1.0), clamp(cracks * 0.8 + fine * 0.3, 0.0, 1.0));
	frost = mix(frost, vec3(0.6, 0.95, 1.0), ring);
	ALBEDO = frost * (1.0 + ring * 0.6);
	float a = inside * (0.1 + cloud * 0.1 + cracks * 0.42 + fine * 0.1 + circles * 0.6) + ring * 0.35;
	ALPHA = clamp(a * outer * alpha, 0.0, 0.92);
}
"""

## Cristal de gelo facetado: translúcido, borda turquesa e brilho interno.
const ICE_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.78, 0.94, 1.0, 0.78);
uniform float glow = 0.6;
uniform float alpha = 1.0;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float h = clamp(UV.y, 0.0, 1.0);
	ALBEDO = mix(vec3(0.3, 0.62, 0.8), tint.rgb, 0.45 + 0.55 * h);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = vec3(0.4, 0.86, 0.95) * (fres * 1.6 + h * 0.35) * glow + vec3(0.85, 0.97, 1.0) * pow(h, 6.0) * glow * 1.2;
	ALPHA = clamp(tint.a * (0.55 + fres * 0.45) * alpha, 0.0, 1.0);
}
"""

static var _line_tex: ImageTexture
static var _noise_tex: NoiseTexture2D
static var _crack_tex: NoiseTexture2D
static var _funnel_shader: Shader
static var _gust_shader: Shader
static var _frost_shader: Shader
static var _ice_shader: Shader
static var _crystal_mesh: ArrayMesh
static var _shard_mesh: ArrayMesh


static func _new_fx(at: Vector3, life_s: float) -> MistralFX:
	var fx := MistralFX.new()
	fx.life = life_s
	var root: Node = Game.world_root if Game.world_root != null else Engine.get_main_loop().root
	root.add_child(fx)
	fx.global_position = at
	return fx


static func _cam_pos() -> Vector3:
	var tree := Engine.get_main_loop() as SceneTree
	var cam := tree.root.get_viewport().get_camera_3d() if tree != null else null
	if cam != null:
		return cam.global_position
	return Vector3(0, 20, 20)


# ================================================================ texturas

## Faixa de luz: forte no meio, apagando nas bordas (largura do raio).
static func _line_texture() -> ImageTexture:
	if _line_tex != null:
		return _line_tex
	var img := Image.create(4, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var v := absf((float(y) + 0.5) / 64.0 * 2.0 - 1.0)
		var a := pow(clampf(1.0 - v, 0.0, 1.0), 1.6)
		for x in 4:
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_line_tex = ImageTexture.create_from_image(img)
	return _line_tex


static func _noise() -> NoiseTexture2D:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.025
		n.fractal_octaves = 4
		var t := NoiseTexture2D.new()
		t.noise = n
		t.seamless = true
		t.width = 256
		t.height = 256
		_noise_tex = t
	return _noise_tex


## Rachaduras: bordas das células (Voronoi), finas e claras.
static func _cracks() -> NoiseTexture2D:
	if _crack_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.02
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.cellular_jitter = 1.0
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		var t := NoiseTexture2D.new()
		t.noise = n
		t.seamless = true
		t.width = 256
		t.height = 256
		t.generate_mipmaps = true
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.03, 0.09, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1), Color(0.75, 0.75, 0.75), Color(0, 0, 0), Color(0, 0, 0)])
		t.color_ramp = g
		_crack_tex = t
	return _crack_tex


static func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s


static func _line_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _line_texture()
	m.disable_receive_shadows = true
	return m


## Material de poeira (mistura normal: poeira escurece de leve, não brilha).
static func _dust_material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


# ================================================================ raios

## Pontos de um raio quebrado entre `a` e `b` (mais torto no meio).
static func bolt_path(a: Vector3, b: Vector3, jag: float, seg_len: float = 0.32) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var d := b - a
	var length := d.length()
	var n := clampi(int(length / seg_len), 3, 48)
	var dir := d / maxf(length, 0.001)
	var s1 := dir.cross(Vector3.UP)
	if s1.length() < 0.1:
		s1 = dir.cross(Vector3.RIGHT)
	s1 = s1.normalized()
	var s2 := dir.cross(s1).normalized()
	var off := Vector2.ZERO
	for i in n + 1:
		var t := float(i) / float(n)
		if i == 0 or i == n:
			pts.append(a.lerp(b, t))
			continue
		off = off * 0.45 + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * jag
		var env := sin(t * PI)
		pts.append(a.lerp(b, t) + (s1 * off.x + s2 * off.y) * env)
	return pts


## Fita virada para a câmera seguindo `pts` (largura `w`, cor por vértice).
static func _ribbon(im: ImmediateMesh, pts: PackedVector3Array, w: float, c: Color, cam: Vector3, taper := true) -> void:
	if pts.size() < 2:
		return
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var seg := p1 - p0
		var view0 := (cam - p0).normalized()
		var side := seg.cross(view0).normalized() * w * 0.5
		var k0 := 1.0
		var k1 := 1.0
		if taper:
			k0 = lerpf(1.0, 0.35, float(i) / float(n - 1))
			k1 = lerpf(1.0, 0.35, float(i + 1) / float(n - 1))
		im.surface_set_color(c)
		im.surface_set_uv(Vector2(0, 0))
		im.surface_add_vertex(p0 - side * k0)
		im.surface_set_uv(Vector2(0, 1))
		im.surface_add_vertex(p0 + side * k0)
		im.surface_set_uv(Vector2(1, 1))
		im.surface_add_vertex(p1 + side * k1)
		im.surface_set_uv(Vector2(0, 0))
		im.surface_add_vertex(p0 - side * k0)
		im.surface_set_uv(Vector2(1, 1))
		im.surface_add_vertex(p1 + side * k1)
		im.surface_set_uv(Vector2(1, 0))
		im.surface_add_vertex(p1 - side * k1)


## Desenha um raio em 3 camadas (halo oceano, corpo turquesa, núcleo branco).
static func _draw_bolt(im: ImmediateMesh, pts: PackedVector3Array, width: float, a: float, cam: Vector3) -> void:
	_ribbon(im, pts, width * 4.2, Color(OCEAN.r, OCEAN.g, OCEAN.b, 0.32 * a), cam, false)
	_ribbon(im, pts, width * 1.7, Color(TURQ.r, TURQ.g, TURQ.b, 0.85 * a), cam)
	_ribbon(im, pts, width * 0.6, Color(ICE.r, ICE.g, ICE.b, 1.0 * a), cam)


## Ramificações saindo de pontos do raio principal.
static func _branches(main: PackedVector3Array, count: int, reach: float, jag: float) -> Array:
	var out: Array = []
	for i in count:
		var k := randi_range(1, maxi(1, main.size() - 3))
		var p := main[k]
		var fwd := (main[mini(k + 1, main.size() - 1)] - p).normalized()
		var rnd := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)).normalized()
		var dir := (fwd * 0.6 + rnd * 0.8).normalized()
		out.append(bolt_path(p, p + dir * reach * randf_range(0.5, 1.0), jag, 0.18))
	return out


## Descarga Relampejante: raio da mão ao alvo, tremendo por ~0,2 s, com
## ramificações, clarão no impacto e luz azul curta. `strong` = Carga
## Atmosférica (mais grosso, mais ramos, clarão maior).
static func bolt(from: Vector3, to: Vector3, strong: bool = false, hit: bool = true, secondary: bool = false) -> MistralFX:
	var fx := _new_fx(to, 0.4)
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _line_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	fx.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var length := from.distance_to(to)
	var width := 0.085 if not secondary else 0.06
	if strong:
		width *= 1.45
	var jag := clampf(length * 0.06, 0.12, 0.42)
	var nb := (3 if strong else 2) if not secondary else 1
	var life_bolt := 0.2 if not strong else 0.26
	var state := {"clock": 0.0, "pts": PackedVector3Array(), "br": []}
	var regen := func() -> void:
		state["pts"] = bolt_path(from, to, jag)
		state["br"] = _branches(state["pts"], nb, minf(length * 0.35, 1.8), jag * 0.6)
	regen.call()
	# Clarão na mão (curto) e no impacto.
	fx._flash(from, 0.5 if not secondary else 0.0, 0.07)
	if hit:
		fx._flash(to, 1.6 if strong else (1.1 if not secondary else 0.8), 0.14)
		fx._spark_burst_e(to, (from - to).normalized(), 10 if strong else 6, 6.5, 70.0)
		var l := OmniLight3D.new()
		l.light_color = ELECTRIC
		l.light_energy = 3.0 if strong else 2.0
		l.omni_range = 4.5
		l.top_level = true
		fx.add_child(l)
		l.global_position = to + Vector3(0, 0.3, 0)
		fx.create_tween().tween_property(l, "light_energy", 0.0, 0.18)
	fx.on_tick = func(age: float, dt: float) -> void:
		state["clock"] = float(state["clock"]) + dt
		if float(state["clock"]) > 0.035:
			state["clock"] = 0.0
			regen.call()
		im.clear_surfaces()
		if age > life_bolt:
			return
		# Pisca: dois quadros fortes, um fraco, apagando no fim.
		var a := clampf(1.0 - age / life_bolt, 0.0, 1.0)
		a *= 0.55 + 0.45 * float(int(age * 60.0) % 3 != 2)
		var cam := _cam_pos()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_draw_bolt(im, state["pts"], width, a, cam)
		for b in state["br"]:
			_draw_bolt(im, b, width * 0.55, a * 0.85, cam)
		im.surface_end()
	return fx


## Estrela de clarão azul-branca (glow + estrela do jogo).
func _flash(at: Vector3, size: float, duration: float) -> void:
	if size <= 0.0:
		return
	var g := _glow_sprite(size * 1.3, Color(TURQ, 0.75))
	g.top_level = true
	add_child(g)
	g.global_position = at
	var tw := g.create_tween()
	tw.set_parallel(true)
	tw.tween_property(g, "scale", Vector3.ONE * 1.5, duration * 1.5)
	tw.tween_property(g.material_override, "albedo_color:a", 0.0, duration * 1.5)
	var s := Game.laser_flare(at, size, duration)
	if s != null:
		s.modulate = Color(0.75, 0.95, 1.0)


## Faíscas elétricas rápidas (pontas brancas, cauda azul).
func _spark_burst_e(at: Vector3, dir: Vector3, amount: int, speed: float, spread: float) -> GPUParticles3D:
	var p := _particles(amount, 0.3, 0.055, false, ELECTRIC_SPARK_RAMP)
	p.top_level = true
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = 0.08
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -6.0, 0)
	pm.damping_min = 3.0
	pm.damping_max = 6.0
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.1)])
	p.global_transform = Transform3D(_basis_up(dir if dir.length() > 0.01 else Vector3.UP), at)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	return p


static func sparks(at: Vector3, dir: Vector3, amount: int, speed := 5.0) -> void:
	var fx := _new_fx(at, 0.5)
	fx._spark_burst_e(at, dir, amount, speed, 80.0)


static func _basis_up(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


# ================================================================ Olho do Furacão (Q)

## Malha do funil: cone aberto (mais largo em cima) com uma torção.
static func _funnel_mesh(r0: float, r1: float, h: float, twist: float, rings := 10, segs := 28) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rings:
		for i in segs:
			var quad := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var u := float(c[0]) / float(segs)
				var v := float(c[1]) / float(rings)
				var r := lerpf(r0, r1, pow(v, 1.4))
				var ang := u * TAU + v * twist
				quad.append([Vector3(cos(ang) * r, v * h, sin(ang) * r), Vector2(u, v), Vector3(cos(ang), -0.3, sin(ang)).normalized()])
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(quad[k][2])
				st.set_uv(quad[k][1])
				st.add_vertex(quad[k][0])
	return st.commit()


## Furacão em `center`: funil de três camadas girando, anel de vento no
## chão marcando a área, poeira e folhas em espiral e raios curtos dentro.
## Vive `duration` s e se desfaz em 0,4 s. `big` = versão com Carga.
static func tornado(center: Vector3, radius: float, duration: float, big := false) -> MistralFX:
	var fx := _new_fx(center, duration + 0.5)
	var h := radius * 1.4
	if _funnel_shader == null:
		_funnel_shader = _shader(FUNNEL_SHADER)
	var layers: Array[MeshInstance3D] = []
	var defs := [
		# r0, r1, altura, torção, cor, velocidade, alfa
		[0.25, radius * 0.7, h * 0.9, 2.2, Color(ICE, 0.9), 2.6, 0.9],
		[0.45, radius * 0.9, h, 1.6, Color(TURQ, 0.8), 1.8, 0.75],
		[0.7, radius * 1.05, h * 1.05, 1.1, Color(OCEAN.lightened(0.15), 0.7), 1.2, 0.55],
	]
	var seed := randf() * 10.0
	for d in defs:
		var mi := MeshInstance3D.new()
		mi.mesh = _funnel_mesh(d[0], d[1], d[2], d[3])
		var m := ShaderMaterial.new()
		m.shader = _funnel_shader
		m.set_shader_parameter("noise_tex", _noise())
		m.set_shader_parameter("tint", d[4])
		m.set_shader_parameter("speed", d[5])
		m.set_shader_parameter("seed", seed)
		m.set_shader_parameter("alpha", 0.0)
		seed += 3.3
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("a", d[6])
		fx.add_child(mi)
		layers.append(mi)
	# Anel de vento no chão: espiral girando (soma luz fraca) e borda da área.
	var swirl := fx._swirl_disc(radius)
	var edge := fx._ground_ring(radius * 2.15, TURQ)
	(edge.material_override as StandardMaterial3D).albedo_color = Color(TURQ, 0.0)
	# Poeira e folhas girando em espiral (malhas próprias, animadas aqui).
	var debris := fx._debris(30 if not big else 44, radius)
	# Névoa clara na base.
	var mist := fx._particles(10, 1.2, 1.6, false, MIST_RAMP, true)
	var pm := mist.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = radius * 0.6
	pm.gravity = Vector3(0, 0.4, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	mist.position = Vector3(0, 0.3, 0)
	mist.emitting = true
	var l := OmniLight3D.new()
	l.light_color = TURQ
	l.light_energy = 0.0
	l.omni_range = radius * 2.2
	l.position = Vector3(0, 1.2, 0)
	fx.add_child(l)
	var state := {"zap": 0.3}
	fx.on_tick = func(age: float, dt: float) -> void:
		var grow := clampf(age / 0.3, 0.0, 1.0)
		grow = 1.0 - pow(1.0 - grow, 3.0)
		var out := clampf((age - duration) / 0.4, 0.0, 1.0)
		var a := grow * (1.0 - out)
		var spin := age * 5.5
		for i in layers.size():
			var mi := layers[i]
			mi.rotation.y = -spin * (1.0 + 0.35 * float(i))
			mi.scale = Vector3(lerpf(0.3, 1.0, grow) * (1.0 + out * 0.5), lerpf(0.2, 1.0, grow) * (1.0 + out * 0.3), lerpf(0.3, 1.0, grow) * (1.0 + out * 0.5))
			(mi.material_override as ShaderMaterial).set_shader_parameter("alpha", a * float(mi.get_meta("a")))
		swirl.rotation.y = -age * 3.0
		(swirl.material_override as ShaderMaterial).set_shader_parameter("alpha", a)
		(edge.material_override as StandardMaterial3D).albedo_color.a = 0.5 * a
		l.light_energy = 0.9 * a
		fx._tick_debris(debris, age, dt, radius, h, out)
		if out > 0.0:
			mist.emitting = false
		# Raios curtos dentro do funil (eletricidade + vento).
		state["zap"] = float(state["zap"]) - dt
		if float(state["zap"]) <= 0.0 and out <= 0.0 and age > 0.2:
			state["zap"] = randf_range(0.28, 0.55)
			var ang := randf() * TAU
			var top := fx.global_position + Vector3(cos(ang) * radius * 0.5, h * randf_range(0.6, 0.9), sin(ang) * radius * 0.5)
			var bot := fx.global_position + Vector3(cos(ang + 1.6) * radius * 0.3, randf_range(0.2, 0.8), sin(ang + 1.6) * radius * 0.3)
			bolt(top, bot, false, false, true)
	return fx


## Disco no chão com braços de espiral (vento rente ao chão).
func _swirl_disc(radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.6, radius * 2.6)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = _shader("""
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float alpha = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float arms = sin(a * 4.0 + r * 9.0) * 0.5 + 0.5;
	float n = texture(noise_tex, vec2(a * 0.3 + r * 0.6, r * 1.5)).r;
	float band = smoothstep(0.55, 0.95, arms * (0.6 + n * 0.8));
	float fade = (1.0 - smoothstep(0.55, 1.0, r)) * smoothstep(0.05, 0.25, r);
	ALBEDO = mix(vec3(0.4, 0.87, 0.92), vec3(0.87, 0.97, 1.0), n);
	ALPHA = clamp(band * fade * 0.55 * alpha, 0.0, 1.0);
}
""")
	m.set_shader_parameter("noise_tex", _noise())
	m.set_shader_parameter("alpha", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.07, 0)
	add_child(mi)
	return mi


## Pedaços de poeira, folhas e pedrinhas girando em volta do funil.
func _debris(count: int, radius: float) -> Array:
	var out: Array = []
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.36, 0.42, 0.22)
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.roughness = 0.8
	var leaf_mat2 := leaf_mat.duplicate() as StandardMaterial3D
	leaf_mat2.albedo_color = Color(0.55, 0.42, 0.22)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.32, 0.33, 0.36)
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.12, 0.07)
	var rock := BoxMesh.new()
	rock.size = Vector3(0.06, 0.05, 0.07)
	for i in count:
		var mi := MeshInstance3D.new()
		var kind := i % 3
		mi.mesh = rock if kind == 2 else leaf
		mi.material_override = rock_mat if kind == 2 else (leaf_mat if kind == 0 else leaf_mat2)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		out.append({"mi": mi, "ang": randf() * TAU, "t": randf(), "r": randf_range(0.5, 1.15), "spd": randf_range(0.6, 1.0), "spin": Vector3(randf(), randf(), randf()) * 9.0})
	return out


func _tick_debris(debris: Array, age: float, dt: float, radius: float, h: float, out: float) -> void:
	for d in debris:
		var mi: MeshInstance3D = d["mi"]
		var t: float = fposmod(float(d["t"]) + dt * 0.45 * float(d["spd"]), 1.0)
		d["t"] = t
		d["ang"] = float(d["ang"]) - dt * (7.5 - 3.0 * t) * float(d["spd"])
		var r: float = radius * float(d["r"]) * lerpf(0.35, 1.0, pow(t, 0.8)) * (1.0 + out * 2.0)
		var y := t * h * 0.95 * (1.0 - out * 0.5)
		mi.position = Vector3(cos(d["ang"]) * r, y + 0.05, sin(d["ang"]) * r)
		mi.rotation = d["spin"] * age
		var s := clampf(minf(age / 0.3, 1.0) * (1.0 - out) * (1.0 - smoothstep(0.85, 1.0, t)), 0.0, 1.0)
		mi.scale = Vector3.ONE * maxf(s, 0.001)


## Inimigo sendo puxado: rastro curto de vento indo para o centro.
static func pull_streak(from: Vector3, to: Vector3) -> void:
	var fx := _new_fx(from, 0.25)
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _line_material()
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var pts := PackedVector3Array()
	var side := (to - from).cross(Vector3.UP).normalized()
	for i in 8:
		var t := float(i) / 7.0
		pts.append(from.lerp(to, t * 0.7) + side * sin(t * PI) * 0.25 + Vector3(0, 0.9 + t * 0.2, 0))
	fx.on_tick = func(age: float, _dt: float) -> void:
		im.clear_surfaces()
		var a := clampf(1.0 - age / 0.25, 0.0, 1.0)
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_ribbon(im, pts, 0.09, Color(ICE.r, ICE.g, ICE.b, 0.5 * a), _cam_pos())
		im.surface_end()


# ================================================================ Investida de Vendaval (E)

## Faixa vertical em arco (parte de um anel) para as ondas de vento.
static func _arc_band(half: float, height: float, segs := 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var quad := []
		for c in [[i, 0], [i + 1, 0], [i + 1, 1], [i, 1]]:
			var u := float(c[0]) / float(segs)
			var ang := lerpf(-half, half, u)
			var v := float(c[1])
			# Curva para dentro em cima: a onda se inclina para a frente.
			var r := 1.0 + v * 0.12
			quad.append([Vector3(sin(ang) * r, v * height, -cos(ang) * r), Vector2(u, v)])
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	return st.commit()


## Rajada em cone: três ondas de vento que correm para fora, riscos de
## velocidade, poeira e folhas levantadas. `strong` = Carga Atmosférica.
static func gust(origin: Vector3, facing: Vector3, length: float, arc_degrees: float, strong := false) -> MistralFX:
	var fx := _new_fx(origin, 0.9)
	var flat := Vector3(facing.x, 0, facing.z).normalized()
	fx.global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP), origin)
	var half := deg_to_rad(arc_degrees) * 0.5
	if _gust_shader == null:
		_gust_shader = _shader(GUST_SHADER)
	var waves: Array[MeshInstance3D] = []
	var n_waves := 4 if strong else 3
	for i in n_waves:
		var mi := MeshInstance3D.new()
		mi.mesh = _arc_band(half, 1.0)
		var m := ShaderMaterial.new()
		m.shader = _gust_shader
		m.set_shader_parameter("noise_tex", _noise())
		m.set_shader_parameter("seed", randf() * 10.0)
		m.set_shader_parameter("tint", Color(ICE, 1.0) if i % 2 == 0 else Color(TURQ, 1.0))
		m.set_shader_parameter("alpha", 0.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		fx.add_child(mi)
		waves.append(mi)
	# Riscos de velocidade: linhas finas que disparam para fora dentro do cone.
	var im := ImmediateMesh.new()
	var lines := MeshInstance3D.new()
	lines.mesh = im
	lines.material_override = _line_material()
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(lines)
	var streaks: Array = []
	for i in (26 if strong else 18):
		streaks.append({"ang": randf_range(-half, half) * 0.95, "y": randf_range(0.15, 1.9), "delay": randf_range(0.0, 0.12), "len": randf_range(0.8, 1.8), "spd": randf_range(18.0, 26.0)})
	# Poeira e folhas levantadas, saindo para fora.
	var dust := fx._dust_burst(length, half, strong)
	# Clarão de ar comprimido na mão.
	fx._flash(origin + flat * 0.5 + Vector3(0, 1.1, 0), 0.9, 0.1)
	fx.on_tick = func(age: float, _dt: float) -> void:
		for i in waves.size():
			var mi := waves[i]
			var t := clampf((age - float(i) * 0.06) / 0.34, 0.0, 1.0)
			mi.visible = t > 0.0 and t < 1.0
			if not mi.visible:
				continue
			var e := 1.0 - pow(1.0 - t, 2.2)
			var r := lerpf(0.6, length, e)
			var hh := lerpf(0.7, 1.7, e) * (1.25 if strong else 1.0)
			mi.scale = Vector3(r, hh, r)
			mi.position.y = 0.05
			var a := sin(t * PI) * (1.0 if i == 0 else 0.75)
			(mi.material_override as ShaderMaterial).set_shader_parameter("alpha", a * (1.3 if strong else 1.0))
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var cam := fx.global_transform.affine_inverse() * _cam_pos()
		var any := false
		for s in streaks:
			var t: float = age - float(s["delay"])
			if t <= 0.0:
				continue
			var head: float = 0.5 + t * float(s["spd"])
			var tail: float = head - float(s["len"])
			if tail > length:
				continue
			head = minf(head, length + 0.5)
			var ang: float = s["ang"]
			var d := Vector3(sin(ang), 0, -cos(ang))
			var y: float = s["y"]
			var a := clampf(1.0 - t / 0.45, 0.0, 1.0)
			var pts := PackedVector3Array([d * maxf(tail, 0.4) + Vector3(0, y, 0), d * head + Vector3(0, y, 0)])
			_ribbon(im, pts, 0.05, Color(ICE.r, ICE.g, ICE.b, 0.7 * a), cam)
			any = true
		if not any:
			im.surface_add_vertex(Vector3.ZERO)
			im.surface_add_vertex(Vector3.ZERO)
			im.surface_add_vertex(Vector3.ZERO)
		im.surface_end()
		if age > 0.5:
			dust.emitting = false
	return fx


func _dust_burst(length: float, half: float, strong: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40 if strong else 28
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.85
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-10, -2, -12), Vector3(20, 8, 14))
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	q.material = _dust_material(_soft_texture())
	p.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.4, 0.05, 0.3)
	pm.direction = Vector3(0, 0.15, -1)
	pm.spread = rad_to_deg(half)
	pm.flatness = 0.85
	pm.initial_velocity_min = length * 1.2
	pm.initial_velocity_max = length * 2.2
	pm.damping_min = length * 1.6
	pm.damping_max = length * 2.6
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 1.4)])
	pm.color_ramp = _ramp([
		[0.0, Color(0.78, 0.82, 0.86, 0.0)],
		[0.15, Color(0.55, 0.6, 0.66, 0.16)],
		[1.0, Color(0.5, 0.56, 0.62, 0.0)],
	])
	p.process_material = pm
	p.position = Vector3(0, 0.25, -0.6)
	add_child(p)
	p.emitting = true
	return p


## Inimigo arremessado: rastro de vento atrás dele por um instante.
static func push_trail(enemy: Node3D, dir: Vector3) -> void:
	var fx := _new_fx(enemy.global_position, 0.45)
	fx.follow = enemy
	var p := fx._particles(10, 0.35, 0.5, false, [
		[0.0, Color(0.86, 0.97, 1.0, 0.35)],
		[1.0, Color(0.4, 0.87, 0.92, 0.0)],
	], true)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = -dir
	pm.spread = 25.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	p.position = Vector3(0, 0.9, 0)
	p.emitting = true
	fx.on_tick = func(age: float, _dt: float) -> void:
		if age > 0.3:
			p.emitting = false


# ================================================================ Geada Absoluta (R)

## Prisma hexagonal com ponta (cristal de gelo), base na origem, 1 m de altura.
static func _crystal() -> ArrayMesh:
	if _crystal_mesh != null:
		return _crystal_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	var body := 0.72
	var r := 0.16
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var b0 := Vector3(cos(a0) * r, -0.05, sin(a0) * r)
		var b1 := Vector3(cos(a1) * r, -0.05, sin(a1) * r)
		var t0 := Vector3(cos(a0) * r * 0.92, body, sin(a0) * r * 0.92)
		var t1 := Vector3(cos(a1) * r * 0.92, body, sin(a1) * r * 0.92)
		var tip := Vector3(0, 1.0, 0)
		var nm := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		for v in [[b0, 0.0], [t1, body], [b1, 0.0], [b0, 0.0], [t0, body], [t1, body]]:
			st.set_normal(nm)
			st.set_uv(Vector2(0, v[1]))
			st.add_vertex(v[0])
		var nt := (nm + Vector3(0, 0.6, 0)).normalized()
		for v in [[t0, body], [tip, 1.0], [t1, body]]:
			st.set_normal(nt)
			st.set_uv(Vector2(0, v[1]))
			st.add_vertex(v[0])
	_crystal_mesh = st.commit()
	return _crystal_mesh


static func _ice_material() -> ShaderMaterial:
	if _ice_shader == null:
		_ice_shader = _shader(ICE_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _ice_shader
	return m


## Tufo de cristais saindo do chão em `at` (escala `size`), que cresce rápido
## com um repique. Devolve o nó para quebrar depois (shatter_cluster).
static func crystal_cluster(at: Vector3, size: float, life_s: float, encase := false) -> MistralFX:
	var fx := _new_fx(at, life_s + 0.6)
	var mat := _ice_material()
	var count := 7 if encase else randi_range(3, 5)
	var pieces: Array = []
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _crystal()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var tilt := randf_range(0.25, 0.6) if i > 0 or encase else randf_range(0.0, 0.15)
		var rr := (0.38 if encase else 0.12) * size * (0.0 if (i == 0 and not encase) else 1.0)
		var h := size * (randf_range(1.6, 2.3) if encase else (1.4 if i == 0 else randf_range(0.6, 1.1)))
		var w := size * (randf_range(1.6, 2.2) if encase else randf_range(1.2, 1.8))
		var b := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, -tilt) if i > 0 or encase else Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, tilt)
		var final := Transform3D(b * Basis.from_scale(Vector3(w, h, w)), Vector3(cos(ang) * rr, 0, sin(ang) * rr))
		mi.transform = final
		mi.scale = Vector3(w, 0.01, w)
		fx.add_child(mi)
		pieces.append([mi, final, randf_range(0.0, 0.08)])
	fx.set_meta("pieces", pieces)
	fx.set_meta("mat", mat)
	# Névoa fria em volta e pó de gelo subindo.
	var mist := fx._particles(6, 1.0, 1.3, false, MIST_RAMP, true)
	(mist.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.6 * size
	mist.position = Vector3(0, 0.3, 0)
	mist.one_shot = true
	mist.explosiveness = 0.8
	mist.emitting = true
	fx._spark_burst_ice(at + Vector3(0, 0.3, 0), Vector3.UP, 8, 3.5)
	fx.on_tick = func(age: float, _dt: float) -> void:
		for p in pieces:
			if not is_instance_valid(p[0]):
				continue
			var mi: MeshInstance3D = p[0]
			var t := clampf((age - float(p[2])) / 0.14, 0.0, 1.0)
			# Cresce com repique (passa um pouco e volta).
			var k := 1.0 + sin(t * PI) * 0.18 if t < 1.0 else 1.0
			k *= t
			var f: Transform3D = p[1]
			mi.transform = Transform3D(f.basis * Basis.from_scale(Vector3(1.0, maxf(k, 0.01), 1.0)), f.origin)
		if age >= life_s and not fx.has_meta("shattered"):
			fx.shatter()
	return fx


## Quebra o tufo em fragmentos luminosos.
func shatter() -> void:
	if has_meta("shattered"):
		return
	set_meta("shattered", true)
	life = _age + 0.8
	var pieces: Array = get_meta("pieces", [])
	for p in pieces:
		if is_instance_valid(p[0]):
			(p[0] as Node).queue_free()
	pieces.clear()
	var at := global_position + Vector3(0, 0.8, 0)
	_shards(at, 22)
	_flash(at, 1.2, 0.18)
	_spark_burst_ice(at, Vector3.UP, 14, 6.0)


## Fragmentos de gelo voando (losangos brilhantes que caem e somem).
func _shards(at: Vector3, amount: int) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	if _shard_mesh == null:
		var bm := PrismMesh.new()
		bm.size = Vector3(0.07, 0.16, 0.05)
		_shard_mesh = ArrayMesh.new()
		_shard_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.get_mesh_arrays())
	p.draw_pass_1 = _shard_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p.material_override = m
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -12.0, 0)
	pm.angular_velocity_min = -720.0
	pm.angular_velocity_max = 720.0
	pm.particle_flag_rotate_y = true
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	pm.color_ramp = _ramp(SHARD_RAMP)
	p.process_material = pm
	p.top_level = true
	add_child(p)
	p.global_position = at
	p.emitting = true


func _spark_burst_ice(at: Vector3, dir: Vector3, amount: int, speed: float) -> void:
	var p := _particles(amount, 0.6, 0.06, false, SHARD_RAMP)
	p.top_level = true
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = 0.3
	pm.spread = 60.0
	pm.initial_velocity_min = speed * 0.3
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -1.5, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	p.global_transform = Transform3D(_basis_up(dir), at)
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true


## Preparação da Geada: névoa fria subindo em volta, pó de gelo em espiral
## e brilho no chão aos pés da Mistral (dura `duration` s).
static func frost_charge(hero: Node3D, duration: float) -> MistralFX:
	var fx := _new_fx(hero.global_position, duration + 0.6)
	fx.follow = hero
	var mist := fx._particles(18, 1.1, 1.4, false, MIST_RAMP, true)
	var pm := mist.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.4
	pm.emission_ring_inner_radius = 0.6
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.6, 0)
	mist.position = Vector3(0, 0.2, 0)
	mist.emitting = true
	var motes := fx._particles(36, 0.9, 0.08, false, SHARD_RAMP, false)
	var mm := motes.process_material as ParticleProcessMaterial
	mm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mm.emission_ring_axis = Vector3.UP
	mm.emission_ring_radius = 1.1
	mm.emission_ring_inner_radius = 0.9
	mm.emission_ring_height = 0.1
	mm.direction = Vector3.UP
	mm.spread = 5.0
	mm.initial_velocity_min = 1.8
	mm.initial_velocity_max = 2.8
	mm.gravity = Vector3.ZERO
	mm.tangential_accel_min = 4.0
	mm.tangential_accel_max = 6.0
	mm.radial_accel_min = -1.6
	mm.radial_accel_max = -1.0
	motes.emitting = true
	var ring := fx._ground_ring(1.0, ICE)
	var l := fx._light(ICE, 0.0)
	l.omni_range = 6.0
	fx.on_tick = func(age: float, _dt: float) -> void:
		var k := clampf(age / duration, 0.0, 1.0)
		ring.scale = Vector3.ONE * lerpf(1.0, 3.4, k)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.6 * k * clampf(1.0 - (age - duration) / 0.3, 0.0, 1.0)
		l.light_energy = 2.2 * k * clampf(1.0 - (age - duration) / 0.4, 0.0, 1.0)
		if age > duration:
			mist.emitting = false
			motes.emitting = false
	return fx


## Gelo se espalhando pelo chão a partir de `center` até `radius`, cortado
## pelas paredes (`outline`: pontos relativos ao centro, como a R do Feixe).
## A borda avança em `spread_time` s; o gelo fica `hold` s e derrete.
static func frost_floor(center: Vector3, radius: float, outline: PackedVector3Array, spread_time: float, hold: float) -> MistralFX:
	var fx := _new_fx(center, spread_time + hold + 1.2)
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		for v in [Vector3.ZERO, b, a]:
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	mi.mesh = st.commit()
	if _frost_shader == null:
		_frost_shader = _shader(FROST_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _frost_shader
	m.set_shader_parameter("crack_tex", _cracks())
	m.set_shader_parameter("noise_tex", _noise())
	m.set_shader_parameter("center", center)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("front", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.045, 0)
	fx.add_child(mi)
	# Névoa branca e azul rente ao chão, acompanhando a borda.
	var mist := fx._particles(30, 1.6, 1.8, false, MIST_RAMP, true)
	var pm := mist.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.0
	pm.emission_ring_inner_radius = 0.6
	pm.emission_ring_height = 0.1
	pm.direction = Vector3(0, 0.2, 0)
	pm.spread = 180.0
	pm.flatness = 0.8
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.15, 0)
	mist.position = Vector3(0, 0.25, 0)
	mist.emitting = true
	# Ondas: três círculos claros que saem da Mistral.
	for i in 3:
		fx._shockwave(radius * 2.0, spread_time * (1.0 + 0.25 * float(i)), Color(TURQ, 0.5), float(i) * 0.12)
	var l := fx._light(ICE, 0.0)
	l.omni_range = radius
	l.position = Vector3(0, 2.5, 0)
	fx.on_tick = func(age: float, _dt: float) -> void:
		var k := clampf(age / spread_time, 0.0, 1.0)
		var front := radius * (1.0 - pow(1.0 - k, 1.7)) + 0.6
		m.set_shader_parameter("front", front)
		pm.emission_ring_radius = maxf(front - 0.3, 0.6)
		pm.emission_ring_inner_radius = maxf(front - 1.4, 0.3)
		var melt := clampf((age - spread_time - hold) / 1.0, 0.0, 1.0)
		m.set_shader_parameter("alpha", 1.0 - melt)
		l.light_energy = 1.4 * (1.0 - melt) * (0.5 + 0.5 * (1.0 - k))
		if k >= 1.0:
			mist.amount_ratio = 0.35
		if melt > 0.0:
			mist.emitting = false
	return fx


# ================================================================ Carga Atmosférica e detalhes

## Partículas de vento e eletricidade girando em volta da Mistral: uma
## por carga, mais brilhantes a cada carga; com 3, arcos entre elas.
class Orbit extends Node3D:
	var charges: int = 0
	var _t: float = 0.0
	var _motes: Array[Sprite3D] = []
	var _trails: Array = []
	var _im: ImmediateMesh
	var _mi: MeshInstance3D
	var _zap: float = 0.0
	var _show: Array[float] = [0.0, 0.0, 0.0]
	var hero: Node3D

	func _ready() -> void:
		top_level = true
		_im = ImmediateMesh.new()
		_mi = MeshInstance3D.new()
		_mi.mesh = _im
		_mi.material_override = MistralFX._line_material()
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mi)
		for i in 3:
			var s := Sprite3D.new()
			s.texture = FenixFX._soft_texture()
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.shaded = false
			var m := FenixFX._additive(FenixFX._soft_texture())
			m.vertex_color_use_as_albedo = false
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.albedo_color = Color(MistralFX.TURQ, 0.0)
			s.material_override = m
			s.pixel_size = 0.15 / 64.0
			add_child(s)
			_motes.append(s)
			_trails.append([])

	func _process(delta: float) -> void:
		if hero == null or not is_instance_valid(hero):
			return
		_t += delta
		global_position = hero.global_position
		var full := charges >= 3
		var spd := 3.2 if not full else 5.0
		_im.clear_surfaces()
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var cam := MistralFX._cam_pos()
		var drew := false
		var pts_now: Array[Vector3] = []
		for i in 3:
			_show[i] = move_toward(_show[i], 1.0 if i < charges else 0.0, delta * 4.0)
			var ang := _t * spd + TAU * float(i) / 3.0
			var y := 0.95 + sin(_t * 2.3 + float(i) * 2.0) * 0.25
			var r := 0.62 + 0.06 * sin(_t * 3.1 + float(i))
			var p := global_position + Vector3(cos(ang) * r, y, sin(ang) * r)
			pts_now.append(p)
			var s := _motes[i]
			s.global_position = p
			var bright := (0.6 + 0.15 * float(charges)) * _show[i]
			(s.material_override as StandardMaterial3D).albedo_color = Color(MistralFX.TURQ.lerp(MistralFX.ICE, 0.4 if full else 0.0), bright)
			s.scale = Vector3.ONE * (1.0 + 0.35 * float(full) + 0.2 * sin(_t * 20.0 + float(i)))
			var tr: Array = _trails[i]
			tr.push_front(p)
			if tr.size() > 12:
				tr.pop_back()
			if _show[i] > 0.02 and tr.size() > 2:
				MistralFX._ribbon(_im, PackedVector3Array(tr), 0.06, Color(MistralFX.TURQ.r, MistralFX.TURQ.g, MistralFX.TURQ.b, 0.7 * _show[i]), cam)
				drew = true
		# Com 3 cargas: arcos elétricos curtos entre as partículas.
		if full:
			_zap -= delta
			if _zap <= 0.0:
				_zap = randf_range(0.06, 0.14)
			if _zap > 0.05:
				var i0 := int(_t * 7.0) % 3
				var pts := MistralFX.bolt_path(pts_now[i0], pts_now[(i0 + 1) % 3], 0.08, 0.1)
				MistralFX._draw_bolt(_im, pts, 0.03, 0.8, cam)
				drew = true
		if not drew:
			_im.surface_add_vertex(Vector3.ZERO)
			_im.surface_add_vertex(Vector3.ZERO)
			_im.surface_add_vertex(Vector3.ZERO)
		_im.surface_end()


## Faixas de tecido turquesa presas à cintura, sempre flutuando como se
## estivessem no vento (mais agitadas ao correr e durante os poderes).
class Sashes extends Node3D:
	var hero: Hero
	var anchor: Node3D
	var gust: float = 0.0
	var _t: float = 0.0
	var _im: ImmediateMesh
	var _vel := Vector3.ZERO

	func _ready() -> void:
		top_level = true
		_im = ImmediateMesh.new()
		var mi := MeshInstance3D.new()
		mi.mesh = _im
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.7
		m.albedo_color = Color(1, 1, 1)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	func _process(delta: float) -> void:
		if hero == null or not is_instance_valid(hero):
			return
		_t += delta
		global_transform = Transform3D.IDENTITY
		gust = move_toward(gust, 0.0, delta * 1.5)
		var v := hero.velocity
		v.y = 0.0
		_vel = _vel.lerp(v, 1.0 - exp(-6.0 * delta))
		var base: Vector3 = anchor.global_position if anchor != null and is_instance_valid(anchor) else hero.global_position + Vector3(0, 0.9, 0)
		var basis := hero.visual.global_transform.basis.orthonormalized() if hero.visual != null else Basis.IDENTITY
		var back := basis.z
		var right := basis.x
		_im.clear_surfaces()
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 2:
			var side := (0.11 if k == 0 else 0.15) * (1.0 if k == 0 else -1.0)
			var root := base + right * side + back * 0.09
			var pts: Array[Vector3] = []
			var n := 10
			var length := 0.85 if k == 0 else 0.7
			var amp := 0.11 + 0.06 * minf(_vel.length() / 5.0, 1.0) + 0.12 * gust
			for i in n:
				var t := float(i) / float(n - 1)
				var drift := back * (0.35 + 0.65 * t) * length - _vel * 0.07 * t
				drift.y = 0.0
				var wave := right * sin(_t * 5.0 - t * 5.0 + float(k) * 1.7) * amp * t \
						+ Vector3.UP * sin(_t * 3.7 - t * 4.0 + float(k)) * amp * 0.8 * t
				var droop := Vector3(0, -t * length * (0.42 - 0.3 * minf(_vel.length() / 5.0 + gust, 1.0)), 0)
				pts.append(root + drift + wave + droop)
			for i in n - 1:
				var t0 := float(i) / float(n - 1)
				var t1 := float(i + 1) / float(n - 1)
				var w0 := lerpf(0.055, 0.03, t0)
				var w1 := lerpf(0.055, 0.03, t1)
				var up0 := Vector3.UP.cross(pts[i + 1] - pts[i]).normalized().cross(pts[i + 1] - pts[i]).normalized()
				var s0 := (pts[i + 1] - pts[i]).cross(back).normalized()
				if s0.length() < 0.1:
					s0 = right
				var c0 := MistralFX.TURQ.lerp(MistralFX.OCEAN, t0 * 0.6)
				var c1 := MistralFX.TURQ.lerp(MistralFX.OCEAN, t1 * 0.6)
				var a0 := pts[i] - s0 * w0
				var b0 := pts[i] + s0 * w0
				var a1 := pts[i + 1] - s0 * w1
				var b1 := pts[i + 1] + s0 * w1
				for vv in [[a0, c0], [b0, c0], [b1, c1], [a0, c0], [b1, c1], [a1, c1]]:
					_im.surface_set_normal(up0 if up0.length() > 0.1 else back)
					_im.surface_set_color(vv[1])
					_im.surface_add_vertex(vv[0])
		_im.surface_end()


## Olhos: dourados em repouso, azul-elétricos com os poderes ativos.
class Eyes extends RefCounted:
	var mats: Array[StandardMaterial3D] = []
	var power: float = 0.0

	func tick(delta: float, want: float) -> void:
		power = move_toward(power, want, delta * (6.0 if want > power else 2.0))
		for m in mats:
			var c := MistralFX.GOLDEN.lerp(Color(0.6, 0.92, 1.0), power)
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = lerpf(0.8, 4.0, power)


## Dash: rajada curta de vento (riscos) e poeira.
static func dash_gust(at: Vector3, dir: Vector3) -> void:
	var fx := _new_fx(at, 0.5)
	var p := fx._particles(10, 0.35, 0.5, false, [
		[0.0, Color(0.86, 0.97, 1.0, 0.3)],
		[1.0, Color(0.4, 0.87, 0.92, 0.0)],
	], true)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = -dir
	pm.spread = 35.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	p.position = Vector3(0, 0.6, 0)
	p.one_shot = true
	p.explosiveness = 0.7
	p.emitting = true
