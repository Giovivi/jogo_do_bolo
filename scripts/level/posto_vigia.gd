class_name PostoVigia
extends Node3D
## Fase-piloto "Posto Vigia-01" em greybox, montada por código.
## Grade de 2 m, paredes de 3 m. Coordenadas: x = leste, z = sul (metros).
##
## Ida (linha de cima):  1. Entrada -> 2. Triagem -> 3. Celas -> 4. Hangar
## Volta (linha de baixo): porta de serviço -> Corredor -> Cofre -> 5. Saída

signal feixe_rescued
signal run_completed

const WALL_H := 3.0
const WALL_T := 0.5
const FADE_RADIUS := 6.0
const GLASS_VISUAL_H := 1.0

const SOLDIER: EnemyStats = preload("res://data/soldado.tres")
const SHIELD_SOLDIER: EnemyStats = preload("res://data/soldado_escudo.tres")
const DRONE: EnemyStats = preload("res://data/drone.tres")

## Semente da variação (0 = aleatória a cada entrada).
@export var seed_value: int = 0

var player_spawn := Vector3(-4, 0, 4)
var feixe_cell_position := Vector3(60, 0, -7)

var rng := RandomNumberGenerator.new()
var _walls: Array[Dictionary] = []
## Áreas de chão andável (x0, z0, largura, profundidade).
var _floor_rects: Array[Rect2] = []
## Áreas que ficam abertas sem ser chão (vão entre os vidros da triagem e do cofre).
var _open_rects: Array[Rect2] = []
var _hints: Array[Dictionary] = []
var _cage_front: StaticBody3D
var _service_door: Door
var _switch_on: bool = false
var _blast_open: bool = false
var _candidates_root: Node3D
var _exit_rect := Rect2(-5, 23, 4, 4)
var _cell_timer: float = -1.0
var _cell_events: Array[Dictionary] = []
var _cell_done: bool = false
## Textura do chão da sala em construção: [id, metros por repetição, tinta].
## Fotos do ambientCG (CC0), ver assets/textures/CREDITS.md.
var _floor_tex: Array = ["Concrete044D", 2.5, Color(0.8, 0.8, 0.82)]
const WALL_TEX := ["Concrete031", 3.0, Color(0.9, 0.92, 0.95)]
const CORRIDOR_TEX := ["Concrete044D", 2.5, Color(0.8, 0.8, 0.82)]


func _ready() -> void:
	# Depois do build() (também o da escola), cria as zonas de câmera.
	_build_camera_zones.call_deferred()


## Zonas de câmera por sala (tabela da seção 3.7).
func _build_camera_zones() -> void:
	var root := Node3D.new()
	root.name = "ZonasDeCamera"
	add_child(root)
	if self is Escola:
		CameraZone.make(root, -20, 8, 20, 24, CameraZone.Level.OPEN, "Frente")
		CameraZone.make(root, 72, -14, 88, 4, CameraZone.Level.MEDIUM, "Saguao")
		CameraZone.make(root, 56, -14, 71, 4, CameraZone.Level.MEDIUM, "Laboratorio")
		CameraZone.make(root, 89, -14, 104, 4, CameraZone.Level.MEDIUM, "Treino")
		CameraZone.make(root, 74, -24, 86, -14.5, CameraZone.Level.CLOSED, "Sala dos planos")
		return
	CameraZone.make(root, -8, -8, 8, 8, CameraZone.Level.MEDIUM, "Entrada")
	CameraZone.make(root, 20, -10, 40, 10, CameraZone.Level.OPEN, "Triagem")
	CameraZone.make(root, 25, -26, 35, -18, CameraZone.Level.CLOSED, "Sala secreta")
	CameraZone.make(root, 50, -10, 70, 10, CameraZone.Level.OPEN, "Celas")
	CameraZone.make(root, 78, -12, 102, 12, CameraZone.Level.OPEN, "Hangar")
	CameraZone.make(root, 36, 20, 92, 26, CameraZone.Level.CLOSED, "Corredor de servico")
	CameraZone.make(root, 24, 16, 36, 28, CameraZone.Level.CLOSED, "Cofre")
	CameraZone.make(root, -6, 16, 6, 28, CameraZone.Level.CLOSED, "Saida")


func build() -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	print("Posto Vigia-01: semente da variação = ", rng.seed)
	_candidates_root = Node3D.new()
	_candidates_root.name = "Candidatos"
	add_child(_candidates_root)
	_build_lighting()
	_build_entrada()
	_build_triagem()
	_build_secreta()
	_build_celas()
	_build_hangar()
	_build_volta()
	_build_structure()
	# Chão com buracos de verdade nos vãos.
	_build_floor_collision()
	Game.chests_total = get_tree().get_nodes_in_group("chests").size()


# ================================================================ áreas

