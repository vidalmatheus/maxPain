class_name HealthFigure
extends Control
## Max Payne 1 style health indicator: a pale silhouette of the character
## (arms hanging alongside the body) that turns red from the feet up as
## health drops.

const HEALTHY := Color(0.78, 0.83, 0.78, 0.88)
const HURT := Color(0.78, 0.24, 0.18, 0.92)
const OUTLINE := Color(0, 0, 0, 0.45)

## Right half of the silhouette in normalized coordinates (0..1), from the
## top of the head down to the crotch; mirrored for the left half.
const RIGHT_HALF: Array[Vector2] = [
	Vector2(0.5, 0.0), Vector2(0.58, 0.0), Vector2(0.62, 0.03), Vector2(0.62, 0.115),
	Vector2(0.58, 0.145), Vector2(0.58, 0.17), Vector2(0.88, 0.19), Vector2(0.96, 0.23),
	Vector2(0.97, 0.58), Vector2(0.81, 0.59), Vector2(0.79, 0.61), Vector2(0.78, 1.0),
	Vector2(0.54, 1.0), Vector2(0.52, 0.63), Vector2(0.5, 0.63),
]

## 1.0 = full health, 0.0 = dead.
@export_range(0.0, 1.0) var health := 1.0:
	set(value):
		health = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var outline := _silhouette()
	var hurt_line := size.y * health
	_fill(outline, Rect2(0, 0, size.x, hurt_line), HEALTHY)
	_fill(outline, Rect2(0, hurt_line, size.x, size.y - hurt_line), HURT)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, OUTLINE, 1.5, true)


func _silhouette() -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in RIGHT_HALF:
		points.append(p * size)
	for i in range(RIGHT_HALF.size() - 2, 0, -1):
		points.append(Vector2(1.0 - RIGHT_HALF[i].x, RIGHT_HALF[i].y) * size)
	return points


## Fills the part of [param shape] inside [param rect].
func _fill(shape: PackedVector2Array, rect: Rect2, color: Color) -> void:
	if rect.size.y <= 0.0:
		return
	var clip := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for piece in Geometry2D.intersect_polygons(shape, clip):
		draw_colored_polygon(piece, color)
