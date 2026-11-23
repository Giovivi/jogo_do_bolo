class_name FenixModel
extends Node3D
## Modelo 3D de herói (Fênix, Feixe) com esqueleto e animações.
## Malha feita no Blender; esqueleto e animações da Universal Animation
## Library do Quaternius (CC0). Escolhe sozinho parado / andando / correndo /
## no ar pelo movimento do herói; golpes e reações tocam por cima com play_once().

const MODEL := preload("res://art/modelos/fenix_animado.glb")

## Cena do glb a usar; o Feixe troca por feixe_animado.glb (mesmo esqueleto).
var scene: PackedScene = MODEL

const IDLE := "Idle"
const WALK := "Walk"
const RUN := "Jog_Fwd"
const AIR := "Jump"
const DEATH := "Death01"

## Velocidades (m/s) em que as animações de andar e correr ficam no ritmo dos pés.
const WALK_ANIM_SPEED := 1.6
const RUN_ANIM_SPEED := 4.2

var hero: Hero
var anim: AnimationPlayer
var _one_shot: String = ""
## Fogo azul de cada mão ("L"/"R"), criado só por quem chama add_hand_fire() (Fênix).
var hand_fire: Dictionary = {}
## Pernas andando durante os golpes (o tronco bate, as pernas seguem o passo).
var legs: LegsOverride


func _ready() -> void:
	var m := scene.instantiate() as Node3D
	# O glb olha para +Z; os atores do jogo olham para -Z.
	m.rotation_degrees.y = 180.0
	add_child(m)
	_fix_materials(m)
	anim = m.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	# A Godot tira o "_Loop" do nome na importação; garante o loop mesmo assim.
	for n in [IDLE, WALK, RUN, AIR]:
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	anim.animation_finished.connect(_on_finished)
	var found := m.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		legs = LegsOverride.new()
		legs.influence = 0.0
		legs.active = false
		(found.front() as Skeleton3D).add_child(legs)
		legs.setup(found.front() as Skeleton3D, anim.get_animation(WALK))
	_play(IDLE)


## Toca um golpe ou reação uma vez; depois volta sozinho ao movimento.
func play_once(anim_name: String, speed: float = 1.0) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	_one_shot = anim_name
	anim.speed_scale = speed
	anim.play(anim_name, 0.08)
	anim.seek(0.0, true)


func _process(delta: float) -> void:
	if anim == null or hero == null:
		return
	if hero.is_dead:
		_update_legs(delta, false, 0.0, 1.0)
		if _one_shot != DEATH:
			play_once(DEATH)
		return
	if _one_shot == DEATH:
		_one_shot = ""
	var flat_v := Vector3(hero.velocity.x, 0.0, hero.velocity.z)
	var flat := flat_v.length()
	# Andando de ré (corpo virado para o alvo, indo para longe dele): passos ao contrário.
	var dir := 1.0
	if flat > 0.3 and flat_v.normalized().dot(hero.facing) < -0.3:
		dir = -1.0
	var grounded := hero.is_on_floor() or absf(hero.velocity.y) <= 0.5
	_update_legs(delta, _one_shot != "" and grounded and flat > 0.3, flat, dir)
	if _one_shot != "":
		return
	if not grounded:
		_play(AIR)
	elif flat < 0.3:
		_play(IDLE)
	elif flat < 3.0 or dir < 0.0:
		# De ré ele só anda (a corrida de costas fica estranha).
		_play(WALK, flat / WALK_ANIM_SPEED, dir)
	else:
		_play(RUN, flat / RUN_ANIM_SPEED)


## Pernas da animação de andar por cima do golpe, no ritmo da velocidade real.
func _update_legs(delta: float, on: bool, flat: float, dir: float) -> void:
	if legs == null:
		return
	if on:
		legs.time += delta * (flat / WALK_ANIM_SPEED) * dir
	legs.influence = move_toward(legs.influence, 1.0 if on else 0.0, delta * 8.0)
	legs.active = legs.influence > 0.0


func _play(anim_name: String, speed: float = 1.0, dir: float = 1.0) -> void:
	anim.speed_scale = clampf(speed, 0.5, 2.2) * dir
	if anim.current_animation != anim_name:
		anim.play(anim_name, 0.15)


func _on_finished(anim_name: String) -> void:
	# A queda fica parada no último quadro até o herói ser revivido.
	if anim_name == _one_shot and anim_name != DEATH:
		_one_shot = ""


## Cria o fogo azul das duas mãos (chama no antebraço, rastro e garras de fogo).
func add_hand_fire() -> void:
	var found := find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var sk := found.front() as Skeleton3D
	for side in ["L", "R"]:
		var f := HandFire.new()
		f.style = HandFire.Style.GARRAS
		f.skeleton = sk
		f.hand_bone = sk.find_bone("DEF-hand." + side)
		f.forearm_bone = sk.find_bone("DEF-forearm." + side)
		for finger in ["f_index", "f_middle", "f_ring"]:
			var b := sk.find_bone("DEF-%s.03.%s" % [finger, side])
			if b >= 0:
				f.tip_bones.append(b)
		if f.hand_bone < 0:
			continue
		add_child(f)
		hand_fire[side] = f


## Acende o fogo das mãos indicadas ("L", "R" ou "LR") por `duration` segundos.
func ignite_hands(sides: String, duration: float, strong: bool = false) -> void:
	for side in hand_fire:
		if side in sides:
			(hand_fire[side] as HandFire).ignite(duration, strong)


## Texturas vêm do glb; o fogo fica sem sombra para brilhar.
func _fix_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var mat_name := src.resource_name
			# A cor (com a textura) já vem na imagem do glb; não usa cor por vértice.
			if mat_name == "fogo" and src is StandardMaterial3D:
				var fire := StandardMaterial3D.new()
				fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				fire.albedo_texture = (src as StandardMaterial3D).albedo_texture
				fire.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(i, fire)
			elif src is StandardMaterial3D:
				var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.vertex_color_use_as_albedo = false
				if mat_name == "penas":
					m.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(i, m)
	for child in node.get_children():
		_fix_materials(child)
