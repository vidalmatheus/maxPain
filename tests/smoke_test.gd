extends Node
## Headless smoke test for the core mechanics.
##
## Run with:  godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures := 0


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await _frames(30)

	var bullet_time := BulletTime
	var player: Player = main.get_node("Player")
	var target: TargetDummy = main.get_node("Targets/Target1")

	_check(player.is_on_floor(), "player lands on the floor")
	_check(player.state == Player.State.NORMAL, "player starts in NORMAL state")

	# --- Walking -------------------------------------------------------------
	var start := player.global_position
	Input.action_press(&"move_forward")
	await _frames(40)
	Input.action_release(&"move_forward")
	_check(player.global_position.z < start.z - 1.0, "player walks forward (-Z)")

	# --- Shooting: bullets travel and damage targets ------------------------
	var chest := target.global_position + Vector3(0.0, 1.0, 0.0)
	var ammo_before := player.pistol.ammo_in_magazine
	_check(player.pistol.try_fire(chest, [player.get_rid()]), "pistol fires")
	_check(player.pistol.ammo_in_magazine == ammo_before - 1, "firing consumes ammo")
	await _frames(30)
	_check(target.health < target.max_health, "bullet travels and damages the target")

	# Kill it and check the adrenaline reward.
	bullet_time.adrenaline = 50.0
	for i in 5:
		await _frames(12)
		player.pistol.try_fire(chest, [player.get_rid()])
	await _frames(30)
	_check(target.is_dead, "target dies after enough hits")
	_check(bullet_time.adrenaline > 50.0, "kill rewards adrenaline")

	# --- Bullet time toggle ---------------------------------------------------
	bullet_time.adrenaline = bullet_time.max_adrenaline
	bullet_time.toggle()
	await _frames(30)
	_check(bullet_time.is_active, "bullet time activates")
	_check(Engine.time_scale < 0.5, "time scale slows down (%.2f)" % Engine.time_scale)
	bullet_time.toggle()
	await _frames(30)
	_check(not bullet_time.is_active, "bullet time deactivates")
	_check(is_equal_approx(Engine.time_scale, 1.0), "time scale returns to 1.0")

	# --- Shootdodge -----------------------------------------------------------
	Input.action_press(&"move_left")
	await _frames(2)
	player.call(&"_try_shootdodge")
	_check(player.state == Player.State.DIVING, "shootdodge starts a dive")
	_check(bullet_time.is_active, "shootdodge triggers bullet time")
	await _frames(10)
	_check(not player.is_on_floor(), "player is airborne during the dive")
	_check(player.pistol.try_fire(player.global_position + Vector3(0, 1, -20), [player.get_rid()]), "can fire while diving")
	Input.action_release(&"move_left")

	var waited := 0
	while player.state == Player.State.DIVING and waited < 600:
		await _frames(1)
		waited += 1
	_check(player.state == Player.State.PRONE, "dive ends prone on the ground")
	_check(not bullet_time.is_active, "landing ends shootdodge bullet time")

	# Getting up.
	await _frames(40)
	Input.action_press(&"move_forward")
	await _frames(60)
	Input.action_release(&"move_forward")
	_check(player.state == Player.State.NORMAL, "player gets back up")

	# --- Reload -----------------------------------------------------------------
	player.pistol.reload()
	_check(player.pistol.is_reloading(), "reload starts")
	await _frames(120)
	_check(player.pistol.ammo_in_magazine == player.pistol.magazine_size, "reload refills the magazine")

	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok    %s" % description)
	else:
		_failures += 1
		print("  FAIL  %s" % description)
