extends PanelContainer
## Aurora's background: one flat, near-black navy. Also recolours the shared
## Theme's focus colour for the Accent Colour setting, so the app's own pages
## (Settings and so on) follow along.

const P = preload("../assets/palette.gd")

func _ready() -> void:
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	(get_theme_stylebox("panel") as StyleBoxFlat).bg_color = P.BG
	var t := get_tree().root.theme
	if t == null: return
	var accent := P.accent()
	for type in ["ListButton", "Button", "SongoSettingsButton", "AuroraSystemButton", "AuroraPlayButton"]:
		for style_name in ["focus", "pressed", "hover_pressed"]:
			var style := t.get_stylebox(style_name, type) as StyleBoxFlat
			if style: style.bg_color = accent
	var dot := t.get_stylebox("panel", "AuroraDotActive") as StyleBoxFlat
	if dot: dot.bg_color = accent
	for style_name in ["grabber_highlight", "grabber_pressed"]:
		var style := t.get_stylebox(style_name, "VScrollBar") as StyleBoxFlat
		if style: style.bg_color = accent
