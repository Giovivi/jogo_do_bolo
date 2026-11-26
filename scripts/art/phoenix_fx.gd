class_name PhoenixFX
extends FenixFX
## Efeitos da Forma Fênix: rastros de asa em arco, giro, mergulho, penas de
## fogo, poças de fogo no chão, rastro da Investida Solar, explosões e as
## marcas de Brasa nos inimigos. Mesma paleta azul e dourada do Fênix.

const ARC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.6 + vnoise(p * 2.3 + 3.1) * 0.4; }
uniform float head = 1.0;
uniform float tail_len = 1.1;
uniform float fade = 1.0;
uniform vec4 col_out : source_color = vec4(0.15, 0.45, 1.0, 1.0);
uniform vec4 col_in : source_color = vec4(1.0, 0.8, 0.4, 1.0);
// UV.x: 0 no começo do arco, 1 no fim. UV.y: 0 por dentro, 1 por fora.
void fragment() {
	float d = head - UV.x;
	float along = smoothstep(tail_len, 0.0, d) * step(0.0, d);
	vec2 nuv = vec2(UV.x * 3.0 - TIME * 1.8, UV.y * 0.8 + TIME * 0.4);
	float n = fbm(nuv * 4.0);
	float across = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.55 + 0.25 * n, UV.y);
	float hot = smoothstep(0.25, 0.0, d) * smoothstep(0.3, 0.75, UV.y);
	vec3 c = mix(col_out.rgb, col_in.rgb, clamp(hot + 0.3 * n, 0.0, 1.0));
	ALBEDO = c * 2.5;
	ALPHA = clamp(along * across * (0.6 + 0.6 * n) * fade, 0.0, 1.0);
}
"""

const PATCH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.6 + vnoise(p * 2.3 + 3.1) * 0.4; }
uniform float fade = 1.0;
uniform float seed = 0.0;
// Chão queimando: mancha irregular azul com veios dourados.
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = fbm(UV * 3.5 + vec2(seed, TIME * 0.5));
	float n2 = fbm(UV * 8.0 - vec2(TIME * 0.8, seed));
	float blob = smoothstep(0.95, 0.45, r + (n - 0.5) * 0.6);
	float veins = smoothstep(0.62, 0.7, n2) * blob;
	vec3 c = mix(vec3(0.08, 0.3, 1.0), vec3(1.0, 0.7, 0.3), veins);
	ALBEDO = c * 2.5;
	ALPHA = clamp(blob * (0.45 + 0.5 * n) * fade + veins * 0.8 * fade, 0.0, 1.0);
}
"""

static var _arc_shader: Shader
static var _patch_shader: Shader
static var _noise: NoiseTexture2D


# ================================================================ golpes do combo

## Rastro de fogo em arco deixado pela asa. `from_deg`/`to_deg` são ângulos
## em torno do herói (0 = frente, positivo = para a direita), na altura `h`.
static func wing_arc(hero: Node3D, facing: Vector3, radius: float, from_deg: float, to_deg: float, duration: float, h := 1.0, width := 1.2) -> PhoenixFX:
	var fx := _spawn_p(hero.global_position, duration + 0.6)
	fx.basis = Basis.looking_at(Vector3(facing.x, 0, facing.z).normalized(), Vector3.UP)
	var mat := fx._arc_mat()
	var mesh := _arc_mesh(radius - width * 0.6, radius + width * 0.4, from_deg, to_deg, h, 1.1)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)
	# Segunda faixa mais baixa e fina: dá volume ao golpe.
	var mi2 := MeshInstance3D.new()
	mi2.mesh = _arc_mesh(radius - width * 0.3, radius + width * 0.25, from_deg, to_deg, h * 0.55, 0.6)
	var mat2 := fx._arc_mat()
	mat2.set_shader_parameter("col_out", Color(0.1, 0.3, 1.0))
	mi2.material_override = mat2
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi2)
	var light := fx._light(FenixFX.BLUE, 2.0)
	light.omni_range = radius * 2.5
	var embers := fx._particles(160, 0.5, 0.7, true, FenixFX.BLUE_RAMP)
	embers.emitting = true
	fx.on_tick = func(t: float, _d: float) -> void:
		var k := clampf(t / duration, 0.0, 1.0)
		var head := 1.0 - pow(1.0 - k, 2.0)
		var fade := clampf(1.0 - (t - duration) / 0.5, 0.0, 1.0)
		for m in [mat, mat2]:
			m.set_shader_parameter("head", head * 1.25)
			m.set_shader_parameter("fade", fade)
		var a := deg_to_rad(lerpf(from_deg, to_deg, head))
		embers.global_position = fx.global_transform * Vector3(sin(a) * radius, h, -cos(a) * radius)
		embers.emitting = t < duration
		light.position = fx.basis.inverse() * (embers.global_position - fx.global_position)
		light.light_energy = 2.5 * fade
	return fx


