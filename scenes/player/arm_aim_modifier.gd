class_name ArmAimModifier
extends SkeletonModifier3D
## Dual-wield stance: straightens both arms and points them at the target,
## holding the pistols out at arm's length like in the original game.
## Runs after the animation (and the spine twist), so it overrides the arms.

## World-space point the arms aim at.
var target := Vector3.ZERO


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var local_target := skeleton.global_transform.affine_inverse() * target
	for side in ["r", "l"]:
		var upper := skeleton.find_bone("upperarm_" + side)
		var lower := skeleton.find_bone("lowerarm_" + side)
		var hand := skeleton.find_bone("hand_" + side)
		# The rest pose has straight elbows and wrists.
		skeleton.set_bone_pose_rotation(lower, skeleton.get_bone_rest(lower).basis.get_rotation_quaternion())
		skeleton.set_bone_pose_rotation(hand, skeleton.get_bone_rest(hand).basis.get_rotation_quaternion())
		var shoulder := skeleton.get_bone_global_pose(upper)
		var from := (skeleton.get_bone_global_pose(hand).origin - shoulder.origin).normalized()
		var to := (local_target - shoulder.origin).normalized()
		if from.cross(to).length_squared() < 0.0000001:
			continue
		shoulder.basis = Basis(Quaternion(from, to)) * shoulder.basis
		skeleton.set_bone_global_pose(upper, shoulder)
