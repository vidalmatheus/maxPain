extends Node
## Headless smoke test for the core mechanics.
##
## Run with:  godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SURVIVAL_SCENE := preload("res://scenes/game/survival.tscn")
const TITLE_SCENE := preload("res://scenes/title/title_screen.tscn")
const TARGET_SCENE := preload("res://scenes/targets/target_dummy.tscn")

var _failures := 0


func _ready() -> void:
	# A quiet training range with one practice target, which has a clear
	# line of fire from the spawn point.
	var main: TrainingRange = MAIN_SCENE.instantiate()
	main.spawn_mobsters = false
	var target: TargetDummy = TARGET_SCENE.instantiate()
	target.position = Vector3(4, 0, -12)
	main.add_child(target)
	add_child(main)
	await _frames(30)

	var bullet_time := BulletTime
	var player: Player = main.get_node("Player")
	var sounds: Array[AudioStream] = []
	SoundFx.played.connect(func(stream: AudioStream) -> void: sounds.append(stream))

	_check(player.is_on_floor(), "player lands on the floor")
	_check(_gun_aim_error(player) < 4.0, "the pistol points at the crosshair (%.1f deg off)" % _gun_aim_error(player))
	_check(player.state == Player.State.NORMAL, "player starts in NORMAL state")

	# --- Walking -------------------------------------------------------------
	var start := player.global_position
	Input.action_press(&"move_forward")
	await _frames(40)
	Input.action_release(&"move_forward")
	_check(player.global_position.z < start.z - 1.0, "player walks forward (-Z)")

	# --- Jumping: high enough to get onto a car (1.3 m) ----------------------------
	var ground_y := player.global_position.y
	var peak := ground_y
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	for i in 70:
		await _frames(1)
		peak = maxf(peak, player.global_position.y)
	_check(peak - ground_y > 1.4, "Max jumps high enough to get onto a car (%.2f m)" % (peak - ground_y))

	# --- Shooting: bullets travel and damage targets ------------------------
	player.pistol.spread_degrees = 0.0  # Deterministic shots.
	var chest := target.global_position + Vector3(0.0, 1.0, 0.0)
	var ammo_before := player.pistol.ammo_in_magazine
	_check(player.pistol.try_fire(chest, [player.get_rid()]), "pistol fires")
	_check(player.pistol.ammo_in_magazine == ammo_before - 1, "firing consumes ammo")
	_check(get_tree().get_nodes_in_group(&"shell_casings").size() == 1, "firing ejects a shell casing")
	_check(GunModel.SHOT_SOUND in sounds, "firing plays a gunshot")
	await _frames(60)
	_check(GunModel.CASING_SOUNDS.any(func(s: AudioStream) -> bool: return s in sounds), "the casing clinks on the floor")
	_check(target.health < target.max_health, "bullet travels and damages the target")

	# Kill it and check the adrenaline reward.
	bullet_time.adrenaline = 50.0
	for i in 5:
		await _frames(12)
		player.pistol.try_fire(chest, [player.get_rid()])
	await _frames(30)
	_check(target.is_dead, "target dies after enough hits")
	_check(bullet_time.adrenaline > 50.0, "kill rewards adrenaline")
	await get_tree().create_timer(3.2, false).timeout
	_check(not target.is_dead and target.health == target.max_health, "practice targets get back up after 3 seconds")

	# --- Pistol-whip -------------------------------------------------------------
	var whip_spot := player.global_position
	player.global_position = target.global_position + Vector3(0, 0.05, 1.2)
	player.set(&"_yaw", 0.0)  # Facing -Z, at the target.
	await _frames(10)
	_check(player.melee(), "Max swings a pistol-whip")
	_check(Player.MELEE_SWING_SOUND in sounds, "the swing whooshes")
	await get_tree().create_timer(player.melee_time).timeout
	_check(target.health == target.max_health - player.melee_damage, "the pistol-whip hurts the target in front")
	_check(Player.MELEE_HIT_SOUND in sounds, "the blow lands with a thud")
	_check(not player.melee() or player.get(&"_melee_cooldown") > 0.0, "pistol-whips need a moment between them")
	await get_tree().create_timer(player.melee_cooldown).timeout
	var health_before_miss := target.health
	player.set(&"_yaw", PI)  # Facing away.
	await _frames(5)
	player.melee()
	await get_tree().create_timer(player.melee_time).timeout
	_check(target.health == health_before_miss, "a pistol-whip only hits what is in front of Max")
	player.global_position = whip_spot
	player.set(&"_yaw", 0.0)
	await _frames(10)

	# --- Bullet time toggle ---------------------------------------------------
	bullet_time.adrenaline = bullet_time.max_adrenaline
	bullet_time.toggle()
	await _frames(30)
	_check(bullet_time.is_active, "bullet time activates")
	_check(Engine.time_scale < 0.5, "time scale slows down (%.2f)" % Engine.time_scale)
	_check(SoundFx.is_bullet_time_loop_playing() and SoundFx.is_world_muffled(), "bullet time drones and muffles the world")
	bullet_time.toggle()
	await _frames(30)
	_check(not bullet_time.is_active, "bullet time deactivates")
	_check(is_equal_approx(Engine.time_scale, 1.0), "time scale returns to 1.0")
	_check(not SoundFx.is_bullet_time_loop_playing() and not SoundFx.is_world_muffled(), "normal speed sounds normal again")

	# --- Original Max Payne animations ---------------------------------------------
	# Standing still a while: guns away, warming the hands.
	player.warm_hands_delay = 0.5
	await get_tree().create_timer(1.2).timeout
	_check(player.model.is_warming() and not player.pistol.right_gun.visible, "standing still, Max puts the guns away and warms his hands")
	player.call(&"_fire")
	await _frames(2)
	_check(player.pistol.right_gun.visible, "pulling the trigger draws the guns again")
	player.warm_hands_delay = 8.0
	await get_tree().create_timer(0.5).timeout
	# Badly hurt: hunched and limping.
	player.health = player.max_health * 0.2
	await _frames(5)
	_check(player.model.hurt, "badly hurt, Max limps")
	player.health = player.max_health
	await _frames(2)

	# --- Shootdodge -----------------------------------------------------------
	Input.action_press(&"move_left")
	await _frames(2)
	player.call(&"_try_shootdodge")
	_check(player.state == Player.State.DIVING, "shootdodge starts a dive")
	_check(bullet_time.is_active, "shootdodge triggers bullet time")
	await _frames(10)
	_check(not player.is_on_floor(), "player is airborne during the dive")
	_check(_gun_aim_error(player) < 6.0, "the pistol points at the crosshair mid-dive (%.1f deg off)" % _gun_aim_error(player))
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

	# --- Gamepad ------------------------------------------------------------------
	_check(GameInput.detect_layout("DualSense Wireless Controller") == GameInput.Layout.PLAYSTATION, "detects a DualSense (PS5)")
	_check(GameInput.detect_layout("PS4 Controller") == GameInput.Layout.PLAYSTATION, "detects a DualShock 4 (PS4)")
	_check(GameInput.detect_layout("Unknown", {"vendor_id": 1356}) == GameInput.Layout.PLAYSTATION, "detects Sony by USB vendor id")
	_check(GameInput.detect_layout("Xbox Series X Controller") == GameInput.Layout.XBOX, "detects an Xbox controller")
	_check(GameInput.detect_layout("Generic USB Gamepad") == GameInput.Layout.XBOX, "unknown pads use Xbox prompts")

	# Holding the trigger keeps firing at a steady cadence, not once per
	# motion event an analog trigger keeps sending while held.
	player.pistol.reload()
	await _frames(120)
	var ammo_start := player.pistol.ammo_in_magazine
	for value in [0.4, 0.8, 1.0, 0.97, 1.0, 0.98, 1.0, 0.97, 1.0, 0.99]:
		_send_axis(JOY_AXIS_TRIGGER_RIGHT, value)
		await get_tree().create_timer(0.1).timeout
	var held_shots := ammo_start - player.pistol.ammo_in_magazine
	_check(held_shots >= 4 and held_shots <= 7, "holding the trigger keeps firing at a steady cadence (%d shots in 1 s)" % held_shots)
	_check(GameInput.is_using_gamepad(), "gamepad input switches the active layout")
	_check(GameInput.prompt(&"fire") == "RT", "prompts follow the gamepad layout")
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	var released_ammo := player.pistol.ammo_in_magazine
	await get_tree().create_timer(0.5).timeout
	_check(player.pistol.ammo_in_magazine == released_ammo, "letting go of the trigger stops firing")
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(2)
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(2)
	_check(player.pistol.ammo_in_magazine == released_ammo - 1, "a quick pull fires a single shot")

	# L2 zooms in to aim.
	var fov_before := player.camera.fov
	_send_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await get_tree().create_timer(0.4).timeout
	_check(player.is_aiming() and player.camera.fov < fov_before - 10.0, "holding L2 / LT zooms in to aim (fov %.0f)" % player.camera.fov)
	_send_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await get_tree().create_timer(0.4).timeout
	_check(not player.is_aiming() and is_equal_approx(player.camera.fov, fov_before), "letting go of L2 zooms back out")
	_check(not _joy_axis_in(&"shootdodge", JOY_AXIS_TRIGGER_LEFT), "L2 no longer shootdodges")

	# R1 pistol-whips; R3 is the shootdodge button (bullet time standing still).
	_check(_joy_button_in(&"melee", JOY_BUTTON_RIGHT_SHOULDER), "R1 / RB pistol-whips")
	_check(_joy_button_in(&"shootdodge", JOY_BUTTON_RIGHT_STICK) and not _joy_button_in(&"bullet_time", JOY_BUTTON_RIGHT_STICK),
			"R3 shootdodges (and toggles bullet time standing still)")

	# Right stick aims.
	var yaw_before: float = player.get(&"_yaw")
	_send_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(20)
	_send_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(2)
	_check(player.get(&"_yaw") < yaw_before - 0.1, "right stick turns the camera")

	# Keyboard input switches the prompts back.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(2)
	_check(not GameInput.is_using_gamepad(), "keyboard input switches back to keyboard prompts")

	# --- Reload -----------------------------------------------------------------
	player.pistol.reload()
	_check(player.pistol.is_reloading(), "reload starts")
	await _frames(120)
	_check(player.pistol.ammo_in_magazine == player.pistol.magazine_size, "reload refills the magazine")
	_check(Pistol.MAGAZINE_OUT_SOUND in sounds and Pistol.MAGAZINE_IN_SOUND in sounds, "reloading plays the magazine sounds")

	# --- Dual Berettas -----------------------------------------------------------
	_check(player.pistol.magazine_size == 15, "a Beretta magazine holds 15 rounds")
	var shooters: Array[GunModel] = []
	player.pistol.fired.connect(func(gun: GunModel) -> void: shooters.append(gun))
	var key_2 := InputEventKey.new()
	key_2.physical_keycode = KEY_2
	key_2.pressed = true
	Input.parse_input_event(key_2)
	await _frames(2)
	key_2 = key_2.duplicate()
	key_2.pressed = false
	Input.parse_input_event(key_2)
	await _frames(30)
	_check(player.pistol.dual, "key 2 switches to dual Berettas")
	_check(player.pistol.ammo_in_magazine == 30, "dual Berettas hold 30 rounds")
	_check(player.pistol.left_gun.visible, "the second Beretta appears in the left hand")
	for i in 2:
		player.pistol.try_fire(chest, [player.get_rid()])
		await _frames(8)
	_check(shooters.size() == 2 and shooters[0] != shooters[1], "dual Berettas fire alternately")
	player.pistol.reload()
	await _frames(2)
	_check(get_tree().get_nodes_in_group(&"dropped_magazines").size() >= 2, "reloading drops both magazines")
	_check(not player.pistol.left_gun.has_magazine(), "guns are empty while reloading")
	await _frames(150)
	_check(player.pistol.ammo_in_magazine == 30, "dual reload refills both magazines")
	_check(player.pistol.right_gun.has_magazine() and player.pistol.left_gun.has_magazine(), "fresh magazines are inserted")

	# --- Touch controls -----------------------------------------------------------
	var touch: TouchControls = main.get_node("HUD/TouchControls")
	var stick := Vector2(200.0, touch.size.y - 150.0)
	_send_touch(0, stick, true)
	await _frames(2)
	_check(GameInput.is_using_touch() and touch.visible, "touching the screen shows the touch controls")
	var touch_start := player.global_position
	_send_drag(0, stick + Vector2(0, -80), Vector2(0, -80))
	await _frames(30)
	_check(player.global_position.distance_to(touch_start) > 0.5, "the touch joystick moves the player")
	_send_touch(0, stick + Vector2(0, -80), false)
	await _frames(10)

	# Mobile browsers send emulated mouse events after touches: they must not
	# switch away from the touch controls. (Emulated clicks are blocked in the
	# web page itself, see html/head_include in export_presets.cfg.)
	var emulated := InputEventMouseMotion.new()
	emulated.relative = Vector2(40, 20)
	Input.parse_input_event(emulated)
	await _frames(2)
	_check(GameInput.is_using_touch() and touch.visible, "emulated mouse events after a touch keep the touch controls")

	var fire_button := touch.size + Vector2(-150, -190)
	var ammo_before_tap := player.pistol.ammo_in_magazine
	_send_touch(1, fire_button, true)
	await _frames(2)
	_send_touch(1, fire_button, false)
	await _frames(2)
	_check(player.pistol.ammo_in_magazine == ammo_before_tap - 1, "the FIRE button shoots")

	var yaw_before_drag: float = player.get(&"_yaw")
	var look_start := Vector2(touch.size.x * 0.7, touch.size.y * 0.4)
	_send_touch(2, look_start, true)
	_send_drag(2, look_start + Vector2(60, 0), Vector2(60, 0))
	await _frames(2)
	_send_touch(2, look_start + Vector2(60, 0), false)
	_check(not is_equal_approx(player.get(&"_yaw"), yaw_before_drag), "dragging on the right side aims")

	# Joystick and aiming at the same time. Browsers report a bogus relative
	# when only one of the two fingers moves; aiming must follow the
	# aiming finger's real position.
	_send_touch(0, stick, true)
	_send_touch(2, look_start, true)
	await _frames(2)
	var yaw_two_fingers: float = player.get(&"_yaw")
	_send_drag(0, stick + Vector2(0, -60), Vector2(500, 0))
	await _frames(2)
	_check(is_equal_approx(player.get(&"_yaw"), yaw_two_fingers), "moving the joystick does not turn the camera")
	_send_drag(2, look_start + Vector2(10, 0), Vector2(800, 0))
	await _frames(2)
	var turned := absf(player.get(&"_yaw") - yaw_two_fingers)
	_check(turned > 0.0 and turned < 0.1, "a small drag only turns the camera a little while moving (%.2f rad)" % turned)
	_send_touch(0, stick, false)
	_send_touch(2, look_start, false)
	main.queue_free()
	await _frames(2)

	await _test_training()
	await _test_survival()
	await _test_coop()
	await _test_title_screen()

	SoundFx.stop_all()
	Music.stop()
	# Let the music fade out: quitting while sounds play leaks them.
	await get_tree().create_timer(Music.FADE_TIME + 0.3).timeout
	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _test_training() -> void:
	Game.training_mobsters = TrainingRange.MAX_MOBSTERS
	var range: TrainingRange = MAIN_SCENE.instantiate()
	add_child(range)
	await _frames(5)
	var spots := range.spawns.get_child_count()
	var mobsters := get_tree().get_nodes_in_group(&"enemies")
	_check(mobsters.size() == spots, "mobsters stand at the training range's %d spots" % spots)
	var first := mobsters[0] as Enemy
	var spot := first.global_position
	first.take_hit(1000.0, first.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD)
	await _frames(2)
	_check(get_tree().get_nodes_in_group(&"enemies").size() == spots - 1, "a training mobster dies")
	await get_tree().create_timer(TrainingRange.RESPAWN_TIME + 0.3, false).timeout
	var back := false
	for enemy: Enemy in get_tree().get_nodes_in_group(&"enemies"):
		back = back or enemy.global_position.distance_to(spot) < 2.0
	_check(get_tree().get_nodes_in_group(&"enemies").size() == spots and back,
			"it comes back at its spot after %d seconds" % TrainingRange.RESPAWN_TIME)
	# The mobsters shoot back at the chosen difficulty.
	var waited := 0
	while range.player.health >= range.player.max_health and waited < 1200:
		await _frames(1)
		waited += 1
	_check(range.player.health < range.player.max_health, "training mobsters shoot Max")
	range.queue_free()
	await _frames(2)
	# Or practice targets instead, picked on the title screen.
	Game.training_mobsters = 0
	range = MAIN_SCENE.instantiate()
	add_child(range)
	await _frames(5)
	var targets := range.find_children("*", "", true, false).filter(func(node: Node) -> bool: return node is TargetDummy)
	_check(targets.size() == spots and range.find_children("*", "Enemy", true, false).is_empty(),
			"the training range can have practice targets instead")
	range.queue_free()
	await _frames(2)
	# Or just a few mobsters.
	Game.training_mobsters = 2
	range = MAIN_SCENE.instantiate()
	add_child(range)
	await _frames(5)
	_check(get_tree().get_nodes_in_group(&"enemies").size() == 2, "the number of training mobsters can be picked")
	range.queue_free()
	await _frames(2)
	Game.training_mobsters = 3


