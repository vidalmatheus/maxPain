class_name StreetLevel
extends Node3D
## A snowy New York intersection at night, built in code from Kenney's city
## and car kits (CC0): two crossing streets lined with buildings, parked cars,
## police cars with flashing lights, street lamps and concrete barriers.
##
## Everything solid becomes a static body on the world layer, and the bodies
## you can hide behind join the "cover" group. The level bakes its own
## navigation mesh so enemies can find their way around the obstacles.
##
## Coordinates: the main street runs along Z, the cross street along X, and
## they meet at the origin. Each street is ROAD_WIDTH wide, with sidewalks.

const ROAD_WIDTH := 12.0
const SIDEWALK := 3.0
## The playable area is a square of this half size; past it is only scenery.
const HALF_SIZE := 42.0

const CARS := "res://assets/environment/cars/"
const ROADS := "res://assets/environment/city_roads/"
const BUILDINGS := "res://assets/environment/city_buildings/"
## Car models are toy sized: scale them to about 2 x 1.3 x 4.3 m (low enough
## to shoot over from behind).
const CAR_SCALE := Vector3(1.3, 1.0, 1.4)

const LAMP_COLOR := Color(1.0, 0.72, 0.42)
## Kenney's buildings are bright and clean; darken them into grimy brick and
## concrete for a night in New York.
const BUILDING_TINT := Color(0.42, 0.38, 0.36)
const CONCRETE := Color(0.55, 0.55, 0.53)

## Parked cars: [model, position (x, z), heading in degrees].
const PARKED_CARS := [
	["sedan", Vector2(-4.4, -30.0), 0.0], ["van", Vector2(-4.4, -21.0), 180.0],
	["taxi", Vector2(4.4, -26.0), 180.0], ["suv", Vector2(4.4, 19.0), 0.0],
	["sedan", Vector2(-4.4, 24.0), 180.0], ["hatchback-sports", Vector2(4.4, 31.0), 0.0],
	["van", Vector2(-27.0, -4.4), 90.0], ["sedan", Vector2(22.0, 4.4), 270.0],
	["taxi", Vector2(31.0, -4.4), 90.0], ["suv", Vector2(-20.0, 4.4), 270.0],
]
## Police cars around the intersection, parked at an angle, lights flashing.
const POLICE_CARS := [
	[Vector2(3.5, -9.5), 30.0], [Vector2(-6.0, 8.5), -55.0], [Vector2(9.5, 2.5), 100.0],
	[Vector2(-1.5, 36.0), 75.0],
]
## Concrete barriers (cover): [position (x, z), heading in degrees].
const BARRIERS := [
	[Vector2(-2.5, 12.0), 0.0], [Vector2(2.0, -15.5), 90.0], [Vector2(-12.0, -2.0), 90.0],
	[Vector2(13.0, -1.5), 0.0], [Vector2(-1.0, -27.0), 10.0], [Vector2(26.0, 1.5), 80.0],
	[Vector2(-28.0, 1.0), 100.0], [Vector2(1.5, 25.0), 95.0],
]
## Dumpsters (cover) on the sidewalks.
const DUMPSTERS := [
	[Vector2(7.6, -16.0), 90.0], [Vector2(-7.6, 15.0), 90.0], [Vector2(17.0, 7.6), 0.0],
	[Vector2(-33.0, -7.6), 0.0],
]
## Striped construction barriers (low cover).
const ROADWORKS := [
	[Vector2(-4.0, -6.5), 0.0], [Vector2(5.5, 7.0), 90.0], [Vector2(-8.0, -33.0), 30.0],
]
## Where enemies come from: the four ends of the streets.
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(0, 0, -38), Vector3(0, 0, 38), Vector3(-38, 0, 0), Vector3(38, 0, 0),
	Vector3(-3, 0, -38), Vector3(3, 0, 38), Vector3(-38, 0, 3), Vector3(38, 0, -3),
]

var _navigation: NavigationRegion3D
var _concrete: StandardMaterial3D


