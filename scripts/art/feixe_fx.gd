class_name FeixeFX
extends FenixFX
## Efeitos do Feixe (documento "Direção de arte e VFX" da Vivi; pranchas
## feixe-reformulado-v1/v2 e feixe-e-cone-v3). Luz óptica coerente, não fogo:
## núcleo branco quente, corpo vermelho vivo, borda vermelho profundo e
## sombra vinho, cada um em camada separada. O clarão estrelado é a
## assinatura: pequeno no clique, grande no Foco, no Q e na R.

const CORE := Color(1.0, 0.957, 0.91)       # #FFF4E8
const RED := Color(1.0, 0.188, 0.22)        # #FF3038
const DEEP := Color(0.70, 0.05, 0.14)       # #B30D24
const WINE := Color(0.29, 0.027, 0.078)     # #4A0714
const PINK := Color(1.0, 0.72, 0.68)

const RED_RAMP := [
	[0.0, Color(1.0, 0.85, 0.8, 0.5)],
	[0.3, Color(1.0, 0.25, 0.25, 0.4)],
	[0.7, Color(0.7, 0.05, 0.12, 0.2)],
	[1.0, Color(0.3, 0.0, 0.05, 0.0)],
]
const RED_SPARK_RAMP := [
	[0.0, Color(1.0, 0.96, 0.92, 1.0)],
	[0.45, Color(1.0, 0.4, 0.4, 0.9)],
	[1.0, Color(0.8, 0.04, 0.1, 0.0)],
]
## Largura de cada camada em relação à largura do raio, e cor/alfa.
## A sombra vinho usa mistura normal (separa o raio de pisos claros); as
## outras somam luz. O núcleo é sempre a parte mais clara.
const LAYERS := [
	[1.1, WINE, 0.28, false],
	[1.0, DEEP, 0.5, true],
	[0.62, RED, 0.85, true],
	[0.2, CORE, 0.95, true],
]

## Estado do efeito que acompanha um raio (Q) ou a varredura (R).
var _from := Vector3.ZERO
var _to := Vector3.FORWARD
var _width := 0.4
var _power := 0.0
var _beam: Array[MeshInstance3D] = []
var _floor_strip: MeshInstance3D
var _rings: Array = []
var _ring_clock: float = 0.0
var _embers: GPUParticles3D
var _splash_glow: Sprite3D
var _splash_star: Sprite3D
var _splash_light: OmniLight3D
var _splash_sparks: GPUParticles3D
var _skid: GPUParticles3D
var _push_lines: GPUParticles3D
var _stopping: bool = false
var _stop_age: float = 0.0
## Varredura da Suprema: fatias [yaw, idade, alcance] por onde o raio passou.
var _wedges: Array = []
var _radius: float = 14.0
var _center := Vector3.ZERO
var _outline: MeshInstance3D
var _outline_pts: PackedVector3Array = PackedVector3Array()
var _trail: ImmediateMesh

static var _diamond_tex: ImageTexture


static func _make(at: Vector3, life_s: float) -> FeixeFX:
	var fx := FeixeFX.new()
	fx.life = life_s
	var root: Node = Game.world_root if Game.world_root != null else Engine.get_main_loop().root
	root.add_child(fx)
	fx.global_position = at
	return fx


# ================================================================ peças comuns

## Raio em camadas (sombra vinho, borda, corpo, núcleo), caixas esticadas.
func _beam_layers() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var i := 0
	for l in LAYERS:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 1.0
		cm.radial_segments = 14
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if l[3]:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(l[1], l[2])
		m.render_priority = i
		m.disable_receive_shadows = true
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		out.append(mi)
		i += 1
	return out


static func _place_layers(layers: Array[MeshInstance3D], from: Vector3, to: Vector3, width: float, alpha: float = 1.0) -> void:
	for i in layers.size():
		var mi := layers[i]
		if not is_instance_valid(mi):
			continue
		var l: Array = LAYERS[i]
		var d := to - from
		var length := maxf(d.length(), 0.02)
		var w := maxf(width * float(l[0]), 0.005)
		var b := _basis_y(d if d.length() > 0.001 else Vector3.FORWARD)
		mi.global_transform = Transform3D(Basis(b.x * w, b.y * length, b.z * w), (from + to) * 0.5)
		(mi.material_override as StandardMaterial3D).albedo_color.a = float(l[2]) * alpha


## Estrela pequena de impacto (o clarão do jogo), que cresce e apaga.
static func star(at: Vector3, size: float, duration: float) -> Sprite3D:
	return Game.laser_flare(at, size, duration)


## Faíscas (riscos rápidos com ponta branca) saindo de `at` para `dir`.
func _spark_burst(at: Vector3, dir: Vector3, amount: int, speed: float, spread: float) -> GPUParticles3D:
	var p := _sparks(amount, 0.35)
	p.top_level = true
	var pm := p.process_material as ParticleProcessMaterial
	pm.color_ramp = _ramp(RED_SPARK_RAMP)
	pm.emission_sphere_radius = 0.06
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -7.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 5.0
	(p.draw_pass_1 as QuadMesh).size = Vector2(0.06, 0.06)
	p.global_transform = Transform3D(_basis_y(dir if dir.length() > 0.01 else Vector3.UP), at)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	return p


## Faíscas soltas num ponto, sem nó próprio para controlar (apagam sozinhas).
static func sparks_at(at: Vector3, dir: Vector3, amount: int, speed: float = 5.0, spread: float = 60.0) -> void:
	var fx := _make(at, 0.6)
	fx._spark_burst(at, dir, amount, speed, spread)