func _test_survival() -> void:
	Game.difficulty = Game.Difficulty.HARD_BOILED
	var game: Survival = SURVIVAL_SCENE.instantiate()
	add_child(game)
	var player := game.player
	await _frames(5)
	_check(game.wave_size(1) == 3 and game.wave_size(2) == 5, "each wave brings two more mobsters")
	_check(player.painkillers == 2, "Max starts with painkillers")

	# --- Waves and enemies -------------------------------------------------------
	game.break_left = 0.05
	await _frames(90)
	_check(game.wave == 1, "the first wave starts")
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	_check(enemies.size() >= 1, "mobsters enter the street")
	# Bring one into the open in front of Max to save time.
	var shooter := enemies[0] as Enemy
	shooter.global_position = player.global_position + Vector3(0, 0, -10)
	var waited := 0
	while player.health >= player.max_health and waited < 900:
		await _frames(1)
		waited += 1
	_check(player.health < player.max_health, "mobsters shoot Max (health %.0f)" % player.health)

	# --- Kills, drops and pickups ------------------------------------------------
	var reserve := player.pistol.reserve_ammo
	shooter.take_hit(1000.0, shooter.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD)
	_check(shooter.state == Enemy.State.DEAD, "a mobster dies")
	_check(game.kills == 1, "kills are counted")
	await _frames(2)
	var ammo: Pickup = null
	for pickup: Pickup in get_tree().get_nodes_in_group(&"pickups"):
		if pickup.kind == Pickup.Kind.AMMO:
			ammo = pickup
	_check(ammo != null, "dead mobsters drop ammo")
	if ammo:
		player.global_position = ammo.global_position
		await _frames(10)
		_check(player.pistol.reserve_ammo > reserve, "walking over ammo picks it up")

	# Clear the wave: kill every mobster, including the ones still to come.
	waited = 0
	while game.remaining() > 0 and waited < 1200:
		for enemy: Enemy in get_tree().get_nodes_in_group(&"enemies"):
			enemy.take_hit(1000.0, enemy.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD)
		await _frames(1)
		waited += 1
	_check(game.remaining() == 0 and game.break_left > 14.0, "the next wave comes 15 s after a wave is cleared")

	# Heal between waves, with nobody shooting: wait for stray bullets, and
	# clear the drops so none is picked up meanwhile.
	for pickup in get_tree().get_nodes_in_group(&"pickups"):
		pickup.queue_free()
	await get_tree().create_timer(1.0).timeout
	var hurt_health := player.health
	var bottles := player.painkillers
	_check(player.use_painkiller(), "Max takes a painkiller")
	await get_tree().create_timer(1.4).timeout
	_check(player.health > hurt_health and player.painkillers == bottles - 1,
			"painkillers heal (%.0f -> %.0f)" % [hurt_health, player.health])

	# Painkillers turn up at random on the street, a few at a time.
	var bottle := game.spawn_map_painkiller()
	_check(bottle != null and bottle.kind == Pickup.Kind.PAINKILLER
			and bottle.global_position.distance_to(player.global_position) >= Survival.MIN_PAINKILLER_DISTANCE,
			"painkillers turn up at random spots, away from Max")
	for i in Survival.MAX_MAP_PAINKILLERS:
		game.spawn_map_painkiller()
	_check(get_tree().get_nodes_in_group(&"map_painkillers").size() == Survival.MAX_MAP_PAINKILLERS,
			"no more than %d painkillers on the map at once" % Survival.MAX_MAP_PAINKILLERS)
	for pickup in get_tree().get_nodes_in_group(&"map_painkillers"):
		pickup.queue_free()

	# --- Curbs -----------------------------------------------------------------------
	player.global_position = Vector3(4.0, 0.05, 12.5)
	player.set(&"_yaw", -PI * 0.5)  # Facing +X, towards the sidewalk.
	await _frames(5)
	Input.action_press(&"move_forward")
	await get_tree().create_timer(1.0).timeout
	Input.action_release(&"move_forward")
	_check(player.global_position.x > 6.8 and player.global_position.y > StreetLevel.CURB_HEIGHT * 0.7,
			"Max walks up the curb onto the sidewalk (%.2f, %.2f)" % [player.global_position.x, player.global_position.y])

	# --- Cover -----------------------------------------------------------------------
	# The concrete barrier at (-2.5, 12) is waist high; stand east of it, facing west.
	player.global_position = Vector3(-1.4, 0.05, 12.0)
	player.set(&"_yaw", PI * 0.5)
	await _frames(10)
	_check(player.try_take_cover(), "Max takes cover behind a barrier")
	await _frames(30)
	_check(player.state == Player.State.COVER and player.is_crouching(), "Max ducks behind low cover")
	player.call(&"_fire")
	await _frames(2)
	_check(not player.is_crouching(), "shooting from cover pops Max up")
	await _frames(30)
	_check(player.pistol.ammo_in_magazine < player.pistol.magazine_size, "the shot from cover is fired")

	# --- Death -----------------------------------------------------------------------
	var game_over := [false]
	game.game_over.connect(func(_wave: int, _kills: int, _record: bool) -> void: game_over[0] = true)
	player.take_hit(1000.0, player.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD)
	_check(player.state == Player.State.DEAD, "Max dies")
	await get_tree().create_timer(3.0).timeout
	_check(game_over[0], "the game over screen comes up")
	game.queue_free()
	await _frames(2)


