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
## Emitted when a gamepad is plugged in or removed.
signal controller_connection_changed(controller_name: String, connected: bool)

## Which button names to show in prompts.
enum Layout { KEYBOARD_MOUSE, XBOX, PLAYSTATION }

const DEADZONE := 0.25
const LOOK_DEADZONE := 0.1
## How far an analog stick must move before it counts as "using the gamepad".
const ANALOG_ACTIVITY_THRESHOLD := 0.4

const KEYS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"jump": [KEY_SPACE],
	&"bullet_time": [KEY_SHIFT, KEY_Q],
	&"reload": [KEY_R],
	&"release_mouse": [KEY_ESCAPE],
	&"toggle_help": [KEY_F1],
	&"toggle_fullscreen": [KEY_F11],
	&"weapon_beretta": [KEY_1],
	&"weapon_dual_berettas": [KEY_2],
}

const MOUSE_BUTTONS := {
	&"fire": [MOUSE_BUTTON_LEFT],
	&"shootdodge": [MOUSE_BUTTON_RIGHT],
	&"next_weapon": [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN],
}

## Button names follow the Xbox layout; on PlayStation A = Cross, B = Circle,
## X = Square, Y = Triangle, Back = Create and Start = Options.
const JOY_BUTTONS := {
	&"jump": [JOY_BUTTON_A],
	&"reload": [JOY_BUTTON_X],
	&"bullet_time": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_STICK],
	&"shootdodge": [JOY_BUTTON_RIGHT_SHOULDER],
	&"toggle_help": [JOY_BUTTON_START, JOY_BUTTON_BACK],
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
	&"shootdodge": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
}

const LOOK_ACTIONS: Array[StringName] = [&"look_left", &"look_right", &"look_up", &"look_down"]

## Prompt text per action, indexed by Layout.
const PROMPTS := {
	&"move": ["WASD", "Left stick", "Left stick"],
	&"aim": ["Mouse", "Right stick", "Right stick"],
	&"fire": ["Left click", "RT", "R2"],
	&"jump": ["Space", "A", "Cross"],
	&"reload": ["R", "X", "Square"],
	&"bullet_time": ["Shift / Q", "LB / R3", "L1 / R3"],
	&"shootdodge": ["Right click", "RB / LT", "R1 / L2"],
	&"toggle_help": ["F1", "Menu", "Options"],
	&"next_weapon": ["1 / 2 / Wheel", "Y", "Triangle"],
}

## Layout used for prompts, based on the last device that sent input.
var layout := Layout.KEYBOARD_MOUSE
## Device id of the last gamepad used, or -1 when none has been used yet.
var active_joypad := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var defaults := _build_default_events()
	for action: StringName in defaults:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, LOOK_DEADZONE if action in LOOK_ACTIONS else DEADZONE)
		for event: InputEvent in defaults[action]:
			InputMap.action_add_event(action, event)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	# Track the device the player is actually using to show matching prompts.
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion
			and absf((event as InputEventJoypadMotion).axis_value) > ANALOG_ACTIVITY_THRESHOLD):
		active_joypad = event.device
		_set_layout(detect_layout(Input.get_joy_name(event.device), Input.get_joy_info(event.device)))
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion
			and (event as InputEventMouseMotion).relative.length() > 2.0):
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
	return layout != Layout.KEYBOARD_MOUSE


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
			_append(events, action, joy_button)
	for action: StringName in JOY_AXES:
		for entry: Array in JOY_AXES[action]:
			var motion := InputEventJoypadMotion.new()
			motion.axis = entry[0]
			motion.axis_value = entry[1]
			_append(events, action, motion)
	return events


func _append(events: Dictionary, action: StringName, event: InputEvent) -> void:
	if not events.has(action):
		events[action] = []
	events[action].append(event)
