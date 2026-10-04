class_name Survival
extends Node3D
## Survival mode: endless waves of mobsters on the street.
##
## Each wave has two more mobsters than the one before (the first wave's size
## depends on the difficulty). They come in from the ends of the streets, a
## few at a time, and the next wave starts BREAK_TIME seconds after the last
## mobster of a wave dies. The game ends when Max dies.
##
## In local co-op (Game.coop) a second player joins in split screen, each
## with their own camera and HUD. A player who dies gets back up when the
## next wave starts; the game ends when both are down.

signal wave_started(wave: int, enemies: int)
signal wave_cleared(wave: int)
signal enemies_changed(remaining: int)
signal game_over(wave: int, kills: int, new_record: bool)

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
## Player two's jacket and pants (multipliers above 1 lighten Max's dark
## leather), so the two can tell each other apart.
const PLAYER_TWO_CLOTHES := [Color(2.4, 1.7, 1.1), Color(1.3, 1.2, 1.1)]
## Name tags over the players' heads in co-op, each on its own render layer
## (from TAG_LAYER) so a player's own half doesn't show their tag.
const TAG_COLORS := [Color(1.0, 0.85, 0.3), Color(0.4, 0.75, 1.0)]
const TAG_LAYER := 10
## Seconds before the first wave and between waves (real time).
const FIRST_DELAY := 5.0
const BREAK_TIME := 15.0
const ENEMIES_ADDED_PER_WAVE := 2
## Seconds between two mobsters entering the street.
const SPAWN_INTERVAL := 1.3
## Spawn points closer than this to Max are skipped.
const MIN_SPAWN_DISTANCE := 20.0
## Painkiller bottles also turn up at random spots on the street, every
## PAINKILLER_INTERVAL seconds give or take PAINKILLER_JITTER, a few at a time.
const PAINKILLER_INTERVAL := 32.0
const PAINKILLER_JITTER := 8.0
const MAX_MAP_PAINKILLERS := 3
const MAP_PAINKILLER_LIFETIME := 60.0
## They show up at least this far from Max, so it takes a run to get them.
const MIN_PAINKILLER_DISTANCE := 8.0

var wave := 0
var kills := 0
## Real seconds left until the next wave, or 0 during a wave.
var break_left := FIRST_DELAY
var is_over := false

var _to_spawn := 0
var _alive := 0
var _spawn_timer := 0.0
var _painkiller_timer := PAINKILLER_INTERVAL
## Split screen: [camera in a half of the screen, the player it follows].
var _views: Array = []

@onready var level: StreetLevel = $Street/Level
## Player one (the only player outside co-op).
@onready var player: Player = $Player
@onready var players: Array[Player] = [player]


func _ready() -> void:
	if Game.coop:
		_start_coop()
	for each: Player in players:
		each.died.connect(_on_player_died)
		each.painkillers = Game.setting("start_painkillers")
		each.painkillers_changed.emit(each.painkillers)
	Music.play_gameplay()


func _process(delta: float) -> void:
	# Split screen: each half's camera follows its player's camera (players
	# update theirs first, see process_priority in _start_coop).
	for view: Array in _views:
		var camera: Camera3D = view[0]
		var source: Camera3D = (view[1] as Player).camera
		camera.global_transform = source.global_transform
		camera.fov = source.fov
	if is_over:
		return
	if wave > 0:
		_painkiller_timer -= delta
		if _painkiller_timer <= 0.0:
			_painkiller_timer = PAINKILLER_INTERVAL + randf_range(-PAINKILLER_JITTER, PAINKILLER_JITTER)
			spawn_map_painkiller()
	if break_left > 0.0:
		break_left = maxf(break_left - BulletTime.to_real_delta(delta), 0.0)
		if break_left == 0.0:
			_start_wave()
		return
	if _to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _alive < Game.setting("max_alive"):
			_spawn_enemy()
			_spawn_timer = SPAWN_INTERVAL


## Mobsters still to beat in this wave (alive or yet to come).
func remaining() -> int:
	return _alive + _to_spawn


func wave_size(number: int) -> int:
	return Game.setting("first_wave") + ENEMIES_ADDED_PER_WAVE * (number - 1)


## Drops a bottle of painkillers at a random reachable spot on the street.
## Returns it, or null when there are enough on the map already.
func spawn_map_painkiller() -> Pickup:
	var on_map := get_tree().get_nodes_in_group(&"map_painkillers").size()
	if on_map >= MAX_MAP_PAINKILLERS:
		return null
	var map := get_world_3d().navigation_map
	var spot := Vector3.ZERO
	for attempt in 12:
		spot = NavigationServer3D.map_get_random_point(map, 1, true)
		var inside := absf(spot.x) < StreetLevel.HALF_SIZE - 3.0 and absf(spot.z) < StreetLevel.HALF_SIZE - 3.0
		if inside and _distance_to_players(spot) >= MIN_PAINKILLER_DISTANCE:
			break
	var pickup := Pickup.spawn(self, Pickup.Kind.PAINKILLER, spot + Vector3(0, 0.05, 0))
	pickup.lifetime = MAP_PAINKILLER_LIFETIME
	pickup.add_to_group(&"map_painkillers")
	return pickup


