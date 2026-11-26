class_name Feixe
extends Hero
## Feixe: DPS à distância e controle, tudo em raio óptico vermelho saindo
## dos óculos (documentos "O Feixe — especificação" e "Direção de arte e
## VFX" da Vivi; pranchas feixe-reformulado-v1/v2 e feixe-e-cone-v3).
## Passiva Foco Óptico, Disparo Óptico, Feixe de Contenção (Q), Ruptura
## Óptica (E) e Aniquilação Circular (R).

## Tempo para o Feixe de Contenção nascer fino e chegar à largura do momento.
const LASER_GROW_TIME := 0.15
## Largura visual do Q (m): fina com 16/s, 1,2 m com 28/s (o mesmo que acerta).
const LASER_VISUAL_MIN := 0.3
const LASER_VISUAL_MAX := 1.2
## Tolerância de altura entre o raio e o centro do corpo do inimigo (m).
const BEAM_HEIGHT_TOLERANCE := 1.1
## Malha do Feixe (óculos de laser) no mesmo esqueleto e animações do Fênix.
const MODEL := preload("res://art/modelos/feixe_animado.glb")
## Centro das lentes no espaço do glb (feixe_build.py: lentes em x ±0,037,
## altura 1,697 e 0,107 à frente; o glb olha para +Z).
const LENS_GLB := Vector3(0, 1.697, 0.107)
## O mesmo em relação aos pés do herói (o jogo olha para -Z), se faltar o osso.
const LENS_REST := Vector3(0, 1.697, -0.107)

var _laser_active: bool = false
var _laser_time: float = 0.0
var _laser_tick: float = 0.0
var _laser_ai_limit: float = 0.0
var _laser_ai_empty: float = 0.0
## Tempo que o Q está em cada inimigo (id -> s): o dano sobe com ele.
var _laser_on: Dictionary = {}
## Força mostrada (0 a 1): largura e brilho acompanham o dano.
var _laser_power: float = 0.0
var _laser_fx: FeixeFX
## Foco Óptico: alvo, acertos seguidos e se está completo.
var _focus_target: Actor = null
var _focus_stacks: int = 0
var _focus_full: bool = false
var lenses: FeixeFX.Lenses
## Ponto das lentes preso ao osso da cabeça.
var _head: BoneAttachment3D
var _lens_local: Vector3 = Vector3.ZERO
var _lens_ready: bool = false
## Aniquilação Circular: preparação (>= 0) e varredura (>= 0).
var _charge_time: float = -1.0
var _sweep_time: float = -1.0
var _sweep_yaw0: float = 0.0
var _sweep_hit: Array = []
var _sweep_fx: FeixeFX
var _mark_fx: FeixeFX
var _outline_mats: Array[StandardMaterial3D] = []
var _outline_meshes: Array[MeshInstance3D] = []
## Mão na têmpora (Q e R).
var temple: TempleOverride
var _temple_target: float = 0.0
var _ai_target: Actor = null
var _was_dashing: bool = false
var _ghosts_left: int = 0
var _ghost_clock: float = 0.0
var model: FenixModel


func _fb() -> FeixeStats:
	return stats as FeixeStats


func _ready() -> void:
	super._ready()
	_use_model()
	# Faísca de acerto genérica em vermelho (os clarões próprios vêm do FeixeFX).
	impact_color = Color(1.0, 0.55, 0.5, 0.7)
	impact_color_strong = Color(1.0, 0.2, 0.22, 0.9)


