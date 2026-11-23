class_name FenixFX
extends Node3D
## Efeitos de fogo azul e dourado das habilidades do Fênix (prancha
## fenix-animacoes-fogo-v1): carga e salto da suprema, a ave de fogo, o
## impacto, a cura que suga o fogo e as Asas de Fogo.
## Cada efeito é um nó solto no mundo que se apaga sozinho depois de `life` s.

# Transparência baixa de propósito: as chamas são somadas (blend add) e muitas
# se sobrepõem; com alfa alto tudo vira um borrão branco.
const BLUE_RAMP := [
	[0.0, Color(0.45, 0.75, 1.0, 0.4)],
	[0.2, Color(0.15, 0.5, 1.0, 0.36)],
	[0.55, Color(0.06, 0.22, 0.9, 0.22)],
	[1.0, Color(0.02, 0.05, 0.4, 0.0)],
]
const GOLD_RAMP := [
	[0.0, Color(1.0, 0.85, 0.5, 0.4)],
	[0.3, Color(1.0, 0.55, 0.12, 0.36)],
	[0.7, Color(0.8, 0.25, 0.02, 0.18)],
	[1.0, Color(0.4, 0.08, 0.0, 0.0)],
]
const SPARK_RAMP := [
	[0.0, Color(1.0, 0.95, 0.8, 1.0)],
	[0.5, Color(1.0, 0.75, 0.3, 0.9)],
	[1.0, Color(0.4, 0.6, 1.0, 0.0)],
]
const BLUE := Color(0.35, 0.7, 1.0)
const GOLD := Color(1.0, 0.72, 0.25)

## Segue este nó (posição) enquanto vive.
var follow: Node3D
var follow_offset := Vector3.ZERO
var life: float = 1.0
var _age: float = 0.0
## Chamado todo quadro com (idade, delta).
var on_tick: Callable

static var _flame_tex: Texture2D
static var _soft_tex: Texture2D
static var _ring_tex: Texture2D


func _process(delta: float) -> void:
	_age += delta
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position + follow_offset
	if on_tick.is_valid():
		on_tick.call(_age, delta)
	if _age >= life:
		queue_free()


static func _spawn(at: Vector3, life_s: float) -> FenixFX:
	var fx := FenixFX.new()
	fx.life = life_s
	var root: Node = Game.world_root if Game.world_root != null else Engine.get_main_loop().root
	root.add_child(fx)
	fx.global_position = at
	return fx


# ================================================================ R: carga

