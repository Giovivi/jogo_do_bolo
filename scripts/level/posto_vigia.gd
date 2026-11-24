class_name PostoVigia
extends Node3D
## Fase-piloto "Posto Vigia-01" em greybox, montada por código.
## Grade de 2 m. Coordenadas: x = leste, z = sul (metros).
## Paredes do chão ao teto e tetos em tudo (regras de paredes do hub,
## docs/regras-paredes.md): feita para a câmera atrás do herói.
##
## Planta em anel:
## Ida (linha de baixo):  1. Entrada -> 2. Triagem -> 3. Celas -> 4. Hangar
## Volta (linha de cima): porta de serviço -> Depósito -> Cofre -> 5. Saída
## A volta fica ao norte da ida, nunca entre a câmera e o herói.

signal feixe_rescued
signal run_completed

const WALL_T := 0.5
## Pé-direito padrão das salas, dos corredores e altura das portas (m).
const ROOM_H := 7.5
const CORR_H := 3.5
const DOOR_H := 3.0
## Espessura das lajes do teto.
const LAJE_T := 0.3
const LUZ_FASE := Color(0.85, 0.92, 1.0)
## Segundos de aviso antes de cada inimigo da onda da cela entrar.
const WAVE_WARNING := 1.0

const SOLDIER: EnemyStats = preload("res://data/soldado.tres")
const SHIELD_SOLDIER: EnemyStats = preload("res://data/soldado_escudo.tres")
const DRONE: EnemyStats = preload("res://data/drone.tres")

## Semente da variação (0 = aleatória a cada entrada).
@export var seed_value: int = 0

var player_spawn := Vector3(-4, 0, 4)
var feixe_cell_position := Vector3(60, 0, -7)

var rng := RandomNumberGenerator.new()
## Áreas de chão andável (x0, z0, largura, profundidade).
var _floor_rects: Array[Rect2] = []
var _hints: Array[Dictionary] = []
var _cage_front: Node3D
var _service_door: Door
var _switch_on: bool = false
var _blast_open: bool = false
var _candidates_root: Node3D
var _exit_rect := Rect2(-5, -39, 4, 4)
var _cell_timer: float = -1.0
var _cell_events: Array[Dictionary] = []
var _cell_done: bool = false
## Paredes registradas (erguidas no fim), tetos, batentes e materiais.
var _muros: Array[Dictionary] = []
var _tetos: Array = []
var _batentes: Array = []
var _mats: Dictionary = {}
## Textura do chão da sala em construção: [id, metros por repetição, tinta].
## Fotos do ambientCG (CC0), ver assets/textures/CREDITS.md.
var _floor_tex: Array = ["Concrete044D", 2.5, Color(0.8, 0.8, 0.82)]
const WALL_TEX := ["Concrete031", 3.0, Color(0.9, 0.92, 0.95)]
## Visual das paredes (prancha fase1-base-secreta): "A" sala de controle,
## "B" paredes inclinadas no alto, "C" painéis de hexágonos.
static var estilo := "B"
## Salas e corredores registrados para o acabamento (_vestir, no fim).
var _salas: Array[Dictionary] = []
var _corredores: Array[Dictionary] = []
var _pisos: Array = []
var _consoles: Array = []
## Salas com cara de laboratório: armários altos nas paredes.
var _labs: Array[Rect2] = []
const CORRIDOR_TEX := ["Concrete044D", 2.5, Color(0.8, 0.8, 0.82)]


func _ready() -> void:
	# Depois do build() (também o da escola), cria as zonas de câmera.
	_build_camera_zones.call_deferred()


## Zonas de câmera por sala (tabela da seção 3.7).
func _build_camera_zones() -> void:
	var root := Node3D.new()
	root.name = "ZonasDeCamera"
	add_child(root)
	for z in _zone_table():
		CameraZone.make(root, z[0], z[1], z[2], z[3], z[4], z[5])


## Salas: [x0, z0, x1, z1, nível de zoom, nome]. Servem para a câmera e para
## o corte das paredes (só a sala atual tem a frente cortada).
func _zone_table() -> Array:
	if self is Escola:
		return [
			[-38, 22, 118, 46, CameraZone.Level.OPEN, "Frente"],
			[0, -5, 80, 22, CameraZone.Level.MEDIUM, "Escola"],
			[96, -3, 112, 9, CameraZone.Level.MEDIUM, "Garagem"],
		]
	return [
		[-8, -8, 8, 8, CameraZone.Level.MEDIUM, "Entrada"],
		[20, -10, 40, 10, CameraZone.Level.OPEN, "Triagem"],
		[13, -28, 25, -18, CameraZone.Level.CLOSED, "Sala secreta"],
		[50, -10, 70, 10, CameraZone.Level.OPEN, "Celas"],
		[78, -12, 102, 12, CameraZone.Level.OPEN, "Hangar"],
		[96, -30, 102, -12, CameraZone.Level.CLOSED, "Servico"],
		[52, -34, 70, -16, CameraZone.Level.MEDIUM, "Deposito"],
		[26, -24, 36, -14, CameraZone.Level.CLOSED, "Cofre"],
		[-6, -40, 6, -26, CameraZone.Level.CLOSED, "Saida"],
	]


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
	_vestir()
	_build_pisos()
	_erguer_muros()
	# Câmera de cima (opção antiga): a fase fica sem teto, como maquete.
	if Game.rules.camera_behind:
		_build_tetos()
	# Chão com buracos de verdade nos vãos.
	_build_floor_collision()
	Game.chests_total = get_tree().get_nodes_in_group("chests").size()




# ================================================================ áreas

