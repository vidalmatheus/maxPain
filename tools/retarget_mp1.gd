extends SceneTree
## Retargets animations from the original Max Payne 1 model onto our Max.
##
## The source (assets/characters/max_payne/source/max_payne_1_animated.glb,
## "Max Payne 1 (Animated + Updated again)" by pineware31, CC BY 4.0) has
## the first game's skeleton and animations but no textures. Our character
## keeps its own textured model and humanoid rig (see build_character.gd);
## this script only converts the source's motion to that rig:
##
## - Each mapped bone points the way its source bone points: the source's
##   rotation away from its rest pose is applied to our bone, after turning
##   our bone's rest to the source's rest direction. So the different rest
##   poses (arms forward there, out to the sides here) don't matter.
## - Bones without a source (clavicles, the middle of the spine) keep their
##   rest; the fingers hold the grip of our pistol idle.
## - The pelvis moves like the source's, scaled to our height.
## - The source's data is mirrored (its "R" bones, the gun hand, are on the
##   left of the way its feet point), so it is reflected back first.
##
## The animations are added to animations.res as "MP1_<name>", replacing
## older versions. Run after build_character.gd (which writes that file):
##   godot --headless --path . -s tools/retarget_mp1.gd

const SOURCE := "res://assets/characters/max_payne/source/max_payne_1_animated.glb"
const RIG := "res://assets/characters/max_payne/max_payne_rigged.scn"
const LIBRARY := "res://assets/characters/max_payne/animations.res"
const FPS := 30.0

## Source animation -> [our name for it, whether it loops].
const ANIMATIONS := {
	"Skeleton|Death": ["MP1_Death", false],
	"Skeleton|Death 2": ["MP1_Death2", false],
	"Skeleton|Stand Hurt": ["MP1_Stand_Hurt", true],
	"Skeleton|Walk Hurt": ["MP1_Walk_Hurt", true],
	"Skeleton|ReloadPistol": ["MP1_Reload", false],
	"Skeleton|ReloadPistolDual": ["MP1_Reload_Dual", false],
	"Skeleton|IdleWarmingHands": ["MP1_Warming_Hands", true],
}

## Our bone -> [source bone, our bone it points at, source bone it points at].
## An empty aim keeps the rest correction of the bone's parent (hands, toes
## and the head line up with the bone before them).
const BONES := {
	"pelvis": ["Pelvis_01", "spine_01", "Torso_02"],
	"spine_01": ["Torso_02", "neck_01", "Neck_03"],
	"neck_01": ["Neck_03", "Head", "Head_04"],
	"Head": ["Head_04", "", ""],
	"upperarm_r": ["UpArm-R_013", "lowerarm_r", "LoArm-R_014"],
	"lowerarm_r": ["LoArm-R_014", "hand_r", "Hand-R_015"],
	"hand_r": ["Hand-R_015", "", ""],
	"upperarm_l": ["UpArm-L_017", "lowerarm_l", "LoArm-L_018"],
	"lowerarm_l": ["LoArm-L_018", "hand_l", "Hand-L_019"],
	"hand_l": ["Hand-L_019", "", ""],
	"thigh_r": ["UpLeg-R_020", "calf_r", "LoLeg-R_021"],
	"calf_r": ["LoLeg-R_021", "foot_r", "Foot-R_022"],
	"foot_r": ["Foot-R_022", "ball_r", "Toe-R_023"],
	"ball_r": ["Toe-R_023", "", ""],
	"thigh_l": ["UpLeg-L_024", "calf_l", "LoLeg-L_025"],
	"calf_l": ["LoLeg-L_025", "foot_l", "Foot-L_026"],
	"foot_l": ["Foot-L_026", "ball_l", "Toe-L_027"],
	"ball_l": ["Toe-L_027", "", ""],
}
## Animation whose first frame gives the fingers' grip.
const FINGER_POSE := "Pistol_Idle_Loop"

var _source: Skeleton3D
var _target: Skeleton3D
## Rotation taking source skeleton space to ours (facing, up, handedness).
var _align := Quaternion.IDENTITY
var _scale := 1.0
## Per our bone: rest global rotation turned to the source's rest direction.
var _corrected_rest := {}
var _source_rest_global := {}
## Reflection applied to the source's poses when its data is mirrored.
var _mirror := Basis.IDENTITY