## Troca a cápsula provisória pelo modelo 3D (a colisão continua a mesma).
func _use_model() -> void:
	for child in visual.get_children():
		if child is MeshInstance3D:
			child.visible = false
	model = FenixModel.new()
	model.scene = MODEL
	model.hero = self
	visual.add_child(model)
	lenses = FeixeFX.lenses(self)
	var found := model.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		var sk := found.front() as Skeleton3D
		temple = TempleOverride.new()
		sk.add_child(temple)
		temple.setup(sk)
		var hb := sk.find_bone("DEF-head")
		if hb >= 0:
			_head = BoneAttachment3D.new()
			_head.bone_name = "DEF-head"
			sk.add_child(_head)
			# Ponto das lentes no espaço do osso da cabeça (pose de descanso).
			var glb := model.get_child(0) as Node3D
			var lens_sk := sk.global_transform.affine_inverse() * (glb.global_transform * LENS_GLB)
			_lens_local = sk.get_bone_global_rest(hb).affine_inverse() * lens_sk
			_lens_ready = true
	# Materiais: lentes (brilho controlado pelo Foco) e contorno fino da
	# invulnerabilidade da R (camada por cima, inflada, só a borda).
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		_outline_meshes.append(m)
		for i in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(i)
			if mat is StandardMaterial3D and m.mesh.surface_get_material(i) != null \
					and m.mesh.surface_get_material(i).resource_name == "lente":
				lenses.lens_mats.append(mat as StandardMaterial3D)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if temple != null:
		var want := _temple_target if not is_dead else 0.0
		temple.weight = move_toward(temple.weight, want, delta * 7.0)
	_update_lenses(delta)
	_update_dash_fx(delta)
	if _laser_active:
		if is_dead or not in_party:
			stop_laser()
		else:
			_tick_laser(delta)


func ability_slots() -> Array:
	var s := _fb()
	var laser_name := "Feixe de Contenção (%.1f s)" % laser_time_left() if _laser_active else "Feixe de Contenção (segure)"
	return [
		["Clique", "Disparo Óptico", 0.0, 0.0],
		["Q", laser_name, cooldown_left("q"), s.q_cooldown],
		["E", "Ruptura Óptica", cooldown_left("e"), s.e_cooldown],
		["R", "Aniquilação Circular", 0.0, 0.0],
		["Shift", "Dash", cooldown_left("dash"), s.dash_cooldown],
		["Passiva", "Foco Óptico", 0.0, 0.0],
	]


func set_controlled(value: bool) -> void:
	if not value:
		stop_laser()
	super.set_controlled(value)


# ---------------------------------------------------------------- jogador

func _player_actions(_aim: Vector3, _move: Vector3) -> void:
	if Input.is_action_pressed("attack") and not _laser_active:
		optic_shot()
	if Input.is_action_just_pressed("ability_1"):
		start_laser(0.0)
	if _laser_active and not Input.is_action_pressed("ability_1"):
		stop_laser()
	if Input.is_action_just_pressed("ability_2"):
		repulsion_pulse()


# ---------------------------------------------------------------- óculos

## Centro das lentes no mundo (acompanha a cabeça nas animações).
func lens_center() -> Vector3:
	if _lens_ready and is_instance_valid(_head):
		return _head.global_transform * _lens_local
	return global_position + visual.global_transform.basis.orthonormalized() * LENS_REST


func _update_lenses(delta: float) -> void:
	if lenses == null:
		return
	var right := visual.global_transform.basis.orthonormalized().x
	var head_top := lens_center() + Vector3(0, 0.3, 0)
	lenses.visible = not is_dead
	lenses.place(lens_center(), right, head_top, delta)


## O rosto do Feixe: de onde saem os raios e o clarão (um pouco à frente das lentes).
func _muzzle() -> Vector3:
	return lens_center() + facing * 0.08


func _set_focus(stacks: int, full: bool) -> void:
	_focus_stacks = stacks
	_focus_full = full
	if lenses != null:
		lenses.set_stacks(stacks, full)


func _lose_focus() -> void:
	if (_focus_stacks > 0 or _focus_full) and lenses != null:
		lenses.lose(lens_center())
	_focus_stacks = 0
	_focus_full = false
	_focus_target = null


## Alvo do raio: o inimigo embaixo do cursor (jogador) ou o da IA.
func _shot_target() -> Actor:
	var t: Actor = aim_target if controlled else _ai_target
	if t != null and (not is_instance_valid(t) or t.is_dead):
		return null
	return t


