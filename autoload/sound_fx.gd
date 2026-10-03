extends Node
## Plays the game's sound effects.
##
## Gameplay sounds (shots, casings, reloads) are short positional one-shots
## on the "World" bus. In bullet time they slow down (and drop in pitch)
## together with the world, and the World bus is muffled with a low-pass
## filter, like in the original game. The bullet-time sounds themselves play
## at normal speed: a "time freeze" hit when it starts, a droning clock while
## it lasts and a faster hit when it ends.
##
## The slowdown is applied to each sound's pitch_scale instead of with
## AudioServer.playback_speed_scale, because browsers play sounds as Web Audio
## samples, which only follow the pitch scale (they also skip bus effects, so
## the muffling is desktop only).

## Emitted for every one-shot that starts playing.
signal played(stream: AudioStream)

const WORLD_BUS := &"World"
## Too many overlapping one-shots (e.g. dozens of casings) just add noise.
const MAX_ONE_SHOTS := 32
## World bus low-pass cutoff once fully slowed down.
const SLOW_CUTOFF_HZ := 2000.0
const LOOP_VOLUME_DB := -10.0

const BULLET_TIME_ENTER := preload("res://assets/sounds/bullet_time_enter.ogg")
const BULLET_TIME_EXIT := preload("res://assets/sounds/bullet_time_exit.ogg")
const BULLET_TIME_LOOP := preload("res://assets/sounds/bullet_time_loop.ogg")

var _one_shots := 0
var _lowpass: AudioEffectLowPassFilter
var _world_bus_index := -1
var _enter: AudioStreamPlayer
var _exit: AudioStreamPlayer
var _loop: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_world_bus()
	_enter = _make_realtime_player(BULLET_TIME_ENTER, -3.0)
	_exit = _make_realtime_player(BULLET_TIME_EXIT, -6.0)
	var loop_stream := BULLET_TIME_LOOP.duplicate() as AudioStreamOggVorbis
	loop_stream.loop = true
	_loop = _make_realtime_player(loop_stream, LOOP_VOLUME_DB)
	BulletTime.activated.connect(_on_bullet_time_activated)
	BulletTime.deactivated.connect(_on_bullet_time_deactivated)


func _exit_tree() -> void:
	# The AudioServer outlives the scene tree; don't leak the filter.
	AudioServer.remove_bus_effect(_world_bus_index, 0)


func _process(_delta: float) -> void:
	var blend := BulletTime.get_blend()
	AudioServer.set_bus_effect_enabled(_world_bus_index, 0, blend > 0.0)
	# Ease the cutoff exponentially, which sounds linear to the ear.
	_lowpass.cutoff_hz = 20000.0 * pow(SLOW_CUTOFF_HZ / 20000.0, blend)

	# World sounds follow the game speed, also while easing in and out.
	for player: AudioStreamPlayer3D in get_tree().get_nodes_in_group(&"sound_one_shots"):
		var pitch := _world_pitch(player.get_meta(&"pitch"))
		if not is_equal_approx(player.pitch_scale, pitch):
			player.pitch_scale = pitch

	# The drone fades in and out with the time scale.
	if blend > 0.0:
		_loop.volume_db = LOOP_VOLUME_DB + linear_to_db(blend)
		if not _loop.playing:
			_loop.play()
	elif _loop.playing:
		_loop.stop()


## Plays [param stream] once at [param position] in the world. Returns the
## player, or null when too many sounds are already playing.
func play_3d(stream: AudioStream, position: Vector3, volume_db := 0.0, pitch := 1.0,
		unit_size := 10.0) -> AudioStreamPlayer3D:
	var scene := get_tree().current_scene
	if scene == null or _one_shots >= MAX_ONE_SHOTS:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.set_meta(&"pitch", pitch)
	player.pitch_scale = _world_pitch(pitch)
	player.unit_size = unit_size
	player.bus = WORLD_BUS
	player.add_to_group(&"sound_one_shots")
	player.finished.connect(player.queue_free)
	player.tree_exiting.connect(func() -> void: _one_shots -= 1)
	_one_shots += 1
	scene.add_child(player)
	player.global_position = position
	player.play()
	played.emit(stream)
	return player


## Silences everything. Quitting while sounds still play leaks their
## playbacks, so the tests call this and wait a few frames before quitting.
func stop_all() -> void:
	for player in [_enter, _exit, _loop]:
		player.stop()
	for player in get_tree().get_nodes_in_group(&"sound_one_shots"):
		player.queue_free()


func is_bullet_time_loop_playing() -> bool:
	return _loop.playing


func is_world_muffled() -> bool:
	return AudioServer.is_bus_effect_enabled(_world_bus_index, 0)


func _world_pitch(pitch: float) -> float:
	# Godot rejects a pitch scale of zero.
	return maxf(pitch * Engine.time_scale, 0.01)


func _create_world_bus() -> void:
	_world_bus_index = AudioServer.get_bus_index(WORLD_BUS)
	if _world_bus_index == -1:
		AudioServer.add_bus()
		_world_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_world_bus_index, WORLD_BUS)
		AudioServer.set_bus_send(_world_bus_index, &"Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.resonance = 0.6
	AudioServer.add_bus_effect(_world_bus_index, _lowpass, 0)
	AudioServer.set_bus_effect_enabled(_world_bus_index, 0, false)


func _make_realtime_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _on_bullet_time_activated() -> void:
	_exit.stop()
	_enter.play()


func _on_bullet_time_deactivated() -> void:
	_enter.stop()
	_exit.play()
