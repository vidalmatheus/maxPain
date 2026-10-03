class_name ImpactEffect
extends CPUParticles3D
## One-shot burst of sparks (or blood) spawned where a bullet hits.
##
## Uses CPU particles so it works on every renderer, including the web.
## Particles follow the scaled process delta, so they slow down in bullet time.

## Meshes are cached per color so repeated impacts don't allocate resources.
static var _mesh_cache := {}


static func spawn(parent: Node, at: Vector3, normal: Vector3, color: Color) -> ImpactEffect:
	var effect := ImpactEffect.new()
	effect._configure(color)
	parent.add_child(effect)
	effect.global_position = at
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	effect.look_at(at + normal, up)
	effect.emitting = true
	return effect


func _configure(color: Color) -> void:
	one_shot = true
	explosiveness = 0.95
	amount = 16
	lifetime = 0.5
	direction = Vector3.FORWARD  # -Z, which look_at() aligns with the surface normal.
	spread = 40.0
	initial_velocity_min = 2.0
	initial_velocity_max = 6.0
	gravity = Vector3(0.0, -12.0, 0.0)
	scale_amount_min = 0.5
	scale_amount_max = 1.2
	mesh = _get_mesh(color)
	finished.connect(queue_free)


static func _get_mesh(color: Color) -> Mesh:
	var key := color.to_html()
	if not _mesh_cache.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		var sphere := SphereMesh.new()
		sphere.radius = 0.02
		sphere.height = 0.04
		sphere.radial_segments = 6
		sphere.rings = 3
		sphere.material = material
		_mesh_cache[key] = sphere
	return _mesh_cache[key]
