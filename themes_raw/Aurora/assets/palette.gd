@tool
extends RefCounted
## Aurora's colours and the theme's setting lookups, in one place. Every
## component preloads this.
##
## The colours are the muOS Aurora theme's (by Rosabel): a near-black navy
## page, raised navy panels and pills, an indigo accent, and the four bright
## accents its main menu cards use (teal, pink, orange and blue).

const BG := Color("090b12")          # the page
const PANEL := Color("0f1528")       # cards, pills, panels
const PANEL_HI := Color("1a2238")    # raised on a panel; idle dots and tracks
const INDIGO := Color("5468e3")      # the accent: focus, the active dot
const INDIGO_DARK := Color("222957") # the logo's shading
const TEXT := Color("ffffff")        # titles and list text
const TEXT_DIM := Color("adafb6")    # subtitles, secondary text
const TEXT_FAINT := Color("5e626f")  # hints' quiet parts, empty states
const RED := Color("f94144")         # low battery, the focused power button
const RED_SOFT := Color("ff7878")    # the power glyph
const RED_DARK := Color("271010")    # the power button
const TEAL := Color("00bcb9")
const PINK := Color("ef476f")
const ORANGE := Color("ff7f1e")
const BLUE := Color("1884ff")

const DEFAULT_ACCENT := "5468e3"

## The main menu's cards, in order: each one's accent (its glyph and title
## bar) and the four corners of its gradient (top left, top right, bottom
## left, bottom right), as on Aurora's Explore, Collections, History and
## Applications cards. Entries past the fourth reuse them in turn.
const CARDS := [
	{"accent": TEAL, "corners": [Color("7635e1"), Color("4ad1e0"), Color("e943b0"), Color("b5ec87")]},
	{"accent": PINK, "corners": [Color("f2936e"), Color("f17ec6"), Color("e98175"), Color("d578d9")]},
	{"accent": ORANGE, "corners": [Color("d94cff"), Color("e1eec5"), Color("8a58fc"), Color("6bddc9")]},
	{"accent": BLUE, "corners": [Color("f27864"), Color("e0e25a"), Color("b845a0"), Color("a5d1b6")]},
]

static func card(index: int) -> Dictionary:
	return CARDS[posmod(index, CARDS.size())]

## The focus colour: the selected row, the focused button, the active dot.
static func accent() -> Color:
	return Color(_setting("accent_color", DEFAULT_ACCENT))

const DEFAULT_SECOND_ACCENT := "00bcb9"

## The second colour, for the slow trail behind Now Playing's visualizer.
static func second_accent() -> Color:
	return Color(_setting("visualizer_trail_color", DEFAULT_SECOND_ACCENT))

static func show_battery_percentage() -> bool:
	return bool(_setting("battery_percentage", false))

static func show_clock() -> bool:
	return bool(_setting("show_clock", true))

## Follows the app's own 24 hour clock setting.
static func clock_24_hour() -> bool:
	if Engine.is_editor_hint():
		return true
	return SongoSettings.get_instance().clock_24_hour

static func clock_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	var hour: int = now.hour
	if not clock_24_hour():
		var suffix := "PM" if hour >= 12 else "AM"
		hour = hour % 12
		if hour == 0: hour = 12
		return "%d:%02d %s" % [hour, now.minute, suffix]
	return "%02d:%02d" % [hour, now.minute]

static func time_text(seconds: float) -> String:
	if seconds < 0: return "--:--"
	var s := int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]

## A rounded box (Aurora's panels, pills and buttons).
static func box(fill: Color, radius: int, margin := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	style.anti_aliasing = true
	style.set_content_margin_all(margin)
	return style

static func _setting(key: String, fallback):
	# Autoloads don't exist while editing scenes, so the editor gets defaults.
	if Engine.is_editor_hint():
		return fallback
	return ThemeManager.settings.get(key, fallback)
