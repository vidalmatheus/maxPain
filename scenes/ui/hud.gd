extends CanvasLayer
## In-game HUD in the style of the original game: a health silhouette and a
## bullet-time hourglass at the bottom left, ammo and weapon name at the
## bottom right, a dot crosshair, plus the bullet-time screen effect, touch
## controls on phones and tablets, and a controls help panel.

## Gamepad button names (PlayStation, then Xbox), by Godot's button index.
const JOY_BUTTON_NAMES := ["Cross / A", "Circle / B", "Square / X", "Triangle / Y", "Create / View",
		"PS / Guide", "Options / Menu", "L3", "R3", "L1 / LB", "R1 / RB", "D-pad up", "D-pad down",
		"D-pad left", "D-pad right", "Mic / Share", "Paddle 1", "Paddle 2", "Paddle 3", "Paddle 4", "Touchpad"]

const TOAST_DURATION := 3.0
## Health below which the screen edges pulse red.
const LOW_HEALTH := 0.3

@export var player: Player

var _toast_time_left := 0.0
var _damage_flash := 0.0
var _pulse := 0.0
var _damage_overlay: ColorRect

@onready var overlay: ColorRect = %BulletTimeOverlay
@onready var health_figure: HealthFigure = %HealthFigure
@onready var hourglass: Hourglass = %Hourglass
@onready var ammo_label: Label = %AmmoLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var reload_label: Label = %ReloadLabel
@onready var help_hint: Label = %HelpHint
@onready var help_label: Label = %HelpLabel
@onready var capture_hint: Label = %CaptureHint
@onready var toast_label: Label = %ToastLabel
@onready var rotate_overlay: ColorRect = %RotateOverlay
@onready var painkiller_icon: Control = %PainkillerIcon
@onready var painkiller_label: Label = %PainkillerLabel


func _ready() -> void:
	BulletTime.adrenaline_changed.connect(_on_adrenaline_changed)
	_on_adrenaline_changed(BulletTime.adrenaline, BulletTime.max_adrenaline)
	GameInput.layout_changed.connect(_on_layout_changed)
	GameInput.controller_connection_changed.connect(_on_controller_connection_changed)
	GameInput.joy_button_pressed.connect(func(_button: int) -> void: _refresh_help())
	_refresh_help()
	toast_label.visible = false
	Game.message.connect(_show_toast)
	_damage_overlay = ColorRect.new()
	_damage_overlay.color = Color(0.55, 0.0, 0.0, 0.0)
	_damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_overlay)
	move_child(_damage_overlay, 1)
	if player:
		player.health_changed.connect(_on_health_changed)
		player.hurt.connect(_on_hurt)
		player.painkillers_changed.connect(set_painkillers)
		_on_health_changed(player.health, player.max_health)
		set_painkillers(player.painkillers)
		player.pistol.ammo_changed.connect(_on_ammo_changed)
		player.pistol.mode_changed.connect(_on_weapon_mode_changed)
		_on_ammo_changed(player.pistol.ammo_in_magazine, player.pistol.reserve_ammo)
		_on_weapon_mode_changed(player.pistol.dual)


func _process(delta: float) -> void:
	var blend := BulletTime.get_blend()
	overlay.visible = blend > 0.01
	(overlay.material as ShaderMaterial).set_shader_parameter(&"intensity", blend)
	hourglass.flowing = BulletTime.is_active

	var touch := GameInput.is_using_touch()
	capture_hint.visible = not touch and not GameInput.is_using_gamepad() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	reload_label.visible = player != null and player.pistol.is_reloading()
	var screen := get_viewport().get_visible_rect().size
	rotate_overlay.visible = touch and screen.y > screen.x

	# Red flash when hit, and a slow pulse when badly hurt.
	var real_delta := BulletTime.to_real_delta(delta)
	_damage_flash = maxf(_damage_flash - real_delta * 2.5, 0.0)
	var alpha := _damage_flash * 0.35
	if player and player.state != Player.State.DEAD and player.health < player.max_health * LOW_HEALTH:
		_pulse += real_delta * 4.0
		alpha = maxf(alpha, 0.08 + 0.06 * sin(_pulse))
	_damage_overlay.color.a = alpha

	if _toast_time_left > 0.0:
		_toast_time_left -= BulletTime.to_real_delta(delta)
		toast_label.visible = _toast_time_left > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		help_label.visible = not help_label.visible


func _refresh_help() -> void:
	var touch := GameInput.is_using_touch()
	help_hint.visible = not touch
	help_hint.text = "%s: controls" % GameInput.prompt(&"toggle_help")
	if touch:
		help_label.visible = false
	var lines := PackedStringArray([
		"%s: move      %s: aim      %s: fire" % _prompts([&"move", &"aim", &"fire"]),
		"%s: jump      %s: reload      %s: bullet time" % _prompts([&"jump", &"reload", &"bullet_time"]),
		"%s + direction: shootdodge" % GameInput.prompt(&"shootdodge"),
		"%s standing still: bullet time" % GameInput.prompt(&"shootdodge"),
		"%s: Beretta / dual Berettas" % GameInput.prompt(&"next_weapon"),
		"%s: take cover      %s: painkiller      %s: pause" % _prompts([&"take_cover", &"use_painkiller", &"pause"]),
		"%s: pistol-whip      hold %s: keep firing      %s: aim" % _prompts([&"melee", &"fire", &"aim_zoom"]),
	])
	if GameInput.layout == GameInput.Layout.KEYBOARD_MOUSE:
		lines.append("F11: fullscreen")
	elif GameInput.is_using_gamepad():
		# Helps to tell which button a controller really sends.
		var button := GameInput.last_joy_button
		var button_name: String = JOY_BUTTON_NAMES[button] if button >= 0 and button < JOY_BUTTON_NAMES.size() else "?"
		lines.append("%s   ·   last button: %d (%s)" % [Input.get_joy_name(GameInput.active_joypad), button, button_name])
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


## Shows the painkiller count; like in the original game, the bottle is only
## shown while the player carries some.
func set_painkillers(count: int) -> void:
	painkiller_icon.visible = count > 0
	painkiller_label.visible = count > 0
	painkiller_label.text = str(count)


func _on_health_changed(health: float, max_health: float) -> void:
	health_figure.health = health / max_health


func _on_hurt(_damage: float) -> void:
	_damage_flash = 1.0


func _on_adrenaline_changed(value: float, max_value: float) -> void:
	hourglass.fill = value / max_value


func _on_weapon_mode_changed(dual: bool) -> void:
	weapon_label.text = "Dual Berettas" if dual else "Beretta"


func _on_ammo_changed(in_magazine: int, reserve: int) -> void:
	ammo_label.text = "%d + %d" % [in_magazine, reserve]
