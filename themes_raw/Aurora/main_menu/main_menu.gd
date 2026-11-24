@tool
extends Control
## Aurora's main menu: a row of cards (menu_card.tscn) that slides along as
## focus moves, the focused one wide and bright; dots under the row show
## where you are.
##
## Settings and Exit sit apart, as square buttons in the bottom right (Exit
## in red), like Aurora's row of system buttons. Down moves to them, up
## back to the cards. While music plays, the bar Songo shows for it sits
## just above them, so they shrink (keeping their bottom right corner) to
## leave a small gap under it, and grow back once it's gone.
##
## Everything sits in Screen, which this keeps over the whole screen, so the
## layout is in Aurora's own pixels (640x480) and lines up with the header
## and footer whatever margins Songo puts around the menu.

const P = preload("../assets/palette.gd")
const MenuCard = preload("menu_card.tscn")

const FOCUS_W := 360.0
const CARD_W := 180.0
const GAP := 16.0
const BUTTON_SIZE := 64.0
const BUTTON_BOTTOM := 464.0
# The gap left between the playing bar and the buttons under it.
const FOLLOW_GAP := 8.0
const SLIDE_TIME := 0.2
const RESIZE_TIME := 0.2

# Songo's menu icons (by file name): Aurora's glyph and a line about each.
const ENTRIES := {
	"music.svg": ["music", "Every song in your library"],
	"record.svg": ["album", "Browse your albums"],
	"user.svg": ["artist", "Browse by artist"],
	"layergroup.svg": ["playlist", "Your playlists"],
}
const SYSTEM_ICONS := {"gear.svg": "settings", "exit_walk.svg": "power"}

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"], ["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"], ["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"], ["Exit", "res://assets/exit_walk.svg"],
]

var _cards: Array[Button] = []
var _system: Array[Button] = []
var _focused_card := 0
var _slide: Tween
var _button_size := BUTTON_SIZE
var _button_target := BUTTON_SIZE
var _resize: Tween

func _ready() -> void:
	for item in _menu_items():
		var file: String = item.icon_path.get_file()
		if SYSTEM_ICONS.has(file):
			_add_system_button(item, file == "exit_walk.svg", _icon(SYSTEM_ICONS[file]))
		else:
			_add_card(item)
	for i in _cards.size():
		_cards[i].focus_entered.connect(_on_card_focus.bind(i))
		%Dots.add_child(_make_dot())
	_link_buttons()
	_place_screen()
	_set_focus_visuals(0)
	%Row.position.x = _target_row_x(0)
	var first: Button = _cards[0] if not _cards.is_empty() else (_system[0] if not _system.is_empty() else null)
	if first and not Engine.is_editor_hint(): first.grab_focus.call_deferred()

## Called by Songo once the menu is in the tree.
func setup() -> void:
	pass

func _menu_items() -> Array:
	if Engine.is_editor_hint():
		var preview := []
		for entry in EDITOR_PREVIEW_ITEMS:
			preview.append(MenuItemData.new(entry[0], entry[1], Callable()))
		return preview
	return Controller.menu_items

func _icon(icon_name: String) -> Texture2D:
	var path := "res://theme_dev/themes_raw/Aurora/assets/icons/%s.svg" % icon_name
	return load(path) if ResourceLoader.exists(path) else null

func _add_card(item: MenuItemData) -> void:
	var entry: Array = ENTRIES.get(item.icon_path.get_file(), ["plugin", ""])
	var glyph := _icon(entry[0])
	var accent := _icon(entry[0] + "_accent")
	# A plugin's entry shows its own icon, when it has one.
	if entry[0] == "plugin" and item.icon():
		glyph = item.icon()
		accent = null
	var card: Button = MenuCard.instantiate()
	%Row.add_child(card)
	card.setup(item, _cards.size(), glyph, accent, entry[1])
	if not Engine.is_editor_hint() and item.action.is_valid():
		card.pressed.connect(item.action)
	_cards.append(card)

func _add_system_button(item: MenuItemData, exit: bool, glyph: Texture2D) -> void:
	var button := Button.new()
	button.theme_type_variation = &"AuroraPowerButton" if exit else &"AuroraSystemButton"
	button.icon = glyph
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	if not Engine.is_editor_hint() and item.action.is_valid():
		button.pressed.connect(item.action)
	%System.add_child(button)
	_system.append(button)

func _make_dot() -> PanelContainer:
	var dot := PanelContainer.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return dot

