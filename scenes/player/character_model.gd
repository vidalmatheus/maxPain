class_name CharacterModel
extends Node3D
## Animated character: drives an AnimationTree that blends locomotion (legs)
## with pistol aiming (upper body) plus one-shot fire and reload actions.
## Procedural modifiers then pose the body on top of the animation: the dive
## pose for shootdodges, the spine twist towards the aim, arm IK that holds
## the guns on the aim line, and the head looking at the target.
##
## The tree is built in code so it is easy to read and review; the animations
## come from res://assets/characters/max_payne/animations.res. Deaths, the
## hurt stance and limp, reloads and warming the hands in the cold are the
## original Max Payne's (retargeted by tools/retarget_mp1.gd).

## Emitted every frame once the final pose (after all modifiers) is known;
## read the guns' places with [method get_gun_transform].
signal hands_posed

enum Locomotion { IDLE, RUN, RUN_BACK, AIR, CROUCH, DEAD }

const ANIMATIONS := preload("res://assets/characters/max_payne/animations.res")
const SKELETON_PATH := "Armature/Skeleton3D"
const LOCOMOTION_INPUTS := ["idle", "run", "run_back", "air", "crouch", "dead", "idle_hurt", "walk_hurt"]
const DEATHS := ["MP1_Death", "MP1_Death2"]
## Ground speed (m/s) at which the limp plays at normal speed.
const LIMP_SPEED := 1.6
## How fast the hands go to warming (and back), per second.
const WARM_FADE_SPEED := 2.5
## Ground speed (m/s) at which the jog animation plays at normal speed.
const JOG_SPEED := 4.5
## Aim pitch (radians) that maps to the full "aim up/down" poses.
const MAX_AIM_PITCH := deg_to_rad(60.0)
const MAX_TWIST := deg_to_rad(100.0)
## How fast the arm IK fades out for a reload and back in, per second.
const IK_FADE_SPEED := 8.0
## How far the chest turns with a pistol-whip, each way.
const STRIKE_TWIST := deg_to_rad(50.0)
## How fast the recoil of a shot settles, per second.
const RECOIL_RECOVERY := 7.0

@onready var rig: Node3D = $MaxPayne
@onready var skeleton: Skeleton3D = rig.get_node(SKELETON_PATH)

var _tree: AnimationTree
var _dive: DivePoseModifier
var _twist: AimTwistModifier
var _arms: ArmIKModifier
var _head: HeadLookModifier
var _locomotion := Locomotion.IDLE
var _locomotion_input := "idle"
var _dead := false
## Badly hurt: stands hunched and limps instead of jogging forward.
var hurt := false
## 0..1: how far into warming the hands (guns put away, IK off).
var _warm := 0.0
var _warming := false
var _reload_timer: SceneTreeTimer
## Seconds into the current pistol-whip, and how long it lasts (0 = none).
var _strike_time := 0.0
var _strike_duration := 0.0
## Gun transforms per hand, in skeleton space, from the last final pose.
var _gun_poses := {"r": Transform3D.IDENTITY, "l": Transform3D.IDENTITY}


func _ready() -> void:
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.add_animation_library(&"", ANIMATIONS)
	add_child(_tree)
	_tree.root_node = _tree.get_path_to(rig)
	_tree.tree_root = _build_tree()
	_tree.active = true
	_tree.set(&"parameters/upper/blend_amount", 1.0)

	# Modifiers run in child order: body pose, spine twist, arms, head.
	_dive = DivePoseModifier.new()
	_dive.influence = 0.0
	skeleton.add_child(_dive)
	_twist = AimTwistModifier.new()
	skeleton.add_child(_twist)
	_arms = ArmIKModifier.new()
	skeleton.add_child(_arms)
	_head = HeadLookModifier.new()
	skeleton.add_child(_head)
	# Bone poses read later in the frame no longer include the modifiers, so
	# grab the hands once the final pose is known (also when the modifiers
	# are off, e.g. dead).
	skeleton.skeleton_updated.connect(_on_pose_finished)


