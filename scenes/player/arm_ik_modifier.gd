class_name ArmIKModifier
extends SkeletonModifier3D
## Aims the pistols: places each gun on the line to the target and solves the
## arms with two-bone IK so the hands wrap around the grips.
##
## - One Beretta: a two-handed isosceles grip in front of the chest, the
##   right hand on the grip and the left hand cupping it.
## - Dual Berettas: both arms straight out, one pistol in each hand.
##
## The guns themselves are placed from the hands (see [method gun_from_hand]),
## so when the IK is faded out (e.g. by the reload animation) they stay in
## the animated hands.
##
## Works in skeleton space: +Y up the spine, +Z forward, character's right -X.

enum Stance { TWO_HANDED, DUAL }

## How a hand holds a gun, in the gun's frame (X right, Y up, -Z forward):
## the direction from the wrist to the knuckles, the palm's normal, where the
## hand closes (the center of the fist), and how much the fingers curl
## (radians per joint, from the knuckle out) for the index finger, the other
## fingers and the thumb. The Beretta's grip runs from y -0.07 to -0.01,
## centered at z 0.014.
const GRIPS := {
	&"right": {
		"fingers": Vector3(0.0, -0.3, -1.0), "palm_normal": Vector3(-1.0, 0.0, 0.0), "fist": Vector3(0.0, -0.032, 0.014),
		"index": Vector3(0.5, 0.9, 0.5), "fingers_curl": Vector3(1.3, 1.4, 0.8), "thumb": Vector3(0.2, 0.25, 0.1),
	},
	&"left": {
		"fingers": Vector3(0.0, -0.3, -1.0), "palm_normal": Vector3(1.0, 0.0, 0.0), "fist": Vector3(0.0, -0.032, 0.014),
		"index": Vector3(0.5, 0.9, 0.5), "fingers_curl": Vector3(1.3, 1.4, 0.8), "thumb": Vector3(0.2, 0.25, 0.1),
	},
	# Support hand: palm against the left of the grip, fingers wrapped over
	# the right hand's fingers.
	&"support": {
		"fingers": Vector3(0.35, -0.75, -0.55), "palm_normal": Vector3(1.0, 0.35, 0.0), "fist": Vector3(-0.03, -0.05, -0.015),
		"index": Vector3(0.9, 1.0, 0.5), "fingers_curl": Vector3(0.9, 1.0, 0.5), "thumb": Vector3(0.1, 0.15, 0.1),
	},
}
## Distance of the gun from the middle of the shoulders, two-handed.
const TWO_HANDED_REACH := 0.36
## The same with the arms stretched out (see [member extend]).
const TWO_HANDED_MAX_REACH := 0.44
## Distance of each gun from its shoulder, dual wield (arms almost straight).
const DUAL_REACH := 0.45
## How far a shot pushes the hands back, in meters.
const RECOIL_DISTANCE := 0.035
## Where the elbows point (skeleton space): down and slightly out.
const ELBOW_POLES := {"r": Vector3(-0.5, -1.0, -0.2), "l": Vector3(0.5, -1.0, -0.2)}
const FINGERS: Array[String] = ["index", "middle", "ring", "pinky"]
## Center of the closed fist in the hand bone's frame (meters along the
## fingers and towards the palm), measured on Max's (large) hand mesh.
const FIST_CENTER := Vector2(0.11, 0.035)

## World-space point to aim at.
var target := Vector3.ZERO
## 0..1: pushes the guns out to arm's length, e.g. mid-dive.
var extend := 0.0
var stance := Stance.TWO_HANDED
## 1 right after a shot, decaying to 0.
var recoil := 0.0
## Progress through a pistol-whip, 0..1 (0 when not swinging): the right gun
## is raised, muzzle up, then brought down butt first and back to the aim.
var strike := 0.0

## Per side: the hand's frame (fingers, palm normal) in the hand bone's local
## space. Built from the rest pose.
var _hand_frames := {}


