@tool
extends Control
## Aurora's wifi mark: a dot under two arcs, in white.

const P = preload("palette.gd")

func _init() -> void:
	custom_minimum_size = Vector2(20, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var base := Vector2(size.x / 2.0, size.y / 2.0 + 6)
	draw_circle(base, 2.0, P.TEXT, true, -1, true)
	for i in 2:
		draw_arc(base, 6.0 + i * 5.0, deg_to_rad(-135), deg_to_rad(-45), 16, P.TEXT, 2.0, true)
