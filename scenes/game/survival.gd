class_name Survival
extends Node3D
## Survival mode: endless waves of mobsters on the street.
##
## Each wave has two more mobsters than the one before (the first wave's size
## depends on the difficulty). They come in from the ends of the streets, a
## few at a time, and the next wave starts BREAK_TIME seconds after the last
## mobster of a wave dies. The game ends when Max dies.

signal wave_started(wave: int, enemies: int)
signal wave_cleared(wave: int)
signal enemies_changed(remaining: int)
signal game_over(wave: int, kills: int, new_record: bool)

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
## Seconds before the first wave and between waves (real time).
const FIRST_DELAY := 5.0
const BREAK_TIME := 15.0
const ENEMIES_ADDED_PER_WAVE := 2
## Seconds between two mobsters entering the street.
const SPAWN_INTERVAL := 1.3
## Spawn points closer than this to Max are skipped.
const MIN_SPAWN_DISTANCE := 20.0

var wave := 0
var kills := 0
## Real seconds left until the next wave, or 0 during a wave.
var break_left := FIRST_DELAY
var is_over := false

var _to_spawn := 0
var _alive := 0
var _spawn_timer := 0.0

@onready var level: StreetLevel = $Street/Level
@onready var player: Player = $Player


func _ready() -> void:
	player.died.connect(_on_player_died)
	player.painkillers = Game.setting("start_painkillers")
	player.painkillers_changed.emit(player.painkillers)
	Music.play_gameplay()


func _process(delta: float) -> void:
	if is_over:
		return
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


func _start_wave() -> void:
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
		if point.distance_to(player.global_position) >= MIN_SPAWN_DISTANCE:
			spot = point
			break
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.target = player
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
	is_over = true
	var record := Game.record_wave(wave)
	get_tree().create_timer(2.5, true, false, true).timeout.connect(
			func() -> void: game_over.emit(wave, kills, record))
