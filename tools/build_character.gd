extends SceneTree
## Builds the playable Max Payne character without Blender:
##
## 1. Rigs the static Max Payne model (assets/characters/max_payne) onto the
##    humanoid skeleton of Quaternius' Universal Animation Library:
##    - the skeleton is scaled to Max's height,
##    - arms and legs are bent so the bones line up with the mesh (bind pose),
##    - each vertex is weighted to the nearest bones of its body part.
## 2. Extracts the animations we use from the animation libraries into a
##    single AnimationLibrary, keeping only bone rotations (plus the pelvis
##    position, scaled to Max's legs) so they fit our proportions.
##
## Run after importing the project (so the model's textures are extracted):
##   godot --headless --path . --import
##   godot --headless --path . -s tools/build_character.gd -- --source=<dir>
## where <dir> contains the extracted "Universal Animation Library[Standard]"
## and "Universal Animation Library 2[Standard]" packs (CC0, by Quaternius).

const MODEL := "res://assets/characters/max_payne/max_payne_1.glb"
const OUTPUT_SCENE := "res://assets/characters/max_payne/max_payne_rigged.scn"
const OUTPUT_ANIMATIONS := "res://assets/characters/max_payne/animations.res"
## Character height in meters.
const HEIGHT := 1.8

const UAL1 := "Universal Animation Library[Standard]/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"
const UAL2 := "Universal Animation Library 2[Standard]/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb"

## Animations to keep, per library.
const ANIMATIONS := {
	UAL1: [
		"Idle_Loop", "Pistol_Idle_Loop", "Pistol_Aim_Neutral", "Pistol_Aim_Up", "Pistol_Aim_Down",
		"Pistol_Shoot", "Pistol_Reload", "Jog_Fwd_Loop", "Walk_Loop", "Sprint_Loop",
		"Jump_Start", "Jump_Loop", "Jump_Land", "Roll", "Crouch_Idle_Loop", "Hit_Chest", "Death01",
	],
	UAL2: ["LayToIdle", "Hit_Knockback", "NinjaJump_Idle_Loop"],
}

## Bones each body part of the model may be weighted to. Keys are prefixes of
## the model's mesh names (the longest match wins); the sleeves are the jacket
## meshes with materials #51 (right) and #48 (left).
const PART_BONES := {
	"head": ["Head", "neck_01"],
	"face": ["Head"],
	"eyes_mouth": ["Head"],
	"hair": ["Head"],
	"torso": ["spine_01", "spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"],
	"belt": ["pelvis", "spine_01"],
	"pants": ["pelvis", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"],
	"r_foot": ["foot_l", "ball_l", "calf_l", "foot_r", "ball_r", "calf_r"],
	"r_hand": ["hand_r", "lowerarm_r"],
	"l_hand": ["hand_l", "lowerarm_l"],
	"jacket_a_Material #51": ["clavicle_r", "upperarm_r", "lowerarm_r", "spine_03"],
	"jacket_a_Material #48": ["clavicle_l", "upperarm_l", "lowerarm_l", "spine_03"],
	"jacket_a": ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "thigh_l", "thigh_r", "neck_01"],
}

## Segment each bone covers, for distance-based weights: bone -> child bone.
const SEGMENTS := {
	"pelvis": "spine_01", "spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01",
	"neck_01": "Head", "clavicle_l": "upperarm_l", "upperarm_l": "lowerarm_l", "lowerarm_l": "hand_l",
	"hand_l": "middle_01_l", "clavicle_r": "upperarm_r", "upperarm_r": "lowerarm_r",
	"lowerarm_r": "hand_r", "hand_r": "middle_01_r", "thigh_l": "calf_l", "calf_l": "foot_l",
	"foot_l": "ball_l", "ball_l": "ball_leaf_l", "thigh_r": "calf_r", "calf_r": "foot_r",
	"foot_r": "ball_r", "ball_r": "ball_leaf_r",
}

var _source := ""
## Fitted pose, kept outside Skeleton3D (whose global poses only refresh
## inside the scene tree): local rotation and position per bone.
var _pose_rotations: Array[Quaternion] = []
var _pose_positions := PackedVector3Array()
## Bone offsets before fitting, to measure how much the legs were stretched.
var _original_positions := PackedVector3Array()


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			_source = arg.trim_prefix("--source=")
	if _source.is_empty() or not DirAccess.dir_exists_absolute(_source):
		push_error("Pass the animation packs directory with -- --source=<dir>")
		quit(1)
		return

	var parts := _load_model_parts()
	var skeleton := _load_skeleton()
	var landmarks := _landmarks(parts)
	print("Landmarks: ", landmarks)
	_fit_skeleton(skeleton, landmarks)
	var leg_scale := _leg_scale(skeleton)
	_save_rigged_scene(skeleton, parts)
	_build_animation_library(leg_scale)
	quit()


