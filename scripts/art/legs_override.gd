class_name LegsOverride
extends SkeletonModifier3D
## Durante um golpe, troca só as pernas pela animação de andar: o tronco
## bate e as pernas continuam dando passos (para frente ou de ré), no ritmo
## da velocidade em que o herói está andando.

const LEG_BONES := [
	"DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-toe.L",
	"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R", "DEF-toe.R",
]

var walk: Animation
## Tempo na animação de andar; o FenixModel avança (ou volta, andando de ré).
var time: float = 0.0
## Pares [osso, trilha de rotação] das pernas.
var _tracks: Array = []


func setup(skeleton: Skeleton3D, walk_anim: Animation) -> void:
	walk = walk_anim
	_tracks.clear()
	for i in walk.get_track_count():
		if walk.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(walk.track_get_path(i)).get_slice(":", 1)
		if bone_name in LEG_BONES:
			var b := skeleton.find_bone(bone_name)
			if b >= 0:
				_tracks.append([b, i])


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or walk == null:
		return
	var t := fposmod(time, walk.length)
	for tr in _tracks:
		sk.set_bone_pose_rotation(tr[0], walk.rotation_track_interpolate(tr[1], t))