## Fogo que fica no chão ao longo do arco do golpe 1.
static func ground_arc(at: Vector3, facing: Vector3, radius: float, from_deg: float, to_deg: float, count: int, life_s: float) -> void:
	var b := Basis.looking_at(Vector3(facing.x, 0, facing.z).normalized(), Vector3.UP)
	for i in count:
		var a := deg_to_rad(lerpf(from_deg, to_deg, (i + 0.5) / count))
		var p := at + b * Vector3(sin(a) * radius, 0, -cos(a) * radius)
		fire_patch(p, 0.9, life_s, i * 0.03)


## Giro: anel completo de fogo em volta, com onda no chão.
static func spin(hero: Node3D, radius: float, duration: float) -> void:
	var fx := wing_arc(hero, Vector3.FORWARD, radius, -180.0, 180.0, duration, 0.9, 1.4)
	var m := fx.get_child(0) as MeshInstance3D
	(m.material_override as ShaderMaterial).set_shader_parameter("tail_len", 0.9)
	fx._shockwave(radius * 2.2, 0.35, FenixFX.GOLD, duration * 0.6)
	fx._shockwave(radius * 2.0, 0.4, FenixFX.BLUE, duration * 0.7)


## Pequena explosão do Mergulho da Fênix (golpe 3).
static func small_burst(at: Vector3, radius: float) -> void:
	var fx := _spawn_p(at, 1.4)
	fx._shockwave(radius * 2.0, 0.3, FenixFX.BLUE)
	fx._shockwave(radius * 1.3, 0.25, FenixFX.GOLD)
	fx._radial_burst(140, radius, 0.5, FenixFX.BLUE_RAMP, 1.1)
	fx._radial_burst(60, radius * 0.7, 0.45, FenixFX.GOLD_RAMP, 0.9)
	var s := fx._sparks(70, 0.9)
	(s.process_material as ParticleProcessMaterial).spread = 80.0
	(s.process_material as ParticleProcessMaterial).initial_velocity_max = 7.0
	s.one_shot = true
	s.explosiveness = 0.95
	s.emitting = true
	var l := fx._light(FenixFX.BLUE, 5.0)
	l.omni_range = radius * 3.0
	fx.on_tick = func(t: float, _d: float) -> void:
		l.light_energy = maxf(0.0, 5.0 - t * 9.0)
	fire_patch(at, radius * 1.2, 2.0, 0.0)


## Linha de fogo no chão entre dois pontos (Mergulho e Investida Solar).
static func trail_line(from: Vector3, to: Vector3, width: float, life_s: float) -> void:
	var d := to - from
	d.y = 0.0
	var n := maxi(2, int(d.length() / (width * 0.55)))
	for i in n:
		var k := float(i) / float(n - 1)
		fire_patch(from.lerp(to, k), width, life_s, k * 0.15)


## Rastro de velocidade da Investida Solar: faixa de fogo na altura do corpo,
## de `from` até `to`, que se apaga do começo para o fim.
static func rush_streak(from: Vector3, to: Vector3, life_s: float) -> void:
	var d := to - from
	d.y = 0.0
	var fx := _spawn_p(from, life_s)
	fx.basis = Basis.looking_at(d.normalized(), Vector3.UP)
	var ln := d.length()
	var mat := fx._arc_mat()
	mat.set_shader_parameter("tail_len", 1.0)
	mat.set_shader_parameter("head", 1.0)
	for h in [[1.25, 1.1], [0.7, 0.6]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y: float = h[0]
		var w: float = h[1]
		var p := [Vector3(0, y - w * 0.5, 0), Vector3(0, y + w * 0.5, 0), Vector3(0, y + w * 0.5, -ln), Vector3(0, y - w * 0.5, -ln)]
		var uv := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[j])
			st.add_vertex(p[j])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx.add_child(mi)
	fx.on_tick = func(t: float, _d: float) -> void:
		mat.set_shader_parameter("head", 1.0 + t / life_s * 1.2)
		mat.set_shader_parameter("tail_len", 1.0)


# ================================================================ Q: Tempestade de Penas

