class_name TargetDummy
extends RigidBody3D
## Practice target: takes damage, topples over physically when killed,
## rewards adrenaline and respawns after a delay.
##
## While alive the body is frozen (kinematic) so it can optionally patrol.
## On death it is unfrozen and the killing shot knocks it over.

signal died

const BLOOD_COLOR := Color(0.7, 0.05, 0.05)

@export var max_health := 100.0
## Hits above this local height count as headshots.
@export var headshot_height := 1.48
@export var headshot_multiplier := 3.0
@export var death_impulse := 6.0
## Respawn delay in game seconds.
@export var respawn_delay := 6.0
## If greater than zero, the target slides back and forth along its local X axis.
@export var patrol_distance := 0.0
@export var patrol_speed := 1.5

var health := 0.0
var is_dead := false

var _spawn_transform := Transform3D.IDENTITY
var _patrol_time := 0.0
var _hit_flash := 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	health = max_health
	_spawn_transform = global_transform
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true

	# Give each target its own material so hit flashes don't affect the others.
	var body_mesh := $Body as MeshInstance3D
	_material = body_mesh.get_active_material(0).duplicate()
	_material.emission_enabled = true
	_material.emission = Color.WHITE
	_material.emission_energy_multiplier = 0.0
	for mesh_instance: MeshInstance3D in [body_mesh, $Head as MeshInstance3D]:
		mesh_instance.material_override = _material


func _physics_process(delta: float) -> void:
	if is_dead or patrol_distance <= 0.0:
		return
	_patrol_time += delta
	var offset := sin(_patrol_time * patrol_speed / patrol_distance) * patrol_distance
	global_position = _spawn_transform.origin + _spawn_transform.basis.x * offset


func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(_hit_flash - delta * 6.0, 0.0)
		_material.emission_energy_multiplier = _hit_flash * 2.0


## Called by bullets. [param direction] is the normalized bullet direction.
func take_hit(damage: float, point: Vector3, direction: Vector3) -> void:
	ImpactEffect.spawn(get_parent(), point, -direction, BLOOD_COLOR)
	if is_dead:
		apply_impulse(direction * death_impulse * 0.5, point - global_position)
		return

	var is_headshot := to_local(point).y >= headshot_height
	health -= damage * (headshot_multiplier if is_headshot else 1.0)
	_hit_flash = 1.0
	if health <= 0.0:
		_die(point, direction)


func _die(point: Vector3, direction: Vector3) -> void:
	is_dead = true
	freeze = false
	apply_impulse(direction * death_impulse, point - global_position)
	BulletTime.add_adrenaline(BulletTime.kill_reward)
	died.emit()
	get_tree().create_timer(respawn_delay, false).timeout.connect(_respawn)


func _respawn() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _spawn_transform
	health = max_health
	is_dead = false
	_patrol_time = 0.0