func _build_entrada() -> void:
	var c := Color(0.42, 0.44, 0.47)
	_room(-8, -8, 8, 8, c, {"E": [[0.0, 4.0]]})
	# Saliência com baú atrás de um vão de 2 m (ensina o pulo).
	_pit(-8, -5, -1, -3)
	_wall(-1.25, -8, -0.75, -3, WALL_H)
	_chest(Vector3(-4.5, 0, -6.5))
	_label("1. Entrada", Vector3(0, 0, 7))
	# 4 soldados em 2 grupos.
	_enemy_group("Entrada A", SOLDIER, 2, [Vector3(4, 0, -3), Vector3(3, 0, 3)])
	# Plataforma de 1 m no canto: sobe com um pulo.
	_platform(3, -8, 8, -4, 1.0)
	_enemy_group("Entrada B", SOLDIER, 2, [Vector3(6, 0, 5), Vector3(5.5, 1, -6)])
	if Game.rules.camera_behind:
		_hint(Rect2(-8, 0, 10, 8), "WASD move · mouse gira a câmera · Espaço pula · clique ataca · Q e E habilidades · Shift dash")
	else:
		_hint(Rect2(-8, 0, 10, 8), "WASD move · Espaço pula · mouse mira · clique ataca · Q e E habilidades · Shift dash")
	_hint(Rect2(-8, -3, 7, 2.5), "Vão de 2 m: pule (Espaço) com corrida até a saliência do baú.")
	_corridor_x(8, 20, 0.0, c)


func _build_triagem() -> void:
	var c := Color(0.4, 0.43, 0.5)
	_floor_tex = ["Tiles140", 2.0, Color(1.1, 1.12, 1.18)]
	_room(20, -10, 40, 10, c, {"W": [[0.0, 4.0]], "E": [[0.0, 4.0]], "N": [[30.0, 4.0]]}, {"S": [[30.0, 8.0]]})
	# Níveis: mezanino de 1 m no fundo e plataforma de 2 m no canto
	# nordeste (sobe pelo mezanino, degrau de 1 m), com baú no alto.
	_platform(20, -10, 34, -6, 1.0)
	_platform(34, -10, 40, -4, 2.0)
	_crate(25, -3, 2, 2)
	_crate(35, 4, 2, 2)
	_crate(26, 5, 1, 2)
	_label("2. Triagem", Vector3(30, 0, 8.5))
	# 3 baús escolhidos entre 5 pontos candidatos.
	_chest_candidates("Triagem baús", [Vector3(22, 1, -8), Vector3(38, 2, -8), Vector3(38, 0, 8), Vector3(22, 0, 8), Vector3(29, 0, -3)], 3)
	_enemy_group("Triagem A", SOLDIER, 2, [Vector3(24, 1, -8), Vector3(26, 0, 2)])
	_enemy_group("Triagem B", SOLDIER, 2, [Vector3(37, 2, -7), Vector3(34, 0, 7)])
	_enemy_group("Triagem C", SOLDIER, 2, [Vector3(31, 0, 6), Vector3(31, 1, -8)])
	_enemy_group("Triagem drones", DRONE, 2, [Vector3(36, 0, 0), Vector3(30, 0, 2)])
	_hint(Rect2(24, 4, 12, 6), "Atrás do vidro blindado, um cofre... A porta dele não abre por aqui.")
	_corridor_x(40, 50, 0.0, c)


func _build_secreta() -> void:
	var c := Color(0.35, 0.33, 0.42)
	_floor_tex = ["MetalPlates014", 1.6, Color(0.7, 0.72, 0.78)]
	# Corredor norte com vão de 4 m.
	_floor(28, -18, 32, -10, c)
	_wall(28 - WALL_T, -18, 28, -10, WALL_H)
	_wall(32, -18, 32 + WALL_T, -10, WALL_H)
	_pit(28, -15, 32, -11)
	_room(25, -26, 35, -18, c, {"S": [[30.0, 4.0]]})
	_chest(Vector3(30, 0, -23))
	_label("sala secreta", Vector3(30, 0, -20))
	_hint(Rect2(28, -11, 4, 1.5), "Vão de 4 m: só o Fênix passa. Pule e segure Espaço para planar.")


