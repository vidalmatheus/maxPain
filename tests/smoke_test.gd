extends Node
## Headless smoke test for the core mechanics.
##
## Run with:  godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures := 0


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await _frames(30)

	var bullet_time := BulletTime
	var player: Player = main.get_node("Player")
	# Target3 has a clear line of fire from the spawn point.
	var target: TargetDummy = main.get_node("Targets/Target3")

	_check(player.is_on_floor(), "player lands on the floor")
	_check(player.state == Player.State.NORMAL, "player starts in NORMAL state")

	# --- Walking -------------------------------------------------------------
	var start := player.global_position
	Input.action_press(&"move_forward")
	await _frames(40)
	Input.action_release(&"move_forward")
	_check(player.global_position.z < start.z - 1.0, "player walks forward (-Z)")

	# --- Shooting: bullets travel and damage targets ------------------------
	player.pistol.spread_degrees = 0.0  # Deterministic shots.
	var chest := target.global_position + Vector3(0.0, 1.0, 0.0)
	var ammo_before := player.pistol.ammo_in_magazine
	_check(player.pistol.try_fire(chest, [player.get_rid()]), "pistol fires")
	_check(player.pistol.ammo_in_magazine == ammo_before - 1, "firing consumes ammo")
	_check(get_tree().get_nodes_in_group(&"shell_casings").size() == 1, "firing ejects a shell casing")
	await _frames(30)
	_check(target.health < target.max_health, "bullet travels and damages the target")

	# Kill it and check the adrenaline reward.
	bullet_time.adrenaline = 50.0
	for i in 5:
		await _frames(12)
		player.pistol.try_fire(chest, [player.get_rid()])
	await _frames(30)
	_check(target.is_dead, "target dies after enough hits")
	_check(bullet_time.adrenaline > 50.0, "kill rewards adrenaline")

	# --- Bullet time toggle ---------------------------------------------------
	bullet_time.adrenaline = bullet_time.max_adrenaline
	bullet_time.toggle()
	await _frames(30)
	_check(bullet_time.is_active, "bullet time activates")
	_check(Engine.time_scale < 0.5, "time scale slows down (%.2f)" % Engine.time_scale)
	bullet_time.toggle()
	await _frames(30)
	_check(not bullet_time.is_active, "bullet time deactivates")
	_check(is_equal_approx(Engine.time_scale, 1.0), "time scale returns to 1.0")

	# --- Shootdodge -----------------------------------------------------------
	Input.action_press(&"move_left")
	await _frames(2)
	player.call(&"_try_shootdodge")
	_check(player.state == Player.State.DIVING, "shootdodge starts a dive")
	_check(bullet_time.is_active, "shootdodge triggers bullet time")
	await _frames(10)
	_check(not player.is_on_floor(), "player is airborne during the dive")
	_check(player.pistol.try_fire(player.global_position + Vector3(0, 1, -20), [player.get_rid()]), "can fire while diving")
	Input.action_release(&"move_left")

	var waited := 0
	while player.state == Player.State.DIVING and waited < 600:
		await _frames(1)
		waited += 1
	_check(player.state == Player.State.PRONE, "dive ends prone on the ground")
	_check(not bullet_time.is_active, "landing ends shootdodge bullet time")

	# Getting up.
	await _frames(40)
	Input.action_press(&"move_forward")
	await _frames(60)
	Input.action_release(&"move_forward")
	_check(player.state == Player.State.NORMAL, "player gets back up")

	# --- Gamepad ------------------------------------------------------------------
	_check(GameInput.detect_layout("DualSense Wireless Controller") == GameInput.Layout.PLAYSTATION, "detects a DualSense (PS5)")
	_check(GameInput.detect_layout("PS4 Controller") == GameInput.Layout.PLAYSTATION, "detects a DualShock 4 (PS4)")
	_check(GameInput.detect_layout("Unknown", {"vendor_id": 1356}) == GameInput.Layout.PLAYSTATION, "detects Sony by USB vendor id")
	_check(GameInput.detect_layout("Xbox Series X Controller") == GameInput.Layout.XBOX, "detects an Xbox controller")
	_check(GameInput.detect_layout("Generic USB Gamepad") == GameInput.Layout.XBOX, "unknown pads use Xbox prompts")

	# Holding the trigger fires once (semi-automatic), even though an analog
	# trigger keeps sending motion events while held.
	player.pistol.reload()
	await _frames(120)
	var ammo_start := player.pistol.ammo_in_magazine
	for value in [0.4, 0.8, 1.0, 0.97, 1.0, 0.98, 1.0, 0.97, 1.0, 0.99]:
		_send_axis(JOY_AXIS_TRIGGER_RIGHT, value)
		await _frames(6)
	_check(player.pistol.ammo_in_magazine == ammo_start - 1, "holding the trigger fires a single shot")
	_check(GameInput.is_using_gamepad(), "gamepad input switches the active layout")
	_check(GameInput.prompt(&"fire") == "RT", "prompts follow the gamepad layout")
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(6)
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(6)
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(2)
	_check(player.pistol.ammo_in_magazine == ammo_start - 2, "pulling the trigger again fires again")

	# Right stick aims.
	var yaw_before: float = player.get(&"_yaw")
	_send_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(20)
	_send_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(2)
	_check(player.get(&"_yaw") < yaw_before - 0.1, "right stick turns the camera")

	# Keyboard input switches the prompts back.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(2)
	_check(not GameInput.is_using_gamepad(), "keyboard input switches back to keyboard prompts")

	# --- Reload -----------------------------------------------------------------
	player.pistol.reload()
	_check(player.pistol.is_reloading(), "reload starts")
	await _frames(120)
	_check(player.pistol.ammo_in_magazine == player.pistol.magazine_size, "reload refills the magazine")

	# --- Dual Berettas -----------------------------------------------------------
	_check(player.pistol.magazine_size == 15, "a Beretta magazine holds 15 rounds")
	var shooters: Array[GunModel] = []
	player.pistol.fired.connect(func(gun: GunModel) -> void: shooters.append(gun))
	var key_2 := InputEventKey.new()
	key_2.physical_keycode = KEY_2
	key_2.pressed = true
	Input.parse_input_event(key_2)
	await _frames(2)
	key_2 = key_2.duplicate()
	key_2.pressed = false
	Input.parse_input_event(key_2)
	await _frames(30)
	_check(player.pistol.dual, "key 2 switches to dual Berettas")
	_check(player.pistol.ammo_in_magazine == 30, "dual Berettas hold 30 rounds")
	_check(player.pistol.left_gun.visible, "the second Beretta appears in the left hand")
	for i in 2:
		player.pistol.try_fire(chest, [player.get_rid()])
		await _frames(8)
	_check(shooters.size() == 2 and shooters[0] != shooters[1], "dual Berettas fire alternately")
	player.pistol.reload()
	await _frames(2)
	_check(get_tree().get_nodes_in_group(&"dropped_magazines").size() >= 2, "reloading drops both magazines")
	_check(not player.pistol.left_gun.has_magazine(), "guns are empty while reloading")
	await _frames(150)
	_check(player.pistol.ammo_in_magazine == 30, "dual reload refills both magazines")
	_check(player.pistol.right_gun.has_magazine() and player.pistol.left_gun.has_magazine(), "fresh magazines are inserted")

	# --- Touch controls -----------------------------------------------------------
	var touch: TouchControls = main.get_node("HUD/TouchControls")
	var stick := Vector2(200.0, touch.size.y - 150.0)
	_send_touch(0, stick, true)
	await _frames(2)
	_check(GameInput.is_using_touch() and touch.visible, "touching the screen shows the touch controls")
	var touch_start := player.global_position
	_send_drag(0, stick + Vector2(0, -80), Vector2(0, -80))
	await _frames(30)
	_check(player.global_position.distance_to(touch_start) > 0.5, "the touch joystick moves the player")
	_send_touch(0, stick + Vector2(0, -80), false)
	await _frames(10)

	var fire_button := touch.size + Vector2(-150, -190)
	var ammo_before_tap := player.pistol.ammo_in_magazine
	_send_touch(1, fire_button, true)
	await _frames(2)
	_send_touch(1, fire_button, false)
	await _frames(2)
	_check(player.pistol.ammo_in_magazine == ammo_before_tap - 1, "the FIRE button shoots")

	var yaw_before_drag: float = player.get(&"_yaw")
	var look_start := Vector2(touch.size.x * 0.7, touch.size.y * 0.4)
	_send_touch(2, look_start, true)
	_send_drag(2, look_start + Vector2(60, 0), Vector2(60, 0))
	await _frames(2)
	_send_touch(2, look_start + Vector2(60, 0), false)
	_check(not is_equal_approx(player.get(&"_yaw"), yaw_before_drag), "dragging on the right side aims")

	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## Touch events arrive in window coordinates; [param position] is given in
## canvas (UI) coordinates and converted, like a real screen would report it.
func _send_touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_drag(index: int, position: Vector2, relative: Vector2) -> void:
	var to_window := get_viewport().get_final_transform()
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to_window * position
	event.relative = to_window.basis_xform(relative)
	Input.parse_input_event(event)


func _send_axis(axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok    %s" % description)
	else:
		_failures += 1
		print("  FAIL  %s" % description)