# --- Model -------------------------------------------------------------------

## Loads every mesh of the model, transformed into a Y-up, feet-on-the-ground
## space of HEIGHT meters, facing +Z (the skeleton's convention).
func _load_model_parts() -> Array[Dictionary]:
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	var parts: Array[Dictionary] = []
	var all_points := PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var transform := _global_transform(mesh_instance, model)
		var arrays := mesh_instance.mesh.surface_get_arrays(0)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in positions.size():
			positions[i] = transform * positions[i]
			normals[i] = (transform.basis * normals[i]).normalized()
		all_points.append_array(positions)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		parts.append({
			"name": String(mesh_instance.name),
			"arrays": arrays,
			"material": mesh_instance.mesh.surface_get_material(0),
		})

	var bounds := _bounds(all_points)
	var scale := HEIGHT / bounds.size.y
	var offset := Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	for part in parts:
		var positions: PackedVector3Array = part.arrays[Mesh.ARRAY_VERTEX]
		for i in positions.size():
			positions[i] = (positions[i] + offset) * scale
		part.arrays[Mesh.ARRAY_VERTEX] = positions
	model.free()
	return parts


func _global_transform(node: Node3D, root: Node) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent != root and parent is Node3D:
		transform = (parent as Node3D).transform * transform
		parent = parent.get_parent()
	return transform


func _part_positions(parts: Array[Dictionary], prefix: String) -> PackedVector3Array:
	var result := PackedVector3Array()
	for part in parts:
		if (part.name as String).begins_with(prefix):
			result.append_array(part.arrays[Mesh.ARRAY_VERTEX])
	return result


## Joint positions measured on the mesh. The character's right side is -X.
func _landmarks(parts: Array[Dictionary]) -> Dictionary:
	var result := {}
	var feet := _part_positions(parts, "r_foot")  # Both shoes live in these meshes.
	for side: String in ["r", "l"]:
		var hand := _part_positions(parts, "%s_hand" % side)
		var sleeve := _part_positions(parts, "jacket_a_Material #51" if side == "r" else "jacket_a_Material #48")
		var hand_box := _bounds(hand)
		var sleeve_box := _bounds(sleeve)
		var inner_x := sleeve_box.end.x if side == "r" else sleeve_box.position.x
		var wrist := _centroid(hand, func(p: Vector3) -> bool: return p.y > hand_box.end.y - hand_box.size.y * 0.2)
		var shoulder := _centroid(sleeve, func(p: Vector3) -> bool: return absf(p.x - inner_x) < sleeve_box.size.x * 0.12)
		result["wrist_" + side] = wrist
		result["hand_tip_" + side] = _centroid(hand, func(p: Vector3) -> bool: return p.y < hand_box.position.y + hand_box.size.y * 0.3)
		result["shoulder_" + side] = shoulder
		result["elbow_" + side] = shoulder.lerp(wrist, 0.5)

		var on_side := func(p: Vector3) -> bool: return (p.x < 0.0) == (side == "r")
		var foot_box := _bounds(feet, on_side)
		result["ankle_" + side] = _centroid(feet, func(p: Vector3) -> bool: return on_side.call(p) and p.y > foot_box.end.y - foot_box.size.y * 0.3)
		result["ball_" + side] = _centroid(feet, func(p: Vector3) -> bool: return on_side.call(p) and p.z > foot_box.end.z - foot_box.size.z * 0.3 and p.y < foot_box.position.y + foot_box.size.y * 0.5)
	return result


func _bounds(points: PackedVector3Array, filter: Callable = Callable()) -> AABB:
	var box := AABB()
	var first := true
	for p in points:
		if filter.is_valid() and not filter.call(p):
			continue
		box = AABB(p, Vector3.ZERO) if first else box.expand(p)
		first = false
	return box


func _centroid(points: PackedVector3Array, filter: Callable) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for p in points:
		if filter.call(p):
			sum += p
			count += 1
	return sum / maxi(count, 1)


# --- Skeleton ----------------------------------------------------------------

