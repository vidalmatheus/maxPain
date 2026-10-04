class_name TitleScreen
extends Node3D
## Title screen: "MAX PAIN" over the snowy street at night, with a slow
## camera move, Max standing guard with his Berettas, and the main menu:
## start a survival game, pick the difficulty, practice on the training
## range or read the controls. Cold, melancholic strings play in the background.

const TRAINING_SCENE := "res://scenes/main.tscn"
const BERETTA := preload("res://scenes/weapons/beretta.tscn")
## Camera dolly: from, to (looking at the intersection), seconds per pass.
const DOLLY_FROM := Vector3(4.2, 1.4, 14.5)
const DOLLY_TO := Vector3(-0.6, 2.2, 13.0)
const DOLLY_LOOK := Vector3(0.6, 1.3, 2.0)
const DOLLY_TIME := 30.0

var _time := 0.0
var _menu: VBoxContainer
var _difficulty_button: Button
var _difficulty_info: Label
var _controls_panel: Control
var _controls_label: Label

@onready var camera: Camera3D = $Camera3D
@onready var max_model: CharacterModel = $Max


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	BulletTime.reset()
	Music.play_title()
	_pose_max()
	_build_ui()
	GameInput.layout_changed.connect(func(_layout: GameInput.Layout) -> void: _refresh_controls())
	_refresh_difficulty()
	_refresh_controls()
	(_menu.get_child(0) as Button).grab_focus()


func _process(delta: float) -> void:
	_time += delta
	# Ping-pong dolly with a gentle ease.
	var t := 0.5 - 0.5 * cos(_time / DOLLY_TIME * TAU)
	camera.global_position = DOLLY_FROM.lerp(DOLLY_TO, t)
	camera.look_at(DOLLY_LOOK)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		TouchControls.request_fullscreen_landscape()
	var root := _controls_panel if _controls_panel.visible else _menu
	# A pressed button may have changed the scene already.
	if MenuStyle.handle_touch(root, event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _controls_panel.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"ui_accept")):
		_show_controls(false)
		get_viewport().set_input_as_handled()
	elif _difficulty_button.has_focus():
		if event.is_action_pressed(&"ui_left"):
			_cycle_difficulty(-1)
			MenuStyle.play_move()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_right"):
			_cycle_difficulty(1)
			MenuStyle.play_move()
			get_viewport().set_input_as_handled()


## Max stands in the intersection with his back to the camera, dual
## Berettas raised down the street.
func _pose_max() -> void:
	max_model.set_dual(true)
	max_model.aim_at(max_model.global_position + Vector3(-3.0, 1.4, -20.0))
	var guns := [BERETTA.instantiate(), BERETTA.instantiate()]
	for gun: Node3D in guns:
		gun.top_level = true
		add_child(gun)
	max_model.hands_posed.connect(func() -> void:
		guns[0].global_transform = max_model.get_gun_transform("r")
		guns[1].global_transform = max_model.get_gun_transform("l"))


# --- Menu ----------------------------------------------------------------------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	# Darken the left side, where the menu is.
	var shade := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, Color(0, 0, 0, 0.85))
	gradient.gradient.set_color(1, Color(0, 0, 0, 0.0))
	gradient.fill_to = Vector2(1, 0)
	shade.texture = gradient
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 760.0
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 70.0
	column.offset_right = 700.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 0)
	ui.add_child(column)

	var title := MenuStyle.label("MAX PAIN", 132)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_constant_override(&"line_spacing", -30)
	column.add_child(title)
	var subtitle := MenuStyle.label("S U R V I V A L", 26, Color(0.75, 0.12, 0.1))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 28.0
	column.add_child(gap)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", -4)
	column.add_child(_menu)
	var start := _menu_button("Start")
	start.pressed.connect(Game.start_survival)
	_difficulty_button = _menu_button("")
	_difficulty_button.pressed.connect(_cycle_difficulty.bind(1))
	_difficulty_info = MenuStyle.label("", 18, MenuStyle.DIM)
	_difficulty_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu.add_child(_difficulty_info)
	var training := _menu_button("Training range")
	training.pressed.connect(_start_training)
	var controls := _menu_button("Controls")
	controls.pressed.connect(_show_controls.bind(true))

	var credits := MenuStyle.label("A Max Payne fan tribute. Not affiliated with Remedy or Rockstar.\n"
			+ "Music: \"When Snow Become Ashes\" by Alexandr Zhelanov, \"Hitman\" by Kevin MacLeod (incompetech.com), CC BY 4.0.", 13, Color(1, 1, 1, 0.45))
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	credits.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credits.offset_left = 24.0
	credits.offset_top = -58.0
	credits.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(credits)

	_controls_panel = ColorRect.new()
	(_controls_panel as ColorRect).color = Color(0, 0, 0, 0.85)
	_controls_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_panel.visible = false
	var controls_column := VBoxContainer.new()
	controls_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	controls_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	controls_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	controls_column.add_child(MenuStyle.label("CONTROLS", 56))
	_controls_label = MenuStyle.label("", 22)
	controls_column.add_child(_controls_label)
	var back := MenuStyle.button("Back", 34)
	back.pressed.connect(_show_controls.bind(false))
	controls_column.add_child(back)
	_controls_panel.add_child(controls_column)
	ui.add_child(_controls_panel)


func _menu_button(text: String) -> Button:
	var item := MenuStyle.button(text, 44)
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu.add_child(item)
	return item


func _cycle_difficulty(step: int) -> void:
	var count := Game.Difficulty.size()
	Game.set_difficulty(posmod(Game.difficulty + step, count) as Game.Difficulty)
	_refresh_difficulty()


func _refresh_difficulty() -> void:
	_difficulty_button.text = "< %s >" % Game.difficulty_name()
	var best := Game.best_wave()
	var info: String = Game.setting("description")
	if best > 0:
		info += "   Best: wave %d" % best
	_difficulty_info.text = info


func _show_controls(show: bool) -> void:
	_controls_panel.visible = show
	if show:
		(_controls_panel.find_children("*", "Button", true, false)[0] as Button).grab_focus()
	else:
		(_menu.get_child(2) as Button).grab_focus()


func _refresh_controls() -> void:
	var p := GameInput.prompt
	_controls_label.text = "\n".join(PackedStringArray([
		"Move: %s      Aim: %s      Fire: %s" % [p.call(&"move"), p.call(&"aim"), p.call(&"fire")],
		"Shootdodge: %s + direction      Bullet time: %s" % [p.call(&"shootdodge"), p.call(&"bullet_time")],
		"Take cover: %s      Painkiller: %s      Reload: %s" % [p.call(&"take_cover"), p.call(&"use_painkiller"), p.call(&"reload")],
		"Jump: %s      Switch weapon: %s      Pause: %s" % [p.call(&"jump"), p.call(&"next_weapon"), p.call(&"pause")],
		"",
		"Survive the waves. Every wave brings two more mobsters.",
		"Dead mobsters drop ammo, and sometimes adrenaline or painkillers.",
	]))


func _start_training() -> void:
	BulletTime.reset()
	get_tree().change_scene_to_file(TRAINING_SCENE)
