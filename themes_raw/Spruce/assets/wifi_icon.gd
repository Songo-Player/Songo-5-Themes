@tool
extends Control
## spruce's wifi mark: a dot and three rising arcs, in yellow.

const P = preload("palette.gd")

@export var color := P.YELLOW:
	set(value):
		color = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(28, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var line := maxf(2.0, size.y / 9.0)
	var base := Vector2(size.x / 2, size.y - line)
	draw_circle(base, line * 0.95, color)
	var step := (size.y - line * 2) / 3.2
	for i in 3:
		var r := step * (i + 1.15)
		# Each arc spans the top quarter-and-a-bit of its circle.
		draw_arc(base, r, deg_to_rad(-90 - 48), deg_to_rad(-90 + 48), 24, color, line, true)
