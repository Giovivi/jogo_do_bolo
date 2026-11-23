class_name HandFire
extends Node3D
## Fogo azul preso a uma mão do modelo durante os golpes.
## Segue os ossos do antebraço e da mão todo quadro: chama envolvendo mão e
## antebraço, rastro em forma de chama atrás do movimento (mais longo quanto
## mais rápido o golpe, subindo como calor), faíscas, luz e, no golpe forte,
## uma onda de fogo no chão. Acende com ignite() e apaga sozinho.

enum Style { CHAMA, GARRAS }

## CHAMA: um rastro largo saindo da mão. GARRAS: três línguas de fogo nas pontas dos dedos.
var style: Style = Style.CHAMA
var skeleton: Skeleton3D
var hand_bone: int = -1
var forearm_bone: int = -1
var tip_bones: Array[int] = []

var _power: float = 0.0
var _hold: float = 0.0
var _strong: bool = false
var _time: float = 0.0
var _speed: float = 0.0
var _last_hand: Vector3 = Vector3.ZERO
## Histórico do rastro: cada item é [tempo, PackedVector3Array com um ponto por língua de fogo].
var _hist: Array = []

var _flame: GPUParticles3D
var _arm_flame: GPUParticles3D
## Rastro de chama: línguas de fogo soltas ao longo do caminho da mão.
var _trail_fire: GPUParticles3D
var _sparks: GPUParticles3D
var _burst: GPUParticles3D
var _light: OmniLight3D
var _trail: MeshInstance3D
var _mesh: ImmediateMesh
var _ring: MeshInstance3D
var _ring_t: float = -1.0

