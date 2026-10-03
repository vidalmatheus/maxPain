extends Control
## Minimal crosshair drawn around the control's origin (screen center).

@export var color := Color(1.0, 1.0, 1.0, 0.9)
@export var outline_color := Color(0.0, 0.0, 0.0, 0.6)
@export var gap := 5.0
@export var length := 8.0
@export var thickness := 2.0


func _draw() -> void:
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for pass_color: Color in [outline_color, color]:
		var width := thickness + (2.0 if pass_color == outline_color else 0.0)
		for direction in directions:
			draw_line(direction * gap, direction * (gap + length), pass_color, width)
	draw_circle(Vector2.ZERO, 1.5, color)