func _build_celas() -> void:
	var c := Color(0.38, 0.4, 0.4)
	_floor_tex = ["Tiles140", 2.0, Color(1.05, 1.1, 1.1)]
	_room(50, -10, 70, 10, c, {"W": [[0.0, 4.0]], "E": [[0.0, 4.0]]})
	_label("3. Celas", Vector3(60, 0, 8.5))
	# Cela do Feixe (a grade da frente some quando destrava).
	for cx in [57.5, 62.5]:
		var bar := _wall(cx - 0.25, -10, cx + 0.25, -4.5, WALL_H, Color(0.75, 0.8, 0.9))
		Look.texture_std(bar.get_child(1).material_override, "MetalPlates014", 1.6, Color(0.75, 0.8, 0.9))
	# Feixe já resgatado em outra ida: a cela fica aberta e vazia, sem
	# console nem defesa.
	var already_rescued: bool = Game.progress.get("feixe", false)
	if already_rescued:
		_cell_done = true
	else:
		_cage_front = _wall(57.25, -4.75, 62.75, -4.25, WALL_H, Color(0.5, 0.75, 0.95, 0.45))
		var console := CellConsole.new()
		console.position = Vector3(60, 0, -2)
		add_child(console)
		console.activated.connect(_start_cell_unlock)
	# Plataformas de 1 m nos cantos do sul, boas para defender a cela.
	_platform(50, 5, 54, 10, 1.0)
	_platform(66, 5, 70, 10, 1.0)
	if not already_rescued:
		_hint(Rect2(50, -10, 20, 20), "A cela do Feixe! Use o console (F) para destravar e aguente 60 s.")
	_corridor_x(70, 78, 0.0, c)


func _build_hangar() -> void:
	var c := Color(0.36, 0.38, 0.44)
	_floor_tex = ["Concrete046", 3.0, Color(0.58, 0.58, 0.6)]
	_room(78, -12, 102, 12, c, {"W": [[0.0, 4.0]], "S": [[90.0, 4.0]]})
	_label("4. Hangar", Vector3(90, 0, 10.5))
	# Passarela alta (inalcançável a pé) com o interruptor.
	var walkway := _box_body(Vector3(90, 1.5, -10.5), Vector3(24, 3, 3), Color(0.5, 0.52, 0.58), Game.LAYER_WALKWAY)
	walkway.name = "Passarela"
	Look.texture_std(walkway.get_child(1).material_override, "DiamondPlate008A", 1.5, Color(0.62, 0.65, 0.7))
	var sw := BeamSwitch.new()
	sw.position = Vector3(90, 3.5, -10.5)
	add_child(sw)
	var service := Door.new()
	service.name = "PortaServico"
	service.position = Vector3(90, 0, 12)
	add_child(service)
	service.setup(Vector3(4, WALL_H, 0.6), Color(0.75, 0.6, 0.2))
	Look.texture_std(service._mat, "PaintedMetal016", 1.5)
	_service_door = service
	sw.triggered.connect(_on_switch_triggered)
	# Torre de caixas no sudoeste (1 m e 2 m), longe da passarela de 3 m.
	_platform(80, 7, 84, 10, 1.0)
	_platform(80, 4, 84, 7, 2.0)
	_crate(87, 4, 2, 2)
	_crate(96, -2, 2, 2)
	_chest_candidates("Hangar baú", [Vector3(99, 0, 9), Vector3(82, 2, 5.5)], 1)
	_enemy_group("Hangar drones 1", DRONE, 2, [Vector3(86, 0, -4), Vector3(84, 0, -6)])
	_enemy_group("Hangar drones 2", DRONE, 2, [Vector3(96, 0, -5), Vector3(98, 0, 2)])
	_enemy_group("Hangar escudo", SHIELD_SOLDIER, 1, [Vector3(90, 0, 4), Vector3(92, 0, 0)])
	_hint(Rect2(78, -6, 24, 18), "Interruptor na passarela alta: troque para o Feixe (2) e acerte com o tiro.")


func _on_switch_triggered() -> void:
	_switch_on = true
	if _service_door != null:
		_service_door.open()
	Game.message("A porta de serviço abriu (sul do hangar).", 3.0)


func _on_blast_door_opened() -> void:
	_blast_open = true
	Game.message("Porta blindada cortada!", 2.5)


