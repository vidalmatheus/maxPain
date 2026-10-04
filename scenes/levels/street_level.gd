class_name StreetLevel
extends Node3D
## A snowy New York intersection at night, built in code: two crossing
## streets of worn asphalt with painted lines and crosswalks, concrete
## sidewalks with granite curbs, brick tenements with lit windows, shops with
## neon signs and awnings, fire escapes and water towers, traffic lights,
## hydrants, steaming manholes and plowed snow along the curbs. Cars, police
## cars, lamps, dumpsters and roadworks come from Kenney's kits (CC0) and the
## textures from ambientCG (CC0), see assets/textures/street/README.md.
##
## Everything solid becomes a static body on the world layer, and the bodies
## you can hide behind join the "cover" group. The level bakes its own
## navigation mesh so enemies can find their way around the obstacles.
##
## Coordinates: the main street runs along Z, the cross street along X, and
## they meet at the origin. Each street is ROAD_WIDTH wide, with sidewalks.
## The four blocks around the intersection are laid out once, for the block
## at +X +Z, and mirrored into the others.

const ROAD_WIDTH := 12.0
const SIDEWALK := 3.0
## The playable area is a square of this half size; past it is only scenery.
const HALF_SIZE := 42.0
## How far the streets and buildings go on, into the fog.
const STREET_LENGTH := 84.0
const CURB_HEIGHT := 0.12
## The curb's collision is a gentle ramp this wide, so Max and the mobsters
## walk up onto the sidewalk instead of getting stuck on the step.
const CURB_RAMP := 0.3

const CARS := "res://assets/environment/cars/"
const ROADS := "res://assets/environment/city_roads/"
const TEXTURES := "res://assets/textures/street/"
## Car models are toy sized: scale them to about 2 x 1.3 x 4.3 m (low enough
## to shoot over from behind).
const CAR_SCALE := Vector3(1.3, 1.0, 1.4)

const LAMP_COLOR := Color(1.0, 0.72, 0.42)
const CONCRETE := Color(0.55, 0.55, 0.53)

## Building lots of the +X +Z block: Rect2(x, z, width along X, depth along Z).
## The ones on the corner face both streets.
const LOTS: Array[Rect2] = [
	Rect2(9, 9, 11, 11), Rect2(9, 20, 11, 11), Rect2(9, 31, 11, 16), Rect2(9, 47, 11, 37),
	Rect2(20, 9, 11, 11), Rect2(31, 9, 16, 11), Rect2(47, 9, 37, 11),
]
## Building heights: the shops' floor plus 3 m floors.
const HEIGHTS := [16.5, 22.5, 19.5, 28.5, 13.5, 25.5, 19.5]
## The brick facades: one texture tile is 6 x 6 windows.
const FACADES := ["facade_a", "facade_b"]
const FACADE_TILE := Vector2(16.5, 18.0)
const WINDOWS_PER_TILE := 6
const SHOP_HEIGHT := 4.5
const FLOOR_HEIGHT := 3.0
const SHOP_SIGNS := ["BAR", "DINER", "HOTEL", "LIQUORS", "PAWN", "OPEN 24H", "DELI", "PIZZA",
		"LAUNDRY", "CLUB", "DRUGS", "CHECKS CASHED"]
const NEON := [Color(1.0, 0.15, 0.25), Color(0.25, 0.6, 1.0), Color(1.0, 0.55, 0.1),
		Color(0.3, 1.0, 0.45), Color(1.0, 0.3, 0.9)]
## Kinds of lit shop windows (shared materials keep the draw calls down).
const SHOP_LIGHTS := 6
const AWNINGS := [Color(0.35, 0.06, 0.06), Color(0.06, 0.2, 0.1), Color(0.08, 0.1, 0.25), Color(0.3, 0.22, 0.08)]
## Lots (index in LOTS) with a fire escape on their street side.
const FIRE_ESCAPE_LOTS := [1, 3, 4]

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
## Fire hydrants and trash baskets on the sidewalks, near the curb.
const HYDRANTS := [Vector2(6.7, -12.5), Vector2(-6.7, 20.0), Vector2(23.0, -6.7), Vector2(-14.0, 6.7),
		Vector2(6.7, 36.0)]
const TRASH_BASKETS := [Vector2(7.0, 9.6), Vector2(-9.6, -7.0), Vector2(-7.0, -24.0), Vector2(28.0, 7.0),
		Vector2(-7.0, 33.0)]
## Manholes in the asphalt; the ones marked true steam.
const MANHOLES := [[Vector2(1.5, -19.0), true], [Vector2(-18.0, -1.5), true], [Vector2(-2.0, 30.0), false],
		[Vector2(30.0, 2.0), false]]
## An orange and white Con Edison steam stack by the roadworks.
const STEAM_STACK := Vector2(-6.2, -4.2)
## Where enemies come from: the four ends of the streets.
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(0, 0, -38), Vector3(0, 0, 38), Vector3(-38, 0, 0), Vector3(38, 0, 0),
	Vector3(-3, 0, -38), Vector3(3, 0, 38), Vector3(-38, 0, 3), Vector3(38, 0, -3),
]
## The four blocks, as signs of x and z.
const BLOCKS: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
## Traffic light cycle in seconds: green, yellow, then red while the other
## street has green and yellow.
const GREEN_TIME := 9.0
const YELLOW_TIME := 3.0

