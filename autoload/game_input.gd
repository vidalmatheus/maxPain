extends Node
## Registers the default input bindings and handles global shortcuts.
##
## Bindings are defined in code (instead of the Input Map in project.godot)
## so they are easy to read, review and extend. If an action already exists
## in the project settings it is left untouched, so it can still be remapped
## from the editor. Physical keycodes are used so WASD works on any layout.

const DEADZONE := 0.25

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
}

const MOUSE_BUTTONS := {
	&"fire": [MOUSE_BUTTON_LEFT],
	&"shootdodge": [MOUSE_BUTTON_RIGHT],
}

const JOY_BUTTONS := {
	&"jump": [JOY_BUTTON_A],
	&"reload": [JOY_BUTTON_X],
	&"bullet_time": [JOY_BUTTON_RIGHT_SHOULDER],
	&"shootdodge": [JOY_BUTTON_LEFT_SHOULDER],
	&"toggle_help": [JOY_BUTTON_BACK],
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var defaults := _build_default_events()
	for action: StringName in defaults:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for event: InputEvent in defaults[action]:
			InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		var window := get_window()
		if window.mode == Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
		else:
			window.mode = Window.MODE_FULLSCREEN


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