static func _diamond_texture() -> ImageTexture:
	if _diamond_tex != null:
		return _diamond_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d: float = absf(x + 0.5 - n * 0.5) + absf(y + 0.5 - n * 0.5)
			var a := 1.0 if d < n * 0.42 else (0.0 if d > n * 0.48 else 0.6)
			var c := Color(1, 1, 1, a)
			if d > n * 0.33 and d < n * 0.42:
				c = Color(0.85, 0.85, 0.85, a)
			img.set_pixel(x, y, c)
	_diamond_tex = ImageTexture.create_from_image(img)
	return _diamond_tex


# ================================================================ Clique

## Disparo Óptico: flash na lente, raio fino que some da cauda para a
## ponta, estrela pequena e 2–3 fragmentos. `charged` = Foco consumido;
## `on_wall` = parou numa parede (faísca curta, sem estrela grande).
static func shot(from: Vector3, to: Vector3, charged: bool = false, on_wall: bool = false) -> void:
	var fx := _make(to, 0.6)
	var width := 0.16 if charged else 0.07
	var layers := fx._beam_layers()
	_place_layers(layers, from, to, width)
	var dir := (to - from).normalized()
	# Flash de 1–2 quadros na lente.
	star(from, 0.55 if charged else 0.3, 0.06)
	if on_wall:
		var g := fx._glow_sprite(0.45, Color(RED, 0.8))
		g.top_level = true
		fx.add_child(g)
		g.global_position = to - dir * 0.05
		fx._spark_burst(to - dir * 0.05, -dir, 5, 4.0, 70.0)
		fx.on_tick = func(age: float, _dt: float) -> void:
			var a := clampf(1.0 - age / 0.12, 0.0, 1.0)
			_place_layers(layers, from.lerp(to, clampf(age / 0.1, 0.0, 0.98)), to, width, a)
			g.modulate.a = 0.8 * clampf(1.0 - age / 0.45, 0.0, 1.0)
		return
	if charged:
		star(to, 1.9, 0.22)
		star(to, 1.1, 0.3)
		# Anel de energia que se contrai no alvo.
		var ring := Sprite3D.new()
		ring.texture = _ring_texture()
		ring.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ring.shaded = false
		ring.no_depth_test = true
		ring.modulate = Color(RED, 0.9)
		ring.pixel_size = 2.2 / 256.0
		ring.top_level = true
		fx.add_child(ring)
		ring.global_position = to
		# Brasas ao longo do raio e leque de faíscas em cruz.
		var emb := fx._particles(26, 0.4, 0.07, false, RED_SPARK_RAMP)
		emb.top_level = true
		var em := emb.process_material as ParticleProcessMaterial
		em.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		em.emission_box_extents = Vector3(0.08, 0.08, from.distance_to(to) * 0.5)
		em.spread = 180.0
		em.initial_velocity_min = 0.3
		em.initial_velocity_max = 1.2
		em.gravity = Vector3(0, -2.0, 0)
		emb.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD), (from + to) * 0.5)
		emb.one_shot = true
		emb.explosiveness = 1.0
		emb.emitting = true
		var side := dir.cross(Vector3.UP).normalized()
		for d in [-dir, side, -side, Vector3.UP]:
			fx._spark_burst(to, (d as Vector3) * 0.8 - dir * 0.3, 5, 6.0, 25.0)
		fx.on_tick = func(age: float, _dt: float) -> void:
			var a := clampf(1.0 - age / 0.16, 0.0, 1.0)
			_place_layers(layers, from.lerp(to, clampf((age - 0.05) / 0.11, 0.0, 0.98)), to, width * (1.0 + age * 2.0), a)
			var k := clampf(age / 0.25, 0.0, 1.0)
			ring.scale = Vector3.ONE * lerpf(1.0, 0.15, k)
			ring.modulate.a = 0.9 * (1.0 - k)
		return
	star(to, 0.75, 0.12)
	fx._spark_burst(to, -dir, 3, 3.5, 55.0)
	fx.on_tick = func(age: float, _dt: float) -> void:
		var a := clampf(1.0 - age / 0.1, 0.0, 1.0)
		# A cauda some primeiro: o começo do raio corre até a ponta.
		_place_layers(layers, from.lerp(to, clampf(age / 0.08, 0.0, 0.98)), to, width, a)


# ================================================================ Óculos e Foco