func _process(delta: float) -> void:
	# Into warming slowly, out of it quickly (to shoot).
	var warming := _warming and not _dead
	_warm = move_toward(_warm, 1.0 if warming else 0.0, (WARM_FADE_SPEED if warming else 4.0 * WARM_FADE_SPEED) * delta)
	_tree.set(&"parameters/warm/blend_amount", smoothstep(0.0, 1.0, _warm))
	_twist.influence = 1.0 - _warm
	_head.influence = 1.0 - _warm
	# Let the reload animation drive the arms while it plays.
	var ik_weight := 0.0 if _reload_timer != null or _warm > 0.0 else 1.0
	_arms.influence = move_toward(_arms.influence, ik_weight, IK_FADE_SPEED * delta)
	_arms.recoil = move_toward(_arms.recoil, 0.0, RECOIL_RECOVERY * delta)
	if _strike_duration > 0.0:
		_strike_time += delta
		_arms.strike = _strike_time / _strike_duration
		if _arms.strike >= 1.0:
			_arms.strike = 0.0
			_strike_duration = 0.0


## World transform of the gun in a hand ("r" or "l"), following the hand
## whether it is aiming (IK) or animated (reloading).
func get_gun_transform(side := "r") -> Transform3D:
	return skeleton.global_transform * _gun_poses[side]


func _on_pose_finished() -> void:
	for side in ["r", "l"]:
		var grip := &"right" if side == "r" else &"left"
		var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side))
		_gun_poses[side] = hand * _arms.gun_from_hand(side, grip)
	hands_posed.emit()


## Dual wield: both arms held out straight, each with a pistol. Otherwise a
## two-handed grip.
func set_dual(enabled: bool) -> void:
	_arms.stance = ArmIKModifier.Stance.DUAL if enabled else ArmIKModifier.Stance.TWO_HANDED


## Blends the shootdodge pose in ([param amount] 1) or out (0). [param along]
## says where the aim is relative to the dive: 1 when shooting where Max
## dives (head first, face down), -1 when shooting back over his feet (on his
## back, curled up to aim between the legs).
func set_dive_pose(amount: float, along: float) -> void:
	_dive.influence = amount
	_arms.extend = amount
	_dive.active = amount > 0.0
	if along >= 0.0:
		_dive.curl = lerpf(0.15, -0.25, along)
	else:
		_dive.curl = lerpf(0.15, 0.95, -along)
	_dive.leg_raise = maxf(-along, 0.0) * 0.5


func set_locomotion(locomotion: Locomotion, ground_speed: float) -> void:
	if _dead:
		return
	_locomotion = locomotion
	var input: String = LOCOMOTION_INPUTS[locomotion]
	if hurt and locomotion == Locomotion.IDLE:
		input = "idle_hurt"
	elif hurt and locomotion == Locomotion.RUN:
		input = "walk_hurt"
	if input != _locomotion_input:
		_locomotion_input = input
		_tree.set(&"parameters/locomotion/transition_request", input)
	var scale := 1.0
	if input == "walk_hurt":
		scale = clampf(ground_speed / LIMP_SPEED, 0.7, 2.4)
	elif locomotion == Locomotion.RUN or locomotion == Locomotion.RUN_BACK:
		scale = clampf(ground_speed / JOG_SPEED, 0.6, 1.4)
	_tree.set(&"parameters/locomotion_speed/scale", scale)


## Points the upper body at [param target] (world space): the spine twists
## towards it and the arms blend between the aim-down/neutral/up poses.
func aim_at(target: Vector3) -> void:
	var local := skeleton.global_basis.inverse() * (target - skeleton.global_position)
	if local.length_squared() < 0.01:
		return
	# The chest turns with a pistol-whip: right to wind up, left to swing.
	var swing := -ArmIKModifier.strike_side(_arms.strike) * STRIKE_TWIST
	_twist.yaw = clampf(atan2(local.x, local.z) + swing, -MAX_TWIST, MAX_TWIST)
	_arms.target = target
	_head.target = target
	var pitch := atan2(local.y - 1.4, Vector2(local.x, local.z).length())
	_tree.set(&"parameters/aim/blend_position", clampf(pitch / MAX_AIM_PITCH, -1.0, 1.0))