func _test_coop() -> void:
	# Player one on the keyboard, player two on controller 5.
	Game.coop = true
	Game.coop_joypads = [-1, 5]
	var game: Survival = SURVIVAL_SCENE.instantiate()
	add_child(game)
	await _frames(10)
	_check(game.players.size() == 2 and get_tree().get_nodes_in_group(&"player").size() == 2, "co-op brings in player two")
	_check(game.find_children("*", "SubViewport", true, false).size() == 2 and get_viewport().disable_3d,
			"the screen splits in two halves")
	var huds := 0
	for view: SubViewport in game.find_children("*", "SubViewport", true, false):
		huds += view.find_children("*", "CanvasLayer", false, false).size()
	_check(huds == 2, "each half has its own HUD")
	var one := game.players[0]
	var two := game.players[1]
	# Player two's controller moves only player two.
	var one_start := one.global_position
	var two_start := two.global_position
	var stick := InputEventJoypadMotion.new()
	stick.device = 5
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await _frames(30)
	stick = stick.duplicate()
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	_check(two.global_position.distance_to(two_start) > 0.5 and one.global_position.distance_to(one_start) < 0.1,
			"player two's controller moves player two only")
	await _frames(30)
	# And the keyboard moves only player one.
	one_start = one.global_position
	two_start = two.global_position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(30)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(2)
	_check(one.global_position.distance_to(one_start) > 0.5 and two.global_position.distance_to(two_start) < 0.1,
			"the keyboard moves player one only (%.2f, %.2f)" % [one.global_position.distance_to(one_start), two.global_position.distance_to(two_start)])
	# A fallen player gets back up at the next wave; both down is game over.
	two.take_hit(1000.0, two.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD)
	_check(two.state == Player.State.DEAD and not game.is_over, "the game goes on while one player is standing")
	game.call(&"_start_wave")
	await _frames(2)
	_check(two.state == Player.State.NORMAL and two.health > 0.0, "a fallen player gets back up at the next wave")
	for each: Player in game.players:
		each.take_hit(1000.0, each.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD)
	_check(game.is_over, "the game is over when both players are down")
	game.queue_free()
	await _frames(2)
	_check(not get_viewport().disable_3d, "leaving co-op restores the main view")
	Game.coop = false


