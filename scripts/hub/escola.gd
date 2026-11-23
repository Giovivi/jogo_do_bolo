class_name Escola
extends PostoVigia
## Hub "Escola": internato abandonado tomado pelo mato (planta aprovada no grill).
## Reaproveita o kit de peças do Posto Vigia (salas, paredes, corte da câmera),
## trocando os materiais por cel shading com texturas procedurais.
##
## Duas áreas no mesmo mundo, ligadas pela porta principal:
##   Frente (x -20..20, z 8..24): pátio de entrada com mato, fachada ao fundo.
##   Dentro (x 56..104): laboratório (oeste) | saguão com palco e mezanino | treino (leste).
## A câmera olha para o norte; o lado sul fica em corte.

signal mission_requested

const ROOM_COUNT := 8
const IN_X := 80.0  # centro do saguão
const MEZ_Y := 3.5
const LAMP := Color(1.0, 0.76, 0.42)

const CAMPO_X := 34.0     # o campo vai de -34 a 34 em x
const CAMPO_Z0 := -26.0   # e de -26 (atrás do prédio) até a frente do pátio
const PREDIO_Z0 := -8.0   # fundo do prédio

var inside_spawn := Vector3(IN_X, 0, 2)
var outside_door_spot := Vector3(0, 0, 10)

var _floor_mat: Material
var _lamp_scale := 1.0
var _lab_door: Door
## Parede da frente das salas laterais: {rect, mat} (some com o grupo dentro).
var _frentes: Array[Dictionary] = []
var _predio: Node3D
var _porta_oficiais: Array = []
var _mapa: MesaMapa


func build() -> void:
	rng.seed = 7
	player_spawn = Vector3(0, 0, 19)
	feixe_cell_position = Vector3(2, 0, 20)
	_candidates_root = Node3D.new()
	_candidates_root.name = "Candidatos"
	add_child(_candidates_root)
	_build_lighting()
	_build_ground()
	_build_frente()
	_build_saguao()
	_build_laboratorio()
	_build_treino()
	# Estrutura mais alta: o prédio tem dois andares.
	var old_h := Game.rules.backdrop_height
	Game.rules.backdrop_height = 8.0
	_build_structure()
	Game.rules.backdrop_height = old_h
	# Paredes que continuam à vista ganham cor de tijolo.
	for w in _walls:
		var c := Color(0.95, 0.92, 0.9)
		w["color"] = c
		Look.texture_std(w["mat"] as StandardMaterial3D, "Bricks097", 2.4, c, 1.2)
	Game.chests_total = 0
	_build_paredes_laterais()


func rescued_count() -> int:
	return 1 + (1 if Game.progress.get("feixe", false) else 0)


# ================================================================ frente

func _build_frente() -> void:
	# Pátio de terra batida arenosa com mato ralo e seco.
	_floor_mat = Look.tiles(Look.tex("Ground088", Vector2(4.0, 4.0), Color(0.95, 0.92, 0.88), {"tile_size": 1.0, "grass_amount": 0.35, "grass_color": Color(0.45, 0.42, 0.26), "dirt_color": Color(0.58, 0.5, 0.38)}))
	_floor(-20, 8, 20, 24, Color.WHITE)
	# Caminho de cimento rachado até a porta.
	_box_visual_mat(Vector3(0, 0.01, 16), Vector3(4, 0.02, 16), Look.tiles(Look.tex("Concrete044D", Vector2(2.5, 2.5), Color(1.0, 0.97, 0.92), {"tile_size": 1.0, "grass_amount": 0.2, "grass_color": Color(0.58, 0.5, 0.38)})))
	_build_limites_frente()
	_build_predio()
	var n0 := get_child_count()
	_build_fachada()
	for c in get_children().slice(n0):
		(c as Node).reparent(_predio)
	# Atrás do prédio, ele sai da frente da câmera.
	_frentes.append({"rect": Rect2(-CAMPO_X, CAMPO_Z0, CAMPO_X * 2.0, PREDIO_Z0 - CAMPO_Z0 + 0.5), "nodes": [_predio], "faded": false})
	Look.tree(self, Vector3(-15, 0, 12), 1.3, 1)
	Look.tree(self, Vector3(16, 0, 11), 1.1, 2)
	Look.tree(self, Vector3(-11, 0, 21), 0.9, 3)
	var bushes := [Vector3(-7, 0, 10), Vector3(6, 0, 9.5), Vector3(12, 0, 18), Vector3(-17, 0, 18), Vector3(9, 0, 14), Vector3(-5, 0, 15), Vector3(17, 0, 21), Vector3(-3, 0, 22)]
	var keep := clampi(bushes.size() - (rescued_count() - 1) * 2, 3, bushes.size())
	for i in keep:
		Look.bush(self, bushes[i], rng.randf_range(1.0, 1.8), i)
	# Banco quebrado e um poste apagado.
	_solid_piece(Vector3(-8, 0.45, 17), Vector3(2.4, 0.12, 0.6), Look.wood(), Vector3(0, 0, 6))
	_solid_piece(Vector3(8.5, 1.8, 11), Vector3(0.15, 3.6, 0.15), Look.surface(Color(0.25, 0.26, 0.28), {"outline": 0.03}))
	var porta := HubDoor.new()
	porta.position = outside_door_spot
	porta.prompt = "Entrar na escola"
	porta.target = inside_spawn
	add_child(porta)
	porta.used_door.connect(_move_party)
	_label("Frente da escola", Vector3(-5, 0, 22.5))
	_hint(Rect2(-20, 8, 40, 16), "A escola. A sala de planos fica lá dentro, no fundo do saguão. Use F na porta.")


