@tool
extends MarginContainer
## spruce's main menu: a row of four big outlined icons with their names
## underneath. The focused one lights up (yellow and green in turn, like
## spruce's Favorites / Games / Apps / Settings) with its name in bright
## cream; the rest wait in gray. With more than four entries the row slides
## along as focus moves, and dots underneath show where you are.

const P = preload("../assets/palette.gd")
const FONT_BOLD = preload("../assets/font_bold.tres")

const SLOTS := 4
const ICON_SIZE := 92.0
const LABEL_SIZE := 22
const SLIDE_TIME := 0.18

# Songo's own menu icons, swapped for this theme's spruce-style ones.
const ICONS := {
	"music.svg": preload("../assets/icons/music.svg"),
	"record.svg": preload("../assets/icons/record.svg"),
	"user.svg": preload("../assets/icons/user.svg"),
	"layergroup.svg": preload("../assets/icons/playlist.svg"),
	"gear.svg": preload("../assets/icons/gear.svg"),
	"exit_walk.svg": preload("../assets/icons/power.svg"),
}

const EDITOR_PREVIEW_ITEMS := [
	["All Songs", "res://assets/music.svg"],
	["Albums", "res://assets/record.svg"],
	["Artists", "res://assets/user.svg"],
	["Playlists", "res://assets/layergroup.svg"],
	["Settings", "res://assets/gear.svg"],
	["Exit", "res://assets/exit_walk.svg"],
]

var buttons: Array[Button] = []
var _tiles: Array[Dictionary] = []
var _first_visible := 0
var _slide: Tween

func _ready() -> void:
	var items := _resolve_menu_items()
	for i in items.size():
		_add_tile(items[i], i)
	for i in buttons.size():
		var left := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var right := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(left)
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(right)
		# Nothing above or below: keep focus in the row.
		buttons[i].focus_neighbor_top = NodePath(".")
		buttons[i].focus_neighbor_bottom = NodePath(".")
	_build_dots()
	%Window.resized.connect(_layout_row.bind(false))

	if Engine.is_editor_hint():
		if not _tiles.is_empty(): _show_focus(0, true)
		return
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	if not buttons.is_empty(): buttons[0].grab_focus()

# Optional; called once the menu is in the scene tree.
func setup() -> void:
	pass

# Controller isn't available while editing (it's an autoload), so the editor
# gets a fixed set of entries just to preview the layout.
func _resolve_menu_items() -> Array[MenuItemData]:
	if Engine.is_editor_hint():
		var preview: Array[MenuItemData] = []
		for entry in EDITOR_PREVIEW_ITEMS:
			preview.append(MenuItemData.new(entry[0], entry[1], Callable()))
		return preview
	return Controller.menu_items

func _add_tile(item: MenuItemData, index: int) -> void:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.flat = true
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	%Row.add_child(button)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	button.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon := TextureRect.new()
	icon.texture = ICONS.get(item.icon_path.get_file(), item.icon())
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)

	var label := Label.new()
	label.text = item.label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_font_size_override("font_size", LABEL_SIZE)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)

	_tiles.append({"button": button, "icon": icon, "label": label})
	buttons.append(button)
	_show_focus(index, false)
	button.focus_entered.connect(_on_tile_focus.bind(index, true))
	button.focus_exited.connect(_on_tile_focus.bind(index, false))
	if item.action.is_valid():
		button.pressed.connect(item.action)

func _on_tile_focus(index: int, focused: bool) -> void:
	_show_focus(index, focused)
	if not focused: return
	# Keep the focused tile inside the four visible slots.
	if index < _first_visible:
		_first_visible = index
	elif index >= _first_visible + SLOTS:
		_first_visible = index - SLOTS + 1
	_layout_row(true)
	_update_dots(index)

func _show_focus(index: int, focused: bool) -> void:
	var tile: Dictionary = _tiles[index]
	tile.icon.modulate = P.icon_focus(index) if focused else P.GRAY
	tile.label.add_theme_color_override("font_color", P.TEXT_BRIGHT if focused else P.GRAY)
	tile.label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75 if focused else 0.0))

# Tiles split the visible width four ways. Fewer than four entries sit
# centred; more slide so the focused one stays in view.
func _layout_row(animate: bool) -> void:
	var width: float = %Window.size.x
	if width <= 0 or _tiles.is_empty(): return
	var tile_width := floorf(width / SLOTS)
	for tile in _tiles:
		tile.button.custom_minimum_size = Vector2(tile_width, ICON_SIZE + 60)
	var total := tile_width * _tiles.size()
	var target := 0.0
	if _tiles.size() <= SLOTS:
		target = floorf((width - total) / 2.0)
	else:
		_first_visible = clampi(_first_visible, 0, _tiles.size() - SLOTS)
		target = -_first_visible * tile_width
	%Row.size = Vector2(total, %Window.size.y)
	if _slide: _slide.kill()
	if animate and is_inside_tree() and not Engine.is_editor_hint():
		_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide.tween_property(%Row, "position:x", target, SLIDE_TIME)
	else:
		%Row.position.x = target

func _build_dots() -> void:
	%Dots.visible = _tiles.size() > SLOTS
	for i in _tiles.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.bg_color = P.GRAY
		dot.add_theme_stylebox_override("panel", style)
		%Dots.add_child(dot)
	_update_dots(0)

func _update_dots(focused: int) -> void:
	for i in %Dots.get_child_count():
		var style := (%Dots.get_child(i) as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = P.TEXT_BRIGHT if i == focused else P.PANEL_HI

func _apply_settings() -> void:
	# The host keeps the menu out of the tree while other pages are open.
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for i in _tiles.size():
		_show_focus(i, _tiles[i].button == focused)
