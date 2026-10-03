class_name TouchControls
extends Control
## On-screen controls for phones and tablets, drawn in the same minimal style
## as the HUD:
## - left half: a floating joystick (it appears where the thumb lands) to move,
## - right half: drag anywhere to aim,
## - buttons for firing, shootdodge, bullet time, jumping, reloading and
##   switching weapons.
##
## The controls press the same input actions as the keyboard and gamepads, so
## the player code does not need to know about touch. Multi-touch is fully
## supported: e.g. hold a direction with the joystick and tap DODGE.

## Buttons, positioned from the bottom-right corner (in canvas pixels).
const BUTTONS := [
	{"action": &"fire", "label": "FIRE", "offset": Vector2(-150, -190), "radius": 74.0},
	{"action": &"shootdodge", "label": "DODGE", "offset": Vector2(-310, -120), "radius": 56.0},
	{"action": &"bullet_time", "label": "SLOW", "offset": Vector2(-300, -290), "radius": 50.0},
	{"action": &"jump", "label": "JUMP", "offset": Vector2(-140, -370), "radius": 46.0},
	{"action": &"reload", "label": "RELOAD", "offset": Vector2(-450, -90), "radius": 44.0},
	{"action": &"next_weapon", "label": "GUN", "offset": Vector2(-70, -500), "radius": 42.0},
]
const JOYSTICK_RADIUS := 100.0
## Where the joystick hint is drawn while not in use (from the bottom-left).
const JOYSTICK_HINT_OFFSET := Vector2(190, -200)
## Aim speed in radians per pixel dragged.
const LOOK_SENSITIVITY := 0.006
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_forward", &"move_back"]

const COLOR := Color(1, 1, 1, 0.22)
const COLOR_PRESSED := Color(1, 1, 1, 0.45)
const OUTLINE := Color(1, 1, 1, 0.5)

var _joystick_touch := -1
var _joystick_origin := Vector2.ZERO
var _joystick_vector := Vector2.ZERO
var _look_touch := -1
## Last position of the aiming finger.
var _look_position := Vector2.ZERO
## Touch index -> action held by that finger.
var _button_touches := {}
var _requested_fullscreen := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameInput.layout_changed.connect(func(_layout: GameInput.Layout) -> void: _refresh_visibility())
	_refresh_visibility()


func _input(event: InputEvent) -> void:
	var is_touch := event is InputEventScreenTouch or event is InputEventScreenDrag
	if not visible:
		# This node sees input before GameInput switches to the touch layout,
		# so show up right away instead of losing the first touch.
		if not is_touch:
			return
		visible = true
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_pressed(touch.index, touch.position)
		else:
			_on_touch_released(touch.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joystick_touch:
			_set_joystick((drag.position - _joystick_origin) / JOYSTICK_RADIUS)
			queue_redraw()
		elif drag.index == _look_touch:
			# Not drag.relative: in browsers Godot computes it against the
			# previous position of whichever finger was listed first, so with
			# the joystick held it jumps between the two fingers.
			var moved := drag.position - _look_position
			_look_position = drag.position
			var player := get_tree().get_first_node_in_group(&"player") as Player
			if player:
				player.look(-moved.x * LOOK_SENSITIVITY, -moved.y * LOOK_SENSITIVITY)


func _on_touch_pressed(index: int, position: Vector2) -> void:
	_request_fullscreen_landscape()
	var button := _button_at(position)
	if not button.is_empty():
		_button_touches[index] = button.action
		Input.action_press(button.action)
	elif position.x < size.x * 0.5:
		# The newest finger on the left always takes the joystick, so a touch
		# the browser cancelled without telling us can never leave it stuck.
		_joystick_touch = index
		_joystick_origin = position
		_set_joystick(Vector2.ZERO)
	else:
		_look_touch = index
		_look_position = position


func _on_touch_released(index: int) -> void:
	if _button_touches.has(index):
		Input.action_release(_button_touches[index])
		_button_touches.erase(index)
	elif index == _joystick_touch:
		_joystick_touch = -1
		_set_joystick(Vector2.ZERO)
	elif index == _look_touch:
		_look_touch = -1


## Presses the movement actions with analog strength from the joystick.
func _set_joystick(vector: Vector2) -> void:
	_joystick_vector = vector.limit_length(1.0)
	var strengths := [
		maxf(-_joystick_vector.x, 0.0), maxf(_joystick_vector.x, 0.0),
		maxf(-_joystick_vector.y, 0.0), maxf(_joystick_vector.y, 0.0),
	]
	for i in MOVE_ACTIONS.size():
		if strengths[i] > 0.05:
			Input.action_press(MOVE_ACTIONS[i], strengths[i])
		else:
			Input.action_release(MOVE_ACTIONS[i])


func _button_at(position: Vector2) -> Dictionary:
	for button: Dictionary in BUTTONS:
		if position.distance_to(_button_center(button)) <= button.radius * 1.15:
			return button
	return {}


func _button_center(button: Dictionary) -> Vector2:
	return size + (button.offset as Vector2)


func _refresh_visibility() -> void:
	visible = GameInput.is_using_touch()
	if not visible:
		_release_all()


func _release_all() -> void:
	for index: int in _button_touches:
		Input.action_release(_button_touches[index])
	_button_touches.clear()
	_joystick_touch = -1
	_look_touch = -1
	_set_joystick(Vector2.ZERO)


## In the browser, go fullscreen and lock to landscape on the first touch
## (browsers only allow this during a user gesture; iPhones don't support the
## orientation lock, so the HUD shows a "rotate your device" hint instead).
func _request_fullscreen_landscape() -> void:
	if _requested_fullscreen or not OS.has_feature("web"):
		return
	_requested_fullscreen = true
	JavaScriptBridge.eval("""
		(function () {
			var root = document.documentElement;
			var request = root.requestFullscreen || root.webkitRequestFullscreen;
			if (request) {
				var result = request.call(root);
				if (result && result.then) {
					result.then(function () {
						if (screen.orientation && screen.orientation.lock) {
							screen.orientation.lock('landscape').catch(function () {});
						}
					}).catch(function () {});
				}
			}
		})();
	""", true)


func _draw() -> void:
	var font := get_theme_default_font()

	# Joystick: a hint ring when idle, base and knob while held.
	var base := _joystick_origin if _joystick_touch >= 0 else Vector2(JOYSTICK_HINT_OFFSET.x, size.y + JOYSTICK_HINT_OFFSET.y)
	draw_arc(base, JOYSTICK_RADIUS, 0.0, TAU, 48, OUTLINE, 2.0, true)
	draw_circle(base, JOYSTICK_RADIUS, Color(1, 1, 1, 0.06))
	draw_circle(base + _joystick_vector * JOYSTICK_RADIUS, JOYSTICK_RADIUS * 0.4, COLOR_PRESSED if _joystick_touch >= 0 else COLOR)

	var held := _button_touches.values()
	for button: Dictionary in BUTTONS:
		var center := _button_center(button)
		var radius: float = button.radius
		draw_circle(center, radius, COLOR_PRESSED if button.action in held else COLOR)
		draw_arc(center, radius, 0.0, TAU, 48, OUTLINE, 2.0, true)
		var font_size := int(clampf(radius * 0.36, 14.0, 26.0))
		var text_size := font.get_string_size(button.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.3), button.label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.85))
