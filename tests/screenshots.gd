extends Node
## Plays a scripted sequence of the core mechanics and saves screenshots plus
## an index.html gallery. Needs a real renderer (not --headless); in CI it
## runs under a virtual display (xvfb) and the gallery is published with
## each PR preview.
##
## Run with:
##   godot --path . res://tests/screenshots.tscn -- --output=<directory>

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TITLE_SCENE := preload("res://scenes/title/title_screen.tscn")
const SURVIVAL_SCENE := preload("res://scenes/game/survival.tscn")
const DEFAULT_OUTPUT := "user://screenshots"

var _output_dir := DEFAULT_OUTPUT
var _shots: Array[Dictionary] = []
var _player: Player


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_output_dir = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	_player = main.get_node("Player")
	# The mobsters shoot back; Max must live through the whole sequence.
	_player.hurt.connect(func(_damage: float) -> void: _player.health = _player.max_health * 0.7)
	await _physics_frames(30)
	await _shot("idle", "The training range: mobsters at the far end shoot back.")

	# Fire a few shots in bullet time; the last bullets are still in flight.
	BulletTime.toggle()
	await _physics_frames(20)
	_player._pitch = deg_to_rad(-4.0)
	for i in 3:
		_player.call(&"_fire")
		await _game_seconds(0.2)
	await _shot("bullet_time", "Bullet time: the world slows down while aiming stays responsive.")
	BulletTime.toggle()
	await _physics_frames(30)

	# Shootdodge to the left while firing.
	_player._yaw = deg_to_rad(15.0)
	Input.action_press(&"move_left")
	await _physics_frames(2)
	_player.call(&"_try_shootdodge")
	Input.action_release(&"move_left")
	for i in 3:
		await _game_seconds(0.16)
		_player.call(&"_fire")
	await _game_seconds(0.03)
	await _shot("shootdodge", "Shootdodge: slow-motion dive while shooting.")

	while _player.state == Player.State.DIVING:
		await _physics_frames(1)
	await _physics_frames(30)
	await _shot("prone", "Landed: still able to shoot while on the ground.")

	# Reload: the empty magazine drops out (with physics).
	Input.action_press(&"move_forward")
	await _physics_frames(60)
	Input.action_release(&"move_forward")
	await _physics_frames(20)
	_player.call(&"_fire")
	await _game_seconds(0.2)
	_player.pistol.reload()
	await _game_seconds(0.45)
	await _shot("reload", "Reloading: the magazine drops out.")

	# Dual Berettas in bullet time.
	await _game_seconds(1.5)
	_player.pistol.set_dual(true)
	BulletTime.toggle()
	await _game_seconds(0.4)
	for i in 4:
		_player.call(&"_fire")
		await _game_seconds(0.12)
	await _shot("dual_berettas", "Dual Berettas, one in each hand, firing alternately.")
	BulletTime.toggle()

	# Title screen, then a survival game on the street.
	main.queue_free()
	var title: Node = TITLE_SCENE.instantiate()
	add_child(title)
	await _game_seconds(1.5)
	await _shot("title", "Title screen: survival mode, difficulty levels, training range.")
	title.queue_free()
	await get_tree().process_frame
	var game: Survival = SURVIVAL_SCENE.instantiate()
	add_child(game)
	game.break_left = 0.1
	var player := game.player
	# Max must live through the whole sequence.
	player.hurt.connect(func(_damage: float) -> void: player.health = player.max_health * 0.7)
	player.set(&"_yaw", PI)  # Down the main street.
	await _game_seconds(4.0)
	for enemy: Enemy in get_tree().get_nodes_in_group(&"enemies"):
		enemy.global_position = player.global_position + Vector3(randf_range(-4, 4), 0, randf_range(9, 14))
	await _game_seconds(2.5)
	await _shot("survival", "Survival: mobsters come in waves and shoot back.")
	# Cover behind the concrete barrier west of the street.
	player.global_position = Vector3(-1.4, 0.05, 12.0)
	player.set(&"_yaw", PI * 0.5)
	await _physics_frames(10)
	player.try_take_cover()
	player.set(&"_yaw", PI * 0.75)
	await _game_seconds(1.0)
	await _shot("cover", "Taking cover behind a concrete barrier.")
	game.queue_free()
	Music.stop()
	await _game_seconds(Music.FADE_TIME + 0.3)

	_write_index()
	SoundFx.stop_all()
	for i in 10:
		await get_tree().process_frame
	print("Saved %d screenshots to %s" % [_shots.size(), ProjectSettings.globalize_path(_output_dir)])
	get_tree().quit()


func _shot(file_name: String, caption: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_output_dir.path_join(file_name + ".png"))
	_shots.append({"file": file_name + ".png", "caption": caption})


func _write_index() -> void:
	var html := PackedStringArray([
		"<!doctype html><meta charset=\"utf-8\"><title>Max Pain - screenshots</title>",
		"<style>body{background:#111;color:#eee;font-family:sans-serif;margin:24px}",
		"figure{display:inline-block;margin:0 16px 24px 0;max-width:640px}",
		"img{width:100%;border:1px solid #333}</style>",
		"<h1>Max Pain - screenshots</h1>",
	])
	for shot in _shots:
		html.append("<figure><img src=\"%s\"><figcaption>%s</figcaption></figure>" % [shot.file, shot.caption])
	var file := FileAccess.open(_output_dir.path_join("index.html"), FileAccess.WRITE)
	file.store_string("\n".join(html))


## Waits in game time, which slows down during bullet time.
func _game_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
