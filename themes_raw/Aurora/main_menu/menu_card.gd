extends Button
## One of the main menu's cards. Focused, it's wide: its gradient face with
## the glyph in white, and the navy panel underneath with the coloured bar,
## the name and a line about it. Otherwise it's narrow and navy, with the
## glyph in two colours and the name below.

const P = preload("../assets/palette.gd")

const FOCUS_W := 360.0
const CARD_W := 180.0

var item: MenuItemData
var _accent := Color.WHITE

## index picks the card's colours (Aurora's four, in turn).
func setup(item_arg: MenuItemData, index: int, glyph: Texture2D, glyph_accent: Texture2D, subtitle: String) -> void:
	item = item_arg
	var colors: Dictionary = P.card(index)
	_accent = colors.accent
	var corners: Array[Color] = []
	corners.assign(colors.corners)
	%Face.corners = corners
	%Icon.texture = glyph
	%IconAccent.texture = glyph_accent
	%IconAccent.visible = glyph_accent != null
	%AccentBar.add_theme_stylebox_override("panel", P.box(_accent, 4))
	%Title.text = item.label
	%Subtitle.text = subtitle
	%Subtitle.visible = subtitle != ""
	%NameLabel.text = item.label
	set_focused(false)

func set_focused(focused: bool) -> void:
	custom_minimum_size.x = FOCUS_W if focused else CARD_W
	%Face.visible = focused
	%InfoPanel.visible = focused
	%Plain.visible = not focused
	%NameLabel.visible = not focused
	# Bigger, and centred over the panel, on the focused card.
	var icon := 96.0 if focused else 84.0
	var top := 45.0 if focused else 66.0
	for rect in [%Icon, %IconAccent]:
		rect.offset_left = -icon / 2.0
		rect.offset_right = icon / 2.0
		rect.offset_top = top
		rect.offset_bottom = top + icon
	%IconAccent.self_modulate = Color.WHITE if focused else _accent
