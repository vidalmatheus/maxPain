class_name GunModel
extends Node3D
## Visual of a single Beretta: muzzle flash, recoil kick and the magazine,
## which drops out with physics when reloading and is replaced by a new one.
##
## The weapon logic (ammo, fire rate, bullets) lives in Pistol.

## Dropped magazines are removed after this many game seconds.
const DROPPED_MAGAZINE_LIFETIME := 12.0

@export var flash_duration := 0.05
## How far the gun kicks back and how much the muzzle flips up when firing.
@export var kick_distance := 0.035
@export var kick_degrees := 9.0

var _flash_timer := 0.0
var _kick := 0.0
var _model_rest := Transform3D.IDENTITY
var _magazine: Node3D

@onready var model: Node3D = $Model
@onready var muzzle: Marker3D = $Muzzle
@onready var muzzle_flash: Node3D = $Muzzle/MuzzleFlash


func _ready() -> void:
	_model_rest = model.transform
	muzzle_flash.visible = false
	# The source model also has a loose magazine lying next to the gun.
	var loose_magazine := model.find_child("Gun001", true, false) as Node3D
	if loose_magazine:
		loose_magazine.visible = false
	_magazine = model.find_child("Magazine", true, false) as Node3D


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			muzzle_flash.visible = false

	# Kick back and flip the muzzle up around the grip, then recover.
	_kick = move_toward(_kick, 0.0, delta * 0.45)
	var amount := _kick / kick_distance
	var kick := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(kick_degrees) * amount), Vector3(0.0, 0.0, _kick))
	model.transform = kick * _model_rest


func play_fire() -> void:
	_flash_timer = flash_duration
	muzzle_flash.visible = true
	muzzle_flash.rotation.z = randf() * TAU
	_kick = kick_distance


## Ejects the current magazine: a physics copy falls to the ground.
func drop_magazine() -> void:
	if _magazine == null or not _magazine.visible:
		return
	_magazine.visible = false
	for node in _magazine.find_children("*", "MeshInstance3D", true, false):
		_spawn_dropped_copy(node as MeshInstance3D)


func insert_magazine() -> void:
	if _magazine:
		_magazine.visible = true


func has_magazine() -> bool:
	return _magazine != null and _magazine.visible


func _spawn_dropped_copy(mesh_instance: MeshInstance3D) -> void:
	var source := mesh_instance.global_transform
	# Physics bodies must not be scaled: keep the scale on the mesh instead.
	var body := RigidBody3D.new()
	body.name = "DroppedMagazine"
	body.collision_layer = 0
	body.collision_mask = 1  # world only
	body.mass = 0.3
	body.add_to_group(&"dropped_magazines")
	var copy := MeshInstance3D.new()
	copy.mesh = mesh_instance.mesh
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = source.basis.get_scale() * mesh_instance.get_aabb().size
	shape.shape = box
	body.add_child(copy)
	body.add_child(shape)
	get_tree().current_scene.add_child(body)
	body.global_transform = Transform3D(source.basis.orthonormalized(), source.origin)
	copy.transform = body.global_transform.affine_inverse() * source
	shape.position = copy.transform * mesh_instance.get_aabb().get_center()
	body.linear_velocity = -global_basis.y * 0.6
	body.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	get_tree().create_timer(DROPPED_MAGAZINE_LIFETIME, false).timeout.connect(body.queue_free)
