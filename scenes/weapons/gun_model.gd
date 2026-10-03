class_name GunModel
extends Node3D
## Visual of a single Beretta: muzzle flash, recoil kick, the shot sound and
## the magazine, which drops out with physics when reloading and is replaced
## by a new one. Spent casings and dropped magazines clink on the floor.
##
## The weapon logic (ammo, fire rate, bullets) lives in Pistol.

## Dropped magazines are removed after this many game seconds.
const DROPPED_MAGAZINE_LIFETIME := 12.0
## Spent casings are removed after this many game seconds, and the oldest are
## removed early if there are too many on the ground.
const CASING_LIFETIME := 8.0
const MAX_CASINGS := 60
## Each casing clinks on its first few bounces only.
const CASING_CLINKS := 3

const SHOT_SOUND := preload("res://assets/sounds/pistol_shot.ogg")
const CASING_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/casing_1.ogg"),
	preload("res://assets/sounds/casing_2.ogg"),
	preload("res://assets/sounds/casing_3.ogg"),
]
const MAGAZINE_DROP_SOUND := preload("res://assets/sounds/magazine_drop.ogg")

## Shared by every casing, created on first use.
static var _casing_mesh: Mesh
static var _casing_bounce: PhysicsMaterial

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
@onready var ejection_port: Marker3D = $EjectionPort


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
	SoundFx.play_3d(SHOT_SOUND, muzzle.global_position, 0.0, randf_range(0.94, 1.06), 20.0)
	_eject_casing()


## Throws a spent 9 mm casing out of the ejection port, to the right of the
## slide, spinning; it bounces on the floor with physics.
func _eject_casing() -> void:
	var casings := get_tree().get_nodes_in_group(&"shell_casings")
	if casings.size() >= MAX_CASINGS:
		casings[0].queue_free()

	var body := RigidBody3D.new()
	body.name = "ShellCasing"
	body.collision_layer = 0
	body.collision_mask = 1  # world only
	body.mass = 0.012
	body.continuous_cd = true  # tiny and fast: avoid falling through the floor
	body.physics_material_override = _get_casing_bounce()
	body.add_to_group(&"shell_casings")
	_clink_on_impact(body, CASING_CLINKS, func() -> void:
		# Brass rings much higher than the metal plates the samples come from.
		var speed := body.linear_velocity.length()
		SoundFx.play_3d(CASING_SOUNDS.pick_random(), body.global_position,
				linear_to_db(clampf(speed / 3.0, 0.2, 1.0)) - 6.0, randf_range(2.0, 2.6), 3.0))
	var mesh := MeshInstance3D.new()
	mesh.mesh = _get_casing_mesh()
	mesh.rotation.x = PI * 0.5  # cylinder along the barrel axis
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.012, 0.012, 0.024)
	shape.shape = box
	body.add_child(mesh)
	body.add_child(shape)
	get_tree().current_scene.add_child(body)
	body.global_transform = ejection_port.global_transform

	var right := global_basis.x
	var up := global_basis.y
	var back := global_basis.z
	body.linear_velocity = right * randf_range(2.0, 3.0) + up * randf_range(1.5, 2.5) + back * randf_range(0.2, 0.8)
	body.angular_velocity = Vector3(randf_range(-25, 25), randf_range(-25, 25), randf_range(-25, 25))
	get_tree().create_timer(CASING_LIFETIME, false).timeout.connect(body.queue_free)


## Calls [param play_sound] when [param body] hits the floor, for its first
## [param max_clinks] bounces.
func _clink_on_impact(body: RigidBody3D, max_clinks: int, play_sound: Callable) -> void:
	body.contact_monitor = true
	body.max_contacts_reported = 1
	var clinks := [0]  # boxed, so the lambda can count
	body.body_entered.connect(func(_other: Node) -> void:
		if clinks[0] < max_clinks:
			clinks[0] += 1
			play_sound.call())


static func _get_casing_mesh() -> Mesh:
	if _casing_mesh == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.85, 0.62, 0.25)
		material.metallic = 0.9
		material.roughness = 0.3
		# Slightly larger than a real 9 mm casing so it reads from the camera.
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.006
		cylinder.bottom_radius = 0.006
		cylinder.height = 0.024
		cylinder.radial_segments = 8
		cylinder.rings = 1
		cylinder.material = material
		_casing_mesh = cylinder
	return _casing_mesh


static func _get_casing_bounce() -> PhysicsMaterial:
	if _casing_bounce == null:
		_casing_bounce = PhysicsMaterial.new()
		_casing_bounce.bounce = 0.45
		_casing_bounce.friction = 0.6
	return _casing_bounce


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
	_clink_on_impact(body, 2, func() -> void:
		SoundFx.play_3d(MAGAZINE_DROP_SOUND, body.global_position, -4.0, randf_range(0.9, 1.1), 4.0))
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