## Agachado fazendo força: anel de fogo nos pés que cresce, chamas subindo,
## brasas e luz pulsando cada vez mais forte.
static func charge(hero: Node3D, duration: float) -> void:
	var fx := _spawn(hero.global_position, duration + 0.6)
	fx.follow = hero
	var ring := fx._ground_ring(1.0, BLUE)
	var flames := fx._particles(260, 0.6, 0.85, true, BLUE_RAMP)
	var pm := flames.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.1
	pm.emission_ring_inner_radius = 0.6
	pm.emission_ring_height = 0.05
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.2
	pm.radial_accel_min = -3.0
	pm.radial_accel_max = -1.5
	flames.emitting = true
	var core := fx._particles(90, 0.5, 0.8, true, GOLD_RAMP)
	(core.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.3
	(core.process_material as ParticleProcessMaterial).initial_velocity_max = 2.5
	core.emitting = true
	var sparks := fx._sparks(60, 0.8)
	sparks.emitting = true
	var light := fx._light(BLUE, 1.0)
	fx.on_tick = func(t: float, _d: float) -> void:
		var k := clampf(t / duration, 0.0, 1.0)
		ring.scale = Vector3.ONE * lerpf(1.2, 2.8, k)
		(ring.material_override as StandardMaterial3D).albedo_color = Color(BLUE, (0.3 + 0.35 * k) if t < duration else maxf(0.0, 1.0 - (t - duration) * 4.0))
		flames.amount_ratio = lerpf(0.4, 1.0, k)
		light.light_energy = (0.6 + 1.8 * k) * (0.8 + 0.2 * sin(t * 40.0)) if t < duration else maxf(0.0, 2.4 - (t - duration) * 8.0)
		var on := t < duration
		flames.emitting = on
		core.emitting = on
		sparks.emitting = on


# ================================================================ R: salto

## Coluna de fogo que fica para trás quando ele sobe e sai da tela.
static func launch(at: Vector3) -> void:
	var fx := _spawn(at, 1.4)
	var column := fx._particles(220, 0.7, 1.0, true, BLUE_RAMP)
	var pm := column.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 18.0
	pm.damping_min = 4.0
	pm.damping_max = 8.0
	column.one_shot = true
	column.explosiveness = 0.75
	column.emitting = true
	var gold := fx._particles(70, 0.6, 0.8, true, GOLD_RAMP)
	var gm := gold.process_material as ParticleProcessMaterial
	gm.direction = Vector3.UP
	gm.spread = 5.0
	gm.initial_velocity_min = 8.0
	gm.initial_velocity_max = 14.0
	gold.one_shot = true
	gold.explosiveness = 0.8
	gold.emitting = true
	fx._shockwave(3.2, 0.45, BLUE)
	fx._radial_burst(90, 2.6, 0.55, BLUE_RAMP)
	var s := fx._sparks(80, 1.0)
	(s.process_material as ParticleProcessMaterial).initial_velocity_max = 9.0
	s.one_shot = true
	s.explosiveness = 0.9
	s.emitting = true
	var light := fx._light(BLUE, 3.0)
	fx.on_tick = func(t: float, _d: float) -> void:
		light.light_energy = maxf(0.0, 3.0 - t * 5.0)


# ================================================================ R: a ave de fogo

## A fênix de fogo desce do alto da tela até `dest` em `duration` s.
## Devolve o nó da ave (some sozinho logo depois de chegar).
static func phoenix(dest: Vector3, duration: float) -> FenixFX:
	var axes := Game.screen_axes()
	var screen_up: Vector3 = axes[0]
	var start := dest + Vector3.UP * 11.0 + screen_up * 5.0
	var fx := _spawn(start, duration + 0.05)
	var bird := Node3D.new()
	fx.add_child(bird)
	var dir := (dest + Vector3.UP * 0.6 - start).normalized()
	# A ave olha para onde mergulha (-Z do nó = frente).
	bird.basis = Basis.looking_at(dir, Vector3.UP)
	bird.scale = Vector3.ONE * 2.2
	# corpo e cabeça
	var core := fx._glow_sprite(0.8, Color(0.25, 0.55, 1.0, 0.55))
	bird.add_child(core)
	var head := fx._glow_sprite(0.35, Color(1.0, 0.75, 0.35, 0.7))
	head.position = Vector3(0, 0.05, -0.55)
	bird.add_child(head)
	for i in 5:
		var f := fx._feather(0.9 - i * 0.08, 0.28, BLUE if i % 2 == 0 else GOLD)
		f.position = Vector3(0, 0, -0.4)
		f.rotation = Vector3(deg_to_rad(90.0 + randf_range(-10, 10)), deg_to_rad(randf_range(-12, 12)), 0)
		bird.add_child(f)
	# crista dourada
	for i in 3:
		var c := fx._feather(0.4, 0.12, GOLD)
		c.position = Vector3(0, 0.1, -0.55)
		c.rotation = Vector3(deg_to_rad(40.0), deg_to_rad((i - 1) * 18.0), 0)
		bird.add_child(c)
	# asas: penas presas ao longo da asa, mais longas na ponta
	var wings: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.12 * side, 0.05, -0.2)
		bird.add_child(pivot)
		fx._build_wing(pivot, side, 1.9, 13)
		wings.append(pivot)
	# cauda longa
	for i in 7:
		var f := fx._feather(randf_range(1.4, 2.0), 0.26, BLUE)
		f.position = Vector3(0, 0, 0.3)
		f.rotation = Vector3(deg_to_rad(90.0), deg_to_rad((i - 3) * 9.0), 0)
		bird.add_child(f)
	# rastro de fogo no mundo
	var trail := fx._particles(400, 0.5, 1.1, true, BLUE_RAMP)
	var tm := trail.process_material as ParticleProcessMaterial
	tm.emission_sphere_radius = 0.9
	tm.initial_velocity_max = 1.0
	trail.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	trail.emitting = true
	var gold_trail := fx._particles(150, 0.4, 0.8, true, GOLD_RAMP)
	(gold_trail.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.5
	gold_trail.visibility_aabb = trail.visibility_aabb
	gold_trail.emitting = true
	var sparks := fx._sparks(120, 0.9)
	sparks.visibility_aabb = trail.visibility_aabb
	sparks.emitting = true
	var light := fx._light(BLUE, 2.5)
	light.omni_range = 6.0
	fx.on_tick = func(t: float, _d: float) -> void:
		var k := clampf(t / duration, 0.0, 1.0)
		# acelera no fim, como um mergulho
		fx.global_position = start.lerp(dest + Vector3.UP * 0.6, k * k * (1.6 - 0.6 * k))
		var flap := sin(t * 22.0) * 0.45
		wings[0].rotation = Vector3(0, 0, -flap)
		wings[1].rotation = Vector3(0, 0, flap)
		trail.global_position = fx.global_position
		gold_trail.global_position = fx.global_position
		sparks.global_position = fx.global_position
	return fx


# ================================================================ R: impacto

## Pousa: anel de fogo até `radius`, chamas jogadas para os lados, colunas de
## fogo na borda, brasas, clarão e tremor.
static func impact(at: Vector3, radius: float) -> void:
	var fx := _spawn(at, 2.2)
	fx._shockwave(radius * 2.0, 0.4, BLUE)
	fx._shockwave(radius * 1.2, 0.3, GOLD)
	var scorch := fx._ground_ring(radius * 2.0, BLUE, true)
	# chamas jogadas para os lados, rente ao chão, até a borda
	fx._radial_burst(260, radius, 0.6, BLUE_RAMP, 1.6)
	fx._radial_burst(60, radius * 0.7, 0.5, GOLD_RAMP, 1.2)
	# colunas de fogo que sobem na borda do anel, logo depois
	var edge := fx._particles(260, 0.9, 1.4, true, BLUE_RAMP)
	var em := edge.process_material as ParticleProcessMaterial
	em.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	em.emission_ring_axis = Vector3.UP
	em.emission_ring_radius = radius
	em.emission_ring_inner_radius = radius * 0.8
	em.emission_ring_height = 0.1
	em.direction = Vector3.UP
	em.spread = 10.0
	em.initial_velocity_min = 3.0
	em.initial_velocity_max = 7.0
	em.damping_min = 2.0
	em.damping_max = 4.0
	edge.one_shot = true
	edge.explosiveness = 0.6
	# coluna dourada no centro
	var pillar := fx._particles(50, 0.8, 1.2, true, GOLD_RAMP)
	var pmat := pillar.process_material as ParticleProcessMaterial
	pmat.emission_sphere_radius = 0.6
	pmat.direction = Vector3.UP
	pmat.spread = 15.0
	pmat.initial_velocity_min = 4.0
	pmat.initial_velocity_max = 9.0
	pillar.one_shot = true
	pillar.explosiveness = 0.85
	pillar.emitting = true
	var pillar2 := fx._particles(70, 0.9, 1.4, true, BLUE_RAMP)
	var pm2 := pillar2.process_material as ParticleProcessMaterial
	pm2.emission_sphere_radius = 1.0
	pm2.direction = Vector3.UP
	pm2.spread = 25.0
	pm2.initial_velocity_min = 3.0
	pm2.initial_velocity_max = 7.0
	pillar2.one_shot = true
	pillar2.explosiveness = 0.8
	pillar2.emitting = true
	var s := fx._sparks(200, 1.4)
	var sm := s.process_material as ParticleProcessMaterial
	sm.spread = 80.0
	sm.initial_velocity_min = 3.0
	sm.initial_velocity_max = 10.0
	sm.gravity = Vector3(0, -4.0, 0)
	s.one_shot = true
	s.explosiveness = 0.9
	s.emitting = true
	var light := fx._light(BLUE, 5.0)
	light.omni_range = radius * 2.2
	# Estado guardado num dicionário: a função anônima recebe cópias das variáveis.
	var state := {"edge": false}
	fx.on_tick = func(t: float, _d: float) -> void:
		light.light_energy = maxf(0.0, 5.0 - t * 6.0)
		(scorch.material_override as StandardMaterial3D).albedo_color = Color(BLUE, clampf(0.25 - t * 0.15, 0.0, 1.0))
		if not state["edge"] and t > 0.12:
			state["edge"] = true
			edge.emitting = true
	Game.shake(0.5, 0.45)


# ================================================================ E: cura (suga o fogo)

## Fogo vindo de longe e entrando em espiral no peito do Fênix por `duration` s;
## no fim o peito acende e solta a cura. `target` != hero: um fio de fogo vai até o aliado.
static func absorb(hero: Node3D, duration: float) -> void:
	var fx := _spawn(hero.global_position, duration + 1.4)
	fx.follow = hero
	var chest := Vector3(0, 1.3, 0)
	# chamas no chão em volta, que somem quando são puxadas
	var floor_ring := fx._particles(160, 0.5, 0.75, true, BLUE_RAMP)
	var fm := floor_ring.process_material as ParticleProcessMaterial
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fm.emission_ring_axis = Vector3.UP
	fm.emission_ring_radius = 2.8
	fm.emission_ring_inner_radius = 2.2
	fm.emission_ring_height = 0.05
	fm.direction = Vector3.UP
	fm.spread = 10.0
	fm.initial_velocity_min = 1.5
	fm.initial_velocity_max = 3.0
	floor_ring.emitting = true
	# as espirais: nascem numa esfera em volta e são puxadas para o peito girando
	var swirl := fx._particles(320, 0.7, 0.6, true, BLUE_RAMP, false)
	swirl.position = chest
	var sw := swirl.process_material as ParticleProcessMaterial
	sw.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	sw.emission_sphere_radius = 2.8
	sw.direction = Vector3.ZERO
	sw.spread = 180.0
	sw.initial_velocity_min = 0.0
	sw.initial_velocity_max = 0.5
	sw.gravity = Vector3(0, -0.5, 0)
	sw.tangential_accel_min = 22.0
	sw.tangential_accel_max = 30.0
	sw.radial_accel_min = -24.0
	sw.radial_accel_max = -16.0
	sw.damping_min = 0.5
	sw.damping_max = 1.5
	sw.scale_curve = _curve([Vector2(0, 0.4), Vector2(0.35, 1.0), Vector2(1, 0.15)])
	swirl.emitting = true
	var gold_swirl := fx._particles(160, 0.7, 0.55, true, GOLD_RAMP, false)
	gold_swirl.position = chest
	gold_swirl.process_material = sw.duplicate()
	(gold_swirl.process_material as ParticleProcessMaterial).color_ramp = _ramp(GOLD_RAMP)
	gold_swirl.emitting = true
	# o peito acende aos poucos
	var heart := fx._glow_sprite(0.5, Color(0.5, 0.75, 1.0, 0.9))
	heart.position = chest + Vector3(0, 0, 0)
	fx.add_child(heart)
	var light := fx._light(BLUE, 0.6)
	light.position = chest
	var state := {"burst": false}
	fx.on_tick = func(t: float, _d: float) -> void:
		var k := clampf(t / duration, 0.0, 1.0)
		var on := t < duration
		floor_ring.emitting = on and t < duration * 0.7
		swirl.emitting = on
		gold_swirl.emitting = on
		if on:
			heart.pixel_size = 0.004 * (0.6 + 2.2 * k) * (0.9 + 0.1 * sin(t * 50.0))
			light.light_energy = 0.6 + 2.0 * k
		else:
			var f := maxf(0.0, 1.0 - (t - duration) * 1.4)
			heart.modulate.a = f
			light.light_energy = 3.0 * f
		if not state["burst"] and t >= duration:
			state["burst"] = true
			fx._heal_burst(chest)


func _heal_burst(chest: Vector3) -> void:
	var flare := _glow_sprite(3.0, Color(0.3, 0.55, 1.0, 0.5))
	flare.position = chest
	add_child(flare)
	var tw := create_tween()
	tw.tween_property(flare, "modulate:a", 0.0, 0.45)
	_shockwave(4.5, 0.5, BLUE, 0.05)
	# chamas saindo do peito em todas as direções
	var out := _particles(120, 0.5, 0.7, true, BLUE_RAMP, false)
	out.position = chest
	var om := out.process_material as ParticleProcessMaterial
	om.emission_sphere_radius = 0.2
	om.direction = Vector3.UP
	om.spread = 180.0
	om.initial_velocity_min = 4.0
	om.initial_velocity_max = 8.0
	om.damping_min = 8.0
	om.damping_max = 12.0
	out.one_shot = true
	out.explosiveness = 0.9
	out.emitting = true
	# faíscas douradas de cura subindo
	var up := _sparks(120, 1.6, false)
	up.position = chest
	var um := up.process_material as ParticleProcessMaterial
	um.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	um.emission_sphere_radius = 0.9
	um.direction = Vector3.UP
	um.spread = 30.0
	um.initial_velocity_min = 1.0
	um.initial_velocity_max = 3.5
	um.gravity = Vector3(0, 1.0, 0)
	up.one_shot = true
	up.explosiveness = 0.5
	up.emitting = true
	var ring := _particles(140, 0.7, 0.8, true, BLUE_RAMP)
	var rm := ring.process_material as ParticleProcessMaterial
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	rm.emission_ring_axis = Vector3.UP
	rm.emission_ring_radius = 1.4
	rm.emission_ring_inner_radius = 1.1
	rm.emission_ring_height = 0.05
	rm.direction = Vector3.UP
	rm.spread = 8.0
	rm.initial_velocity_min = 2.0
	rm.initial_velocity_max = 4.0
	ring.one_shot = true
	ring.explosiveness = 0.8
	ring.emitting = true


## Fio de fogo do Fênix até o aliado curado, com o aliado acendendo.
static func heal_link(from_hero: Node3D, to_hero: Node3D) -> void:
	var fx := _spawn(to_hero.global_position, 1.2)
	fx.follow = to_hero
	var a := from_hero.global_position + Vector3(0, 1.3, 0)
	var b := to_hero.global_position + Vector3(0, 1.1, 0)
	var line := fx._particles(200, 0.4, 0.5, true, BLUE_RAMP)
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
	for i in 60:
		var k := float(i) / 59.0
		var p := a.lerp(b, k) + Vector3.UP * sin(k * PI) * 0.8
		line.emit_particle(Transform3D(Basis(), p), (b - a).normalized() * 3.0 + Vector3.UP, Color.WHITE, Color.WHITE, flags)
	var up := fx._sparks(60, 1.2)
	(up.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.6
	up.position = Vector3(0, 1.0, 0)
	up.one_shot = true
	up.explosiveness = 0.6
	up.emitting = true
	fx._shockwave(2.6, 0.45, BLUE, 0.05)


# ================================================================ Q: Asas de Fogo

## Asas de fogo abrem das costas e batem para a frente, soltando o cone.
## `facing` é a direção do golpe; `length` e `arc` são o alcance do cone.
static func wings(hero: Node3D, facing: Vector3, length: float, arc_degrees: float) -> void:
	var fx := _spawn(hero.global_position, 1.3)
	fx.follow = hero
	var fwd := Vector3(facing.x, 0, facing.z).normalized()
	fx.basis = Basis.looking_at(fwd, Vector3.UP)
	var pivots: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var p := Node3D.new()
		p.position = Vector3(0.14 * side, 1.4, 0.18)
		fx.add_child(p)
		fx._build_wing(p, side, 2.1, 12)
		p.scale = Vector3.ONE * 0.01
		pivots.append(p)
	var back_fire := fx._particles(160, 0.45, 0.8, true, BLUE_RAMP, false)
	back_fire.position = Vector3(0, 1.4, 0.2)
	back_fire.emitting = true
	var light := fx._light(BLUE, 1.5)
	light.position = Vector3(0, 1.4, 0)
	var state := {"cone": false}
	fx.on_tick = func(t: float, _d: float) -> void:
		# 0-0,14 s abre; 0,14-0,3 s bate para a frente; depois some
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			var p := pivots[i]
			if t < 0.14:
				var k := t / 0.14
				p.scale = Vector3.ONE * lerpf(0.2, 1.15, 1.0 - pow(1.0 - k, 3.0))
				p.rotation = Vector3(0, 0, side * lerpf(0.3, 0.85, k))
			elif t < 0.3:
				var k := (t - 0.14) / 0.16
				p.scale = Vector3.ONE * 1.15
				p.rotation = Vector3(lerpf(0.0, -0.3, k), -side * lerpf(0.0, 1.05, k * k), side * lerpf(0.85, 0.2, k))
			else:
				var k := clampf((t - 0.3) / 0.35, 0.0, 1.0)
				p.scale = Vector3.ONE * lerpf(1.15, 0.01, k)
		back_fire.emitting = t < 0.35
		light.light_energy = maxf(0.0, 1.5 + (2.5 if t > 0.2 and t < 0.45 else 0.0) - t * 1.2)
		if not state["cone"] and t >= 0.2:
			state["cone"] = true
			fx._cone_burst(length, arc_degrees)


func _cone_burst(length: float, arc_degrees: float) -> void:
	# coordenadas do mundo, com a frente do efeito (-Z)
	var fwd := -global_transform.basis.z
	for ramp_size in [[BLUE_RAMP, 150, 1.3], [GOLD_RAMP, 60, 1.0]]:
		var p := _particles(ramp_size[1], 0.55, ramp_size[2], true, ramp_size[0])
		p.global_position = global_position + Vector3(0, 0.9, 0) + fwd * 0.4
		var pm := p.process_material as ParticleProcessMaterial
		pm.emission_sphere_radius = 0.4
		pm.direction = fwd
		pm.spread = arc_degrees * 0.5
		pm.flatness = 0.7
		# para perto do fim do cone
		pm.initial_velocity_min = length * 1.6
		pm.initial_velocity_max = length * 2.6
		pm.damping_min = length * 2.2
		pm.damping_max = length * 3.0
		pm.gravity = Vector3(0, 1.5, 0)
		p.one_shot = true
		p.explosiveness = 0.85
		p.emitting = true
	var s := _sparks(90, 1.0)
	s.global_position = global_position + Vector3(0, 1.0, 0)
	var sm := s.process_material as ParticleProcessMaterial
	sm.direction = fwd
	sm.spread = arc_degrees * 0.5
	sm.initial_velocity_min = 5.0
	sm.initial_velocity_max = 11.0
	s.one_shot = true
	s.explosiveness = 0.9
	s.emitting = true


# ================================================================ peças

## Asa: penas de fogo presas ao longo do braço da asa (+X para `side` = 1),
## apontando para trás (+Z), as da ponta mais longas; cobertas douradas.
func _build_wing(pivot: Node3D, side: float, span: float, n: int) -> void:
	for k in n:
		var t := float(k) / float(n - 1)
		var root := Vector3(side * span * t, sin(t * PI) * 0.18 * span, 0)
		var ln := span * (0.38 + 0.6 * pow(t, 1.2))
		var f := _feather(ln, span * 0.2, BLUE)
		f.position = root
		# deita a pena para trás e abre em leque para fora na ponta
		f.rotation = Vector3(deg_to_rad(80.0), side * deg_to_rad(-38.0 * pow(t, 1.5)), 0)
		pivot.add_child(f)
		if k % 2 == 0:
			var g := _feather(ln * 0.5, span * 0.15, GOLD)
			g.position = root + Vector3(0, 0.02, 0)
			g.rotation = Vector3(deg_to_rad(78.0), side * deg_to_rad(-20.0 * t), 0)
			pivot.add_child(g)


## Pena de fogo: quadrado com a textura de chama, raiz na origem e ponta em +Y.
func _feather(length: float, width: float, color: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	q.center_offset = Vector3(0, length * 0.5, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := _additive(_flame_texture())
	m.vertex_color_use_as_albedo = false
	m.albedo_color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.75)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _glow_sprite(size: float, color: Color) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _soft_texture()
	s.pixel_size = size / 64.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = false
	s.modulate = color
	var m := _additive(_soft_texture())
	m.vertex_color_use_as_albedo = false
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


func _light(color: Color, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 5.0
	l.position = Vector3(0, 0.8, 0)
	add_child(l)
	return l


## Disco/anel no chão. `filled` = chão queimado (disco cheio que some).
func _ground_ring(size: float, color: Color, filled := false) -> MeshInstance3D:
	var m := _additive(_ring_texture() if not filled else _soft_texture())
	m.vertex_color_use_as_albedo = false
	m.albedo_color = Color(color, 0.45)
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	var r := MeshInstance3D.new()
	r.mesh = pm
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.position = Vector3(0, 0.06, 0)
	r.scale = Vector3.ONE * size
	add_child(r)
	return r


## Onda que se abre no chão até `size` de diâmetro em `duration` s.
func _shockwave(size: float, duration: float, color: Color, delay: float = 0.0) -> void:
	var r := _ground_ring(0.3, color)
	r.top_level = true
	r.global_position = global_position + Vector3(0, 0.07, 0)
	var mat := r.material_override as StandardMaterial3D
	mat.albedo_color = Color(color, 0.7)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(r, "scale", Vector3.ONE * size, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration * 1.3).set_ease(Tween.EASE_IN)


## Chamas que saem do centro para os lados, rente ao chão, parando perto de `reach`.
func _radial_burst(amount: int, reach: float, life_s: float, ramp: Array, size: float = 1.2) -> void:
	var p := _particles(amount, life_s, size, true, ramp)
	p.position = Vector3(0, 0.3, 0)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 180.0
	pm.flatness = 0.92
	pm.initial_velocity_min = reach * 2.0
	pm.initial_velocity_max = reach * 3.2
	pm.damping_min = reach * 3.5
	pm.damping_max = reach * 4.5
	pm.gravity = Vector3(0, 2.5, 0)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true


func _sparks(amount: int, life_s: float, world := true) -> GPUParticles3D:
	var p := _particles(amount, life_s, 0.07, false, SPARK_RAMP, world)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, 1.5, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	return p


## Partículas de chama (ou brilho). `world` = soltas no mundo (ficam para trás).
func _particles(amount: int, life_s: float, size: float, flame: bool, ramp: Array, world := true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life_s
	p.local_coords = not world
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 16, 24))
	var q := QuadMesh.new()
	q.size = Vector2(size, size * (1.6 if flame else 1.0))
	var m := _additive(_flame_texture() if flame else _soft_texture())
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, 2.5, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.scale_curve = _curve([Vector2(0, 0.5), Vector2(0.2, 1.0), Vector2(1, 0.15)])
	pm.color_ramp = _ramp(ramp)
	if flame:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.0
		pm.turbulence_noise_scale = 2.5
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.15
	p.process_material = pm
	add_child(p)
	return p


# ================================================================ texturas e materiais

static func _flame_texture() -> Texture2D:
	if _flame_tex == null:
		_flame_tex = HandFire._flame_texture()
	return _flame_tex


static func _soft_texture() -> Texture2D:
	if _soft_tex == null:
		_soft_tex = HandFire._soft_texture()
	return _soft_tex


static func _ring_texture() -> Texture2D:
	if _ring_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.82, 0.93, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 256
		t.height = 256
		_ring_tex = t
	return _ring_tex


static func _additive(tex: Texture2D) -> StandardMaterial3D:
	return HandFire._additive(tex)


static func _ramp(a: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(a.map(func(x): return x[0]))
	g.colors = PackedColorArray(a.map(func(x): return x[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t
