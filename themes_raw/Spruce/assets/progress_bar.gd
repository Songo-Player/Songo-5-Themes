@tool
extends Control
## A rounded progress track (spruce's raised gray by default), filled with the
## selection color, with a cream knob at the play position.

const P = preload("palette.gd")

@export_range(0.0, 1.0) var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var fill_color := P.ORANGE:
	set(value):
		fill_color = value
		queue_redraw()
@export var track_color := P.PANEL_HI:
	set(value):
		track_color = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var h := 6.0
	var y := (size.y - h) / 2
	_pill(Rect2(0, y, size.x, h), track_color)
	var x := size.x * progress
	if x > 0: _pill(Rect2(0, y, maxf(x, h), h), fill_color)
	draw_circle(Vector2(clampf(x, 5, size.x - 5), size.y / 2), 6.0, P.TEXT_BRIGHT, true, -1, true)

func _pill(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(rect.size.y / 2))
	draw_style_box(style, rect)
