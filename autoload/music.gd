extends Node
## Background music with crossfades: a sad trio on the title screen and a
## tense track during the game (both by Kevin MacLeod, CC BY 4.0; see
## assets/music/README.md). The music ducks a little in bullet time.
##
## On desktop the whole tracks stream from disk. Browsers get ~100 s mono
## loops instead (assets/music/web/), played as Web Audio samples: streaming
## in a browser is mixed on the main thread and drops out whenever a frame
## takes long, and a whole song decoded as a sample would take tens of
## megabytes on a phone.

const TITLE := "title_sad_trio.ogg"
const GAMEPLAY := "gameplay_hitman.ogg"
const VOLUME_DB := -8.0
const SILENT_DB := -40.0
const FADE_TIME := 1.5
## How much quieter the music gets in full bullet time.
const BULLET_TIME_DUCK_DB := 5.0

var _current: AudioStreamPlayer
var _current_name := ""
var _fade := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _current == null:
		return
	_fade = minf(_fade + BulletTime.to_real_delta(delta) / FADE_TIME, 1.0)
	_current.volume_db = lerpf(SILENT_DB, VOLUME_DB, _fade) - BULLET_TIME_DUCK_DB * BulletTime.get_blend()


func play_title() -> void:
	_play(TITLE)


func play_gameplay() -> void:
	_play(GAMEPLAY)


func stop() -> void:
	_fade_out(_current)
	_current = null
	_current_name = ""


func is_playing() -> bool:
	return _current != null and _current.playing


func _play(file: String) -> void:
	if file == _current_name and is_playing():
		return
	_fade_out(_current)
	var web := OS.has_feature("web")
	var path := "res://assets/music/%s%s" % ["web/" if web else "", file]
	var looping := (load(path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	looping.loop = true
	_current = AudioStreamPlayer.new()
	_current.stream = looping
	_current.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if web else AudioServer.PLAYBACK_TYPE_STREAM
	_current.volume_db = SILENT_DB
	add_child(_current)
	_current.play()
	_current_name = file
	_fade = 0.0


func _fade_out(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, FADE_TIME)
	tween.tween_callback(player.queue_free)