func _start_wave() -> void:
	# Fallen co-op players get back up next to a standing one.
	for each: Player in players:
		if each.state == Player.State.DEAD:
			each.revive(_standing_player().global_position + Vector3(1.5, 0.1, 0.0))
	wave += 1
	_to_spawn = wave_size(wave)
	_spawn_timer = 0.0
	wave_started.emit(wave, _to_spawn)
	enemies_changed.emit(remaining())


func _spawn_enemy() -> void:
	var points := level.get_spawn_points()
	points.shuffle()
	var spot := points[0]
	for point in points:
		if _distance_to_players(point) >= MIN_SPAWN_DISTANCE:
			spot = point
			break
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.target = _standing_player()
	add_child(enemy)
	enemy.global_position = spot + Vector3(randf_range(-1.5, 1.5), 0.05, randf_range(-1.5, 1.5))
	enemy.apply_difficulty()
	enemy.died.connect(_on_enemy_died)
	_to_spawn -= 1
	_alive += 1


func _on_enemy_died(_enemy: Enemy) -> void:
	kills += 1
	_alive -= 1
	enemies_changed.emit(remaining())
	if remaining() == 0 and not is_over:
		wave_cleared.emit(wave)
		break_left = BREAK_TIME


func _on_player_died() -> void:
	if _standing_player() != null:
		return
	is_over = true
	var record := Game.record_wave(wave)
	get_tree().create_timer(2.5, true, false, true).timeout.connect(
			func() -> void: game_over.emit(wave, kills, record))


func _exit_tree() -> void:
	if Game.coop:
		get_viewport().disable_3d = false


## A player who is still standing (null when everyone is down).
func _standing_player() -> Player:
	for each: Player in players:
		if each.state != Player.State.DEAD:
			return each
	return null


func _distance_to_players(point: Vector3) -> float:
	var closest := INF
	for each: Player in players:
		closest = minf(closest, point.distance_to(each.global_position))
	return closest


## Local co-op: brings in player two and splits the screen in two halves,
## each with its own camera and HUD.
func _start_coop() -> void:
	GameInput.add_player_actions("p1_", Game.coop_joypads[0], true)
	GameInput.add_player_actions("p2_", Game.coop_joypads[1], false)
	player.input_prefix = "p1_"
	player.joypad = Game.coop_joypads[0] if Game.coop_joypads[0] >= 0 else -2
	var second: Player = PLAYER_SCENE.instantiate()
	second.name = "Player2"
	second.input_prefix = "p2_"
	second.joypad = Game.coop_joypads[1]
	second.uses_mouse = false
	second.position = player.position + Vector3(2.0, 0.0, 0.0)
	add_child(second)
	second.model.set_clothes_tint(PLAYER_TWO_CLOTHES[0], PLAYER_TWO_CLOTHES[1])
	players.append(second)
	for index in players.size():
		var tag := Label3D.new()
		tag.text = "P%d" % (index + 1)
		tag.font_size = 36
		tag.pixel_size = 0.006
		tag.modulate = TAG_COLORS[index]
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.position.y = 2.15
		tag.layers = 1 << (TAG_LAYER + index)
		players[index].add_child(tag)
	# The cameras follow the players after they have moved.
	process_priority = 100

	# The main view stops drawing the world: the two halves draw it instead.
	get_viewport().disable_3d = true
	var layer := CanvasLayer.new()
	layer.name = "SplitScreen"
	layer.layer = -1
	add_child(layer)
	var halves := HBoxContainer.new()
	halves.set_anchors_preset(Control.PRESET_FULL_RECT)
	halves.add_theme_constant_override(&"separation", 2)
	halves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(halves)
	for index in players.size():
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halves.add_child(container)
		var view := SubViewport.new()
		view.world_3d = get_viewport().find_world_3d()
		view.handle_input_locally = false
		container.add_child(view)
		var camera := Camera3D.new()
		camera.current = true
		camera.cull_mask &= ~(1 << (TAG_LAYER + index))
		view.add_child(camera)
		_views.append([camera, players[index]])
		if index == 0:
			$HUD.reparent(view)
		else:
			var hud: CanvasLayer = HUD_SCENE.instantiate()
			hud.set(&"player", players[index])
			view.add_child(hud)