## Brilho das lentes, estrela do Foco completo e indicador de 3 losangos
## acima da cabeça. Vive com o herói; o Feixe chama place() todo quadro.
class Lenses extends Node3D:
	var lens_l: Sprite3D
	var lens_r: Sprite3D
	var focus_star: Sprite3D
	var segs: Array[Sprite3D] = []
	var stacks: int = 0
	var full: bool = false
	var _clock: float = 0.0
	var _flash: float = 0.0
	var _orbit: Array[Sprite3D] = []
	var charge: float = 0.0
	## Materiais "lente" do modelo (brilho próprio que pulsa).
	var lens_mats: Array[StandardMaterial3D] = []

	func _init() -> void:
		top_level = true
		lens_l = _soft(0.06)
		lens_r = _soft(0.06)
		focus_star = Game.laser_flare(Vector3.ZERO, 0.35, 0.0)
		if focus_star != null:
			focus_star.get_parent().remove_child(focus_star)
			add_child(focus_star)
			focus_star.visible = false
		for i in 3:
			var s := Sprite3D.new()
			s.texture = FeixeFX._diamond_texture()
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.shaded = false
			s.no_depth_test = true
			s.render_priority = 10
			s.pixel_size = 0.0045
			s.offset = Vector2((i - 1) * 40, 0)
			s.visible = false
			add_child(s)
			segs.append(s)
		for i in 5:
			var o := _soft(0.07)
			o.visible = false
			_orbit.append(o)

	func _soft(size: float) -> Sprite3D:
		var s := Sprite3D.new()
		s.texture = HandFire._soft_texture()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.pixel_size = size / 64.0
		s.modulate = Color(FeixeFX.RED, 0.5)
		var m := HandFire._additive(HandFire._soft_texture())
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		s.material_override = m
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		return s

	## Centro das lentes, lado do rosto (direita do herói) e cabeça.
	func place(center: Vector3, right: Vector3, head_top: Vector3, delta: float) -> void:
		_clock += delta
		_flash = maxf(0.0, _flash - delta * 6.0)
		global_position = Vector3.ZERO
		lens_l.global_position = center - right * 0.055
		lens_r.global_position = center + right * 0.055
		# Repouso: pulsação lenta; cada acerto do Foco acende mais.
		var k := 0.18 + 0.06 * sin(_clock * 2.2)
		if stacks >= 1:
			k = 0.4
		if stacks >= 2:
			k = 0.62 + 0.08 * sin(_clock * 9.0)
		if full:
			k = 0.95 + 0.1 * sin(_clock * 12.0)
		k = maxf(k, charge)
		k = minf(1.3, k + _flash)
		for l in [lens_l, lens_r]:
			var s := l as Sprite3D
			s.modulate = Color(FeixeFX.RED.lerp(FeixeFX.CORE, clampf(k - 0.7, 0.0, 0.5)), 0.2 + 0.5 * minf(k, 1.0))
			s.scale = Vector3.ONE * (0.8 + 0.8 * k)
		for m in lens_mats:
			m.emission_energy_multiplier = 1.4 + 3.0 * k
		if focus_star != null:
			focus_star.visible = full
			focus_star.global_position = center + Vector3(0, 0.01, 0)
			focus_star.scale = Vector3.ONE * (0.9 + 0.2 * sin(_clock * 14.0))
		# Fragmento orbitando a lente (2º acerto) e os da preparação da R.
		var n_orbit := 1 if stacks == 2 and not full else 0
		if charge > 0.05:
			n_orbit = 5
		for i in _orbit.size():
			var o := _orbit[i]
			o.visible = i < n_orbit
			if o.visible:
				var r := 0.09 if charge <= 0.05 else 0.35
				var a := _clock * (7.0 if charge <= 0.05 else 5.0) + TAU * float(i) / 5.0
				var c := (lens_r.global_position if charge <= 0.05 else head_top - Vector3(0, 0.25, 0))
				o.global_position = c + right * cos(a) * r + Vector3.UP * sin(a) * r * 0.6
				o.modulate = Color(FeixeFX.CORE, 0.9)
		for i in segs.size():
			var s := segs[i]
			s.visible = stacks > 0 or full
			s.global_position = head_top + Vector3(0, 0.25, 0)
			if i < stacks or full:
				s.modulate = FeixeFX.CORE if full else FeixeFX.RED
			else:
				s.modulate = Color(0.2, 0.05, 0.07, 0.8)

	func set_stacks(n: int, is_full: bool) -> void:
		stacks = n
		full = is_full
		_flash = 0.35

	func flash(amount: float = 0.6) -> void:
		_flash = maxf(_flash, amount)

	## Foco perdido: o brilho se desfaz em 2–3 pixels que apagam.
	func lose(center: Vector3) -> void:
		if stacks == 0 and not full:
			return
		stacks = 0
		full = false
		FeixeFX.sparks_at(center, Vector3.UP, 3, 1.2, 160.0)


static func lenses(hero: Node3D) -> Lenses:
	var l := Lenses.new()
	hero.add_child(l)
	return l


# ================================================================ Q: Feixe de Contenção

