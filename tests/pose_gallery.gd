extends Node
## Development aid: freezes the player in each shootdodge direction and in the
## standing stances, and saves screenshots from the game camera and from an
## outside camera, to review the character's poses and how it holds the guns.
##
## Run with (needs a renderer, like tests/screenshots.tscn):
##   godot --path . res://tests/pose_gallery.tscn -- --output=<directory> [--only=stand|whip|mp1]

const MAIN_SCENE := preload("res://scenes/main.tscn")

## Dive directions, as move input (x = right, y = back).
const DIVES := {
	"forward": Vector2(0, -1),
	"back": Vector2(0, 1),
	"left": Vector2(-1, 0),
	"right": Vector2(1, 0),
	"forward_left": Vector2(-0.7, -0.7),
	"back_right": Vector2(0.7, 0.7),
}

## Run directions, as move input.
const RUNS := {
	"left": Vector2(-1, 0),
	"back_right": Vector2(0.7, 0.7),
	"forward_right": Vector2(0.7, -0.7),
}

var _output_dir := "user://poses"
var _player: Player
var _outside: Camera3D
var _spawn := Vector3.ZERO
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_output_dir = arg.trim_prefix("--output=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var main: TrainingRange = MAIN_SCENE.instantiate()
	main.spawn_mobsters = false
	add_child(main)
	_player = main.get_node("Player")
	_spawn = _player.global_position + Vector3(0, 0.05, 0)
	_outside = Camera3D.new()
	_outside.fov = 50.0
	add_child(_outside)
	BulletTime.adrenaline_changed.connect(func(_v: float, _m: float) -> void: BulletTime.adrenaline = BulletTime.max_adrenaline)
	await _physics_frames(30)

	if _only == "mp1":
		await _mp1_shots()
		get_tree().quit()
		return
	for dual in [false, true]:
		_player.pistol.set_dual(dual)
		await _game_seconds(0.5)
		if _only != "whip":
			await _stand_shots("dual" if dual else "single")
		await _whip_shots("dual" if dual else "single")
	_player.pistol.set_dual(false)
	if _only == "whip":
		get_tree().quit()
		return

	# Running while aiming forward: legs follow the movement, the upper body
	# twists back to the aim.
	for run_name: String in RUNS:
		await _run_shots(run_name, RUNS[run_name])

	for dive_name: String in DIVES if _only != "stand" else {}:
		for dual in [false, true]:
			await _dive_shots(dive_name, DIVES[dive_name], dual)

	print("Saved poses to %s" % ProjectSettings.globalize_path(_output_dir))
	SoundFx.stop_all()
	await _physics_frames(10)
	get_tree().quit()


func _stand_shots(label: String) -> void:
	_reset_player()
	await _game_seconds(0.6)
	await _capture(label + "_stand", [Vector3(2.2, 1.5, -1.2), Vector3(-1.6, 1.4, -2.0), Vector3(2.6, 1.2, 0.6)])
	# Close-ups of the hands: from the right, from the front-left, from above.
	await _capture(label + "_hands", [Vector3(0.45, 0.68, -0.45), Vector3(-0.45, 0.68, -0.45), Vector3(0.05, 1.0, -0.3)], 1.42)


## The pistol-whip frozen at a few points of the swing: wound up to the
## right, sweeping, the blow, and swept through to the left.
func _whip_shots(label: String) -> void:
	_reset_player()
	await _game_seconds(0.4)
	var arms: ArmIKModifier = _player.model.get(&"_arms")
	for phase: float in [0.3, 0.42, 0.48, 0.6]:
		arms.strike = phase
		await _physics_frames(3)
		await _capture("whip_%s_%d" % [label, roundi(phase * 100)], [Vector3(2.4, 1.3, -0.8)])
	arms.strike = 0.0


## The original game's animations: reloading one and two pistols, warming
## the hands, limping and dying.
func _mp1_shots() -> void:
	for dual in [false, true]:
		_reset_player()
		_player.pistol.set_dual(dual)
		await _game_seconds(0.6)
		_player.pistol.ammo_in_magazine = 1
		_player.pistol.reload()
		var label := "dual" if dual else "single"
		for i in 3:
			await _game_seconds(_player.pistol.dual_reload_time / 4.0 if dual else _player.pistol.reload_time / 4.0)
			await _capture("reload_%s_%d" % [label, i], [Vector3(2.0, 1.4, -1.2)])
	_player.pistol.set_dual(false)
	_reset_player()
	_player.warm_hands_delay = 0.2
	await _game_seconds(2.5)
	await _capture("warming", [Vector3(1.8, 1.4, -1.6)])
	_player.warm_hands_delay = 8.0
	_reset_player()
	_player.health = _player.max_health * 0.2
	var actions := _press(Vector2(0, -1))
	await _game_seconds(1.0)
	await _capture("limp", [Vector3(2.4, 0.8, -1.0)])
	await _game_seconds(0.4)
	await _capture("limp_b", [Vector3(2.4, 0.8, -1.0)])
	for action: StringName in actions:
		Input.action_release(action)
	await _game_seconds(0.5)
	await _capture("hurt_stand", [Vector3(2.0, 1.2, -1.6)])
	_player.take_hit(1000.0, _player.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD)
	await _game_seconds(0.5)
	await _capture("death_a", [Vector3(3.0, 1.6, 0.0)])
	await _game_seconds(2.0)
	await _capture("death_b", [Vector3(3.0, 1.6, 0.0)])


func _run_shots(label: String, input: Vector2) -> void:
	_reset_player()
	await _game_seconds(0.3)
	var actions := _press(input)
	await _game_seconds(0.7)
	await _capture("run_" + label, [Vector3(2.4, 0.6, -1.6), Vector3(-2.4, 0.6, -1.6)])
	for action: StringName in actions:
		Input.action_release(action)


func _press(input: Vector2) -> Array[StringName]:
	var actions: Array[StringName] = []
	if input.x != 0:
		actions.append(&"move_right" if input.x > 0 else &"move_left")
		Input.action_press(actions[-1], absf(input.x))
	if input.y != 0:
		actions.append(&"move_back" if input.y > 0 else &"move_forward")
		Input.action_press(actions[-1], absf(input.y))
	return actions


func _dive_shots(label: String, input: Vector2, dual: bool) -> void:
	_reset_player()
	_player.pistol.set_dual(dual)
	await _game_seconds(0.5)
	var actions := _press(input)
	await _physics_frames(2)
	_player.call(&"_try_shootdodge")
	for action: StringName in actions:
		Input.action_release(action)
	await _game_seconds(0.3)
	var prefix := "dive_%s_%s" % [label, "dual" if dual else "single"]
	await _capture(prefix, [Vector3(3.2, 1.0, 0.0), Vector3(0.0, 1.0, -3.4), Vector3(-2.4, 2.4, 2.4)])
	while _player.state == Player.State.DIVING:
		await _physics_frames(1)
	await _game_seconds(0.5)
	await _capture(prefix + "_prone", [Vector3(2.6, 1.4, -1.5)])


func _reset_player() -> void:
	_player.state = Player.State.NORMAL
	_player.velocity = Vector3.ZERO
	_player.global_position = _spawn
	_player._yaw = 0.0
	_player._pitch = deg_to_rad(-5.0)


## Saves the game camera view and one view per outside camera offset
## (relative to the player, in the aim's frame).
func _capture(file_name: String, offsets: Array, look_height := 0.7) -> void:
	get_tree().paused = true
	await _render()
	_save(file_name)
	var center := _player.global_position + Vector3(0, 0.8, 0)
	var look := _player.global_position + Basis(Vector3.UP, _player._yaw) * Vector3(0, look_height, -0.35 if look_height > 1.0 else 0.0)
	for i in offsets.size():
		var offset := Basis(Vector3.UP, _player._yaw) * (offsets[i] as Vector3)
		_outside.global_position = center + offset
		_outside.look_at(look)
		_outside.current = true
		await _render()
		_save("%s_%d" % [file_name, i + 1])
	_player.camera.current = true
	get_tree().paused = false


func _render() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file_name + ".png"))


func _game_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
