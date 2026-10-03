class_name Hourglass
extends Control
## Max Payne 1 bullet-time meter, traced from the original game's HUD: a tall,
## semi-transparent hourglass with straight-sided bulbs and a curved neck,
## filled from the bottom up with the adrenaline left.

const FRAME := Color(0.08, 0.08, 0.08, 0.6)
const EMPTY := Color(0, 0, 0, 0.18)
const SAND := Color(0.68, 0.75, 0.86, 0.62)
const SAND_FLOWING := Color(0.78, 0.84, 0.94, 0.72)

## Right half of the outline in normalized coordinates, top to bottom;
## mirrored for the left half.
const RIGHT_HALF: Array[Vector2] = [
	Vector2(0.5, 0.0), Vector2(0.86, 0.0), Vector2(1.0, 0.035), Vector2(1.0, 0.42),
	Vector2(0.97, 0.465), Vector2(0.86, 0.5), Vector2(0.76, 0.52), Vector2(0.86, 0.545),
	Vector2(0.97, 0.58), Vector2(1.0, 0.625), Vector2(1.0, 0.965), Vector2(0.86, 1.0),
	Vector2(0.5, 1.0),
]

## Remaining adrenaline, 0..1.
@export_range(0.0, 1.0) var fill := 1.0:
	set(value):
		fill = clampf(value, 0.0, 1.0)
		queue_redraw()

## Whether bullet time is active (the sand glows while it drains).
var flowing := false:
	set(value):
		if value != flowing:
			flowing = value
			queue_redraw()


func _draw() -> void:
	var shape := _outline()
	draw_colored_polygon(shape, EMPTY)
	var level := size.y * (1.0 - fill)
	var clip := PackedVector2Array([Vector2(0, level), Vector2(size.x, level), size, Vector2(0, size.y)])
	for piece in Geometry2D.intersect_polygons(shape, clip):
		draw_colored_polygon(piece, SAND_FLOWING if flowing else SAND)
	var closed := shape.duplicate()
	closed.append(shape[0])
	draw_polyline(closed, FRAME, 1.5, true)


func _outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in RIGHT_HALF:
		points.append(p * size)
	for i in range(RIGHT_HALF.size() - 2, 0, -1):
		points.append(Vector2(1.0 - RIGHT_HALF[i].x, RIGHT_HALF[i].y) * size)
	return points