# Left and right along the cards (no wrapping, as in Aurora), down to
# Settings and Exit, up back to the card last focused.
func _link_buttons() -> void:
	for i in _cards.size():
		var card := _cards[i]
		card.focus_neighbor_left = card.get_path_to(_cards[maxi(0, i - 1)])
		card.focus_neighbor_right = card.get_path_to(_cards[mini(_cards.size() - 1, i + 1)])
		card.focus_neighbor_top = NodePath(".")
		card.focus_neighbor_bottom = card.get_path_to(_system[0]) if not _system.is_empty() else NodePath(".")
	for i in _system.size():
		var button := _system[i]
		button.focus_neighbor_left = button.get_path_to(_system[maxi(0, i - 1)])
		button.focus_neighbor_right = button.get_path_to(_system[mini(_system.size() - 1, i + 1)])
		button.focus_neighbor_bottom = NodePath(".")
		button.focus_neighbor_top = button.get_path_to(_cards[_focused_card]) if not _cards.is_empty() else NodePath(".")

func _on_card_focus(index: int) -> void:
	_set_focus_visuals(index)
	for button in _system:
		button.focus_neighbor_top = button.get_path_to(_cards[index])
	var target := _target_row_x(index)
	if _slide: _slide.kill()
	if is_inside_tree() and not Engine.is_editor_hint():
		_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide.tween_property(%Row, "position:x", target, SLIDE_TIME)
	else:
		%Row.position.x = target

func _set_focus_visuals(index: int) -> void:
	_focused_card = index
	for i in _cards.size():
		_cards[i].set_focused(i == index)
		var dot: PanelContainer = %Dots.get_child(i)
		dot.theme_type_variation = &"AuroraDotActive" if i == index else &"AuroraDot"
		dot.custom_minimum_size = Vector2(32 if i == index else 8, 8)

# The first card's x for a focused card: the first sits at the edge; any
# other has the card before it peeking in at the left. Held so the row
# doesn't stop short of the right edge.
func _target_row_x(index: int) -> float:
	var w: float = %Screen.size.x
	var before := index * (CARD_W + GAP)
	var focus_x := 16.0 if index == 0 else 140.0
	var after := (_cards.size() - 1 - index) * (CARD_W + GAP)
	var end := focus_x + FOCUS_W + after
	if index > 0 and end < w - 16.0:
		focus_x = minf(focus_x + (w - 16.0 - end), maxf(16.0, before + 16.0))
	return focus_x - before

##############################
#           SCREEN           #
##############################

# Keeps Screen over the whole screen (it starts above and left of the menu).
func _place_screen() -> void:
	if Engine.is_editor_hint():
		%Screen.position = Vector2(-16, -80)
		%Screen.size = Vector2(640, 480)
		return
	var screen: Control = UiHelper.transform_container
	if screen == null: return
	var offset := _screen_offset(self)
	if %Screen.position != -offset or %Screen.size != screen.size:
		%Screen.position = -offset
		%Screen.size = screen.size

func _screen_offset(control: Control) -> Vector2:
	var screen: Control = UiHelper.transform_container
	var offset := Vector2.ZERO
	var node: Node = control
	while node is Control and node != screen:
		offset += (node as Control).position
		node = node.get_parent()
	return offset

# The playing bar comes and goes without telling the menu, so it's checked
# each frame (cheaply), and the buttons ease to their new size.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	_place_screen()
	var wanted := _wanted_button_size()
	if is_equal_approx(wanted, _button_target): return
	_button_target = wanted
	if _resize: _resize.kill()
	_resize = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_resize.tween_method(_set_button_size, _button_size, wanted, RESIZE_TIME)

func _set_button_size(value: float) -> void:
	_button_size = value
	for button in _system:
		button.custom_minimum_size = Vector2(value, value)

# Full size, or small enough to leave a gap under the playing bar.
func _wanted_button_size() -> float:
	var follow_bottom := _follow_bottom()
	if follow_bottom < 0.0: return BUTTON_SIZE
	return clampf(BUTTON_BOTTOM - follow_bottom - FOLLOW_GAP, 32.0, BUTTON_SIZE)

# The bottom of Songo's playing bar, in the screen's pixels, or -1 when it
# isn't showing.
func _follow_bottom() -> float:
	if UiHelper.content_margin_container == null: return -1.0
	var follow := UiHelper.content_margin_container.get_node_or_null("VBoxContainer/ThemeSongFollow") as Control
	if follow == null or not follow.is_visible_in_tree() or follow.size.y <= 1.0: return -1.0
	if not ("theme_element" in follow) or follow.theme_element == null: return -1.0
	return _screen_offset(follow).y + follow.size.y
