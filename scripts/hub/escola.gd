class_name Escola
extends PostoVigia
## Hub "Escola": o antigo internato abandonado, a Base dos Heróis.
## Planta: docs/Base_dos_Herois_planta.pdf (1 m = 1 unidade).
## Fachada: prancha reforma-hub-v1 (tijolo velho, pórtico com frontão,
## telhado de ardósia, hera e areia).
##
## Coordenadas da planta: x = leste, z = sul (o "y" da planta). O prédio vai
## de x 0 a 80 e de z -5 a 22, com o pórtico até z 25 e a escadaria até z 28.
## A fachada da entrada (z 22) ficou onde a planta põe; o resto do prédio
## recuou 5 m para trás, e o saguão ganhou esses 5 m (prancha escola-comprida-v1).
## Térreo e 1º andar ficam no mesmo cenário, ligados por escadas de verdade.
##
## Construção no padrão novo (Obra): uma parede = uma peça, vãos recortados,
## tetos em todas as salas e nada sumindo conforme a posição do herói.

signal mission_requested

const ROOM_COUNT := 8
const LAMP := Color(1.0, 0.76, 0.42)

## Alturas (m). O prédio fica sobre um embasamento de 45 cm.
const B := 0.45            # piso do térreo
const TETO0 := 3.95        # teto do térreo = fundo da laje
const LAJE := 4.22         # topo da laje (as paredes do 1º andar nascem aqui)
const F1 := 4.25           # piso do 1º andar (acabamento de 3 cm)
const TETO1 := 7.65        # teto do 1º andar = fundo da cobertura
const TOPO := 7.95         # topo da cobertura e das paredes externas
const PLATIBANDA := 8.85   # mureta das alas do meio

const EXT := 0.3           # meia espessura da parede externa
const INT := 0.125         # meia espessura da parede interna

## Área interna do prédio (faces de dentro das paredes externas).
const MIOLO := [Rect2(0.3, -1.7, 79.4, 13.4), Rect2(30.3, -4.7, 19.4, 3.0), Rect2(30.3, 11.7, 19.4, 10.0)]
## Vazio do saguão e escadas (sem laje).
const VAZIO := Rect2(30.125, 8.0, 19.75, 13.7)
## Quarto trancado do telhado desabado (sem cobertura).
const DESABADO := Rect2(0.3, -1.7, 9.575, 13.4)

var _lamp_scale := 1.0
var _lab_door: Door
var _mapa: MesaMapa
var M := {}
## Paredes do andar em montagem: [{axis, fixo, a0, a1, y0, y1, t, mat, vaos}].
var _paredes: Array[Dictionary] = []
var _folhas: Array = []


func build() -> void:
	rng.seed = 7
	player_spawn = Vector3(40, 0, 29.3)
	feixe_cell_position = Vector3(41.6, 0, 29.8)
	_candidates_root = Node3D.new()
	_candidates_root.name = "Candidatos"
	add_child(_candidates_root)
	_materiais()
	_build_lighting()
	_build_terreno()
	var predio := Node3D.new()
	predio.name = "Predio"
	add_child(predio)
	_build_casca(predio)
	_build_terreo(predio)
	_build_primeiro(predio)
	_levantar_paredes(predio)
	_build_lajes(predio)
	_build_telhados(predio)
	_build_portico(predio)
	_build_saguao(predio)
	_build_salas(predio)
	_build_dormitorios(predio)
	_build_garagem()
	_build_areia(predio)
	Game.chests_total = 0


func rescued_count() -> int:
	return 1 + (1 if Game.progress.get("feixe", false) else 0)


# ================================================================ materiais

func _materiais() -> void:
	var areia := Color(0.66, 0.56, 0.4)
	M = {
		"tijolo": Look.brick(Look.tex("Bricks094", Vector2(1.8, 1.8), Color(1.25, 0.98, 0.84), {"tex_contrast": 0.95})),
		"reboco": Look.surface(Color(0.6, 0.55, 0.47), Look.tex("Plaster007", Vector2(3.0, 3.0), Color(0.8, 0.74, 0.64))),
		"reboco_tijolo": Look.surface(Color(0.7, 0.6, 0.5), Look.tex("PaintedPlaster016", Vector2(3.5, 3.5), Color(0.98, 0.9, 0.82))),
		"teto": Look.surface(Color(0.5, 0.48, 0.45), Look.tex("PaintedPlaster015", Vector2(3.0, 3.0), Color(0.68, 0.65, 0.6))),
		"friso": Look.surface(Color(0.78, 0.74, 0.66), Look.tex("Concrete044D", Vector2(2.5, 2.5), Color(1.15, 1.1, 1.0))),
		"concreto": Look.surface(Color(0.55, 0.52, 0.47), Look.tex("Concrete036", Vector2(3.0, 3.0), Color(1.0, 0.96, 0.88))),
		"asfalto": Look.surface(Color(0.3, 0.3, 0.3), Look.tex("Concrete047A", Vector2(3.0, 3.0), Color(0.62, 0.6, 0.58))),
		"ardosia": Look.surface(Color(0.3, 0.32, 0.34), Look.tex("RoofingTiles003", Vector2(2.4, 2.4), Color(0.95, 0.97, 1.0))),
		"areia": Look.surface(Color(0.74, 0.63, 0.45), Look.tex("Ground054", Vector2(3.0, 3.0), Color(1.08, 1.0, 0.9))),
		"grama": Look.surface(Color(0.22, 0.3, 0.16), Look.tex("Ground109", Vector2(5.0, 5.0))),
		"madeira": Look.wood(),
		"madeira_escura": Look.wood(Color(0.3, 0.2, 0.14)),
		"metal": Look.surface(Color(0.24, 0.27, 0.3), Look.tex("PaintedMetal006", Vector2(2.0, 2.0), Color(0.6, 0.68, 0.72), {"outline": 0.02})),
		"chapa": Look.surface(Color(0.4, 0.43, 0.46), Look.tex("MetalPlates014", Vector2(1.6, 1.6), Color(0.85, 0.88, 0.9))),
		"vidro": Look.surface(Color(0.08, 0.11, 0.13), {"variation": 0.3, "noise_scale": 4.0}),
		"escuro": Look.surface(Color(0.05, 0.05, 0.06), {"variation": 0.1}),
		# Pisos (a areia entra pelos cantos: "grass" do shader de ladrilho).
		"p_saguao": Look.tiles(Look.tex("Tiles013", Vector2(2.4, 2.4), Color(0.92, 0.88, 0.8), {"tile_size": 1.2, "grass_amount": 0.32, "grass_color": areia, "dirt_color": Color(0.5, 0.42, 0.32)})),
		"p_azulejo": Look.tiles(Look.tex("Tiles016", Vector2(1.6, 1.6), Color(0.85, 0.83, 0.78), {"tile_size": 0.4, "grass_amount": 0.25, "grass_color": areia})),
		"p_lab": Look.tiles(Look.tex("Tiles107", Vector2(2.0, 2.0), Color(0.55, 0.56, 0.55), {"tile_size": 0.4, "grass_amount": 0.3, "grass_color": areia})),
		"p_taco": Look.surface(Color(0.3, 0.2, 0.14), Look.tex("WoodFloor043", Vector2(1.3, 0.65), Color(0.85, 0.8, 0.76))),
		"p_corredor": Look.surface(Color(0.45, 0.42, 0.38), Look.tex("WoodFloor003", Vector2(2.0, 2.0), Color(0.9, 0.86, 0.8))),
		"p_ginasio": Look.surface(Color(0.5, 0.33, 0.22), Look.tex("WoodFloor051", Vector2(1.8, 1.8), Color(0.88, 0.82, 0.76))),
		"p_tabua": Look.surface(Color(0.45, 0.3, 0.2), Look.tex("WoodFloor004", Vector2(2.0, 2.0), Color(0.8, 0.72, 0.64))),
		"p_cimento": Look.tiles(Look.tex("Concrete036", Vector2(3.0, 3.0), Color(0.95, 0.9, 0.82), {"tile_size": 1.0, "grass_amount": 0.35, "grass_color": areia})),
	}


# ================================================================ terreno

