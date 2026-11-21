@tool
extends RefCounted
## spruce's button hints: yellow glyphs with dark lettering, a round one for
## face buttons (A, B, X, Y) and a rounded pill for SELECT, START and MENU,
## each followed by what the button does.

const P = preload("palette.gd")
const FONT_BOLD = preload("font_bold.tres")
const FONT = preload("font_regular.tres")

## A row of hints: pairs = [[button, action], ...].
static func build(pairs: Array, glyph_size := 20, text_size := 15) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	for pair in pairs:
		row.add_child(hint(pair[0], pair[1], glyph_size, text_size))
	return row

static func hint(button: String, action: String, glyph_size := 20, text_size := 15) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	box.add_child(glyph(button, glyph_size))
	if action != "":
		var label := Label.new()
		label.text = action
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", text_size)
		label.add_theme_color_override("font_color", P.TEXT)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(label)
	return box

static func glyph(button: String, glyph_size := 20) -> PanelContainer:
	var round := button.length() == 1
	var style := StyleBoxFlat.new()
	style.bg_color = P.YELLOW
	style.set_corner_radius_all(glyph_size)
	style.anti_aliasing = true
	style.content_margin_left = 0 if round else glyph_size * 0.45
	style.content_margin_right = style.content_margin_left
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", style)
	pill.custom_minimum_size = Vector2(glyph_size, glyph_size)
	var label := Label.new()
	label.text = button
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_font_size_override("font_size", int(glyph_size * (0.7 if round else 0.55)))
	label.add_theme_color_override("font_color", P.BG)
	pill.add_child(label)
	return pill
