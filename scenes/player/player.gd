class_name Player
extends CharacterBody3D
## Third-person player controller inspired by Max Payne.
##
## Features an over-the-shoulder camera, strafing movement (the character
## always faces where the camera aims), jumping, firing the pistol and the
## signature shootdodge: a slow-motion dive during which you keep shooting.
##
## Mouse aiming is driven by raw input events, so it stays fully responsive
## while the rest of the world is slowed down by bullet time.
##
## Max can take cover behind walls, cars and barriers (crouching behind low
## cover and popping up to shoot), gets hurt by enemy bullets and heals with
## painkillers, like in the original game.

signal state_changed(new_state: State)
signal health_changed(health: float, max_health: float)
## Emitted when a bullet hits Max, with the damage taken.
signal hurt(damage: float)
signal painkillers_changed(count: int)
signal died

enum State {
	NORMAL,      ## Walking, running, jumping.
	DIVING,      ## In the air during a shootdodge.
	PRONE,       ## On the ground after a shootdodge. Can still shoot.
	GETTING_UP,  ## Standing back up.
	COVER,       ## Behind cover: crouched behind low cover, popping up to shoot.
	DEAD,
}

## Physics layers the camera aim ray and bullets can hit (world, enemies, props).
const AIM_MASK := 0b1101
const AIM_DISTANCE := 200.0
const BLOOD_COLOR := Color(0.6, 0.04, 0.04)
## Collision capsule height standing and crouched behind cover.
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1

@export_group("Movement")
@export var run_speed := 5.5
## Speed multiplier when moving away from the aim direction.
@export var backpedal_multiplier := 0.75
@export var acceleration := 40.0
@export var air_acceleration := 6.0
@export var jump_velocity := 5.0
@export var gravity := 14.0

@export_group("Shootdodge")
@export var dive_speed := 7.5
@export var dive_up_velocity := 4.0
@export var dive_gravity := 12.0
## Minimum time spent on the ground before the player can get up.
@export var prone_min_time := 0.35
@export var getting_up_time := 0.35
## Deceleration while sliding on the ground after landing.
@export var prone_friction := 10.0
@export var prone_body_height := 0.22
@export var prone_camera_height := 0.8

@export_group("Health")
@export var max_health := 100.0
## Health restored by one painkiller, over painkiller_time game seconds.
@export var painkiller_heal := 40.0
@export var painkiller_time := 1.2
@export var max_painkillers := 8

@export_group("Cover")
## How far away cover can be taken.
@export var cover_reach := 1.9
## Distance kept between the body's center and the cover.
@export var cover_offset := 0.45
@export var cover_speed := 2.6
## Cover lower than this is crouched behind; higher cover is stood against.
@export var low_cover_height := 1.45
## How long Max stays up after shooting from low cover.
@export var cover_popup_time := 0.9
## Delay between popping up and the shot, so the gun clears the cover.
@export var cover_popup_delay := 0.15
@export var cover_camera_height := 1.05

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var min_pitch_degrees := -70.0
@export var max_pitch_degrees := 65.0
@export var recoil_degrees := 1.2
## How fast the visual model turns and leans (per second of game time).
@export var body_turn_speed := 14.0

@export_group("Gamepad aiming")
## Turn speeds at full stick deflection, in radians per real second.
@export var gamepad_yaw_speed := 3.2
@export var gamepad_pitch_speed := 2.2
## Response curve exponent: values above 1 give finer control near the center.
@export var gamepad_look_exponent := 1.8
## Extra turn speed after holding the stick at the edge for a moment.
@export var gamepad_turn_boost := 1.6
@export var gamepad_turn_boost_delay := 0.25
## Look speed multiplier while the crosshair is over an enemy ("aim friction").
@export var aim_friction := 0.45

var state := State.NORMAL
## World position the crosshair is currently pointing at.
var aim_point := Vector3.ZERO

var _yaw := 0.0
var _pitch := 0.0
var _state_time := 0.0
var _dive_direction := Vector3.FORWARD
var _body_rest_height := 0.0
var _camera_rest_height := 0.0
var _aiming_at_enemy := false
var _look_hold_time := 0.0
## Process frame in which a click captured the mouse; that click must not fire.
var _capture_click_frame := -1
## Whether the legs currently play the run cycle backwards (with hysteresis).
var _running_backwards := false
## 0..1, how far the body is in the shootdodge pose.
var _dive_pose := 0.0

var health := 0.0
var painkillers := 0
## Health still to be restored by the painkillers taken.
var _healing := 0.0

