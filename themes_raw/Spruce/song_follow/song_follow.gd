extends MarginContainer
## Shown at the foot of other pages while music plays: a raised spruce
## panel with the song scrolling by, a thin progress line along its bottom
## edge, and SELECT / START pills for getting back to it or stopping it.

const P = preload("../assets/palette.gd")
const Hints = preload("../assets/button_hints.gd")

const HINTS := [["SELECT", "Return"], ["START", "Stop"]]

var _duration := -1.0

func _ready() -> void:
	%Hints.add_child(Hints.build(HINTS, 18, 13))
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	%Fill.color = P.selection()
	%SongTitle.font_color = P.TEXT_BRIGHT

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	%SongTitle.set_carousel_text("%s  ·  %s" % [music_record.title, music_record.artist])
	_duration = music_record.raw_length if music_record.raw_length > 0 else -1.0

func _process(_delta: float) -> void:
	var track: float = %Track.size.x
	var ratio := 0.0
	if _duration > 0 and SongoPlayer.is_playing():
		ratio = clampf(SongoPlayer.get_playback_position() / _duration, 0.0, 1.0)
	%Track.visible = _duration > 0
	%Fill.size = Vector2(track * ratio, %Track.size.y)