## Raio contínuo: nasce fino, engrossa com a força (o dano que sobe) e ganha
## brasas, faíscas e bandas. Quem chama move o raio com update_beam() todo
## quadro e chama stop() ao soltar.
static func beam(hero: Node3D) -> FeixeFX:
	var fx := _make(hero.global_position, 9999.0)
	fx._beam = fx._beam_layers()
	# Onda circular na origem ao acender.
	var wave := Sprite3D.new()
	wave.texture = _ring_texture()
	wave.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wave.shaded = false
	wave.modulate = Color(PINK, 0.9)
	wave.pixel_size = 0.25 / 256.0
	wave.top_level = true
	fx.add_child(wave)
	var wt := wave.create_tween()
	wt.set_parallel(true)
	wt.tween_property(wave, "scale", Vector3.ONE * 3.0, 0.3)
	wt.tween_property(wave, "modulate:a", 0.0, 0.3)
	wt.chain().tween_callback(wave.queue_free)
	fx.set_meta("wave", wave)
	# Faixa de luz no chão embaixo do feixe (mistura normal, fraca).
	var strip := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	strip.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.albedo_texture = _strip_texture()
	sm.albedo_color = Color(RED, 0.3)
	strip.material_override = sm
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.top_level = true
	fx.add_child(strip)
	fx._floor_strip = strip
	# Brasas soltas ao longo do raio (ficam para trás no mundo).
	fx._embers = fx._particles(160, 0.55, 0.06, false, RED_SPARK_RAMP)
	fx._embers.top_level = true
	var em := fx._embers.process_material as ParticleProcessMaterial
	em.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	em.emission_box_extents = Vector3(0.2, 0.2, 1.0)
	em.spread = 180.0
	em.initial_velocity_min = 0.4
	em.initial_velocity_max = 1.8
	em.gravity = Vector3(0, -2.0, 0)
	em.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	fx._embers.emitting = true
	# Ponta: impacto persistente (estrela, brilho, luz e faíscas).
	fx._splash_glow = fx._glow_sprite(1.6, Color(RED, 0.7))
	fx._splash_glow.top_level = true
	fx.add_child(fx._splash_glow)
	fx._splash_star = Game.laser_flare(hero.global_position, 1.2, 0.0)
	if fx._splash_star != null:
		fx._splash_star.reparent(fx)
	fx._splash_light = fx._light(RED, 2.0)
	fx._splash_light.top_level = true
	fx._splash_sparks = fx._sparks(90, 0.4)
	fx._splash_sparks.top_level = true
	var ss := fx._splash_sparks.process_material as ParticleProcessMaterial
	ss.color_ramp = _ramp(RED_SPARK_RAMP)
	ss.emission_sphere_radius = 0.12
	ss.spread = 80.0
	ss.initial_velocity_min = 3.0
	ss.initial_velocity_max = 8.0
	ss.gravity = Vector3(0, -9.0, 0)
	ss.damping_min = 2.0
	ss.damping_max = 4.0
	fx._splash_sparks.emitting = true
	# Recuo: faíscas raspando no chão atrás do Feixe e linhas de pressão.
	fx._skid = fx._sparks(40, 0.35)
	fx._skid.top_level = true
	var km := fx._skid.process_material as ParticleProcessMaterial
	km.color_ramp = _ramp(RED_SPARK_RAMP)
	km.emission_sphere_radius = 0.25
	km.spread = 35.0
	km.initial_velocity_min = 1.5
	km.initial_velocity_max = 3.5
	km.gravity = Vector3(0, -6.0, 0)
	fx._skid.emitting = true
	fx._push_lines = fx._particles(24, 0.25, 0.05, false, RED_RAMP)
	fx._push_lines.top_level = true
	var plm := fx._push_lines.process_material as ParticleProcessMaterial
	plm.emission_sphere_radius = 0.35
	plm.spread = 8.0
	plm.initial_velocity_min = 4.0
	plm.initial_velocity_max = 6.0
	plm.gravity = Vector3.ZERO
	fx._push_lines.emitting = true
	fx.on_tick = fx._tick_beam
	return fx


static func _strip_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.5, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 4
	return t