## Limites do pátio: a fachada e a estrutura em volta só eram desenho, sem colisão,
## e o grupo atravessava a escola. Agora seguram o grupo dentro do pátio.
func _build_limites_frente() -> void:
	# O campo em volta da escola: pátio na frente, gramado dos lados e atrás.
	# Terra seca com capim ralo (Ground109), sem musgo.
	var grass := Look.surface(Color(0.22, 0.3, 0.16), Look.tex("Ground109", Vector2(5.0, 5.0)))
	var keep := _floor_mat
	_floor_mat = grass
	_floor(-CAMPO_X, CAMPO_Z0, -20, 24, Color.WHITE)
	_floor(20, CAMPO_Z0, CAMPO_X, 24, Color.WHITE)
	_floor(-20, CAMPO_Z0, 20, 8, Color.WHITE)
	_floor_mat = keep
	# Bordas do campo (a mureta em corte na frente; mato fechado no resto).
	_invisible_wall(Vector3(-CAMPO_X - 0.2, 1.5, (CAMPO_Z0 + 24.0) * 0.5), Vector3(0.4, 3.0, 24.0 - CAMPO_Z0))
	_invisible_wall(Vector3(CAMPO_X + 0.2, 1.5, (CAMPO_Z0 + 24.0) * 0.5), Vector3(0.4, 3.0, 24.0 - CAMPO_Z0))
	_invisible_wall(Vector3(0, 1.5, CAMPO_Z0 - 0.2), Vector3(CAMPO_X * 2.0, 3.0, 0.4))
	_invisible_wall(Vector3(0, 1.5, 24.2), Vector3(CAMPO_X * 2.0, 3.0, 0.4))
	# Fora do campo: mata fechada em vez de paredão de tijolo (atrás e dos lados).
	_floor_mat = grass
	_floor(-56, -46, 54, CAMPO_Z0, Color.WHITE)
	_floor(-56, CAMPO_Z0, -CAMPO_X, 30, Color.WHITE)
	_floor(CAMPO_X, CAMPO_Z0, 54, 30, Color.WHITE)
	_floor_mat = keep
	var k := 0
	var zf := -45.0
	while zf < 28.0:
		var xf := -54.0
		while xf < 52.0:
			var q := Vector3(xf + rng.randf_range(-1.2, 1.2), 0, zf + rng.randf_range(-1.2, 1.2))
			var fora := q.z < CAMPO_Z0 - 1.0 or absf(q.x) > CAMPO_X + 1.0
			var perto := q.z > CAMPO_Z0 - 16.0 and absf(q.x) < CAMPO_X + 16.0
			if fora and perto:
				k += 1
				if k % 4 == 0:
					Look.bush(self, q, rng.randf_range(1.4, 2.2), 400 + k)
				else:
					Look.tree(self, q, rng.randf_range(1.1, 1.7), 400 + k)
			xf += 4.0
		zf += 4.0
	# Mato e árvores pelo campo, mais fechado perto das bordas.
	for i in 26:
		var p := Vector3(rng.randf_range(-CAMPO_X + 1.0, CAMPO_X - 1.0), 0, rng.randf_range(CAMPO_Z0 + 1.0, 23.0))
		if absf(p.x) < 23.0 and p.z > -18.0:
			continue  # longe do prédio e do pátio
		if i % 3 == 0:
			Look.tree(self, p, rng.randf_range(1.0, 1.5), 200 + i)
		else:
			Look.bush(self, p, rng.randf_range(1.0, 1.8), 200 + i)


## O prédio da escola visto de fora: dois andares de tijolo e telhado de
## duas águas. Atrás dele, o prédio sai da frente da câmera.
func _build_predio() -> void:
	var predio := Node3D.new()
	predio.name = "Predio"
	add_child(predio)
	var h := 8.0
	var tijolo := Look.brick()
	# Volume do prédio (com colisão).
	var body := _solid_piece(Vector3(0, h * 0.5, (PREDIO_Z0 + 7.9) * 0.5), Vector3(40.0, h, 7.9 - PREDIO_Z0), tijolo)
	body.reparent(predio)
	# Telhado de duas águas com beiral.
	var telha := Look.surface(Color(0.45, 0.22, 0.16), Look.tex("RoofingTiles014B", Vector2(2.9, 2.9), Color.WHITE, {"outline": 0.04}))
	var prism := PrismMesh.new()
	prism.size = Vector3(7.9 - PREDIO_Z0 + 1.6, 4.0, 41.6)
	var roof := MeshInstance3D.new()
	roof.mesh = prism
	roof.material_override = telha
	roof.rotation_degrees = Vector3(0, 90, 0)
	roof.position = Vector3(0, h + 2.0, (PREDIO_Z0 + 7.9) * 0.5)
	predio.add_child(roof)
	# Janelas nas laterais e nos fundos.
	var frame := Look.surface(Color(0.36, 0.22, 0.15), {"outline": 0.03})
	var glass := Look.surface(Color(0.1, 0.14, 0.17), {"variation": 0.3, "noise_scale": 4.0})
	for y in [1.9, 5.4]:
		for z in [PREDIO_Z0 + 3.0, PREDIO_Z0 + 8.0, PREDIO_Z0 + 13.0]:
			for sx in [-1.0, 1.0]:
				Look.piece(predio, Look.box(Vector3(0.12, 1.8, 2.6)), frame, Vector3(sx * 20.02, y, z))
				Look.piece(predio, Look.box(Vector3(0.14, 1.6, 2.3)), glass, Vector3(sx * 20.03, y, z))
		for x in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
			Look.piece(predio, Look.box(Vector3(2.6, 1.8, 0.12)), frame, Vector3(x, y, PREDIO_Z0 - 0.02))
			Look.piece(predio, Look.box(Vector3(2.3, 1.6, 0.14)), glass, Vector3(x, y, PREDIO_Z0 - 0.03))
	_predio = predio


func _invisible_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child(body)