## The animation library's skeleton, scaled to the model's height.
func _load_skeleton() -> Skeleton3D:
	var scene := _load_gltf(_source.path_join(UAL1))
	var source := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var scale := HEIGHT / _mesh_height(scene)

	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	for bone in source.get_bone_count():
		skeleton.add_bone(source.get_bone_name(bone))
	for bone in source.get_bone_count():
		skeleton.set_bone_parent(bone, source.get_bone_parent(bone))
		var rest := source.get_bone_rest(bone)
		rest.origin *= scale
		skeleton.set_bone_rest(bone, rest)
	for bone in skeleton.get_bone_count():
		_pose_rotations.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
		_pose_positions.append(skeleton.get_bone_rest(bone).origin)
	_original_positions = _pose_positions.duplicate()
	scene.free()
	return skeleton


func _mesh_height(scene: Node) -> float:
	var height := 0.0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		height = maxf(height, (node as MeshInstance3D).get_aabb().end.y)
	return height


## Bends the skeleton into the model's pose and stretches arm and leg bones
## to its lengths. Rest rotations stay untouched so animations still apply.
func _fit_skeleton(skeleton: Skeleton3D, landmarks: Dictionary) -> void:
	for side: String in ["r", "l"]:
		_aim_bone(skeleton, "clavicle_" + side, "upperarm_" + side, landmarks["shoulder_" + side])
		_aim_bone(skeleton, "upperarm_" + side, "lowerarm_" + side, landmarks["elbow_" + side])
		_aim_bone(skeleton, "lowerarm_" + side, "hand_" + side, landmarks["wrist_" + side])
		_aim_bone(skeleton, "hand_" + side, "middle_01_" + side, landmarks["hand_tip_" + side], false)
		var hip := _global_origin(skeleton, "thigh_" + side)
		var ankle: Vector3 = landmarks["ankle_" + side]
		var knee := hip.lerp(ankle, 0.48) + Vector3(0, 0, 0.02)
		_aim_bone(skeleton, "thigh_" + side, "calf_" + side, knee)
		_aim_bone(skeleton, "calf_" + side, "foot_" + side, ankle)
		_aim_bone(skeleton, "foot_" + side, "ball_" + side, landmarks["ball_" + side])


## Rotates [param bone_name] so its child lands on [param target]. When
## [param stretch] is set, the child's rest offset is scaled to reach it.
func _aim_bone(skeleton: Skeleton3D, bone_name: String, child_name: String, target: Vector3, stretch := true) -> void:
	var bone := skeleton.find_bone(bone_name)
	var child := skeleton.find_bone(child_name)
	var origin := _global_pose(skeleton, bone).origin
	if stretch:
		var current_length := (_global_pose(skeleton, child).origin - origin).length()
		_pose_positions[child] *= (target - origin).length() / current_length
		var rest := skeleton.get_bone_rest(child)
		rest.origin = _pose_positions[child]
		skeleton.set_bone_rest(child, rest)
	var from := (_global_pose(skeleton, child).origin - origin).normalized()
	var to := (target - origin).normalized()
	var new_global := Basis(Quaternion(from, to)) * _global_pose(skeleton, bone).basis
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := _global_pose(skeleton, parent).basis if parent >= 0 else Basis.IDENTITY
	_pose_rotations[bone] = (parent_basis.inverse() * new_global).get_rotation_quaternion()