func _init() -> void:
	var source_scene := _load_gltf(ProjectSettings.globalize_path(SOURCE))
	_source = source_scene.find_children("*", "Skeleton3D", true, false)[0]
	var player := source_scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig: Node = (load(RIG) as PackedScene).instantiate()
	_target = rig.find_children("*", "Skeleton3D", true, false)[0]
	_measure()

	var library := load(LIBRARY) as AnimationLibrary
	var fingers := _finger_pose(library.get_animation(FINGER_POSE))
	for source_name: String in ANIMATIONS:
		var animation := _retarget(player.get_animation(source_name), fingers)
		var our_name: String = ANIMATIONS[source_name][0]
		animation.loop_mode = Animation.LOOP_LINEAR if ANIMATIONS[source_name][1] else Animation.LOOP_NONE
		if library.has_animation(our_name):
			library.remove_animation(our_name)
		library.add_animation(our_name, animation)
		print("%s -> %s (%.2f s)" % [source_name, our_name, animation.length])
	var error := ResourceSaver.save(library, LIBRARY, ResourceSaver.FLAG_COMPRESS)
	assert(error == OK)
	source_scene.free()
	rig.free()
	quit()


## Works out how the source skeleton is oriented and scaled relative to ours,
## and each bone's rest correction.
func _measure() -> void:
	var src := {}
	for bone in _source.get_bone_count():
		src[_source.get_bone_name(bone)] = _source.get_bone_global_rest(bone)
	# Mirrored? Compare the "R" side with the right of the way the feet point.
	var up: Vector3 = (src["Neck_03"].origin - src["Pelvis_01"].origin).normalized()
	var forward: Vector3 = src["Toe-R_023"].origin - src["Foot-R_022"].origin
	forward = (forward - up * forward.dot(up)).normalized()
	var named_right: Vector3 = src["UpLeg-R_020"].origin - src["UpLeg-L_024"].origin
	if forward.cross(up).dot(named_right) < 0.0:
		var axis := named_right.normalized()
		_mirror = Basis(Vector3.RIGHT - 2.0 * axis.x * axis, Vector3.UP - 2.0 * axis.y * axis,
				Vector3.BACK - 2.0 * axis.z * axis)
		print("Source is mirrored; reflecting it")
		for bone_name: String in src:
			src[bone_name] = _reflect(src[bone_name])
	_source_rest_global = src
	var tgt := func(bone_name: String) -> Transform3D:
		return _target.get_bone_global_rest(_target.find_bone(bone_name))
	# Character frames from the rest poses: up the spine, across the hips.
	var src_up: Vector3 = (src["Neck_03"].origin - src["Pelvis_01"].origin).normalized()
	var src_right: Vector3 = (src["UpLeg-R_020"].origin - src["UpLeg-L_024"].origin).normalized()
	var tgt_up: Vector3 = (tgt.call("neck_01").origin - tgt.call("pelvis").origin).normalized()
	var tgt_right: Vector3 = (tgt.call("thigh_r").origin - tgt.call("thigh_l").origin).normalized()
	var src_frame := _frame(src_right, src_up)
	var tgt_frame := _frame(tgt_right, tgt_up)
	_align = (tgt_frame * src_frame.inverse()).get_rotation_quaternion()
	_scale = (tgt.call("pelvis").origin.y - tgt.call("foot_r").origin.y) \
			/ (src["Pelvis_01"].origin - src["Foot-R_022"].origin).dot(src_up)

	for bone_name: String in BONES:
		var spec: Array = BONES[bone_name]
		var rest: Quaternion = tgt.call(bone_name).basis.get_rotation_quaternion()
		var correction := Quaternion.IDENTITY
		if spec[1] != "":
			var ours: Vector3 = tgt.call(spec[1]).origin - tgt.call(bone_name).origin
			var theirs: Vector3 = _align * (src[spec[2]].origin - src[spec[0]].origin)
			correction = Quaternion(ours.normalized(), theirs.normalized())
		else:
			var parent := _target.get_bone_name(_target.get_bone_parent(_target.find_bone(bone_name)))
			correction = _corrected_rest[parent] * tgt.call(parent).basis.get_rotation_quaternion().inverse()
		_corrected_rest[bone_name] = correction * rest


static func _frame(right: Vector3, up: Vector3) -> Basis:
	var forward := up.cross(right).normalized()
	right = forward.cross(up).normalized()
	return Basis(right, up.normalized(), forward)


