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

signal state_changed(new_state: State)

enum State {
	NORMAL,      ## Walking, running, jumping.
	DIVING,      ## In the air during a shootdodge.
	PRONE,       ## On the ground after a shootdodge. Can still shoot.
	GETTING_UP,  ## Standing back up.
}

## Physics layers the camera aim ray and bullets can hit (world, enemies, props).
const AIM_MASK := 0b1101
const AIM_DISTANCE := 200.0

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

@onready var visual: Node3D = $Visual
@onready var body: Node3D = $Visual/Body
@onready var model: CharacterModel = $Visual/Body/Model
@onready var pistol: Pistol = $Visual/Pistol
@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group(&"player")
	spring_arm.add_excluded_object(get_rid())
	# The root never rotates; the spawn orientation becomes the initial aim.
	_yaw = rotation.y
	rotation = Vector3.ZERO
	visual.rotation.y = _yaw
	_body_rest_height = body.position.y
	pistol.reload_started.connect(model.play_reload)
	_camera_rest_height = camera_yaw.position.y
	# Browsers only allow pointer lock after a user gesture, so on the web
	# the first click captures the mouse instead (see _unhandled_input).
	if not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	# Clicking the window grabs the mouse; that click must not fire.
	if event is InputEventMouseButton and event.pressed and not captured:
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
	var target_camera_height := prone_camera_height if state == State.PRONE else _camera_rest_height
	camera_yaw.position.y = lerpf(camera_yaw.position.y, target_camera_height, _blend(6.0, delta))

	_update_aim()
	_update_visual(delta)


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.NORMAL:
			_physics_normal(delta)
		State.DIVING:
			_physics_diving(delta)
		State.PRONE:
			_physics_prone(delta)
		State.GETTING_UP:
			_physics_getting_up(delta)
	move_and_slide()


# --- Input -------------------------------------------------------------------

## Actions are polled on state transitions instead of handled per event:
## analog triggers send a stream of motion events while held, which would
## otherwise turn the semi-automatic pistol into an automatic one.
func _process_actions() -> void:
	if Input.is_action_just_pressed(&"fire") and Engine.get_process_frames() != _capture_click_frame:
		_fire()
	if Input.is_action_just_pressed(&"reload"):
		pistol.reload()
	if Input.is_action_just_pressed(&"jump"):
		_try_jump()
	if Input.is_action_just_pressed(&"shootdodge"):
		_try_shootdodge()
	if Input.is_action_just_pressed(&"bullet_time"):
		BulletTime.toggle()


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
	if state == State.NORMAL and is_on_floor():
		velocity.y = jump_velocity


func _try_shootdodge() -> void:
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
	if state == State.GETTING_UP:
		return
	_update_aim()
	if pistol.try_fire(aim_point, [get_rid()]):
		model.play_fire()
		GameInput.rumble(0.3, 0.5, 0.08)
		_add_look(randf_range(-0.3, 0.3) * deg_to_rad(recoil_degrees), deg_to_rad(recoil_degrees))


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

	model.aim_at(aim_point)
	_hold_pistol()


## Picks the leg animation and returns how far (radians) the hips turn away
## from the aim: when strafing, the legs face the movement (running forwards
## or backwards, whichever is closer) and the spine twists back to the aim.
func _update_locomotion() -> float:
	var ground_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var speed := ground_velocity.length()
	match state:
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


## Keeps the pistol in the right hand, pointing exactly at the crosshair.
func _hold_pistol() -> void:
	var hand := model.get_hand_position()
	var to_target := aim_point - hand
	if to_target.length_squared() < 0.04:
		return
	var up := body.global_basis.y
	if absf(to_target.normalized().dot(up)) > 0.98:
		up = body.global_basis.z
	pistol.global_transform = Transform3D(Basis.looking_at(to_target, up), hand)


## Orientation of the body while diving: the head points along the dive and
## the chest turns towards the aim, so diving forward is a "superman" pose
## and diving backwards lands the player on their back.
func _get_dive_body_basis() -> Basis:
	var head := _dive_direction
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