## Posição atual do raio (de `from` até `to`), pés do herói, largura visual
## (m) e força de 0 a 1 (brilho e densidade das partículas).
func update_beam(from: Vector3, to: Vector3, feet: Vector3, width: float = 0.5, power: float = 1.0) -> void:
	_from = from
	_to = to
	_width = width
	_power = power
	var d := to - from
	var length := maxf(d.length(), 0.1)
	var dir := d / length
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)
	if has_meta("wave"):
		var w = get_meta("wave")
		if is_instance_valid(w):
			(w as Sprite3D).global_position = from
	if _embers != null:
		_embers.global_transform = Transform3D(basis, (from + to) * 0.5)
		(_embers.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(width * 0.4, width * 0.4, length * 0.5)
		_embers.amount_ratio = 0.25 + 0.75 * power
	var hit := to - dir * 0.12
	if _splash_glow != null:
		_splash_glow.global_position = hit
		_splash_glow.scale = Vector3.ONE * (0.7 + 0.7 * power)
		if is_instance_valid(_splash_star):
			_splash_star.global_position = hit
		_splash_light.global_position = hit - dir * 0.5
		_splash_sparks.global_transform = Transform3D(_basis_y(-dir), hit)
		_splash_sparks.amount_ratio = 0.35 + 0.65 * power
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() > 0.01:
		flat = flat.normalized()
		if _skid != null:
			_skid.global_transform = Transform3D(_basis_y(-flat * 0.8 + Vector3.UP * 0.6), feet + Vector3(0, 0.08, 0) - flat * 0.3)
			_skid.amount_ratio = 0.3 + 0.7 * power
		if _push_lines != null:
			_push_lines.global_transform = Transform3D(_basis_y(-flat), feet + Vector3(0, 1.0, 0) - flat * 0.3)
		if _floor_strip != null:
			var a := Vector3(from.x, feet.y + 0.04, from.z) + flat * 0.6
			var b := Vector3(to.x, feet.y + 0.04, to.z)
			var fl := maxf(Vector2(b.x - a.x, b.z - a.z).length(), 0.1)
			var side := flat.cross(Vector3.UP).normalized()
			_floor_strip.global_transform = Transform3D(Basis(side * width * 1.8, Vector3.UP, -flat * fl), (a + b) * 0.5)


func _tick_beam(age: float, delta: float) -> void:
	var d := _to - _from
	var length := maxf(d.length(), 0.1)
	var dir := d / length
	var fade := 1.0
	if _stopping:
		fade = clampf(1.0 - (age - _stop_age) / 0.14, 0.0, 1.0)
	# Feixe: pulsa de leve; ao soltar, afina e recolhe para os óculos.
	var w := _width * (1.0 + 0.06 * sin(age * 38.0))
	var tip := _to
	if _stopping:
		var k := clampf((age - _stop_age) / 0.14, 0.0, 1.0)
		tip = _to.lerp(_from, k)
		w = _width * (1.0 - 0.8 * k)
	_place_layers(_beam, _from, tip, w, 0.75 + 0.25 * _power if not _stopping else fade)
	if _floor_strip != null:
		(_floor_strip.material_override as StandardMaterial3D).albedo_color.a = (0.14 + 0.16 * _power) * fade
	# Bandas de energia correndo da origem até a ponta (mais com a força).
	_ring_clock += delta
	var every := lerpf(0.16, 0.07, _power)
	if _ring_clock >= every and not _stopping:
		_ring_clock = 0.0
		var ring := _ground_ring(1.0, PINK)
		ring.top_level = true
		_rings.append({"node": ring, "t": 0.0})
	var keep: Array = []
	for r in _rings:
		var node := r["node"] as MeshInstance3D
		r["t"] += delta / 0.35
		var t: float = r["t"]
		if t >= 1.0 or _stopping:
			node.queue_free()
			continue
		var pos := _from + dir * (0.4 + (length - 0.4) * t)
		node.global_transform = Transform3D(_basis_y(dir).scaled(Vector3.ONE * _width * lerpf(1.1, 1.5, t)), pos)
		(node.material_override as StandardMaterial3D).albedo_color.a = (0.35 + 0.3 * _power) * (1.0 - t)
		keep.append(r)
	_rings = keep
	if _splash_glow != null:
		_splash_glow.modulate.a = fade * (0.65 + 0.25 * sin(age * 47.0))
		_splash_light.light_energy = fade * (1.5 + 1.5 * _power + 0.6 * sin(age * 31.0))
		if is_instance_valid(_splash_star):
			_splash_star.modulate.a = fade
			_splash_star.scale = Vector3.ONE * (0.8 + 0.6 * _power + 0.1 * sin(age * 40.0))


## Solta o raio: afina e recolhe para os óculos; as faíscas param.
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	_stop_age = _age
	life = _age + 0.6
	for p in [_embers, _splash_sparks, _skid, _push_lines]:
		if p != null:
			(p as GPUParticles3D).emitting = false
	star(_from, 0.7, 0.12)


## Clarão local e faíscas num inimigo atravessado pelo Q.
static func beam_contact(at: Vector3, dir: Vector3, power: float) -> void:
	star(at, 0.6 + 0.5 * power, 0.12)
	var side := dir.cross(Vector3.UP).normalized()
	var fx := _make(at, 0.6)
	fx._spark_burst(at, side + Vector3.UP * 0.4, int(3 + 6 * power), 4.0 + 3.0 * power, 50.0)
	fx._spark_burst(at, -side + Vector3.UP * 0.4, int(3 + 6 * power), 4.0 + 3.0 * power, 50.0)


# ================================================================ E: Ruptura Óptica

## Um raio só sai dos óculos e abre em leque horizontal de `arc_degrees`, na
## altura do rosto, até `length`. A frente é um arco brilhante contínuo;
## no fim o leque quebra em fragmentos que apagam da ponta para a origem.
static func cone(hero: Node3D, eyes: Vector3, facing: Vector3, length: float, arc_degrees: float) -> void:
	var flat := Vector3(facing.x, 0, facing.z).normalized()
	if flat.length() < 0.1:
		flat = Vector3.FORWARD
	var fx := _make(eyes, 0.95)
	fx.global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP), eyes)
	var half := deg_to_rad(arc_degrees) * 0.5
	star(eyes, 1.4, 0.18)
	# Raio único que sai primeiro (0,06 s) e depois vira leque.
	var core := fx._beam_layers()
	# Leque horizontal na altura do rosto.
	var fan := fx._fan_mesh(half, 1.0, 0.55)
	fx.add_child(fan)
	var fan_mat := fan.material_override as StandardMaterial3D
	# Frente da onda e linhas radiais: fitas redesenhadas a cada quadro.
	var arcs := ImmediateMesh.new()
	var arcs_mi := MeshInstance3D.new()
	arcs_mi.mesh = arcs
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.vertex_color_use_as_albedo = true
	arcs_mi.material_override = am
	arcs_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(arcs_mi)
	var light := fx._light(RED, 2.5)
	light.position = Vector3.ZERO
	light.omni_range = length * 0.8
	# Brasas e faíscas no plano do leque (sem gravidade forte, nada no chão).
	var embers := fx._particles(120, 0.5, 0.06, false, RED_SPARK_RAMP)
	embers.position = Vector3(0, 0, -0.3)
	var em := embers.process_material as ParticleProcessMaterial
	em.direction = Vector3(0, 0, -1)
	em.spread = arc_degrees * 0.5
	em.flatness = 1.0
	em.initial_velocity_min = length * 1.2
	em.initial_velocity_max = length * 2.4
	em.damping_min = length * 2.0
	em.damping_max = length * 3.0
	em.gravity = Vector3(0, -0.6, 0)
	embers.one_shot = true
	embers.explosiveness = 0.8
	embers.emitting = true
	var spk := fx._sparks(60, 0.45)
	spk.position = embers.position
	var sm := spk.process_material as ParticleProcessMaterial
	sm.color_ramp = _ramp(RED_SPARK_RAMP)
	sm.direction = Vector3(0, 0, -1)
	sm.spread = arc_degrees * 0.5
	sm.flatness = 1.0
	sm.initial_velocity_min = length * 2.0
	sm.initial_velocity_max = length * 2.8
	sm.damping_min = length * 2.0
	sm.damping_max = length * 2.6
	sm.gravity = Vector3.ZERO
	spk.one_shot = true
	spk.explosiveness = 0.9
	spk.emitting = true
	const SHOT := 0.06
	const OPEN := 0.14
	const HOLD := 0.14
	const BREAK := 0.4
	var broke := [false]
	fx.on_tick = func(age: float, _dt: float) -> void:
		var fwd := -fx.global_transform.basis.z
		# 1. Raio único para a frente.
		var shot_k := clampf(age / SHOT, 0.0, 1.0)
		var core_a := clampf(1.0 - (age - SHOT) / 0.1, 0.0, 1.0)
		_place_layers(core, eyes, eyes + fwd * length * 0.45 * shot_k, 0.35, core_a)
		# 2. Abre em leque.
		var open := clampf((age - SHOT * 0.5) / OPEN, 0.0, 1.0)
		open = 1.0 - pow(1.0 - open, 3.0)
		var t_break := age - SHOT - OPEN - HOLD
		var a := clampf(1.0 - t_break / BREAK, 0.0, 1.0)
		var reach := length * open
		fan.scale = Vector3(maxf(reach, 0.01), 1.0, maxf(reach, 0.01))
		fan_mat.albedo_color.a = a * (1.0 if open > 0.0 else 0.0)
		light.light_energy = 2.5 * a
		light.position = Vector3(0, 0, -reach * 0.5)
		arcs.clear_surfaces()
		if open > 0.0:
			# Frente brilhante (núcleo + corpo), apaga da ponta para a origem.
			var front := clampf(1.0 - t_break / (BREAK * 0.6), 0.0, 1.0)
			_arc_ribbon(arcs, half, reach, 0.16, Color(CORE, 0.95 * front))
			_arc_ribbon(arcs, half, reach - 0.08, 0.45, Color(RED, 0.65 * front))
			_arc_ribbon(arcs, half, reach - 0.2, 0.6, Color(DEEP, 0.35 * front))
			# Linhas radiais curtas (energia indo para fora).
			_radials(arcs, half, reach, Color(PINK, 0.5 * a))
		# 3. Quebra em fragmentos da ponta para a origem.
		if t_break > 0.0 and not broke[0]:
			broke[0] = true
			fx._fan_break(half, length)