## Ponto final do raio: na direção do alvo (inclusive para cima, no drone)
## ou reto para a frente, cortado pela primeira parede.
func _beam_end(from: Vector3, length: float) -> Vector3:
	var dir := facing
	var t := _shot_target()
	if t != null:
		dir = (Game.body_center(t) - from).normalized()
	var to := from + dir * length
	var hit := Game.raycast_world(from, to)
	if not hit.is_empty():
		to = hit["position"]
	return to


## O raio parou numa parede (não chegou ao alcance total)?
func _beam_blocked(from: Vector3, to: Vector3, length: float) -> bool:
	return from.distance_to(to) < length - 0.05


## Inimigos atravessados pelo raio, do mais perto ao mais longe.
func _enemies_on_beam(from: Vector3, to: Vector3, width: float) -> Array[Actor]:
	var out: Array[Actor] = []
	var seg := to - from
	var flat_len := Vector2(seg.x, seg.z).length()
	var dists: Array[float] = []
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.flat_distance_to_segment(enemy.global_position, from, to) > width * 0.5 + enemy.body_radius:
			continue
		# Altura do raio no ponto do inimigo.
		var along: float = clampf(Game.flat_distance(from, enemy.global_position) / maxf(flat_len, 0.01), 0.0, 1.0)
		var beam_y: float = lerpf(from.y, to.y, along)
		if absf(Game.body_center(enemy).y - beam_y) > BEAM_HEIGHT_TOLERANCE + enemy.body_radius * 0.5:
			continue
		var d := Game.flat_distance(from, enemy.global_position)
		var i := 0
		while i < dists.size() and dists[i] < d:
			i += 1
		dists.insert(i, d)
		out.insert(i, enemy)
	return out


func _hit_switches(from: Vector3, to: Vector3) -> void:
	for sw in get_tree().get_nodes_in_group("switches"):
		var n := sw as Node3D
		if Game.flat_distance_to_segment(n.global_position, from, to) < 0.9:
			if not bool(n.get("on")):
				FeixeFX.sparks_at(n.global_position + Vector3(0, 0.5, 0), Vector3.UP, 3, 3.0, 70.0)
			n.call("on_beam_hit", self)


# ---------------------------------------------------------------- Clique + Foco Óptico

## Disparo Óptico: instantâneo, para no primeiro inimigo ou parede. Três
## acertos seguidos no mesmo inimigo completam o Foco; o próximo disparo
## nele consome o Foco e soma focus_bonus. Errar ou trocar de alvo zera.
func optic_shot() -> bool:
	if not cooldown_ready("basic") or ability_lock > 0.0:
		return false
	var s := _fb()
	start_cooldown("basic", s.shot_interval)
	var from := _muzzle()
	var to := _beam_end(from, s.shot_range)
	_hit_switches(from, to)
	var victims := _enemies_on_beam(from, to, s.shot_width)
	var charged := false
	if victims.is_empty():
		_lose_focus()
		FeixeFX.shot(from, to, false, _beam_blocked(from, to, s.shot_range))
	else:
		var v: Actor = victims[0]
		var c: Vector3 = Game.body_center(v)
		to = from + (to - from).normalized() * from.distance_to(c)
		var dir := c - global_position
		dir.y = 0.0
		if v != _focus_target:
			_lose_focus()
			_focus_target = v
		charged = _focus_full
		var dmg := s.shot_damage + (s.focus_bonus if charged else 0.0)
		# O disparo com Foco é forte: cancela a carga do tiro do inimigo.
		var info := {"strength": Impact.STRONG if charged else Impact.WEAK, "dir": dir, "ability": false}
		if charged:
			info["push"] = 0.35
		var dealt := deal_damage(v, dmg, info)
		var blocked := dealt <= 0.0 and not v.is_dead
		if v.is_dead:
			_focus_target = null
			_set_focus(0, false)
		elif blocked:
			pass # escudo de frente: não conta, mas também não perde
		elif charged:
			_set_focus(0, false)
		else:
			var n := _focus_stacks + 1
			_set_focus(mini(n, s.focus_hits), n >= s.focus_hits)
		FeixeFX.shot(from, to, charged and not blocked, false)
	if lenses != null:
		lenses.flash(0.7 if charged else 0.3)
	_anim("Spell_Simple_Shoot", 2.0)
	return true