var _navigation: NavigationRegion3D
var _random := RandomNumberGenerator.new()
var _materials := {}
## Traffic light lamps: [street][red, yellow, green] materials.
var _signal_lamps: Array = []
var _signal_time := 0.0


func _ready() -> void:
	# The same street every time.
	_random.seed = 1999

	_navigation = NavigationRegion3D.new()
	_navigation.name = "Navigation"
	add_child(_navigation)

	_build_ground()
	_build_road_markings()
	_build_sidewalks()
	for block_index in BLOCKS.size():
		for lot_index in LOTS.size():
			_build_building(block_index, lot_index)
	_build_skyline()
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
	_build_traffic_lights()
	_build_street_furniture()
	_build_snow_banks()
	_bake_navigation()


func _process(delta: float) -> void:
	_signal_time = fmod(_signal_time + delta, (GREEN_TIME + YELLOW_TIME) * 2.0)
	var half := GREEN_TIME + YELLOW_TIME
	for street in 2:
		var t := fmod(_signal_time + street * half, half * 2.0)
		var lit := 2 if t < GREEN_TIME else 1 if t < half else 0
		for lamp in 3:
			var material: StandardMaterial3D = _signal_lamps[street][lamp]
			material.emission_energy_multiplier = 4.0 if lamp == lit else 0.0


## Spawn points for enemies, in world space.
func get_spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point in SPAWN_POINTS:
		points.append(to_global(point))
	return points


## Height of the ground at a point: the sidewalks are a curb above the road.
static func ground_height(position: Vector2) -> float:
	var edge := ROAD_WIDTH * 0.5
	return CURB_HEIGHT if absf(position.x) > edge and absf(position.y) > edge else 0.0


