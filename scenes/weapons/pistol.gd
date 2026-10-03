class_name Pistol
extends Node3D
## Semi-automatic pistol that fires physical, visible bullets.
##
## All timers run on game time, so in bullet time the fire rate, muzzle flash
## and reload slow down together with the rest of the world.

signal fired
signal ammo_changed(in_magazine: int, reserve: int)
signal reload_started(duration: float)

const BULLET_SCENE := preload("res://scenes/weapons/bullet.tscn")

@export var damage := 34.0
## Minimum time between shots, in seconds.
@export var fire_interval := 0.15
@export var magazine_size := 18
@export var reserve_ammo := 180
@export var reload_time := 1.3
## Bullet speed in meters per second. Deliberately slower than a real bullet
## so it reads well in slow motion.
@export var bullet_speed := 90.0
@export var spread_degrees := 0.4
@export var flash_duration := 0.05
## How far the gun model kicks back when firing.
@export var kick_distance := 0.07

var ammo_in_magazine := 0

var _cooldown := 0.0
var _reload_timer := 0.0
var _flash_timer := 0.0
var _kick := 0.0
var _model_rest_position := Vector3.ZERO

@onready var model: Node3D = $Model
@onready var muzzle: Marker3D = $Muzzle
@onready var muzzle_flash: Node3D = $Muzzle/MuzzleFlash


func _ready() -> void:
	ammo_in_magazine = magazine_size
	_model_rest_position = model.position
	muzzle_flash.visible = false


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			muzzle_flash.visible = false

	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	# Recover from the recoil kick (+Z points back towards the shooter).
	_kick = move_toward(_kick, 0.0, delta * 0.8)
	model.position = _model_rest_position + Vector3(0.0, 0.0, _kick)
	model.rotation.x = _kick * 5.0


func is_reloading() -> bool:
	return _reload_timer > 0.0


## Fires one bullet towards [param target]. Returns true if a shot was fired.
func try_fire(target: Vector3, exclude: Array[RID]) -> bool:
	if _cooldown > 0.0 or is_reloading():
		return false
	if ammo_in_magazine <= 0:
		reload()
		return false

	ammo_in_magazine -= 1
	_cooldown = fire_interval
	_spawn_bullet(target, exclude)

	_flash_timer = flash_duration
	muzzle_flash.visible = true
	muzzle_flash.rotation.z = randf() * TAU
	_kick = kick_distance

	fired.emit()
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)
	if ammo_in_magazine == 0:
		reload()
	return true


func reload() -> void:
	if is_reloading() or ammo_in_magazine == magazine_size or reserve_ammo <= 0:
		return
	_reload_timer = reload_time
	reload_started.emit(reload_time)


func _finish_reload() -> void:
	var taken := mini(magazine_size - ammo_in_magazine, reserve_ammo)
	ammo_in_magazine += taken
	reserve_ammo -= taken
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)


func _spawn_bullet(target: Vector3, exclude: Array[RID]) -> void:
	var origin := muzzle.global_position
	var direction := target - origin
	if direction.length_squared() < 0.0001:
		direction = -muzzle.global_basis.z
	direction = _apply_spread(direction.normalized())

	var bullet: Bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.launch(origin, direction * bullet_speed, damage, exclude)


func _apply_spread(direction: Vector3) -> Vector3:
	var spread := deg_to_rad(spread_degrees)
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(direction).normalized()
	return direction.rotated(side, randf_range(-spread, spread)).rotated(up, randf_range(-spread, spread))
