class_name DivePoseModifier
extends SkeletonModifier3D
## Shootdodge pose: straightens the body like a diver, legs together and
## trailing behind with the knees slightly bent and the toes pointed.
##
## [member curl] bends the spine forward (positive) or back (negative): when
## diving backwards the chest curls up so the guns can aim over the feet, and
## [member leg_raise] lifts the legs to match. Blend it in and out with
## [member SkeletonModifier3D.influence].
##
## Works in skeleton space, where +Y is up the spine, +Z is forward and the
## character's right is -X. Rotating about +X tips "up" towards "forward".

const SPINE: Array[StringName] = [&"spine_01", &"spine_02", &"spine_03"]
const STRAIGHT: Array[StringName] = [
	&"pelvis", &"spine_01", &"spine_02", &"spine_03",
	&"thigh_l", &"calf_l", &"foot_l", &"thigh_r", &"calf_r", &"foot_r",
]

## Spine bend in radians, spread over the three spine bones.
var curl := 0.0
## Hip flexion in radians (legs towards the chest).
var leg_raise := 0.0
## Knee bend in radians for the right and left leg; a little asymmetry looks
## less stiff.
var knee_bend := Vector2(0.35, 0.15)
## Plantar flexion of the feet (toes pointed along the legs).
var toe_point := 0.9
## How far the legs spread apart, in radians.
var leg_spread := 0.05


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	for bone_name in STRAIGHT:
		var bone := skeleton.find_bone(bone_name)
		var rest := skeleton.get_bone_rest(bone)
		skeleton.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion())
		if bone_name == &"pelvis":
			skeleton.set_bone_pose_position(bone, rest.origin)

	for bone_name in SPINE:
		_rotate(skeleton, bone_name, Vector3.RIGHT, curl / SPINE.size())

	for side in ["r", "l"]:
		var sign := -1.0 if side == "r" else 1.0
		_rotate(skeleton, "thigh_" + side, Vector3.RIGHT, -leg_raise)
		_rotate(skeleton, "thigh_" + side, Vector3.BACK, sign * leg_spread)
		_rotate(skeleton, "calf_" + side, Vector3.RIGHT, knee_bend.x if side == "r" else knee_bend.y)
		_rotate(skeleton, "foot_" + side, Vector3.RIGHT, toe_point)


## Rotates a bone (and everything attached to it) about a skeleton-space axis.
func _rotate(skeleton: Skeleton3D, bone_name: StringName, axis: Vector3, angle: float) -> void:
	if is_zero_approx(angle):
		return
	var bone := skeleton.find_bone(bone_name)
	var pose := skeleton.get_bone_global_pose(bone)
	pose.basis = Basis(axis, angle) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)
