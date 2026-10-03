class_name HealthFigure
extends Control
## Max Payne 1 health indicator: a smooth, semi-transparent silhouette of Max
## seen from behind, traced from the original game's HUD. Damage fills it
## with red from the feet up.

const BODY := Color(0.74, 0.74, 0.72, 0.62)
const HURT := Color(0.62, 0.16, 0.1, 0.75)
const OUTLINE := Color(0.08, 0.08, 0.06, 0.5)

## Outline in normalized coordinates (0..1), clockwise from the top of the head.
const OUTLINE_POINTS: Array[Vector2] = [
	Vector2(0.378, 0.0), Vector2(0.631, 0.012), Vector2(0.654, 0.07), Vector2(0.645, 0.123),
	Vector2(0.608, 0.149), Vector2(0.7, 0.167), Vector2(0.862, 0.193), Vector2(0.931, 0.237),
	Vector2(0.968, 0.325), Vector2(0.995, 0.553), Vector2(0.954, 0.584), Vector2(0.885, 0.579),
	Vector2(0.848, 0.602), Vector2(0.82, 0.614), Vector2(0.802, 0.956), Vector2(0.848, 0.977),
	Vector2(0.839, 1.0), Vector2(0.627, 1.0), Vector2(0.59, 0.956), Vector2(0.553, 0.64),
	Vector2(0.498, 0.623), Vector2(0.452, 0.64), Vector2(0.433, 0.956), Vector2(0.424, 1.0),
	Vector2(0.24, 1.0), Vector2(0.221, 0.977), Vector2(0.249, 0.956), Vector2(0.23, 0.614),
	Vector2(0.147, 0.602), Vector2(0.065, 0.584), Vector2(0.0, 0.553), Vector2(0.018, 0.325),
	Vector2(0.065, 0.237), Vector2(0.147, 0.198), Vector2(0.309, 0.167), Vector2(0.401, 0.149),
	Vector2(0.378, 0.123), Vector2(0.359, 0.07),
]

## 1.0 = full health, 0.0 = dead.
@export_range(0.0, 1.0) var health := 1.0:
	set(value):
		health = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var outline := PackedVector2Array()
	for p in OUTLINE_POINTS:
		outline.append(p * size)
	var hurt_line := size.y * health
	_fill(outline, Rect2(0, 0, size.x, hurt_line), BODY)
	_fill(outline, Rect2(0, hurt_line, size.x, size.y - hurt_line), HURT)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, OUTLINE, 1.5, true)


## Fills the part of [param shape] inside [param rect].
func _fill(shape: PackedVector2Array, rect: Rect2, color: Color) -> void:
	if rect.size.y <= 0.0:
		return
	var clip := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for piece in Geometry2D.intersect_polygons(shape, clip):
		draw_colored_polygon(piece, color)
