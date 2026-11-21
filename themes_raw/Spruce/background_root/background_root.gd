extends PanelContainer
## spruce's background: one flat, warm dark gray. Also recolors the shared
## Theme's highlights for the Selection Color setting, so the app's own pages
## (Settings and so on) follow along.

const P = preload("../assets/palette.gd")

func _ready() -> void:
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	(get_theme_stylebox("panel") as StyleBoxFlat).bg_color = P.BG
	var t := get_tree().root.theme
	if t == null: return
	var selection := P.selection()
	# The selected row: spruce's dark fill inside a colored edge.
	for type in ["ListButton", "Button", "SongoSettingsButton"]:
		for style_name in ["focus", "pressed"]:
			_border(t, type, style_name, selection)
	for style_name in ["grabber_highlight", "grabber_pressed"]:
		var style := t.get_stylebox(style_name, "VScrollBar") as StyleBoxFlat
		if style: style.bg_color = selection

func _border(t: Theme, type: String, style_name: String, color: Color) -> void:
	var style := t.get_stylebox(style_name, type) as StyleBoxFlat
	if style: style.border_color = color