# --- Ground --------------------------------------------------------------------

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(STREET_LENGTH * 3.0, 1.0, STREET_LENGTH * 3.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	# Dirt and slush under everything else.
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(STREET_LENGTH * 3.0, STREET_LENGTH * 3.0)
	plane.material = _plain(Color(0.08, 0.08, 0.09), 1.0)
	base.mesh = plane
	base.position.y = -0.01
	ground.add_child(base)
	_navigation.add_child(ground)

	# Asphalt in 12 m squares, so each square only gets the lights near it.
	var asphalt := _textured("asphalt", Vector3(2, 2, 1), Color(0.62, 0.62, 0.66))
	# Wet from the melting snow: the lamps glint on it.
	asphalt.roughness = 0.5
	var tile := PlaneMesh.new()
	tile.size = Vector2(ROAD_WIDTH, ROAD_WIDTH)
	tile.material = asphalt
	var count := int(STREET_LENGTH / ROAD_WIDTH)
	for i in range(-count, count + 1):
		for spot: Vector2 in [Vector2(0, i), Vector2(i, 0)] if i != 0 else [Vector2.ZERO]:
			var square := MeshInstance3D.new()
			square.mesh = tile
			square.position = Vector3(spot.x * ROAD_WIDTH, 0.0, spot.y * ROAD_WIDTH)
			add_child(square)


## Double yellow center lines, white lines along the parking lanes, stop
## lines and zebra crosswalks on every side of the intersection.
func _build_road_markings() -> void:
	var batch := Batch.new()
	var white := _plain(Color(0.78, 0.78, 0.74), 0.6)
	var yellow := _plain(Color(0.85, 0.62, 0.12), 0.6)
	var edge := ROAD_WIDTH * 0.5
	var crosswalk_start := edge + 1.0
	var crosswalk_end := crosswalk_start + 3.0
	var line_start := crosswalk_end + 0.8
	var length := STREET_LENGTH - line_start
	for street in 2:
		for side: float in [-1.0, 1.0]:
			var center := side * (line_start + length * 0.5)
			for offset: float in [-0.13, 0.13]:
				_add_road_line(batch, yellow, street, offset, center, 0.11, length)
			for offset: float in [-3.3, 3.3]:
				_add_road_line(batch, white, street, offset, center, 0.12, length)
			# Stop line across the lanes coming into the intersection (traffic
			# drives on the right).
			var lane := side if street == 0 else -side
			_add_road_line(batch, white, street, lane * edge * 0.5, side * (crosswalk_end + 0.5), edge - 0.4, 0.4)
			# Zebra stripes, parallel to the traffic.
			var stripe := -edge + 0.6
			while stripe < edge - 0.3:
				_add_road_line(batch, white, street, stripe, side * (crosswalk_start + 1.5), 0.45, 3.0)
				stripe += 0.9
	batch.build(self, "RoadMarkings")


## A painted strip on the road. [param across] is the offset from the street's
## center line and [param along] the position along the street; [param width]
## and [param length] are across and along it.
func _add_road_line(batch: Batch, material: Material, street: int, across: float, along: float,
		width: float, length: float) -> void:
	var size := Vector3(width, 0.01, length)
	var position := Vector3(across, 0.02, along)
	if street == 1:
		position = Vector3(along, 0.02, across)
		size = Vector3(size.z, size.y, size.x)
	batch.add_box(material, size, Transform3D(Basis.IDENTITY, position))


## Concrete sidewalks a curb above the road, in strips along both streets.
func _build_sidewalks() -> void:
	var paving := _textured("sidewalk", Vector3.ONE / SIDEWALK, Color(0.75, 0.74, 0.72))
	paving.uv1_triplanar = true
	paving.uv1_world_triplanar = true
	paving.roughness = 0.85
	var curb := _plain(Color(0.42, 0.42, 0.43), 0.7)
	var edge := ROAD_WIDTH * 0.5
	var chunk := (STREET_LENGTH - edge) / 3.0
	for block in BLOCKS:
		var batch := Batch.new()
		for i in 3:
			var start := edge + i * chunk
			# Along the main street (including the corner), then along the cross street.
			_add_slab(batch, paving, Rect2(edge, start, SIDEWALK, chunk), block)
			_add_slab(batch, paving, Rect2(edge + SIDEWALK + i * (chunk - SIDEWALK / 3.0), edge,
					chunk - SIDEWALK / 3.0, SIDEWALK), block)
		# Granite curbs along the road.
		var curb_length := STREET_LENGTH - edge
		batch.add_box(curb, Vector3(0.2, CURB_HEIGHT + 0.02, curb_length),
				Transform3D(Basis.IDENTITY, Vector3(block.x * (edge + 0.1), (CURB_HEIGHT + 0.02) * 0.5, block.y * (edge + curb_length * 0.5))))
		batch.add_box(curb, Vector3(curb_length, CURB_HEIGHT + 0.02, 0.2),
				Transform3D(Basis.IDENTITY, Vector3(block.x * (edge + curb_length * 0.5), (CURB_HEIGHT + 0.02) * 0.5, block.y * (edge + 0.1))))
		batch.build(self, "Sidewalk")

		# One convex collider for the whole block, ramped along the curbs.
		var body := StaticBody3D.new()
		body.name = "SidewalkBlock"
		var far := STREET_LENGTH * 1.2
		var top := edge + CURB_RAMP
		var points := PackedVector3Array()
		for corner: Vector2 in [Vector2(edge, edge), Vector2(far, edge), Vector2(far, far), Vector2(edge, far)]:
			points.append(Vector3(block.x * corner.x, 0.0, block.y * corner.y))
		for corner: Vector2 in [Vector2(top, top), Vector2(far, top), Vector2(far, far), Vector2(top, far)]:
			points.append(Vector3(block.x * corner.x, CURB_HEIGHT, block.y * corner.y))
		var shape := CollisionShape3D.new()
		var convex := ConvexPolygonShape3D.new()
		convex.points = points
		shape.shape = convex
		body.add_child(shape)
		_navigation.add_child(body)


## A sidewalk slab over [param area] (in the +X +Z block's coordinates).
func _add_slab(batch: Batch, material: Material, area: Rect2, block: Vector2) -> void:
	var center := area.get_center() * block
	batch.add_box(material, Vector3(area.size.x, CURB_HEIGHT, area.size.y),
			Transform3D(Basis.IDENTITY, Vector3(center.x, CURB_HEIGHT * 0.5, center.y)))


# --- Buildings -----------------------------------------------------------------

func _build_building(block_index: int, lot_index: int) -> void:
	var block := BLOCKS[block_index]
	var lot := LOTS[lot_index]
	var height: float = HEIGHTS[(lot_index + block_index * 3) % HEIGHTS.size()]
	var facade: String = FACADES[(lot_index + block_index) % FACADES.size()]
	var center2 := lot.get_center() * block
	var size := Vector3(lot.size.x, height, lot.size.y)

	var body := StaticBody3D.new()
	body.name = "Building"
	body.position = Vector3(center2.x, 0.0, center2.y)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = height * 0.5
	body.add_child(shape)
	body.add_to_group(&"cover")
	_navigation.add_child(body)

	var walls := MeshInstance3D.new()
	walls.mesh = _facade_mesh(size, SHOP_HEIGHT, _facade_material(facade))
	body.add_child(walls)

	var batch := Batch.new()
	var stone := _plain(Color(0.2, 0.19, 0.18), 0.8)
	var snow := _snow_material()
	# Neighbors' ledges stick out by different amounts, so where they meet
	# their faces are never in the same plane (which would flicker).
	var ledge := 0.04 * lot_index
	var grow := Vector3(2.0 * ledge, 0.0, 2.0 * ledge)
	# Cornice with snow on it, closing the roof.
	batch.add_box(stone, Vector3(size.x + 0.5, 0.6, size.z + 0.5) + grow, Transform3D(Basis.IDENTITY, Vector3(0, height + 0.3, 0)))
	batch.add_box(snow, Vector3(size.x + 0.4, 0.06, size.z + 0.4) + grow, Transform3D(Basis.IDENTITY, Vector3(0, height + 0.63, 0)))
	# Ground floor: dark granite, with shops on the street sides.
	batch.add_box(_plain(Color(0.09, 0.085, 0.08), 0.6), Vector3(size.x + 0.24, SHOP_HEIGHT, size.z + 0.24) + grow,
			Transform3D(Basis.IDENTITY, Vector3(0, SHOP_HEIGHT * 0.5 - ledge * 0.1, 0)))
	batch.add_box(stone, Vector3(size.x + 0.4, 0.3, size.z + 0.4) + grow, Transform3D(Basis.IDENTITY, Vector3(0, SHOP_HEIGHT + ledge * 0.1, 0)))
	# The street sides, as (outward normal, length along it).
	var street_sides: Array = []
	if is_equal_approx(lot.position.x, ROAD_WIDTH * 0.5 + SIDEWALK):
		street_sides.append([Vector3(-block.x, 0, 0), size.z])
	if is_equal_approx(lot.position.y, ROAD_WIDTH * 0.5 + SIDEWALK):
		street_sides.append([Vector3(0, 0, -block.y), size.x])
	for side: Array in street_sides:
		var normal: Vector3 = side[0]
		var depth := absf(normal.dot(size)) * 0.5
		_add_shops(batch, body, normal, depth + ledge, side[1])
		if lot_index in FIRE_ESCAPE_LOTS and side == street_sides[0]:
			_add_fire_escape(batch, normal, depth, height)
	if _random.randf() < 0.45:
		_add_water_tower(batch, Vector3(_random.randf_range(-0.25, 0.25) * size.x, height + 0.6,
				_random.randf_range(-0.25, 0.25) * size.z))
	var decor := batch.build(body, "Details")
	decor.position = Vector3.ZERO


## A row of shops along a street side of a building: lit or shuttered
## windows, sign boards, some neon signs and awnings.
func _add_shops(batch: Batch, building: Node3D, normal: Vector3, depth: float, length: float) -> void:
	var right := Vector3.UP.cross(normal)
	var count := maxi(1, roundi(length / 5.5))
	var width := length / count
	var frame := _plain(Color(0.05, 0.05, 0.05), 0.5)
	var shutter := _plain(Color(0.3, 0.3, 0.32), 0.5)
	var board := _plain(Color(0.07, 0.07, 0.08), 0.7)
	for i in count:
		var along := -length * 0.5 + width * (i + 0.5)
		var front := normal * (depth + 0.13) + right * along
		var basis := Basis(right, Vector3.UP, normal)
		var glass_size := Vector3(width - 1.4, 2.5, 0.04)
		batch.add_box(frame, glass_size + Vector3(0.2, 0.2, 0.02), Transform3D(basis, front + Vector3(0, 1.95, 0)))
		# In front of the frame (whose face is 3 cm out), not in its plane.
		var glass := Transform3D(basis * Basis.from_scale(Vector3(glass_size.x, glass_size.y, 1.0)), front + normal * 0.05 + Vector3(0, 1.95, 0))
		if _random.randf() < 0.7:
			# Lit inside: bright under the ceiling lights, darker below.
			batch.add_mesh(_shop_window(_random.randi() % SHOP_LIGHTS), _unit_quad(), glass)
		else:
			batch.add_mesh(shutter, _unit_quad(), glass)
		# Sign board over the window, and a neon sign on some of them.
		batch.add_box(board, Vector3(width - 0.8, 0.7, 0.08), Transform3D(basis, front + Vector3(0, 3.75, 0)))
		if _random.randf() < 0.55:
			var sign := Label3D.new()
			sign.text = SHOP_SIGNS[_random.randi() % SHOP_SIGNS.size()]
			sign.font_size = 72
			sign.outline_size = 0
			sign.pixel_size = 0.0075
			sign.shaded = false
			sign.double_sided = false
			sign.modulate = NEON[_random.randi() % NEON.size()] * 2.2
			sign.position = front + normal * 0.06 + Vector3(0, 3.75, 0)
			sign.basis = basis
			building.add_child(sign)
		elif _random.randf() < 0.6:
			# A canvas awning, sloping down over the window.
			var awning := _plain(AWNINGS[_random.randi() % AWNINGS.size()], 0.9)
			var slope := Basis(right, deg_to_rad(-25.0))
			batch.add_box(awning, Vector3(width - 0.9, 0.05, 1.3), Transform3D(slope * basis, front + normal * 0.6 + Vector3(0, 3.2, 0)))


## A black iron fire escape zigzagging up the facade from the second floor.
func _add_fire_escape(batch: Batch, normal: Vector3, depth: float, height: float) -> void:
	var iron := _plain(Color(0.06, 0.06, 0.06), 0.5)
	var right := Vector3.UP.cross(normal)
	var basis := Basis(right, Vector3.UP, normal)
	var width := 4.2
	var out := 1.1
	var level := SHOP_HEIGHT + FLOOR_HEIGHT
	var flip := 1.0
	while level < height - 1.0:
		var base := normal * (depth + out * 0.5)
		# Landing, with a railing on the three open sides.
		batch.add_box(iron, Vector3(width, 0.05, out), Transform3D(basis, base + Vector3(0, level, 0)))
		batch.add_box(iron, Vector3(width, 0.04, 0.04), Transform3D(basis, base + normal * out * 0.5 + Vector3(0, level + 1.0, 0)))
		batch.add_box(iron, Vector3(width, 0.03, 0.03), Transform3D(basis, base + normal * out * 0.5 + Vector3(0, level + 0.5, 0)))
		for end: float in [-1.0, 1.0]:
			batch.add_box(iron, Vector3(0.04, 0.04, out), Transform3D(basis, base + right * end * width * 0.5 + Vector3(0, level + 1.0, 0)))
			for post: float in [0.0, 0.5]:
				var at := base + right * end * width * (0.5 - post) + normal * out * 0.5
				batch.add_box(iron, Vector3(0.04, 1.0, 0.04), Transform3D(basis, at + Vector3(0, level + 0.5, 0)))
		# Stairs up to the next landing.
		if level + FLOOR_HEIGHT < height - 1.0:
			var run := width - 1.2
			var stairs := Basis(normal, flip * atan2(FLOOR_HEIGHT, run)) * basis
			batch.add_box(iron, Vector3(sqrt(run * run + FLOOR_HEIGHT * FLOOR_HEIGHT), 0.06, 0.6),
					Transform3D(stairs, normal * (depth + 0.35) + Vector3(0, level + FLOOR_HEIGHT * 0.5, 0)))
		flip = -flip
		level += FLOOR_HEIGHT
	# The drop ladder below the first landing.
	var ladder := normal * (depth + out * 0.8) + right * width * 0.35
	for rail: float in [-0.2, 0.2]:
		batch.add_box(iron, Vector3(0.04, 2.6, 0.04), Transform3D(basis, ladder + right * rail + Vector3(0, SHOP_HEIGHT + FLOOR_HEIGHT - 1.3, 0)))
	for rung in 8:
		batch.add_box(iron, Vector3(0.4, 0.03, 0.03), Transform3D(basis, ladder + Vector3(0, SHOP_HEIGHT + 0.6 + rung * 0.3, 0)))


## A wooden water tank on steel legs, on a roof.
func _add_water_tower(batch: Batch, position: Vector3) -> void:
	var wood := _plain(Color(0.22, 0.15, 0.1), 0.95)
	var steel := _plain(Color(0.08, 0.08, 0.08), 0.6)
	var tank := CylinderMesh.new()
	tank.top_radius = 1.6
	tank.bottom_radius = 1.6
	tank.height = 3.2
	tank.radial_segments = 12
	tank.rings = 1
	batch.add_mesh(wood, tank, Transform3D(Basis.IDENTITY, position + Vector3(0, 4.1, 0)))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.05
	roof.bottom_radius = 1.75
	roof.height = 1.0
	roof.radial_segments = 12
	roof.rings = 1
	batch.add_mesh(_snow_material(), roof, Transform3D(Basis.IDENTITY, position + Vector3(0, 6.2, 0)))
	for corner: Vector3 in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		batch.add_box(steel, Vector3(0.15, 2.5, 0.15), Transform3D(Basis.IDENTITY, position + corner * 1.05 + Vector3(0, 1.25, 0)))
	batch.add_box(steel, Vector3(3.2, 0.15, 3.2), Transform3D(Basis.IDENTITY, position + Vector3(0, 2.5, 0)))


## The four walls of a building from [param base] up, with the facade
## texture mapped to whole windows on each wall (no roof: the cornice
## covers it).
static func _facade_mesh(size: Vector3, base: float, material: Material) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var bay := FACADE_TILE.x / WINDOWS_PER_TILE
	for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var right := Vector3.UP.cross(normal)
		var width := absf(right.dot(size))
		var center := normal * absf(normal.dot(half))
		# Whole bays across the wall, starting and ending at a pier.
		var u_scale := maxf(roundf(width / bay), 1.0) / WINDOWS_PER_TILE / width
		var u0 := 0.5 / WINDOWS_PER_TILE
		# A spandrel (between two rows of windows) right above the shops.
		var v := func(y: float) -> float: return 0.5 / WINDOWS_PER_TILE - (y - base) / FACADE_TILE.y
		var corners := [
			[center - right * width * 0.5 + Vector3.UP * base, Vector2(u0, v.call(base))],
			[center - right * width * 0.5 + Vector3.UP * size.y, Vector2(u0, v.call(size.y))],
			[center + right * width * 0.5 + Vector3.UP * size.y, Vector2(u0 + width * u_scale, v.call(size.y))],
			[center + right * width * 0.5 + Vector3.UP * base, Vector2(u0 + width * u_scale, v.call(base))],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(normal)
			tool.set_uv(corners[index][1])
			tool.add_vertex(corners[index][0])
	tool.generate_tangents()
	tool.set_material(material)
	return tool.commit()


## Office towers at the far ends of the streets, dark glass with a few
## offices still lit (scenery only).
func _build_skyline() -> void:
	var material := _textured("tower", Vector3.ONE, Color.WHITE)
	material.emission_enabled = true
	material.emission_texture = load(TEXTURES + "tower_emission.jpg")
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 1.4
	for end: Vector2 in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
		for side: float in [-1.0, 1.0]:
			var across := Vector2(end.y, end.x) * side * _random.randf_range(20.0, 26.0)
			var spot := end * (STREET_LENGTH + _random.randf_range(8.0, 20.0)) + across
			var size := Vector3(_random.randf_range(16.0, 22.0), _random.randf_range(45.0, 75.0), 18.0)
			var tower := MeshInstance3D.new()
			var tower_material := material.duplicate() as StandardMaterial3D
			tower_material.uv1_scale = Vector3(1.0 / 20.0, 1.0 / 24.0, 1.0)
			tower_material.uv1_triplanar = true
			tower_material.uv1_world_triplanar = true
			var box := BoxMesh.new()
			box.size = size
			box.material = tower_material
			tower.mesh = box
			tower.position = Vector3(spot.x, size.y * 0.5, spot.y)
			add_child(tower)


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
	var car := _place_model(CARS + model + ".glb", position, heading, CAR_SCALE, true)
	# Snow on the roof.
	var bounds := _mesh_bounds(car.get_child(0) as Node3D)
	var top := Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z) * CAR_SCALE
	var snow := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(bounds.size.x * CAR_SCALE.x * 0.62, 0.07, bounds.size.z * CAR_SCALE.z * 0.26)
	box.material = _snow_material()
	snow.mesh = box
	snow.position = top
	car.add_child(snow)
	return car


func _place_police_car(position: Vector2, heading: float) -> void:
	var car := _place_car("police", position, heading)
	var lights := PoliceLights.new()
	lights.position = Vector3(0, 1.75, 0)
	car.add_child(lights)


## A concrete jersey barrier: waist-high cover.
func _place_barrier(position: Vector2, heading: float) -> void:
	var concrete := _plain(CONCRETE, 0.95)
	var body := StaticBody3D.new()
	body.name = "Barrier"
	var mesh := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 1.0, 2.6)
	prism.left_to_right = 0.5
	prism.material = concrete
	mesh.mesh = prism
	mesh.position.y = 0.5
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.7, 0.35, 2.6)
	base_box.material = concrete
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
	body.position = Vector3(position.x, ground_height(position), position.y)
	body.rotation_degrees.y = heading
	body.add_to_group(&"cover")
	_navigation.add_child(body)


