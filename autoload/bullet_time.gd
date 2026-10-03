extends Node
## Global bullet-time ("slow motion") controller.
##
## Owns Engine.time_scale and the adrenaline meter. Gameplay code never sets
## the time scale directly: it either toggles bullet time or opens a
## shootdodge window, and this node decides the resulting time scale.
##
## Adrenaline drains in *real* time while slow motion is active and is
## refilled by kills, like the hourglass in the original game.

signal adrenaline_changed(value: float, max_value: float)
signal activated
signal deactivated

## World time scale while bullet time is fully engaged.
@export var slow_time_scale := 0.3
## How fast the time scale eases in/out, in time-scale units per real second.
@export var ease_speed := 5.0
@export var max_adrenaline := 100.0
## Adrenaline consumed per real second while slow motion is active.
@export var drain_per_second := 11.0
## Minimum adrenaline needed to start a manual bullet-time toggle.
@export var min_adrenaline_to_start := 5.0
## Adrenaline granted for each kill.
@export var kill_reward := 20.0

var adrenaline := 0.0
## True while slow motion is requested and there is adrenaline to pay for it.
var is_active := false

var _toggled := false
var _shootdodge := false
var _last_ticks_usec := 0


func _ready() -> void:
	# Keep running even if the tree is paused so time scale always recovers.
	process_mode = Node.PROCESS_MODE_ALWAYS
	adrenaline = max_adrenaline
	Engine.time_scale = 1.0
	_last_ticks_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var real_delta := _consume_real_delta()

	if is_active:
		_set_adrenaline(adrenaline - drain_per_second * real_delta)
		if adrenaline <= 0.0:
			_toggled = false
			_shootdodge = false
			_refresh()

	var target_scale := slow_time_scale if is_active else 1.0
	Engine.time_scale = move_toward(Engine.time_scale, target_scale, ease_speed * real_delta)


## Manually toggles bullet time on/off.
func toggle() -> void:
	if _toggled:
		_toggled = false
	elif adrenaline >= min_adrenaline_to_start:
		_toggled = true
	_refresh()


## Called when a shootdodge starts. Forces slow motion while adrenaline lasts.
func start_shootdodge() -> void:
	_shootdodge = adrenaline > 0.0
	_refresh()


## Called when a shootdodge ends (the player hits the ground).
func end_shootdodge() -> void:
	_shootdodge = false
	_refresh()


func add_adrenaline(amount: float) -> void:
	_set_adrenaline(adrenaline + amount)


## 0.0 at normal speed, 1.0 when fully slowed down. Useful for visual effects.
func get_blend() -> float:
	return clampf(inverse_lerp(1.0, slow_time_scale, Engine.time_scale), 0.0, 1.0)


## Converts a time-scaled delta back into real seconds.
func to_real_delta(scaled_delta: float) -> float:
	return scaled_delta / maxf(Engine.time_scale, 0.0001)


func _refresh() -> void:
	var wants_slow_motion := (_toggled or _shootdodge) and adrenaline > 0.0
	if wants_slow_motion == is_active:
		return
	is_active = wants_slow_motion
	if is_active:
		activated.emit()
	else:
		deactivated.emit()


func _set_adrenaline(value: float) -> void:
	adrenaline = clampf(value, 0.0, max_adrenaline)
	adrenaline_changed.emit(adrenaline, max_adrenaline)


func _consume_real_delta() -> float:
	var now := Time.get_ticks_usec()
	# Clamp to avoid a huge jump after a hitch or a breakpoint.
	var real_delta := minf((now - _last_ticks_usec) / 1_000_000.0, 0.1)
	_last_ticks_usec = now
	return real_delta
