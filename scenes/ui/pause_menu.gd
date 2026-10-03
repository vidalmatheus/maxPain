class_name PauseMenu
extends CanvasLayer
## Pause menu (Esc / P, Start / Options, or the II button on touch screens):
## resume, restart the current scene or quit to the title screen.

## Set by game modes that have their own end screen, to stop pausing then.
var enabled := true

var _panel: ColorRect
var _resume_button: Button


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"pause_menu")
	_panel = ColorRect.new()
	_panel.color = Color(0, 0, 0, 0.72)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 4)
	column.add_child(MenuStyle.label("PAUSED", 72))
	_resume_button = MenuStyle.button("Resume")
	_resume_button.pressed.connect(set_paused.bind(false))
	var restart := MenuStyle.button("Restart")
	restart.pressed.connect(_restart)
	var quit := MenuStyle.button("Quit to title")
	quit.pressed.connect(Game.go_to_title)
	for item in [_resume_button, restart, quit]:
		column.add_child(item)
	_panel.add_child(column)
	add_child(_panel)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause") and (enabled or get_tree().paused):
		set_paused(not get_tree().paused)


func _input(event: InputEvent) -> void:
	if _panel.visible and MenuStyle.handle_touch(_panel, event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_panel.visible = paused
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_resume_button.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	BulletTime.reset()
	get_tree().reload_current_scene()
