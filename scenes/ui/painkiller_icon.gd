class_name PainkillerIcon
extends Control
## Small painkiller bottle, drawn next to the hourglass like in the original
## game. The count is shown by a label beside it.

const BOTTLE := Color(0.82, 0.84, 0.82, 0.88)
const OUTLINE := Color(0, 0, 0, 0.5)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cap := Rect2(w * 0.22, 0, w * 0.56, h * 0.22)
	var body := Rect2(0, h * 0.26, w, h * 0.74)
	for rect in [cap, body]:
		draw_rect(rect.grow(1.0), OUTLINE)
		draw_rect(rect, BOTTLE)
	# Label band.
	draw_rect(Rect2(0, h * 0.5, w, h * 0.22), Color(0.3, 0.32, 0.3, 0.6))
