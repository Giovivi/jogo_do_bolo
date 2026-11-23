class_name Obra
extends RefCounted
## Kit de construção do hub no padrão novo (prancha reforma-hub-v1):
##   1. Uma parede = uma peça: o desenho e a colisão têm o mesmo tamanho.
##   2. Portas e janelas são vãos recortados na própria peça. Nada é empilhado
##      por cima de outra peça, então não há faces no mesmo plano (z-fighting).
##   3. Tudo o que é visível e alto colide (camada do mundo): a câmera desvia
##      de paredes, lajes e tetos e nunca entra neles.
## Coordenadas em metros: x = leste, z = sul, y = altura.


## Divide o retângulo "r" menos os buracos em retângulos que não se sobrepõem.
## Serve para paredes (u ao longo da parede, v = altura) e lajes (x, z).
static func retangulos(r: Rect2, holes: Array) -> Array[Rect2]:
	var xs: Array[float] = [r.position.x, r.end.x]
	var ys: Array[float] = [r.position.y, r.end.y]
	var hs: Array[Rect2] = []
	for h0 in holes:
		var h: Rect2 = (h0 as Rect2).intersection(r)
		if h.size.x <= 0.001 or h.size.y <= 0.001:
			continue
		hs.append(h)
		xs.append(h.position.x)
		xs.append(h.end.x)
		ys.append(h.position.y)
		ys.append(h.end.y)
	xs = _unicos(xs)
	ys = _unicos(ys)
	var nx := xs.size() - 1
	var ny := ys.size() - 1
	var solid := PackedByteArray()
	solid.resize(nx * ny)
	for j in ny:
		for i in nx:
			var c := Vector2((xs[i] + xs[i + 1]) * 0.5, (ys[j] + ys[j + 1]) * 0.5)
			var v := 1
			for h in hs:
				if h.has_point(c):
					v = 0
					break
			solid[j * nx + i] = v
	var out: Array[Rect2] = []
	for j in ny:
		for i in nx:
			if solid[j * nx + i] != 1:
				continue
			var i2 := i
			while i2 + 1 < nx and solid[j * nx + i2 + 1] == 1:
				i2 += 1
			var j2 := j
			var ok := true
			while ok and j2 + 1 < ny:
				for k in range(i, i2 + 1):
					if solid[(j2 + 1) * nx + k] != 1:
						ok = false
						break
				if ok:
					j2 += 1
			for jj in range(j, j2 + 1):
				for k in range(i, i2 + 1):
					solid[jj * nx + k] = 2
			out.append(Rect2(xs[i], ys[j], xs[i2 + 1] - xs[i], ys[j2 + 1] - ys[j]))
	return out


static func _unicos(v: Array[float]) -> Array[float]:
	v.sort()
	var out: Array[float] = []
	for x in v:
		if out.is_empty() or x - out[-1] > 0.0005:
			out.append(x)
	return out


