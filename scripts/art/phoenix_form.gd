class_name PhoenixForm
extends Node3D
## Corpo da Forma Fênix (suprema do Fênix): ave de fogo azul e dourado que
## substitui o modelo humano enquanto a forma dura. Feita só de peças com
## brilho (penas com shader próprio, núcleo, chamas e faíscas), sem malha
## nem esqueleto: as asas, a cauda e o corpo são animados por código.
## Frente = -Z, origem no chão, como os atores do jogo.
##
## pose: "voo" (parado/andando), "golpe_e" / "golpe_d" (asa esquerda ou
## direita varre para a frente), "giro", "mergulho" (asas fechadas para trás),
## "leque" (asas batem para a frente, Q) e "abrir" (asas bem abertas, fim do E).
## blend vai de 0 a 1 entre a pose anterior e a atual.

const BLUE := Color(0.3, 0.62, 1.0)
const DEEP := Color(0.08, 0.22, 0.95)
const GOLD := Color(1.0, 0.74, 0.3)
const HOVER := 0.55

const FEATHER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 base_color : source_color = vec4(0.15, 0.45, 1.0, 1.0);
uniform vec4 tip_color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float intensity = 1.0;
uniform float seed = 0.0;
// Pena: UV.y 0 na raiz, 1 na ponta. Haste no meio, barbas em diagonal,
// ponta que tremula como chama.
void fragment() {
	float y = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME * 3.0 + seed * 7.0;
	float flick = sin(y * 9.0 - t * 2.0 + seed * 3.0) * 0.06 * y;
	float half_w = 0.78 * pow(sin(clamp(y, 0.0, 1.0) * 3.1416 * 0.94 + 0.05), 0.8) * (1.0 - 0.35 * y);
	float ax = abs(x - flick);
	float edge = smoothstep(half_w, half_w * 0.3, ax);
	float tip_cut = smoothstep(1.0, 0.82 - 0.08 * sin(t + x * 6.0), y);
	float shape = edge * tip_cut;
	float barbs = 0.75 + 0.25 * sin((y * 26.0 - ax * 14.0) + seed * 5.0);
	float rachis = smoothstep(0.06, 0.0, abs(x - flick)) * (1.0 - y * 0.7) * 0.6;
	vec3 col = mix(base_color.rgb, tip_color.rgb, smoothstep(0.2, 1.0, y));
	col = mix(col, core_color.rgb, clamp(rachis * 0.9 + smoothstep(0.35, 0.0, y) * 0.35, 0.0, 1.0));
	ALBEDO = col * intensity * (0.8 + 0.4 * barbs);
	ALPHA = clamp(shape * (0.55 + 0.45 * barbs) * base_color.a, 0.0, 1.0);
}
"""

const CORE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 rim : source_color = vec4(0.25, 0.6, 1.0, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.78, 0.4, 1.0);
uniform float intensity = 1.0;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = 0.5 + 0.5 * sin(TIME * 5.0 + VERTEX.y * 9.0 + VERTEX.x * 7.0);
	vec3 c = mix(core.rgb, rim.rgb, smoothstep(0.1, 0.75, f));
	ALBEDO = c * intensity * (0.85 + 0.25 * n);
	ALPHA = clamp(0.12 + f * 0.45, 0.0, 1.0);
}
"""

static var _feather_shader: Shader
static var _core_shader: Shader

var hero: Node3D
## "ave": ave de fogo inteira no lugar do corpo. "alado": o Fênix humano
## continua visível, pairando, com asas e cauda de fogo.
var style: String = "ave"
var pose: String = "voo"
var blend: float = 1.0
var intensity: float = 1.0

var _body: Node3D
var _wings: Array[Node3D] = []
var _tail: Node3D
var _tail_feathers: Array[MeshInstance3D] = []
var _aura: GPUParticles3D
var _embers: GPUParticles3D
var _sparks: GPUParticles3D
var _light: OmniLight3D
var _time: float = 0.0
var _body_y: float = 1.35 + HOVER * 0.4
var _from: Dictionary = {}
var _to: Dictionary = {}
var _mats: Array[ShaderMaterial] = []


func _ready() -> void:
	_body = Node3D.new()
	_body.position = Vector3(0, 1.35 + HOVER * 0.4, 0)
	add_child(_body)
	_build_body()
	for side in [-1.0, 1.0]:
		var p := Node3D.new()
		p.position = Vector3(0.22 * side, 0.22, 0.05)
		_body.add_child(p)
		_build_wing(p, side)
		_wings.append(p)
	_tail = Node3D.new()
	_tail.position = Vector3(0, -0.15, 0.45)
	_body.add_child(_tail)
	_build_tail()
	_build_particles()
	if style == "alado":
		_body_y = 1.75
		for c in _body.get_children():
			if c is MeshInstance3D:
				c.visible = false
		for w in _wings:
			w.position = Vector3(0.12 * (-1.0 if w == _wings[0] else 1.0), 0.15, 0.2)
		_tail.position = Vector3(0, -0.45, 0.25)
		_tail.scale = Vector3.ONE * 0.8
	_from = _pose_values("voo")
	_to = _from