func _build_volta() -> void:
	var c := Color(0.34, 0.36, 0.38)
	_floor_tex = CORRIDOR_TEX
	# Corredor de serviço (sai do hangar para o sul).
	_floor(88, 12, 92, 20, c)
	_wall(88 - WALL_T, 12, 88, 20, WALL_H)
	_wall(92, 12, 92 + WALL_T, 20, WALL_H)
	# Corredor longo até o cofre (a parede oeste é a do cofre).
	_room(36, 20, 92, 26, c, {"N": [[90.0, 4.0]]}, {}, ["W"])
	_label("corredor", Vector3(64, 0, 24.5))
	_enemy_group("Corredor", SOLDIER, 2, [Vector3(60, 0, 23), Vector3(70, 0, 23), Vector3(50, 0, 23)])
	# Cofre blindado, visto pelo vidro da triagem.
	var vc := Color(0.45, 0.42, 0.33)
	# Fosso de serviço entre o vidro da triagem e o do cofre: fica aberto
	# para o cofre aparecer, mas não é chão andável.
	_open_rects.append(Rect2(26, 10, 8, 6))
	_box_visual(Vector3(30, -0.6, 13), Vector3(8, 0.2, 6), Color(0.12, 0.13, 0.15))
	_floor_tex = ["DiamondPlate008A", 1.5, Color(0.85, 0.82, 0.72)]
	_room(24, 16, 36, 28, vc, {"E": [[23.0, 4.0]], "W": [[22.0, 4.0]]}, {"N": [[30.0, 8.0]]})
	_label("cofre", Vector3(30, 0, 26.5))
	var blast := Door.new()
	blast.name = "PortaBlindada"
	blast.blast_door = true
	blast.position = Vector3(36, 0, 23)
	add_child(blast)
	blast.setup(Vector3(0.8, WALL_H, 4), Color(0.55, 0.6, 0.65))
	blast.opened_door.connect(_on_blast_door_opened)
	_chest(Vector3(27, 0, 19), true)
	_hint(Rect2(37, 20, 8, 6), "Porta blindada: com o Feixe, segure Q para cortar com o laser.")
	# Saída.
	_corridor_x(6, 24, 22.0, c)
	_floor_tex = ["Concrete044D", 2.5, Color(0.72, 0.85, 0.78)]
	_room(-6, 16, 6, 28, Color(0.3, 0.42, 0.36), {"E": [[22.0, 4.0]]})
	_label("5. Saída", Vector3(0, 0, 17))
	_chest(Vector3(2, 0, 25), false, true)
	var pad := _box_visual(Vector3(_exit_rect.get_center().x, 0.06, _exit_rect.get_center().y), Vector3(_exit_rect.size.x, 0.1, _exit_rect.size.y), Color(0.3, 0.95, 0.6))
	pad.name = "SaidaPad"
	_label("SAÍDA", Vector3(_exit_rect.get_center().x, 0, _exit_rect.get_center().y))


# ================================================================ cela e ondas

func _start_cell_unlock() -> void:
	_cell_timer = 0.0
	Game.message("Destravando a cela... aguente 60 segundos!", 3.0)
	var west := Vector3(51.5, 0, 0)
	var east := Vector3(68.5, 0, 0)
	var south := Vector3(60, 0, 8)
	_cell_events = [
		{"t": 0.0, "stats": SOLDIER, "pos": west},
		{"t": 0.5, "stats": SOLDIER, "pos": east},
		{"t": 12.0, "stats": DRONE, "pos": south},
		{"t": 13.0, "stats": SOLDIER, "pos": west},
		{"t": 24.0, "stats": SOLDIER, "pos": east},
		{"t": 25.0, "stats": SOLDIER, "pos": west},
		{"t": 36.0, "stats": DRONE, "pos": south},
		{"t": 37.0, "stats": SOLDIER, "pos": east},
		{"t": 48.0, "stats": DRONE, "pos": south},
	]


func objective_text() -> String:
	if not _cell_done:
		if _cell_timer >= 0.0:
			return "Defenda a cela: %d s" % int(ceil(cell_time_left()))
		return "Encontre a cela e liberte o mutante preso"
	if not _switch_on:
		return "Hangar: acerte o interruptor da passarela com o Feixe"
	if not _blast_open:
		return "Volte pela porta de serviço e corte a porta blindada do cofre"
	return "Vá para a saída"


func cell_time_left() -> float:
	if _cell_timer < 0.0 or _cell_done:
		return -1.0
	return maxf(0.0, Game.rules.cell_unlock_time - _cell_timer)


func _process_cell(delta: float) -> void:
	if _cell_timer < 0.0 or _cell_done:
		return
	_cell_timer += delta
	while not _cell_events.is_empty() and float(_cell_events[0]["t"]) <= _cell_timer:
		var ev: Dictionary = _cell_events.pop_front()
		var st: EnemyStats = ev["stats"]
		var p: Vector3 = ev["pos"]
		_spawn_enemy(st, p + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), true)
	if _cell_timer >= Game.rules.cell_unlock_time:
		open_cell()


## Também usado pelo atalho de teste F3.
func open_cell() -> void:
	if _cell_done:
		return
	_cell_done = true
	_cell_timer = Game.rules.cell_unlock_time
	if _cage_front != null:
		_cage_front.queue_free()
		var kept: Array[Dictionary] = []
		for w in _walls:
			if w["body"] != _cage_front:
				kept.append(w)
		_walls = kept
		_cage_front = null
	feixe_rescued.emit()


# ================================================================ por quadro

func _physics_process(delta: float) -> void:
	_process_cell(delta)
	var party := Game.party
	if party == null or party.controlled_hero == null:
		return
	var hero: Hero = party.controlled_hero
	_update_wall_fade(hero.global_position)
	_update_hints(hero.global_position)
	if not Game.run_finished and _exit_rect.has_point(Vector2(hero.global_position.x, hero.global_position.z)):
		run_completed.emit()