## Uma pena de fogo voando de `from` até `to` em `time` s; ao chegar, deixa
## uma poça de fogo. Devolve o nó (para marcar acertos no caminho).
static func feather_shot(from: Vector3, to: Vector3, time: float, patch_life: float) -> PhoenixFX:
	var fx := _spawn_p(from, time + 0.05)
	var dir := (to - from)
	dir.y = 0.0
	fx.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	var form := PhoenixForm.new()
	var f := form._feather(1.4, 0.5, Color(0.25, 0.55, 1.0), Color(0.8, 0.95, 1.0), randi() % 50)
	form.free()
	# Deitada, ponta para a frente.
	f.rotation = Vector3(deg_to_rad(-90.0), 0, 0)
	# Plano da pena em pé: de frente para a câmera baixa, não de lado.
	f.rotate_object_local(Vector3.UP, PI * 0.5)
	f.position = Vector3(0, 0, 0.55)
	fx.add_child(f)
	var core := fx._glow_sprite(0.4, Color(1.0, 0.8, 0.45, 0.7))
	fx.add_child(core)
	var tr := fx._particles(30, 0.22, 0.35, true, FenixFX.BLUE_RAMP)
	var tm := tr.process_material as ParticleProcessMaterial
	tm.gravity = Vector3.ZERO
	tm.initial_velocity_max = 0.3
	tr.emitting = true
	fx.on_tick = func(t: float, _d: float) -> void:
		var k := clampf(t / time, 0.0, 1.0)
		var p := from.lerp(to, k)
		p.y = lerpf(from.y, to.y + 0.15, k * k)
		fx.global_position = p
		tr.global_position = p
		if t >= time and not fx.has_meta("landed"):
			fx.set_meta("landed", true)
			fire_patch(Vector3(to.x, to.y, to.z), 1.1, patch_life, 0.0)
	return fx


## Leque de penas: `count` penas espalhadas em `arc_deg` graus até `reach` m.
static func feather_fan(hero: Node3D, facing: Vector3, count: int, arc_deg: float, reach: float, time: float, patch_life: float) -> void:
	var b := Basis.looking_at(Vector3(facing.x, 0, facing.z).normalized(), Vector3.UP)
	var from := hero.global_position + Vector3(0, 1.4, 0)
	var g := Vector3(hero.global_position.x, hero.global_position.y + 0.05, hero.global_position.z)
	for i in count:
		var a := deg_to_rad(lerpf(-arc_deg * 0.5, arc_deg * 0.5, float(i) / float(count - 1)))
		var r := reach * (0.85 + 0.15 * absf(sin(i * 1.7)))
		var to := g + b * Vector3(sin(a) * r, 0, -cos(a) * r)
		feather_shot(from + b * Vector3(sin(a) * 0.4, 0, -0.4), to, time * (r / reach), patch_life)
	# Rajada de faíscas no bater de asas.
	var fx := _spawn_p(hero.global_position, 1.0)
	fx.basis = b
	var s := fx._sparks(80, 0.8)
	s.position = Vector3(0, 1.4, 0)
	var sm := s.process_material as ParticleProcessMaterial
	sm.direction = Vector3(0, 0.1, -1)
	sm.spread = arc_deg * 0.5
	sm.initial_velocity_min = 4.0
	sm.initial_velocity_max = 9.0
	s.one_shot = true
	s.explosiveness = 0.9
	s.emitting = true


# ================================================================ chão e explosões

## Poça de fogo no chão: mancha que queima e chamas baixas.
static func fire_patch(at: Vector3, size: float, life_s: float, delay: float) -> void:
	var fx := _spawn_p(at, life_s + delay)
	var mat := ShaderMaterial.new()
	mat.shader = _shader_patch()
	mat.set_shader_parameter("seed", randf() * 10.0)
	mat.set_shader_parameter("fade", 0.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position.y = 0.04
	mi.rotation.y = randf() * TAU
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)
	var fl := fx._particles(int(8 * size), 0.5, 0.4 * size, true, FenixFX.BLUE_RAMP)
	var flm := fl.process_material as ParticleProcessMaterial
	flm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flm.emission_box_extents = Vector3(size * 0.3, 0.02, size * 0.3)
	flm.initial_velocity_min = 0.3
	flm.initial_velocity_max = 0.9
	fl.position.y = 0.1
	var gl := fx._particles(int(3 * size), 0.45, 0.3 * size, true, FenixFX.GOLD_RAMP)
	(gl.process_material as ParticleProcessMaterial).emission_sphere_radius = size * 0.2
	gl.position.y = 0.1
	fx.on_tick = func(t: float, _d: float) -> void:
		var tt := t - delay
		var f := clampf(tt / 0.12, 0.0, 1.0) * clampf((life_s - tt) / 0.5, 0.0, 1.0)
		mat.set_shader_parameter("fade", f)
		fl.emitting = tt > 0.0 and tt < life_s - 0.4
		gl.emitting = fl.emitting


