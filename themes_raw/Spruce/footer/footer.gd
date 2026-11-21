extends MarginContainer
## spruce's tips bar: yellow button glyphs with what they do on this page,
## and the app version tucked in on the right.

const P = preload("../assets/palette.gd")
const Hints = preload("../assets/button_hints.gd")

const MAIN_MENU_HINTS := [["A", "Open"]]
const LIST_HINTS := [["A", "Select"], ["B", "Back"]]

var _hints: Control

func _ready() -> void:
	%VersionLabel.text = "Songo " + str(SongoDataResource.VERSION)
	Controller.page_changed.connect(_update_hints)
	SongoPlayer.updated_repeat.connect(_update_hints)
	_update_hints()

# On the now playing page X turns repeat on and off. Turning it off goes
# back to the order the queue was playing in, so the hint names what X
# switches to.
func _song_hints() -> Array:
	var x_action := "Repeat"
	if SongoPlayer.repeating:
		x_action = "Shuffle" if SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE else "Linear"
	return [["B", "Back"], ["X", x_action], ["SELECT", "Info"]]

func _update_hints() -> void:
	var pairs: Array = LIST_HINTS
	if Controller.is_song_view(Controller.active_container):
		pairs = _song_hints()
	elif Controller.nav_label.size() <= 1:
		pairs = MAIN_MENU_HINTS
	if _hints: _hints.queue_free()
	_hints = Hints.build(pairs)
	%Row.add_child(_hints)
	%Row.move_child(_hints, 0)
