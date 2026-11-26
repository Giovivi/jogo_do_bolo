class_name TempleOverride
extends SkeletonModifier3D
## Mão direita na têmpora, como quem segura a rajada dos óculos (Raio Forte e
## Suprema do Feixe). Gira o braço e o antebraço por cima da animação que
## estiver tocando; `weight` (0 a 1) mistura a pose aos poucos.

## Direções do braço e do antebraço no espaço do esqueleto (o modelo olha
## para +Z): o cotovelo vai para o lado e a mão sobe até a cabeça.
const UPPER_DIR := Vector3(-0.75, -0.15, 0.35)
const FORE_DIR := Vector3(0.55, 0.82, 0.15)

var weight: float = 0.0
var _upper := -1
var _fore := -1
var _hand := -1


func setup(skeleton: Skeleton3D) -> void:
	_upper = skeleton.find_bone("DEF-upper_arm.R")
	_fore = skeleton.find_bone("DEF-forearm.R")
	_hand = skeleton.find_bone("DEF-hand.R")


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or weight <= 0.0 or _upper < 0 or _fore < 0 or _hand < 0:
		return
	_aim(sk, _upper, _fore, UPPER_DIR.normalized())
	_aim(sk, _fore, _hand, FORE_DIR.normalized())


## Gira o osso `bone` para que a ponta (o osso filho) aponte para `dir`.
func _aim(sk: Skeleton3D, bone: int, child: int, dir: Vector3) -> void:
	var g := sk.get_bone_global_pose(bone)
	var cur := (sk.get_bone_global_pose(child).origin - g.origin).normalized()
	if cur.length() < 0.5:
		return
	var full := Quaternion(cur, dir)
	var q := Quaternion.IDENTITY.slerp(full, weight)
	var new_basis := Basis(q) * g.basis
	var parent := sk.get_bone_parent(bone)
	var parent_basis := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
