extends Control
## Now Playing, built from the main menu's pieces. The song is a focused
## card (Card): its cover (or, without one, one of Aurora's gradients with a
## white note, picked by the album) over a navy panel with a coloured bar,
## the title and the artist. Beside it (Column), navy panels: the file type,
## where it is in the queue and the album, over a visualizer (bars in the
## accent colour, with a slower trail of balls in the second accent colour
## behind them) that lyrics fade in over; the progress bar between the time
## played and the song's length; and the controls as the main menu's square
## buttons, play wide in the accent colour.
##
## On a screen taller than it is wide (or rotated) the card sits on top and
## the panels go underneath.
##
## A plays and pauses (the play button keeps focus); Songo itself handles
## left / right (skip) and up / down (seek).

const P = preload("../assets/palette.gd")
const ICON_PLAY = preload("../assets/icons/play.svg")
const ICON_PAUSE = preload("../assets/icons/pause.svg")
const ICON_SHUFFLE = preload("../assets/icons/shuffle.svg")
const ICON_REPEAT = preload("../assets/icons/repeat.svg")

const CARD_W := 300.0
const LYRIC_FADE := 0.25

var current_song_duration := 1.0
var loaded_song = null
var _record = null
var _playing := true
var _lyric_tween: Tween
var _lyrics_connected := false

func _ready() -> void:
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	resized.connect(_update_orientation)
	_apply_settings()
	_update_orientation()
	_connect_lyrics()
	%PlayButton.grab_focus.call_deferred()

func _enter_tree() -> void:
	if not SongoPlayer.updated_repeat.is_connected(_update_chips):
		SongoPlayer.updated_repeat.connect(_update_chips)

func _exit_tree() -> void:
	if SongoPlayer.updated_repeat.is_connected(_update_chips):
		SongoPlayer.updated_repeat.disconnect(_update_chips)

func setup() -> void:
	pass

func _apply_settings() -> void:
	%Progress.fill_color = P.accent()
	%Bars.bar_color = P.accent()
	%Trail.bar_color = P.second_accent()
	%LockIcon.self_modulate = P.accent()
	%SunIcon.self_modulate = P.accent()

# Side by side when wide; the card on top when tall.
func _update_orientation() -> void:
	var portrait := size.y > size.x
	%Layout.vertical = portrait
	if portrait:
		%Card.custom_minimum_size = Vector2(0, floorf(minf(size.x * 0.95, size.y * 0.55)))
	else:
		%Card.custom_minimum_size = Vector2(floorf(minf(CARD_W, (size.x - 16) * 0.5)), 0)

##############################
#            SONG            #
##############################

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	_record = music_record
	display_play_button()
	%Title.set_carousel_text(music_record.title)
	%Artist.text = music_record.artist
	%Album.text = music_record.album
	%Album.visible = str(music_record.album) != ""
	%AlbumCaption.visible = %Album.visible
	%FileLabel.text = "Web Stream" if SongoPlayer.is_stream_record(music_record) else str(music_record.file_type).to_upper()
	_update_chips()
	if loaded_song == music_record.full_path: return
	loaded_song = music_record.full_path
	_show_lyric("")
	# Songs from the same album get the same card colours.
	var key := str(music_record.album) if str(music_record.album) != "" else str(music_record.title)
	var colors: Dictionary = P.card(absi(key.hash()) % P.CARDS.size())
	var corners: Array[Color] = []
	corners.assign(colors.corners)
	%Face.corners = corners
	%Face.picture = Artwork.song_cover_texture(music_record)
	%NoteIcon.visible = %Face.picture == null
	%AccentBar.add_theme_stylebox_override("panel", P.box(colors.accent, 4))
	var length: float = music_record.raw_length
	current_song_duration = length if length > 0 else -1.0
	%TimeEnd.text = P.time_text(current_song_duration)