func _retarget(source: Animation, fingers: Dictionary) -> Animation:
	var animation := Animation.new()
	animation.length = source.length
	var skeleton_path := "%s:%s"
	var path_prefix := String(NodePath("Armature/Skeleton3D"))
	var tracks := {}
	for bone in _target.get_bone_count():
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, skeleton_path % [path_prefix, _target.get_bone_name(bone)])
		tracks[bone] = track
	var pelvis := _target.find_bone("pelvis")
	var pelvis_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(pelvis_track, skeleton_path % [path_prefix, "pelvis"])

	var frames := maxi(int(ceil(source.length * FPS)), 1)
	for frame in frames + 1:
		var time := minf(frame / FPS, source.length)
		var src_global := _source_globals(source, time)
		var globals: Array[Transform3D] = []
		globals.resize(_target.get_bone_count())
		for bone in _target.get_bone_count():
			var bone_name := _target.get_bone_name(bone)
			var parent := _target.get_bone_parent(bone)
			var parent_global := globals[parent] if parent >= 0 else Transform3D.IDENTITY
			var local := _target.get_bone_rest(bone)
			if fingers.has(bone_name):
				local.basis = Basis(fingers[bone_name])
			var global := parent_global * local
			if BONES.has(bone_name):
				var source_bone: String = BONES[bone_name][0]
				var delta: Quaternion = src_global[source_bone].basis.get_rotation_quaternion() \
						* (_source_rest_global[source_bone] as Transform3D).basis.get_rotation_quaternion().inverse()
				var rotation: Quaternion = (_align * delta * _align.inverse()) * _corrected_rest[bone_name]
				global.basis = Basis(rotation)
			if bone == pelvis:
				var moved: Vector3 = src_global["Pelvis_01"].origin - (_source_rest_global["Pelvis_01"] as Transform3D).origin
				global.origin = _target.get_bone_global_rest(bone).origin + _align * moved * _scale
			globals[bone] = global
			var local_rotation := (parent_global.basis.inverse() * global.basis).get_rotation_quaternion()
			animation.rotation_track_insert_key(tracks[bone], time, local_rotation)
			if bone == pelvis:
				animation.position_track_insert_key(pelvis_track, time, parent_global.affine_inverse() * global.origin)
	# Drop the keys a straight line between their neighbors already gives
	# (all but one on bones that don't move).
	animation.optimize()
	return animation


## Global (skeleton space) bone transforms of the source at [param time].
func _source_globals(animation: Animation, time: float) -> Dictionary:
	var locals: Array[Transform3D] = []
	for bone in _source.get_bone_count():
		locals.append(_source.get_bone_rest(bone))
	for track in animation.get_track_count():
		var bone := _source.find_bone(String(animation.track_get_path(track).get_subname(0)))
		if bone < 0:
			continue
		match animation.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				locals[bone].basis = Basis(animation.rotation_track_interpolate(track, time))
			Animation.TYPE_POSITION_3D:
				locals[bone].origin = animation.position_track_interpolate(track, time)
	var globals := {}
	var by_index: Array[Transform3D] = []
	for bone in _source.get_bone_count():
		var parent := _source.get_bone_parent(bone)
		var global := (by_index[parent] if parent >= 0 else Transform3D.IDENTITY) * locals[bone]
		by_index.append(global)
		globals[_source.get_bone_name(bone)] = _reflect(global)
	return globals


## [param transform] reflected back if the source is mirrored. Reflecting on
## both sides keeps the bone's axes a proper rotation.
func _reflect(transform: Transform3D) -> Transform3D:
	if _mirror == Basis.IDENTITY:
		return transform
	return Transform3D(_mirror * transform.basis * _mirror, _mirror * transform.origin)


## The fingers' local rotations in the first frame of [param animation].
func _finger_pose(animation: Animation) -> Dictionary:
	var pose := {}
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(animation.track_get_path(track).get_subname(0))
		for finger in ["thumb", "index", "middle", "ring", "pinky"]:
			if bone_name.begins_with(finger):
				pose[bone_name] = animation.rotation_track_interpolate(track, 0.0)
	return pose


func _load_gltf(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error := doc.append_from_file(path, state)
	assert(error == OK, "Could not load " + path)
	return doc.generate_scene(state)
