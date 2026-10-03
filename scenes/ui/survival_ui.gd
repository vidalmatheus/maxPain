class_name SurvivalUI
extends CanvasLayer
## Survival mode screens on top of the HUD: the wave counter and countdown,
## the "WAVE n" banner and the game over screen.

@export var survival: Survival

var _wave_label: Label
var _info_label: Label
var _banner: Label
var _banner_time := 0.0
var _game_over_panel: Control
var _game_over_stats: Label
var _retry_button: Button


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_status()
	_game_over_panel = _build_game_over()
	survival.wave_started.connect(_on_wave_started)
	survival.wave_cleared.connect(_on_wave_cleared)
	survival.game_over.connect(_on_game_over)


func _process(delta: float) -> void:
	var real_delta := BulletTime.to_real_delta(delta)
	if survival.break_left > 0.0 and not survival.is_over:
		_wave_label.text = "WAVE %d" % (survival.wave + 1)
		_info_label.text = "Get ready: %d" % ceili(survival.break_left)
	elif survival.wave > 0:
		_wave_label.text = "WAVE %d" % survival.wave
		var left := survival.remaining()
		_info_label.text = "%d mobster%s left" % [left, "" if left == 1 else "s"]
	if _banner_time > 0.0:
		_banner_time -= real_delta
		_banner.modulate.a = clampf(_banner_time, 0.0, 1.0)
		_banner.visible = _banner_time > 0.0


func _input(event: InputEvent) -> void:
	if _game_over_panel.visible and MenuStyle.handle_touch(_game_over_panel, event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func _build_status() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = 12.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override(&"separation", -6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_label = MenuStyle.label("", 30)
	_info_label = MenuStyle.label("", 20, MenuStyle.DIM)
	box.add_child(_wave_label)
	box.add_child(_info_label)
	add_child(box)
	_banner = MenuStyle.label("", 96, MenuStyle.TEXT)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.visible = false
	add_child(_banner)


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner_time = 2.5
	_banner.visible = true


func _on_wave_started(wave: int, _enemies: int) -> void:
	_show_banner("WAVE %d" % wave)


func _on_wave_cleared(wave: int) -> void:
	_show_banner("WAVE %d CLEARED" % wave)


# --- Menus ---------------------------------------------------------------------

## A dimmed full-screen panel with a centered column.
func _panel(title: String) -> Array:
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.72)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 4)
	column.add_child(MenuStyle.label(title, 72))
	panel.add_child(column)
	add_child(panel)
	return [panel, column]


func _build_game_over() -> Control:
	var parts := _panel("YOU'RE DEAD")
	var column: VBoxContainer = parts[1]
	_game_over_stats = MenuStyle.label("", 26, MenuStyle.DIM)
	column.add_child(_game_over_stats)
	_retry_button = MenuStyle.button("Try again")
	_retry_button.pressed.connect(Game.start_survival)
	var title := MenuStyle.button("Quit to title")
	title.pressed.connect(Game.go_to_title)
	column.add_child(_retry_button)
	column.add_child(title)
	return parts[0]


func _on_game_over(wave: int, kills: int, new_record: bool) -> void:
	var pause := get_tree().get_first_node_in_group(&"pause_menu") as PauseMenu
	if pause:
		pause.enabled = false
	var lines := PackedStringArray([
		"%s  ·  Wave %d  ·  %d kill%s" % [Game.difficulty_name(), wave, kills, "" if kills == 1 else "s"],
	])
	lines.append("New record!" if new_record else "Best: wave %d" % Game.best_wave())
	_game_over_stats.text = "\n".join(lines)
	_game_over_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_retry_button.grab_focus()