## Caixa com desenho e colisão do mesmo tamanho (solid = false: só desenho,
## para peças baixas ou finas que não precisam bloquear nada).
static func caixa(parent: Node3D, center: Vector3, size: Vector3, mat: Material, solid: bool = true, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
	if not solid:
		return Look.piece(parent, Look.box(size), mat, center, rot_deg)
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
	parent.add_child(body)
	return body


## Caixa dada pelos cantos.
static func bloco(parent: Node3D, a: Vector3, b: Vector3, mat: Material, solid: bool = true) -> Node3D:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return caixa(parent, (lo + hi) * 0.5, hi - lo, mat, solid)


## Parede reta. axis "x": corre ao longo de x, centrada em z = fixo.
## axis "z": corre ao longo de z, centrada em x = fixo.
## camadas: [[de, até, material], ...] na espessura, medida a partir do eixo
## (negativo = lado -z ou -x). vaos: [[u0, u1, v0, v1], ...] com u ao longo
## da parede (coordenada do mundo) e v = altura do mundo.
static func parede(parent: Node3D, axis: String, fixo: float, a0: float, a1: float, y0: float, y1: float, camadas: Array, vaos: Array = []) -> void:
	var holes: Array = []
	for v in vaos:
		holes.append(Rect2(v[0], v[2], v[1] - v[0], v[3] - v[2]))
	var rects := retangulos(Rect2(a0, y0, a1 - a0, y1 - y0), holes)
	for c in camadas:
		var o0: float = c[0]
		var o1: float = c[1]
		var mat: Material = c[2]
		for r in rects:
			if axis == "x":
				bloco(parent, Vector3(r.position.x, r.position.y, fixo + o0), Vector3(r.end.x, r.end.y, fixo + o1), mat)
			else:
				bloco(parent, Vector3(fixo + o0, r.position.y, r.position.x), Vector3(fixo + o1, r.end.y, r.end.x), mat)


## Laje: a área (x, z) menos os buracos, de y0 a y1, em peças que não se sobrepõem.
static func laje(parent: Node3D, areas: Array, holes: Array, y0: float, y1: float, mat: Material, solid: bool = true) -> void:
	for a in areas:
		for r in retangulos(a, holes):
			bloco(parent, Vector3(r.position.x, y0, r.position.y), Vector3(r.end.x, y1, r.end.y), mat, solid)


## Telhado de quatro águas sobre o retângulo (x, z), com a cumeeira no lado
## mais comprido. Desenhado dos dois lados (o beiral aparece por baixo) e
## com colisão do mesmo formato.
static func telhado(parent: Node3D, r: Rect2, base_y: float, altura: float, mat: Material) -> StaticBody3D:
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var top := base_y + altura
	var tris: Array = []
	var c00 := Vector3(x0, base_y, z0)
	var c10 := Vector3(x1, base_y, z0)
	var c11 := Vector3(x1, base_y, z1)
	var c01 := Vector3(x0, base_y, z1)
	if r.size.x >= r.size.y:
		var h := r.size.y * 0.5
		var ra := Vector3(x0 + h, top, (z0 + z1) * 0.5)
		var rb := Vector3(x1 - h, top, (z0 + z1) * 0.5)
		tris = [[c00, c10, rb], [c00, rb, ra], [c11, c01, ra], [c11, ra, rb], [c01, c00, ra], [c10, c11, rb]]
	else:
		var h := r.size.x * 0.5
		var ra := Vector3((x0 + x1) * 0.5, top, z0 + h)
		var rb := Vector3((x0 + x1) * 0.5, top, z1 - h)
		tris = [[c10, c11, rb], [c10, rb, ra], [c01, c00, ra], [c01, ra, rb], [c00, c10, ra], [c11, c01, rb]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for t in tris:
		_tri_dupla(st, t[0], t[1], t[2], Vector3(0, top + 1.0, (z0 + z1) * 0.5))
		faces.append(t[0])
		faces.append(t[1])
		faces.append(t[2])
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cps := ConcavePolygonShape3D.new()
	cps.backface_collision = true
	cps.set_faces(faces)
	shape.shape = cps
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)
	return body


## Triângulo visível dos dois lados, cada lado com a normal certa.
## (No Godot a face da frente é a de giro horário vista de fora.)
static func _tri_dupla(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, _hint: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.set_normal(-n)
		st.add_vertex(v)
	for v in [a, c, b]:
		st.set_normal(n)
		st.add_vertex(v)


## Rampa: só colisão (a escada desenha os degraus por cima) ou, com
## material, desenho e colisão do mesmo tamanho.
static func rampa(parent: Node3D, from: Vector3, to: Vector3, width: float, mat: Material = null) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.2, from.distance_to(to))
	shape.shape = box
	body.add_child(shape)
	if mat != null:
		Look.piece(body, Look.box(box.size), mat, Vector3.ZERO)
	parent.add_child(body)
	# A face de cima da rampa passa pela linha from -> to.
	var dir := (to - from).normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var up := right.cross(dir).normalized()
	var center := (from + to) * 0.5 - up * 0.1
	body.look_at_from_position(center, center + dir, up)


## Escada reta de "from" (pé, embaixo) a "to" (topo), andando em z.
## Degraus maciços desenhados + rampa invisível para andar.
static func escada(parent: Node3D, x0: float, x1: float, z_pe: float, z_topo: float, y_pe: float, y_topo: float, mat: Material) -> void:
	var n := int(ceil((y_topo - y_pe) / 0.19))
	var h := (y_topo - y_pe) / float(n)
	var d := (z_topo - z_pe) / float(n)
	# Os degraus só desenham: quem anda e segura a câmera é a rampa.
	var degraus := Node3D.new()
	degraus.name = "Degraus"
	degraus.set_meta("so_desenho", true)
	parent.add_child(degraus)
	for k in n:
		var za := z_pe + d * k
		var zb := z_pe + d * (k + 1)
		bloco(degraus, Vector3(x0, y_pe, za), Vector3(x1, y_pe + h * (k + 1), zb), mat, false)
	var xm := (x0 + x1) * 0.5
	rampa(parent, Vector3(xm, y_pe, z_pe), Vector3(xm, y_topo, z_topo), x1 - x0)
