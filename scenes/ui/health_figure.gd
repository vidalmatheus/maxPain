class_name HealthFigure
extends Control
## Max Payne style health indicator: Max in his coat, seen from behind (as
## the camera sees him), drawn as a grey silhouette with a pale blue rim and
## the coat's seams. Damage fills it with dark red from the feet up.

const BODY := Color(0.53, 0.53, 0.49, 0.85)
const HURT := Color(0.56, 0.15, 0.09, 0.92)
const RIM := Color(0.7, 0.76, 0.86, 0.9)
const SHADOW := Color(0, 0, 0, 0.55)
const SEAMS := Color(0.08, 0.08, 0.08, 0.7)

## Right half of the outline in normalized coordinates (0..1), traced from
## the top of the head, down the arm and coat, to the right foot and back up
## the inner leg to the crotch. Mirrored for the left half.
const RIGHT_HALF: Array[Vector2] = [
	Vector2(0.5, 0.0), Vector2(0.62, 0.01), Vector2(0.66, 0.05), Vector2(0.65, 0.108),
	Vector2(0.61, 0.125), Vector2(0.64, 0.14), Vector2(0.84, 0.18), Vector2(0.92, 0.215),
	Vector2(0.97, 0.33), Vector2(0.99, 0.52), Vector2(0.95, 0.56), Vector2(0.86, 0.565),
	Vector2(0.82, 0.6), Vector2(0.77, 0.61), Vector2(0.75, 0.92), Vector2(0.84, 0.945),
	Vector2(0.82, 0.995), Vector2(0.58, 0.995), Vector2(0.55, 0.92), Vector2(0.52, 0.63),
	Vector2(0.5, 0.63),
]

## Seams and folds of the coat, as line segments (pairs of points).
const SEAM_LINES: Array[Vector2] = [
	# Collar.
	Vector2(0.37, 0.14), Vector2(0.63, 0.14),
	# Shoulder seams into the back panel.
	Vector2(0.17, 0.22), Vector2(0.31, 0.25), Vector2(0.83, 0.22), Vector2(0.69, 0.25),
	Vector2(0.31, 0.25), Vector2(0.69, 0.25),
	# Back panel.
	Vector2(0.31, 0.25), Vector2(0.3, 0.5), Vector2(0.69, 0.25), Vector2(0.7, 0.5),
	# Arms against the body.
	Vector2(0.16, 0.24), Vector2(0.14, 0.55), Vector2(0.84, 0.24), Vector2(0.86, 0.55),
	# Elbows.
	Vector2(0.03, 0.37), Vector2(0.14, 0.37), Vector2(0.86, 0.37), Vector2(0.97, 0.37),
	# Half belt at the back of the coat.
	Vector2(0.32, 0.5), Vector2(0.68, 0.5), Vector2(0.32, 0.53), Vector2(0.68, 0.53),
	Vector2(0.32, 0.5), Vector2(0.32, 0.53), Vector2(0.68, 0.5), Vector2(0.68, 0.53),
	# Coat hem.
	Vector2(0.2, 0.585), Vector2(0.8, 0.585),
	# Shoes.
	Vector2(0.23, 0.93), Vector2(0.43, 0.93), Vector2(0.57, 0.93), Vector2(0.77, 0.93),
]

## 1.0 = full health, 0.0 = dead.
@export_range(0.0, 1.0) var health := 1.0:
	set(value):
		health = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var outline := _silhouette()
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, SHADOW, 4.0, true)

	var hurt_line := size.y * health
	_fill(outline, Rect2(0, 0, size.x, hurt_line), BODY)
	_fill(outline, Rect2(0, hurt_line, size.x, size.y - hurt_line), HURT)

	for i in range(0, SEAM_LINES.size(), 2):
		draw_line(SEAM_LINES[i] * size, SEAM_LINES[i + 1] * size, SEAMS, 1.0, true)
	draw_polyline(closed, RIM, 1.5, true)


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
