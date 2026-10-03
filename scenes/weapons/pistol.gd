class_name Pistol
extends Node
## The player's Berettas: a single pistol or two in dual-wield mode.
##
## Handles ammo, fire rate, reloading and spawning bullets. The guns' visuals
## (muzzle flash, recoil, magazines) live in the GunModel nodes. Bullets are
## physical projectiles, and all timers run on game time, so in bullet time
## the fire rate, muzzle flash and reload slow down with the rest of the world.

signal fired(gun: GunModel)
signal ammo_changed(in_magazine: int, reserve: int)
signal reload_started(duration: float)
signal mode_changed(dual: bool)

const BULLET_SCENE := preload("res://scenes/weapons/bullet.tscn")

@export var right_gun: GunModel
@export var left_gun: GunModel

@export var damage := 34.0
## Minimum time between shots, in seconds.
@export var fire_interval := 0.15
@export var dual_fire_interval := 0.09
## Rounds per Beretta 92FS magazine; dual wield holds two.
@export var rounds_per_magazine := 15
@export var reserve_ammo := 180
@export var reload_time := 1.3
@export var dual_reload_time := 1.8
## Delay before firing after switching between one and two pistols.
@export var draw_time := 0.3
## Bullet speed in meters per second. Deliberately slower than a real bullet
## so it reads well in slow motion.
@export var bullet_speed := 90.0
@export var spread_degrees := 0.4
@export var dual_spread_degrees := 0.9
## Fraction of the reload after which the fresh magazine appears in the gun.
@export_range(0.0, 1.0) var magazine_insert_point := 0.6

var dual := false
var magazine_size := 0
var ammo_in_magazine := 0

var _cooldown := 0.0
var _reload_timer := 0.0
var _reload_duration := 0.0
var _magazine_inserted := true
## Which gun fires next in dual-wield mode (0 = right, 1 = left).
var _next_gun := 0


func _ready() -> void:
	magazine_size = rounds_per_magazine
	ammo_in_magazine = magazine_size
	left_gun.visible = false


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if not _magazine_inserted and _reload_timer <= _reload_duration * (1.0 - magazine_insert_point):
			_magazine_inserted = true
			for gun in get_active_guns():
				gun.insert_magazine()
		if _reload_timer <= 0.0:
			_finish_reload()


func is_reloading() -> bool:
	return _reload_timer > 0.0


func get_active_guns() -> Array[GunModel]:
	if dual:
		return [right_gun, left_gun]
	return [right_gun]


## Switches between one and two pistols. Loaded rounds go back to the reserve
## and a full magazine for the new mode is loaded, like in the original game.
func set_dual(enabled: bool) -> void:
	if enabled == dual or is_reloading():
		return
	dual = enabled
	left_gun.visible = dual
	reserve_ammo += ammo_in_magazine
	magazine_size = rounds_per_magazine * (2 if dual else 1)
	ammo_in_magazine = mini(magazine_size, reserve_ammo)
	reserve_ammo -= ammo_in_magazine
	_next_gun = 0
	_cooldown = draw_time
	mode_changed.emit(dual)
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)


## Fires one bullet towards [param target]. Returns true if a shot was fired.
## In dual-wield mode the two pistols take turns.
func try_fire(target: Vector3, exclude: Array[RID]) -> bool:
	if _cooldown > 0.0 or is_reloading():
		return false
	if ammo_in_magazine <= 0:
		reload()
		return false

	var gun := right_gun
	if dual:
		gun = right_gun if _next_gun == 0 else left_gun
		_next_gun = 1 - _next_gun
	ammo_in_magazine -= 1
	_cooldown = dual_fire_interval if dual else fire_interval
	_spawn_bullet(gun.muzzle.global_position, target, exclude)
	gun.play_fire()

	fired.emit(gun)
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)
	if ammo_in_magazine == 0:
		reload()
	return true


func reload() -> void:
	if is_reloading() or ammo_in_magazine == magazine_size or reserve_ammo <= 0:
		return
	_reload_duration = dual_reload_time if dual else reload_time
	_reload_timer = _reload_duration
	_magazine_inserted = false
	for gun in get_active_guns():
		gun.drop_magazine()
	reload_started.emit(_reload_duration)


func _finish_reload() -> void:
	var taken := mini(magazine_size - ammo_in_magazine, reserve_ammo)
	ammo_in_magazine += taken
	reserve_ammo -= taken
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)


func _spawn_bullet(origin: Vector3, target: Vector3, exclude: Array[RID]) -> void:
	var direction := target - origin
	if direction.length_squared() < 0.0001:
		direction = -right_gun.global_basis.z
	var spread := dual_spread_degrees if dual else spread_degrees
	direction = _apply_spread(direction.normalized(), spread)

	var bullet: Bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.launch(origin, direction * bullet_speed, damage, exclude)


func _apply_spread(direction: Vector3, spread_deg: float) -> Vector3:
	var spread := deg_to_rad(spread_deg)
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(direction).normalized()
	return direction.rotated(side, randf_range(-spread, spread)).rotated(up, randf_range(-spread, spread))