## Linhas radiais curtas dentro do leque.
static func _radials(im: ImmediateMesh, half: float, reach: float, color: Color) -> void:
	if reach < 1.0 or color.a <= 0.0:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 9
	for i in n:
		var ang := -half * 0.9 + 1.8 * half * float(i) / float(n - 1)
		var d := Vector3(sin(ang), 0, -cos(ang))
		var side := Vector3(cos(ang), 0, sin(ang)) * 0.025
		var r0 := reach * (0.5 + 0.08 * float(i % 3))
		var r1 := r0 + reach * 0.18
		var c0 := Color(color, 0.0)
		im.surface_set_color(c0); im.surface_add_vertex(d * r0 - side)
		im.surface_set_color(color); im.surface_add_vertex(d * r1 - side)
		im.surface_set_color(color); im.surface_add_vertex(d * r1 + side)
		im.surface_set_color(c0); im.surface_add_vertex(d * r0 - side)
		im.surface_set_color(color); im.surface_add_vertex(d * r1 + side)
		im.surface_set_color(c0); im.surface_add_vertex(d * r0 + side)
	im.surface_end()


## Fragmentos ao longo do leque, da ponta para a origem: pequenos estouros
## em fileiras (raio 90%, 65%, 40%) com um intervalo curto entre elas.
func _fan_break(half: float, length: float) -> void:
	var rows := [0.9, 0.65, 0.4]
	for ri in rows.size():
		var r: float = length * float(rows[ri])
		var n := 7 - ri * 2
		for i in n:
			var ang := -half * 0.9 + 1.8 * half * float(i) / float(maxi(n - 1, 1))
			var pos := Vector3(sin(ang), 0, -cos(ang)) * r
			var p := _particles(10, 0.35, 0.06, false, RED_SPARK_RAMP)
			p.position = pos
			var pm := p.process_material as ParticleProcessMaterial
			pm.emission_sphere_radius = r * 0.08
			pm.direction = Vector3(sin(ang), 0.3, -cos(ang))
			pm.spread = 45.0
			pm.initial_velocity_min = 0.4
			pm.initial_velocity_max = 1.4
			pm.gravity = Vector3(0, -2.5, 0)
			p.one_shot = true
			p.explosiveness = 0.9
			var tw := create_tween()
			tw.tween_interval(0.07 * float(ri))
			tw.tween_callback(func() -> void: p.emitting = true)


## Leque plano (plano XZ, abrindo para -Z) de raio 1: claro no centro,
## vermelho na frente. A escala do nó dá o alcance.
func _fan_mesh(half: float, alpha: float, edge_alpha: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var segs := 28
	for ri in rings:
		var r0 := float(ri) / float(rings)
		var r1 := float(ri + 1) / float(rings)
		for si in segs:
			var a0 := -half + 2.0 * half * float(si) / float(segs)
			var a1 := -half + 2.0 * half * float(si + 1) / float(segs)
			var p := [
				[r0, a0], [r1, a0], [r1, a1],
				[r0, a0], [r1, a1], [r0, a1],
			]
			for q in p:
				var r: float = q[0]
				var ang: float = q[1]
				var side := clampf((half - absf(ang)) / (half * 0.12), 0.0, 1.0)
				var c := CORE.lerp(RED, clampf(r * 2.2, 0.0, 1.0)).lerp(DEEP, clampf(r * 1.4 - 0.6, 0.0, 1.0))
				c.a = lerpf(alpha, edge_alpha, r) * lerpf(0.5, 1.0, side) * 0.5
				st.set_color(c)
				st.add_vertex(Vector3(sin(ang), 0, -cos(ang)) * r)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.01, 1, 0.01)
	return mi