func _update_hints(pos: Vector3) -> void:
	var p := Vector2(pos.x, pos.z)
	for h in _hints:
		if h["shown"]:
			continue
		var r: Rect2 = h["rect"]
		if r.has_point(p):
			h["shown"] = true
			Game.message(h["text"], 5.0)


## Paredes entre a câmera e o herói, perto dele, ficam transparentes.
func _update_wall_fade(hero_pos: Vector3) -> void:
	if Game.camera == null or not Game.rules.wall_fade:
		return
	var to_cam := Game.camera.global_transform.basis.z
	to_cam.y = 0.0
	to_cam = to_cam.normalized()
	var hp := Vector2(hero_pos.x, hero_pos.z)
	var cam2 := Vector2(to_cam.x, to_cam.z)
	for w in _walls:
		var r: Rect2 = w["rect"]
		var closest := Vector2(clampf(hp.x, r.position.x, r.end.x), clampf(hp.y, r.position.y, r.end.y))
		var off := closest - hp
		var fade := off.length() < FADE_RADIUS and off.dot(cam2) > 0.2
		if fade != w["faded"]:
			w["faded"] = fade
			var mat: StandardMaterial3D = w["mat"]
			var base: Color = w["color"]
			if fade:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = Color(base.r, base.g, base.b, 0.18)
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if base.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color = base


# ================================================================ estrutura em corte

## Preenche todo o entorno das salas com estrutura maciça, para não haver
## "buraco" no mapa. Perto do lado da câmera, a estrutura é cortada baixa
## (como uma maquete em corte); no fundo, sobe até a altura das paredes.
func _build_structure() -> void:
	var cell := 1.0
	var x_min := -30
	var x_max := 126
	var z_min := -46
	var z_max := 52
	var nx := x_max - x_min
	var nz := z_max - z_min
	var open := PackedByteArray()
	open.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var p := Vector2(x_min + ix + 0.5, z_min + iz + 0.5)
			var v := 0
			for r in _floor_rects:
				if r.has_point(p):
					v = 1
					break
			if v == 0:
				for r in _open_rects:
					if r.has_point(p):
						v = 2
						break
			open[iz * nx + ix] = v

	# Direção em que a câmera olha, no chão.
	var yaw := deg_to_rad(Game.rules.camera_yaw_degrees)
	var view := Vector2(-sin(yaw), -cos(yaw))
	var pitch := deg_to_rad(maxf(Game.rules.camera_pitch_degrees, 5.0))
	var back_h := maxf(Game.rules.backdrop_height, WALL_H)
	var reach := back_h / tan(pitch) + Game.rules.cutaway_margin

	# 0 = aberto, 1 = estrutura baixa (cortada), 2 = estrutura alta.
	var kind := PackedByteArray()
	kind.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var idx := iz * nx + ix
			if open[idx] != 0:
				kind[idx] = 0
				continue
			var c := Vector2(x_min + ix + 0.5, z_min + iz + 0.5)
			var low := false
			var k := 0.5
			# Câmera atrás do herói: sem corte, paredes inteiras.
			if Game.rules.camera_behind:
				k = reach + 1.0
			while k <= reach:
				var q := c + view * k
				var qx := int(floor(q.x)) - x_min
				var qz := int(floor(q.y)) - z_min
				if qx >= 0 and qx < nx and qz >= 0 and qz < nz and open[qz * nx + qx] != 0:
					low = true
					break
				k += 0.5
			kind[idx] = 1 if low else 2

	var low_h := Game.rules.cutaway_height
	var st_wall := _surface()
	var st_cap := _surface()
	var st_upper := _surface()
	var st_trim := _surface()
	var st_cut := _surface()
	var st_cut_cap := _surface()
	var unused := _surface()
	for iz in nz:
		var ix := 0
		while ix < nx:
			var kd := kind[iz * nx + ix]
			if kd == 0:
				ix += 1
				continue
			var start := ix
			while ix < nx and kind[iz * nx + ix] == kd:
				ix += 1
			var x0 := float(x_min + start) * cell
			var x1 := float(x_min + ix) * cell
			var z0 := float(z_min + iz) * cell
			var z1 := z0 + cell
			if kd == 2:
				# Parede de 3 m, faixa escura no topo dela e estrutura acima.
				_add_box(st_wall, unused, Vector3(x0, 0.0, z0), Vector3(x1, WALL_H - 0.25, z1))
				_add_box(st_trim, unused, Vector3(x0, WALL_H - 0.25, z0), Vector3(x1, WALL_H, z1))
				_add_box(st_upper, st_cap, Vector3(x0, WALL_H, z0), Vector3(x1, back_h, z1))
			else:
				_add_box(st_cut, st_cut_cap, Vector3(x0, 0.0, z0), Vector3(x1, low_h, z1))

	var mesh := ArrayMesh.new()
	_commit(st_wall, mesh, Color(0.58, 0.6, 0.64))
	_commit(st_trim, mesh, Color(0.24, 0.25, 0.28))
	_commit(st_upper, mesh, Color(0.35, 0.37, 0.4))
	_commit(st_cap, mesh, Color(0.14, 0.15, 0.17))
	_commit(st_cut, mesh, Color(0.3, 0.31, 0.34))
	_commit(st_cut_cap, mesh, Color(0.22, 0.23, 0.26))
	var mi := MeshInstance3D.new()
	mi.name = "Estrutura"
	mi.mesh = mesh
	add_child(mi)

	# As paredes que ficaram dentro da estrutura continuam colidindo,
	# mas não precisam mais aparecer.
	var kept: Array[Dictionary] = []
	for w in _walls:
		var r: Rect2 = w["rect"]
		if _rect_fully_solid(r, open, x_min, z_min, nx, nz):
			var body: StaticBody3D = w["body"]
			(body.get_child(1) as MeshInstance3D).visible = false
		else:
			kept.append(w)
	_walls = kept