func _build_entrada() -> void:
	var c := Color(0.42, 0.44, 0.47)
	_room(-8, -8, 8, 8, c, {"E": [[0.0, 4.0]]})
	# Saliência com baú atrás de um vão de 2 m (ensina o pulo). A mureta
	# que separa a saliência vai do chão ao teto.
	_pit(-8, -5, -1.25, -3)
	_muro(-1.25, -8, -0.75, -3, ROOM_H)
	_chest(Vector3(-4.5, 0, -6.5))
	_label("1. Entrada", Vector3(0, 0, 7))
	_console(-6.9, 4.5, Vector3.RIGHT)
	_armario(1.0, 7.3, Vector3.FORWARD)
	_armario(2.2, 7.3, Vector3.FORWARD)
	_bancada(-3.5, 7.25, Vector3.FORWARD)
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
	# Fundo: porta da secreta (x 23) no mezanino e vidro que mostra o cofre
	# (x 30). A porta da secreta é mais alta: ela nasce no mezanino de 1 m.
	_room(20, -10, 40, 10, c, {"W": [[0.0, 4.0]], "E": [[0.0, 4.0]], "N": [[23.0, 4.0, 4.0]]},
			{"N": [[30.0, 6.0, 1.6, 3.6]]})
	# Níveis: mezanino de 1 m no fundo e plataforma de 2 m no canto
	# nordeste (sobe pelo mezanino, degrau de 1 m), com baú no alto.
	_platform(20, -10, 34, -6, 1.0)
	_platform(34, -10, 40, -4, 2.0)
	_crate(25, -3, 2, 2)
	_crate(35, 4, 2, 2)
	_crate(26, 5, 1, 2)
	_arco_consoles(Vector3(30, 0, 11.5), 4.2, [-150.0, -120.0, -90.0, -60.0, -30.0])
	_label("2. Triagem", Vector3(30, 0, 8.5))
	# 3 baús escolhidos entre 5 pontos candidatos.
	_chest_candidates("Triagem baús", [Vector3(22, 1, -8), Vector3(38, 2, -8), Vector3(38, 0, 8), Vector3(22, 0, 8), Vector3(29, 0, -3)], 3)
	_enemy_group("Triagem A", SOLDIER, 2, [Vector3(24, 1, -8), Vector3(26, 0, 2)])
	_enemy_group("Triagem B", SOLDIER, 2, [Vector3(37, 2, -7), Vector3(34, 0, 7)])
	_enemy_group("Triagem C", SOLDIER, 2, [Vector3(31, 0, 6), Vector3(31, 1, -8)])
	_enemy_group("Triagem drones", DRONE, 2, [Vector3(36, 0, 0), Vector3(30, 0, 2)])
	_hint(Rect2(26, -10, 8, 6), "Atrás do vidro blindado, um cofre... A porta dele não abre por aqui.")
	_corridor_x(40, 50, 0.0, c)


func _build_secreta() -> void:
	var c := Color(0.35, 0.33, 0.42)
	_floor_tex = ["MetalPlates014", 1.6, Color(0.7, 0.72, 0.78)]
	# Corredor norte com vão de 4 m (pé-direito de 4 m, igual à porta).
	_floor(21, -18, 25, -10, c)
	_muro(21 - WALL_T, -17.5, 21, -10.5, 4.0 + LAJE_T)
	_muro(25, -17.5, 25 + WALL_T, -10.5, 4.0 + LAJE_T)
	_teto(Rect2(21, -17.5, 4, 7), 4.0)
	_luminaria(Vector3(23, 4.0, -14))
	_pit(21, -15, 25, -11)
	_room(13, -28, 25, -18, c, {"S": [[23.0, 4.0, 4.0]]})
	_chest(Vector3(17, 0, -24))
	_labs.append(Rect2(13, -28, 12, 10))
	_bancada(13.75, -26.0, Vector3.RIGHT)
	_bancada(13.75, -21.5, Vector3.RIGHT)
	_armario(24.3, -26.5, Vector3.LEFT)
	_label("sala secreta", Vector3(19, 0, -20))
	_hint(Rect2(21, -11, 4, 1.5), "Vão de 4 m: só o Fênix passa. Pule e segure Espaço para planar.")


func _build_celas() -> void:
	var c := Color(0.38, 0.4, 0.4)
	_floor_tex = ["Tiles140", 2.0, Color(1.05, 1.1, 1.1)]
	_room(50, -10, 70, 10, c, {"W": [[0.0, 4.0]], "E": [[0.0, 4.0]]})
	_label("3. Celas", Vector3(60, 0, 8.5))
	# Cela do Feixe: laterais de chapa até o teto e frente de campo de
	# força, também até o teto (some quando destrava).
	for cx in [57.5, 62.5]:
		_muro(cx - 0.25, -10, cx + 0.25, -4.25, ROOM_H, [], [], 0.0, "chapa")
	# Feixe já resgatado em outra ida: a cela fica aberta e vazia, sem
	# console nem defesa.
	var already_rescued: bool = Game.progress.get("feixe", false)
	if already_rescued:
		_cell_done = true
	else:
		_cage_front = Obra.bloco(self, Vector3(57.75, 0, -4.75), Vector3(62.25, ROOM_H, -4.25), _mat("campo"))
		_cage_front.name = "FrenteDaCela"
		var console := CellConsole.new()
		console.position = Vector3(60, 0, -2)
		add_child(console)
		console.activated.connect(_start_cell_unlock)
	# Plataformas de 1 m nos cantos do sul, boas para defender a cela.
	_platform(50, 5, 54, 10, 1.0)
	_platform(66, 5, 70, 10, 1.0)
	for ax in [52.0, 53.2, 66.8, 68.0]:
		_armario(ax, -9.3, Vector3.BACK)
	_bancada(60, 9.25, Vector3.FORWARD, 2.8)
	if not already_rescued:
		_hint(Rect2(50, -10, 20, 20), "A cela do Feixe! Use o console (F) para destravar e aguente 60 s.")
	_corridor_x(70, 78, 0.0, c)


func _build_hangar() -> void:
	var c := Color(0.36, 0.38, 0.44)
	_floor_tex = ["Concrete046", 3.0, Color(0.58, 0.58, 0.6)]
	# Pé-direito de 7 m: a passarela tem 3 m e o interruptor fica em cima.
	# A porta de serviço (norte) já tem modelo próprio: sem batente.
	_room(78, -12, 102, 12, c, {"W": [[0.0, 4.0]], "N": [[99.5, 4.0, DOOR_H, false]]})
	_label("4. Hangar", Vector3(90, 0, 10.5))
	# Passarela alta (inalcançável a pé) com o interruptor.
	var walkway := _box_body(Vector3(88, 1.5, -10.5), Vector3(16, 3, 3), Color(0.5, 0.52, 0.58), Game.LAYER_WALKWAY)
	walkway.name = "Passarela"
	walkway.get_child(1).material_override = BaseKit.mat("plataforma")
	var sw := BeamSwitch.new()
	sw.position = Vector3(88, 3.5, -10.5)
	add_child(sw)
	var service := Door.new()
	service.name = "PortaServico"
	service.position = Vector3(99.5, 0, -12.25)
	add_child(service)
	service.setup(Vector3(4, DOOR_H, 0.6), Color(0.75, 0.6, 0.2))
	_service_door = service
	sw.triggered.connect(_on_switch_triggered)
	# Torre de caixas no sudoeste (1 m e 2 m), longe da passarela de 3 m.
	_platform(80, 7, 84, 10, 1.0)
	_platform(80, 4, 84, 7, 2.0)
	_crate(87, 4, 2, 2)
	_crate(96, -2, 2, 2)
	_crate(91.5, 9.6, 2.2, 1.5)
	_crate(91.5, 9.6, 1.4, 1.1, 1.2, 1.0)
	_consoles.append(["heliponto", Vector3(90, 0, 0), Vector3.BACK, 4.0])
	_consoles.append(["ponte", Vector3(90, 0, 0), Vector3.BACK, 0.0])
	for tz in [-4.5, -3.0, 4.5, 6.0]:
		_consoles.append(["tanque", Vector3(101.1, 0, tz), Vector3.LEFT, 0.6])
	_chest_candidates("Hangar baú", [Vector3(99, 0, 9), Vector3(82, 2, 5.5)], 1)
	_enemy_group("Hangar drones 1", DRONE, 2, [Vector3(86, 0, -4), Vector3(84, 0, -6)])
	_enemy_group("Hangar drones 2", DRONE, 2, [Vector3(96, 0, -5), Vector3(98, 0, 2)])
	_enemy_group("Hangar escudo", SHIELD_SOLDIER, 1, [Vector3(90, 0, 4), Vector3(92, 0, 0)])
	_hint(Rect2(78, -6, 24, 18), "Interruptor na passarela alta: troque para o Feixe (2) e acerte com o tiro.")


