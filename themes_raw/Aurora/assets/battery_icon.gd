@tool
extends Control
## Aurora's battery: a sideways rounded outline with a nub on the right and
## a fill for the level, white, red when low and the accent while charging.

const P = preload("palette.gd")

@export_range(0, 100) var level := 100:
	set(value):
		level = clampi(value, 0, 100)
		queue_redraw()
@export var charging := false:
	set(value):
		charging = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(30, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var color := P.TEXT
	if charging: color = P.accent()
	elif level <= 15: color = P.RED
	var body := Rect2(0, (size.y - 14) / 2.0, 26, 14)
	var outline := P.box(Color.TRANSPARENT, 4)
	outline.draw_center = false
	outline.border_color = color
	outline.set_border_width_all(2)
	draw_style_box(outline, body)
	draw_rect(Rect2(body.end.x + 1, body.position.y + 4, 2.5, body.size.y - 8), color)
	var inner := body.grow(-4)
	inner.size.x = maxf(2.0, inner.size.x * level / 100.0)
	draw_style_box(P.box(color, 2), inner)
