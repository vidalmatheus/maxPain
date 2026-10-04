class_name MenuStyle
extends RefCounted
## Shared look and behavior for the menus (title, pause, game over): big
## condensed uppercase text like the original game's menus, buttons that
## light up when hovered or focused (keyboard and gamepad navigation), and
## taps on touch screens.
##
## Touch screens don't emulate a mouse in this project (it would fire the gun
## on every tap), so menus pass their screen touches to [method handle_touch].
##
## Moving between options clicks like a gun's hammer, and choosing one racks
## the slide.

const FONT := preload("res://assets/fonts/Oswald-Medium.ttf")
const TEXT := Color(0.86, 0.86, 0.84)
const HIGHLIGHT := Color(0.95, 0.75, 0.35)
const DIM := Color(0.6, 0.6, 0.6)
const MOVE_SOUND := preload("res://assets/sounds/dry_fire.ogg")
const SELECT_SOUND := preload("res://assets/sounds/reload_slide.ogg")
## Focus changes this soon after a button is created are the menu opening,
## not the player moving: no click for those.
const QUIET_AFTER_CREATION_MSEC := 300


static func label(text: String, size: int, color := TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_override(&"font", FONT)
	result.add_theme_font_size_override(&"font_size", size)
	result.add_theme_color_override(&"font_color", color)
	result.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	result.add_theme_constant_override(&"outline_size", maxi(size / 8, 4))
	return result


static func button(text: String, size := 40) -> Button:
	var result := Button.new()
	result.text = text
	result.flat = true
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_font_override(&"font", FONT)
	result.add_theme_font_size_override(&"font_size", size)
	for state in [&"font_color", &"font_pressed_color"]:
		result.add_theme_color_override(state, TEXT)
	for state in [&"font_hover_color", &"font_focus_color", &"font_hover_pressed_color"]:
		result.add_theme_color_override(state, HIGHLIGHT)
	result.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	result.add_theme_constant_override(&"outline_size", maxi(size / 8, 4))
	var empty := StyleBoxEmpty.new()
	for style in [&"normal", &"hover", &"pressed", &"focus", &"hover_pressed"]:
		result.add_theme_stylebox_override(style, empty)
	result.mouse_entered.connect(result.grab_focus)
	var created := Time.get_ticks_msec()
	result.focus_entered.connect(func() -> void:
		if Time.get_ticks_msec() - created > QUIET_AFTER_CREATION_MSEC:
			play_move())
	result.pressed.connect(play_select)
	return result


## A button that turns all sound on and off, showing the current state.
static func sound_button(size := 40) -> Button:
	var result := button("", size)
	var refresh := func() -> void:
		result.text = "Sound: %s" % ("Off" if Game.muted else "On")
	refresh.call()
	result.pressed.connect(func() -> void:
		Game.set_muted(not Game.muted)
		refresh.call())
	return result


## The click of moving between options (also for changing a setting).
static func play_move() -> void:
	SoundFx.play_ui(MOVE_SOUND, -12.0, 1.35)


static func play_select() -> void:
	SoundFx.play_ui(SELECT_SOUND, -6.0)


## Presses the visible button under a released touch inside [param root].
## Returns true if a button was pressed.
static func handle_touch(root: Control, event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch == null or touch.pressed or not root.is_visible_in_tree():
		return false
	# Events reaching _input are already in canvas coordinates.
	var position := touch.position
	for node in root.find_children("*", "BaseButton", true, false):
		var target := node as BaseButton
		if target.is_visible_in_tree() and not target.disabled and target.get_global_rect().has_point(position):
			target.grab_focus()
			target.pressed.emit()
			return true
	return false