func _on_switch_triggered() -> void:
	_switch_on = true
	if _service_door != null:
		_service_door.open()
	Game.message("A porta de serviço abriu (fundo do hangar).", 3.0)


func _on_blast_door_opened() -> void:
	_blast_open = true
	Game.message("Porta blindada cortada!", 2.5)


func _build_volta() -> void:
	var c := Color(0.34, 0.36, 0.38)
	_floor_tex = CORRIDOR_TEX
	# Serviço: sai do fundo do hangar e sobe (6 m de largura).
	_room(96, -30, 102, -12, c, {"W": [[-25.0, 4.0]]}, {}, ["S"], 4.0)
	_corridor_x(70, 96, -25.0, c)
	# Depósito: sala de luta da volta, com caixas de cobertura.
	_floor_tex = ["Concrete046", 3.0, Color(0.62, 0.6, 0.56)]
	_room(52, -34, 70, -16, Color(0.36, 0.35, 0.38), {"W": [[-19.0, 4.0]], "E": [[-25.0, 4.0]]})
	_label("Depósito", Vector3(61, 0, -17.5))
	_platform(64, -34, 70, -30, 1.0)
	_crate(57, -25, 2, 2)
	_crate(63, -22, 2, 1)
	_crate(56, -30, 1, 2)
	_estante(56, -33.2, Vector3.BACK)
	_estante(60.5, -33.2, Vector3.BACK, 3.0)
	_estante(52.8, -28, Vector3.RIGHT)
	_chest(Vector3(67, 1, -32))
	_enemy_group("Depósito A", SOLDIER, 2, [Vector3(58, 0, -29), Vector3(62, 0, -31)])
	_enemy_group("Depósito escudo", SHIELD_SOLDIER, 1, [Vector3(56, 0, -20), Vector3(60, 0, -27)])
	_corridor_x(36, 52, -19.0, c)
	# Cofre blindado no fundo da triagem, visto pelo vidro dela.
	var vc := Color(0.45, 0.42, 0.33)
	# Fosso entre o vidro da triagem e o do cofre: fechado dos lados e por
	# cima, com o fundo 60 cm abaixo do chão (não é chão andável).
	_box_visual(Vector3(30, -0.6, -12), Vector3(6, 0.2, 3), Color(0.12, 0.13, 0.15))
	_muro(26.5, -13.5, 27, -10.5, 4.0 + LAJE_T, [], [], -0.7)
	_muro(33, -13.5, 33.5, -10.5, 4.0 + LAJE_T, [], [], -0.7)
	_teto(Rect2(27, -13.5, 6, 3), 4.0)
	_floor_tex = ["DiamondPlate008A", 1.5, Color(0.85, 0.82, 0.72)]
	# A porta blindada (leste) já tem modelo próprio: sem batente.
	_room(26, -24, 36, -14, vc, {"E": [[-19.0, 4.0, DOOR_H, false]], "N": [[30.0, 4.0]]},
			{"S": [[30.0, 6.0, 0.9, 2.9]]})
	# As paredes do fosso descem até o fundo dele.
	_label("cofre", Vector3(31, 0, -15.5))
	var blast := Door.new()
	blast.name = "PortaBlindada"
	blast.blast_door = true
	blast.position = Vector3(36, 0, -19)
	add_child(blast)
	blast.setup(Vector3(0.8, DOOR_H, 4), Color(0.55, 0.6, 0.65))
	blast.opened_door.connect(_on_blast_door_opened)
	_chest(Vector3(32, 0, -22), true)
	_labs.append(Rect2(26, -24, 10, 10))
	_armario(26.7, -21.5, Vector3.RIGHT)
	_armario(26.7, -20.3, Vector3.RIGHT)
	_armario(26.7, -17.0, Vector3.RIGHT)
	_hint(Rect2(37, -21, 8, 4), "Porta blindada: com o Feixe, segure Q para cortar com o laser.")
	# Saída: sobe pelo norte do cofre e volta para cima da entrada.
	_floor_tex = CORRIDOR_TEX
	_floor(28, -32, 32, -24, c)
	_muro(28 - WALL_T, -31.5, 28, -24.5, CORR_H + LAJE_T)
	_muro(32, -31.5, 32 + WALL_T, -24.5, CORR_H + LAJE_T)
	_teto(Rect2(28, -31.5, 4, 7), CORR_H)
	_luminaria(Vector3(30, CORR_H, -28))
	_room(6, -36, 32, -32, c, {"S": [[30.0, 4.0]]}, {}, ["W"], CORR_H)
	_floor_tex = ["Concrete044D", 2.5, Color(0.72, 0.85, 0.78)]
	_room(-6, -40, 6, -26, Color(0.3, 0.42, 0.36), {"E": [[-34.0, 4.0]]})
	_label("5. Saída", Vector3(0, 0, -27.5))
	_chest(Vector3(3, 0, -38), false, true)
	_console(2.0, -26.75, Vector3.FORWARD)
	_bancada(-3.5, -26.75, Vector3.FORWARD, 2.0)
	var pad := _box_visual(Vector3(_exit_rect.get_center().x, 0.06, _exit_rect.get_center().y), Vector3(_exit_rect.size.x, 0.1, _exit_rect.size.y), Color(0.3, 0.95, 0.6))
	pad.name = "SaidaPad"
	_label("SAÍDA", Vector3(_exit_rect.get_center().x, 0, _exit_rect.get_center().y))
	_build_porta_saida()


## Elevador de saída: pórtico de metal na frente do piso verde, com a placa
## acesa (a saída tem modelo, não só o ponto no chão).
func _build_porta_saida() -> void:
	var r := _exit_rect
	var z0 := r.end.y
	var x0 := r.position.x - 0.2
	var x1 := r.end.x + 0.2
	var root := Node3D.new()
	root.name = "ElevadorSaida"
	add_child(root)
	Obra.bloco(root, Vector3(x0, 0, z0), Vector3(x0 + 0.25, DOOR_H, z0 + 0.25), _mat("batente"))
	Obra.bloco(root, Vector3(x1 - 0.25, 0, z0), Vector3(x1, DOOR_H, z0 + 0.25), _mat("batente"))
	Obra.bloco(root, Vector3(x0, DOOR_H, z0), Vector3(x1, DOOR_H + 0.35, z0 + 0.25), _mat("batente"))
	Obra.bloco(root, Vector3(r.get_center().x - 0.8, DOOR_H + 0.08, z0 + 0.25), Vector3(r.get_center().x + 0.8, DOOR_H + 0.27, z0 + 0.3), _mat("placa"), false)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.6)
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = Vector3(r.get_center().x, 2.2, r.get_center().y)
	root.add_child(light)