## Fachada de dois andares (só visual, na frente da estrutura do fundo).
func _build_fachada() -> void:
	var z := 7.95
	var frame := Look.surface(Color(0.36, 0.22, 0.15), {"outline": 0.03})
	var glass := Look.surface(Color(0.1, 0.14, 0.17), {"variation": 0.3, "noise_scale": 4.0})
	var concrete := Look.surface(Color(0.6, 0.58, 0.53), Look.tex("Concrete044D", Vector2(2.5, 2.5), Color(1.1, 1.07, 1.0), {"outline": 0.04}))
	for row in [[1.9, 1.6], [5.4, 1.6]]:
		var y: float = row[0]
		var h: float = row[1]
		for x in [-16.0, -11.5, -7.0, 7.0, 11.5, 16.0]:
			Look.piece(self, Look.box(Vector3(2.6, h + 0.2, 0.12)), frame, Vector3(x, y, z))
			Look.piece(self, Look.box(Vector3(2.3, h, 0.14)), glass, Vector3(x, y, z + 0.01))
			Look.piece(self, Look.box(Vector3(0.1, h, 0.16)), frame, Vector3(x, y, z + 0.02))
	# Janelão do saguão no segundo andar.
	Look.piece(self, Look.box(Vector3(6.2, 1.8, 0.12)), frame, Vector3(0, 5.4, z))
	Look.piece(self, Look.box(Vector3(5.9, 1.6, 0.14)), glass, Vector3(0, 5.4, z + 0.01))
	# Marquise com pilares e porta azul descascada.
	_solid_piece(Vector3(0, 3.2, 9.2), Vector3(5.6, 0.3, 2.6), concrete)
	_solid_piece(Vector3(-2.5, 1.55, 10.2), Vector3(0.35, 3.1, 0.35), concrete)
	_solid_piece(Vector3(2.5, 1.55, 10.2), Vector3(0.35, 3.1, 0.35), concrete)
	Look.piece(self, Look.box(Vector3(2.6, 2.6, 0.16)), Look.surface(Color(0.17, 0.36, 0.55), {"variation": 0.35, "noise_scale": 3.0, "outline": 0.03}), Vector3(0, 1.3, z + 0.02))
	Look.piece(self, Look.box(Vector3(0.06, 2.6, 0.2)), frame, Vector3(0, 1.3, z + 0.04))
	Look.piece(self, Look.box(Vector3(4.0, 0.24, 2.0)), concrete, Vector3(0, 0.12, 9.0))
	# Hera subindo pela fachada.
	var ivy := Look.foliage(Color(0.3, 0.44, 0.2))
	for p in [Vector3(-18.5, 2.5, 8.1), Vector3(-13.6, 4.5, 8.1), Vector3(13.5, 1.5, 8.1), Vector3(18.3, 4.0, 8.1)]:
		Look.piece(self, Look.box(Vector3(1.2, 3.5, 0.25)), ivy, p)


# ================================================================ saguão

