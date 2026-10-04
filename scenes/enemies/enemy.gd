class_name Enemy
extends CharacterBody3D
## A mobster with a Beretta. Runs (along the navigation mesh) until it can see
## Max, then shoots at him in bursts. Hurt mobsters run for cover on the far
## side of a car or barrier, duck behind it and pop up to shoot.
##
## Accuracy, damage, health and reaction time come from the difficulty
## (see Game.SETTINGS). Like in the original game, a shootdodging Max is much
## harder to hit. Dead mobsters drop ammo and sometimes adrenaline or
## painkillers.

signal died(enemy: Enemy)

enum State { ADVANCE, ATTACK, COVER, DEAD }

const BULLET_SCENE := preload("res://scenes/weapons/bullet.tscn")
const BLOOD_COLOR := Color(0.6, 0.04, 0.04)
## Hits above this height (from the feet) are headshots.
const HEAD_HEIGHT := 1.5
const HEADSHOT_MULTIPLIER := 3.0
const EYE_HEIGHT := 1.55
## Jacket and pants tints, picked at random for each mobster.
const CLOTHES := [
	[Color(0.35, 0.35, 0.38), Color(0.5, 0.5, 0.55)],
	[Color(0.75, 0.45, 0.3), Color(0.35, 0.3, 0.3)],
	[Color(0.3, 0.42, 0.3), Color(0.45, 0.42, 0.35)],
	[Color(0.55, 0.2, 0.18), Color(0.25, 0.25, 0.28)],
	[Color(0.25, 0.28, 0.45), Color(0.3, 0.3, 0.32)],
]
const CORPSE_TIME := 9.0
## Seconds a mobster reels after a pistol-whip, unable to shoot.
const STAGGER_TIME := 0.9

@export var run_speed := 4.2
@export var strafe_speed := 1.6
## Mobsters stop advancing and open fire inside this distance.
@export var attack_range := 16.0
@export var bullet_speed := 70.0
@export var rounds_per_magazine := 12
@export var reload_time := 1.8
@export var shots_per_burst := 3
@export var shot_interval := 0.22

var state := State.ADVANCE
var health := 100.0
var target: Player

var _damage := 10.0
var _spread_degrees := 4.0
var _reaction_time := 0.75
var _burst_interval := 1.4
var _drop_adrenaline_chance := 0.4
var _drop_painkiller_chance := 0.2

var _think_timer := 0.0
var _can_see := false
## How long Max has been in sight; mobsters need a moment to react.
var _sight_time := 0.0
var _unseen_time := 0.0
var _burst_left := 0
var _shot_timer := 0.0
var _ammo := 0
var _reload_timer := 0.0
var _strafe_side := 1.0
var _strafe_timer := 0.0
var _crouched := false
var _popup_timer := 0.0
var _cover_point := Vector3.ZERO
var _cover_time := 0.0
var _aim_point := Vector3.ZERO
var _running_backwards := false
var _stagger_timer := 0.0

@onready var visual: Node3D = $Visual
@onready var model: CharacterModel = $Visual/Model
@onready var gun: GunModel = $Gun
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(&"enemies")
	collision_shape.shape = collision_shape.shape.duplicate()
	var clothes: Array = CLOTHES.pick_random()
	model.set_clothes_tint(clothes[0], clothes[1])
	model.hands_posed.connect(_hold_gun)
	_ammo = rounds_per_magazine
	_think_timer = randf() * 0.4
	_strafe_side = 1.0 if randf() < 0.5 else -1.0
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Player


## Applies the current difficulty's tuning.
func apply_difficulty() -> void:
	health = Game.setting("enemy_health")
	_damage = Game.setting("enemy_damage")
	_spread_degrees = Game.setting("enemy_spread_degrees")
	_reaction_time = Game.setting("enemy_reaction_time")
	_burst_interval = Game.setting("enemy_burst_interval")
	_drop_adrenaline_chance = Game.setting("drop_adrenaline_chance")
	_drop_painkiller_chance = Game.setting("drop_painkiller_chance")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		velocity.y -= 14.0 * delta
		move_and_slide()
		return
	if target == null or target.state == Player.State.DEAD:
		_idle(delta)
		return
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		_idle(delta)
		_update_visual(delta)
		return

	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = randf_range(0.25, 0.4)
		_think()

	if _can_see:
		_sight_time += delta
		_unseen_time = 0.0
	else:
		_sight_time = 0.0
		_unseen_time += delta

	var move := Vector3.ZERO
	match state:
		State.ADVANCE:
			move = _follow_path(run_speed)
			if _can_see and global_position.distance_to(target.global_position) < attack_range:
				state = State.ATTACK
		State.ATTACK:
			move = _strafe(delta)
			if _unseen_time > 2.0 or global_position.distance_to(target.global_position) > attack_range * 1.3:
				state = State.ADVANCE
		State.COVER:
			move = _follow_path(run_speed)
			_cover_time += delta
			if agent.is_navigation_finished():
				move = Vector3.ZERO
			if _cover_time > 9.0 or (_unseen_time > 3.0 and agent.is_navigation_finished()):
				state = State.ADVANCE

	move += _separation()
	var accel := 18.0 * delta
	velocity.x = move_toward(velocity.x, move.x, accel)
	velocity.z = move_toward(velocity.z, move.z, accel)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 14.0 * delta
	move_and_slide()

	_update_shooting(delta)
	_update_crouch(delta)
	_update_visual(delta)