# Where it is in the queue, or shuffle / repeat when they're on.
func _update_chips() -> void:
	var text := ""
	var icon: Texture2D = null
	if SongoPlayer.repeating:
		text = "Repeat"
		icon = ICON_REPEAT
	elif SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE:
		text = "Shuffle"
		icon = ICON_SHUFFLE
	elif SongoPlayer.music_files.size() > 0:
		text = "%d / %d" % [SongoPlayer.play_index + 1, SongoPlayer.music_files.size()]
	%QueueChip.visible = text != ""
	%QueueLabel.text = text
	%QueueIcon.texture = icon
	%QueueIcon.visible = icon != null

func _process(_delta: float) -> void:
	%LockIcon.visible = DeviceOS.inputs_locked
	%SunIcon.visible = DeviceOS.keep_screen_awake
	if not _lyrics_connected: _connect_lyrics()
	if not SongoPlayer.is_playing(): return
	var position_s: float = SongoPlayer.get_playback_position()
	%TimeNow.text = P.time_text(position_s)
	if current_song_duration > 0:
		%Progress.progress = position_s / current_song_duration
	else:
		# A stream has no end, so the knob just keeps going round.
		%Progress.progress = fmod(position_s, 120.0) / 120.0

## Songo calls these by what was just done: play shows pause, and so on.
func display_play_button() -> void:
	_playing = true
	%PlayButton.icon = ICON_PAUSE
	%PlayButton.grab_focus()

func display_pause_button() -> void:
	_playing = false
	%PlayButton.icon = ICON_PLAY
	%PlayButton.grab_focus()

func _on_play_button_pressed() -> void:
	if _playing:
		SongoPlayer.pause()
		display_pause_button()
	else:
		SongoPlayer.resume()
		display_play_button()

# The skip buttons (for a tap; a controller uses left / right) follow
# Songo's own L1 / R1: a stream only moves between streams, and only when
# there's more than one, and previous restarts a song that's 3 seconds or
# more in.
func _on_prev_button_pressed() -> void:
	if not _can_skip(): return
	if SongoPlayer.get_playback_position() >= 3.0 and not SongoPlayer.is_current_stream():
		SongoPlayer.play_from_start()
	else:
		SongoPlayer.play_previous()

func _on_next_button_pressed() -> void:
	if _can_skip(): SongoPlayer.play_next()

func _can_skip() -> bool:
	if DeviceOS.inputs_locked: return false
	return not SongoPlayer.is_current_stream() or SongoPlayer.music_files.size() > 1

##############################
#           LYRICS           #
##############################

# LrcProcess sends lyrics here instead of flashing them while this is
# connected. It's started a little after boot, so this keeps trying until it
# exists. A method (not a lambda) is connected so Godot drops the connection
# when this scene is freed, and lyrics go back to the default display.
func _connect_lyrics() -> void:
	var lrc_process := get_node_or_null("/root/LrcProcess")
	if lrc_process == null: return
	if not lrc_process.display_lyric.is_connected(_on_display_lyric):
		lrc_process.display_lyric.connect(_on_display_lyric)
	_lyrics_connected = true

func _on_display_lyric(lyric_text: String) -> void:
	_show_lyric(lyric_text)

# Fades the current line out, then the new one in, with the visualizer
# dimmed behind it while there are words to read.
func _show_lyric(lyric_text: String) -> void:
	if _lyric_tween: _lyric_tween.kill()
	_lyric_tween = create_tween()
	if %Lyric.modulate.a > 0.0:
		_lyric_tween.tween_property(%Lyric, "modulate:a", 0.0, LYRIC_FADE)
	_lyric_tween.tween_callback(func(): %Lyric.text = lyric_text)
	var has_words := lyric_text.strip_edges() != ""
	_lyric_tween.parallel().tween_property(%Bars, "modulate:a", 0.25 if has_words else 1.0, LYRIC_FADE)
	_lyric_tween.parallel().tween_property(%Trail, "modulate:a", 0.25 if has_words else 1.0, LYRIC_FADE)
	if has_words:
		_lyric_tween.tween_property(%Lyric, "modulate:a", 1.0, LYRIC_FADE)