# ================================================================ paredes e tetos
## Regras de paredes (docs/regras-paredes.md), as mesmas do hub:
##   1. Uma parede = uma peça: desenho e colisão do mesmo tamanho (Obra).
##   2. Portas e janelas são vãos recortados na peça; nada empilhado.
##   3. Tudo o que é visível e alto colide (a câmera desvia).
##   4. Nada some nem aparece conforme a posição do herói; teto em tudo.
##   5. Toda porta e saída tem modelo (batente, porta ou o elevador).

## Material das peças, criado uma vez por fase.
func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"parede", "teto", "batente":
			var bk := {"parede": "parede", "teto": "teto", "batente": "peca"}
			_mats[key] = BaseKit.mat(bk[key])
			return _mats[key]
		"chapa":
			Look.texture_std(m, "MetalPlates014", 1.6, Color(0.75, 0.8, 0.9))
		"campo":
			m.albedo_color = Color(0.5, 0.75, 0.95, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color(0.3, 0.6, 1.0)
			m.emission_energy_multiplier = 0.4
		"vidro":
			m.albedo_color = Color(0.55, 0.8, 1.0, 0.28)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.3
		"luz":
			m.albedo_color = Color(0.9, 0.95, 1.0)
			m.emission_enabled = true
			m.emission = LUZ_FASE
			m.emission_energy_multiplier = 2.5
		"placa":
			m.albedo_color = Color(0.3, 0.95, 0.6)
			m.emission_enabled = true
			m.emission = Color(0.3, 0.95, 0.6)
			m.emission_energy_multiplier = 2.0
	_mats[key] = m
	return m


## Registra uma parede reta (caixa x0..x1, z0..z1, de y0 a y1). Ela só é
## construída no fim (_erguer_muros), depois de resolver os encontros.
## vaos e vidros: [[u0, u1, v0, v1], ...] com u ao longo da parede.
func _muro(x0: float, z0: float, x1: float, z1: float, y1: float, vaos: Array = [], vidros: Array = [], y0: float = 0.0, mat: String = "parede") -> void:
	var axis := "x" if x1 - x0 >= z1 - z0 else "z"
	_muros.append({
		"rect": Rect2(x0, z0, x1 - x0, z1 - z0),
		"axis": axis,
		"y0": y0,
		"y1": y1,
		"vaos": vaos,
		"vidros": vidros,
		"mat": mat,
	})


func _teto(r: Rect2, y: float) -> void:
	_tetos.append([r, y])


## Sala retangular com paredes do chão ao teto e teto.
## openings: {"N"|"S"|"W"|"E": [[centro, largura, altura = DOOR_H, batente = true], ...]}
## glass: {lado: [[centro, largura, de = 1.0, até = 2.6], ...]} (janela com vidro)
## skip: lados sem parede (a sala vizinha já fecha esse lado).
func _room(x0: float, z0: float, x1: float, z1: float, color: Color, openings: Dictionary = {}, glass: Dictionary = {}, skip: Array = [], h: float = ROOM_H) -> void:
	_floor(x0, z0, x1, z1, color)
	var t := WALL_T
	# Do lado sem parede, o teto para na parede da sala vizinha.
	var tx0 := x0 + (t if "W" in skip else 0.0)
	var tx1 := x1 - (t if "E" in skip else 0.0)
	var tz0 := z0 + (t if "N" in skip else 0.0)
	var tz1 := z1 - (t if "S" in skip else 0.0)
	_teto(Rect2(tx0, tz0, tx1 - tx0, tz1 - tz0), h)
	_salas.append({"r": Rect2(x0, z0, x1 - x0, z1 - z0), "h": h, "open": openings, "glass": glass, "skip": skip})
	var top := h + LAJE_T
	for side in ["N", "S", "W", "E"]:
		if side in skip:
			continue
		var vaos: Array = []
		for o in openings.get(side, []):
			var c: float = o[0]
			var w: float = o[1]
			var oh: float = o[2] if o.size() > 2 else DOOR_H
			vaos.append([c - w * 0.5, c + w * 0.5, 0.0, oh])
			if o.size() <= 3 or o[3]:
				_batentes.append({"side": side, "u0": c - w * 0.5, "u1": c + w * 0.5, "h": oh,
						"fixo": z0 - t if side == "N" else (z1 if side == "S" else (x0 - t if side == "W" else x1))})
		var vidros: Array = []
		for g in glass.get(side, []):
			var c: float = g[0]
			var w: float = g[1]
			var v0: float = g[2] if g.size() > 2 else 1.0
			var v1: float = g[3] if g.size() > 3 else 2.6
			vaos.append([c - w * 0.5, c + w * 0.5, v0, v1])
			vidros.append([c - w * 0.5, c + w * 0.5, v0, v1])
		# As paredes norte e sul fecham os cantos (menos onde a vizinha fecha).
		var a := x0 - (0.0 if "W" in skip else t)
		var b := x1 + (0.0 if "E" in skip else t)
		match side:
			"N":
				_muro(a, z0 - t, b, z0, top, vaos, vidros)
			"S":
				_muro(a, z1, b, z1 + t, top, vaos, vidros)
			"W":
				_muro(x0 - t, z0, x0, z1, top, vaos, vidros)
			_:
				_muro(x1, z0, x1 + t, z1, top, vaos, vidros)
	# Luminárias no teto, uma a cada ~7 m.
	var nx := maxi(1, int(round((x1 - x0) / 7.0)))
	var nz := maxi(1, int(round((z1 - z0) / 7.0)))
	for i in nx:
		for j in nz:
			_luminaria(Vector3(x0 + (x1 - x0) * (i + 0.5) / nx, h, z0 + (z1 - z0) * (j + 0.5) / nz))


## Corredor leste-oeste de 4 m de largura centrado em z, entre duas salas
## (as paredes e o teto param na face de fora das paredes delas).
func _corridor_x(x0: float, x1: float, z: float, color: Color) -> void:
	var room_tex := _floor_tex
	_floor_tex = CORRIDOR_TEX
	_floor(x0, z - 2, x1, z + 2, color)
	_floor_tex = room_tex
	var t := WALL_T
	_muro(x0 + t, z - 2 - t, x1 - t, z - 2, CORR_H + LAJE_T)
	_muro(x0 + t, z + 2, x1 - t, z + 2 + t, CORR_H + LAJE_T)
	_teto(Rect2(x0 + t, z - 2, x1 - x0 - 2.0 * t, 4.0), CORR_H)
	_corredores.append({"r": Rect2(x0 + t, z - 2, x1 - x0 - 2.0 * t, 4.0), "h": CORR_H})
	var n := maxi(1, int(round((x1 - x0) / 7.0)))
	for i in n:
		_luminaria(Vector3(x0 + (x1 - x0) * (i + 0.5) / n, CORR_H, z))


## Luminária presa no teto (y = altura do teto) com a luz dela. Sem teto
## (câmera de cima) fica só a luz.
func _luminaria(p: Vector3) -> void:
	# A barra acesa é desenhada pelo acabamento (_vestir); aqui só a luz,
	# baixada nas salas altas para alcançar o chão.
	var light := OmniLight3D.new()
	light.light_color = LUZ_FASE
	light.light_energy = 1.3
	light.omni_range = 10.0 if p.y > 5.0 else 8.0
	light.omni_attenuation = 1.1
	light.position = Vector3(p.x, minf(p.y - 0.4, 5.5), p.z)
	add_child(light)


## Constrói as paredes registradas. Onde duas se encontram, a mais baixa
## (ou a mais nova, se tiverem a mesma altura) perde o trecho do encontro:
## assim nenhuma peça fica dentro da outra (sem faces no mesmo plano).
func _erguer_muros() -> void:
	var root := Node3D.new()
	root.name = "Paredes"
	add_child(root)
	var cortes: Array = []
	for i in _muros.size():
		cortes.append([])
	for i in _muros.size():
		for j in range(i + 1, _muros.size()):
			var A: Dictionary = _muros[i]
			var B: Dictionary = _muros[j]
			var ov := (A["rect"] as Rect2).intersection(B["rect"])
			if ov.size.x <= 0.001 or ov.size.y <= 0.001:
				continue
			var perde := j if float(B["y1"]) <= float(A["y1"]) else i
			cortes[perde].append(ov)
	for i in _muros.size():
		var w: Dictionary = _muros[i]
		var r: Rect2 = w["rect"]
		var along_x: bool = w["axis"] == "x"
		var a0 := r.position.x if along_x else r.position.y
		var a1 := r.end.x if along_x else r.end.y
		var f0 := r.position.y if along_x else r.position.x
		var f1 := r.end.y if along_x else r.end.x
		# Trechos que sobram depois dos cortes (ao longo da parede).
		var trechos: Array = [[a0, a1]]
		for ov in cortes[i]:
			var o: Rect2 = ov
			var c0 := o.position.x if along_x else o.position.y
			var c1 := o.end.x if along_x else o.end.y
			var novos: Array = []
			for tr in trechos:
				if c1 <= tr[0] or c0 >= tr[1]:
					novos.append(tr)
					continue
				if c0 > tr[0]:
					novos.append([tr[0], c0])
				if c1 < tr[1]:
					novos.append([c1, tr[1]])
			trechos = novos
		for tr in trechos:
			if tr[1] - tr[0] < 0.01:
				continue
			Obra.parede(root, w["axis"], f0, tr[0], tr[1], w["y0"], w["y1"], [[0.0, f1 - f0, _mat(w["mat"])]], w["vaos"])
		# Vidro no meio da espessura, do tamanho exato da janela (colide).
		for g in w["vidros"]:
			var fm := (f0 + f1) * 0.5
			if along_x:
				Obra.bloco(root, Vector3(g[0], g[2], fm - 0.03), Vector3(g[1], g[3], fm + 0.03), _mat("vidro"))
			else:
				Obra.bloco(root, Vector3(fm - 0.03, g[2], g[0]), Vector3(fm + 0.03, g[3], g[1]), _mat("vidro"))
	# Batentes de metal forrando os vãos de porta (saltam 6 cm da parede).
	for bt in _batentes:
		var side: String = bt["side"]
		var f0: float = bt["fixo"]
		var f1 := f0 + WALL_T
		var u0: float = bt["u0"]
		var u1: float = bt["u1"]
		var hh: float = bt["h"]
		var k := 0.15
		var e := 0.06
		var pecas := [[u0, u0 + k, 0.0, hh - k], [u1 - k, u1, 0.0, hh - k], [u0, u1, hh - k, hh]]
		for p in pecas:
			if side == "N" or side == "S":
				Obra.bloco(root, Vector3(p[0], p[2], f0 - e), Vector3(p[1], p[3], f1 + e), _mat("batente"))
			else:
				Obra.bloco(root, Vector3(f0 - e, p[2], p[0]), Vector3(f1 + e, p[3], p[1]), _mat("batente"))


## Tetos de concreto com colisão: a câmera chega mais perto quando bate.
func _build_tetos() -> void:
	var root := Node3D.new()
	root.name = "Tetos"
	add_child(root)
	for tt in _tetos:
		var r: Rect2 = tt[0]
		var y: float = tt[1]
		Obra.bloco(root, Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y + LAJE_T, r.end.y), _mat("teto"))