# ---------------------------------------------------------------- Q: Feixe de Contenção

## ai_limit > 0 limita a duração (usado pela IA).
func start_laser(ai_limit: float) -> bool:
	if _laser_active or not cooldown_ready("q") or _sweep_time >= 0.0 or _charge_time >= 0.0:
		return false
	_laser_active = true
	_laser_time = 0.0
	_laser_tick = 0.0
	_laser_ai_limit = ai_limit
	_laser_ai_empty = 0.0
	_laser_on.clear()
	_laser_power = 0.0
	move_multiplier = _fb().laser_move_multiplier
	var from := _muzzle()
	_laser_fx = FeixeFX.beam(self)
	_laser_fx.update_beam(from, from + facing * 0.1, global_position, 0.05, 0.0)
	FeixeFX.star(from, 0.9, 0.15)
	_temple_target = 1.0
	return true


func stop_laser() -> void:
	if not _laser_active:
		return
	_laser_active = false
	move_multiplier = 1.0
	_laser_on.clear()
	if is_instance_valid(_laser_fx):
		_laser_fx.stop()
	_laser_fx = null
	if _sweep_time < 0.0 and _charge_time < 0.0:
		_temple_target = 0.0
	if lenses != null:
		lenses.flash(0.6)
		if _charge_time < 0.0 and _sweep_time < 0.0:
			lenses.charge = 0.0
	start_cooldown("q", _fb().q_cooldown)


func laser_active() -> bool:
	return _laser_active


func laser_time_left() -> float:
	return maxf(0.0, _fb().laser_max_time - _laser_time)


func _tick_laser(delta: float) -> void:
	var s := _fb()
	_laser_time += delta
	var limit := s.laser_max_time
	if _laser_ai_limit > 0.0:
		limit = minf(limit, _laser_ai_limit)
	if _laser_time >= limit:
		stop_laser()
		return
	# Recuo: escorrega para trás (para nas paredes).
	if not busy and is_on_floor():
		move_and_collide(-facing * s.laser_recoil * delta)
	var from := _muzzle()
	var to := _beam_end(from, s.laser_range)
	_cut_blast_doors(from, to, delta)
	_hit_switches(from, to)
	# Tempo do feixe em cada inimigo: quem sai do feixe recomeça do zero.
	var on := _enemies_on_beam(from, to, s.laser_width)
	var still: Dictionary = {}
	var best := 0.0
	for enemy in on:
		var id := enemy.get_instance_id()
		var t: float = float(_laser_on.get(id, 0.0)) + delta
		still[id] = t
		best = maxf(best, t)
	_laser_on = still
	if controlled or on.size() > 0:
		_laser_ai_empty = 0.0
	else:
		_laser_ai_empty += delta
		if _laser_ai_empty > 0.5:
			stop_laser()
			return
	# Largura e brilho acompanham o dano (sobem devagar, afinam rápido).
	var want := s.laser_power_at(best) if not on.is_empty() else 0.0
	_laser_power = move_toward(_laser_power, want, delta * (3.0 if want < _laser_power else 6.0))
	var grow := clampf(_laser_time / LASER_GROW_TIME, 0.0, 1.0)
	var width := lerpf(LASER_VISUAL_MIN, LASER_VISUAL_MAX, _laser_power) * grow
	var shown := from.lerp(to, grow)
	if is_instance_valid(_laser_fx):
		_laser_fx.update_beam(from, shown, global_position, maxf(width, 0.04), _laser_power)
	if lenses != null:
		lenses.charge = 0.6 + 0.4 * _laser_power
	# Dano em pulsos de 0,25 s, pelo tempo que o feixe está em cada um.
	_laser_tick += delta
	if _laser_tick >= 0.25:
		var dt := _laser_tick
		_laser_tick = 0.0
		for enemy in on:
			var t: float = _laser_on.get(enemy.get_instance_id(), 0.0)
			var dmg := s.laser_dps_at(t) * dt
			# Forte: interrompe o inimigo. "quiet" evita pausa a cada pulso.
			deal_damage(enemy, dmg, {"strength": Impact.STRONG, "push": 0.3, "quiet": true, "dir": facing, "ability": true, "color": Color(1, 0.4, 0.4)})
			FeixeFX.beam_contact(Game.body_center(enemy), (to - from).normalized(), _laser_power)


