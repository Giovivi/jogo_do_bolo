class_name FeixeFX
extends FenixFX
## Efeitos de raio vermelho do Feixe (prancha feixe-animacoes-v1): faíscas
## girando em volta do Raio Forte, anéis de pressão e respingo onde bate, o
## leque liso do Cone de Raios e a varredura da Suprema com rastro no chão.

const RED_RAMP := [
	[0.0, Color(1.0, 0.8, 0.72, 0.42)],
	[0.3, Color(1.0, 0.3, 0.18, 0.36)],
	[0.7, Color(0.75, 0.06, 0.03, 0.18)],
	[1.0, Color(0.3, 0.0, 0.0, 0.0)],
]
const RED_SPARK_RAMP := [
	[0.0, Color(1.0, 0.96, 0.92, 1.0)],
	[0.45, Color(1.0, 0.5, 0.35, 0.9)],
	[1.0, Color(0.85, 0.05, 0.02, 0.0)],
]
const RED := Color(1.0, 0.22, 0.14)
const PINK := Color(1.0, 0.72, 0.66)
## Pontos de cada fio da espiral e quantos fios.
const HELIX_POINTS := 18
const HELIX_STRANDS := 2

## Estado do efeito que acompanha um raio (Q) ou a varredura (R).
var _from := Vector3.ZERO
var _to := Vector3.FORWARD
var _helix: Array[Sprite3D] = []
var _rings: Array = []
var _ring_clock: float = 0.0
var _embers: GPUParticles3D
var _splash_glow: Sprite3D
var _splash_light: OmniLight3D
var _splash_sparks: GPUParticles3D
var _splash_flames: GPUParticles3D
var _skid: GPUParticles3D
var _stopping: bool = false
var _stop_age: float = 0.0
## Varredura da Suprema: fatias [yaw, idade, alcance] por onde o raio passou.
var _wedges: Array = []
var _radius: float = 14.0
var _outline: MeshInstance3D
var _trail: ImmediateMesh


static func _make(at: Vector3, life_s: float) -> FeixeFX:
	var fx := FeixeFX.new()
	fx.life = life_s
	var root: Node = Game.world_root if Game.world_root != null else Engine.get_main_loop().root
	root.add_child(fx)
	fx.global_position = at
	return fx


# ================================================================ Q: Raio Forte

## Faíscas, anéis e respingo de um raio contínuo. Quem chama move o raio com
## update_beam() todo quadro e chama stop() ao soltar.
static func beam(hero: Node3D) -> FeixeFX:
	var fx := _make(hero.global_position, 9999.0)
	# Clarão no chão ao acender.
	fx._shockwave(3.0, 0.35, RED)
	for s in HELIX_POINTS * HELIX_STRANDS:
		var sp := fx._glow_sprite(0.22 if s % 3 else 0.34, Color(1.0, 0.55, 0.45, 0.85))
		sp.top_level = true
		fx.add_child(sp)
		fx._helix.append(sp)
	# Brasas soltas ao longo do raio (ficam para trás no mundo).
	fx._embers = fx._particles(90, 0.55, 0.09, false, RED_SPARK_RAMP)
	fx._embers.top_level = true
	var pm := fx._embers.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.2, 0.2, 1.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	fx._embers.emitting = true
	# Respingo onde o raio bate.
	fx._splash_glow = fx._glow_sprite(2.4, Color(1.0, 0.35, 0.25, 0.8))
	fx._splash_glow.top_level = true
	fx.add_child(fx._splash_glow)
	fx._splash_light = fx._light(RED, 2.2)
	fx._splash_light.top_level = true
	fx._splash_sparks = fx._sparks(70, 0.4)
	fx._splash_sparks.top_level = true
	var sm := fx._splash_sparks.process_material as ParticleProcessMaterial
	sm.color_ramp = _ramp(RED_SPARK_RAMP)
	sm.emission_sphere_radius = 0.15
	sm.spread = 75.0
	sm.initial_velocity_min = 3.0
	sm.initial_velocity_max = 8.0
	sm.gravity = Vector3(0, -9.0, 0)
	sm.damping_min = 2.0
	sm.damping_max = 4.0
	fx._splash_sparks.emitting = true
	fx._splash_flames = fx._particles(40, 0.3, 0.7, false, RED_RAMP)
	fx._splash_flames.top_level = true
	var fm := fx._splash_flames.process_material as ParticleProcessMaterial
	fm.spread = 80.0
	fm.initial_velocity_min = 1.0
	fm.initial_velocity_max = 3.0
	fm.gravity = Vector3.ZERO
	fx._splash_flames.emitting = true
	# Faíscas raspando no chão: ele escorrega para trás com o tranco do raio.
	fx._skid = fx._sparks(26, 0.35)
	fx._skid.top_level = true
	var km := fx._skid.process_material as ParticleProcessMaterial
	km.color_ramp = _ramp(RED_SPARK_RAMP)
	km.emission_sphere_radius = 0.25
	km.spread = 35.0
	km.initial_velocity_min = 1.5
	km.initial_velocity_max = 3.5
	km.gravity = Vector3(0, -6.0, 0)
	fx._skid.emitting = true
	fx.on_tick = fx._tick_beam
	return fx