## Instances a model and, if [param solid], wraps it in a static body with a
## box collider fitted to its meshes. Models stand on the road or sidewalk.
func _place_model(path: String, position: Vector2, heading: float, scale: Vector3,
		solid: bool, cover := solid) -> Node3D:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.scale = scale
	var origin := Vector3(position.x, ground_height(position), position.y)
	if not solid:
		model.position = origin
		model.rotation_degrees.y = heading
		add_child(model)
		return model
	var body := StaticBody3D.new()
	body.name = path.get_file().get_basename().to_pascal_case()
	body.position = origin
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


## Fire hydrants, trash baskets, manholes (some steaming) and a steam stack.
func _build_street_furniture() -> void:
	var batch := Batch.new()
	var hydrant := _plain(Color(0.55, 0.08, 0.05), 0.5)
	var chrome := _plain(Color(0.6, 0.6, 0.58), 0.3)
	for spot: Vector2 in HYDRANTS:
		var base := Vector3(spot.x, CURB_HEIGHT, spot.y)
		batch.add_mesh(hydrant, _cylinder(0.13, 0.13, 0.55), Transform3D(Basis.IDENTITY, base + Vector3(0, 0.3, 0)))
		batch.add_mesh(hydrant, _cylinder(0.04, 0.16, 0.15), Transform3D(Basis.IDENTITY, base + Vector3(0, 0.65, 0)))
		batch.add_mesh(hydrant, _cylinder(0.18, 0.18, 0.06), Transform3D(Basis.IDENTITY, base + Vector3(0, 0.05, 0)))
		batch.add_mesh(chrome, _cylinder(0.06, 0.06, 0.4), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), base + Vector3(0, 0.42, 0)))
	var basket := _plain(Color(0.08, 0.2, 0.1), 0.6)
	for spot: Vector2 in TRASH_BASKETS:
		batch.add_mesh(basket, _cylinder(0.3, 0.24, 0.85), Transform3D(Basis.IDENTITY, Vector3(spot.x, CURB_HEIGHT + 0.425, spot.y)))
		batch.add_mesh(_snow_material(), _cylinder(0.27, 0.27, 0.05), Transform3D(Basis.IDENTITY, Vector3(spot.x, CURB_HEIGHT + 0.86, spot.y)))
	var iron := _plain(Color(0.07, 0.07, 0.07), 0.4)
	for manhole: Array in MANHOLES:
		var spot: Vector2 = manhole[0]
		batch.add_mesh(iron, _cylinder(0.4, 0.4, 0.02), Transform3D(Basis.IDENTITY, Vector3(spot.x, 0.01, spot.y)))
		if manhole[1]:
			_add_steam(Vector3(spot.x, 0.05, spot.y), 0.6)
	# Con Ed stack: orange with white stripes, puffing steam.
	var stack := Vector3(STEAM_STACK.x, 0.0, STEAM_STACK.y)
	var orange := _plain(Color(0.9, 0.35, 0.05), 0.6)
	var stripe := _plain(Color(0.85, 0.85, 0.82), 0.6)
	for ring in 6:
		batch.add_mesh(orange if ring % 2 == 0 else stripe, _cylinder(0.28, 0.32, 0.4), Transform3D(Basis.IDENTITY, stack + Vector3(0, 0.2 + ring * 0.4, 0)))
	_add_steam(stack + Vector3(0, 2.4, 0), 1.0)
	batch.build(self, "StreetFurniture")