# ================================================================ kit de peças

## Bunker fechado: sem sol, só a luz fria das luminárias e um ambiente baixo.
func _build_lighting() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.56, 0.68)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 0.9
	env.environment = e
	add_child(env)


func _floor(x0: float, z0: float, x1: float, z1: float, _color: Color) -> void:
	_floor_rects.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	_pisos.append(Rect2(x0, z0, x1 - x0, z1 - z0))


## Pisos de chapa de metal, com os vãos recortados de verdade.
func _build_pisos() -> void:
	var root := Node3D.new()
	root.name = "Pisos"
	add_child(root)
	Obra.laje(root, _pisos, Game.gaps, -0.2, 0.0, BaseKit.mat("piso"), false)


## Plataforma maciça de altura "h" (em que se sobe pulando), com borda
## clara no topo para ler a altura com a câmera baixa.
func _platform(x0: float, z0: float, x1: float, z1: float, h: float) -> StaticBody3D:
	var col := Color(0.5, 0.53, 0.58) if h <= 1.0 else Color(0.46, 0.49, 0.55)
	var body := _box_body(Vector3((x0 + x1) * 0.5, h * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, h, z1 - z0), col, Game.LAYER_WORLD)
	body.name = "Plataforma"
	body.get_child(1).material_override = BaseKit.mat("plataforma")
	var trim := Color(0.93, 0.8, 0.35)
	var t := 0.1
	var y := h + 0.01
	# Faixa de aviso amarela e preta nas bordas.
	for strip in [
		_box_visual(Vector3((x0 + x1) * 0.5, y, z1 - t * 0.5), Vector3(x1 - x0, 0.02, t), trim),
		_box_visual(Vector3((x0 + x1) * 0.5, y, z0 + t * 0.5), Vector3(x1 - x0, 0.02, t), trim),
		# As laterais param nas faixas da frente e do fundo (sem sobrepor).
		_box_visual(Vector3(x0 + t * 0.5, y, (z0 + z1) * 0.5), Vector3(t, 0.02, z1 - z0 - 2.0 * t), trim),
		_box_visual(Vector3(x1 - t * 0.5, y, (z0 + z1) * 0.5), Vector3(t, 0.02, z1 - z0 - 2.0 * t), trim),
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



# ================================================================ cela e ondas

func _start_cell_unlock() -> void:
	_cell_timer = 0.0
	Game.message("Destravando a cela... aguente 60 segundos!", 3.0)
	# Entradas das ondas: lados e cantos do fundo (nunca por baixo da tela).
	var west := Vector3(51.5, 0, 0)
	var east := Vector3(68.5, 0, 0)
	var back_w := Vector3(52, 0, -8)
	var back_e := Vector3(68, 0, -8)
	_cell_events = [
		{"t": 0.0, "stats": SOLDIER, "pos": west},
		{"t": 0.5, "stats": SOLDIER, "pos": east},
		{"t": 12.0, "stats": DRONE, "pos": back_w},
		{"t": 13.0, "stats": SOLDIER, "pos": west},
		{"t": 24.0, "stats": SOLDIER, "pos": east},
		{"t": 25.0, "stats": SOLDIER, "pos": west},
		{"t": 36.0, "stats": DRONE, "pos": back_e},
		{"t": 37.0, "stats": SOLDIER, "pos": east},
		{"t": 48.0, "stats": DRONE, "pos": back_w},
	]


func objective_text() -> String:
	if not _cell_done:
		if _cell_timer >= 0.0:
			return "Defenda a cela: %d s" % int(ceil(cell_time_left()))
		return "Encontre a cela e liberte o mutante preso"
	if not _switch_on:
		return "Hangar: acerte o interruptor da passarela com o Feixe"
	if not _blast_open:
		return "Volte pela porta de serviço (fundo do hangar) e corte a porta blindada do cofre"
	return "Vá para a saída"


func cell_time_left() -> float:
	if _cell_timer < 0.0 or _cell_done:
		return -1.0
	return maxf(0.0, Game.rules.cell_unlock_time - _cell_timer)


func _process_cell(delta: float) -> void:
	if _cell_timer < 0.0 or _cell_done:
		return
	_cell_timer += delta
	# Aviso: o ponto de entrada acende vermelho 1 s antes.
	for ev in _cell_events:
		if float(ev["t"]) - WAVE_WARNING > _cell_timer:
			break
		if not ev.has("marker"):
			ev["marker"] = _wave_marker(ev["pos"])
	while not _cell_events.is_empty() and float(_cell_events[0]["t"]) <= _cell_timer:
		var ev: Dictionary = _cell_events.pop_front()
		var st: EnemyStats = ev["stats"]
		var p: Vector3 = ev["pos"]
		if ev.has("marker") and is_instance_valid(ev["marker"]):
			(ev["marker"] as Node).queue_free()
		_spawn_enemy(st, p + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), true)
	if _cell_timer >= Game.rules.cell_unlock_time:
		open_cell()