func _build_saguao() -> void:
	var x0 := IN_X - 8.0
	var x1 := IN_X + 8.0
	_floor_mat = _saguao_floor()
	_room(x0, -14, x1, 4, Color.WHITE, {"W": [[-2.0, 3.0]], "E": [[-2.0, 3.0]], "N": [[IN_X, 2.0]]})
	_link(x0 - 1, -3.5, x0, -0.5)
	_link(x1, -3.5, x1 + 1, -0.5)
	_label("Saguão", Vector3(IN_X, 0, 3))
	# Pé-direito duplo: as paredes do saguão sobem inteiras até o 2º andar,
	# para não se ver as salas vizinhas por cima delas.
	var tall := Look.brick(_reboco_interno())
	var top_h := 7.5
	var up := top_h - WALL_H
	_solid_piece(Vector3(x0 - WALL_T * 0.5, WALL_H + up * 0.5, -5.0), Vector3(WALL_T, up, 18.0 + 2.0 * WALL_T), tall)
	_solid_piece(Vector3(x1 + WALL_T * 0.5, WALL_H + up * 0.5, -5.0), Vector3(WALL_T, up, 18.0 + 2.0 * WALL_T), tall)
	var n_wall: Array = []
	n_wall.append(Look.piece(self, Look.box(Vector3(16.0 + 2.0 * WALL_T, up, WALL_T)), tall, Vector3(IN_X, WALL_H + up * 0.5, -14.0 - WALL_T * 0.5)))
	# Paredes laterais (saguão | laboratório e saguão | treino): o trecho da
	# frente, que o corte deixava baixo, sobe inteiro, e as portas ganham
	# parede por cima, para não se ver as salas vizinhas pelos vãos.
	for wx in [x0 - WALL_T * 0.5 - 0.25, x1 + WALL_T * 0.5 + 0.25]:
		Look.piece(self, Look.box(Vector3(1.0, top_h, 5.0)), tall, Vector3(wx, top_h * 0.5, 2.0))
		Look.piece(self, Look.box(Vector3(1.0, top_h - WALL_H, 3.0)), tall, Vector3(wx, WALL_H + (top_h - WALL_H) * 0.5, -2.0))
	# A parede de baixo entre o saguão e a sala dos oficiais (com a porta).
	var seg := (16.0 + 2.0 * WALL_T - 2.0) * 0.5
	for sx in [-1.0, 1.0]:
		n_wall.append(Look.piece(self, Look.box(Vector3(seg, WALL_H, WALL_T)), tall, Vector3(IN_X + sx * (1.0 + seg * 0.5), WALL_H * 0.5, -14.0 - WALL_T * 0.5)))
	# Rodapé de madeira na altura do mezanino.
	for wx in [x0 + 0.02, x1 - 0.02]:
		Look.piece(self, Look.box(Vector3(0.06, 0.2, 18.0)), Look.wood(Color(0.3, 0.2, 0.14)), Vector3(wx, MEZ_Y + 0.1, -5.0))
	var wood := Look.wood()
	var dark_wood := Look.wood(Color(0.3, 0.2, 0.14))
	# Sala de planos fechada, atrás da porta dos oficiais no fundo do saguão.
	_build_sala_planos()
	# Dentro da sala dos oficiais, essa parede e a porta somem (ficam entre a
	# câmera e o herói).
	_frentes.append({"rect": Rect2(74, -24, 12, 9.5), "nodes": n_wall + _porta_oficiais, "faded": false})
	# Mezanino a 3,5 m: fundo e laterais, com guarda-corpo.
	var slab := Look.surface(Color(0.45, 0.44, 0.41), Look.tex("Concrete044D", Vector2(2.5, 2.5), Color(0.85, 0.83, 0.78), {"outline": 0.04}))
	_solid_piece(Vector3(x0 + 1.25, MEZ_Y - 0.15, -5.0), Vector3(2.5, 0.3, 18.0), slab)
	_solid_piece(Vector3(x1 - 1.25, MEZ_Y - 0.15, -5.0), Vector3(2.5, 0.3, 18.0), slab)
	var rail := Look.surface(Color(0.5, 0.3, 0.18), {"outline": 0.025})
	Look.piece(self, Look.box(Vector3(0.1, 0.1, 17.5)), rail, Vector3(x0 + 2.5, MEZ_Y + 1.0, -5.25))
	Look.piece(self, Look.box(Vector3(0.1, 0.1, 17.5)), rail, Vector3(x1 - 2.5, MEZ_Y + 1.0, -5.25))
	for i in 9:
		for rx in [x0 + 2.5, x1 - 2.5]:
			Look.piece(self, Look.box(Vector3(0.06, 1.0, 0.06)), rail, Vector3(rx, MEZ_Y + 0.5, -13.5 + i * 2.0))
	# Escada até o mezanino (rampa de colisão com degraus visuais).
	_stairs(Vector3(x0 + 3.5, 0, 3.0), Vector3(x0 + 3.5, MEZ_Y, -5.0), 2.0, dark_wood)
	# Portas dos quartos no fundo do mezanino.
	_build_quartos(x0)
	# Passarela quebrada sobre o saguão: vão de 4 m, só planando.
	_solid_piece(Vector3(x0 + 4.25, MEZ_Y - 0.1, -2.0), Vector3(3.5, 0.2, 1.6), dark_wood)
	_solid_piece(Vector3(x1 - 4.25, MEZ_Y - 0.1, -2.0), Vector3(3.5, 0.2, 1.6), dark_wood)
	# Apoios: viga presa ao mezanino, escora diagonal e pontas lascadas no vão.
	for side in [-1.0, 1.0]:
		var edge: float = IN_X + side * 5.5  # borda interna do mezanino
		var tip: float = IN_X + side * 2.0   # ponta da tábua, no vão
		Look.piece(self, Look.box(Vector3(3.6, 0.18, 0.2)), wood, Vector3((edge + tip) * 0.5, MEZ_Y - 0.29, -2.55))
		Look.piece(self, Look.box(Vector3(3.6, 0.18, 0.2)), wood, Vector3((edge + tip) * 0.5, MEZ_Y - 0.29, -1.45))
		# Dois pontaletes até o chão e uma travessa em X entre eles.
		var post_x: float = tip - side * 0.5
		for pz in [-2.6, -1.4]:
			_solid_piece(Vector3(post_x, (MEZ_Y - 0.38) * 0.5, pz), Vector3(0.2, MEZ_Y - 0.38, 0.2), wood)
		Look.piece(self, Look.box(Vector3(0.08, 3.4, 0.1)), wood, Vector3(post_x, MEZ_Y * 0.5 - 0.2, -2.0), Vector3(20.0, 0, 0))
		Look.piece(self, Look.box(Vector3(0.08, 3.4, 0.1)), wood, Vector3(post_x, MEZ_Y * 0.5 - 0.2, -2.0), Vector3(-20.0, 0, 0))
		Look.piece(self, Look.box(Vector3(0.7, 0.06, 0.3)), dark_wood, Vector3(tip - side * 0.1, MEZ_Y - 0.25, -2.4), Vector3(0, side * 12.0, side * -24.0))
		Look.piece(self, Look.box(Vector3(0.5, 0.06, 0.26)), dark_wood, Vector3(tip - side * 0.05, MEZ_Y - 0.2, -1.6), Vector3(0, side * -8.0, side * -32.0))
	# Caixas para treinar o pulo (1 m e 2 m).
	var crate := Look.wood(Color(0.45, 0.34, 0.22))
	_solid_piece(Vector3(x1 - 3.5, 0.5, 1.0), Vector3(1.6, 1.0, 1.6), crate)
	_solid_piece(Vector3(x1 - 3.5, 1.0, -1.2), Vector3(1.6, 2.0, 1.6), crate)
	# Mato entrando pelo saguão e lâmpadas.
	for p in [Vector3(x0 + 0.8, 0, 3), Vector3(x1 - 0.8, 0, -8), Vector3(x0 + 3, 0, -9)]:
		Look.bush(self, p, 1.0, int(p.x))
	_lamp(Vector3(IN_X, 4.2, -11.3), 2.4)
	_lamp(Vector3(x0 + 1.2, MEZ_Y + 2.0, -11.0), 1.0)
	var saida := HubDoor.new()
	saida.position = Vector3(IN_X, 0, 3.4)
	saida.prompt = "Sair para a frente"
	saida.target = outside_door_spot + Vector3(0, 0, 1.5)
	add_child(saida)
	saida.used_door.connect(_move_party)
	_hint(Rect2(x0, -6, 16, 10), "O saguão. A sala de planos fica atrás da porta dos oficiais, no fundo.")