## A plume of steam rising and drifting with the wind.
func _add_steam(position: Vector3, strength: float) -> void:
	var steam := CPUParticles3D.new()
	steam.name = "Steam"
	steam.amount = 26
	steam.lifetime = 3.5
	steam.preprocess = 3.5
	steam.local_coords = false
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.25 * strength
	steam.direction = Vector3(0.15, 1.0, 0.05)
	steam.spread = 12.0
	steam.gravity = Vector3(0.25, 0.35, 0.1)
	steam.initial_velocity_min = 0.6 * strength
	steam.initial_velocity_max = 1.1 * strength
	steam.scale_amount_min = 1.0
	steam.scale_amount_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 2.2))
	steam.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 0.22))
	steam.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2(1.0, 1.0) * strength
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.75, 0.78, 0.85)
	material.albedo_texture = _puff_texture()
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	puff.material = material
	steam.mesh = puff
	steam.position = position
	add_child(steam)


## A soft round blob for steam puffs.
func _puff_texture() -> Texture2D:
	if not _materials.has("puff"):
		var texture := GradientTexture2D.new()
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 64
		texture.height = 64
		texture.gradient = Gradient.new()
		texture.gradient.set_color(0, Color(1, 1, 1, 1))
		texture.gradient.set_color(1, Color(1, 1, 1, 0))
		_materials["puff"] = texture
	return _materials["puff"]


