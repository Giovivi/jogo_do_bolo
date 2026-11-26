extends SceneTree
## Checagem das regras de parede do hub e da fase (prancha reforma-hub-diagnostico-v1).
## Monta a escola e acusa:
##   - faces de caixas no mesmo plano, viradas para o mesmo lado e sobrepostas
##     (z-fighting: as texturas "piscam");
##   - caixas visíveis e altas (mais de 1,5 m) sem colisão (a câmera entraria).
## Uso: godot --headless -s res://tools/checa_hub.gd            (hub)
##      godot --headless -s res://tools/checa_hub.gd -- fase    (fase 1)
## Sai com erro se achar algo.

const TOL := 0.004
const MIN_AREA := 0.01

var _frames := 0
var _main: Node


func _initialize() -> void:
	MainMenu.shown = true
	if "fase" in OS.get_cmdline_user_args():
		root.get_node("Game").mode = "fase"
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var level: Node = _main.get("level")
	var caixas: Array = []
	var sem_colisao: Array = []
	_coleta(level, caixas, sem_colisao)
	var grade := {}
	for i in caixas.size():
		var ab: AABB = caixas[i][1]
		for gx in range(int(floor(ab.position.x / 4.0)), int(floor(ab.end.x / 4.0)) + 1):
			for gz in range(int(floor(ab.position.z / 4.0)), int(floor(ab.end.z / 4.0)) + 1):
				var k := Vector2i(gx, gz)
				if not grade.has(k):
					grade[k] = []
				grade[k].append(i)
	var vistos := {}
	var achados: Array = []
	for k in grade:
		var lst: Array = grade[k]
		for ai in lst.size():
			for bi in range(ai + 1, lst.size()):
				var a: int = lst[ai]
				var b: int = lst[bi]
				var par := Vector2i(mini(a, b), maxi(a, b))
				if vistos.has(par):
					continue
				vistos[par] = true
				var area := _sobreposicao(caixas[a][1], caixas[b][1], caixas)
				if area > MIN_AREA:
					achados.append("%.2f m²  %s  <->  %s" % [area, caixas[a][0], caixas[b][0]])
	print("Caixas visíveis: %d" % caixas.size())
	print("Faces sobrepostas (z-fighting): %d" % achados.size())
	for s in achados:
		print("  ", s)
	print("Caixas altas sem colisão: %d" % sem_colisao.size())
	for s in sem_colisao:
		print("  ", s)
	quit(1 if achados.size() + sem_colisao.size() > 0 else 0)
	return true


## Área de faces coplanares, viradas para o mesmo lado, que se sobrepõem.
## Não conta faces escondidas: abaixo do chão ou encostadas em outra caixa.
func _sobreposicao(A: AABB, B: AABB, todas: Array) -> float:
	var total := 0.0
	for ax in 3:
		for lado in 2:
			var fa: float = A.end[ax] if lado == 1 else A.position[ax]
			var fb: float = B.end[ax] if lado == 1 else B.position[ax]
			if absf(fa - fb) > TOL:
				continue
			var o := 1.0
			var centro := Vector3.ZERO
			for k in 3:
				if k == ax:
					continue
				var lo := maxf(A.position[k], B.position[k])
				var hi := minf(A.end[k], B.end[k])
				o *= maxf(0.0, hi - lo)
				centro[k] = (lo + hi) * 0.5
			if o <= 0.0:
				continue
			centro[ax] = fa + (0.003 if lado == 1 else -0.003)
			if centro.y < 0.0 or _dentro(centro, todas):
				continue
			total += o
	return total


func _dentro(p: Vector3, todas: Array) -> bool:
	for c in todas:
		var ab: AABB = c[1]
		if p.x > ab.position.x and p.x < ab.end.x and p.y > ab.position.y and p.y < ab.end.y and p.z > ab.position.z and p.z < ab.end.z:
			return true
	return false


func _coleta(n: Node, caixas: Array, sem_colisao: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree() and (n as MeshInstance3D).mesh is BoxMesh:
		var mi := n as MeshInstance3D
		var r := mi.global_rotation_degrees
		var reto := absf(fmod(r.x, 90.0)) < 0.01 and absf(fmod(r.y, 90.0)) < 0.01 and absf(fmod(r.z, 90.0)) < 0.01
		if reto:
			var ab := mi.global_transform * mi.get_aabb()
			var nome := "%s %s" % [mi.get_parent().name, _txt(ab)]
			caixas.append([nome, ab])
			if ab.size.y > 1.5 and not (mi.get_parent() is StaticBody3D) and not mi.get_parent().has_meta("so_desenho"):
				sem_colisao.append(nome)
	for c in n.get_children():
		_coleta(c, caixas, sem_colisao)


func _txt(ab: AABB) -> String:
	return "[x %.2f–%.2f, y %.2f–%.2f, z %.2f–%.2f]" % [ab.position.x, ab.end.x, ab.position.y, ab.end.y, ab.position.z, ab.end.z]