## Porta blindada: o Q corta se passar por ela (com folga de ~1 m), mesmo
## que a ponta do raio pare no batente da parede.
func _cut_blast_doors(from: Vector3, to: Vector3, delta: float) -> void:
	var far := from + (to - from).normalized() * (from.distance_to(to) + 1.0)
	for d in get_tree().get_nodes_in_group("blast_doors"):
		var door := d as Door
		if door == null or door.is_open:
			continue
		if absf(door.global_position.y - global_position.y) > 2.0:
			continue
		if Game.flat_distance_to_segment(door.global_position, from, far) <= 1.6:
			door.cut(delta, self)


# ---------------------------------------------------------------- E: Ruptura Óptica

## Um raio sai dos óculos e abre em leque horizontal: dano, interrompe e
## empurra todos no cone (drones também).
func repulsion_pulse() -> bool:
	if not cooldown_ready("e") or ability_lock > 0.0:
		return false
	var s := _fb()
	start_cooldown("e", s.e_cooldown)
	ability_lock = 0.25
	var from := _muzzle()
	FeixeFX.cone(self, from, facing, s.pulse_range, s.pulse_arc_degrees)
	if lenses != null:
		lenses.flash(1.0)
	Game.shake(0.1, 0.16)
	_anim("Punch_Cross", 1.6)
	for e in Game.living_enemies():
		var enemy := e as Actor
		if Game.in_cone(global_position, facing, enemy.global_position, s.pulse_range, s.pulse_arc_degrees, enemy.body_radius) \
				and Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			var dir := enemy.global_position - global_position
			dir.y = 0.0
			deal_damage(enemy, s.pulse_damage, {"strength": Impact.STRONG, "push": s.pulse_push_meters, "dir": dir, "ability": true})
			FeixeFX.push_trail(enemy, dir.normalized(), enemy.flying)
	return true


# ---------------------------------------------------------------- R: Aniquilação Circular

## Dois dedos na têmpora e marcação no chão (blast_charge_time); depois um
## raio de 14 m dá a volta no sentido horário em blast_sweep_time e o corpo
## gira junto. Atravessa inimigos, paredes bloqueiam. Parado e invulnerável.
func use_special(_aim: Vector3) -> bool:
	if _sweep_time >= 0.0 or _charge_time >= 0.0:
		return false
	var s := _fb()
	stop_laser()
	busy = true
	invulnerable = true
	velocity = Vector3.ZERO
	ability_lock = s.blast_charge_time + s.blast_sweep_time + 0.1
	_charge_time = 0.0
	_sweep_yaw0 = atan2(-facing.x, -facing.z)
	_visual_yaw = _sweep_yaw0
	_sweep_hit.clear()
	_temple_target = 1.0
	_set_outline(true)
	_mark_fx = FeixeFX.sweep_mark(global_position, _reach_outline(s.blast_radius), s.blast_charge_time)
	return true


