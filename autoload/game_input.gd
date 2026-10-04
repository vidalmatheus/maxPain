extends Node
## Registers the default input bindings, tracks the active input device and
## handles global shortcuts.
##
## Bindings are defined in code (instead of the Input Map in project.godot)
## so they are easy to read, review and extend. If an action already exists
## in the project settings it is left untouched, so it can still be remapped
## from the editor. Physical keycodes are used so WASD works on any layout.
##
## Gamepads use the standard (SDL) layout, so Xbox, PlayStation (DualSense,
## DualShock) and most other controllers work out of the box, on desktop and
## in the browser. The default layout follows Max Payne 3.

## Emitted when the player switches between keyboard/mouse and a gamepad, or
## between gamepads of a different family. HUD prompts listen to this.
signal layout_changed(layout: Layout)
## Emitted for every gamepad button press, with Godot's button index (for
## the controller info in the help overlay).
signal joy_button_pressed(button: int)
## Emitted when a gamepad is plugged in or removed.
signal controller_connection_changed(controller_name: String, connected: bool)

## Which button names to show in prompts.
enum Layout { KEYBOARD_MOUSE, XBOX, PLAYSTATION, TOUCH }

const DEADZONE := 0.25
const LOOK_DEADZONE := 0.1
## How far an analog stick must move before it counts as "using the gamepad".
const ANALOG_ACTIVITY_THRESHOLD := 0.4
## Device id that makes a binding match every controller (InputMap's
## ALL_DEVICES). Events made in code default to device 0, the first
## controller only, while browsers often number a (re)connected controller 1.
const ALL_DEVICES := -1
## Mobile browsers send emulated mouse events right after touches; mouse input
## this soon after a touch is ignored instead of switching away from touch.
const TOUCH_MOUSE_GRACE_MSEC := 1000

const KEYS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"jump": [KEY_SPACE],
	&"bullet_time": [KEY_Q],
	# Like the right mouse button: with a direction it dives, standing still
	# it toggles bullet time.
	&"shootdodge": [KEY_SHIFT],
	&"reload": [KEY_R],
	&"release_mouse": [KEY_ESCAPE],
	&"toggle_help": [KEY_F1],
	&"toggle_fullscreen": [KEY_F11],
	&"weapon_beretta": [KEY_1],
	&"weapon_dual_berettas": [KEY_2],
	&"take_cover": [KEY_C, KEY_CTRL],
	&"use_painkiller": [KEY_TAB, KEY_H, KEY_E],
	&"pause": [KEY_P, KEY_ESCAPE],
	&"melee": [KEY_V, KEY_F],
	&"aim_zoom": [KEY_Z],
}

const MOUSE_BUTTONS := {
	&"fire": [MOUSE_BUTTON_LEFT],
	&"shootdodge": [MOUSE_BUTTON_RIGHT],
	&"melee": [MOUSE_BUTTON_MIDDLE],
	&"next_weapon": [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN],
}

## Button names follow the Xbox layout; on PlayStation A = Cross, B = Circle,
## X = Square, Y = Triangle, Back = Create and Start = Options.
const JOY_BUTTONS := {
	&"jump": [JOY_BUTTON_A],
	&"reload": [JOY_BUTTON_X],
	&"bullet_time": [JOY_BUTTON_LEFT_SHOULDER],
	# Like Shift: with a direction it dives, standing still it toggles
	# bullet time.
	&"shootdodge": [JOY_BUTTON_RIGHT_STICK],
	&"melee": [JOY_BUTTON_RIGHT_SHOULDER],
	&"toggle_help": [JOY_BUTTON_BACK],
	&"pause": [JOY_BUTTON_START],
	&"take_cover": [JOY_BUTTON_B],
	&"use_painkiller": [JOY_BUTTON_DPAD_UP],
	&"next_weapon": [JOY_BUTTON_Y, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT],
}

## Each entry is [axis, direction].
const JOY_AXES := {
	&"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	&"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	&"move_forward": [[JOY_AXIS_LEFT_Y, -1.0]],
	&"move_back": [[JOY_AXIS_LEFT_Y, 1.0]],
	&"look_left": [[JOY_AXIS_RIGHT_X, -1.0]],
	&"look_right": [[JOY_AXIS_RIGHT_X, 1.0]],
	&"look_up": [[JOY_AXIS_RIGHT_Y, -1.0]],
	&"look_down": [[JOY_AXIS_RIGHT_Y, 1.0]],
	&"fire": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"aim_zoom": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
}

const LOOK_ACTIONS: Array[StringName] = [&"look_left", &"look_right", &"look_up", &"look_down"]

## Godot's built-in menu actions have no controller buttons for confirming
## and going back; add them (Cross / A confirms, Circle / B goes back).
const UI_JOY_BUTTONS := {
	&"ui_accept": JOY_BUTTON_A,
	&"ui_cancel": JOY_BUTTON_B,
}