## Global (skeleton space) transform of a bone in the fitted pose.
func _global_pose(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var local := Transform3D(Basis(_pose_rotations[bone]), _pose_positions[bone])
	var parent := skeleton.get_bone_parent(bone)
	return _global_pose(skeleton, parent) * local if parent >= 0 else local


func _global_origin(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	return _global_pose(skeleton, skeleton.find_bone(bone_name)).origin


## Ratio between Max's leg length and the scaled mannequin's, used to scale
## the pelvis height in animations so the feet stay on the ground.
func _leg_scale(skeleton: Skeleton3D) -> float:
	var fitted := 0.0
	var original := 0.0
	for bone_name in ["calf_r", "foot_r"]:
		var bone := skeleton.find_bone(bone_name)
		fitted += _pose_positions[bone].length()
		original += _original_positions[bone].length()
	return fitted / original


# --- Skinning ----------------------------------------------------------------

func _save_rigged_scene(skeleton: Skeleton3D, parts: Array[Dictionary]) -> void:
	var segments := {}
	for bone_name: String in SEGMENTS:
		segments[bone_name] = [_global_origin(skeleton, bone_name), _global_origin(skeleton, SEGMENTS[bone_name])]
	var head := _global_origin(skeleton, "Head")
	segments["Head"] = [head, head + Vector3(0, 0.2, 0)]

	var mesh := ArrayMesh.new()
	for part in parts:
		var candidates: Array = _part_candidates(part.name)
		var arrays: Array = part.arrays
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for p in positions:
			_weigh_vertex(p, candidates, segments, skeleton, bones, weights)
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface := mesh.get_surface_count() - 1
		mesh.surface_set_material(surface, part.material)
		mesh.surface_set_name(surface, part.name)

	# Bind pose = the fitted pose, so the mesh deforms from where it was modeled.
	var skin := Skin.new()
	for bone in skeleton.get_bone_count():
		skin.add_bind(bone, _global_pose(skeleton, bone).affine_inverse())

	var root := Node3D.new()
	root.name = "MaxPayne"
	var armature := Node3D.new()
	armature.name = "Armature"
	root.add_child(armature)
	armature.owner = root
	skeleton.reset_bone_poses()
	armature.add_child(skeleton)
	skeleton.owner = root
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	body.skin = skin
	skeleton.add_child(body)
	body.owner = root
	body.skeleton = NodePath("..")

	var packed := PackedScene.new()
	packed.pack(root)
	var error := ResourceSaver.save(packed, OUTPUT_SCENE, ResourceSaver.FLAG_COMPRESS)
	assert(error == OK)
	print("Saved rigged character to ", OUTPUT_SCENE)
	root.free()


func _part_candidates(part_name: String) -> Array:
	var best := ""
	for prefix: String in PART_BONES:
		if part_name.begins_with(prefix) and prefix.length() > best.length():
			best = prefix
	return PART_BONES[best]


## Weights a vertex to its nearest candidate bones (inverse distance).
func _weigh_vertex(p: Vector3, candidates: Array, segments: Dictionary, skeleton: Skeleton3D, bones: PackedInt32Array, weights: PackedFloat32Array) -> void:
	var scored: Array = []
	for bone_name: String in candidates:
		var segment: Array = segments[bone_name]
		var distance := p.distance_to(Geometry3D.get_closest_point_to_segment(p, segment[0], segment[1]))
		scored.append([1.0 / pow(distance + 0.02, 4.0), skeleton.find_bone(bone_name)])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var kept := mini(3, scored.size())
	var total := 0.0
	for i in kept:
		total += scored[i][0]
	var vertex_bones := PackedInt32Array([0, 0, 0, 0])
	var vertex_weights := PackedFloat32Array([0, 0, 0, 0])
	var sum := 0.0
	for i in kept:
		var weight: float = scored[i][0] / total
		if weight > 0.03:
			vertex_bones[i] = scored[i][1]
			vertex_weights[i] = weight
			sum += weight
	for i in 4:
		vertex_weights[i] /= sum
	bones.append_array(vertex_bones)
	weights.append_array(vertex_weights)


# --- Animations --------------------------------------------------------------

func _build_animation_library(pelvis_scale: float) -> void:
	var library := AnimationLibrary.new()
	for file: String in ANIMATIONS:
		var scene := _load_gltf(_source.path_join(file))
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var scale := HEIGHT / _mesh_height(scene) * pelvis_scale
		for anim_name: String in ANIMATIONS[file]:
			var animation := player.get_animation(anim_name).duplicate(true) as Animation
			_retarget(animation, scale)
			library.add_animation(anim_name, animation)
		scene.free()
	var error := ResourceSaver.save(library, OUTPUT_ANIMATIONS, ResourceSaver.FLAG_COMPRESS)
	assert(error == OK)
	print("Saved %d animations to %s" % [library.get_animation_list().size(), OUTPUT_ANIMATIONS])


## Keeps only bone rotations plus the pelvis position (scaled to our body), so
## animations made for the mannequin don't stretch our character's limbs.
func _retarget(animation: Animation, pelvis_scale: float) -> void:
	for t in range(animation.get_track_count() - 1, -1, -1):
		var type := animation.track_get_type(t)
		var bone := String(animation.track_get_path(t).get_subname(0))
		if type == Animation.TYPE_SCALE_3D or (type == Animation.TYPE_POSITION_3D and bone != "pelvis" and bone != "root"):
			animation.remove_track(t)
		elif type == Animation.TYPE_POSITION_3D and bone == "pelvis":
			for k in animation.track_get_key_count(t):
				animation.track_set_key_value(t, k, animation.track_get_key_value(t, k) * pelvis_scale)


func _load_gltf(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error := doc.append_from_file(path, state)
	assert(error == OK, "Could not load " + path)
	return doc.generate_scene(state)