func _build_terreno() -> void:
	# Chão de colisão único (o campo inteiro); os pisos só desenham.
	var body := StaticBody3D.new()
	body.name = "ChaoColisao"
	body.collision_layer = Game.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 62)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(40, -0.5, 17)
	add_child(body)
	# Camadas do chão de fora em alturas diferentes (nada no mesmo plano):
	# grama 0 · asfalto 1,5 cm · caminhos 2,5 cm · quadra 3 cm · pátio 3,5 cm.
	Obra.bloco(self, Vector3(-40, -0.2, -14), Vector3(120, 0.0, 48), M["grama"], false)
	Obra.bloco(self, Vector3(22, -0.1, 28), Vector3(58, 0.035, 37.5), M["concreto"], false)
	for r in [Rect2(38, 37.5, 4, 10.5), Rect2(58, 31, 39, 2), Rect2(82.6, 0.6, 13.4, 2.8), Rect2(66, -11.8, 2, 8.0), Rect2(-10, 4, 9.7, 2)]:
		Obra.bloco(self, Vector3(r.position.x, -0.1, r.position.y), Vector3(r.end.x, 0.025, r.end.y), M["p_cimento"], false)
	Obra.bloco(self, Vector3(97, -0.1, 9), Vector3(111, 0.015, 48), M["asfalto"], false)
	_build_fonte(Vector3(40, 0, 35.2))
	_build_quadra()
	# Bordas do campo (o mato fechado em volta).
	for w in [[Vector3(-38.2, 1.5, 17), Vector3(0.4, 3, 62)], [Vector3(118.2, 1.5, 17), Vector3(0.4, 3, 62)],
			[Vector3(40, 1.5, -12.2), Vector3(160, 3, 0.4)], [Vector3(40, 1.5, 46.2), Vector3(160, 3, 0.4)]]:
		_invisible_wall(w[0], w[1])
	# Árvores e moitas fora do prédio, dos caminhos e do pátio.
	var livres := [Rect2(-2, -6, 84, 35), Rect2(20, 26, 40, 22), Rect2(94, -5, 20, 53), Rect2(-36, -1, 28, 19), Rect2(56, 29, 42, 6), Rect2(64, -14, 6, 14), Rect2(78, -2, 20, 7)]
	var k := 0
	var z := -10.0
	while z < 45.0:
		var x := -36.0
		while x < 117.0:
			var p := Vector3(x + rng.randf_range(-2.0, 2.0), 0, z + rng.randf_range(-2.0, 2.0))
			var ok := true
			for r in livres:
				if (r as Rect2).has_point(Vector2(p.x, p.z)):
					ok = false
					break
			k += 1
			if ok and rng.randf() < 0.55:
				if k % 3 == 0:
					Look.bush(self, p, rng.randf_range(1.2, 2.0), 300 + k)
				else:
					Look.tree(self, p, rng.randf_range(1.0, 1.6), 300 + k)
			x += 7.0
		z += 7.0
	# Mato baixo encostado no prédio.
	for p in [Vector3(5, 0, 13.5), Vector3(14, 0, 13), Vector3(27, 0, 13.4), Vector3(53, 0, 13.3), Vector3(64, 0, 13), Vector3(76, 0, 13.6), Vector3(31.5, 0, 23), Vector3(48.5, 0, 23.2), Vector3(-1.5, 0, 1), Vector3(81.5, 0, 9)]:
		Look.bush(self, p, rng.randf_range(1.0, 1.5), int(p.x * 10))


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


## Fonte seca no meio do pátio: anel de pedra, fundo de areia e pedestal.
func _build_fonte(c: Vector3) -> void:
	var pedra: Material = M["friso"]
	var n := 16
	var r := 2.6
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var h := 0.6 if i % 2 == 0 else 0.62
		Obra.caixa(self, p + Vector3(0, h * 0.5, 0), Vector3(0.45, h, 1.08), pedra, true, Vector3(0, -rad_to_deg(a), 0))
	Look.piece(self, Look.cylinder(r - 0.1, r - 0.1, 0.24, 16), M["areia"], c + Vector3(0, 0.12, 0))
	Obra.caixa(self, c + Vector3(0, 0.7, 0), Vector3(0.6, 1.4, 0.6), pedra)
	Look.piece(self, Look.cylinder(0.9, 0.35, 0.35, 10), pedra, c + Vector3(0, 1.55, 0))


## Quadra antiga a oeste: piso rachado, linhas apagadas e duas tabelas.
func _build_quadra() -> void:
	Obra.bloco(self, Vector3(-34, -0.1, 1), Vector3(-10, 0.03, 16), M["p_cimento"], false)
	var linha := Look.surface(Color(0.75, 0.72, 0.64), {"variation": 0.35, "noise_scale": 3.0})
	# Linhas que se cruzam ficam em alturas diferentes (sem faces no mesmo plano).
	for seg in [[-33, 1.5, -11, 1.6, 0.04], [-33, 15.4, -11, 15.5, 0.04], [-33, 1.6, -32.9, 15.4, 0.045], [-11.1, 1.6, -11, 15.4, 0.045], [-22.05, 1.6, -21.95, 15.4, 0.045]]:
		Obra.bloco(self, Vector3(seg[0], 0.03, seg[1]), Vector3(seg[2], seg[4], seg[3]), linha, false)
	var poste := Look.surface(Color(0.5, 0.3, 0.2), {"outline": 0.03})
	for sx in [-1.0, 1.0]:
		var x: float = -22.0 + sx * 10.6
		Obra.caixa(self, Vector3(x, 1.75, 8.5), Vector3(0.15, 3.5, 0.15), poste)
		Obra.caixa(self, Vector3(x - sx * 0.12, 3.3, 8.5), Vector3(0.08, 1.1, 1.8), M["friso"], true, Vector3(0, 0, sx * 6.0))


# ================================================================ paredes

## Registra uma parede para ser levantada no fim (as do eixo z são aparadas
## onde encontram as do eixo x, para nenhuma peça entrar na outra).
func _parede(axis: String, fixo: float, a0: float, a1: float, y0: float, y1: float, t: float, mat: Material, vaos: Array = []) -> void:
	_paredes.append({"axis": axis, "fixo": fixo, "a0": a0, "a1": a1, "y0": y0, "y1": y1, "t": t, "mat": mat, "vaos": vaos})


func _levantar_paredes(parent: Node3D) -> void:
	for w in _paredes:
		var segs: Array = [[w["a0"], w["a1"]]]
		if w["axis"] == "z":
			for o in _paredes:
				if o["axis"] != "x":
					continue
				# A parede x cruza esta? (sobreposição de verdade, não só encostar)
				var ox0: float = o["a0"]
				var ox1: float = o["a1"]
				var x0: float = w["fixo"] - w["t"]
				var x1: float = w["fixo"] + w["t"]
				if ox1 <= x0 + 0.001 or ox0 >= x1 - 0.001:
					continue
				if o["y1"] <= w["y0"] + 0.001 or o["y0"] >= w["y1"] - 0.001:
					continue
				var cz0: float = o["fixo"] - o["t"]
				var cz1: float = o["fixo"] + o["t"]
				var novos: Array = []
				for s in segs:
					if cz1 <= s[0] + 0.001 or cz0 >= s[1] - 0.001:
						novos.append(s)
						continue
					if cz0 > s[0] + 0.001:
						novos.append([s[0], cz0])
					if cz1 < s[1] - 0.001:
						novos.append([cz1, s[1]])
				segs = novos
		for s in segs:
			Obra.parede(parent, w["axis"], w["fixo"], s[0], s[1], w["y0"], w["y1"], [[-w["t"], w["t"], w["mat"]]], w["vaos"])
	_paredes.clear()
	for f in _folhas:
		Obra.bloco(parent, f[0], f[1], M["madeira_escura"])
	_folhas.clear()


