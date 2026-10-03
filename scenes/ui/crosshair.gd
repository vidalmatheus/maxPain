extends Control
## Minimal crosshair, Max Payne style: a small white dot with a thin dark
## outline so it stays visible on bright backgrounds. Centered on the
## control's origin (screen center).

@export var color := Color(1.0, 1.0, 1.0, 0.95)
@export var outline_color := Color(0.0, 0.0, 0.0, 0.6)
@export var radius := 3.0
@export var outline_width := 1.5


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + outline_width, outline_color)
	draw_circle(Vector2.ZERO, radius, color)
