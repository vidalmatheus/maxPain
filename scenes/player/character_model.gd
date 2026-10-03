class_name CharacterModel
extends Node3D
## Animated character: drives an AnimationTree that blends locomotion (legs)
## with pistol aiming (upper body) plus one-shot fire and reload actions, and
## twists the spine so the upper body faces the aim.
##
## The tree is built in code so it is easy to read and review; the animations
## come from res://assets/characters/max_payne/animations.res.

enum Locomotion { IDLE, RUN, RUN_BACK, AIR, CROUCH }

const ANIMATIONS := preload("res://assets/characters/max_payne/animations.res")
const SKELETON_PATH := "Armature/Skeleton3D"
const LOCOMOTION_INPUTS := ["idle", "run", "run_back", "air", "crouch"]
## Ground speed (m/s) at which the jog animation plays at normal speed.
const JOG_SPEED := 4.5
## Aim pitch (radians) that maps to the full "aim up/down" poses.
const MAX_AIM_PITCH := deg_to_rad(60.0)
const MAX_TWIST := deg_to_rad(100.0)

@onready var rig: Node3D = $MaxPayne
@onready var skeleton: Skeleton3D = rig.get_node(SKELETON_PATH)

var _tree: AnimationTree
var _twist: AimTwistModifier
var _hand: BoneAttachment3D
var _locomotion := Locomotion.IDLE


func _ready() -> void:
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.add_animation_library(&"", ANIMATIONS)
	add_child(_tree)
	_tree.root_node = _tree.get_path_to(rig)
	_tree.tree_root = _build_tree()
	_tree.active = true
	_tree.set(&"parameters/upper/blend_amount", 1.0)

	_twist = AimTwistModifier.new()
	skeleton.add_child(_twist)

	_hand = BoneAttachment3D.new()
	_hand.bone_name = "hand_r"
	skeleton.add_child(_hand)


## World position of the right hand, where the pistol is held.
func get_hand_position() -> Vector3:
	return _hand.global_position


func set_locomotion(locomotion: Locomotion, ground_speed: float) -> void:
	if locomotion != _locomotion:
		_locomotion = locomotion
		_tree.set(&"parameters/locomotion/transition_request", LOCOMOTION_INPUTS[locomotion])
	var scale := clampf(ground_speed / JOG_SPEED, 0.6, 1.4) if locomotion == Locomotion.RUN or locomotion == Locomotion.RUN_BACK else 1.0
	_tree.set(&"parameters/locomotion_speed/scale", scale)


## Points the upper body at [param target] (world space): the spine twists
## towards it and the arms blend between the aim-down/neutral/up poses.
func aim_at(target: Vector3) -> void:
	var local := skeleton.global_basis.inverse() * (target - skeleton.global_position)
	if local.length_squared() < 0.01:
		return
	_twist.yaw = clampf(atan2(local.x, local.z), -MAX_TWIST, MAX_TWIST)
	var pitch := atan2(local.y - 1.4, Vector2(local.x, local.z).length())
	_tree.set(&"parameters/aim/blend_position", clampf(pitch / MAX_AIM_PITCH, -1.0, 1.0))


func play_fire() -> void:
	_tree.set(&"parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Plays the reload animation stretched to [param duration] seconds.
func play_reload(duration: float) -> void:
	var length := ANIMATIONS.get_animation(&"Pistol_Reload").length
	_tree.set(&"parameters/reload_speed/scale", length / maxf(duration, 0.1))
	_tree.set(&"parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _build_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()

	# Legs: idle / jog forward / jog backward / airborne / crouch.
	var locomotion := AnimationNodeTransition.new()
	locomotion.input_count = LOCOMOTION_INPUTS.size()
	locomotion.xfade_time = 0.15
	for i in LOCOMOTION_INPUTS.size():
		locomotion.set_input_name(i, LOCOMOTION_INPUTS[i])
	tree.add_node(&"locomotion", locomotion)
	var clips := ["Pistol_Idle_Loop", "Jog_Fwd_Loop", "Jog_Fwd_Loop", "Jump_Loop", "Crouch_Idle_Loop"]
	for i in clips.size():
		var clip := _clip(clips[i])
		if LOCOMOTION_INPUTS[i] == "run_back":
			clip.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
		tree.add_node(StringName(LOCOMOTION_INPUTS[i]), clip)
		tree.connect_node(&"locomotion", i, StringName(LOCOMOTION_INPUTS[i]))
	tree.add_node(&"locomotion_speed", AnimationNodeTimeScale.new())
	tree.connect_node(&"locomotion_speed", 0, &"locomotion")

	# Upper body: aim poses blended by pitch.
	var aim := AnimationNodeBlendSpace1D.new()
	aim.min_space = -1.0
	aim.max_space = 1.0
	aim.add_blend_point(_clip("Pistol_Aim_Down"), -1.0, -1, &"down")
	aim.add_blend_point(_clip("Pistol_Aim_Neutral"), 0.0, -1, &"neutral")
	aim.add_blend_point(_clip("Pistol_Aim_Up"), 1.0, -1, &"up")
	tree.add_node(&"aim", aim)

	var upper := AnimationNodeBlend2.new()
	_filter_upper_body(upper)
	tree.add_node(&"upper", upper)
	tree.connect_node(&"upper", 0, &"locomotion_speed")
	tree.connect_node(&"upper", 1, &"aim")

	# One-shot actions on the upper body.
	tree.add_node(&"reload_clip", _clip("Pistol_Reload"))
	tree.add_node(&"reload_speed", AnimationNodeTimeScale.new())
	tree.connect_node(&"reload_speed", 0, &"reload_clip")
	var reload := AnimationNodeOneShot.new()
	reload.fadein_time = 0.1
	reload.fadeout_time = 0.15
	_filter_upper_body(reload)
	tree.add_node(&"reload", reload)
	tree.connect_node(&"reload", 0, &"upper")
	tree.connect_node(&"reload", 1, &"reload_speed")

	var fire := AnimationNodeOneShot.new()
	fire.fadein_time = 0.02
	fire.fadeout_time = 0.12
	_filter_upper_body(fire)
	tree.add_node(&"fire_clip", _clip("Pistol_Shoot"))
	tree.add_node(&"fire", fire)
	tree.connect_node(&"fire", 0, &"reload")
	tree.connect_node(&"fire", 1, &"fire_clip")

	tree.connect_node(&"output", 0, &"fire")
	return tree


func _clip(animation_name: String) -> AnimationNodeAnimation:
	var clip := AnimationNodeAnimation.new()
	clip.animation = StringName(animation_name)
	return clip


## Restricts a blend node to the spine, head and arms.
func _filter_upper_body(node: AnimationNode) -> void:
	node.filter_enabled = true
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		var is_leg := bone_name.begins_with("thigh") or bone_name.begins_with("calf") \
				or bone_name.begins_with("foot") or bone_name.begins_with("ball")
		if bone_name != "root" and bone_name != "pelvis" and not is_leg:
			node.set_filter_path(NodePath("%s:%s" % [SKELETON_PATH, bone_name]), true)