## Fita em arco (plano XZ, abrindo para -Z) de raio `r` e largura `w`,
## mais forte no meio da largura.
static func _arc_ribbon(im: ImmediateMesh, half: float, r: float, w: float, color: Color) -> void:
	if r <= 0.05 or color.a <= 0.0:
		return
	var segs := 40
	var clear := Color(color, 0.0)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := -half + 2.0 * half * float(i) / float(segs)
		var a1 := -half + 2.0 * half * float(i + 1) / float(segs)
		var d0 := Vector3(sin(a0), 0, -cos(a0))
		var d1 := Vector3(sin(a1), 0, -cos(a1))
		for band in [[r - w * 0.5, r, clear, color], [r, r + w * 0.5, color, clear]]:
			var ri: float = maxf(band[0], 0.0)
			var ro: float = band[1]
			var ci: Color = band[2]
			var co: Color = band[3]
			im.surface_set_color(ci); im.surface_add_vertex(d0 * ri)
			im.surface_set_color(co); im.surface_add_vertex(d0 * ro)
			im.surface_set_color(co); im.surface_add_vertex(d1 * ro)
			im.surface_set_color(ci); im.surface_add_vertex(d0 * ri)
			im.surface_set_color(co); im.surface_add_vertex(d1 * ro)
			im.surface_set_color(ci); im.surface_add_vertex(d1 * ri)
	im.surface_end()


## Inimigo empurrado pelo E: rastro vermelho curto que o acompanha e faíscas
## no sentido do empurrão (drones: sem poeira de chão).
static func push_trail(enemy: Node3D, dir: Vector3, flying: bool) -> void:
	var at := enemy.global_position + Vector3(0, 0.9 if not flying else 0.4, 0)
	star(at, 0.9, 0.14)
	var fx := _make(at, 0.45)
	fx._spark_burst(at, dir + Vector3.UP * 0.2, 8, 6.0, 30.0)
	var trail := fx._particles(30, 0.25, 0.22, false, RED_RAMP)
	trail.top_level = false
	var pm := trail.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = 0.25
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3.ZERO
	trail.emitting = true
	fx.follow = enemy
	fx.follow_offset = Vector3(0, 0.9 if not flying else 0.4, 0)
	fx.on_tick = func(age: float, _dt: float) -> void:
		if age > 0.28:
			trail.emitting = false


# ================================================================ R: Aniquilação Circular

## Marcação (preparação): círculo fino no chão, já cortado pelas paredes.
## `pts` são os pontos do contorno (relativos ao centro).
static func sweep_mark(center: Vector3, pts: PackedVector3Array, _duration: float) -> FeixeFX:
	var fx := _make(center, 9999.0)
	fx._center = center
	fx._outline_pts = pts
	fx._outline = fx._outline_mesh(pts, Color(RED, 0.9), 0.12)
	var mat := fx._outline.material_override as StandardMaterial3D
	fx.on_tick = func(age: float, _dt: float) -> void:
		mat.albedo_color.a = 0.9 * minf(1.0, age / 0.12)
	return fx


func _outline_mesh(pts: PackedVector3Array, color: Color, w: float) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var na := Vector3(a.x, 0, a.z).normalized()
		var nb := Vector3(b.x, 0, b.z).normalized()
		for q in [[a - na * w, a + na * w, b + nb * w], [a - na * w, b + nb * w, b - nb * w]]:
			for v in q:
				im.surface_add_vertex(v)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	mi.global_position = _center + Vector3(0, 0.06, 0)
	return mi


## Varredura: o raio gira em volta do Feixe e deixa no chão um rastro
## contínuo (uma peça só) que apaga suavemente atrás do raio. O Feixe chama
## sweep_to() todo quadro.
static func sweep(hero: Node3D, radius: float, mark: FeixeFX) -> FeixeFX:
	var fx := beam(hero)
	fx._skid.emitting = false
	fx._push_lines.emitting = false
	fx._floor_strip.visible = false
	fx._radius = radius
	fx._center = hero.global_position
	if mark != null:
		fx._outline_pts = mark._outline_pts
		mark.on_tick = Callable()
	var trail := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = trail
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	fx.add_child(mi)
	mi.global_position = fx._center + Vector3(0, 0.05, 0)
	fx._trail = trail
	# Brasas que caem do rastro, logo atrás do raio.
	var drop := fx._particles(140, 0.7, 0.06, false, RED_SPARK_RAMP)
	drop.top_level = true
	var dm := drop.process_material as ParticleProcessMaterial
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dm.emission_box_extents = Vector3(0.1, 0.4, radius * 0.45)
	dm.spread = 180.0
	dm.initial_velocity_min = 0.2
	dm.initial_velocity_max = 0.9
	dm.gravity = Vector3(0, -3.0, 0)
	drop.emitting = true
	fx.set_meta("drop", drop)
	var beam_tick := fx.on_tick
	fx.on_tick = func(age: float, delta: float) -> void:
		beam_tick.call(age, delta)
		fx._tick_trail(age)
	return fx