func _idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	move_and_slide()
	model.set_locomotion(CharacterModel.Locomotion.IDLE, 0.0)


## Re-evaluates sight and where to go a few times per second.
func _think() -> void:
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var query := PhysicsRayQueryParameters3D.create(eye, target.get_target_point(), 1, [get_rid()])
	_can_see = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if state == State.ADVANCE:
		agent.target_position = target.global_position


func _follow_path(speed: float) -> Vector3:
	if agent.is_navigation_finished():
		return Vector3.ZERO
	var next := agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.ZERO
	return direction.normalized() * speed


## Sidesteps while shooting, changing direction now and then.
func _strafe(delta: float) -> Vector3:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.8, 2.0)
		_strafe_side = -_strafe_side if randf() < 0.6 else _strafe_side
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var side := to_target.normalized().cross(Vector3.UP) * _strafe_side
	# Don't strafe off the navigable area (into cars, walls).
	var ahead := global_position + side * 0.8
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_closest_point(map, ahead).distance_to(ahead) > 0.3:
		_strafe_side = -_strafe_side
		return Vector3.ZERO
	return side * strafe_speed


## Keeps mobsters from walking into each other.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		if other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance < 1.2 and distance > 0.001:
			push += away / distance * (1.2 - distance) * 3.0
	return push


# --- Shooting ----------------------------------------------------------------

func _update_shooting(delta: float) -> void:
	_aim_point = target.get_target_point()
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_ammo = rounds_per_magazine
			gun.insert_magazine()
		return
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	if _burst_left > 0:
		_shoot()
		_burst_left -= 1
		_shot_timer = shot_interval if _burst_left > 0 else _burst_interval * randf_range(0.8, 1.3)
		return
	# Start a burst once Max has been in sight long enough to react.
	if _can_see and _sight_time >= _reaction_time and state != State.ADVANCE:
		if _crouched:
			_popup_timer = 0.35 + shots_per_burst * shot_interval
			_shot_timer = 0.3  # Stand up first.
		_burst_left = shots_per_burst
	elif _can_see and _sight_time >= _reaction_time and state == State.ADVANCE and randf() < 0.01:
		# Running mobsters occasionally fire on the move.
		_burst_left = 1


func _shoot() -> void:
	if _ammo <= 0:
		_start_reload()
		return
	_ammo -= 1
	var origin := gun.muzzle.global_position
	var direction := (_aim_point - origin).normalized()
	var spread := _spread_degrees
	if target.state == Player.State.DIVING:
		spread *= 2.2  # Shootdodging makes Max hard to hit.
	elif target.velocity.length() > 3.0:
		spread *= 1.3
	direction = _apply_spread(direction, spread)
	var bullet: Bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.launch(origin, direction * bullet_speed, _damage, [get_rid()], Bullet.ENEMY_BULLET_MASK)
	gun.play_fire()
	model.play_fire()
	if _ammo <= 0:
		_start_reload()


func _start_reload() -> void:
	_burst_left = 0
	_reload_timer = reload_time
	gun.drop_magazine()
	model.play_reload(reload_time)


static func _apply_spread(direction: Vector3, spread_degrees: float) -> Vector3:
	var spread := deg_to_rad(spread_degrees)
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(direction).normalized()
	return direction.rotated(side, randfn(0.0, spread * 0.5)).rotated(up, randfn(0.0, spread * 0.5))


# --- Cover -----------------------------------------------------------------------

## Runs to the far side of the nearest cover, out of Max's sight.
func _seek_cover() -> bool:
	var best := Vector3.ZERO
	var best_score := INF
	var map := get_world_3d().navigation_map
	var space := get_world_3d().direct_space_state
	for cover: Node3D in get_tree().get_nodes_in_group(&"cover"):
		var distance := global_position.distance_to(cover.global_position)
		if distance > 14.0:
			continue
		var away := cover.global_position - target.global_position
		away.y = 0.0
		var spot := cover.global_position + away.normalized() * 1.8
		spot = NavigationServer3D.map_get_closest_point(map, spot)
		# The spot must be hidden from Max (by the cover itself).
		var query := PhysicsRayQueryParameters3D.create(target.get_target_point(), spot + Vector3(0, 0.6, 0), 1)
		if space.intersect_ray(query).is_empty():
			continue
		var score := global_position.distance_to(spot) + randf() * 3.0
		if score < best_score:
			best_score = score
			best = spot
	if best_score == INF:
		return false
	_cover_point = best
	_cover_time = 0.0
	agent.target_position = best
	state = State.COVER
	return true


