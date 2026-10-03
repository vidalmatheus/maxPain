class_name Hourglass
extends Control
## Max Payne 1 style bullet-time meter: a tall hourglass with rounded bulbs
## and a dark frame, filled from the bottom up with the adrenaline left.

const FRAME := Color(0.04, 0.04, 0.05, 0.85)
const EMPTY := Color(0, 0, 0, 0.25)
const SAND := Color(0.82, 0.86, 0.95, 0.9)
const SAND_FLOWING := Color(0.95, 0.85, 0.55, 0.95)

## Right half of the outline in normalized coordinates, top to bottom;
## mirrored for the left half.
const RIGHT_HALF: Array[Vector2] = [
	Vector2(0.5, 0.0), Vector2(0.8, 0.0), Vector2(0.95, 0.035), Vector2(1.0, 0.1),
	Vector2(1.0, 0.3), Vector2(0.92, 0.4), Vector2(0.7, 0.465), Vector2(0.62, 0.5),
	Vector2(0.7, 0.535), Vector2(0.92, 0.6), Vector2(1.0, 0.7), Vector2(1.0, 0.9),
	Vector2(0.95, 0.965), Vector2(0.8, 1.0), Vector2(0.5, 1.0),
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
	draw_polyline(closed, FRAME, 2.5, true)


func _outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in RIGHT_HALF:
		points.append(p * size)
	for i in range(RIGHT_HALF.size() - 2, 0, -1):
		points.append(Vector2(1.0 - RIGHT_HALF[i].x, RIGHT_HALF[i].y) * size)
	return points