func _rect_fully_solid(r: Rect2, open: PackedByteArray, x_min: int, z_min: int, nx: int, nz: int) -> bool:
	var ix0 := int(floor(r.position.x + 0.01)) - x_min
	var ix1 := int(ceil(r.end.x - 0.01)) - x_min
	var iz0 := int(floor(r.position.y + 0.01)) - z_min
	var iz1 := int(ceil(r.end.y - 0.01)) - z_min
	for iz in range(iz0, iz1):
		for ix in range(ix0, ix1):
			if ix < 0 or ix >= nx or iz < 0 or iz >= nz:
				continue
			if open[iz * nx + ix] != 0:
				return false
	return true


func _surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _commit(st: SurfaceTool, mesh: ArrayMesh, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Concreto do bunker nas paredes, metal escuro na faixa do topo.
	if color.r > 0.5:
		Look.texture_std(mat, WALL_TEX[0], WALL_TEX[1], WALL_TEX[2])
	elif color.r > 0.33:
		Look.texture_std(mat, "Concrete032", 3.0, Color(0.75, 0.77, 0.8))
	elif color.r > 0.27:
		Look.texture_std(mat, "Concrete032", 3.0, Color(0.68, 0.7, 0.74))
	elif color.r > 0.23:
		Look.texture_std(mat, "Metal027", 2.0, Color(0.8, 0.82, 0.86))
	st.set_material(mat)
	st.commit(mesh)


## Caixa: laterais em "sides", tampa em "top" (sem fundo).
func _add_box(sides: SurfaceTool, top: SurfaceTool, a: Vector3, b: Vector3) -> void:
	_quad(top, Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z), Vector3.UP)
	_quad(sides, Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z), Vector3.BACK)
	_quad(sides, Vector3(b.x, a.y, a.z), Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3.FORWARD)
	_quad(sides, Vector3(b.x, a.y, b.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3.RIGHT)
	_quad(sides, Vector3(a.x, a.y, a.z), Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(a.x, b.y, a.z), Vector3.LEFT)


func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3) -> void:
	for v in [p0, p1, p2, p0, p2, p3]:
		st.set_normal(normal)
		st.add_vertex(v)


# ================================================================ kit de peças

func _build_lighting() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)


## Plataforma maciça de altura "h" (em que se sobe pulando), com borda
## clara no topo para ler a altura com a câmera baixa.
func _platform(x0: float, z0: float, x1: float, z1: float, h: float) -> StaticBody3D:
	var col := Color(0.5, 0.53, 0.58) if h <= 1.0 else Color(0.46, 0.49, 0.55)
	var body := _box_body(Vector3((x0 + x1) * 0.5, h * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, h, z1 - z0), col, Game.LAYER_WORLD)
	body.name = "Plataforma"
	Look.texture_std(body.get_child(1).material_override, "DiamondPlate008A", 1.5, Color(0.95, 0.97, 1.0) if h <= 1.0 else Color(0.85, 0.88, 0.92))
	var trim := Color(0.93, 0.8, 0.35)
	var t := 0.1
	var y := h + 0.01
	# Faixa de aviso amarela e preta nas bordas.
	for strip in [
		_box_visual(Vector3((x0 + x1) * 0.5, y, z1 - t * 0.5), Vector3(x1 - x0, 0.02, t), trim),
		_box_visual(Vector3((x0 + x1) * 0.5, y, z0 + t * 0.5), Vector3(x1 - x0, 0.02, t), trim),
		_box_visual(Vector3(x0 + t * 0.5, y, (z0 + z1) * 0.5), Vector3(t, 0.02, z1 - z0), trim),
		_box_visual(Vector3(x1 - t * 0.5, y, (z0 + z1) * 0.5), Vector3(t, 0.02, z1 - z0), trim),
	]:
		Look.texture_std(strip.material_override, "PaintedMetal016", 0.8)
	return body


