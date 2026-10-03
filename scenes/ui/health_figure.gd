class_name HealthFigure
extends Control
## Max Payne style health indicator: a silhouette of the character that turns
## red from the feet up as health drops.

const HEALTHY := Color(0.82, 0.82, 0.8, 0.9)
const HURT := Color(0.75, 0.08, 0.05, 0.95)
const OUTLINE := Color(0, 0, 0, 0.55)

## 1.0 = full health, 0.0 = dead.
@export_range(0.0, 1.0) var health := 1.0:
	set(value):
		health = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var parts := _body_parts()
	# Outline pass, then the body. Each part is colored by how high it sits:
	# damage "fills" the figure with red from the feet up.
	for part: Dictionary in parts:
		_draw_part(part, OUTLINE, 1.5)
	for part: Dictionary in parts:
		var height_ratio: float = 1.0 - (part.center as Vector2).y / size.y
		var color := HURT if height_ratio < 1.0 - health else HEALTHY
		_draw_part(part, color, 0.0)


## The silhouette, in coordinates relative to the control size.
func _body_parts() -> Array[Dictionary]:
	var w := size.x
	var h := size.y
	var parts: Array[Dictionary] = [
		_circle(Vector2(w * 0.5, h * 0.09), h * 0.075),  # head
		_rect(Rect2(w * 0.3, h * 0.18, w * 0.4, h * 0.36)),  # torso
		_rect(Rect2(w * 0.12, h * 0.2, w * 0.16, h * 0.32)),  # right arm
		_rect(Rect2(w * 0.72, h * 0.2, w * 0.16, h * 0.32)),  # left arm
		_rect(Rect2(w * 0.31, h * 0.54, w * 0.17, h * 0.44)),  # right leg
		_rect(Rect2(w * 0.52, h * 0.54, w * 0.17, h * 0.44)),  # left leg
	]
	return parts


func _circle(center: Vector2, radius: float) -> Dictionary:
	return {"type": "circle", "center": center, "radius": radius}


func _rect(rect: Rect2) -> Dictionary:
	return {"type": "rect", "rect": rect, "center": rect.get_center()}


func _draw_part(part: Dictionary, color: Color, grow: float) -> void:
	if part.type == "circle":
		draw_circle(part.center, part.radius + grow, color)
	else:
		draw_rect((part.rect as Rect2).grow(grow), color)
