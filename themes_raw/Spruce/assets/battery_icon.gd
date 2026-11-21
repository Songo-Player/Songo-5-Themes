@tool
extends Control
## spruce's battery: an upright outline with a nub on top and up to four
## level bars stacked inside. Green when there's plenty, then yellow, orange
## and red as it runs down; a bolt replaces the bars while charging.

const P = preload("palette.gd")

@export_range(0, 100) var level := 100:
	set(value):
		level = clampi(value, 0, 100)
		queue_redraw()
@export var charging := false:
	set(value):
		charging = value
		queue_redraw()
## No reading (a device without a battery): an empty gray outline.
@export var unknown := false:
	set(value):
		unknown = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(14, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func color() -> Color:
	if unknown: return P.GRAY
	if charging or level > 50: return P.GREEN
	if level > 20: return P.YELLOW
	if level > 5: return P.ORANGE
	return P.RED

func _draw() -> void:
	var c := color()
	var line := maxf(1.5, size.x / 8.0)
	var nub := Vector2(size.x * 0.44, size.y * 0.1)
	var body := Rect2(line / 2, nub.y + line / 2, size.x - line, size.y - nub.y - line)
	draw_rect(Rect2((size.x - nub.x) / 2, 0, nub.x, nub.y + 1), c)
	draw_rect(body, c, false, line)
	if unknown: return

	var inner := body.grow(-line * 1.25)
	if charging:
		# A bolt down the middle, like spruce's charging icon.
		var w := inner.size.x
		var h := inner.size.y
		var o := inner.position
		draw_colored_polygon(PackedVector2Array([
			o + Vector2(w * 0.62, 0), o + Vector2(w * 0.12, h * 0.56), o + Vector2(w * 0.48, h * 0.56),
			o + Vector2(w * 0.38, h), o + Vector2(w * 0.88, h * 0.42), o + Vector2(w * 0.52, h * 0.42),
		]), c)
		return
	var bars := clampi(ceili(level / 25.0), 0, 4)
	var gap := maxf(1.0, inner.size.y * 0.08)
	var bar_h := (inner.size.y - gap * 3) / 4.0
	for i in bars:
		var y := inner.end.y - (i + 1) * bar_h - i * gap
		draw_rect(Rect2(inner.position.x, y, inner.size.x, bar_h), c)