## Colisão do chão feita por faixas de 1 m, sem os vãos: cair num vão é
## cair de verdade (o herói volta para a última beirada segura).
func _build_floor_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "ChaoColisao"
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	var bounds := Rect2()
	var first := true
	for r in _floor_rects:
		bounds = r if first else bounds.merge(r)
		first = false
	var x_min := int(floor(bounds.position.x))
	var x_max := int(ceil(bounds.end.x))
	var z_min := int(floor(bounds.position.y))
	var z_max := int(ceil(bounds.end.y))
	for z in range(z_min, z_max):
		var x := x_min
		while x < x_max:
			if not _is_solid_floor(x, z):
				x += 1
				continue
			var start := x
			while x < x_max and _is_solid_floor(x, z):
				x += 1
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(float(x - start), 1.0, 1.0)
			shape.shape = box
			shape.position = Vector3((float(start) + float(x)) * 0.5, -0.5, float(z) + 0.5)
			body.add_child(shape)


func _is_solid_floor(x: int, z: int) -> bool:
	var p := Vector2(float(x) + 0.5, float(z) + 0.5)
	for g in Game.gaps:
		if g.has_point(p):
			return false
	for r in _floor_rects:
		if r.has_point(p):
			return true
	return false


func _build_ground() -> void:
	# Um chão de colisão único; as salas só pintam o chão.
	var body := StaticBody3D.new()
	body.name = "ChaoColisao"
	body.collision_layer = Game.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 80)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(45, -0.5, 0)
	add_child(body)


func _floor(x0: float, z0: float, x1: float, z1: float, color: Color) -> void:
	_floor_rects.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	var ground := _box_visual(Vector3((x0 + x1) * 0.5, -0.1, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.2, z1 - z0), color)
	Look.texture_std(ground.material_override, _floor_tex[0], _floor_tex[1], _floor_tex[2])
	# Linhas da grade de 2 m.
	var grid_color := color.darkened(0.15)
	var x := ceilf(x0 / 2.0) * 2.0
	while x <= x1:
		_box_visual(Vector3(x, 0.005, (z0 + z1) * 0.5), Vector3(0.04, 0.01, z1 - z0), grid_color)
		x += 2.0
	var z := ceilf(z0 / 2.0) * 2.0
	while z <= z1:
		_box_visual(Vector3((x0 + x1) * 0.5, 0.005, z), Vector3(x1 - x0, 0.01, 0.04), grid_color)
		z += 2.0


## Sala retangular. openings/glass: {"N"|"S"|"W"|"E": [[centro, largura], ...]}
func _room(x0: float, z0: float, x1: float, z1: float, color: Color, openings: Dictionary = {}, glass: Dictionary = {}, skip: Array = []) -> void:
	_floor(x0, z0, x1, z1, color)
	var t := WALL_T
	for side in ["N", "S", "W", "E"]:
		if side in skip:
			continue
		var holes: Array = openings.get(side, [])
		var panes: Array = glass.get(side, [])
		var horizontal: bool = side == "N" or side == "S"
		var a := x0 - t if horizontal else z0
		var b := x1 + t if horizontal else z1
		var cuts: Array = []
		for o in holes:
			cuts.append([float(o[0]) - float(o[1]) * 0.5, float(o[0]) + float(o[1]) * 0.5, false])
		for g in panes:
			cuts.append([float(g[0]) - float(g[1]) * 0.5, float(g[0]) + float(g[1]) * 0.5, true])
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var cursor := a
		for cut in cuts:
			var c0: float = cut[0]
			var c1: float = cut[1]
			if c0 > cursor:
				_side_wall(side, cursor, c0, x0, z0, x1, z1, false)
			if cut[2]:
				_side_wall(side, c0, c1, x0, z0, x1, z1, true)
			cursor = c1
		if cursor < b:
			_side_wall(side, cursor, b, x0, z0, x1, z1, false)


func _side_wall(side: String, a: float, b: float, x0: float, z0: float, x1: float, z1: float, is_glass: bool) -> void:
	var t := WALL_T
	var col := Color(0.55, 0.8, 1.0, 0.35) if is_glass else Color(0.62, 0.63, 0.66)
	var body: StaticBody3D
	match side:
		"N":
			body = _wall(a, z0 - t, b, z0, WALL_H, col)
		"S":
			body = _wall(a, z1, b, z1 + t, WALL_H, col)
		"W":
			body = _wall(x0 - t, a, x0, b, WALL_H, col)
		_:
			body = _wall(x1, a, x1 + t, b, WALL_H, col)
	if is_glass:
		# O vidro aparece como mureta de 1 m (continua bloqueando 3 m).
		var mi := body.get_child(1) as MeshInstance3D
		var bm := mi.mesh as BoxMesh
		bm.size = Vector3(bm.size.x, GLASS_VISUAL_H, bm.size.z)
		mi.position.y = GLASS_VISUAL_H * 0.5 - WALL_H * 0.5


