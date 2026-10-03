class_name Snowfall
extends CPUParticles3D
## Snow falling around the camera. The emitter follows the active camera, so
## a small box of flakes is enough to fill the view anywhere in the level.
## Particles run in game time and drift slowly in bullet time.

## Size of the box of snow around the camera.
const AREA := Vector3(36.0, 14.0, 36.0)


func _ready() -> void:
	amount = 900 if not OS.has_feature("mobile") and not OS.has_feature("web_ios") and not OS.has_feature("web_android") else 450
	lifetime = 6.0
	preprocess = 6.0
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = AREA * 0.5
	direction = Vector3(0.15, -1, 0.05)
	spread = 12.0
	gravity = Vector3.ZERO
	initial_velocity_min = 1.0
	initial_velocity_max = 1.8
	scale_amount_min = 0.6
	scale_amount_max = 1.2
	var flake := QuadMesh.new()
	flake.size = Vector2(0.05, 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92, 0.94, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	flake.material = material
	mesh = flake
	emitting = true


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position + Vector3(0, AREA.y * 0.3, 0)
