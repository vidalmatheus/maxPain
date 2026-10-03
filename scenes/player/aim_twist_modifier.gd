class_name AimTwistModifier
extends SkeletonModifier3D
## Twists the spine after the animation is applied, so the upper body (and
## the gun) faces the aim while the legs keep following the movement.

const SPINE_BONES: Array[StringName] = [&"spine_01", &"spine_02", &"spine_03"]

## Twist around the body's up axis, in radians, spread across the spine.
var yaw := 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or is_zero_approx(yaw):
		return
	var step := yaw / SPINE_BONES.size()
	for bone_name in SPINE_BONES:
		var bone := skeleton.find_bone(bone_name)
		var pose := skeleton.get_bone_global_pose(bone)
		pose.basis = Basis(Vector3.UP, step) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
