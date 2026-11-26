class_name EmberMark
extends Node3D
## Marca de Brasa num inimigo (Forma Fênix): uma brasa dourada girando em
## volta do corpo por acúmulo (até 3) e um anel em 3 partes no chão, que
## acende uma parte por acúmulo. Some quando os acúmulos acabam.

const MAX := 3
const GOLD := Color(1.0, 0.7, 0.25)

var count: int = 0
var _embers: Array[Sprite3D] = []
var _segments: Array[MeshInstance3D] = []
var _time: float = 0.0
var _flame: GPUParticles3D


func _ready() -> void:
	var fx := FenixFX.new()
	fx.life = 1e9
	add_child(fx)
	for i in MAX:
		var s := fx._glow_sprite(0.3, Color(1.0, 0.8, 0.4, 1.0))
		s.visible = false
		add_child(s)
		_embers.append(s)
		var seg := MeshInstance3D.new()
		seg.mesh = PhoenixFX._arc_mesh(0.62, 0.8, i * 120.0 + 8.0, i * 120.0 + 112.0, 0.0, 0.0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(0.3, 0.3, 0.35, 0.25)
		seg.material_override = m
		seg.position.y = 0.06
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seg)
		_segments.append(seg)
	_flame = fx._particles(40, 0.5, 0.35, true, FenixFX.GOLD_RAMP, true)
	(_flame.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.35
	_flame.position.y = 0.9
	_set_count(0)


func add(n: int = 1) -> void:
	_set_count(mini(MAX, count + n))


func clear() -> void:
	_set_count(0)


func _set_count(n: int) -> void:
	count = n
	for i in MAX:
		_embers[i].visible = i < n
		var m := _segments[i].material_override as StandardMaterial3D
		m.albedo_color = Color(GOLD, 0.9) if i < n else Color(0.3, 0.3, 0.35, 0.18)
	_flame.emitting = n > 0
	_flame.amount = maxi(1, 14 * n)
	visible = n > 0


func _process(delta: float) -> void:
	_time += delta
	for i in MAX:
		var a := _time * 3.0 + TAU * i / MAX
		_embers[i].position = Vector3(cos(a) * 0.6, 1.05 + sin(_time * 4.0 + i) * 0.12, sin(a) * 0.6)
		_embers[i].scale = Vector3.ONE * (0.9 + 0.2 * sin(_time * 9.0 + i * 2.0))