func _update_crouch(delta: float) -> void:
	_popup_timer = maxf(_popup_timer - delta, 0.0)
	var at_cover := state == State.COVER and agent.is_navigation_finished()
	_crouched = at_cover and _popup_timer <= 0.0
	var capsule := collision_shape.shape as CapsuleShape3D
	var height := 1.1 if _crouched else 1.8
	if not is_equal_approx(capsule.height, height):
		capsule.height = height
		collision_shape.position.y = height * 0.5


# --- Visuals ---------------------------------------------------------------------

func _update_visual(delta: float) -> void:
	var to_aim := _aim_point - global_position
	var aim_yaw := atan2(-to_aim.x, -to_aim.z)
	var ground := Vector3(velocity.x, 0.0, velocity.z)
	var speed := ground.length()
	var facing := aim_yaw
	if _crouched:
		model.set_locomotion(CharacterModel.Locomotion.CROUCH, 0.0)
	elif speed < 0.4:
		model.set_locomotion(CharacterModel.Locomotion.IDLE, 0.0)
	else:
		var relative := wrapf(atan2(-ground.x, -ground.z) - aim_yaw, -PI, PI)
		var threshold := PI * 0.5 + (-0.25 if _running_backwards else 0.25)
		_running_backwards = absf(relative) > threshold
		if _running_backwards:
			model.set_locomotion(CharacterModel.Locomotion.RUN_BACK, speed)
			facing += wrapf(relative - PI, -PI, PI)
		else:
			model.set_locomotion(CharacterModel.Locomotion.RUN, speed)
			facing += relative
	visual.rotation.y = lerp_angle(visual.rotation.y, facing, 1.0 - exp(-10.0 * delta))
	model.aim_at(_aim_point if _can_see or state != State.ADVANCE else global_position + ground.normalized() * 10.0 + Vector3(0, 1.3, 0))


func _hold_gun() -> void:
	if state != State.DEAD:
		gun.global_transform = model.get_gun_transform("r")


# --- Damage ----------------------------------------------------------------------

## Called by bullets.
func take_hit(damage: float, point: Vector3, direction: Vector3) -> void:
	ImpactEffect.spawn(get_parent(), point, -direction, BLOOD_COLOR)
	if state == State.DEAD:
		return
	var headshot := point.y - global_position.y >= HEAD_HEIGHT * (0.62 if _crouched else 1.0)
	health -= damage * (HEADSHOT_MULTIPLIER if headshot else 1.0)
	model.play_hit()
	# Getting shot gives the shooter away.
	_sight_time = maxf(_sight_time, _reaction_time * 0.5)
	if health <= 0.0:
		_die(direction)
	elif state != State.COVER and health < Game.setting("enemy_health") * 0.6 and randf() < 0.6:
		_seek_cover()


## Knocked back by a pistol-whip: reels for a moment, unable to shoot.
func stagger(push: Vector3) -> void:
	if state == State.DEAD:
		return
	_stagger_timer = STAGGER_TIME
	_burst_left = 0
	_shot_timer = maxf(_shot_timer, 0.3)
	velocity = Vector3(push.x, 0.0, push.z)


func _die(direction: Vector3) -> void:
	state = State.DEAD
	remove_from_group(&"enemies")
	collision_layer = 0
	collision_mask = 1
	velocity = direction * 1.5
	model.play_death()
	_drop_gun(direction)
	_drop_loot()
	BulletTime.add_adrenaline(BulletTime.kill_reward)
	died.emit(self)
	get_tree().create_timer(CORPSE_TIME, false).timeout.connect(queue_free)


## Lets go of the gun, which falls to the ground.
func _drop_gun(direction: Vector3) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.04, 0.14, 0.22)
	shape.shape = box
	body.add_child(shape)
	get_parent().add_child(body)
	body.global_transform = Transform3D(gun.global_basis.orthonormalized(), gun.global_position)
	gun.reparent(body)
	gun.top_level = false
	body.linear_velocity = direction * 1.5 + Vector3.UP * 1.0
	body.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	get_tree().create_timer(CORPSE_TIME, false).timeout.connect(body.queue_free)


func _drop_loot() -> void:
	var spot := global_position + Vector3(0, 0.05, 0)
	Pickup.spawn(get_parent(), Pickup.Kind.AMMO, spot)
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 0.8
	if randf() < _drop_adrenaline_chance:
		Pickup.spawn(get_parent(), Pickup.Kind.ADRENALINE, spot + side)
	if randf() < _drop_painkiller_chance:
		Pickup.spawn(get_parent(), Pickup.Kind.PAINKILLER, spot - side)