## Posição atual do raio (de `from` até `to`) e dos pés do herói.
func update_beam(from: Vector3, to: Vector3, feet: Vector3, power: float = 1.0) -> void:
	_from = from
	_to = to
	var d := to - from
	var length := maxf(d.length(), 0.1)
	var dir := d / length
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)
	if _embers != null:
		_embers.global_transform = Transform3D(basis, (from + to) * 0.5)
		(_embers.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(0.22, 0.22, length * 0.5)
	# O respingo fica um pouco antes da parede/inimigo, virado para o Feixe.
	var hit := to - dir * 0.15
	if _splash_glow != null:
		_splash_glow.global_position = hit
		_splash_light.global_position = hit - dir * 0.5
		_splash_sparks.global_transform = Transform3D(_basis_y(-dir), hit)
		_splash_flames.global_transform = Transform3D(_basis_y(-dir), hit)
		_splash_glow.scale = Vector3.ONE * power
	if _skid != null:
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		_skid.global_transform = Transform3D(_basis_y(flat * 0.8 + Vector3.UP * 0.6), feet + Vector3(0, 0.08, 0) + flat * 0.3)


func _tick_beam(age: float, delta: float) -> void:
	var d := _to - _from
	var length := maxf(d.length(), 0.1)
	var dir := d / length
	var u := dir.cross(Vector3.UP)
	if u.length() < 0.1:
		u = dir.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := u.cross(dir).normalized()
	var fade := 1.0
	if _stopping:
		fade = clampf(1.0 - (age - _stop_age) / 0.25, 0.0, 1.0)
	# Faíscas em espiral: dois fios que correm do rosto até a ponta, girando.
	for i in _helix.size():
		var strand := i / HELIX_POINTS
		var k := float(i % HELIX_POINTS) / float(HELIX_POINTS)
		var t := fposmod(k + age * 1.6, 1.0)
		var phase := t * length * 1.6 - age * 14.0 + PI * float(strand)
		var r := 0.32 + 0.1 * sin(age * 9.0 + k * 11.0)
		var sp := _helix[i]
		sp.global_position = _from + dir * (length * t) + (u * cos(phase) + v * sin(phase)) * r
		sp.modulate.a = fade * clampf(t * 8.0, 0.0, 1.0) * clampf((1.0 - t) * 8.0, 0.0, 1.0)
	# Anéis de pressão: nascem no rosto e correm até a ponta abrindo.
	_ring_clock += delta
	if _ring_clock >= 0.14 and not _stopping:
		_ring_clock = 0.0
		var ring := _ground_ring(1.0, PINK)
		ring.top_level = true
		_rings.append({"node": ring, "t": 0.0})
	var keep: Array = []
	for r in _rings:
		var node := r["node"] as MeshInstance3D
		r["t"] += delta / 0.4
		var t: float = r["t"]
		if t >= 1.0:
			node.queue_free()
			continue
		var pos := _from + dir * (0.6 + (length - 0.6) * t)
		# O plano do anel fica de pé, atravessado pelo raio.
		var b := _basis_y(dir)
		node.global_transform = Transform3D(b.scaled(Vector3.ONE * lerpf(0.6, 1.6, t)), pos)
		(node.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - t) * fade
		keep.append(r)
	_rings = keep
	if _splash_glow != null:
		_splash_glow.modulate.a = fade * (0.75 + 0.25 * sin(age * 47.0))
		_splash_light.light_energy = fade * (2.0 + 0.8 * sin(age * 31.0))


## Solta o raio: as faíscas somem e o nó se apaga sozinho.
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	_stop_age = _age
	life = _age + 0.5
	for p in [_embers, _splash_sparks, _splash_flames, _skid]:
		if p != null:
			(p as GPUParticles3D).emitting = false


## Clique (Raio Laser): as mesmas faíscas em menor, num tiro só.
static func shot(from: Vector3, to: Vector3) -> void:
	var fx := _make(to, 0.45)
	var d := to - from
	var length := maxf(d.length(), 0.1)
	var dir := d / length
	var u := dir.cross(Vector3.UP)
	if u.length() < 0.1:
		u = Vector3.RIGHT
	u = u.normalized()
	var v := u.cross(dir).normalized()
	var n := 10
	var sprites: Array[Sprite3D] = []
	for i in n:
		var sp := fx._glow_sprite(0.14, Color(1.0, 0.55, 0.45, 0.8))
		sp.top_level = true
		fx.add_child(sp)
		var t := float(i + 1) / float(n + 1)
		var ph := t * length * 1.8
		sp.global_position = from + dir * (length * t) + (u * cos(ph) + v * sin(ph)) * 0.16
		sprites.append(sp)
	var glow := fx._glow_sprite(1.0, Color(1.0, 0.4, 0.3, 0.8))
	fx.add_child(glow)
	var sparks := fx._sparks(14, 0.3)
	var sm := sparks.process_material as ParticleProcessMaterial
	sm.color_ramp = _ramp(RED_SPARK_RAMP)
	sm.emission_sphere_radius = 0.08
	sm.spread = 70.0
	sm.initial_velocity_min = 2.0
	sm.initial_velocity_max = 5.0
	sm.gravity = Vector3(0, -9.0, 0)
	sparks.transform = Transform3D(_basis_y(-dir), Vector3.ZERO)
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.emitting = true
	fx.on_tick = func(age: float, _dt: float) -> void:
		var a := clampf(1.0 - age / 0.2, 0.0, 1.0)
		for sp in sprites:
			sp.modulate.a = 0.8 * a
		glow.modulate.a = 0.8 * a
		glow.scale = Vector3.ONE * (1.0 + age * 3.0)


# ================================================================ E: Cone de Raios

## Leque liso de energia que se abre dos óculos até `length`, com a borda
## acesa, ondas correndo para fora e brasas.
static func cone(hero: Node3D, eyes: Vector3, facing: Vector3, length: float, arc_degrees: float) -> void:
	var flat := Vector3(facing.x, 0, facing.z).normalized()
	if flat.length() < 0.1:
		flat = Vector3.FORWARD
	var fx := _make(hero.global_position, 0.9)
	fx.global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP), hero.global_position)
	var half := deg_to_rad(arc_degrees) * 0.5
	var eye_h := eyes.y - hero.global_position.y
	# Leque que sai dos óculos e desce até perto do chão no fim.
	var tilt := atan2(eye_h - 0.35, length)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, eye_h, 0)
	pivot.rotation.x = -tilt
	fx.add_child(pivot)
	var fan := fx._fan_mesh(half, 1.0, 0.75)
	pivot.add_child(fan)
	# Leque refletido no chão, mais fraco.
	var ground := fx._fan_mesh(half, 0.45, 0.45)
	fx.add_child(ground)
	ground.position = Vector3(0, 0.07, 0)
	# Borda e ondas: fitas em arco redesenhadas a cada quadro.
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
	pivot.add_child(arcs_mi)
	var light := fx._light(RED, 3.0)
	light.omni_range = length
	# Brasas e faíscas jogadas para dentro do leque.
	var embers := fx._particles(110, 0.55, 0.5, false, RED_RAMP)
	embers.position = Vector3(0, eye_h * 0.6, -0.3)
	var em := embers.process_material as ParticleProcessMaterial
	em.direction = Vector3(0, 0, -1)
	em.spread = arc_degrees * 0.5
	em.flatness = 0.85
	em.initial_velocity_min = length * 1.6
	em.initial_velocity_max = length * 2.4
	em.damping_min = length * 2.4
	em.damping_max = length * 3.2
	em.gravity = Vector3(0, -1.0, 0)
	embers.one_shot = true
	embers.explosiveness = 0.85
	embers.emitting = true
	var sparks := fx._sparks(70, 0.6)
	sparks.position = embers.position
	var sm := sparks.process_material as ParticleProcessMaterial
	sm.color_ramp = _ramp(RED_SPARK_RAMP)
	sm.direction = Vector3(0, 0, -1)
	sm.spread = arc_degrees * 0.5
	sm.flatness = 0.6
	sm.initial_velocity_min = length * 1.4
	sm.initial_velocity_max = length * 2.6
	sm.damping_min = length * 1.6
	sm.damping_max = length * 2.4
	sm.gravity = Vector3(0, -3.0, 0)
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.emitting = true
	var fan_mat := fan.material_override as StandardMaterial3D
	var ground_mat := ground.material_override as StandardMaterial3D
	const OPEN := 0.16
	const HOLD := 0.18
	const FADE := 0.45
	fx.on_tick = func(age: float, _dt: float) -> void:
		var open := clampf(age / OPEN, 0.0, 1.0)
		open = 1.0 - pow(1.0 - open, 3.0)
		var a := clampf(1.0 - (age - OPEN - HOLD) / FADE, 0.0, 1.0)
		var reach := length * open
		fan.scale = Vector3(reach, 1.0, reach)
		ground.scale = Vector3(reach, 1.0, reach) * Vector3(1, 1, cos(tilt))
		fan_mat.albedo_color.a = a
		ground_mat.albedo_color.a = a
		light.light_energy = 3.0 * a
		light.position = Vector3(0, 1.0, -reach * 0.5)
		arcs.clear_surfaces()
		# Borda da frente acesa.
		_arc_ribbon(arcs, half, reach, 0.38, Color(1.0, 0.85, 0.8, 0.95 * a))
		_arc_ribbon(arcs, half, reach - 0.12, 0.7, Color(1.0, 0.25, 0.15, 0.5 * a))
		# Ondas correndo para fora depois de aberto.
		for k in 3:
			var w := (age - OPEN * 0.6 - 0.09 * float(k)) / 0.35
			if w > 0.0 and w < 1.0:
				_arc_ribbon(arcs, half, length * (0.2 + 0.8 * w), 0.16, Color(1.0, 0.7, 0.62, 0.7 * (1.0 - w) * a))


