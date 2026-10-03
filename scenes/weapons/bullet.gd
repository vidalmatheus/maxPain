class_name Bullet
extends Node3D
## A visible bullet that physically travels through the world.
##
## Instead of an instant hitscan, the bullet sweeps a ray along its path every
## physics frame. This keeps it visible in slow motion while never tunnelling
## through thin geometry, no matter how fast it moves.

## Physics layers bullets collide with (world, enemies, props).
const COLLISION_MASK := 0b1101
const SPARK_COLOR := Color(1.0, 0.8, 0.45)

@export var max_lifetime := 4.0
@export var trail_length := 2.5
## Impulse applied to rigid bodies that get hit.
@export var impact_impulse := 3.0

var velocity := Vector3.ZERO
var damage := 0.0

var _exclude: Array[RID] = []
var _age := 0.0
var _distance := 0.0

@onready var trail: Node3D = $Trail


func launch(origin: Vector3, initial_velocity: Vector3, bullet_damage: float, exclude: Array[RID]) -> void:
	global_position = origin
	velocity = initial_velocity
	damage = bullet_damage
	_exclude = exclude
	var up := Vector3.UP if absf(velocity.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	look_at(origin + velocity, up)
	trail.scale.z = 0.01


func _physics_process(delta: float) -> void:
	var from := global_position
	var step := velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, from + step, COLLISION_MASK, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_on_hit(hit)
		return

	global_position = from + step
	_distance += step.length()
	# The trail grows from the muzzle until it reaches its full length.
	trail.scale.z = clampf(_distance, 0.01, trail_length)

	_age += delta
	if _age >= max_lifetime:
		queue_free()


func _on_hit(hit: Dictionary) -> void:
	var collider: Object = hit["collider"]
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var direction := velocity.normalized()

	if collider.has_method(&"take_hit"):
		# Hittables spawn their own impact effects (e.g. blood).
		collider.call(&"take_hit", damage, point, direction)
	else:
		if collider is RigidBody3D:
			var rigid_body := collider as RigidBody3D
			rigid_body.apply_impulse(direction * impact_impulse, point - rigid_body.global_position)
		ImpactEffect.spawn(get_parent(), point, normal, SPARK_COLOR)
	queue_free()