## Plowed snow piled along the curbs, broken up where it was shoveled.
func _build_snow_banks() -> void:
	var snow := _snow_material()
	var edge := ROAD_WIDTH * 0.5
	for street in 2:
		for side: float in [-1.0, 1.0]:
			var batch := Batch.new()
			var along := edge + 4.0
			while along < STREET_LENGTH:
				var length := _random.randf_range(2.0, 4.5)
				for direction: float in [-1.0, 1.0]:
					if _random.randf() < 0.3:
						continue
					# A few lumps of different sizes along the bank.
					var lump := 0.0
					while lump < length:
						var size := _random.randf_range(0.7, 1.4)
						var center := Vector3(side * (edge + _random.randf_range(0.0, 0.3)), 0.0, direction * (along + lump + size * 0.5))
						var scale := Vector3(_random.randf_range(0.35, 0.6), _random.randf_range(0.15, 0.3), size * 0.7)
						if street == 1:
							center = Vector3(center.z, 0.0, center.x)
							scale = Vector3(scale.z, scale.y, scale.x)
						batch.add_mesh(snow, _blob(), Transform3D(Basis.from_scale(scale).rotated(Vector3.UP, _random.randf_range(-0.3, 0.3)), center))
						lump += size * 0.6
				along += length + _random.randf_range(1.0, 5.0)
			batch.build(self, "SnowBank")
	# Bigger heaps on the corners, where the plows turn.
	var corners := Batch.new()
	for block in BLOCKS:
		var center := Vector3(block.x * (edge + 1.6), CURB_HEIGHT, block.y * (edge + 1.6))
		for lump in 3:
			var offset := Vector3(_random.randf_range(-0.5, 0.5), 0.0, _random.randf_range(-0.5, 0.5))
			var scale := Vector3(_random.randf_range(0.5, 0.8), _random.randf_range(0.25, 0.45), _random.randf_range(0.5, 0.8))
			corners.add_mesh(snow, _blob(), Transform3D(Basis.from_scale(scale), center + offset))
	corners.build(self, "SnowHeaps")