## Vão de porta. tipo: simples, dupla, arco, portao, pregada, blindada.
## lado (+1/-1): para que lado do eixo a folha abre (encostada na parede).
## O vão começa no fundo do piso (os pisos das duas salas se encontram no eixo
## da parede, sem soleira por cima); nas portas externas, no piso.
func _porta(axis: String, fixo: float, t: float, u0: float, u1: float, y: float, tipo: String, lado: float = 1.0, externa: bool = false) -> Array:
	var h := {"simples": 2.2, "dupla": 2.4, "arco": 2.8, "portao": 3.0, "pregada": 2.2, "blindada": 2.3}[tipo] as float
	if tipo == "simples" or tipo == "dupla":
		var w := (u1 - u0) if tipo == "simples" else (u1 - u0) * 0.5
		var hinges := [u0] if tipo == "simples" else [u0, u1 - 0.05]
		for hu in hinges:
			var f0: float = fixo + lado * t
			var f1: float = f0 + lado * (w - 0.02)
			if axis == "x":
				_folhas.append([Vector3(hu, y, f0), Vector3(hu + 0.05, y + h - 0.05, f1)])
			else:
				_folhas.append([Vector3(f0, y, hu), Vector3(f1, y + h - 0.05, hu + 0.05)])
	var base := y
	if not externa:
		base = 0.0 if is_equal_approx(y, B) else (LAJE if is_equal_approx(y, F1) else y)
	return [u0, u1, base, y + h]


## Janela: vão + vidro (inteiro, quebrado ou tapado com tábuas) + peitoril.
## fora: +1/-1, lado de fora da parede (externa).
func _janela(parent: Node3D, axis: String, fixo: float, u: float, piso: float, fora: float, w: float = 1.2) -> Array:
	var v0 := piso + 0.9
	var v1 := piso + 2.5
	var u0 := u - w * 0.5
	var u1 := u + w * 0.5
	var sorte := rng.randf()
	var a := func(uu: float, yy: float, ff: float) -> Vector3:
		return Vector3(uu, yy, ff) if axis == "x" else Vector3(ff, yy, uu)
	if sorte < 0.55:
		Obra.bloco(parent, a.call(u0, v0, fixo - 0.02), a.call(u1, v1, fixo + 0.02), M["vidro"])
	elif sorte < 0.8:
		for k in 3:
			var y0 := v0 + 0.15 + k * 0.5
			Obra.bloco(parent, a.call(u0, y0, fixo + fora * 0.05), a.call(u1, y0 + 0.3, fixo + fora * 0.15), M["madeira"], false)
	else:
		# Quebrada: só um caco no canto.
		Obra.bloco(parent, a.call(u0, v0, fixo - 0.02), a.call(u0 + 0.4, v0 + 0.5, fixo + 0.02), M["vidro"], false)
	Obra.bloco(parent, a.call(u0 - 0.1, v0 - 0.08, fixo + fora * EXT), a.call(u1 + 0.1, v0, fixo + fora * (EXT + 0.1)), M["friso"], false)
	return [u0, u1, v0, v1]


# ================================================================ casca

## Paredes externas (tijolo, de uma peça do chão ao topo), frisos e platibanda.
func _build_casca(parent: Node3D) -> void:
	var t: Material = M["tijolo"]
	# Janelas por parede: posições ao longo dela (térreo, 1º andar).
	var alas_t := [2.5, 7.5, 12.5, 17.5, 22.5, 27.5, 52.5, 57.5, 62.5, 72.5, 77.5]
	var alas_1 := [2.5, 7.5, 12.5, 17.5, 22.5, 27.5, 52.5, 57.5, 62.5, 67.5, 72.5, 77.5]
	# Norte das alas (z = -2), com a porta de serviço da cozinha.
	var v: Array = []
	for u in alas_t:
		v.append(_janela(parent, "x", -2.0, u, B, -1.0))
	for u in alas_1:
		v.append(_janela(parent, "x", -2.0, u, F1, -1.0))
	v.append(_porta("x", -2.0, EXT, 66.4, 67.6, B, "simples", 1.0, true))
	v.append_array(_platibanda_vaos())
	_parede("x", -2.0, -0.3, 30.3, 0.0, PLATIBANDA, EXT, t, v.filter(func(q: Array) -> bool: return q[1] <= 30.3))
	_parede("x", -2.0, 49.7, 80.3, 0.0, PLATIBANDA, EXT, t, v.filter(func(q: Array) -> bool: return q[0] >= 49.7))
	# Sul das alas (z = 12).
	v = []
	for u in alas_1:
		v.append(_janela(parent, "x", 12.0, u, B, 1.0))
		v.append(_janela(parent, "x", 12.0, u, F1, 1.0))
	v.append_array(_platibanda_vaos())
	_parede("x", 12.0, -0.3, 30.3, 0.0, PLATIBANDA, EXT, t, v.filter(func(q: Array) -> bool: return q[1] <= 30.3))
	_parede("x", 12.0, 49.7, 80.3, 0.0, PLATIBANDA, EXT, t, v.filter(func(q: Array) -> bool: return q[0] >= 49.7))
	# Corpo central: norte (z = -5) e sul (z = 22, a fachada da entrada, que não mudou).
	v = []
	for u in [35.0, 45.0]:
		v.append(_janela(parent, "x", -5.0, u, B, -1.0))
	for u in [32.5, 36.5, 40.0, 43.5, 47.5]:
		v.append(_janela(parent, "x", -5.0, u, F1, -1.0))
	_parede("x", -5.0, 29.7, 50.3, 0.0, TOPO, EXT, t, v)
	v = [[38.5, 41.5, B, B + 2.6]]
	for u in [33.0, 47.0]:
		v.append(_janela(parent, "x", 22.0, u, B, 1.0))
	for u in [33.0, 36.8, 43.2, 47.0]:
		v.append(_janela(parent, "x", 22.0, u, F1, 1.0))
	v.append(_janela(parent, "x", 22.0, 40.0, F1, 1.0, 2.4))
	_parede("x", 22.0, 29.7, 50.3, 0.0, TOPO, EXT, t, v)
	# Pontas (x = 0 e x = 80) e laterais do corpo central.
	v = []
	for u in [0.0, 3.5, 7.0, 10.0]:
		v.append(_janela(parent, "z", 0.0, u, B, -1.0))
		v.append(_janela(parent, "z", 0.0, u, F1, -1.0))
	_parede("z", 0.0, -2.0, 12.0, 0.0, TOPO, EXT, t, v)
	v = [_porta("z", 80.0, EXT, 0.5, 3.5, B, "portao", 1.0, true)]
	for u in [7.0, 10.0]:
		v.append(_janela(parent, "z", 80.0, u, B, 1.0))
	for u in [0.0, 3.5, 7.0, 10.0]:
		v.append(_janela(parent, "z", 80.0, u, F1, 1.0))
	_parede("z", 80.0, -2.0, 12.0, 0.0, TOPO, EXT, t, v)
	# Laterais do corpo central: atrás das alas (3 m) e na frente delas (10 m,
	# a parte do saguão que avança para o pátio).
	for sx in [30.0, 50.0]:
		var fora := -1.0 if sx < 40.0 else 1.0
		v = []
		for u in [-3.5]:
			v.append(_janela(parent, "z", sx, u, B, fora, 1.0))
			v.append(_janela(parent, "z", sx, u, F1, fora, 1.0))
		_parede("z", sx, -5.0, -2.0, 0.0, TOPO, EXT, t, v)
		v = []
		for u in [14.5, 19.5]:
			v.append(_janela(parent, "z", sx, u, B, fora, 1.0))
			v.append(_janela(parent, "z", sx, u, F1, fora, 1.0))
		_parede("z", sx, 12.0, 22.0, 0.0, TOPO, EXT, t, v)
	# Frisos de reboco claro na altura das lajes (só nas fachadas norte e sul).
	for fz in [[-2.0, -1.0, -0.3, 29.7], [-2.0, -1.0, 50.3, 80.3], [12.0, 1.0, -0.3, 29.7], [12.0, 1.0, 50.3, 80.3], [-5.0, -1.0, 29.7, 50.3], [22.0, 1.0, 29.7, 35.6], [22.0, 1.0, 44.4, 50.3]]:
		var z0: float = fz[0] + fz[1] * EXT
		Obra.bloco(parent, Vector3(fz[2], LAJE - 0.25, z0), Vector3(fz[3], LAJE + 0.05, z0 + fz[1] * 0.08), M["friso"], false)
	# Óculos redondos na platibanda e a porta de serviço (degraus para fora).
	var oculo := Look.cylinder(0.32, 0.32, 0.04, 12)
	for zf in [[-2.0, -1.0], [12.0, 1.0]]:
		for x in [12.5, 17.5, 22.5, 27.5, 52.5, 57.5, 62.5, 67.5]:
			var zz: float = zf[0] + zf[1] * (EXT + 0.02)
			Look.piece(parent, oculo, M["escuro"], Vector3(x, (TOPO + PLATIBANDA) * 0.5, zz), Vector3(90, 0, 0))
	Obra.escada(parent, 66.2, 67.8, -3.8, -2.3, 0.0, B, M["concreto"])
	Obra.rampa(parent, Vector3(82.6, 0.0, 2.0), Vector3(80.3, B, 2.0), 3.2, M["concreto"])