## Explosão circular do fim da Investida Solar (asas abrem).
static func solar_nova(at: Vector3, radius: float, boosted: bool) -> void:
	FenixFX.impact(at, radius)
	var fx := _spawn_p(at, 1.6)
	fx._shockwave(radius * 2.3, 0.45, FenixFX.GOLD, 0.05)
	if boosted:
		fx._radial_burst(120, radius * 1.1, 0.6, FenixFX.GOLD_RAMP, 1.4)
	# Penas soltas que voam para fora.
	var form := PhoenixForm.new()
	for i in 12:
		var a := TAU * i / 12.0
		var f := form._feather(0.9, 0.35, Color(0.25, 0.55, 1.0), FenixFX.GOLD if i % 2 == 0 else Color(0.8, 0.95, 1.0), i)
		var holder := Node3D.new()
		fx.add_child(holder)
		holder.rotation.y = a
		f.rotation = Vector3(deg_to_rad(-90.0), 0, 0)
		holder.add_child(f)
		holder.set_meta("a", a)
	form.free()
	fx.on_tick = func(t: float, _d: float) -> void:
		var k := clampf(t / 0.5, 0.0, 1.0)
		for c in fx.get_children():
			if c.has_meta("a"):
				var h := c as Node3D
				h.position = Vector3(0, 1.0 - k * 0.6, 0) + h.basis * Vector3(0, 0, -radius * (0.2 + 0.8 * (1.0 - pow(1.0 - k, 2.0))))
				h.scale = Vector3.ONE * (1.0 - clampf((t - 0.5) / 0.4, 0.0, 1.0)) + Vector3.ONE * 0.01


## Brasa consumida pela Tempestade de Penas: estouro dourado no inimigo.
static func ember_pop(at: Vector3, stacks: int) -> void:
	var r := 1.0 + 0.35 * stacks
	var fx := _spawn_p(at, 1.2)
	fx._shockwave(r * 2.0, 0.28, FenixFX.GOLD)
	fx._radial_burst(40 + 30 * stacks, r, 0.45, FenixFX.GOLD_RAMP, 0.9 + 0.15 * stacks)
	var b := fx._particles(30 * stacks, 0.5, 0.9, true, FenixFX.BLUE_RAMP)
	var bm := b.process_material as ParticleProcessMaterial
	bm.initial_velocity_min = 2.0
	bm.initial_velocity_max = 5.0
	bm.spread = 50.0
	b.position.y = 0.8
	b.one_shot = true
	b.explosiveness = 0.95
	b.emitting = true
	var l := fx._light(FenixFX.GOLD, 4.0)
	fx.on_tick = func(t: float, _d: float) -> void:
		l.light_energy = maxf(0.0, 4.0 - t * 8.0)


# ================================================================ peças

static func _spawn_p(at: Vector3, life_s: float) -> PhoenixFX:
	var fx := PhoenixFX.new()
	fx.life = life_s
	var root: Node = Game.world_root if Game.world_root != null else Engine.get_main_loop().root
	root.add_child(fx)
	fx.global_position = at
	return fx


func _arc_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if _arc_shader == null:
		_arc_shader = Shader.new()
		_arc_shader.code = ARC_SHADER
	m.shader = _arc_shader
	m.set_shader_parameter("head", 0.0)
	return m


## Faixa em arco (anel parcial) na altura h, levemente inclinada para fora.
static func _arc_mesh(r0: float, r1: float, from_deg: float, to_deg: float, h: float, tilt := 0.25) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := maxi(8, int(absf(to_deg - from_deg) / 6.0))
	for i in seg:
		var k0 := float(i) / seg
		var k1 := float(i + 1) / seg
		var a0 := deg_to_rad(lerpf(from_deg, to_deg, k0))
		var a1 := deg_to_rad(lerpf(from_deg, to_deg, k1))
		var p := [
			Vector3(sin(a0) * r0, h + tilt * 0.6, -cos(a0) * r0), Vector3(sin(a0) * r1, h - tilt * 0.4, -cos(a0) * r1),
			Vector3(sin(a1) * r1, h - tilt * 0.4, -cos(a1) * r1), Vector3(sin(a1) * r0, h + tilt * 0.6, -cos(a1) * r0),
		]
		var uv := [Vector2(k0, 0), Vector2(k0, 1), Vector2(k1, 1), Vector2(k1, 0)]
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[j])
			st.add_vertex(p[j])
	return st.commit()


static func _shader_patch() -> Shader:
	if _patch_shader == null:
		_patch_shader = Shader.new()
		_patch_shader.code = PATCH_SHADER
	return _patch_shader


static func _noise_tex() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.02
		n.fractal_octaves = 3
		_noise = NoiseTexture2D.new()
		_noise.noise = n
		_noise.seamless = true
		_noise.width = 256
		_noise.height = 256
	return _noise