func _blob() -> SphereMesh:
	if not _materials.has("blob"):
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		sphere.is_hemisphere = true
		_materials["blob"] = sphere
	return _materials["blob"]


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 10
	cylinder.rings = 1
	return cylinder


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


## A traffic light on every corner, with a signal head for each street.
## The two streets take turns (see _process).
func _build_traffic_lights() -> void:
	var colors := [Color(1.0, 0.1, 0.05), Color(1.0, 0.6, 0.05), Color(0.1, 1.0, 0.45)]
	for street in 2:
		var lamps: Array[StandardMaterial3D] = []
		for color: Color in colors:
			var lamp := StandardMaterial3D.new()
			lamp.albedo_color = color * 0.25
			lamp.emission_enabled = true
			lamp.emission = color
			lamps.append(lamp)
		_signal_lamps.append(lamps)
	var batch := Batch.new()
	var paint := _plain(Color(0.12, 0.13, 0.1), 0.6)
	var corner := ROAD_WIDTH * 0.5 + 0.7
	for block in BLOCKS:
		var base := Vector3(block.x * corner, CURB_HEIGHT, block.y * corner)
		var body := StaticBody3D.new()
		body.name = "TrafficLight"
		body.position = base
		var shape := CollisionShape3D.new()
		var pole := CylinderShape3D.new()
		pole.radius = 0.1
		pole.height = 3.6
		shape.shape = pole
		shape.position.y = 1.8
		body.add_child(shape)
		_navigation.add_child(body)
		batch.add_mesh(paint, _cylinder(0.08, 0.1, 3.6), Transform3D(Basis.IDENTITY, base + Vector3(0, 1.8, 0)))
		# One head facing along each street, both ways, hung towards the road.
		for street in 2:
			var axis := Vector3(0, 0, 1) if street == 0 else Vector3(1, 0, 0)
			var toward_road := Vector3(-block.x, 0, 0) if street == 0 else Vector3(0, 0, -block.y)
			var head := base + Vector3(0, 3.0, 0) + toward_road * 0.3
			batch.add_box(paint, Vector3(0.32, 0.95, 0.32), Transform3D(Basis.IDENTITY, head))
			# Lamp discs, turned from upright to face along the street.
			var disc := Basis(Vector3.UP.cross(axis).normalized(), PI * 0.5)
			for lamp in 3:
				for facing: float in [-1.0, 1.0]:
					var at := head + Vector3(0, 0.3 - lamp * 0.3, 0) + axis * facing * 0.17
					batch.add_mesh(_signal_lamps[street][lamp], _cylinder(0.1, 0.1, 0.03), Transform3D(disc, at))
	batch.build(self, "TrafficLights")


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