## Leque plano (no plano XZ, abrindo para -Z) de raio 1, claro no centro e
## vermelho nas pontas. A escala do nó dá o alcance.
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
				# Lados suaves: some um pouco perto das beiradas do leque.
				var side := clampf((half - absf(ang)) / (half * 0.18), 0.0, 1.0)
				var c := PINK.lerp(RED, clampf(r * 1.3, 0.0, 1.0))
				c.a = lerpf(alpha, edge_alpha, r) * lerpf(0.45, 1.0, side) * 0.55
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
	var segs := 32
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


# ================================================================ R: Suprema

## Varredura: o raio longo gira em volta do Feixe e o chão por onde ele passa
## fica vermelho e vai apagando. O Feixe chama sweep_to() todo quadro.
static func sweep(hero: Node3D, radius: float) -> FeixeFX:
	var fx := beam(hero)
	fx._skid.emitting = false
	fx._radius = radius
	# Contorno fino do alcance no chão.
	var outline := MeshInstance3D.new()
	var ring := ImmediateMesh.new()
	_arc_ribbon(ring, PI, radius, 0.25, Color(1.0, 0.3, 0.2, 0.8))
	outline.mesh = ring
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	om.cull_mode = BaseMaterial3D.CULL_DISABLED
	om.vertex_color_use_as_albedo = true
	outline.material_override = om
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.top_level = true
	fx.add_child(outline)
	outline.global_position = hero.global_position + Vector3(0, 0.06, 0)
	fx._outline = outline
	var trail := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = trail
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Mistura normal (não somada): o chão fica vermelho de verdade, não rosado.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	fx.add_child(mi)
	mi.global_position = hero.global_position + Vector3(0, 0.05, 0)
	fx._trail = trail
	var beam_tick := fx.on_tick
	fx.on_tick = func(age: float, delta: float) -> void:
		beam_tick.call(age, delta)
		fx._tick_trail(age)
	return fx