## A platibanda só existe nas alas do meio; nas pontas e no corpo central
## o telhado de quatro águas encosta no topo da parede.
func _platibanda_vaos() -> Array:
	return [[-0.3, 10.0, TOPO, PLATIBANDA], [70.0, 80.3, TOPO, PLATIBANDA]]


# ================================================================ térreo

func _build_terreo(_parent: Node3D) -> void:
	var r: Material = M["reboco"]
	var y0 := 0.0
	var y1 := TETO0
	# Ala oeste.
	_parede("z", 10.0, -2.0, 12.0, y0, y1, INT, r, [_porta("z", 10.0, INT, 5.25, 7.25, B, "dupla", -1.0)])
	_parede("x", 5.0, 9.875, 30.125, y0, y1, INT, r, [_porta("x", 5.0, INT, 13.5, 14.7, B, "simples", -1.0), _porta("x", 5.0, INT, 24.5, 25.7, B, "simples", -1.0)])
	_parede("x", 7.5, 9.875, 30.125, y0, y1, INT, M["reboco_tijolo"], [_porta("x", 7.5, INT, 15.5, 16.5, B, "simples", 1.0), _porta("x", 7.5, INT, 25.0, 26.0, B, "pregada")])
	_parede("z", 20.0, 7.5, 12.0, y0, y1, INT, r)
	_parede("z", 30.0, -2.0, 12.0, y0, y1, INT, r, [_porta("z", 30.0, INT, 5.2, 7.3, B, "arco")])
	# Corpo central: arquivo | missões | lavabo, e o saguão.
	_parede("x", 4.0, 29.875, 50.125, y0, y1, INT, r, [_porta("x", 4.0, INT, 38.5, 41.5, B, "dupla", -1.0), _porta("x", 4.0, INT, 47.6, 48.5, B, "simples", -1.0)])
	_parede("z", 33.0, -5.0, 4.0, y0, y1, INT, r, [_porta("z", 33.0, INT, 1.8, 2.8, B, "simples", -1.0)])
	_parede("z", 47.0, -5.0, 4.0, y0, y1, INT, r)
	# Ala leste.
	_parede("z", 50.0, -2.0, 12.0, y0, y1, INT, r, [_porta("z", 50.0, INT, 5.2, 7.3, B, "arco")])
	_parede("x", 5.0, 49.875, 70.125, y0, y1, INT, r, [_porta("x", 5.0, INT, 55.0, 56.2, B, "simples", -1.0), _porta("x", 5.0, INT, 65.5, 66.5, B, "simples", -1.0)])
	_parede("x", 7.5, 49.875, 70.125, y0, y1, INT, M["reboco_tijolo"], [_porta("x", 7.5, INT, 54.5, 55.5, B, "blindada"), _porta("x", 7.5, INT, 64.0, 65.0, B, "simples", 1.0)])
	_parede("z", 62.0, -2.0, 5.0, y0, y1, INT, r, [[0.0, 1.6, B + 0.9, B + 1.9]])
	_parede("z", 60.0, 7.5, 12.0, y0, y1, INT, r)
	_parede("z", 70.0, -2.0, 12.0, y0, y1, INT, r, [_porta("z", 70.0, INT, 5.25, 7.25, B, "dupla", 1.0), _porta("z", 70.0, INT, 9.2, 10.2, B, "simples", 1.0)])


# ================================================================ 1º andar

func _build_primeiro(_parent: Node3D) -> void:
	var r: Material = M["reboco"]
	var y0 := LAJE
	var y1 := TETO1
	# Ala oeste: quarto do telhado desabado, dormitórios 1–4, rouparia, banheiro.
	_parede("z", 10.0, -2.0, 12.0, y0, y1, INT, M["reboco_tijolo"], [_porta("z", 10.0, INT, 5.3, 7.2, F1, "pregada")])
	var dv: Array = []
	for x in [10.0, 15.0, 20.0, 25.0]:
		dv.append(_porta("x", 5.0, INT, x + 3.4, x + 4.35, F1, "simples", -1.0))
	_parede("x", 5.0, 9.875, 30.125, y0, y1, INT, r, dv)
	_parede("x", 7.5, 9.875, 30.125, y0, y1, INT, r, [_porta("x", 7.5, INT, 14.2, 15.2, F1, "simples", 1.0), _porta("x", 7.5, INT, 27.6, 28.6, F1, "simples", 1.0)])
	for x in [15.0, 20.0, 25.0]:
		_parede("z", x, -2.0, 5.0, y0, y1, INT, r)
	_parede("z", 22.0, 7.5, 12.0, y0, y1, INT, r)
	_parede("z", 30.0, -2.0, 12.0, y0, y1, INT, r, [_porta("z", 30.0, INT, 5.2, 7.3, F1, "arco")])
	# Galeria | biblioteca.
	_parede("x", 4.0, 29.875, 50.125, y0, y1, INT, r, [_porta("x", 4.0, INT, 38.5, 41.5, F1, "dupla", -1.0)])
	# Ala leste: dormitórios 5–8, banheiro, sala de jogos, convivência.
	_parede("z", 50.0, -2.0, 12.0, y0, y1, INT, r, [_porta("z", 50.0, INT, 5.2, 7.3, F1, "arco")])
	dv = []
	for x in [50.0, 55.0, 60.0, 65.0]:
		dv.append(_porta("x", 5.0, INT, x + 3.4, x + 4.35, F1, "simples", -1.0))
	_parede("x", 5.0, 49.875, 70.125, y0, y1, INT, r, dv)
	_parede("x", 7.5, 49.875, 70.125, y0, y1, INT, r, [_porta("x", 7.5, INT, 51.4, 52.4, F1, "simples", 1.0), _porta("x", 7.5, INT, 63.2, 64.2, F1, "simples", 1.0)])
	for x in [55.0, 60.0, 65.0]:
		_parede("z", x, -2.0, 5.0, y0, y1, INT, r)
	_parede("z", 58.0, 7.5, 12.0, y0, y1, INT, r)
	_parede("z", 70.0, -2.0, 12.0, y0, y1, INT, r, [_porta("z", 70.0, INT, 5.25, 7.25, F1, "dupla", 1.0)])


# ================================================================ pisos e lajes

## [x0, z0, x1, z1, piso] pelos eixos das paredes (a peça é aparada pelo miolo).
const PISOS_T := [
	[0, -2, 10, 12, "p_azulejo"],      # enfermaria
	[10, -2, 30, 5, "p_ginasio"],     # treino
	[10, 5, 30, 7.5, "p_corredor"],
	[10, 7.5, 20, 12, "p_azulejo"],  # vestiário
	[20, 7.5, 30, 12, "p_cimento"],  # trancada: escombros
	[30, -5, 33, 4, "p_azulejo"],      # arquivo
	[33, -5, 47, 4, "p_taco"],         # missões
	[47, -5, 50, 4, "p_azulejo"],      # lavabo
	[30, 4, 50, 22, "p_saguao"],
	[50, -2, 62, 5, "p_tabua"],       # refeitório
	[62, -2, 70, 5, "p_azulejo"],     # cozinha
	[50, 5, 70, 7.5, "p_corredor"],
	[50, 7.5, 60, 12, "p_lab"],      # laboratório (a trancada alagada)
	[60, 7.5, 70, 12, "p_cimento"],  # depósito
	[70, -2, 80, 12, "p_cimento"],     # oficina
]
const PISOS_1 := [
	[0, -2, 10, 12, "p_cimento"],      # trancada: telhado desabado
	[10, -2, 30, 5, "p_taco"],        # dormitórios 1–4
	[10, 5, 30, 7.5, "p_corredor"],
	[10, 7.5, 22, 12, "p_azulejo"],  # rouparia
	[22, 7.5, 30, 12, "p_azulejo"],  # banheiro oeste
	[30, -5, 50, 4, "p_tabua"],        # biblioteca
	[30, 4, 50, 8, "p_corredor"],    # galeria
	[50, -2, 70, 5, "p_taco"],        # dormitórios 5–8
	[50, 5, 70, 7.5, "p_corredor"],
	[50, 7.5, 58, 12, "p_azulejo"],  # banheiro leste
	[58, 7.5, 70, 12, "p_ginasio"],  # sala de jogos
	[70, -2, 80, 12, "p_tabua"],       # convivência
]