## Flinches as if hit in the chest.
func play_hit() -> void:
	if not _dead:
		_tree.set(&"parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Falls down dead: the whole body plays the death animation and the aiming
## modifiers let go.
func play_death() -> void:
	if _dead:
		return
	_dead = true
	_locomotion = Locomotion.DEAD
	_locomotion_input = "dead"
	# One of the original game's deaths, at random.
	var dead := (_tree.tree_root as AnimationNodeBlendTree).get_node(&"dead") as AnimationNodeAnimation
	dead.animation = StringName(DEATHS.pick_random())
	_tree.set(&"parameters/locomotion/transition_request", "dead")
	_tree.set(&"parameters/locomotion_speed/scale", 1.0)
	_tree.set(&"parameters/upper/blend_amount", 0.0)
	for request in [&"fire", &"reload", &"hit"]:
		_tree.set(StringName("parameters/%s/request" % request), AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_twist.active = false
	_arms.active = false
	_head.active = false
	_dive.active = false


## Stands back up after [method play_death].
func revive() -> void:
	if not _dead:
		return
	_dead = false
	_locomotion = Locomotion.IDLE
	_locomotion_input = "idle"
	_tree.set(&"parameters/locomotion/transition_request", "idle")
	_tree.set(&"parameters/upper/blend_amount", 1.0)
	_twist.active = true
	_arms.active = true
	_head.active = true


## Recolors the clothes: a multiplier for the jacket and one for the pants.
## Each character gets its own materials.
func set_clothes_tint(jacket: Color, pants: Color) -> void:
	var body := rig.find_child("Body", true, false) as MeshInstance3D
	for surface in body.mesh.get_surface_count():
		var part: String = (body.mesh as ArrayMesh).surface_get_name(surface)
		var tint: Color = jacket if part.begins_with("jacket") else pants if part.begins_with("pants") else Color.WHITE
		if tint == Color.WHITE:
			continue
		var material := body.get_active_material(surface).duplicate() as BaseMaterial3D
		material.albedo_color *= tint
		body.set_surface_override_material(surface, material)


func play_fire() -> void:
	_arms.recoil = 1.0
	_tree.set(&"parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Swings the gun in a pistol-whip lasting [param duration] seconds. The
## blow lands halfway through.
func play_melee(duration: float) -> void:
	_strike_time = 0.0
	_strike_duration = duration


## Puts the guns away and warms the hands in the cold ([param enabled]), or
## takes them back out.
func set_warming(enabled: bool) -> void:
	_warming = enabled


## Whether the hands are (going) to warming, guns away.
func is_warming() -> bool:
	return _warm > 0.0


## Plays the reload animation (one pistol or two) stretched to
## [param duration] seconds.
func play_reload(duration: float) -> void:
	var clip := &"MP1_Reload_Dual" if _arms.stance == ArmIKModifier.Stance.DUAL else &"MP1_Reload"
	((_tree.tree_root as AnimationNodeBlendTree).get_node(&"reload_clip") as AnimationNodeAnimation).animation = clip
	var length := ANIMATIONS.get_animation(clip).length
	_tree.set(&"parameters/reload_speed/scale", length / maxf(duration, 0.1))
	_tree.set(&"parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_reload_timer = get_tree().create_timer(duration, false)
	_reload_timer.timeout.connect(_on_reload_finished.bind(_reload_timer))


func _on_reload_finished(timer: SceneTreeTimer) -> void:
	if timer == _reload_timer:
		_reload_timer = null


func _build_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()

	# Legs: idle / jog forward / jog backward / airborne / crouch.
	var locomotion := AnimationNodeTransition.new()
	locomotion.input_count = LOCOMOTION_INPUTS.size()
	locomotion.xfade_time = 0.15
	for i in LOCOMOTION_INPUTS.size():
		locomotion.set_input_name(i, LOCOMOTION_INPUTS[i])
	tree.add_node(&"locomotion", locomotion)
	var clips := ["Pistol_Idle_Loop", "Jog_Fwd_Loop", "Jog_Fwd_Loop", "Jump_Loop", "Crouch_Idle_Loop", DEATHS[0],
			"MP1_Stand_Hurt", "MP1_Walk_Hurt"]
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
	tree.add_node(&"reload_clip", _clip("MP1_Reload"))
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

	# Flinch when shot.
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.05
	hit.fadeout_time = 0.2
	_filter_upper_body(hit)
	tree.add_node(&"hit_clip", _clip("Hit_Chest"))
	tree.add_node(&"hit", hit)
	tree.connect_node(&"hit", 0, &"fire")
	tree.connect_node(&"hit", 1, &"hit_clip")

	# Warming the hands, for the whole body.
	var warm := AnimationNodeBlend2.new()
	tree.add_node(&"warm_clip", _clip("MP1_Warming_Hands"))
	tree.add_node(&"warm", warm)
	tree.connect_node(&"warm", 0, &"hit")
	tree.connect_node(&"warm", 1, &"warm_clip")

	tree.connect_node(&"output", 0, &"warm")
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
