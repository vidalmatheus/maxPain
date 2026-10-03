extends CanvasLayer
## In-game HUD: crosshair, adrenaline meter, ammo counter, controls help and
## the full-screen bullet-time effect.

@export var player: Player

@onready var overlay: ColorRect = %BulletTimeOverlay
@onready var adrenaline_bar: ProgressBar = %AdrenalineBar
@onready var ammo_label: Label = %AmmoLabel
@onready var reload_label: Label = %ReloadLabel
@onready var help_label: Label = %HelpLabel
@onready var capture_hint: Label = %CaptureHint


func _ready() -> void:
	BulletTime.adrenaline_changed.connect(_on_adrenaline_changed)
	_on_adrenaline_changed(BulletTime.adrenaline, BulletTime.max_adrenaline)
	if player:
		player.pistol.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(player.pistol.ammo_in_magazine, player.pistol.reserve_ammo)


func _process(_delta: float) -> void:
	var blend := BulletTime.get_blend()
	overlay.visible = blend > 0.01
	(overlay.material as ShaderMaterial).set_shader_parameter(&"intensity", blend)
	capture_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	reload_label.visible = player != null and player.pistol.is_reloading()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		help_label.visible = not help_label.visible


func _on_adrenaline_changed(value: float, max_value: float) -> void:
	adrenaline_bar.max_value = max_value
	adrenaline_bar.value = value


func _on_ammo_changed(in_magazine: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [in_magazine, reserve]