func set_pose(p: String, instant := false) -> void:
	_from = _current() if not instant else _pose_values(p)
	_to = _pose_values(p)
	pose = p
	blend = 1.0 if instant else 0.0


func _current() -> Dictionary:
	var out := {}
	for k in _to.keys():
		out[k] = lerpf(_from.get(k, _to[k]), _to[k], _ease(blend))
	return out


static func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


## Valores de cada pose: ângulos das asas (graus) e do corpo.
## up = asa levantada (V), sweep = asa para trás (+) ou para a frente (-),
## fold = encolhe a asa, pitch = corpo deita para a frente.
func _pose_values(p: String) -> Dictionary:
	match p:
		"golpe_e":
			return {"upL": 15.0, "sweepL": -95.0, "foldL": 0.0, "upR": 40.0, "sweepR": 20.0, "foldR": 0.2, "pitch": 12.0, "flap": 0.15}
		"golpe_d":
			return {"upL": 40.0, "sweepL": 20.0, "foldL": 0.2, "upR": 15.0, "sweepR": -95.0, "foldR": 0.0, "pitch": 12.0, "flap": 0.15}
		"giro":
			return {"upL": 5.0, "sweepL": 0.0, "foldL": 0.0, "upR": 5.0, "sweepR": 0.0, "foldR": 0.0, "pitch": 0.0, "flap": 0.0}
		"mergulho":
			return {"upL": 25.0, "sweepL": 75.0, "foldL": 0.55, "upR": 25.0, "sweepR": 75.0, "foldR": 0.55, "pitch": 15.0, "flap": 0.0}
		"leque":
			return {"upL": 25.0, "sweepL": -55.0, "foldL": 0.0, "upR": 25.0, "sweepR": -55.0, "foldR": 0.0, "pitch": 18.0, "flap": 0.0}
		"abrir":
			return {"upL": 20.0, "sweepL": -5.0, "foldL": 0.0, "upR": 20.0, "sweepR": -5.0, "foldR": 0.0, "pitch": -8.0, "flap": 0.0}
		_:
			return {"upL": 38.0, "sweepL": 10.0, "foldL": 0.0, "upR": 38.0, "sweepR": 10.0, "foldR": 0.0, "pitch": 8.0, "flap": 1.0}


func _process(delta: float) -> void:
	_time += delta
	blend = minf(1.0, blend + delta / 0.12)
	var v := _current()
	var flap: float = sin(_time * 7.0) * 18.0 * v["flap"]
	# Paira subindo e descendo devagar.
	_body.position.y = _body_y + sin(_time * 3.5) * 0.08
	_body.rotation.x = deg_to_rad(-v["pitch"])
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var k := "L" if i == 0 else "R"
		var w := _wings[i]
		# Varrer para trás = girar em Y levando a ponta para +Z.
		w.rotation = Vector3(0, deg_to_rad(side * v["sweep" + k]), deg_to_rad(side * (v["up" + k] + flap)))
		w.scale = Vector3.ONE * lerpf(1.0, 0.55, v["fold" + k])
	for j in _tail_feathers.size():
		var f := _tail_feathers[j]
		f.rotation.z = (j - 3) * 0.12 + sin(_time * 2.5 + j * 0.7) * 0.08
	for m in _mats:
		m.set_shader_parameter("intensity", intensity)


# ---------------------------------------------------------------- peças

func _build_body() -> void:
	# Núcleo alongado, deitado na direção do voo.
	var core := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.3
	s.height = 1.0
	core.mesh = s
	core.rotation.x = deg_to_rad(80.0)
	core.material_override = _core_mat(0.6)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(core)
	# Peito de penas curtas douradas.
	for i in 5:
		var f := _feather(0.55, 0.32, GOLD, BLUE, i)
		f.position = Vector3((i - 2) * 0.07, 0.05, -0.15)
		f.rotation = Vector3(deg_to_rad(-150.0), 0, deg_to_rad((i - 2) * 14.0))
		_body.add_child(f)
	# Pescoço e cabeça.
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.17
	hs.height = 0.36
	head.mesh = hs
	head.position = Vector3(0, 0.35, -0.5)
	head.material_override = _core_mat(0.9)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(head)
	var beak := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.0
	bc.bottom_radius = 0.07
	bc.height = 0.28
	beak.mesh = bc
	beak.rotation.x = deg_to_rad(-100.0)
	beak.position = Vector3(0, 0.32, -0.7)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.0, 0.85, 0.5)
	beak.material_override = bm
	_body.add_child(beak)
	# Crista: penas finas para trás e para cima.
	for i in 5:
		var c := _feather(0.55 + 0.1 * (2 - absf(i - 2)), 0.1, GOLD, Color(1.0, 0.95, 0.75), 10 + i)
		c.position = Vector3(0, 0.45, -0.45)
		c.rotation = Vector3(deg_to_rad(55.0 + i * 8.0), deg_to_rad((i - 2) * 12.0), 0)
		_body.add_child(c)
	# Pescoço: penas em leque ligando cabeça e corpo.
	for i in 4:
		var n := _feather(0.5, 0.3, BLUE, GOLD, 20 + i)
		n.position = Vector3((i - 1.5) * 0.06, 0.25, -0.38)
		n.rotation = Vector3(deg_to_rad(120.0), 0, deg_to_rad((i - 1.5) * 18.0))
		_body.add_child(n)