## Disco vermelho que pulsa no chão onde um inimigo da onda vai entrar.
func _wave_marker(pos: Vector3) -> Node3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 1.2
	m.bottom_radius = 1.2
	m.height = 0.04
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.15, 0.1, 0.55)
	mi.material_override = mat
	mi.position = Vector3(pos.x, 0.04, pos.z)
	add_child(mi)
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mat, "albedo_color:a", 0.15, 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.6, 0.2)
	return mi


## Também usado pelo atalho de teste F3.
func open_cell() -> void:
	if _cell_done:
		return
	_cell_done = true
	_cell_timer = Game.rules.cell_unlock_time
	if _cage_front != null:
		_cage_front.queue_free()
		_cage_front = null
	feixe_rescued.emit()


# ================================================================ por quadro

func _physics_process(delta: float) -> void:
	_process_cell(delta)
	var party := Game.party
	if party == null or party.controlled_hero == null:
		return
	var hero: Hero = party.controlled_hero
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


## Caixa de carga militar de 1,2 m (cobertura e degrau).
func _crate(cx: float, cz: float, sx: float, sz: float, y: float = 0.0, h: float = 1.2) -> void:
	BaseKit.caixa_carga(self, Vector3(cx, y, cz), Vector3(sx, h, sz))


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


## Vão: buraco de verdade no piso (o piso é recortado em _build_pisos), com
## paredes descendo 5 m, fundo escuro com brilho vermelho, faixa de aviso na
## borda e LED logo abaixo dela. Bloqueio invisível: só quem plana atravessa.
func _pit(x0: float, z0: float, x1: float, z1: float) -> void:
	var root := Node3D.new()
	root.name = "Vao"
	add_child(root)
	var fundo := -5.0
	var t := 0.2
	var paredes := [
		[Vector3(x0 - t, fundo, z0 - t), Vector3(x1 + t, 0, z0)],
		[Vector3(x0 - t, fundo, z1), Vector3(x1 + t, 0, z1 + t)],
		[Vector3(x0 - t, fundo, z0), Vector3(x0, 0, z1)],
		[Vector3(x1, fundo, z0), Vector3(x1 + t, 0, z1)],
	]
	for pw in paredes:
		Obra.bloco(root, pw[0], pw[1] - Vector3(0, 0.001, 0), BaseKit.mat("vao"), false)
	Obra.bloco(root, Vector3(x0, fundo - 0.2, z0), Vector3(x1, fundo, z1), BaseKit.mat("fundo"), false)
	# LED logo abaixo da borda, nas quatro faces de dentro.
	var e := 0.02
	for yb in [-0.12, -1.4, -2.7, -4.0]:
		var mled := BaseKit.mat("laranja") if yb > -0.5 else BaseKit.mat("led_fraco")
		for led in [
			[Vector3(x0, yb - 0.03, z0), Vector3(x1, yb + 0.03, z0 + e)],
			[Vector3(x0, yb - 0.03, z1 - e), Vector3(x1, yb + 0.03, z1)],
			[Vector3(x0, yb - 0.03, z0 + e), Vector3(x0 + e, yb + 0.03, z1 - e)],
			[Vector3(x1 - e, yb - 0.03, z0 + e), Vector3(x1, yb + 0.03, z1 - e)],
		]:
			BaseKit.peca(root, led[0], led[1], mled)
	# Faixa de aviso amarela e preta em volta, no piso.
	var f := 0.3
	for fx in [
		[Vector3(x0 - f, 0, z0 - f), Vector3(x1 + f, 0.012, z0)],
		[Vector3(x0 - f, 0, z1), Vector3(x1 + f, 0.012, z1 + f)],
		[Vector3(x0 - f, 0, z0), Vector3(x0, 0.012, z1)],
		[Vector3(x1, 0, z0), Vector3(x1 + f, 0.012, z1)],
	]:
		BaseKit.peca(root, fx[0], fx[1], BaseKit.mat("aviso"))
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.25, 0.1)
	luz.light_energy = 2.5
	luz.omni_range = 6.0
	luz.position = Vector3((x0 + x1) * 0.5, fundo + 0.8, (z0 + z1) * 0.5)
	root.add_child(luz)
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