func _build_lajes(parent: Node3D) -> void:
	for p in PISOS_T:
		var r := Rect2(p[0], p[1], p[2] - p[0], p[3] - p[1])
		Obra.laje(parent, _no_miolo(r), [], 0.0, B, M[p[4]])
	for p in PISOS_1:
		var r := Rect2(p[0], p[1], p[2] - p[0], p[3] - p[1])
		Obra.laje(parent, _no_miolo(r), [VAZIO], LAJE, F1, M[p[4]])
	# Laje entre os andares (o fundo é o teto do térreo) e a cobertura.
	Obra.laje(parent, MIOLO, [VAZIO], TETO0, LAJE, M["teto"])
	Obra.laje(parent, MIOLO, [DESABADO], TETO1, TOPO, M["teto"])


func _no_miolo(r: Rect2) -> Array:
	var out: Array = []
	for m in MIOLO:
		var i := r.intersection(m)
		if i.size.x > 0.001 and i.size.y > 0.001:
			out.append(i)
	return out


# ================================================================ telhados

func _build_telhados(parent: Node3D) -> void:
	var ard: Material = M["ardosia"]
	Obra.telhado(parent, Rect2(29.2, -5.8, 21.6, 28.6), TOPO, 4.6, ard)
	Obra.telhado(parent, Rect2(69.4, -2.6, 11.2, 15.2), TOPO, 3.4, ard)
	# Ponta oeste: o telhado desabou. Sobram as vigas, algumas caídas.
	var viga: Material = M["madeira_escura"]
	for i in 5:
		var z := -1.0 + i * 3.0
		var caida := i == 1 or i == 3
		var rot := Vector3(0, 0, -18.0 if caida else 0.0)
		var y := TOPO + (0.2 if not caida else -1.6)
		Look.piece(parent, Look.box(Vector3(11.0, 0.25, 0.3)), viga, Vector3(5.0, y, z), rot)
	Obra.caixa(parent, Vector3(6.0, F1 + 0.5, 3.2), Vector3(5.5, 0.3, 0.35), viga, true, Vector3(0, 30, 14))
	Obra.caixa(parent, Vector3(3.5, F1 + 0.3, 8.0), Vector3(4.5, 0.3, 0.35), viga, true, Vector3(0, -50, 8))
	# Chaminés.
	for p in [Vector3(33.5, 0, 1.0), Vector3(46.5, 0, 1.0), Vector3(74.5, 0, 1.5), Vector3(3.0, 0, 10.0)]:
		Obra.caixa(parent, Vector3(p.x, TOPO + 3.0, p.z), Vector3(1.2, 6.0, 1.2), M["tijolo"])


# ================================================================ pórtico

## Pórtico de entrada: embasamento, escadaria, 4 colunas altas e frontão.
func _build_portico(parent: Node3D) -> void:
	var pedra: Material = M["friso"]
	Obra.bloco(parent, Vector3(36, 0, 22.3), Vector3(44, B, 25), M["concreto"])
	for k in 3:
		var h := B * float(3 - k) / 3.0
		Obra.bloco(parent, Vector3(36, 0, 25 + k), Vector3(44, h, 26 + k), M["concreto"], false)
	Obra.rampa(parent, Vector3(40, 0.0, 28.0), Vector3(40, B, 25.0), 8.0)
	var topo := TOPO - 0.6
	for x in [36.8, 38.6, 41.4, 43.2]:
		var col := StaticBody3D.new()
		col.collision_layer = Game.LAYER_WORLD
		var sh := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.32
		cyl.height = topo - B
		sh.shape = cyl
		col.add_child(sh)
		Look.piece(col, Look.cylinder(0.3, 0.34, topo - B, 12), pedra, Vector3.ZERO)
		col.position = Vector3(x, (topo + B) * 0.5, 24.3)
		parent.add_child(col)
	Obra.bloco(parent, Vector3(35.6, topo, 22.3), Vector3(44.4, topo + 0.35, 25.1), pedra)
	var prism := PrismMesh.new()
	prism.size = Vector3(8.8, 2.0, 2.8)
	Look.piece(parent, prism, pedra, Vector3(40, topo + 0.35 + 1.0, 23.7))
	var placa := Label3D.new()
	placa.text = "INTERNATO"
	placa.font_size = 56
	placa.pixel_size = 0.006
	placa.outline_size = 6
	placa.modulate = Color(0.25, 0.22, 0.2)
	placa.position = Vector3(40, topo - 0.4, 25.12)
	parent.add_child(placa)
	# Hera subindo pelas colunas e pela fachada.
	for p in [Vector3(36.8, 2.4, 24.75), Vector3(43.2, 3.4, 24.75), Vector3(31.2, 3.0, 22.5), Vector3(48.6, 2.2, 22.5), Vector3(8.0, 2.6, 12.5), Vector3(56.0, 3.5, 12.5), Vector3(25.0, 2.0, 12.5), Vector3(66.0, 2.8, 12.5), Vector3(14.0, 3.2, -2.5), Vector3(-0.5, 2.4, 5.0)]:
		_hera(parent, p)


## Hera grudada na parede: folhas em montinhos, com colisão fina (é alta).
func _hera(parent: Node3D, c: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var sh := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, c.y * 2.0, 0.3)
	sh.shape = box
	body.add_child(sh)
	body.position = Vector3(c.x, c.y, c.z)
	parent.add_child(body)
	if absf(c.x) < 1.0:
		body.rotation_degrees = Vector3(0, 90, 0)
	var greens := [Look.foliage(Color(0.28, 0.4, 0.19)), Look.foliage(Color(0.36, 0.47, 0.22)), Look.foliage(Color(0.22, 0.33, 0.16))]
	var n := int(c.y * 2.5) + 3
	for i in n:
		var r := rng.randf_range(0.25, 0.5)
		var y := rng.randf_range(-c.y, c.y)
		var w := 0.8 * (1.0 - 0.5 * (y + c.y) / (2.0 * c.y))
		Look.piece(body, Look.blob(r, r * 1.3), greens[i % 3], Vector3(rng.randf_range(-w, w), y, 0.0))


# ================================================================ saguão