## Transform of a gun relative to the hand bone holding it with [param grip]
## (a key of GRIPS). Multiply a hand's global pose by it to place the gun.
func gun_from_hand(side: String, grip: StringName) -> Transform3D:
	_init_hands()
	return _hand_in_gun(side, grip).affine_inverse()


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_init_hands()
	var to_local := skeleton.global_transform.affine_inverse()
	var local_target := to_local * target
	var world_up := (to_local.basis * Vector3.UP).normalized()
	var chest := skeleton.get_bone_global_pose(skeleton.find_bone("spine_03")).basis
	var body_up := chest.y.normalized()
	var shoulder_r := skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_r")).origin
	var shoulder_l := skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_l")).origin

	if stance == Stance.TWO_HANDED:
		var center := (shoulder_r + shoulder_l) * 0.5 + body_up * 0.03
		var reach := lerpf(TWO_HANDED_REACH, TWO_HANDED_MAX_REACH, extend)
		var gun := _apply_strike(_gun_transform(center, local_target, reach, world_up, body_up), body_up)
		_solve_arm(skeleton, "r", gun * _hand_in_gun("r", &"right"), &"right")
		_solve_arm(skeleton, "l", gun * _hand_in_gun("l", &"support"), &"support")
	else:
		var gun_r := _apply_strike(_gun_transform(shoulder_r, local_target, DUAL_REACH, world_up, body_up), body_up)
		var gun_l := _gun_transform(shoulder_l, local_target, DUAL_REACH, world_up, body_up)
		_solve_arm(skeleton, "r", gun_r * _hand_in_gun("r", &"right"), &"right")
		_solve_arm(skeleton, "l", gun_l * _hand_in_gun("l", &"left"), &"left")


## Where a gun held [param reach] meters from [param origin] sits, pointing
## at [param aim_target]. Its top faces up, canted with the body when lying
## on a side.
func _gun_transform(origin: Vector3, aim_target: Vector3, reach: float, world_up: Vector3, body_up: Vector3) -> Transform3D:
	var aim := aim_target - origin
	if aim.length_squared() < 0.0001:
		aim = Vector3.BACK
	aim = aim.normalized()
	var up := _flatten(world_up, aim) + _flatten(body_up, aim) * 0.5
	if up.length_squared() < 0.0001:
		up = _flatten(Vector3.BACK, aim)
	var basis := Basis.looking_at(aim, up.normalized())
	return Transform3D(basis, origin + aim * (reach - RECOIL_DISTANCE * recoil))