## Ângulo atual da varredura (yaw) e o ponto onde o raio parou.
func sweep_to(from: Vector3, to: Vector3, yaw: float, feet: Vector3) -> void:
	update_beam(from, to, feet, 0.85, 1.0)
	var reach := Vector2(to.x - _center.x, to.z - _center.z).length()
	# Fatias finas (no máximo 1,5°) para o rastro sair contínuo.
	if not _wedges.is_empty():
		var last: Array = _wedges.back()
		var gap := angle_difference(float(last[0]), yaw)
		var steps := int(ceil(absf(gap) / deg_to_rad(1.5)))
		for i in range(1, steps):
			var t := float(i) / float(steps)
			_wedges.append([float(last[0]) + gap * t, lerpf(float(last[1]), _age, t), lerpf(float(last[2]), reach, t)])
	_wedges.append([yaw, _age, reach])
	var drop = get_meta("drop")
	if is_instance_valid(drop):
		var d := Vector3(to.x - _center.x, 0, to.z - _center.z)
		if d.length() > 0.1:
			var mid := _center + d * 0.5 + Vector3(0, 0.9, 0)
			(drop as GPUParticles3D).global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), mid)
			((drop as GPUParticles3D).process_material as ParticleProcessMaterial).emission_box_extents = Vector3(0.1, 0.5, d.length() * 0.45)


func _tick_trail(age: float) -> void:
	var fade_all := 1.0
	if _stopping:
		fade_all = clampf(1.0 - (age - _stop_age) / 1.2, 0.0, 1.0)
	_trail.clear_surfaces()
	if _wedges.size() < 2:
		return
	_trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, _wedges.size()):
		var w0: Array = _wedges[i - 1]
		var w1: Array = _wedges[i]
		# Forte junto do raio e apagando suave para trás (curva contínua).
		var k0 := _trail_k(age - float(w0[1])) * fade_all
		var k1 := _trail_k(age - float(w1[1])) * fade_all
		if k0 <= 0.0 and k1 <= 0.0:
			continue
		var d0 := Vector3(-sin(float(w0[0])), 0, -cos(float(w0[0])))
		var d1 := Vector3(-sin(float(w1[0])), 0, -cos(float(w1[0])))
		var r0: float = minf(w0[2], _radius)
		var r1: float = minf(w1[2], _radius)
		var in0 := Color(1.0, 0.3, 0.32, 0.22 * k0)
		var in1 := Color(1.0, 0.3, 0.32, 0.22 * k1)
		var out0 := Color(RED, 0.36 * k0)
		var out1 := Color(RED, 0.36 * k1)
		var c0 := Color(RED, 0.05 * k0)
		var c1 := Color(RED, 0.05 * k1)
		for tri in [
			[[c0, Vector3.ZERO], [in0, d0 * r0 * 0.6], [in1, d1 * r1 * 0.6]],
			[[c0, Vector3.ZERO], [in1, d1 * r1 * 0.6], [c1, Vector3.ZERO]],
			[[in0, d0 * r0 * 0.6], [out0, d0 * r0], [out1, d1 * r1]],
			[[in0, d0 * r0 * 0.6], [out1, d1 * r1], [in1, d1 * r1 * 0.6]],
		]:
			for v in tri:
				_trail.surface_set_color(v[0])
				_trail.surface_add_vertex(v[1])
	_trail.surface_end()


static func _trail_k(t: float) -> float:
	# 1 logo atrás do raio, 0,25 depois de 0,5 s, some em ~1,3 s.
	return clampf(exp(-t * 2.6) - 0.03, 0.0, 1.0)


## Fim da varredura: estrela intensa na ponta, faíscas e o círculo apagando
## em ondas; o rastro termina de apagar.
func end_sweep(mark: FeixeFX) -> void:
	var tip := _to
	star(tip, 3.2, 0.45)
	star(tip, 1.8, 0.6)
	_spark_burst(tip, Vector3.UP, 24, 7.0, 180.0)
	stop()
	life = _age + 1.3
	if mark != null and is_instance_valid(mark):
		var pts := mark._outline_pts
		var center := mark._center
		mark.queue_free()
		var waves := _make(center, 1.2)
		waves._center = center
		var rings: Array = []
		for s in [1.0, 0.86, 0.72]:
			var scaled := PackedVector3Array()
			for p in pts:
				scaled.append(p * s)
			rings.append(waves._outline_mesh(scaled, Color(RED, 0.8), 0.1))
		waves.on_tick = func(age: float, _dt: float) -> void:
			for i in rings.size():
				var mi := rings[i] as MeshInstance3D
				var k := clampf((age - 0.12 * float(i)) / 0.6, 0.0, 1.0)
				(mi.material_override as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - k) * (0.5 if i > 0 else 1.0)


## Cada inimigo atingido pela R: flash branco-vermelho e faíscas no corpo.
static func sweep_hit(at: Vector3, dir: Vector3) -> void:
	star(at, 1.3, 0.2)
	var fx := _make(at, 0.6)
	fx._spark_burst(at, dir + Vector3.UP * 0.5, 14, 6.0, 70.0)


# ================================================================ Dash

## Dash do Feixe: flash nos óculos, 2–3 silhuetas vermelhas curtas e um
## flash discreto na chegada (sem trilha longa).
static func dash_ghost(at: Vector3, facing: Vector3, alpha: float) -> void:
	var fx := _make(at, 0.22)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.75
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(RED, alpha)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)
	mi.position = Vector3(0, 0.9, 0)
	fx.global_transform.basis = Basis.looking_at(facing if facing.length() > 0.1 else Vector3.FORWARD, Vector3.UP)
	fx.on_tick = func(age: float, _dt: float) -> void:
		m.albedo_color.a = alpha * clampf(1.0 - age / 0.2, 0.0, 1.0)


## Base cujo eixo Y aponta para `d` (emissores de partículas saem em +Y).
static func _basis_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
