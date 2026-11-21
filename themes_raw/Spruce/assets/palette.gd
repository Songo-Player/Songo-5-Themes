@tool
extends RefCounted
## spruce's colors and the theme's setting lookups, in one place. Every
## component preloads this.
##
## The colors are the ones spruce's own SPRUCE theme draws with (a Gruvbox
## dark palette): the page, panels and the selected row's dark fill, the warm
## cream lettering, the gray idle icons and the yellow, green and orange
## highlights.

const BG := Color("282828")          # the page (background.png)
const BG_HARD := Color("1d2021")     # inside the selected row (list-item-select-bg)
const PANEL := Color("3c3836")       # popups and sub menus (menu-sub-bg)
const PANEL_HI := Color("504945")    # raised rows and buttons (bg-list-s)
const GRAY := Color("7c6f64")        # idle icons and labels (grid color)
const GRAY_LIGHT := Color("a89984")  # secondary text on a raised panel, where GRAY is too faint
const TRACK := Color("665c54")       # an empty progress track on a raised panel
const TEXT := Color("ebdbb2")        # titles, hints, the battery number
const TEXT_BRIGHT := Color("fbf1c7") # list text, the selected label
const ORANGE := Color("d65d0e")      # the selected row's edge, totals
const YELLOW := Color("d7b45f")      # focused icons, wifi, button hints
const GREEN := Color("689d6a")       # focused icons, the battery
const RED := Color("cc241d")         # an empty battery

const DEFAULT_SELECTION := "d65d0e"

## The edge of the selected row, the progress bar and other highlights.
static func selection() -> Color:
	return Color(_setting("selection_color", DEFAULT_SELECTION))

## Lettering drawn on a filled selection color.
static func on_selection() -> Color:
	return BG if selection().get_luminance() > 0.45 else TEXT_BRIGHT

## The color a focused menu icon lights up in. spruce alternates yellow and
## green along its main menu (Favorites yellow, Games green, ...), which is
## the default here too.
static func icon_focus(index: int) -> Color:
	match str(_setting("icon_colors", "spruce")):
		"yellow": return YELLOW
		"green": return GREEN
		"selection": return selection()
		_: return YELLOW if index % 2 == 0 else GREEN

static func show_battery_percentage() -> bool:
	return bool(_setting("battery_percentage", true))

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

static func _setting(key: String, fallback):
	# Autoloads don't exist while editing scenes, so the editor gets defaults.
	if Engine.is_editor_hint():
		return fallback
	return ThemeManager.settings.get(key, fallback)