func _ready() -> void:
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = CONCRETE
	_concrete.roughness = 0.95

	_navigation = NavigationRegion3D.new()
	_navigation.name = "Navigation"
	add_child(_navigation)

	_build_ground()
	_build_buildings()
	_build_bounds()
	for car: Array in PARKED_CARS:
		_place_car(car[0], car[1], car[2])
	for police: Array in POLICE_CARS:
		_place_police_car(police[0], police[1])
	for barrier: Array in BARRIERS:
		_place_barrier(barrier[0], barrier[1])
	for dumpster: Array in DUMPSTERS:
		_place_model(ROADS + "dumpster.glb", dumpster[0], dumpster[1], Vector3.ONE * 6.0, true)
	for works: Array in ROADWORKS:
		_place_model(ROADS + "construction-barrier.glb", works[0], works[1], Vector3(9.0, 7.0, 9.0), true)
	_build_street_lamps()
	_bake_navigation()


## Spawn points for enemies, in world space.
func get_spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point in SPAWN_POINTS:
		points.append(to_global(point))
	return points


# --- Ground ------------------------------------------------------------------

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_SIZE * 4.0, 1.0, HALF_SIZE * 4.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	# Sidewalks and plazas: a big slab of pavement under the roads.
	var pavement := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_SIZE * 4.0, HALF_SIZE * 4.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.42, 0.44)
	material.roughness = 0.9
	plane.material = material
	pavement.mesh = plane
	ground.add_child(pavement)
	_navigation.add_child(ground)

	# Road tiles, slightly above the pavement, crossroad in the middle.
	var tiles := int(ceil(HALF_SIZE * 2.0 / ROAD_WIDTH)) + 2
	for i in range(-tiles / 2, tiles / 2 + 1):
		var offset := i * ROAD_WIDTH
		if i == 0:
			_place_tile("road-crossroad", Vector3.ZERO, 0.0)
			continue
		# The tile's road runs along X.
		_place_tile("road-straight", Vector3(0, 0, offset), 90.0)
		_place_tile("road-straight", Vector3(offset, 0, 0), 0.0)


func _place_tile(model: String, position: Vector3, heading: float) -> void:
	var tile := (load(ROADS + model + ".glb") as PackedScene).instantiate() as Node3D
	tile.position = position + Vector3(0, 0.01, 0)
	tile.rotation_degrees.y = heading
	tile.scale = Vector3(ROAD_WIDTH, 1.0, ROAD_WIDTH)
	add_child(tile)


# --- Buildings -----------------------------------------------------------------

func _build_buildings() -> void:
	var models := ["building-a", "building-b", "building-c", "building-d", "building-e",
			"building-f", "building-g", "building-h"]
	var edge := ROAD_WIDTH * 0.5 + SIDEWALK
	var index := 0
	for quadrant: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		# Facing the main street, then facing the cross street.
		for along: float in [edge + 6.0, edge + 17.0, edge + 28.0]:
			var position := Vector2(quadrant.x * (edge + 6.0), quadrant.y * along)
			var heading := -90.0 if quadrant.x > 0 else 90.0
			_place_building(models[index % models.size()], position, heading)
			index += 1
		for along: float in [edge + 17.0, edge + 28.0]:
			var position := Vector2(quadrant.x * along, quadrant.y * (edge + 6.0))
			var heading := 180.0 if quadrant.y > 0 else 0.0
			_place_building(models[index % models.size()], position, heading)
			index += 1
	# Skyline beyond the ends of the streets (scenery only).
	for end: Vector2 in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
		for side: float in [-1.0, 1.0]:
			var across := Vector2(end.y, end.x) * side * 18.0
			var model := "building-skyscraper-a" if side > 0 else "building-skyscraper-b"
			var tower := _place_model(BUILDINGS + model + ".glb", end * (HALF_SIZE + 22.0) + across, 0.0, Vector3.ONE * 12.0, false, false)
			_tint(tower, BUILDING_TINT)


func _place_building(model: String, position: Vector2, heading: float) -> void:
	var building := _place_model(BUILDINGS + model + ".glb", position, heading, Vector3.ONE * 12.0, true)
	_tint(building, BUILDING_TINT)


## Invisible walls at the edge of the playable area.
func _build_bounds() -> void:
	var walls := StaticBody3D.new()
	walls.name = "Bounds"
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0 if side.x != 0 else HALF_SIZE * 2.0, 8.0, 1.0 if side.z != 0 else HALF_SIZE * 2.0)
		shape.shape = box
		shape.position = side * (HALF_SIZE + 0.5) + Vector3(0, 4, 0)
		walls.add_child(shape)
	add_child(walls)