const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
void fragment() {
	// UV.x: 0 na mão, 1 na ponta do rastro. UV.y: atravessa a chama.
	float age = UV.x;
	float across = abs(UV.y * 2.0 - 1.0);
	vec2 nuv = vec2(UV.x * 1.6 - TIME * 2.4, UV.y * 0.7 + TIME * 0.5);
	float n = texture(noise_tex, nuv).r * 0.6 + texture(noise_tex, nuv * 2.7 + vec2(TIME * 1.7, 0.3)).r * 0.4;
	// Borda que tremula; na ponta a chama se quebra em línguas.
	float width = min(0.85, (1.0 - age * 0.45) * (0.4 + 0.7 * n));
	float shape = smoothstep(width, width * 0.35, across);
	shape *= smoothstep(1.0, 0.45, age + (n - 0.5) * 0.9);
	float core = smoothstep(width * 0.55, 0.0, across) * (1.0 - age) * (0.6 + 0.4 * n);
	vec3 col = mix(vec3(0.05, 0.14, 0.85), vec3(0.25, 0.58, 1.0), smoothstep(0.0, 0.6, shape));
	col = mix(col, vec3(0.75, 0.9, 1.0), clamp(core * 0.8, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(shape * COLOR.a * 0.6, 0.0, 1.0);
}
"""


func _ready() -> void:
	top_level = true
	_flame = _make_flame(56, 0.24, 1.0)
	_arm_flame = _make_flame(32, 0.22, 0.8)
	(_arm_flame.process_material as ParticleProcessMaterial).emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	(_arm_flame.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(0.04, 0.12, 0.04)
	_trail_fire = _make_flame(500, 0.26, 0.85)
	_sparks = _make_sparks()
	_burst = _make_burst()
	_ring = _make_ring()
	_light = OmniLight3D.new()
	_light.light_color = Color(0.35, 0.6, 1.0)
	_light.omni_range = 3.0
	_light.light_energy = 0.0
	add_child(_light)
	_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.material_override = _trail_material()
	add_child(_trail)
	# O rastro é desenhado em coordenadas do mundo.
	_trail.top_level = true
	_trail.global_transform = Transform3D.IDENTITY


## Acende o fogo por `duration` segundos. `strong` deixa maior e abre a onda no chão.
func ignite(duration: float, strong: bool = false) -> void:
	_hold = maxf(_hold, duration)
	_strong = strong
	if strong:
		_burst.global_position = _hand_pos()
		_burst.restart()
		_ring_t = 0.0


func _process(delta: float) -> void:
	if skeleton == null or hand_bone < 0:
		return
	_time += delta
	_hold -= delta
	var target := 1.0 if _hold > 0.0 else 0.0
	_power = move_toward(_power, target, delta * (14.0 if target > _power else 6.0))
	var hand := _hand_pos()
	if delta > 0.0:
		_speed = lerpf(_speed, hand.distance_to(_last_hand) / delta, 0.5)
	if _power > 0.05 and delta > 0.0:
		_emit_trail(_last_hand, hand, delta)
	_last_hand = hand
	global_position = hand
	_flame.global_position = hand
	_sparks.global_position = hand
	if forearm_bone >= 0:
		var arm := _bone(forearm_bone)
		_arm_flame.global_transform = Transform3D(arm.basis.orthonormalized(), arm * Vector3(0, 0.16, 0))
	var lit := _power > 0.05
	_flame.emitting = lit
	_arm_flame.emitting = lit and forearm_bone >= 0
	_sparks.emitting = _power > 0.5
	_flame.amount_ratio = _power
	_arm_flame.amount_ratio = _power
	_light.light_energy = _power * (2.6 if _strong else 1.8) * (0.8 + 0.2 * sin(_time * 37.0) * sin(_time * 23.0))
	_update_trail()
	_update_ring(delta)


## Solta chamas ao longo do trecho que a mão andou neste quadro: golpe rápido
## deixa uma faixa longa de fogo, que fica para trás, sobe e se apaga.
func _emit_trail(from: Vector3, to: Vector3, delta: float) -> void:
	var d := from.distance_to(to)
	if d < 0.005 or d > 1.5:
		return
	var vel := (to - from) / delta
	var n := mini(int(ceil(d / 0.04)), 14)
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR
	for i in n:
		var p := from.lerp(to, (i + randf()) / n)
		p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.04
		# Arrasto: a chama ainda anda um pouco junto do golpe, depois sobe.
		var v := vel * 0.12 + Vector3(randf_range(-0.2, 0.2), randf_range(0.2, 0.6), randf_range(-0.2, 0.2))
		_trail_fire.emit_particle(Transform3D(Basis(), p), v, Color(0.8, 0.9, 1.0, 0.6 * _power), Color(), flags)


func _bone(b: int) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(b)


func _hand_pos() -> Vector3:
	# Um pouco à frente do pulso, no meio da mão.
	return _bone(hand_bone) * Vector3(0, 0.07, 0)


func _tip_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	if style == Style.GARRAS and not tip_bones.is_empty():
		for b in tip_bones:
			pts.append(_bone(b) * Vector3(0, 0.03, 0))
	else:
		pts.append(_hand_pos())
	return pts


func _update_trail() -> void:
	# Golpe rápido deixa um rastro mais longo; parado, a chama só sobe.
	var life := lerpf(0.12, 0.3, clampf(_speed / 8.0, 0.0, 1.0))
	if _power > 0.05:
		_hist.push_front([_time, _tip_points()])
	while not _hist.is_empty() and _time - _hist.back()[0] > 0.3:
		_hist.pop_back()
	_mesh.clear_surfaces()
	if _hist.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	if style != Style.GARRAS:
		return
	var n_ribbons: int = (_hist[0][1] as PackedVector3Array).size()
	var base_w := 0.07 * (1.35 if _strong else 1.0)
	for r in n_ribbons:
		# Curva suave (Catmull-Rom) entre as posições gravadas a cada quadro.
		var raw := PackedVector3Array()
		var ages := PackedFloat32Array()
		for h in _hist:
			var pts: PackedVector3Array = h[1]
			var age := (_time - float(h[0])) / life
			if r >= pts.size() or age > 1.0:
				break
			# Pula pontos colados (mão parada) para a faixa não se abrir em leque.
			if not raw.is_empty() and raw[raw.size() - 1].distance_to(pts[r]) < 0.025:
				continue
			# O fogo que fica para trás sobe, como calor.
			raw.append(pts[r] + Vector3.UP * age * age * 0.35)
			ages.append(age)
		if raw.size() < 2:
			continue
		var pts2 := PackedVector3Array()
		var ages2 := PackedFloat32Array()
		for i in raw.size() - 1:
			var p0 := raw[maxi(i - 1, 0)]
			var p1 := raw[i]
			var p2 := raw[i + 1]
			var p3 := raw[mini(i + 2, raw.size() - 1)]
			for k in 4:
				var t := k / 4.0
				pts2.append(_catmull(p0, p1, p2, p3, t))
				ages2.append(lerpf(ages[i], ages[i + 1], t))
		pts2.append(raw[raw.size() - 1])
		ages2.append(ages[ages.size() - 1])
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var last_side := Vector3.ZERO
		for i in pts2.size():
			var p := pts2[i]
			var along := pts2[maxi(i - 1, 0)] - pts2[mini(i + 1, pts2.size() - 1)]
			if along.length() < 0.0001:
				along = Vector3.UP
			var side := along.cross(eye - p).normalized()
			# Não deixa a faixa torcer quando o golpe vem na direção da câmera.
			if last_side != Vector3.ZERO:
				if side.dot(last_side) < 0.0:
					side = -side
				side = last_side.lerp(side, 0.5).normalized()
			last_side = side
			var age := ages2[i]
			# Já nasce largo na mão, incha logo atrás e afina na ponta.
			var w := base_w * (0.55 + 0.6 * sin(clampf(age * 1.1 + 0.15, 0.0, 1.0) * PI)) * _power
			_mesh.surface_set_color(Color(1, 1, 1, _power))
			_mesh.surface_set_uv(Vector2(age, 0.0))
			_mesh.surface_add_vertex(p + side * w)
			_mesh.surface_set_color(Color(1, 1, 1, _power))
			_mesh.surface_set_uv(Vector2(age, 1.0))
			_mesh.surface_add_vertex(p - side * w)
		_mesh.surface_end()


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Onda de fogo no chão no golpe forte, do tamanho do alcance das garras.
func _update_ring(delta: float) -> void:
	if _ring_t < 0.0:
		_ring.visible = false
		return
	_ring_t += delta
	var k := _ring_t / 0.32
	if k >= 1.0:
		_ring_t = -1.0
		_ring.visible = false
		return
	_ring.visible = true
	var foot := skeleton.global_transform.origin
	_ring.global_position = Vector3(foot.x, foot.y + 0.06, foot.z)
	var size := lerpf(0.6, 4.6, 1.0 - pow(1.0 - k, 3.0))
	_ring.scale = Vector3(size, 1.0, size)
	(_ring.material_override as StandardMaterial3D).albedo_color = Color(0.35, 0.65, 1.0, 1.0 - k)


# ---------------------------------------------------------------- materiais

func _trail_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = TRAIL_SHADER
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 128
	tex.height = 128
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise_tex", tex)
	return m


static func _soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.75))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


## Gota de chama: estreita em cima, redonda embaixo.
static func _flame_texture() -> ImageTexture:
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := (y + 0.5) / h
		var half := 0.46 * pow(v, 0.7) if v < 0.72 else 0.46 * pow(0.72, 0.7) * sqrt(maxf(0.0, 1.0 - pow((v - 0.72) / 0.28, 2.0)))
		for x in w:
			var u := absf((x + 0.5) / w - 0.5)
			var a := 0.0
			if half > 0.001:
				a = clampf(1.0 - u / half, 0.0, 1.0)
			a = pow(a, 0.8) * clampf(v * 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func _additive(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


func _ramp(a: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(a.map(func(x): return x[0]))
	g.colors = PackedColorArray(a.map(func(x): return x[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


func _particles(amount: int, life: float, size: float, flame := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var q := QuadMesh.new()
	q.size = Vector2(size, size * (1.7 if flame else 1.0))
	var m := _additive(_flame_texture() if flame else _soft_texture())
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	p.top_level = true
	return p


## Chama que envolve a mão (ou o antebraço). Em coordenadas do mundo:
## quando a mão se move, as línguas ficam para trás e se esticam sozinhas.
func _make_flame(amount: int, life: float, size_mul: float) -> GPUParticles3D:
	var p := _particles(amount, life, 0.2 * size_mul, true)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.07
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 3.2, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.scale_curve = _curve([Vector2(0, 0.7), Vector2(0.2, 1.0), Vector2(1, 0.1)])
	pm.color_ramp = _ramp([
		[0.0, Color(0.5, 0.75, 1.0, 0.45)],
		[0.25, Color(0.25, 0.52, 1.0, 0.4)],
		[0.65, Color(0.08, 0.22, 0.9, 0.22)],
		[1.0, Color(0.04, 0.06, 0.4, 0.0)],
	])
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.08
	pm.turbulence_influence_max = 0.2
	p.process_material = pm
	return p


func _make_sparks() -> GPUParticles3D:
	var p := _particles(24, 0.5, 0.035)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 1.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = _ramp([
		[0.0, Color(0.9, 0.97, 1.0, 1.0)],
		[1.0, Color(0.2, 0.5, 1.0, 0.0)],
	])
	p.process_material = pm
	return p


## Faíscas que saltam para os lados no golpe forte.
func _make_burst() -> GPUParticles3D:
	var p := _particles(28, 0.35, 0.07)
	p.one_shot = true
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1
	pm.direction = Vector3(0, 0.15, 0)
	pm.spread = 180.0
	pm.flatness = 0.75
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, 1.5, 0)
	pm.damping_min = 6.0
	pm.damping_max = 9.0
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = _ramp([
		[0.0, Color(0.7, 0.88, 1.0, 0.9)],
		[1.0, Color(0.05, 0.1, 0.6, 0.0)],
	])
	p.process_material = pm
	return p


func _make_ring() -> MeshInstance3D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.75, 0.9, 0.96, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	var m := _additive(t)
	m.vertex_color_use_as_albedo = false
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	var r := MeshInstance3D.new()
	r.mesh = pm
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.visible = false
	add_child(r)
	r.top_level = true
	return r