func _build_saguao(parent: Node3D) -> void:
	var escura: Material = M["madeira_escura"]
	# Escadas iguais e espelhadas: o pé ao sul (z 15), o topo na galeria (z 8).
	# Entre o pé delas e a parede da frente sobram 7 m de saguão.
	Obra.escada(parent, 30.125, 33.5, 15.0, 8.0, B, F1, escura)
	Obra.escada(parent, 46.5, 49.875, 15.0, 8.0, B, F1, escura)
	# Guarda-corpo da galeria (entre as escadas) e corrimãos das escadas.
	var grade := Look.surface(Color(0.32, 0.2, 0.13), {"outline": 0.02})
	Obra.bloco(parent, Vector3(33.5, F1, 7.85), Vector3(46.5, F1 + 1.0, 8.0), grade)
	for x in [33.5, 46.35]:
		var ang := rad_to_deg(atan2(F1 - B, 7.0))
		Obra.caixa(parent, Vector3(x + 0.075, (B + F1) * 0.5 + 0.95, 11.5), Vector3(0.15, 0.12, 7.9), grade, true, Vector3(ang, 0, 0))
		Obra.caixa(parent, Vector3(x + 0.075, B + 0.5, 14.9), Vector3(0.15, 1.0, 0.15), grade)
	# Seis colunas do pé-direito duplo (o saguão ficou 5 m mais fundo).
	for p in [Vector2(34.2, 8.4), Vector2(45.8, 8.4), Vector2(34.2, 18.0), Vector2(45.8, 18.0), Vector2(34.2, 21.2), Vector2(45.8, 21.2)]:
		var col := StaticBody3D.new()
		col.collision_layer = Game.LAYER_WORLD
		var sh := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = TETO1 - B
		sh.shape = cyl
		col.add_child(sh)
		Look.piece(col, Look.cylinder(0.28, 0.3, TETO1 - B, 10), M["friso"], Vector3.ZERO)
		col.position = Vector3(p.x, (TETO1 + B) * 0.5, p.y)
		parent.add_child(col)
	# Tapete gasto e o lustre caído no centro.
	Obra.bloco(parent, Vector3(37.0, B, 11.5), Vector3(43.0, B + 0.015, 18.5), Look.surface(Color(0.45, 0.2, 0.16), {"variation": 0.4, "noise_scale": 2.0}), false)
	var lustre := Look.surface(Color(0.55, 0.45, 0.28), {"variation": 0.3, "outline": 0.02})
	Obra.caixa(parent, Vector3(40, B + 0.35, 15), Vector3(1.6, 0.7, 1.6), lustre, true, Vector3(0, 25, 12))
	for i in 5:
		var a := TAU * i / 5.0
		Look.piece(parent, Look.blob(0.12), M["vidro"], Vector3(40 + cos(a) * 1.4, B + 0.08, 15 + sin(a) * 1.2))
	# Folhas abertas da entrada (dupla, presas na parede por dentro).
	Obra.bloco(parent, Vector3(38.5, B, 20.3), Vector3(38.55, B + 2.55, 21.7), escura)
	Obra.bloco(parent, Vector3(41.45, B, 20.3), Vector3(41.5, B + 2.55, 21.7), escura)
	# Mato entrando pela porta e luzes.
	for p in [Vector3(36.5, B, 21.0), Vector3(43.6, B, 20.8)]:
		Look.bush(parent, p, 0.9, int(p.x))
	_luz(Vector3(40, TETO1 - 0.6, 12.0), 3.0, 14.0)
	_luz(Vector3(40, TETO1 - 0.6, 19.0), 2.0, 10.0)
	_luz(Vector3(40, TETO0 - 0.4, 6.0), 1.4, 7.0)
	_luz(Vector3(40, F1 + 2.6, 6.0), 1.2, 7.0)
	_placa("SALA DE MISSÕES", Vector3(40, B + 2.85, 4.14), 0.0)
	_placa("BIBLIOTECA", Vector3(40, F1 + 2.65, 4.14), 0.0)
	_hint(Rect2(30.5, 8, 19, 13.5), "O saguão. A Sala de Missões fica no fundo; as escadas levam aos dormitórios.")


func _placa(texto: String, pos: Vector3, yaw: float) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 40
	l.pixel_size = 0.0045
	l.outline_size = 8
	l.modulate = Color(1.0, 0.92, 0.8)
	l.position = pos
	l.rotation_degrees = Vector3(0, yaw, 0)
	add_child(l)


func _luz(pos: Vector3, energy: float = 1.4, alcance: float = 8.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = LAMP
	light.light_energy = energy * _lamp_scale * 0.6
	light.omni_range = alcance
	light.omni_attenuation = 1.4
	light.position = pos
	add_child(light)
	return light


# ================================================================ salas

func _build_salas(parent: Node3D) -> void:
	_build_missoes(parent)
	_build_treino(parent)
	_build_laboratorio(parent)
	var caixote := Look.wood(Color(0.45, 0.34, 0.22))
	# Salas sem função ainda: poucos móveis, entulho e areia.
	# Enfermaria: leitos na parede oeste.
	for i in 4:
		var z := -0.4 + i * 2.6
		Obra.caixa(parent, Vector3(1.6, B + 0.3, z), Vector3(2.0, 0.6, 0.95), M["metal"])
		Obra.bloco(parent, Vector3(0.7, B + 0.6, z - 0.4), Vector3(2.5, B + 0.72, z + 0.4), Look.surface(Color(0.75, 0.73, 0.68), {"variation": 0.3}), false)
	# Refeitório: duas mesas longas.
	for z in [0.5, 3.0]:
		Obra.caixa(parent, Vector3(56, B + 0.38, z), Vector3(9.0, 0.1, 1.1), M["madeira"])
		for sx in [-4.0, 4.0]:
			Obra.caixa(parent, Vector3(56 + sx, B + 0.17, z), Vector3(0.2, 0.33, 0.9), M["madeira"])
	# Cozinha, depósito, oficina, vestiário: caixas e tambores.
	for p in [Vector3(63.5, 0, -0.5), Vector3(68.5, 0, 3.6), Vector3(61.5, 0, 11.0), Vector3(64.0, 0, 10.6), Vector3(68.6, 0, 8.6), Vector3(78.3, 0, -0.2), Vector3(74.0, 0, 10.5), Vector3(11.5, 0, 11.0), Vector3(22.5, 0, 9.2), Vector3(27.0, 0, 11.0)]:
		var s := rng.randf_range(0.8, 1.3)
		Obra.caixa(parent, Vector3(p.x, B + s * 0.5, p.z), Vector3(s, s, s), caixote, true, Vector3(0, rng.randf_range(-20, 20), 0))
	# Entulho da trancada de escombros.
	for i in 4:
		Obra.caixa(parent, Vector3(22.0 + i * 2.0, B + 0.4, 9.8), Vector3(1.6, 0.8, 1.2), M["concreto"], true, Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 60), rng.randf_range(-10, 10)))
	# Luzes das salas do térreo.
	for p in [Vector3(5, 0, 5), Vector3(20, 0, 1.5), Vector3(15, 0, 10), Vector3(56, 0, 1.5), Vector3(66, 0, 1.5), Vector3(65, 0, 10), Vector3(75, 0, 5), Vector3(31.5, 0, -0.5), Vector3(48.5, 0, -0.5)]:
		_luz(Vector3(p.x, TETO0 - 0.35, p.z), 1.0, 7.0)
	for x in [15.0, 25.0, 55.0, 65.0]:
		_luz(Vector3(x, TETO0 - 0.35, 6.25), 0.8, 5.5)
	_placa("ENFERMARIA", Vector3(10.14, B + 2.7, 6.25), 90.0)
	_placa("OFICINA", Vector3(69.86, B + 2.7, 6.25), -90.0)
	_placa("TREINO", Vector3(19.5, B + 2.5, 5.14), 0.0)
	_placa("REFEITÓRIO", Vector3(55.6, B + 2.5, 5.14), 0.0)
	# Portas pregadas: aviso ao usar F.
	_pregada(Vector3(25.5, B, 6.6), "A porta está pregada. Precisa de muita força para abrir.")
	_pregada(Vector3(11.0, F1, 6.25), "A porta está pregada. Lá dentro o telhado desabou.")
	_hint(Rect2(10.5, 5, 19, 2.5), "Corredor oeste: treino, vestiário e enfermaria.")


## Tábuas pregadas no vão da porta: bloqueiam e explicam.
func _pregada(spot: Vector3, texto: String) -> void:
	var s := HubSpot.new()
	s.position = spot
	s.prompt = "Porta pregada"
	s.text = texto
	add_child(s)


func _fechar_pregadas(parent: Node3D) -> void:
	# Térreo: escombros (x 25–26, z 12,5). 1º andar: telhado (x 10, z 10,3–12,2).
	Obra.bloco(parent, Vector3(25.0, B, 7.45), Vector3(26.0, B + 2.2, 7.55), M["madeira"])
	Obra.bloco(parent, Vector3(9.95, F1, 5.3), Vector3(10.05, F1 + 2.2, 7.2), M["madeira"])
	for k in 3:
		Look.piece(parent, Look.box(Vector3(1.4, 0.16, 0.04)), M["madeira_escura"], Vector3(25.5, B + 0.5 + k * 0.6, 7.36), Vector3(0, 0, 20 - k * 20))
		Look.piece(parent, Look.box(Vector3(0.04, 0.16, 2.3)), M["madeira_escura"], Vector3(10.16, F1 + 0.5 + k * 0.6, 6.25), Vector3(20 - k * 20, 0, 0))