## Prompt text per action, indexed by Layout.
const PROMPTS := {
	&"move": ["WASD", "Left stick", "Left stick", "Left side"],
	&"aim": ["Mouse", "Right stick", "Right stick", "Right side"],
	&"fire": ["Left click", "RT", "R2", "FIRE"],
	&"jump": ["Space", "A", "Cross", "JUMP"],
	&"reload": ["R", "X", "Square", "RELOAD"],
	&"bullet_time": ["Q", "LB", "L1", "SLOW"],
	&"shootdodge": ["Right click / Shift", "R3", "R3", "DODGE"],
	&"aim_zoom": ["Z", "LT", "L2", "-"],
	&"melee": ["V / Middle click", "RB", "R1", "WHIP"],
	&"toggle_help": ["F1", "View", "Create", "?"],
	&"pause": ["Esc / P", "Menu", "Options", "II"],
	&"take_cover": ["C", "B", "Circle", "COVER"],
	&"use_painkiller": ["Tab", "D-pad up", "D-pad up", "PILL"],
	&"next_weapon": ["1 / 2 / Wheel", "Y", "Triangle", "GUN"],
}

## Layout used for prompts, based on the last device that sent input.
var layout := Layout.KEYBOARD_MOUSE
## Device id of the last gamepad used, or -1 when none has been used yet.
var active_joypad := -1
## The last gamepad button pressed (Godot's index), or -1.
var last_joy_button := -1

var _last_touch_msec := -TOUCH_MOUSE_GRACE_MSEC


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var defaults := _build_default_events()
	for action: StringName in defaults:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, LOOK_DEADZONE if action in LOOK_ACTIONS else DEADZONE)
		for event: InputEvent in defaults[action]:
			InputMap.action_add_event(action, event)
	for action: StringName in UI_JOY_BUTTONS:
		var joy_button := InputEventJoypadButton.new()
		joy_button.button_index = UI_JOY_BUTTONS[action]
		joy_button.device = ALL_DEVICES
		if not InputMap.action_has_event(action, joy_button):
			InputMap.action_add_event(action, joy_button)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Phones and tablets (native or in the browser) start with on-screen controls.
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		layout = Layout.TOUCH


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		last_joy_button = (event as InputEventJoypadButton).button_index
		joy_button_pressed.emit(last_joy_button)
	# Track the device the player is actually using to show matching prompts.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_msec = Time.get_ticks_msec()
		_set_layout(Layout.TOUCH)
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion
			and absf((event as InputEventJoypadMotion).axis_value) > ANALOG_ACTIVITY_THRESHOLD):
		active_joypad = event.device
		_set_layout(detect_layout(Input.get_joy_name(event.device), Input.get_joy_info(event.device)))
	elif event is InputEventKey:
		_set_layout(Layout.KEYBOARD_MOUSE)
	elif event is InputEventMouseButton or (event is InputEventMouseMotion
			and (event as InputEventMouseMotion).relative.length() > 2.0):
		if Time.get_ticks_msec() - _last_touch_msec > TOUCH_MOUSE_GRACE_MSEC:
			_set_layout(Layout.KEYBOARD_MOUSE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		var window := get_window()
		if window.mode == Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
		else:
			window.mode = Window.MODE_FULLSCREEN


## Returns the button/key name to show for [param action] on the current layout.
func prompt(action: StringName) -> String:
	return PROMPTS[action][layout]


func is_using_gamepad() -> bool:
	return layout == Layout.XBOX or layout == Layout.PLAYSTATION


func is_using_touch() -> bool:
	return layout == Layout.TOUCH


## Vibrates the active gamepad, if the player is using one. Motor strengths
## go from 0 to 1 and [param duration] is in real seconds.
func rumble(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	if is_using_gamepad() and active_joypad >= 0:
		Input.start_joy_vibration(active_joypad, weak_magnitude, strong_magnitude, duration)


## Guesses the controller family from its name and USB vendor id. Anything
## unknown uses Xbox names, which match the standard layout.
static func detect_layout(joy_name: String, joy_info: Dictionary = {}) -> Layout:
	var lowered := joy_name.to_lower()
	var vendor := str(joy_info.get("vendor_id", ""))
	for hint in ["dualsense", "dualshock", "playstation", "ps5", "ps4", "ps3", "sony", "054c"]:
		if hint in lowered:
			return Layout.PLAYSTATION
	if vendor == "1356":  # 0x054C, Sony
		return Layout.PLAYSTATION
	return Layout.XBOX


func _set_layout(new_layout: Layout) -> void:
	if new_layout == layout:
		return
	layout = new_layout
	layout_changed.emit(layout)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var joy_name := Input.get_joy_name(device)
	if not connected and device == active_joypad:
		active_joypad = -1
		_set_layout(Layout.KEYBOARD_MOUSE)
	controller_connection_changed.emit(joy_name if not joy_name.is_empty() else "Controller", connected)


func _build_default_events() -> Dictionary:
	var events := {}
	for action: StringName in KEYS:
		for keycode: Key in KEYS[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			_append(events, action, key)
	for action: StringName in MOUSE_BUTTONS:
		for button: MouseButton in MOUSE_BUTTONS[action]:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = button
			_append(events, action, mouse)
	for action: StringName in JOY_BUTTONS:
		for button: JoyButton in JOY_BUTTONS[action]:
			var joy_button := InputEventJoypadButton.new()
			joy_button.button_index = button
			joy_button.device = ALL_DEVICES
			_append(events, action, joy_button)
	for action: StringName in JOY_AXES:
		for entry: Array in JOY_AXES[action]:
			var motion := InputEventJoypadMotion.new()
			motion.axis = entry[0]
			motion.axis_value = entry[1]
			motion.device = ALL_DEVICES
			_append(events, action, motion)
	return events


func _append(events: Dictionary, action: StringName, event: InputEvent) -> void:
	if not events.has(action):
		events[action] = []
	events[action].append(event)