## Sala dos oficiais: a antiga diretoria, fechada, com a mesa do mapa.
func _build_sala_planos() -> void:
	var z0 := -24.0
	var z1 := -14.5
	var sx0 := IN_X - 6.0
	var sx1 := IN_X + 6.0
	_floor_mat = Look.surface(Color(0.3, 0.2, 0.14), Look.tex("WoodFloor043", Vector2(1.3, 0.65), Color(0.85, 0.8, 0.76)))
	_room(sx0, z0, sx1, z1, Color.WHITE, {}, {}, ["S"])
	_link(IN_X - 1.0, z1, IN_X + 1.0, -14.0)
	# Porta reforçada com placa.
	var metal := Look.surface(Color(0.24, 0.27, 0.3), Look.tex("PaintedMetal006", Vector2(2.0, 2.0), Color(0.6, 0.68, 0.72), {"outline": 0.03}))
	_porta_oficiais.append(Look.piece(self, Look.box(Vector3(0.25, 2.6, 0.7)), metal, Vector3(IN_X - 1.15, 1.3, -14.25)))
	_porta_oficiais.append(Look.piece(self, Look.box(Vector3(0.25, 2.6, 0.7)), metal, Vector3(IN_X + 1.15, 1.3, -14.25)))
	_porta_oficiais.append(Look.piece(self, Look.box(Vector3(2.55, 0.3, 0.7)), metal, Vector3(IN_X, 2.65, -14.25)))
	_porta_oficiais.append(Look.piece(self, Look.box(Vector3(1.0, 2.3, 0.08)), metal, Vector3(IN_X - 1.45, 1.15, -13.7), Vector3(0, -70, 0)))
	_porta_oficiais.append(Look.piece(self, Look.box(Vector3(1.9, 0.45, 0.06)), Look.surface(Color(0.6, 0.12, 0.1), {"outline": 0.015}), Vector3(IN_X, 3.15, -13.9)))
	var sign := Label3D.new()
	sign.text = "SALA DOS OFICIAIS"
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.outline_size = 8
	sign.modulate = Color(1.0, 0.92, 0.8)
	sign.position = Vector3(IN_X, 3.15, -13.86)
	add_child(sign)
	_porta_oficiais.append(sign)
	_porta_oficiais.append(Look.piece(self, Look.box(Vector3(0.18, 0.28, 0.05)), Look.glow(Color(0.3, 1.0, 0.45), 1.6), Vector3(IN_X + 1.5, 1.3, -13.88)))
	# Paredes internas lisas, de uma peça só. A estrutura em volta é montada
	# em faixas de 1 m e, aqui de perto, o tijolo aparecia em degraus virados.
	var inner := Look.brick(_reboco_interno())
	var hh := 8.0
	for wx in [sx0 - 0.26, sx1 + 0.26]:
		Look.piece(self, Look.box(Vector3(0.5, hh, z1 - z0 + 0.5)), inner, Vector3(wx, hh * 0.5, (z0 + z1) * 0.5 - 0.25))
	Look.piece(self, Look.box(Vector3(sx1 - sx0 + 1.0, hh, 0.5)), inner, Vector3(IN_X, hh * 0.5, z0 - 0.26))
	# Mesa do mapa no centro.
	_build_mesa(Vector3(IN_X, 0.0, -19.5))
	# Quadro de cortiça com fotos e fios, armários e arquivos.
	var cork := Look.surface(Color(0.55, 0.38, 0.22), {"variation": 0.35, "noise_scale": 6.0, "outline": 0.02})
	Look.piece(self, Look.box(Vector3(4.6, 1.8, 0.1)), cork, Vector3(IN_X, 1.9, z0 + 0.05))
	for i in 7:
		var px := IN_X - 2.0 + i * 0.66
		var py := 1.4 + fmod(i * 0.37, 0.8)
		Look.piece(self, Look.box(Vector3(0.36, 0.26, 0.02)), Look.surface(Color(0.92, 0.88, 0.78)), Vector3(px, py, z0 + 0.12), Vector3(0, 0, (i % 3 - 1) * 6.0))
	for i in 3:
		Look.piece(self, Look.box(Vector3(0.8, 1.9, 0.6)), metal, Vector3(sx0 + 0.6, 0.95, z0 + 1.2 + i * 0.85))
	for i in 2:
		Look.piece(self, Look.box(Vector3(0.7, 1.2, 0.7)), Look.surface(Color(0.33, 0.36, 0.3), Look.tex("PaintedMetal006", Vector2(1.5, 1.5), Color(0.5, 0.56, 0.5), {"outline": 0.03})), Vector3(sx1 - 0.6, 0.6, z0 + 1.0 + i * 0.8))
	_solid_piece(Vector3(sx1 - 1.0, 0.4, -16.0), Vector3(1.2, 0.8, 1.2), Look.wood(Color(0.45, 0.34, 0.22)))
	# Bandeira improvisada dos mutantes e luz baixa sobre a mesa.
	Look.piece(self, Look.box(Vector3(1.6, 1.0, 0.04)), Look.surface(Color(0.12, 0.25, 0.45), {"variation": 0.3}), Vector3(IN_X + 4.0, 2.0, z0 + 0.08))
	Look.piece(self, Look.blob(0.2), Look.glow(Color(0.25, 0.7, 1.0), 2.2), Vector3(IN_X + 4.0, 2.0, z0 + 0.12))
	_mapa.lamp = _lamp(Vector3(IN_X, 2.8, -19.5), 1.1)
	_floor_mat = _saguao_floor()
	_hint(Rect2(sx0, z0, 12, 9.5), "Sala dos oficiais. Use F na mesa para escolher a missão.")


