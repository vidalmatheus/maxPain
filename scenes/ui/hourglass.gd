class_name Hourglass
extends Control
## Max Payne style bullet-time meter: an hourglass whose sand is the
## adrenaline left. The top bulb holds the remaining adrenaline and sand
## trickles down while bullet time is active.

const FRAME := Color(0.85, 0.82, 0.75, 0.85)
const SAND := Color(0.95, 0.78, 0.45, 0.95)
const SAND_SPENT := Color(0.95, 0.78, 0.45, 0.35)
const OUTLINE := Color(0, 0, 0, 0.55)

## Remaining adrenaline, 0..1.
@export_range(0.0, 1.0) var fill := 1.0:
	set(value):
		fill = clampf(value, 0.0, 1.0)
		queue_redraw()

## Whether sand is currently falling (bullet time active).
var flowing := false:
	set(value):
		flowing = value
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var neck := Vector2(w * 0.5, h * 0.5)
	var top := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), neck])
	var bottom := PackedVector2Array([neck, Vector2(w, h), Vector2(0, h)])

	# Remaining sand in the top bulb, settled against the neck.
	if fill > 0.0:
		var level := h * 0.5 * (1.0 - fill)
		var half_width := w * 0.5 * (1.0 - level / (h * 0.5))
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.5 - half_width, level), Vector2(w * 0.5 + half_width, level), neck,
		]), SAND)
	# Spent sand piled at the bottom.
	if fill < 1.0:
		var pile := h * 0.5 * (1.0 - fill)
		var y := h - pile
		var half_width := w * 0.5 * ((y - h * 0.5) / (h * 0.5))
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.5 - half_width, y), Vector2(w * 0.5 + half_width, y), Vector2(w, h), Vector2(0, h),
		]), SAND_SPENT if not flowing else SAND)
	if flowing and fill > 0.0:
		draw_line(neck, Vector2(w * 0.5, h - h * 0.5 * (1.0 - fill)), SAND, 1.5)

	for outline in [top, bottom]:
		var closed := PackedVector2Array(outline)
		closed.append(outline[0])
		draw_polyline(closed, OUTLINE, 3.5, true)
		draw_polyline(closed, FRAME, 1.5, true)