## Asa em três camadas: cobertas douradas curtas, secundárias e primárias
## longas na ponta. Penas apontam para fora e para trás.
func _build_wing(pivot: Node3D, side: float) -> void:
	var span := 2.3
	var n := 11
	for k in n:
		var t := float(k) / float(n - 1)
		var root := Vector3(side * span * t, sin(t * PI) * 0.25, 0.02 * k)
		var ln := lerpf(0.9, 1.9, pow(t, 1.3))
		var f := _feather(ln, 0.42, DEEP.lerp(BLUE, 0.4), Color(0.75, 0.9, 1.0), k)
		f.position = root
		# Deita para fora e para baixo; as da ponta abrem em leque.
		f.rotation = Vector3(0, 0, side * deg_to_rad(-90.0 - 60.0 * (1.0 - t) - 25.0 * t))
		pivot.add_child(f)
	for k in 7:
		var t := float(k) / 6.0
		var g := _feather(lerpf(0.45, 0.8, t), 0.34, GOLD, Color(1.0, 0.95, 0.7), 30 + k)
		g.position = Vector3(side * span * 0.75 * t, 0.06 + sin(t * PI) * 0.22, -0.02)
		g.rotation = Vector3(0, 0, side * deg_to_rad(-140.0 + 30.0 * t))
		pivot.add_child(g)
	# Borda de ataque da asa: linha clara do ombro à ponta.
	var arm := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.02
	c.bottom_radius = 0.07
	c.height = span
	arm.mesh = c
	arm.rotation.z = side * deg_to_rad(-90.0)
	arm.position = Vector3(side * span * 0.5, 0.18, 0)
	arm.material_override = _core_mat(0.8)
	pivot.add_child(arm)


func _build_tail() -> void:
	for i in 7:
		var ln := 1.7 + 0.6 * (1.0 - absf(i - 3) / 3.0)
		var f := _feather(ln, 0.36, BLUE if i % 2 == 0 else DEEP.lerp(BLUE, 0.5), GOLD if i == 3 else Color(0.7, 0.9, 1.0), 40 + i)
		f.position = Vector3(0, 0, 0)
		# Para trás e um pouco para baixo, abrindo em leque.
		f.rotation = Vector3(deg_to_rad(105.0), 0, (i - 3) * 0.12)
		_tail.add_child(f)
		_tail_feathers.append(f)


func _build_particles() -> void:
	var fx := FenixFX.new()
	add_child(fx)
	fx.life = 1e9
	_aura = fx._particles(70, 0.5, 0.6, true, FenixFX.BLUE_RAMP, true)
	var am := _aura.process_material as ParticleProcessMaterial
	am.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	am.emission_box_extents = Vector3(0.25, 0.2, 0.5)
	_aura.position = _body.position
	_aura.emitting = true
	_embers = fx._particles(60, 0.9, 0.5, true, FenixFX.GOLD_RAMP, true)
	var em := _embers.process_material as ParticleProcessMaterial
	em.emission_sphere_radius = 0.5
	em.gravity = Vector3(0, -1.5, 0)
	_embers.position = _body.position
	_embers.emitting = true
	_sparks = fx._sparks(50, 1.2)
	_sparks.position = _body.position
	_sparks.emitting = true
	_light = OmniLight3D.new()
	_light.light_color = BLUE
	_light.light_energy = 1.2
	_light.omni_range = 6.0
	_light.position = _body.position
	add_child(_light)


func _feather(length: float, width: float, base: Color, tip: Color, seed: int) -> MeshInstance3D:
	if _feather_shader == null:
		_feather_shader = Shader.new()
		_feather_shader.code = FEATHER_SHADER
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	q.center_offset = Vector3(0, length * 0.5, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _feather_shader
	m.set_shader_parameter("base_color", Color(base, 0.85))
	m.set_shader_parameter("tip_color", tip)
	m.set_shader_parameter("core_color", GOLD)
	m.set_shader_parameter("seed", float(seed) * 0.37)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mats.append(m)
	return mi


func _core_mat(strength: float) -> ShaderMaterial:
	if _core_shader == null:
		_core_shader = Shader.new()
		_core_shader.code = CORE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _core_shader
	m.set_shader_parameter("intensity", strength)
	return m
