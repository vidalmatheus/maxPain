extends CanvasLayer
## In-game HUD: crosshair, adrenaline meter, ammo counter, controls help and
## the full-screen bullet-time effect. Button prompts follow the device the
## player is using (keyboard/mouse, Xbox or PlayStation controller).

const TOAST_DURATION := 3.0

@export var player: Player

var _toast_time_left := 0.0

@onready var overlay: ColorRect = %BulletTimeOverlay
@onready var adrenaline_bar: ProgressBar = %AdrenalineBar
@onready var ammo_label: Label = %AmmoLabel
@onready var reload_label: Label = %ReloadLabel
@onready var help_label: Label = %HelpLabel
@onready var capture_hint: Label = %CaptureHint
@onready var toast_label: Label = %ToastLabel


func _ready() -> void:
	BulletTime.adrenaline_changed.connect(_on_adrenaline_changed)
	_on_adrenaline_changed(BulletTime.adrenaline, BulletTime.max_adrenaline)
	GameInput.layout_changed.connect(_on_layout_changed)
	GameInput.controller_connection_changed.connect(_on_controller_connection_changed)
	_refresh_help()
	toast_label.visible = false
	if player:
		player.pistol.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(player.pistol.ammo_in_magazine, player.pistol.reserve_ammo)


func _process(delta: float) -> void:
	var blend := BulletTime.get_blend()
	overlay.visible = blend > 0.01
	(overlay.material as ShaderMaterial).set_shader_parameter(&"intensity", blend)
	capture_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not GameInput.is_using_gamepad()
	reload_label.visible = player != null and player.pistol.is_reloading()

	if _toast_time_left > 0.0:
		_toast_time_left -= BulletTime.to_real_delta(delta)
		toast_label.visible = _toast_time_left > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		help_label.visible = not help_label.visible


func _refresh_help() -> void:
	var lines := PackedStringArray([
		"%s: move      %s: aim      %s: fire" % _prompts([&"move", &"aim", &"fire"]),
		"%s: jump      %s: reload      %s: bullet time" % _prompts([&"jump", &"reload", &"bullet_time"]),
		"%s + direction: shootdodge" % GameInput.prompt(&"shootdodge"),
		"%s standing still: bullet time" % GameInput.prompt(&"shootdodge"),
	])
	if GameInput.is_using_gamepad():
		lines.append("%s: help" % GameInput.prompt(&"toggle_help"))
	else:
		lines.append("F1: help      F11: fullscreen      Esc: release mouse")
	help_label.text = "\n".join(lines)


func _prompts(actions: Array[StringName]) -> Array:
	return actions.map(GameInput.prompt)


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	_toast_time_left = TOAST_DURATION


func _on_layout_changed(_layout: GameInput.Layout) -> void:
	_refresh_help()


func _on_controller_connection_changed(controller_name: String, connected: bool) -> void:
	_show_toast("%s %s" % [controller_name, "connected" if connected else "disconnected"])


func _on_adrenaline_changed(value: float, max_value: float) -> void:
	adrenaline_bar.max_value = max_value
	adrenaline_bar.value = value


func _on_ammo_changed(in_magazine: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [in_magazine, reserve]
