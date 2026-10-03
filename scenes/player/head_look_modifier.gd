class_name HeadLookModifier
extends SkeletonModifier3D
## Turns the neck and head so Max looks at what he is aiming at, within the
## range a neck can actually turn.

## Share of the rotation done by the neck; the head does the rest.
const NECK_SHARE := 0.4

## World-space point to look at.
var target := Vector3.ZERO
## Largest rotation away from the animated pose, in radians.
var max_angle := deg_to_rad(75.0)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var local_target := skeleton.global_transform.affine_inverse() * target
	var neck := skeleton.find_bone("neck_01")
	var head := skeleton.find_bone("Head")

	var rotation := _rotation_towards(skeleton, head, local_target)
	_rotate(skeleton, neck, rotation.slerp(Quaternion.IDENTITY, 1.0 - NECK_SHARE))
	# The neck moved the head: aim what is left with the head itself.
	_rotate(skeleton, head, _rotation_towards(skeleton, head, local_target))


## Rotation (skeleton space) that turns the face of [param bone] towards
## [param point], limited to [member max_angle].
func _rotation_towards(skeleton: Skeleton3D, bone: int, point: Vector3) -> Quaternion:
	var pose := skeleton.get_bone_global_pose(bone)
	# The face looks along +Z in the rest pose.
	var rest := skeleton.get_bone_global_rest(bone).basis
	var face := (pose.basis * (rest.inverse() * Vector3.BACK)).normalized()
	var to_point := (point - pose.origin).normalized()
	if face.cross(to_point).length_squared() < 0.0000001:
		return Quaternion.IDENTITY
	var full := Quaternion(face, to_point)
	var angle := full.get_angle()
	if angle <= max_angle:
		return full
	return Quaternion.IDENTITY.slerp(full, max_angle / angle)


func _rotate(skeleton: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	pose.basis = Basis(rotation) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)