## Sala de missões: a mesa do mapa no centro, mural ao norte, PCs e rádio.
func _build_missoes(parent: Node3D) -> void:
	_fechar_pregadas(parent)
	_build_mesa(Vector3(40, B, -0.6))
	var cork := Look.surface(Color(0.55, 0.38, 0.22), {"variation": 0.35, "noise_scale": 6.0, "outline": 0.02})
	Obra.bloco(parent, Vector3(37.5, B + 1.0, -4.7), Vector3(42.5, B + 2.8, -4.62), cork)
	for i in 7:
		Look.piece(parent, Look.box(Vector3(0.36, 0.26, 0.02)), Look.surface(Color(0.92, 0.88, 0.78)), Vector3(38.0 + i * 0.66, B + 1.4 + fmod(i * 0.37, 0.8), -4.6), Vector3(0, 0, (i % 3 - 1) * 6.0))
	for i in 3:
		Obra.caixa(parent, Vector3(33.8, B + 0.4, -3.0 + i * 1.4), Vector3(1.0, 0.8, 1.1), M["metal"])
		Look.piece(parent, Look.box(Vector3(0.1, 0.45, 0.6)), Look.glow(Color(0.3, 0.9, 0.6), 0.8), Vector3(34.0, B + 1.1, -3.0 + i * 1.4))
	Obra.caixa(parent, Vector3(46.2, B + 0.5, 1.6), Vector3(1.0, 1.0, 1.4), M["chapa"])
	Look.piece(parent, Look.blob(0.06), Look.glow(Color(1.0, 0.3, 0.2), 2.0), Vector3(46.2, B + 1.06, 1.4))
	Look.piece(parent, Look.box(Vector3(1.6, 1.0, 0.04)), Look.surface(Color(0.12, 0.25, 0.45), {"variation": 0.3}), Vector3(44.5, B + 2.0, -4.66))
	_mapa.lamp = _lamp(Vector3(40, TETO0 - 0.9, -0.6), 1.2)
	_hint(Rect2(33.5, -4.5, 13, 8), "Sala de Missões. Use F na mesa para escolher a missão.")


func _lamp(pos: Vector3, energy: float = 1.6) -> OmniLight3D:
	var light := _luz(pos, energy, 8.0)
	Look.piece(self, Look.cylinder(0.05, 0.3, 0.25, 6), Look.glow(LAMP, 2.0), pos + Vector3(0, 0.15, 0))
	Look.piece(self, Look.box(Vector3(0.02, TETO0 - pos.y - 0.27, 0.02)), M["escuro"], Vector3(pos.x, (TETO0 + pos.y + 0.27) * 0.5, pos.z))
	return light


## Mesa com o mapa aberto e alfinetes das instalações.
func _build_mesa(top: Vector3) -> void:
	var wood := Look.wood(Color(0.35, 0.22, 0.14))
	Obra.caixa(self, top + Vector3(0, 0.45, 0), Vector3(3.6, 0.12, 2.2), wood)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Look.piece(self, Look.box(Vector3(0.14, 0.39, 0.14)), wood, top + Vector3(1.6 * sx, 0.195, 0.9 * sz))
	var paper := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.0, 1.8)
	paper.mesh = pm
	paper.material_override = Look.paper()
	paper.position = top + Vector3(0, 0.52, 0)
	paper.rotation_degrees = Vector3(0, 3, 0)
	add_child(paper)
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
	for sx in [-1.0, 1.0]:
		Obra.caixa(self, top + Vector3(2.4 * sx, 0.25, 0.3), Vector3(0.6, 0.5, 0.6), wood)


## Clicou num alfinete jogável: abre o cartão da missão por cima do mapa e,
## quando o cartão fecha com Esc, volta para o mapa.
func _on_mission_chosen(_id: String) -> void:
	mission_requested.emit()
	for c in get_parent().get_children():
		if c is MissionCard and not c.is_queued_for_deletion():
			(c as MissionCard).closed.connect(_mapa.back_from_card)


## Sala de treinamento: tatame, bonecos e caixas para treinar o pulo.
func _build_treino(parent: Node3D) -> void:
	Obra.bloco(parent, Vector3(11.0, B, -1.2), Vector3(19.0, B + 0.06, 4.2), Look.surface(Color(0.2, 0.32, 0.5), {"variation": 0.25, "noise_scale": 2.0}), false)
	var boneco := Look.surface(Color(0.6, 0.5, 0.35), {"variation": 0.3, "outline": 0.03})
	for p in [Vector3(22.5, 0, 0.0), Vector3(24.5, 0, 0.0), Vector3(26.5, 0, 0.0)]:
		Obra.caixa(parent, Vector3(p.x, B + 0.9, p.z), Vector3(0.45, 1.8, 0.45), boneco)
	var crate := Look.wood(Color(0.45, 0.34, 0.22))
	Obra.caixa(parent, Vector3(27.5, B + 0.5, 3.6), Vector3(1.6, 1.0, 1.6), crate)
	Obra.caixa(parent, Vector3(27.5, B + 1.0, 1.6), Vector3(1.6, 2.0, 1.6), crate)
	var tatame := HubSpot.new()
	tatame.position = Vector3(15.0, B, 1.5)
	tatame.prompt = "Treinar"
	tatame.text = "Tatame: aqui o grupo vai treinar os poderes (em breve)."
	add_child(tatame)


## Laboratório (a antiga sala alagada): porta blindada que o Feixe corta.
func _build_laboratorio(parent: Node3D) -> void:
	var open: bool = Game.progress.get("lab_open", false)
	var agua := Look.surface(Color(0.15, 0.3, 0.32), {"variation": 0.2, "noise_scale": 1.5})
	Obra.bloco(parent, Vector3(50.6, B, 9.0), Vector3(56.5, B + 0.03, 11.5), agua, false)
	for x in [52.5, 57.5]:
		Obra.caixa(parent, Vector3(x, B + 0.5, 10.9), Vector3(3.0, 1.0, 1.1), M["chapa"])
	if open:
		_open_lab()
	else:
		_lab_door = Door.new()
		_lab_door.name = "PortaLaboratorio"
		_lab_door.blast_door = true
		_lab_door.position = Vector3(55.0, B, 7.5)
		add_child(_lab_door)
		_lab_door.setup(Vector3(1.0, 2.3, 0.32), Color(0.55, 0.6, 0.65))
		_lab_door.opened_door.connect(_on_lab_opened)
		if Game.progress.get("feixe", false):
			_hint(Rect2(53, 5, 4, 2.5), "A porta blindada do laboratório. Troque para o Feixe e segure Q para cortar.")
		else:
			_hint(Rect2(53, 5, 4, 2.5), "Porta blindada do laboratório. Alguém que corte aço poderia abrir.")
	_placa("LABORATÓRIO", Vector3(55.0, B + 2.6, 7.36), 180.0)


func _open_lab() -> void:
	_luz(Vector3(55, TETO0 - 0.4, 9.8), 1.4, 7.0)
	var bancada := HubSpot.new()
	bancada.position = Vector3(55.0, B, 9.6)
	bancada.prompt = "Usar a bancada"
	bancada.text = "Bancada do laboratório: aqui o grupo vai fabricar equipamentos com peças do Protocolo (em breve)."
	add_child(bancada)


func _on_lab_opened() -> void:
	Game.progress["lab_open"] = true
	_open_lab()
	Game.message("O Feixe cortou a porta! O laboratório está aberto.", 4.0)


# ================================================================ 1º andar: móveis