## Corredor leste-oeste de 4 m de largura centrado em z.
func _corridor_x(x0: float, x1: float, z: float, color: Color) -> void:
	var room_tex := _floor_tex
	_floor_tex = CORRIDOR_TEX
	_floor(x0, z - 2, x1, z + 2, color)
	_floor_tex = room_tex
	_wall(x0, z - 2 - WALL_T, x1, z - 2, WALL_H)
	_wall(x0, z + 2, x1, z + 2 + WALL_T, WALL_H)


func _wall(x0: float, z0: float, x1: float, z1: float, height: float, color: Color = Color(0.62, 0.63, 0.66)) -> StaticBody3D:
	var size := Vector3(x1 - x0, height, z1 - z0)
	var center := Vector3((x0 + x1) * 0.5, height * 0.5, (z0 + z1) * 0.5)
	# Paredes opacas: concreto do bunker (a cor vira a tinta da foto).
	if color.a >= 1.0 and color == Color(0.62, 0.63, 0.66):
		color = WALL_TEX[2]
	var body := _box_body(center, size, color, Game.LAYER_WORLD)
	var mi := body.get_child(1) as MeshInstance3D
	if color == WALL_TEX[2]:
		Look.texture_std(mi.material_override, WALL_TEX[0], WALL_TEX[1], color)
	_walls.append({
		"body": body,
		"rect": Rect2(x0, z0, x1 - x0, z1 - z0),
		"mat": mi.material_override,
		"color": color,
		"faded": false,
	})
	return body


func _crate(cx: float, cz: float, sx: float, sz: float) -> void:
	var crate := _box_body(Vector3(cx, 0.6, cz), Vector3(sx, 1.2, sz), Color(0.5, 0.45, 0.35), Game.LAYER_WORLD)
	# Caixote militar de chapa, verde-oliva.
	Look.texture_std(crate.get_child(1).material_override, "MetalPlates014", 1.2, Color(0.62, 0.66, 0.45))


func _box_body(center: Vector3, size: Vector3, color: Color, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	body.add_child(mi)
	body.position = center
	add_child(body)
	return body


func _box_visual(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = center
	add_child(mi)
	return mi


## Vão: buraco escuro com bloqueio invisível (só quem plana atravessa).
func _pit(x0: float, z0: float, x1: float, z1: float) -> void:
	_box_visual(Vector3((x0 + x1) * 0.5, 0.02, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.05, z1 - z0), Color(0.02, 0.02, 0.03))
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_GAPS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, 2.0, z1 - z0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3((x0 + x1) * 0.5, 1.0, (z0 + z1) * 0.5)
	add_child(body)
	Game.gaps.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	_label("vão %d m" % int(minf(x1 - x0, z1 - z0)), Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5))


func _chest(pos: Vector3, rare: bool = false, final_chest: bool = false) -> Chest:
	var ch := Chest.new()
	ch.rare = rare
	ch.final_chest = final_chest
	ch.position = pos
	ch.add_to_group("chests")
	add_child(ch)
	return ch


## Cria Marker3D para cada candidato e sorteia "count" deles.
func _chest_candidates(group_name: String, points: Array, count: int) -> void:
	var markers := _markers(group_name, points)
	var order := range(markers.size())
	_shuffle(order)
	for i in mini(count, order.size()):
		_chest(markers[order[i]].position)


func _enemy_group(group_name: String, st: EnemyStats, count: int, points: Array) -> void:
	var markers := _markers(group_name, points)
	var m: Marker3D = markers[rng.randi_range(0, markers.size() - 1)]
	for i in count:
		var offset := Vector3(cos(i * 2.4), 0, sin(i * 2.4)) * (1.5 if count > 1 else 0.0)
		_spawn_enemy(st, m.position + offset, false)


func _markers(group_name: String, points: Array) -> Array[Marker3D]:
	var group := Node3D.new()
	group.name = group_name
	_candidates_root.add_child(group)
	var out: Array[Marker3D] = []
	for p in points:
		var mk := Marker3D.new()
		mk.position = p
		group.add_child(mk)
		out.append(mk)
	return out


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _spawn_enemy(st: EnemyStats, pos: Vector3, start_active: bool) -> Enemy:
	var e := Enemy.new()
	e.stats = st
	e.start_active = start_active
	e.position = pos
	add_child(e)
	return e


func _label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.rotation_degrees = Vector3(-90, Game.rules.camera_yaw_degrees, 0)
	l.font_size = 64
	l.pixel_size = 0.01
	l.modulate = Color(1, 1, 1, 0.5)
	l.position = pos + Vector3(0, 0.03, 0)
	add_child(l)


func _hint(rect: Rect2, text: String) -> void:
	_hints.append({"rect": rect, "text": text, "shown": false})
