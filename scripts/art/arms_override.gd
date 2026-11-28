class_name ArmsOverride
extends SkeletonModifier3D
## Pose dos braços por cima da animação (Mistral): os dois braços erguidos
## na Geada Absoluta, palmas para a frente na Investida de Vendaval e a mão
## direita apontada na Descarga. `weight` (0 a 1) mistura a pose aos poucos.
## Direções no espaço do esqueleto (o modelo olha para +Z; .L fica em +X).

enum Pose { NONE, RAISE, PUSH, POINT }

const DIRS := {
	Pose.RAISE: {"upper": Vector3(0.55, 0.8, 0.15), "fore": Vector3(0.25, 0.95, 0.15)},
	Pose.PUSH: {"upper": Vector3(0.3, -0.05, 1.0), "fore": Vector3(0.12, 0.1, 1.0)},
	Pose.POINT: {"upper": Vector3(0.12, 0.05, 1.0), "fore": Vector3(0.02, 0.06, 1.0)},
}

var weight: float = 0.0
var pose: Pose = Pose.NONE
var _bones := {}


func setup(skeleton: Skeleton3D) -> void:
	for side in ["L", "R"]:
		_bones[side] = [skeleton.find_bone("DEF-upper_arm." + side), skeleton.find_bone("DEF-forearm." + side), skeleton.find_bone("DEF-hand." + side)]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or weight <= 0.0 or pose == Pose.NONE or _bones.is_empty():
		return
	var d: Dictionary = DIRS[pose]
	for side in ["L", "R"]:
		if pose == Pose.POINT and side == "L":
			continue
		var b: Array = _bones[side]
		if b[0] < 0 or b[1] < 0 or b[2] < 0:
			continue
		var sx := 1.0 if side == "L" else -1.0
		var up: Vector3 = d["upper"]
		var fo: Vector3 = d["fore"]
		_aim(sk, b[0], b[1], Vector3(up.x * sx, up.y, up.z).normalized())
		_aim(sk, b[1], b[2], Vector3(fo.x * sx, fo.y, fo.z).normalized())


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
