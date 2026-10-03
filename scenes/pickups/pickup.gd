class_name Pickup
extends Area3D
## Something a dead enemy drops: ammo, adrenaline for bullet time or a bottle
## of painkillers. Spins and glows on the ground until Max walks over it, and
## disappears after a while (blinking first).

enum Kind { AMMO, ADRENALINE, PAINKILLER }

const LIFETIME := 25.0
const BLINK_TIME := 5.0
const AMMO_ROUNDS := 24
const ADRENALINE_AMOUNT := 35.0
const PICKUP_SOUND := preload("res://assets/sounds/reload_magazine_in.ogg")
const GLOW := {
	Kind.AMMO: Color(1.0, 0.75, 0.3),
	Kind.ADRENALINE: Color(0.45, 0.65, 1.0),
	Kind.PAINKILLER: Color(1.0, 0.95, 0.9),
}

var kind := Kind.AMMO

var _age := 0.0
var _visual: Node3D


## Creates a pickup of [param pickup_kind] lying at [param position].
static func spawn(parent: Node, pickup_kind: Kind, position: Vector3) -> Pickup:
	var pickup := Pickup.new()
	pickup.kind = pickup_kind
	parent.add_child(pickup)
	pickup.global_position = position
	return pickup


func _ready() -> void:
	add_to_group(&"pickups")
	collision_layer = 0
	collision_mask = 2  # player
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	shape.shape = sphere
	shape.position.y = 0.5
	add_child(shape)
	_visual = _build_visual()
	add_child(_visual)
	var light := OmniLight3D.new()
	light.light_color = GLOW[kind]
	light.light_energy = 0.8
	light.omni_range = 1.6
	light.position.y = 0.4
	add_child(light)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_age += delta
	_visual.rotation.y += delta * 2.0
	_visual.position.y = 0.3 + sin(_age * 3.0) * 0.05
	if _age > LIFETIME - BLINK_TIME:
		visible = fmod(_age, 0.3) < 0.18
	if _age > LIFETIME:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or player.state == Player.State.DEAD:
		return
	var text := ""
	match kind:
		Kind.AMMO:
			player.pistol.add_ammo(AMMO_ROUNDS)
			text = "+%d rounds" % AMMO_ROUNDS
		Kind.ADRENALINE:
			BulletTime.add_adrenaline(ADRENALINE_AMOUNT)
			text = "Adrenaline"
		Kind.PAINKILLER:
			if not player.add_painkiller():
				return  # Pockets full: leave it there.
			text = "Painkillers"
	SoundFx.play_3d(PICKUP_SOUND, global_position, -2.0, 1.2, 4.0)
	Game.message.emit(text)
	queue_free()


func _build_visual() -> Node3D:
	var root := Node3D.new()
	match kind:
		Kind.AMMO:
			# A box of 9 mm rounds.
			root.add_child(_box(Vector3(0.32, 0.16, 0.22), Color(0.2, 0.25, 0.15), 0.0))
			root.add_child(_box(Vector3(0.3, 0.03, 0.2), Color(0.85, 0.65, 0.25), 0.095))
		Kind.ADRENALINE:
			# A glowing blue hourglass, like the HUD's.
			for side: float in [1.0, -1.0]:
				var cone := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.14 if side > 0 else 0.02
				mesh.bottom_radius = 0.02 if side > 0 else 0.14
				mesh.height = 0.2
				mesh.material = _material(GLOW[kind], true)
				cone.mesh = mesh
				cone.position.y = side * 0.1
				root.add_child(cone)
		Kind.PAINKILLER:
			# A white pill bottle with a red cap.
			var bottle := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.07
			mesh.bottom_radius = 0.07
			mesh.height = 0.2
			mesh.material = _material(Color(0.92, 0.92, 0.9), false)
			bottle.mesh = mesh
			root.add_child(bottle)
			var cap := _box(Vector3(0.15, 0.05, 0.15), Color(0.75, 0.1, 0.08), 0.12)
			root.add_child(cap)
	return root


func _box(size: Vector3, color: Color, height: float) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, false)
	box.mesh = mesh
	box.position.y = height
	return box


func _material(color: Color, glowing: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	if glowing:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	return material