## Console (cobertura) ou armário de servidores, montados no acabamento.
func _console(x: float, z: float, frente: Vector3, largura: float = 2.2) -> void:
	_consoles.append(["console", Vector3(x, 0, z), frente, largura])


func _armario(x: float, z: float, frente: Vector3) -> void:
	_consoles.append(["armario", Vector3(x, 0, z), frente, 1.1])


func _bancada(x: float, z: float, frente: Vector3, largura: float = 2.4) -> void:
	_consoles.append(["bancada", Vector3(x, 0, z), frente, largura])


func _estante(x: float, z: float, frente: Vector3, largura: float = 4.0) -> void:
	_consoles.append(["estante", Vector3(x, 0, z), frente, largura])


## Fileira de consoles em arco (ref. sala de comando), virados para fora
## do centro: o operador fica do lado de fora olhando para o centro.
func _arco_consoles(centro: Vector3, raio: float, angulos: Array) -> void:
	for a in angulos:
		var d := Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
		_consoles.append(["console", centro + d * raio, d, 2.2])


# ================================================================ acabamento da base

## Veste salas e corredores: rodapé com LED, pilares chanfrados, telas,
## sanca (ou parede inclinada), vigas, dutos, luminárias lineares, pintura
## do piso, consoles e armários.
func _vestir() -> void:
	if OS.get_environment("ESTILO") != "":
		estilo = OS.get_environment("ESTILO")
	if not Game.rules.camera_behind:
		return
	var root := Node3D.new()
	root.name = "Acabamento"
	add_child(root)
	var i := 0
	for sala in _salas:
		var r: Rect2 = sala["r"]
		var h: float = sala["h"]
		for side in ["N", "S", "W", "E"]:
			if side in sala["skip"]:
				continue
			_vestir_parede(root, r, h, side, sala["open"].get(side, []), sala["glass"].get(side, []), i, r in _labs)
			i += 3
		_vestir_teto(root, r, h)
		_pintar_piso(root, r, h > 5.0)
	for c in _corredores:
		var r: Rect2 = c["r"]
		for side in ["N", "S"]:
			_vestir_parede(root, r, c["h"], side, [], [], i)
		_vestir_teto(root, r, c["h"])
		_pintar_piso(root, r, false)
	for k in _consoles.size():
		var c: Array = _consoles[k]
		match c[0]:
			"console":
				BaseKit.console(root, c[1], c[2], c[3], k)
			"bancada":
				BaseKit.bancada(root, c[1], c[2], c[3], k)
			"estante":
				BaseKit.estante(root, c[1], c[2], c[3], 3.6, k)
			"tanque":
				BaseKit.tanque(root, c[1], c[3], 2.6)
			"heliponto":
				BaseKit.heliponto(root, c[1], c[3])
			"ponte":
				BaseKit.ponte_rolante(root, Rect2(78, -12, 24, 24), ROOM_H)
			_:
				BaseKit.armario(root, c[1], c[2], k)


## Linha da face de dentro de um lado da sala: origem, direção, normal e
## comprimento.
func _lado(r: Rect2, side: String) -> Array:
	match side:
		"N":
			return [Vector3(r.position.x, 0, r.position.y), Vector3.RIGHT, Vector3.BACK, r.size.x, r.position.x]
		"S":
			return [Vector3(r.position.x, 0, r.end.y), Vector3.RIGHT, Vector3.FORWARD, r.size.x, r.position.x]
		"W":
			return [Vector3(r.position.x, 0, r.position.y), Vector3.BACK, Vector3.RIGHT, r.size.y, r.position.y]
		_:
			return [Vector3(r.end.x, 0, r.position.y), Vector3.BACK, Vector3.LEFT, r.size.y, r.position.y]


## Trechos livres [u0, u1] de 0..L tirando os bloqueios.
func _livres(L: float, bloqueios: Array) -> Array:
	var out: Array = [[0.0, L]]
	for bq in bloqueios:
		var novos: Array = []
		for tr in out:
			if bq[1] <= tr[0] or bq[0] >= tr[1]:
				novos.append(tr)
				continue
			if bq[0] > tr[0]:
				novos.append([tr[0], bq[0]])
			if bq[1] < tr[1]:
				novos.append([bq[1], tr[1]])
		out = novos
	return out


func _livre(u0: float, u1: float, bloqueios: Array) -> bool:
	for bq in bloqueios:
		if u1 > bq[0] and u0 < bq[1]:
			return false
	return true


func _vestir_parede(root: Node3D, r: Rect2, h: float, side: String, vaos: Array, vidros: Array, seed: int, lab: bool = false) -> void:
	var ld := _lado(r, side)
	var o: Vector3 = ld[0]
	var dir: Vector3 = ld[1]
	var nrm: Vector3 = ld[2]
	var L: float = ld[3]
	var base: float = ld[4]
	var portas: Array = []
	for v in vaos:
		portas.append([v[0] - base - v[1] * 0.5 - 0.2, v[0] - base + v[1] * 0.5 + 0.2])
	var janelas: Array = []
	for g in vidros:
		janelas.append([g[0] - base - g[1] * 0.5 - 0.3, g[0] - base + g[1] * 0.5 + 0.3])
	# Vãos no chão encostados na parede: o rodapé não passa por cima.
	var buracos: Array = []
	for gp in Game.gaps:
		var faixa := Rect2()
		match side:
			"N":
				faixa = Rect2(r.position.x, r.position.y, r.size.x, 0.6)
			"S":
				faixa = Rect2(r.position.x, r.end.y - 0.6, r.size.x, 0.6)
			"W":
				faixa = Rect2(r.position.x, r.position.y, 0.6, r.size.y)
			_:
				faixa = Rect2(r.end.x - 0.6, r.position.y, 0.6, r.size.y)
		var ov := (gp as Rect2).intersection(faixa)
		if ov.size.x > 0.0 and ov.size.y > 0.0:
			if side in ["N", "S"]:
				buracos.append([ov.position.x - base - 0.3, ov.end.x - base + 0.3])
			else:
				buracos.append([ov.position.y - base - 0.3, ov.end.y - base + 0.3])
	for tr in _livres(L, portas + buracos):
		if tr[1] - tr[0] > 0.2:
			BaseKit.rodape(root, o, dir, nrm, tr[0], tr[1])
	var alta := h > 5.0
	var topo := h
	if alta:
		if estilo == "B":
			topo = h - 2.6
			BaseKit.inclinada(root, o, dir, nrm, 0.0, L, topo, h, 1.0)
		else:
			topo = h - 0.9
			BaseKit.sanca(root, o, dir, nrm, 0.0, L, h, 0.9)
	else:
		BaseKit.sanca(root, o, dir, nrm, 0.0, L, h, 0.35)
		topo = h - 0.35
	if not alta:
		# Corredor: só pilares a cada ~3,5 m e uma calha de cabos.
		var nc := maxi(1, int(round(L / 3.5)))
		for k in range(1, nc):
			var u := L * k / nc
			if _livre(u - 0.4, u + 0.4, portas + janelas):
				BaseKit.pilar(root, o, dir, nrm, u, topo, 0.5, 0.22)
		return
	var n := maxi(2, int(round(L / 4.5)))
	var us: Array = [0.0]
	for k in range(1, n):
		var u := L * k / n
		if _livre(u - 0.5, u + 0.5, portas + janelas):
			BaseKit.pilar(root, o, dir, nrm, u, topo)
			us.append(u)
	us.append(L)
	for k in us.size() - 1:
		var a: float = us[k] + 0.6
		var b: float = us[k + 1] - 0.6
		if b - a < 1.2:
			continue
		var tem_porta := not _livre(a, b, portas + janelas)
		var m := (a + b) * 0.5
		var w := minf(b - a, 3.0)
		match estilo:
			"C":
				if not tem_porta:
					BaseKit.painel_hex(root, o, dir, nrm, m - w * 0.5, m + w * 0.5, 4.0, topo - 0.6)
					if (k + seed) % 3 == 0:
						BaseKit.tela(root, o, dir, nrm, m, 2.6, minf(w, 2.2), minf(w, 2.2) * 0.56, seed + k)
			_:
				if lab and not tem_porta and (k + seed) % 2 == 1:
					BaseKit.armario_parede(root, o, dir, nrm, m - w * 0.5, m + w * 0.5, 2.3)
				elif not tem_porta and (k + seed) % 2 == 0:
					BaseKit.tela(root, o, dir, nrm, m, 3.0, w * 0.9, w * 0.9 * 0.56, seed + k)
					if estilo == "A" and topo - 4.6 > 1.0:
						BaseKit.tela(root, o, dir, nrm, m, 4.7, w * 0.55, w * 0.55 * 0.56, seed + k + 1)
		# Friso de LED horizontal no alto de cada vão entre pilares.
		var fy := topo - 0.5
		BaseKit.peca(root, BaseKit._min3(BaseKit.ponto(o, dir, nrm, a - 0.4, 0, fy), BaseKit.ponto(o, dir, nrm, b + 0.4, 0.03, fy + 0.05)), BaseKit._max3(BaseKit.ponto(o, dir, nrm, a - 0.4, 0, fy), BaseKit.ponto(o, dir, nrm, b + 0.4, 0.03, fy + 0.05)), BaseKit.mat("led_fraco"))