## Mesa com o mapa aberto e alfinetes das instalações.
func _build_mesa(top: Vector3) -> void:
	var wood := Look.wood(Color(0.35, 0.22, 0.14))
	_solid_piece(top + Vector3(0, 0.45, 0), Vector3(3.6, 0.12, 2.2), wood)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Look.piece(self, Look.box(Vector3(0.14, 0.42, 0.14)), wood, top + Vector3(1.6 * sx, 0.2, 0.9 * sz))
	var paper := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.0, 1.8)
	paper.mesh = pm
	paper.material_override = Look.paper()
	paper.position = top + Vector3(0, 0.52, 0)
	paper.rotation_degrees = Vector3(0, 3, 0)
	add_child(paper)
	# Alfinetes azuis das missões e a câmera que desce até o mapa.
	_mapa = MesaMapa.new()
	_mapa.name = "MesaMapa"
	add_child(_mapa)
	_mapa.setup(top + Vector3(0, 0.52, 0))
	_mapa.mission_chosen.connect(_on_mission_chosen)
	var mesa := HubSpot.new()
	mesa.position = top + Vector3(0, 0, 1.6)
	mesa.prompt = "Abrir o mapa de missões"
	add_child(mesa)
	mesa.used.connect(_mapa.open)
	# Cadeiras.
	for sx in [-1.0, 1.0]:
		_solid_piece(top + Vector3(2.4 * sx, 0.25, 0.3), Vector3(0.6, 0.5, 0.6), wood)


## Portas dos quartos nas paredes laterais do mezanino (2 de cada lado).
func _build_quartos(x0: float) -> void:
	var owners := ["Fênix", "Feixe", "", ""]
	var occupied := [true, Game.progress.get("feixe", false), false, false]
	var frame := Look.surface(Color(0.32, 0.2, 0.13), {"outline": 0.03})
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var wall_x := x0 + 0.06 if side < 0 else x0 + 16.0 - 0.06
		var z := -11.5 + int(i / 2) * 3.6
		var lit: bool = occupied[i]
		Look.piece(self, Look.box(Vector3(0.12, 2.3, 1.4)), frame, Vector3(wall_x, MEZ_Y + 1.15, z))
		var inner: Material = Look.glow(LAMP, 0.6) if lit else Look.surface(Color(0.06, 0.06, 0.07))
		Look.piece(self, Look.box(Vector3(0.13, 2.1, 1.1)), inner, Vector3(wall_x - side * 0.02, MEZ_Y + 1.05, z))
		if lit:
			_label(owners[i], Vector3(wall_x - side * 1.2, MEZ_Y + 0.01, z))
		else:
			for k in 3:
				Look.piece(self, Look.box(Vector3(0.06, 0.16, 1.5)), Look.wood(Color(0.4, 0.3, 0.2), 0.0), Vector3(wall_x - side * 0.1, MEZ_Y + 0.6 + k * 0.6, z), Vector3(8 - k * 9, 0, 0))


# ================================================================ alas

func _build_laboratorio() -> void:
	var open: bool = Game.progress.get("lab_open", false)
	_floor_mat = Look.tiles(Look.tex("Tiles107", Vector2(2.0, 2.0), Color(0.55, 0.56, 0.55), {"tile_size": 0.4, "grass_amount": 0.15 if open else 0.4, "grass_color": Color(0.58, 0.5, 0.38)}))
	_room(56, -14, 71, 4, Color.WHITE, {"E": [[-2.0, 3.0]]})
	_parede_lisa(55.74, -14.0, 4.0)
	_parede_lisa(71.26, -14.0, 4.0, -2.0)
	_label("Laboratório", Vector3(63.5, 0, 2))
	var metal := Look.surface(Color(0.4, 0.43, 0.46), Look.tex("MetalPlates014", Vector2(1.6, 1.6), Color(0.85, 0.88, 0.9), {"outline": 0.03}))
	for x in [59.0, 63.5, 68.0]:
		_solid_piece(Vector3(x, 0.5, -9), Vector3(3.2, 1.0, 1.3), metal)
	_solid_piece(Vector3(63.5, 1.1, -13.4), Vector3(12, 2.2, 0.8), Look.surface(Color(0.32, 0.36, 0.34), Look.tex("MetalPlates014", Vector2(1.6, 1.6), Color(0.6, 0.66, 0.64), {"outline": 0.03})))
	if open:
		_open_lab()
	else:
		for p in [Vector3(58, 0, -2), Vector3(66, 0, 1), Vector3(69, 0, -12)]:
			Look.bush(self, p, 1.3, int(p.x))
		_lab_door = Door.new()
		_lab_door.name = "PortaLaboratorio"
		_lab_door.blast_door = true
		_lab_door.position = Vector3(71.5, 0, -2)
		add_child(_lab_door)
		_lab_door.setup(Vector3(0.8, WALL_H, 3), Color(0.55, 0.6, 0.65))
		_lab_door.opened_door.connect(_on_lab_opened)
		if Game.progress.get("feixe", false):
			_hint(Rect2(72, -4, 3, 4), "A porta blindada do laboratório. Troque para o Feixe e segure Q para cortar.")
		else:
			_hint(Rect2(72, -4, 3, 4), "Porta blindada do laboratório. Alguém que corte aço poderia abrir.")


func _open_lab() -> void:
	_lamp(Vector3(63.5, 2.8, -6), 1.6)
	var bancada := HubSpot.new()
	bancada.position = Vector3(63.5, 0, -7.6)
	bancada.prompt = "Usar a bancada"
	bancada.text = "Bancada do laboratório: aqui o grupo vai fabricar equipamentos com peças do Protocolo (em breve)."
	add_child(bancada)


func _on_lab_opened() -> void:
	Game.progress["lab_open"] = true
	_open_lab()
	Game.message("O Feixe cortou a porta! O laboratório está aberto.", 4.0)