## Contorno do alcance cortado pelas paredes (na altura dos óculos).
func _reach_outline(radius: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var eyes := global_position + Vector3(0, LENS_REST.y, 0)
	var n := 96
	for i in n:
		var a := TAU * float(i) / float(n)
		var d := Vector3(sin(a), 0, cos(a))
		var to := eyes + d * radius
		var hit := Game.raycast_world(eyes, to)
		var r := radius
		if not hit.is_empty():
			r = Vector2(hit["position"].x - eyes.x, hit["position"].z - eyes.z).length()
		out.append(d * r)
	return out


func _set_outline(on: bool) -> void:
	for m in _outline_meshes:
		if not is_instance_valid(m):
			continue
		if on:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_FRONT
			mat.grow = true
			mat.grow_amount = 0.012
			mat.albedo_color = Color(1.0, 0.78, 0.74)
			m.material_overlay = mat
		else:
			m.material_overlay = null


func _process_busy(delta: float) -> void:
	if _charge_time >= 0.0:
		_tick_charge(delta)
	elif _sweep_time >= 0.0:
		_tick_sweep(delta)


func _tick_charge(delta: float) -> void:
	var s := _fb()
	_charge_time += delta
	var k := clampf(_charge_time / s.blast_charge_time, 0.0, 1.0)
	if lenses != null:
		lenses.charge = k
	if _charge_time < s.blast_charge_time:
		return
	_charge_time = -1.0
	_sweep_time = 0.0
	if lenses != null:
		lenses.flash(1.0)
	FeixeFX.star(_muzzle(), 2.6, 0.3)
	_sweep_fx = FeixeFX.sweep(self, s.blast_radius, _mark_fx)


func _tick_sweep(delta: float) -> void:
	var s := _fb()
	_sweep_time += delta
	var k := clampf(_sweep_time / s.blast_sweep_time, 0.0, 1.0)
	# Começa e termina um pouco mais devagar; horário visto de cima = yaw caindo.
	var turned := TAU * (k - sin(TAU * k) * 0.06)
	var yaw := _sweep_yaw0 - turned
	facing = Vector3(-sin(yaw), 0.0, -cos(yaw))
	_visual_yaw = yaw
	visual.rotation.y = yaw
	var from := _muzzle()
	var to := from + facing * s.blast_radius
	var hit := Game.raycast_world(from, to)
	if not hit.is_empty():
		to = hit["position"]
	if is_instance_valid(_sweep_fx):
		_sweep_fx.sweep_to(from, to, yaw, global_position)
	Game.shake(0.05, 0.1)
	# Dano em quem o raio já alcançou nesta volta, se nenhuma parede o protege.
	for e in Game.living_enemies():
		var enemy := e as Actor
		if enemy in _sweep_hit:
			continue
		if Game.flat_distance(enemy.global_position, global_position) > s.blast_radius + enemy.body_radius \
				or not Game.vertical_ok(global_position.y, enemy, Game.REACH_RANGED):
			continue
		var d := enemy.global_position - global_position
		var enemy_yaw := atan2(-d.x, -d.z)
		if fposmod(_sweep_yaw0 - enemy_yaw, TAU) <= turned + 0.05 or k >= 1.0:
			_sweep_hit.append(enemy)
			var c := Game.body_center(enemy)
			if not Game.raycast_world(from, c).is_empty():
				continue # atrás de parede
			d.y = 0.0
			deal_damage(enemy, s.blast_damage, {"strength": Impact.SPECIAL, "ability": true, "dir": d, "color": Color(1, 0.3, 0.3)})
			FeixeFX.sweep_hit(c, d.normalized())
	if k >= 1.0:
		_end_sweep()


func _end_sweep() -> void:
	_sweep_time = -1.0
	busy = false
	_temple_target = 0.0
	_set_outline(false)
	if lenses != null:
		lenses.charge = 0.0
	if _dash_time_left <= 0.0:
		invulnerable = false
	if is_instance_valid(_sweep_fx):
		_sweep_fx.end_sweep(_mark_fx)
	_sweep_fx = null
	_mark_fx = null


func _on_interrupted() -> void:
	stop_laser()
	super._on_interrupted()


# ---------------------------------------------------------------- dash

## Flash nos óculos, 2–3 silhuetas vermelhas curtas e flash na chegada.
func _update_dash_fx(delta: float) -> void:
	var dashing := _dash_time_left > 0.0
	if dashing and not _was_dashing:
		if lenses != null:
			lenses.flash(0.8)
		FeixeFX.dash_ghost(global_position, facing, 0.45)
		FeixeFX.sparks_at(global_position + Vector3(0, 0.1, 0), Vector3.UP - facing, 4, 2.0, 60.0)
		_ghosts_left = 2
		_ghost_clock = 0.0
	elif dashing and _ghosts_left > 0:
		_ghost_clock += delta
		if _ghost_clock >= 0.05:
			_ghost_clock = 0.0
			FeixeFX.dash_ghost(global_position, facing, 0.3 if _ghosts_left == 2 else 0.18)
			_ghosts_left -= 1
	elif not dashing and _was_dashing:
		FeixeFX.star(global_position + Vector3(0, 1.0, 0), 0.6, 0.1)
	_was_dashing = dashing


# ---------------------------------------------------------------- IA

## Fica entre 7 e 10 m: avança acima de 11 m e recua abaixo de 5 m. Atira no
## inimigo com menos vida e continua nele para completar o Foco. Q quando
## alinha 2+ inimigos ou contra alvo prioritário (soldado com escudo);
## E quando 2+ chegam perto. Não usa a R.
func _ai_combat(target: Actor, delta: float) -> Vector3:
	var s := _fb()
	var near: Actor = target
	var aim := _ai_pick_target(near)
	_ai_target = aim
	face_towards(aim.global_position)
	var d_near := Game.flat_distance(global_position, near.global_position)
	var d_aim := Game.flat_distance(global_position, aim.global_position)
	if cooldown_ready("e") and _enemies_within(5.0) >= 2:
		repulsion_pulse()
	if not _laser_active and cooldown_ready("q") and d_aim <= s.laser_range * 0.9:
		var from := _muzzle()
		var to := _beam_end(from, s.laser_range)
		var lined := _enemies_on_beam(from, to, s.laser_width).size()
		if lined >= 2 or _is_priority(aim):
			start_laser(s.laser_max_time)
	if not _laser_active:
		optic_shot()
	var away := global_position - near.global_position
	away.y = 0.0
	if d_near < 5.0:
		return away.normalized() * 0.8
	if d_aim > 11.0:
		return navigate_to(aim.global_position, delta)
	return Vector3.ZERO


## Alvo da IA: mantém o alvo do Foco se ainda dá; senão o de menos vida à vista.
func _ai_pick_target(fallback: Actor) -> Actor:
	var s := _fb()
	if _focus_target != null and is_instance_valid(_focus_target) and not _focus_target.is_dead \
			and Game.flat_distance(global_position, _focus_target.global_position) <= s.shot_range \
			and Game.has_line_of_sight(global_position, _focus_target.global_position):
		return _focus_target
	var best: Actor = fallback
	var best_hp := INF
	for e in Game.living_enemies():
		var enemy := e as Actor
		if enemy == null or not enemy.get("active"):
			continue
		if Game.flat_distance(global_position, enemy.global_position) > s.shot_range:
			continue
		if not Game.has_line_of_sight(global_position, enemy.global_position):
			continue
		if enemy.health < best_hp:
			best_hp = enemy.health
			best = enemy
	return best


func _is_priority(enemy: Actor) -> bool:
	var st = enemy.get("stats")
	return st is EnemyStats and (st as EnemyStats).shielded


func _enemies_within(radius: float) -> int:
	var n := 0
	for e in Game.living_enemies():
		if Game.flat_distance(global_position, (e as Node3D).global_position) <= radius:
			n += 1
	return n


func go_down() -> void:
	stop_laser()
	_lose_focus()
	super.go_down()
	# O modelo tem animação de queda: não precisa deitar a cápsula.
	visual.rotation.x = 0.0
	visual.position.y = 0.0


func _on_damaged(amount: float, source: Node) -> void:
	super._on_damaged(amount, source)
	if not is_dead:
		_anim("Hit_Chest", 1.5)


func _anim(anim_name: String, speed: float) -> void:
	if model != null:
		model.play_once(anim_name, speed)