func _vestir_teto(root: Node3D, r: Rect2, h: float) -> void:
	var ao_x := r.size.x >= r.size.y
	var comp := r.size.x if ao_x else r.size.y
	var larg := r.size.y if ao_x else r.size.x
	var alta := h > 5.0
	var margem := 1.0 if alta else 0.45
	# Vigas atravessadas a cada ~4 m (só nas salas altas).
	if alta and estilo == "B":
		var nv := maxi(1, int(round(comp / 4.0)))
		for k in range(1, nv):
			var c := (r.position.x if ao_x else r.position.y) + comp * k / nv
			if ao_x:
				BaseKit.trelica(root, Vector3(c, 0, r.position.y), Vector3(c, 0, r.end.y), h, 1.0)
			else:
				BaseKit.trelica(root, Vector3(r.position.x, 0, c), Vector3(r.end.x, 0, c), h, 1.0)
	elif alta:
		var nv := maxi(1, int(round(comp / 4.0)))
		for k in range(1, nv):
			var c := (r.position.x if ao_x else r.position.y) + comp * k / nv
			if ao_x:
				Obra.bloco(root, Vector3(c - 0.2, h - 0.45, r.position.y + margem - 0.1), Vector3(c + 0.2, h, r.end.y - margem + 0.1), BaseKit.mat("peca_escura"))
			else:
				Obra.bloco(root, Vector3(r.position.x + margem - 0.1, h - 0.45, c - 0.2), Vector3(r.end.x - margem + 0.1, h, c + 0.2), BaseKit.mat("peca_escura"))
	# Luminárias lineares ao longo do comprimento.
	var linhas := maxi(1, int(round(larg / 5.0)))
	var y := h - (0.46 if alta else 0.0)
	for j in linhas:
		var t := (r.position.y if ao_x else r.position.x) + larg * (j + 0.5) / linhas
		var nseg := maxi(1, int(floor((comp - 2.0 * margem) / 3.2)))
		var passo := (comp - 2.0 * margem) / nseg
		for k in nseg:
			var s0 := (r.position.x if ao_x else r.position.y) + margem + passo * k + 0.35
			var s1 := s0 + passo - 0.7
			if ao_x:
				BaseKit.linear(root, Vector3(s0, y, t), Vector3(s1, y, t), y)
			else:
				BaseKit.linear(root, Vector3(t, y, s0), Vector3(t, y, s1), y)
	# Duto ao longo de uma das paredes compridas.
	if alta:
		var off := 1.9
		var dy := 1.6 if estilo == "B" else 1.0
		if ao_x:
			BaseKit.duto(root, Vector3(r.position.x + 1.2, h - dy, r.position.y + off), Vector3(r.end.x - 1.2, h - dy, r.position.y + off), 0.35, h - 0.45)
		else:
			BaseKit.duto(root, Vector3(r.position.x + off, h - dy, r.position.y + 1.2), Vector3(r.position.x + off, h - dy, r.end.y - 1.2), 0.35, h - 0.45)


## Pintura do piso: faixa laranja a 1 m das paredes compridas e tracejado
## branco no meio (como a sala de controle da referência). Some nos vãos.
func _pintar_piso(root: Node3D, r: Rect2, laranja: bool) -> void:
	var ao_x := r.size.x >= r.size.y
	var faixas: Array[Rect2] = []
	var cor: Array = []
	var w := 0.1
	if ao_x:
		var zc := r.get_center().y
		var x := r.position.x + 0.6
		while x + 1.0 < r.end.x - 0.6:
			faixas.append(Rect2(x, zc - w * 0.5, 1.0, w))
			cor.append("tinta_branca")
			x += 1.8
		if laranja:
			for z in [r.position.y + 1.1, r.end.y - 1.1 - w]:
				faixas.append(Rect2(r.position.x + 1.1, z, r.size.x - 2.2, w))
				cor.append("tinta_laranja")
	else:
		var xc := r.get_center().x
		var z := r.position.y + 0.6
		while z + 1.0 < r.end.y - 0.6:
			faixas.append(Rect2(xc - w * 0.5, z, w, 1.0))
			cor.append("tinta_branca")
			z += 1.8
		if laranja:
			for x in [r.position.x + 1.1, r.end.x - 1.1 - w]:
				faixas.append(Rect2(x, r.position.y + 1.1, w, r.size.y - 2.2))
				cor.append("tinta_laranja")
	for k in faixas.size():
		for p in Obra.retangulos(faixas[k], Game.gaps):
			BaseKit.peca(root, Vector3(p.position.x, 0.0, p.position.y), Vector3(p.end.x, 0.006, p.end.y), BaseKit.mat(cor[k]))


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