# --- Materials -----------------------------------------------------------------

func _plain(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s %s" % [color, roughness]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_materials[key] = material
	return _materials[key]


## Lit shop window number [param kind]: warm or cold light, brightest at
## the top.
func _shop_window(kind: int) -> StandardMaterial3D:
	var key := "shop %d" % kind
	if _materials.has(key):
		return _materials[key]
	if not _materials.has("shop_light"):
		var texture := GradientTexture2D.new()
		texture.fill_from = Vector2(0, 0)
		texture.fill_to = Vector2(0, 1)
		texture.width = 4
		texture.height = 64
		texture.gradient = Gradient.new()
		texture.gradient.set_color(0, Color(1, 1, 1))
		texture.gradient.set_color(1, Color(0.18, 0.16, 0.15))
		texture.gradient.add_point(0.35, Color(0.7, 0.68, 0.65))
		_materials["shop_light"] = texture
	var color := Color(1.0, 0.78, 0.5).lerp(Color(0.85, 0.95, 1.0), float(kind % 3) / 4.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color * 0.3
	material.emission_enabled = true
	material.emission = color
	material.emission_texture = _materials["shop_light"]
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission_energy_multiplier = 0.7 + 0.12 * kind
	_materials[key] = material
	return material


## A 1 x 1 m quad facing +Z, with UVs over the whole quad.
func _unit_quad() -> QuadMesh:
	if not _materials.has("quad"):
		_materials["quad"] = QuadMesh.new()
	return _materials["quad"]


## A material with [param name]'s color and normal maps.
func _textured(name: String, uv_scale: Vector3, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(TEXTURES + name + "_color.jpg")
	material.albedo_color = tint
	material.uv1_scale = uv_scale
	if ResourceLoader.exists(TEXTURES + name + "_normal.jpg"):
		material.normal_enabled = true
		material.normal_texture = load(TEXTURES + name + "_normal.jpg")
	material.roughness = 0.9
	return material


func _facade_material(facade: String) -> StandardMaterial3D:
	if not _materials.has(facade):
		var material := _textured(facade, Vector3.ONE, Color(0.62, 0.58, 0.56))
		material.emission_enabled = true
		material.emission_texture = load(TEXTURES + facade + "_emission.jpg")
		# The texture is the light (ADD would add it to the white color).
		material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 1.2
		_materials[facade] = material
	return _materials[facade]


func _snow_material() -> StandardMaterial3D:
	if not _materials.has("snow"):
		var material := _textured("snow", Vector3.ONE * 0.5, Color(0.72, 0.73, 0.76))
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.roughness = 1.0
		_materials["snow"] = material
	return _materials["snow"]


## Collects boxes and meshes per material and builds them into one mesh, one
## surface per material, so the many small parts of the street draw in a few
## calls.
class Batch:
	var _tools := {}

	func add_box(material: Material, size: Vector3, transform: Transform3D) -> void:
		var box := BoxMesh.new()
		box.size = size
		add_mesh(material, box, transform)

	func add_mesh(material: Material, mesh: Mesh, transform: Transform3D) -> void:
		var tool: SurfaceTool = _tools.get(material)
		if tool == null:
			tool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[material] = tool
		tool.append_from(mesh, 0, transform)

	func build(parent: Node3D, node_name: String) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		for material: Material in _tools:
			var tool: SurfaceTool = _tools[material]
			tool.set_material(material)
			tool.commit(mesh)
		var instance := MeshInstance3D.new()
		instance.name = node_name
		instance.mesh = mesh
		parent.add_child(instance)
		return instance