func _test_title_screen() -> void:
	var title: TitleScreen = TITLE_SCENE.instantiate()
	add_child(title)
	await _frames(5)
	var before := Game.difficulty
	title.call(&"_cycle_difficulty", 1)
	_check(Game.difficulty != before, "the title screen changes the difficulty")
	title.call(&"_cycle_difficulty", -1)
	_check(Game.difficulty == before, "and changes it back")
	title.call(&"_show_controls", true)
	title.call(&"_show_controls", false)
	_check(get_viewport().gui_get_focus_owner() is Button, "closing the controls puts the focus back on the menu")
	var was_muted := Game.muted
	Game.set_muted(not was_muted)
	_check(AudioServer.is_bus_mute(0) != was_muted, "the sound option mutes and unmutes the game")
	Game.set_muted(was_muted)
	# Cross / A on a controller presses the focused menu button.
	var focused := get_viewport().gui_get_focus_owner() as Button
	var pressed := [false]
	if focused:
		focused.pressed.connect(func() -> void: pressed[0] = true)
		# Don't actually start a game.
		for connection in focused.pressed.get_connections():
			if connection.callable.get_method() == &"start_survival":
				focused.pressed.disconnect(connection.callable)
	# Controller 1, not 0: browsers often number a reconnected controller 1.
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.device = 1
	button.pressed = true
	Input.parse_input_event(button)
	await _frames(2)
	button = button.duplicate()
	button.pressed = false
	Input.parse_input_event(button)
	await _frames(2)
	_check(pressed[0], "any controller's Cross / A button presses menu buttons")
	title.queue_free()
	await _frames(2)


## Touch events arrive in window coordinates; [param position] is given in
## canvas (UI) coordinates and converted, like a real screen would report it.
func _send_touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_drag(index: int, position: Vector2, relative: Vector2) -> void:
	var to_window := get_viewport().get_final_transform()
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to_window * position
	event.relative = to_window.basis_xform(relative)
	Input.parse_input_event(event)


func _send_axis(axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)


## Angle in degrees between where the right pistol points and the crosshair.
func _joy_button_in(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func _joy_axis_in(action: StringName, axis: JoyAxis) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == axis:
			return true
	return false


func _gun_aim_error(player: Player) -> float:
	var gun := player.pistol.right_gun
	var to_aim := player.aim_point - gun.muzzle.global_position
	return rad_to_deg((-gun.global_basis.z).angle_to(to_aim))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok    %s" % description)
	else:
		_failures += 1
		print("  FAIL  %s" % description)