func _build_dormitorios(parent: Node3D) -> void:
	var donos := ["Fênix", "Feixe" if Game.progress.get("feixe", false) else "", "", "", "", "", "", ""]
	var xs := [10.0, 15.0, 20.0, 25.0, 50.0, 55.0, 60.0, 65.0]
	var lencol := [Color(0.25, 0.45, 0.8), Color(0.75, 0.3, 0.2), Color(0.5, 0.5, 0.48)]
	for i in 8:
		var x0: float = xs[i]
		var dono: String = donos[i]
		var cor: Color = lencol[0] if i == 0 else (lencol[1] if dono != "" else lencol[2])
		Obra.caixa(parent, Vector3(x0 + 1.2, F1 + 0.25, 0.0), Vector3(1.0, 0.5, 2.0), M["madeira"])
		Obra.bloco(parent, Vector3(x0 + 0.75, F1 + 0.5, -0.9), Vector3(x0 + 1.65, F1 + 0.62, 0.9), Look.surface(cor, {"variation": 0.3}), false)
		Obra.caixa(parent, Vector3(x0 + 4.0, F1 + 0.9, -1.25), Vector3(1.2, 1.8, 0.6), M["madeira_escura"])
		if dono != "":
			_luz(Vector3(x0 + 2.5, TETO1 - 0.4, 1.5), 0.9, 5.0)
			var cama := HubSpot.new()
			cama.position = Vector3(x0 + 2.4, F1, 0.0)
			cama.prompt = "Cama do " + dono
			cama.text = "Quarto do %s. Aqui o grupo vai descansar e salvar o jogo (em breve)." % dono
			add_child(cama)
		_placa("DORM. %d%s" % [i + 1, (" · " + dono.to_upper()) if dono != "" else ""], Vector3(x0 + 3.9, F1 + 2.45, 5.14), 0.0)
	# Biblioteca: estantes nas paredes e duas mesas de leitura.
	for i in 4:
		Obra.caixa(parent, Vector3(33.0 + i * 4.6, F1 + 1.1, -0.5), Vector3(0.5, 2.2, 3.0), M["madeira_escura"])
	for x in [37.5, 42.5]:
		Obra.caixa(parent, Vector3(x, F1 + 0.38, 2.2), Vector3(2.4, 0.08, 1.0), M["madeira"])
	# Convivência e jogos: sofás e mesa de sinuca. Rouparia e banheiros: pouco.
	var sofa := Look.surface(Color(0.32, 0.22, 0.42), {"variation": 0.3, "outline": 0.02})
	Obra.caixa(parent, Vector3(75, F1 + 0.35, 0.0), Vector3(4.0, 0.7, 0.9), sofa)
	Obra.caixa(parent, Vector3(72.5, F1 + 0.35, 3.0), Vector3(0.9, 0.7, 3.0), sofa)
	Obra.caixa(parent, Vector3(63.5, F1 + 0.4, 10.0), Vector3(2.4, 0.8, 1.3), Look.surface(Color(0.12, 0.35, 0.2), {"variation": 0.2, "outline": 0.02}))
	for p in [Vector3(25, 0, 11), Vector3(53, 0, 11)]:
		Obra.caixa(parent, Vector3(p.x, F1 + 0.45, p.z), Vector3(2.4, 0.9, 0.6), Look.surface(Color(0.82, 0.8, 0.74), {"variation": 0.2}))
	# Luzes do 1º andar.
	for p in [Vector3(40, 0, -0.5), Vector3(75, 0, 5), Vector3(64, 0, 9.8), Vector3(16, 0, 9.8), Vector3(26, 0, 9.8), Vector3(54, 0, 9.8)]:
		_luz(Vector3(p.x, TETO1 - 0.4, p.z), 1.0, 7.0)
	for x in [15.0, 25.0, 55.0, 65.0]:
		_luz(Vector3(x, TETO1 - 0.4, 6.25), 0.8, 5.5)
	_hint(Rect2(30.5, 4.2, 19, 3.6), "A galeria. Dormitórios nas duas alas; a biblioteca fica atrás.")


# ================================================================ garagem

func _build_garagem() -> void:
	var g := Node3D.new()
	g.name = "Garagem"
	add_child(g)
	var t: Material = M["tijolo"]
	var h := 4.6
	Obra.bloco(g, Vector3(96.15, -0.1, -2.85), Vector3(111.85, 0.045, 8.85), M["p_cimento"], false)
	_parede("x", -3.0, 95.85, 112.15, 0.0, h, 0.15, t, [])
	_parede("x", 9.0, 95.85, 112.15, 0.0, h, 0.15, t, [[98.0, 110.0, 0.0, 3.6]])
	_parede("z", 96.0, -3.0, 9.0, 0.0, h, 0.15, t, [[1.0, 2.4, 0.0, 2.2]])
	_parede("z", 112.0, -3.0, 9.0, 0.0, h, 0.15, t, [])
	_levantar_paredes(g)
	Obra.bloco(g, Vector3(95.6, h, -3.4), Vector3(112.4, h + 0.25, 9.4), M["chapa"])
	# Portão basculante aberto (preso no teto) e bancada.
	Obra.bloco(g, Vector3(98.1, 3.6, 6.6), Vector3(109.9, 3.7, 8.85), M["metal"])
	Obra.caixa(g, Vector3(104, 0.5, -2.2), Vector3(5.0, 1.0, 1.2), M["madeira"])
	_luz(Vector3(104, h - 0.5, 3.0), 1.2, 9.0)
	# Furgão da equipe estacionado na frente, virado para o sul.
	var furgao := Node3D.new()
	furgao.position = Vector3(103.05, 0, 13.0)
	g.add_child(furgao)
	var lata := Look.surface(Color(0.85, 0.82, 0.74), {"variation": 0.25, "noise_scale": 2.0, "outline": 0.03})
	Obra.caixa(furgao, Vector3(0, 1.3, -0.5), Vector3(2.3, 1.9, 4.2), lata)
	Obra.caixa(furgao, Vector3(0, 1.0, 2.15), Vector3(2.3, 1.3, 1.1), lata)
	Obra.bloco(furgao, Vector3(-1.0, 1.3, 2.71), Vector3(1.0, 1.6, 2.73), M["vidro"], false)
	for p in [Vector3(-1.15, 0.38, 1.6), Vector3(1.15, 0.38, 1.6), Vector3(-1.15, 0.38, -1.8), Vector3(1.15, 0.38, -1.8)]:
		Look.piece(furgao, Look.cylinder(0.38, 0.38, 0.3, 10), M["escuro"], p, Vector3(0, 0, 90))
	var van := HubSpot.new()
	van.position = Vector3(103.0, 0, 16.6)
	van.prompt = "Furgão da equipe"
	van.text = "O furgão da equipe. Escolha a missão na mesa do mapa, na Sala de Missões."
	add_child(van)


# ================================================================ areia

## Areia acumulada nos cantos e encostada nas paredes (montes baixos).
func _build_areia(parent: Node3D) -> void:
	var montes := [
		Vector3(30.8, B, 21.2), Vector3(49.2, B, 21.0), Vector3(36.0, B, 21.4), Vector3(44.2, B, 21.4),
		Vector3(0.9, B, 11.2), Vector3(9.4, B, -1.1), Vector3(29.4, B, 11.2), Vector3(50.8, B, 11.3),
		Vector3(79.2, B, -1.2), Vector3(69.4, B, 11.3), Vector3(10.6, B, 6.9), Vector3(69.4, B, 5.6),
		Vector3(0.8, F1, -1.0), Vector3(9.3, F1, 11.2), Vector3(5.0, F1, 4.5),
		Vector3(35.6, 0, 22.6), Vector3(44.4, 0, 22.6), Vector3(30.0, 0, 22.8), Vector3(50.0, 0, 22.9),
		Vector3(12.0, 0, 12.6), Vector3(60.0, 0, 12.7), Vector3(70.5, 0, -2.6),
	]
	for p in montes:
		var r := rng.randf_range(0.8, 1.5)
		var mi := Look.piece(parent, Look.blob(r, r * 0.5), M["areia"], p + Vector3(0, -r * 0.06, 0), Vector3(0, rng.randf_range(0, 90), 0))
		mi.scale = Vector3(1.0, 0.45, rng.randf_range(0.6, 1.0))


# ================================================================ luz

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
			e.ambient_light_energy = 0.4
			e.glow_intensity = 0.9
			e.adjustment_enabled = true
			e.adjustment_saturation = 1.2
			e.adjustment_contrast = 1.08
			sun.rotation_degrees = Vector3(-55, 30, 0)
			sun.light_color = Color(0.55, 0.72, 1.0)
			sun.light_energy = 0.4
			_lamp_scale = 1.3
		"musgo":
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
		return "Entre na escola e use a mesa do mapa, na Sala de Missões"
	if not Game.progress.get("lab_open", false):
		return "Leve o Feixe ao laboratório (corredor leste) e corte a porta blindada (Q)"
	return "Escola: %d de %d mutantes · a mesa do mapa leva a uma nova missão" % [rescued_count(), ROOM_COUNT]


func _physics_process(_delta: float) -> void:
	var party := Game.party
	if party == null or party.controlled_hero == null:
		return
	_update_hints(party.controlled_hero.global_position)