func _build_treino() -> void:
	_floor_mat = Look.surface(Color(0.5, 0.33, 0.22), Look.tex("WoodFloor051", Vector2(1.8, 1.8), Color(0.88, 0.82, 0.76)))
	_room(89, -14, 104, 4, Color.WHITE, {"W": [[-2.0, 3.0]]})
	_parede_lisa(104.26, -14.0, 4.0)
	_parede_lisa(88.74, -14.0, 4.0, -2.0)
	_label("Treino: ginásio", Vector3(96.5, 0, 2))
	var debris := Look.surface(Color(0.45, 0.43, 0.4), Look.tex("Concrete044D", Vector2(1.5, 1.5), Color(0.92, 0.88, 0.82), {"outline": 0.04}))
	for p in [Vector3(91.5, 0, -1.5), Vector3(93.5, 0, 1.5), Vector3(92.5, 0, -4.5)]:
		_solid_piece(p + Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.8), debris, Vector3(0, rng.randf_range(0, 40), rng.randf_range(-8, 8)))
	# Cesta de basquete torta.
	var metal := Look.surface(Color(0.5, 0.3, 0.2), {"outline": 0.03})
	Look.piece(self, Look.box(Vector3(0.15, 3.5, 0.15)), metal, Vector3(96.5, 1.75, -13.2))
	Look.piece(self, Look.box(Vector3(1.8, 1.1, 0.08)), Look.surface(Color(0.75, 0.73, 0.68), {"outline": 0.03}), Vector3(96.5, 3.4, -12.9), Vector3(0, 0, 7))
	_hint(Rect2(89, -4, 3, 4), "O ginásio está cheio de entulho. Um mutante forte poderia liberar o treino.")


## Clicou num alfinete jogável: abre o cartão da missão por cima do mapa e,
## quando o cartão fecha com Esc, volta para o mapa.
func _on_mission_chosen(_id: String) -> void:
	mission_requested.emit()
	for c in get_parent().get_children():
		if c is MissionCard and not c.is_queued_for_deletion():
			(c as MissionCard).closed.connect(_mapa.back_from_card)


# ================================================================ salas laterais

## Laboratório e treino têm a parede da frente inteira (dois andares), para não
## se ver dentro deles do saguão. Com o grupo dentro, a parede fica transparente.
func _build_paredes_laterais() -> void:
	var h := 8.0
	for r in [Rect2(56, -14, 15, 18), Rect2(89, -14, 15, 18)]:
		var mat := Look.brick({"moss_amount": 0.5})
		var size := Vector3(r.size.x + 2.0 * WALL_T, h, 0.5)
		var c := Vector3(r.get_center().x, h * 0.5, r.end.y + 0.25)
		var mi := Look.piece(self, Look.box(size), mat, c)
		# Faixa escura no topo, como o resto da estrutura.
		var cap := StandardMaterial3D.new()
		cap.albedo_color = Color(0.14, 0.15, 0.17)
		var top := Look.piece(self, Look.box(Vector3(size.x, 0.05, size.z)), cap, c + Vector3(0, h * 0.5 + 0.02, 0))
		_frentes.append({"rect": r, "nodes": [mi, top], "faded": false})


func _update_paredes_laterais(pos: Vector3) -> void:
	var p := Vector2(pos.x, pos.z)
	for f in _frentes:
		var inside: bool = (f["rect"] as Rect2).grow(0.2).has_point(p)
		if inside != f["faded"]:
			f["faded"] = inside
			for n in f["nodes"]:
				(n as Node3D).visible = not inside


# ================================================================ peças do hub

## Piso do saguão: ladrilho bege antigo (Tiles139) com areia acumulada.
func _saguao_floor() -> Material:
	return Look.tiles(Look.tex("Tiles139", Vector2(2.0, 2.0), Color(0.88, 0.85, 0.8), {"tile_size": 0.6, "grass_amount": 0.3, "grass_color": Color(0.58, 0.5, 0.38)}))


## Parede lateral lisa, de uma peça só (só visual), por cima da estrutura em
## faixas de 1 m: ali o tijolo aparecia em degraus, com as fiadas de lado.
## door_z: centro da porta de 3 m nessa parede (NAN = sem porta).
func _parede_lisa(x: float, z0: float, z1: float, door_z: float = NAN) -> void:
	var hh := 8.0
	var mat := Look.brick()
	var spans: Array = [[z0 - 0.5, z1]]
	if not is_nan(door_z):
		spans = [[z0 - 0.5, door_z - 1.5], [door_z + 1.5, z1]]
		# Verga por cima da porta.
		Look.piece(self, Look.box(Vector3(0.5, hh - WALL_H, 3.0)), mat, Vector3(x, (hh + WALL_H) * 0.5, door_z))
	for sp in spans:
		var a: float = sp[0]
		var b: float = sp[1]
		Look.piece(self, Look.box(Vector3(0.5, hh, b - a)), mat, Vector3(x, hh * 0.5, (a + b) * 0.5))


## Paredes de dentro: reboco descascado mostrando o tijolo (PaintedPlaster016).
func _reboco_interno() -> Dictionary:
	return Look.tex("PaintedPlaster016", Vector2(3.5, 3.5), Color(0.92, 0.88, 0.84))


## Chão com o material atual (_floor_mat), sem linhas de grade.
func _floor(x0: float, z0: float, x1: float, z1: float, _color: Color) -> void:
	_floor_rects.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	_box_visual_mat(Vector3((x0 + x1) * 0.5, -0.1, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.2, z1 - z0), _floor_mat)


func _link(x0: float, z0: float, x1: float, z1: float) -> void:
	_floor(x0, z0, x1, z1, Color.WHITE)