## Cover: the surface's outward normal (horizontal) and whether it is low.
var _cover_normal := Vector3.BACK
var _cover_low := false
var _cover_popup := 0.0
## Time left before a shot queued while popping up from cover.
var _pending_fire := -1.0

@onready var visual: Node3D = $Visual
@onready var body: Node3D = $Visual/Body
@onready var model: CharacterModel = $Visual/Body/Model
@onready var pistol: Pistol = $Visual/Pistol
@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(&"player")
	health = max_health
	# Every player gets its own capsule, which shrinks when crouching.
	collision_shape.shape = collision_shape.shape.duplicate()
	spring_arm.add_excluded_object(get_rid())
	# The root never rotates; the spawn orientation becomes the initial aim.
	_yaw = rotation.y
	rotation = Vector3.ZERO
	visual.rotation.y = _yaw
	_body_rest_height = body.position.y
	pistol.reload_started.connect(model.play_reload)
	pistol.mode_changed.connect(model.set_dual)
	model.hands_posed.connect(_hold_pistols)
	_camera_rest_height = camera_yaw.position.y
	# Browsers only allow pointer lock after a user gesture, so on the web
	# the first click captures the mouse instead (see _unhandled_input).
	if not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	# Clicking the window grabs the mouse; that click must not fire. Not on
	# touch screens, where there is no mouse to capture, nor once dead (the
	# game over screen needs the pointer).
	if event is InputEventMouseButton and event.pressed and not captured and not GameInput.is_using_touch() \
			and state != State.DEAD:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_capture_click_frame = Engine.get_process_frames()
		get_viewport().set_input_as_handled()
		return

	# Browsers can report a bogus jump right after locking the pointer.
	var just_captured := Engine.get_process_frames() - _capture_click_frame <= 1
	if event is InputEventMouseMotion and captured and not just_captured:
		var motion := event as InputEventMouseMotion
		_add_look(-motion.relative.x * mouse_sensitivity, -motion.relative.y * mouse_sensitivity)
	elif event.is_action_pressed(&"release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_process_actions()
	_process_gamepad_look(BulletTime.to_real_delta(delta))

	camera_yaw.rotation.y = _yaw
	camera_pitch.rotation.x = _pitch
	var target_camera_height := _camera_rest_height
	if state == State.PRONE or state == State.DEAD:
		target_camera_height = prone_camera_height
	elif is_crouching():
		target_camera_height = cover_camera_height
	camera_yaw.position.y = lerpf(camera_yaw.position.y, target_camera_height, _blend(6.0, delta))

	_update_aim()
	_update_visual(delta)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_process_healing(delta)
	match state:
		State.NORMAL:
			_physics_normal(delta)
		State.DIVING:
			_physics_diving(delta)
		State.PRONE:
			_physics_prone(delta)
		State.GETTING_UP:
			_physics_getting_up(delta)
		State.COVER:
			_physics_cover(delta)
		State.DEAD:
			_physics_getting_up(delta)
	_update_collision_height()
	move_and_slide()


# --- Input -------------------------------------------------------------------

## Actions are polled on state transitions instead of handled per event:
## analog triggers send a stream of motion events while held, which would
## otherwise turn the semi-automatic pistol into an automatic one.
func _process_actions() -> void:
	if state == State.DEAD:
		return
	if _pending_fire >= 0.0:
		_pending_fire -= get_process_delta_time()
		if _pending_fire < 0.0:
			_fire()
	if Input.is_action_just_pressed(&"fire") and Engine.get_process_frames() != _capture_click_frame:
		_fire()
	if Input.is_action_just_pressed(&"take_cover"):
		if state == State.COVER:
			_leave_cover()
		else:
			try_take_cover()
	if Input.is_action_just_pressed(&"use_painkiller"):
		use_painkiller()
	if Input.is_action_just_pressed(&"reload"):
		pistol.reload()
	if Input.is_action_just_pressed(&"jump"):
		_try_jump()
	if Input.is_action_just_pressed(&"shootdodge"):
		_try_shootdodge()
	if Input.is_action_just_pressed(&"bullet_time"):
		BulletTime.toggle()
	if Input.is_action_just_pressed(&"weapon_beretta"):
		pistol.set_dual(false)
	if Input.is_action_just_pressed(&"weapon_dual_berettas"):
		pistol.set_dual(true)
	if Input.is_action_just_pressed(&"next_weapon"):
		pistol.set_dual(not pistol.dual)


## Right-stick aiming. Uses real time so it is not slowed by bullet time.
func _process_gamepad_look(real_delta: float) -> void:
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	var magnitude := look.length()
	if magnitude < 0.001:
		_look_hold_time = 0.0
		return

	var curved := look / magnitude * pow(minf(magnitude, 1.0), gamepad_look_exponent)
	_look_hold_time = _look_hold_time + real_delta if magnitude > 0.95 else 0.0
	var boost := gamepad_turn_boost if _look_hold_time > gamepad_turn_boost_delay else 1.0
	var friction := aim_friction if _aiming_at_enemy else 1.0
	var scale := boost * friction * real_delta
	_add_look(-curved.x * gamepad_yaw_speed * scale, -curved.y * gamepad_pitch_speed * scale)


# --- State logic -------------------------------------------------------------

func _physics_normal(delta: float) -> void:
	var direction := _get_move_direction()
	var speed := run_speed
	if direction.dot(_get_aim_forward()) < -0.3:
		speed *= backpedal_multiplier

	var accel := acceleration if is_on_floor() else air_acceleration
	_accelerate_horizontal(direction * speed, accel * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta


func _physics_diving(delta: float) -> void:
	# No steering mid-air: the dive is committed, only aiming is free.
	velocity.y -= dive_gravity * delta
	if _state_time > 0.15 and is_on_floor():
		_set_state(State.PRONE)
		BulletTime.end_shootdodge()
		GameInput.rumble(0.4, 0.8, 0.25)


func _physics_prone(delta: float) -> void:
	_accelerate_horizontal(Vector3.ZERO, prone_friction * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta

	var wants_up := _get_move_direction() != Vector3.ZERO or Input.is_action_pressed(&"jump")
	if _state_time >= prone_min_time and wants_up:
		_set_state(State.GETTING_UP)


func _physics_getting_up(delta: float) -> void:
	_accelerate_horizontal(Vector3.ZERO, prone_friction * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _state_time >= getting_up_time:
		_set_state(State.NORMAL)


func _try_jump() -> void:
	if state == State.COVER:
		_leave_cover()
	if state == State.NORMAL and is_on_floor():
		velocity.y = jump_velocity


func _try_shootdodge() -> void:
	if state == State.COVER:
		_leave_cover()
	if state != State.NORMAL or not is_on_floor():
		return

	var direction := _get_move_direction()
	if direction == Vector3.ZERO:
		# Like the original game: the dodge button while standing still
		# simply toggles bullet time.
		BulletTime.toggle()
		return

	_dive_direction = direction.normalized()
	velocity = _dive_direction * dive_speed + Vector3.UP * dive_up_velocity
	_set_state(State.DIVING)
	BulletTime.start_shootdodge()


func _fire() -> void:
	if state == State.GETTING_UP or state == State.DEAD:
		return
	if state == State.COVER:
		var was_down := is_crouching()
		_cover_popup = cover_popup_time
		if was_down:
			# Stand up first so the shot clears the cover.
			_pending_fire = cover_popup_delay
			return
	_update_aim()
	if pistol.try_fire(aim_point, [get_rid()]):
		model.play_fire()
		GameInput.rumble(0.3, 0.5, 0.08)
		_add_look(randf_range(-0.3, 0.3) * deg_to_rad(recoil_degrees), deg_to_rad(recoil_degrees))


# --- Cover ---------------------------------------------------------------------

## Whether Max is ducked behind low cover (not popped up to shoot).
func is_crouching() -> bool:
	return state == State.COVER and _cover_low and _cover_popup <= 0.0 and _pending_fire < 0.0


## Looks for a wall, car or barrier within reach (in the direction Max is
## moving, or else where he aims) and takes cover behind it. Returns true if
## there was cover to take.
func try_take_cover() -> bool:
	if state != State.NORMAL or not is_on_floor():
		return false
	var facing := _get_move_direction()
	if facing == Vector3.ZERO:
		facing = _get_aim_forward()
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.6, 0)
	var best: Dictionary = {}
	var best_distance := INF
	for degrees in [0.0, -25.0, 25.0, -50.0, 50.0, -75.0, 75.0]:
		var direction := facing.rotated(Vector3.UP, deg_to_rad(degrees))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * cover_reach, 1, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not (hit.collider as Node).is_in_group(&"cover"):
			continue
		var distance := origin.distance_to(hit.position)
		if distance < best_distance:
			best_distance = distance
			best = hit
	if best.is_empty():
		return false
	var normal := Vector3(best.normal.x, 0.0, best.normal.z)
	if normal.length_squared() < 0.01:
		return false
	_cover_normal = normal.normalized()
	_cover_low = _cover_height(best.position) < low_cover_height
	_cover_popup = 0.0
	_set_state(State.COVER)
	return true


## Height of the top of the cover at [param point] (on its surface).
func _cover_height(point: Vector3) -> float:
	var inside := point - _cover_normal * 0.15
	var from := Vector3(inside.x, global_position.y + 3.0, inside.z)
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(inside.x, global_position.y - 0.5, inside.z), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y - global_position.y if not hit.is_empty() else 3.0


func _leave_cover() -> void:
	if state == State.COVER:
		_pending_fire = -1.0
		_set_state(State.NORMAL)


func _physics_cover(delta: float) -> void:
	_cover_popup = maxf(_cover_popup - delta, 0.0)
	var input := _get_move_direction()
	# Pushing away from the cover leaves it.
	if input.dot(_cover_normal) > 0.7:
		_leave_cover()
		return
	var along := Vector3.UP.cross(_cover_normal).normalized()
	var slide := along * input.dot(along) * cover_speed
	# Stop at the edge of the cover instead of sliding off it.
	if slide.length_squared() > 0.01 and _distance_to_cover(slide.normalized() * 0.35) < 0.0:
		slide = Vector3.ZERO
	# Stay pressed against the cover.
	var gap := _distance_to_cover(Vector3.ZERO)
	if gap < 0.0:
		_leave_cover()  # The cover is gone (e.g. walked past its end).
		return
	var hug := -_cover_normal * clampf((gap - cover_offset) * 8.0, -2.0, 2.0)
	_accelerate_horizontal(slide + hug, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta


## Distance from Max (moved by [param offset]) to the cover behind him, or -1
## if there is no cover there.
func _distance_to_cover(offset: Vector3) -> float:
	var origin := global_position + offset + Vector3(0, 0.5, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, origin - _cover_normal * 1.2, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit.collider as Node).is_in_group(&"cover"):
		return -1.0
	return origin.distance_to(hit.position)


## Shrinks the capsule while crouched behind cover, so bullets hit the cover.
func _update_collision_height() -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	var height := CROUCH_HEIGHT if is_crouching() else STAND_HEIGHT
	if not is_equal_approx(capsule.height, height):
		capsule.height = height
		collision_shape.position.y = height * 0.5


# --- Health ----------------------------------------------------------------------

## Where enemies aim: the chest, lower when ducking or lying down.
func get_target_point() -> Vector3:
	if state == State.PRONE or state == State.DIVING or state == State.DEAD:
		return global_position + Vector3(0, 0.5, 0)
	return global_position + Vector3(0, 0.75 if is_crouching() else 1.3, 0)


## Called by bullets.
func take_hit(damage: float, point: Vector3, direction: Vector3) -> void:
	ImpactEffect.spawn(get_parent(), point, -direction, BLOOD_COLOR)
	if state == State.DEAD:
		return
	health = maxf(health - damage, 0.0)
	health_changed.emit(health, max_health)
	hurt.emit(damage)
	model.play_hit()
	GameInput.rumble(0.6, 0.4, 0.15)
	if health <= 0.0:
		_die()


func _die() -> void:
	_healing = 0.0
	_pending_fire = -1.0
	_set_state(State.DEAD)
	BulletTime.end_shootdodge()
	model.play_death()
	velocity.x = 0.0
	velocity.z = 0.0
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	died.emit()


## Takes a painkiller, which heals over a moment. Returns true if one was taken.
func use_painkiller() -> bool:
	if state == State.DEAD or painkillers <= 0 or health + _healing >= max_health:
		return false
	painkillers -= 1
	_healing += painkiller_heal
	painkillers_changed.emit(painkillers)
	return true


## Picks up a painkiller bottle. Returns false when Max can't carry more.
func add_painkiller() -> bool:
	if painkillers >= max_painkillers:
		return false
	painkillers += 1
	painkillers_changed.emit(painkillers)
	return true


func _process_healing(delta: float) -> void:
	if _healing <= 0.0 or state == State.DEAD:
		return
	var step := minf(painkiller_heal / painkiller_time * delta, _healing)
	_healing -= step
	health = minf(health + step, max_health)
	health_changed.emit(health, max_health)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	state_changed.emit(new_state)


# --- Aim and visuals ---------------------------------------------------------

func _update_aim() -> void:
	var forward := -camera.global_basis.z
	# Start the ray roughly at the player's depth so objects between the
	# camera and the character never steal the aim.
	var from := camera.global_position + forward * spring_arm.get_hit_length()
	var to := from + forward * AIM_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, to, AIM_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	aim_point = hit["position"] if not hit.is_empty() else to
	var collider: Object = hit.get("collider")
	_aiming_at_enemy = collider is Node and (collider as Node).is_in_group(&"enemies")


func _update_visual(delta: float) -> void:
	var weight := _blend(body_turn_speed, delta)
	var locomotion := _update_locomotion()
	visual.rotation.y = lerp_angle(visual.rotation.y, _yaw + locomotion, weight)

	var target_basis := visual.global_basis
	var target_height := _body_rest_height
	match state:
		State.DIVING:
			target_basis = _get_dive_body_basis()
		State.PRONE:
			target_basis = _get_dive_body_basis()
			target_height = prone_body_height

	var current := body.global_basis.get_rotation_quaternion()
	body.global_basis = Basis(current.slerp(target_basis.get_rotation_quaternion(), weight))
	body.position.y = lerpf(body.position.y, target_height, weight)

	var diving := state == State.DIVING or state == State.PRONE
	_dive_pose = move_toward(_dive_pose, 1.0 if diving else 0.0, delta * (8.0 if diving else 4.0))
	model.set_dive_pose(_dive_pose, _get_aim_forward().dot(_dive_direction))
	model.aim_at(aim_point)


## Picks the leg animation and returns how far (radians) the hips turn away
## from the aim: when strafing, the legs face the movement (running forwards
## or backwards, whichever is closer) and the spine twists back to the aim.
func _update_locomotion() -> float:
	var ground_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var speed := ground_velocity.length()
	match state:
		State.DEAD:
			return 0.0
		State.COVER:
			if is_crouching():
				model.set_locomotion(CharacterModel.Locomotion.CROUCH, 0.0)
				return 0.0
		State.DIVING:
			model.set_locomotion(CharacterModel.Locomotion.AIR, 0.0)
			return 0.0
		State.PRONE:
			model.set_locomotion(CharacterModel.Locomotion.IDLE, 0.0)
			return 0.0
		State.GETTING_UP:
			model.set_locomotion(CharacterModel.Locomotion.CROUCH, 0.0)
			return 0.0
	if not is_on_floor():
		model.set_locomotion(CharacterModel.Locomotion.AIR, 0.0)
		return 0.0
	if speed < 0.5:
		model.set_locomotion(CharacterModel.Locomotion.IDLE, 0.0)
		return 0.0

	var relative := wrapf(atan2(-ground_velocity.x, -ground_velocity.z) - _yaw, -PI, PI)
	var threshold := PI * 0.5 + (-0.25 if _running_backwards else 0.25)
	_running_backwards = absf(relative) > threshold
	if _running_backwards:
		model.set_locomotion(CharacterModel.Locomotion.RUN_BACK, speed)
		return wrapf(relative - PI, -PI, PI)
	model.set_locomotion(CharacterModel.Locomotion.RUN, speed)
	return relative


## Keeps each pistol in its hand. The arm IK puts the hands on the aim line,
## so the guns point at the crosshair.
func _hold_pistols() -> void:
	pistol.right_gun.global_transform = model.get_gun_transform("r")
	if pistol.dual:
		pistol.left_gun.global_transform = model.get_gun_transform("l")


## Orientation of the body while diving: the head points along the dive and
## the chest turns towards the aim, so diving forward is a "superman" pose
## and diving backwards lands the player on their back. In the air the body
## follows the arc of the jump: head up while rising, down while falling.
func _get_dive_body_basis() -> Basis:
	var head := _dive_direction
	if state == State.DIVING:
		var climb := clampf(velocity.y / dive_speed, -0.6, 0.6) * 0.5
		head = (_dive_direction + Vector3.UP * climb).normalized()
	var aim_flat := _get_aim_forward()
	var along := aim_flat.dot(head)
	var chest := (aim_flat - head * along) + Vector3.DOWN * along
	if chest.length_squared() < 0.0001:
		chest = Vector3.DOWN
	var back := -chest.normalized()
	var right := head.cross(back).normalized()
	back = right.cross(head).normalized()
	return Basis(right, head, back)


# --- Helpers -----------------------------------------------------------------

## Turns the camera by the given angles (radians). Used by the touch controls.
func look(yaw_delta: float, pitch_delta: float) -> void:
	_add_look(yaw_delta, pitch_delta)


func _add_look(yaw_delta: float, pitch_delta: float) -> void:
	_yaw = wrapf(_yaw + yaw_delta, -PI, PI)
	_pitch = clampf(_pitch + pitch_delta, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


## Movement input relative to the camera, on the ground plane.
func _get_move_direction() -> Vector3:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if input.length_squared() < 0.01:
		return Vector3.ZERO
	return Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)


## Camera forward direction flattened onto the ground plane.
func _get_aim_forward() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


func _accelerate_horizontal(target: Vector3, max_step: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, max_step)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Frame-rate independent interpolation weight.
func _blend(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)
