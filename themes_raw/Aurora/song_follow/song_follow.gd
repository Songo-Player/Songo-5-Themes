extends MarginContainer
## Shown at the foot of other pages while music plays: a navy pill with the
## song scrolling by, a thin accent progress line along its bottom edge, and
## SELECT / START badges for getting back to it or stopping it.

const P = preload("../assets/palette.gd")
var _duration := -1.0

func _ready() -> void:
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	%SongTitle.font_color = P.TEXT

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	%SongTitle.set_carousel_text("%s  ·  %s" % [music_record.title, music_record.artist])
	_duration = music_record.raw_length if music_record.raw_length > 0 else -1.0