# --- Vehicles and props --------------------------------------------------------

func _place_car(model: String, position: Vector2, heading: float) -> Node3D:
	return _place_model(CARS + model + ".glb", position, heading, CAR_SCALE, true)


func _place_police_car(position: Vector2, heading: float) -> void:
	var car := _place_car("police", position, heading)
	var lights := PoliceLights.new()
	lights.position = Vector3(0, 1.75, 0)
	car.add_child(lights)


## A concrete jersey barrier: waist-high cover.
func _place_barrier(position: Vector2, heading: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Barrier"
	var mesh := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 1.0, 2.6)
	prism.left_to_right = 0.5
	prism.material = _concrete
	mesh.mesh = prism
	mesh.position.y = 0.5
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.7, 0.35, 2.6)
	base_box.material = _concrete
	base.mesh = base_box
	base.position.y = 0.175
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.0, 2.6)
	shape.shape = box
	shape.position.y = 0.5
	body.add_child(mesh)
	body.add_child(base)
	body.add_child(shape)
	body.position = Vector3(position.x, 0, position.y)
	body.rotation_degrees.y = heading
	body.add_to_group(&"cover")
	_navigation.add_child(body)


## Instances a model and, if [param solid], wraps it in a static body with a
## box collider fitted to its meshes.
func _place_model(path: String, position: Vector2, heading: float, scale: Vector3,
		solid: bool, cover := solid) -> Node3D:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.scale = scale
	if not solid:
		model.position = Vector3(position.x, 0, position.y)
		model.rotation_degrees.y = heading
		add_child(model)
		return model
	var body := StaticBody3D.new()
	body.name = path.get_file().get_basename().to_pascal_case()
	body.position = Vector3(position.x, 0, position.y)
	body.rotation_degrees.y = heading
	body.add_child(model)
	var bounds := _mesh_bounds(model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size * scale
	shape.shape = box
	shape.position = bounds.get_center() * scale
	body.add_child(shape)
	if cover:
		body.add_to_group(&"cover")
	_navigation.add_child(body)
	return body


## Multiplies the colors of every material under [param root].
static func _tint(root: Node, tint: Color) -> void:
	for mesh_instance: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			material = material.duplicate() as StandardMaterial3D
			material.albedo_color *= tint
			mesh_instance.set_surface_override_material(surface, material)


## Bounding box of every mesh under [param root], in the root's local space
## (ignoring the root's own transform).
static func _mesh_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh_instance: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var transform := Transform3D.IDENTITY
		var node: Node = mesh_instance
		while node != root:
			transform = (node as Node3D).transform * transform
			node = node.get_parent()
		var box := transform * mesh_instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


# --- Lights --------------------------------------------------------------------

func _build_street_lamps() -> void:
	var edge := ROAD_WIDTH * 0.5 + 1.0
	var spots := [
		[Vector2(edge, -32.0), 90.0], [Vector2(-edge, -18.0), -90.0], [Vector2(edge, 15.0), 90.0],
		[Vector2(-edge, 29.0), -90.0], [Vector2(-31.0, -edge), 0.0], [Vector2(19.0, -edge), 0.0],
		[Vector2(-17.0, edge), 180.0], [Vector2(32.0, edge), 180.0],
	]
	for spot: Array in spots:
		var lamp := _place_model(ROADS + "light-square.glb", spot[0], spot[1], Vector3.ONE * 9.0, false, false)
		# The lamp's arm reaches over the street; hang the light under its head.
		var light := OmniLight3D.new()
		light.light_color = LAMP_COLOR
		light.light_energy = 2.2
		light.omni_range = 13.0
		light.omni_attenuation = 1.4
		light.position = Vector3(0, 0.56, -0.19)
		lamp.add_child(light)


func _bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.filter_baking_aabb = AABB(Vector3(-HALF_SIZE, -1, -HALF_SIZE), Vector3(HALF_SIZE * 2, 6, HALF_SIZE * 2))
	_navigation.navigation_mesh = mesh
	_navigation.bake_navigation_mesh(false)