func _box_visual_mat(center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return Look.piece(self, Look.box(size), mat, center)


## Caixa com colisão e material próprio.
func _solid_piece(center: Vector3, size: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	Look.piece(body, Look.box(size), mat, Vector3.ZERO)
	body.position = center
	body.rotation_degrees = rot_deg
	add_child(body)
	return body


## Rampa de colisão de "from" (embaixo) até "to" (em cima).
func _ramp(from: Vector3, to: Vector3, width: float, mat: Material) -> void:
	var length := from.distance_to(to)
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.2, length)
	shape.shape = box
	body.add_child(shape)
	Look.piece(body, Look.box(box.size), mat, Vector3.ZERO)
	add_child(body)
	body.look_at_from_position((from + to) * 0.5, to, Vector3.UP)


## Escada: rampa para andar e degraus visuais por cima.
func _stairs(from: Vector3, to: Vector3, width: float, mat: Material) -> void:
	_ramp(from, to, width, mat)
	var steps := int(ceil((to.y - from.y) / 0.25))
	var depth := absf(to.z - from.z) / float(steps)
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		var p := from.lerp(to, t)
		Look.piece(self, Look.box(Vector3(width, 0.25, depth + 0.02)), mat, Vector3(p.x, p.y - 0.02, p.z))


func _lamp(pos: Vector3, energy: float = 1.6) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = LAMP
	light.light_energy = energy * _lamp_scale
	light.omni_range = 8.0
	light.shadow_enabled = true
	light.position = pos
	add_child(light)
	Look.piece(self, Look.cylinder(0.05, 0.3, 0.25, 6), Look.glow(LAMP, 2.0), pos + Vector3(0, 0.15, 0))
	return light


func _move_party(target: Vector3) -> void:
	var party := Game.party
	if party == null:
		return
	var i := 0
	for h in party.heroes:
		if not h.in_party:
			continue
		h.global_position = target + Vector3(1.2 * i, 0, 0.8 * i)
		h.velocity = Vector3.ZERO
		h.last_safe_position = h.global_position
		i += 1
	party.breadcrumbs.clear()
	if party.camera_rig != null and party.controlled_hero != null:
		party.camera_rig.follow(party.controlled_hero, false)


## Materiais da estrutura em corte: tijolo nas paredes, escuro nos topos.
func _commit(st: SurfaceTool, mesh: ArrayMesh, color: Color) -> void:
	var mat: Material
	if color.r > 0.5:
		mat = Look.brick()
	elif color.r > 0.33:
		mat = Look.brick({"tex_tint": Color(0.8, 0.78, 0.76)})
	elif color.r > 0.27:
		mat = Look.brick({"tex_tint": Color(0.7, 0.68, 0.66)})
	else:
		mat = Look.surface(Color(0.12, 0.13, 0.14), {"variation": 0.2, "noise_scale": 2.0})
	st.set_material(mat)
	st.commit(mesh)


## Entardecer: luz baixa e alaranjada, ambiente frio, brilho no fogo azul.
## Clima padrão: "lanterna" (noite azulada, luz quente das lâmpadas).
## Para comparar: variável de ambiente LOOK=entardecer ou LOOK=musgo.
func _build_lighting() -> void:
	var variant := OS.get_environment("LOOK")
	if variant == "":
		variant = "lanterna"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_bloom = 0.05
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -50, 0)
	sun.shadow_enabled = true
	match variant:
		"lanterna":
			# Noite: sombra fria azul-petróleo, poças de luz quente nas lâmpadas.
			e.background_color = Color(0.03, 0.04, 0.05)
			e.ambient_light_color = Color(0.32, 0.5, 0.6)
			e.ambient_light_energy = 0.32
			e.glow_intensity = 0.9
			e.adjustment_enabled = true
			e.adjustment_saturation = 1.25
			e.adjustment_contrast = 1.1
			sun.rotation_degrees = Vector3(-55, 30, 0)
			sun.light_color = Color(0.55, 0.72, 1.0)
			sun.light_energy = 0.35
			_lamp_scale = 1.3
		"musgo":
			# Ruína úmida: verde-azulado escuro, contraste alto, brilho forte nas fontes.
			e.background_color = Color(0.03, 0.05, 0.045)
			e.ambient_light_color = Color(0.36, 0.55, 0.45)
			e.ambient_light_energy = 0.36
			e.glow_intensity = 1.1
			e.glow_bloom = 0.1
			e.adjustment_enabled = true
			e.adjustment_saturation = 1.35
			e.adjustment_contrast = 1.2
			sun.rotation_degrees = Vector3(-60, -20, 0)
			sun.light_color = Color(0.7, 0.95, 0.8)
			sun.light_energy = 0.3
			_lamp_scale = 1.2
		_:
			e.background_color = Color(0.09, 0.08, 0.1)
			e.ambient_light_color = Color(0.5, 0.55, 0.68)
			e.ambient_light_energy = 0.42
			e.glow_intensity = 0.6
			sun.light_color = Color(1.0, 0.72, 0.5)
			sun.light_energy = 0.85
	env.environment = e
	add_child(env)
	add_child(sun)


# ================================================================ por quadro

func objective_text() -> String:
	if not Game.progress.get("feixe", false):
		return "Entre na escola e use a mesa do mapa, na sala dos oficiais"
	if not Game.progress.get("lab_open", false):
		return "Leve o Feixe ao laboratório (oeste do saguão) e corte a porta blindada (Q)"
	return "Escola: %d de %d mutantes · a mesa do mapa leva a uma nova missão" % [rescued_count(), ROOM_COUNT]


func _physics_process(_delta: float) -> void:
	var party := Game.party
	if party == null or party.controlled_hero == null:
		return
	var hero: Hero = party.controlled_hero
	_update_wall_fade(hero.global_position)
	_update_cutaway(hero.global_position)
	_update_hints(hero.global_position)
	_update_paredes_laterais(hero.global_position)