## Ângulo atual da varredura (yaw) e o ponto onde o raio parou.
func sweep_to(from: Vector3, to: Vector3, yaw: float, feet: Vector3) -> void:
	update_beam(from, to, feet, 1.3)
	var center := _trail_center()
	var reach := Vector2(to.x - center.x, to.z - center.z).length()
	_wedges.append([yaw, _age, reach])


func _trail_center() -> Vector3:
	return _outline.global_position


func _tick_trail(age: float) -> void:
	var trail := _trail
	var wedges := _wedges
	var radius := _radius
	var outline := _outline
	var fade_all := 1.0
	if _stopping:
		fade_all = clampf(1.0 - (age - _stop_age) / 1.4, 0.0, 1.0)
	(outline.material_override as StandardMaterial3D).albedo_color.a = minf(1.0, age / 0.15) * fade_all
	trail.clear_surfaces()
	if wedges.size() < 2:
		return
	trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, wedges.size()):
		var w0: Array = wedges[i - 1]
		var w1: Array = wedges[i]
		var k0 := clampf(1.0 - (age - float(w0[1])) / 1.3, 0.0, 1.0)
		var k1 := clampf(1.0 - (age - float(w1[1])) / 1.3, 0.0, 1.0)
		if k0 <= 0.0 and k1 <= 0.0:
			continue
		var d0 := Vector3(-sin(float(w0[0])), 0, -cos(float(w0[0])))
		var d1 := Vector3(-sin(float(w1[0])), 0, -cos(float(w1[0])))
		var r0: float = minf(w0[2], radius)
		var r1: float = minf(w1[2], radius)
		var c0 := Color(0.9, 0.04, 0.02, 0.5 * k0 * k0 * fade_all)
		var c1 := Color(0.9, 0.04, 0.02, 0.5 * k1 * k1 * fade_all)
		var mid0 := Color(1.0, 0.16, 0.08, 0.4 * k0 * k0 * fade_all)
		var mid1 := Color(1.0, 0.16, 0.08, 0.4 * k1 * k1 * fade_all)
		# Dois anéis por fatia: centro mais claro, borda vermelha.
		trail.surface_set_color(mid0); trail.surface_add_vertex(Vector3.ZERO)
		trail.surface_set_color(mid0); trail.surface_add_vertex(d0 * r0 * 0.5)
		trail.surface_set_color(mid1); trail.surface_add_vertex(d1 * r1 * 0.5)
		trail.surface_set_color(mid0); trail.surface_add_vertex(d0 * r0 * 0.5)
		trail.surface_set_color(c0); trail.surface_add_vertex(d0 * r0)
		trail.surface_set_color(c1); trail.surface_add_vertex(d1 * r1)
		trail.surface_set_color(mid0); trail.surface_add_vertex(d0 * r0 * 0.5)
		trail.surface_set_color(c1); trail.surface_add_vertex(d1 * r1)
		trail.surface_set_color(mid1); trail.surface_add_vertex(d1 * r1 * 0.5)
	trail.surface_end()


## Fim da varredura: o raio some e o rastro termina de apagar.
func end_sweep() -> void:
	stop()
	life = _age + 1.4


## Base cujo eixo Y aponta para `d` (emissores de partículas saem em +Y).
static func _basis_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