## Where a pistol-whip at [param t] (0..1) is across the body: wound up out
## to the right (1), swept across to the left (-1), then back to the aim (0).
## The blow lands as the gun crosses the middle, about halfway through.
static func strike_side(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < 0.35:
		return smoothstep(0.0, 0.35, t)
	if t < 0.6:
		return lerpf(1.0, -1.0, smoothstep(0.35, 0.6, t))
	return smoothstep(0.6, 1.0, t) - 1.0


## Moves an aimed gun through the pistol-whip at [member strike]: a wide
## backhand from the right to the left, laid on its side with the butt
## leading.
func _apply_strike(gun: Transform3D, body_up: Vector3) -> Transform3D:
	var side := strike_side(strike)
	if is_zero_approx(side):
		return gun
	var forward := -gun.basis.z
	var right := gun.basis.x.normalized()
	# Out to the right and pulled back while winding up, across and in front
	# while sweeping; the muzzle turns with the swing.
	var offset := right * side * 0.5 + body_up * 0.08 * absf(side) \
			- forward * 0.12 * maxf(side, 0.0) + forward * 0.08 * maxf(-side, 0.0)
	var basis := gun.basis.rotated(forward, -deg_to_rad(60.0) * absf(side)).rotated(body_up, -side * deg_to_rad(70.0))
	return Transform3D(basis, gun.origin + offset)


## Two-bone IK: bends the elbow so the wrist reaches [param hand] (the hand
## bone's desired transform), then sets the hand's orientation and wraps the
## fingers around the grip.
func _solve_arm(skeleton: Skeleton3D, side: String, hand: Transform3D, grip: StringName) -> void:
	var upper := skeleton.find_bone("upperarm_" + side)
	var lower := skeleton.find_bone("lowerarm_" + side)
	var wrist := skeleton.find_bone("hand_" + side)
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(lower).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(skeleton.get_bone_global_pose(wrist).origin)

	var to_hand := hand.origin - shoulder
	var distance := clampf(to_hand.length(), absf(a - b) + 0.001, (a + b) * 0.999)
	var direction := to_hand.normalized()
	var cos_shoulder := (a * a + distance * distance - b * b) / (2.0 * a * distance)
	var bend := _flatten(ELBOW_POLES[side], direction)
	if bend.length_squared() < 0.0001:
		bend = _flatten(Vector3.DOWN, direction)
	var elbow_target := shoulder + direction * a * cos_shoulder \
			+ bend.normalized() * a * sqrt(maxf(1.0 - cos_shoulder * cos_shoulder, 0.0))
	var wrist_target := shoulder + direction * distance

	_aim_bone(skeleton, upper, elbow, elbow_target)
	elbow = skeleton.get_bone_global_pose(lower).origin
	_aim_bone(skeleton, lower, skeleton.get_bone_global_pose(wrist).origin, wrist_target)
	_roll_forearm(skeleton, side, lower, hand.basis)

	var pose := skeleton.get_bone_global_pose(wrist)
	pose.basis = hand.basis
	skeleton.set_bone_global_pose(wrist, pose)
	_curl_fingers(skeleton, side, hand.basis, GRIPS[grip])


## Straightens the fingers, then bends each joint towards the palm.
func _curl_fingers(skeleton: Skeleton3D, side: String, hand_basis: Basis, spec: Dictionary) -> void:
	var frame: Basis = _hand_frames[side]
	var along := hand_basis * frame.x
	var palm := hand_basis * frame.y
	# Rotating about this axis turns the fingers towards the palm.
	var axis := along.cross(palm).normalized()
	for finger in FINGERS + ["thumb"]:
		var curl: Vector3 = spec.fingers_curl
		if finger == "index" or finger == "thumb":
			curl = spec[finger]
		for joint in 3:
			var bone := skeleton.find_bone("%s_%02d_%s" % [finger, joint + 1, side])
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
			var bone_pose := skeleton.get_bone_global_pose(bone)
			var joint_axis := axis
			if finger == "thumb":
				# The thumb sticks out sideways: fold it towards the palm.
				var child := skeleton.get_bone_global_pose(skeleton.get_bone_children(bone)[0]).origin
				joint_axis = (child - bone_pose.origin).cross(palm).normalized()
			bone_pose.basis = Basis(joint_axis, curl[joint]) * bone_pose.basis
			skeleton.set_bone_global_pose(bone, bone_pose)


## Rotates [param bone] so its child at [param child_position] moves to [param goal].
func _aim_bone(skeleton: Skeleton3D, bone: int, child_position: Vector3, goal: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var from := (child_position - pose.origin).normalized()
	var to := (goal - pose.origin).normalized()
	if from.cross(to).length_squared() < 0.0000001:
		return
	pose.basis = Basis(Quaternion(from, to)) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)


## Rolls the forearm about its own axis so the palm side of the forearm
## matches the hand, instead of twisting the skin at the wrist.
func _roll_forearm(skeleton: Skeleton3D, side: String, lower: int, hand_basis: Basis) -> void:
	var pose := skeleton.get_bone_global_pose(lower)
	var axis := (skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side)).origin - pose.origin).normalized()
	# In the rest pose (T-pose) the palms face down, -Y.
	var rest_basis := skeleton.get_bone_global_rest(lower).basis
	var current := _flatten(pose.basis * (rest_basis.inverse() * Vector3.DOWN), axis)
	var palm: Basis = _hand_frames[side]
	var wanted := _flatten(hand_basis * palm.y, axis)
	if current.length_squared() < 0.0001 or wanted.length_squared() < 0.0001:
		return
	var angle := current.normalized().signed_angle_to(wanted.normalized(), axis)
	pose.basis = Basis(axis, angle) * pose.basis
	skeleton.set_bone_global_pose(lower, pose)


## The hand bone's transform in the gun's frame for a given grip.
func _hand_in_gun(side: String, grip: StringName) -> Transform3D:
	var spec: Dictionary = GRIPS[grip]
	var in_gun := _frame(spec.fingers, spec.palm_normal)
	var hand_frame: Basis = _hand_frames[side]
	var basis := in_gun * hand_frame.transposed()
	var wrist: Vector3 = spec.fist - in_gun.x * FIST_CENTER.x - in_gun.y * FIST_CENTER.y
	return Transform3D(basis, wrist)


func _init_hands() -> void:
	if not _hand_frames.is_empty():
		return
	var skeleton := get_skeleton()
	for side in ["r", "l"]:
		var hand := skeleton.get_bone_global_rest(skeleton.find_bone("hand_" + side))
		var knuckles := skeleton.get_bone_global_rest(skeleton.find_bone("middle_01_" + side)).origin
		# T-pose: fingers along the arm, palms facing down.
		var frame := _frame(knuckles - hand.origin, Vector3.DOWN)
		_hand_frames[side] = hand.basis.orthonormalized().transposed() * frame


## Orthonormal basis with X along [param x] and Y along [param y] (made
## perpendicular to X).
static func _frame(x: Vector3, y: Vector3) -> Basis:
	var x_axis := x.normalized()
	var y_axis := _flatten(y, x_axis).normalized()
	return Basis(x_axis, y_axis, x_axis.cross(y_axis))


## [param vector] without its component along the unit vector [param axis].
static func _flatten(vector: Vector3, axis: Vector3) -> Vector3:
	return vector - axis * vector.dot(axis)
