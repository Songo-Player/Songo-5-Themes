extends MarginContainer
## Now playing, in spruce's colors: the cover in a rounded frame, the title
## in bright cream over the artist and album, a progress track in the
## selection color and a yellow play button like spruce's A glyph.

const P = preload("../assets/palette.gd")

const LYRIC_FADE := 0.25

var current_song_duration := 1.0
var loaded_song = null
var _lyrics_connected := false
var _lyric_tween: Tween

func _ready() -> void:
	update_play_mode_icons()
	%PauseButton.grab_focus()
	ThemeManager.theme_settings_updated.connect(_on_theme_settings_updated)
	_on_theme_settings_updated()
	_connect_lyrics()
	# The app's screen is resized on rotation as well as on window changes.
	var screen: Control = UiHelper.transform_container
	if screen: screen.resized.connect(_queue_layout)
	resized.connect(_queue_layout)
	_update_orientation()

func setup() -> void:
	pass

func _process(_delta: float) -> void:
	%LockIcon.visible = DeviceOS.inputs_locked
	%StayAwakeIcon.visible = DeviceOS.keep_screen_awake
	update_play_time()
	_fit_lyric()
	if not _lyrics_connected: _connect_lyrics()

func setup_display_for(music_record: TagLibMusicRecord) -> void:
	display_play_button()
	# Long titles scroll by rather than being cut short.
	%SongLabel.set_carousel_text(music_record.title)
	%ArtistLabel.text = music_record.artist
	%AlbumLabel.text = music_record.album
	%AlbumLabel.visible = str(music_record.album) != ""

	if loaded_song == music_record.full_path: return
	_show_lyric("")

	var cover = Artwork.song_cover_texture(music_record)
	%MusicImage.visible = cover != null
	%DefaultSongImage.get_parent().visible = cover == null
	if cover: %MusicImage.texture = cover

	%FileTypeLabel.text = "Web Stream" if SongoPlayer.is_stream_record(music_record) else music_record.file_type.to_upper()
	loaded_song = music_record.full_path
	set_end_time(music_record)
	setup_playlist_info()

func setup_playlist_info() -> void:
	%TrackCurrent.text = str(SongoPlayer.play_index + 1)
	%TrackTotal.text = str(SongoPlayer.music_files.size())

func update_play_mode_icons() -> void:
	%TrackCount.visible = SongoPlayer.play_mode == SongoPlayer.MODE.LINEAR and not SongoPlayer.repeating
	%ShuffleIcon.visible = SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE and not SongoPlayer.repeating
	%RepeatingIcon.visible = SongoPlayer.repeating

func set_end_time(music_record: TagLibMusicRecord) -> void:
	var length_sec: float = music_record.raw_length
	current_song_duration = length_sec if length_sec > 0 else -1.0
	%EndTimeLabel.text = P.time_text(current_song_duration)

func update_play_time() -> void:
	if not SongoPlayer.is_playing(): return
	var position: float = SongoPlayer.get_playback_position()
	%CurrentTimeLabel.text = P.time_text(position)
	if current_song_duration > 0:
		%Progress.progress = position / current_song_duration
	else:
		# A stream has no end, so the knob just keeps going round.
		%Progress.progress = fmod(position, 120.0) / 120.0

func display_play_button() -> void:
	%PlayButton.hide()
	%PauseButton.show()
	%PauseButton.grab_focus()

func display_pause_button() -> void:
	%PauseButton.hide()
	%PlayButton.show()
	%PlayButton.grab_focus()

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

# Fades the current line out, then the new one in. An empty line just fades
# out, so a song without lyrics (or a gap in them) leaves the space clear.
func _show_lyric(lyric_text: String) -> void:
	if _lyric_tween: _lyric_tween.kill()
	_lyric_tween = create_tween()
	if %LyricLabel.modulate.a > 0.0:
		_lyric_tween.tween_property(%LyricLabel, "modulate:a", 0.0, LYRIC_FADE)
	_lyric_tween.tween_callback(func(): %LyricLabel.text = lyric_text)
	if lyric_text.strip_edges() != "":
		_lyric_tween.tween_property(%LyricLabel, "modulate:a", 1.0, LYRIC_FADE)

# Lyrics sit in the gap between the art and the buttons without being part
# of the layout, so the page looks the same with or without them. The label
# is fitted to that gap: the full width, from the bottom of the art and info
# panel down to the top of the buttons.
func _fit_lyric() -> void:
	var layer: Control = $LyricLayer
	var top := maxf($Layout/Top/ArtRow/ArtFrame.get_global_rect().end.y, $Layout/Top/InfoPanel.get_global_rect().end.y)
	var bottom: float = $Layout/Controls.get_global_rect().position.y
	var left: float = $Layout.get_global_rect().position.x
	var inverse := layer.get_global_transform().affine_inverse()
	var from: Vector2 = inverse * Vector2(left, top)
	var to: Vector2 = inverse * Vector2(left + $Layout.size.x, bottom)
	%LyricLabel.position = from
	%LyricLabel.size = Vector2(to.x - from.x, maxf(0.0, to.y - from.y))

# When the app is taller than it is wide (a tall window, or a wide one with
# the display rotated), the art sits centered above the info panel with a
# second visualizer on its right, mirroring the left one. The panel matches
# the art's width and only needs the height of its text, and the art grows
# into the extra height, leaving room below for lyrics.
const ART_SIZE := 196.0
const PORTRAIT_ART_MAX := 500.0
const LYRIC_ROOM := 96.0  # split above the art and below the panel

var _layout_queued := false

# Resizes come in bursts (a window drag, a rotation, the art itself growing),
# so the layout is worked out once, after they've all landed.
func _queue_layout() -> void:
	if _layout_queued: return
	_layout_queued = true
	_update_orientation.call_deferred()

func _update_orientation() -> void:
	_layout_queued = false
	var portrait := _app_size().y > _app_size().x
	var top: BoxContainer = $Layout/Top
	top.vertical = portrait
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12 if portrait else 22)
	$Layout/Top/ArtRow/VisualizerRight.visible = portrait
	var panel: PanelContainer = $Layout/Top/InfoPanel
	panel.custom_minimum_size.y = 0.0 if portrait else ART_SIZE
	# Stacked, the panel is as wide as the art above it (sized with the art).
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_EXPAND_FILL
	_set_art_size(_portrait_art_size() if portrait else ART_SIZE)

# The app's own screen, not the window: Songo's Rotate Display turns this
# container inside an unrotated window, so only its size says which way up
# the app is.
func _app_size() -> Vector2:
	var screen: Control = UiHelper.transform_container
	return screen.size if screen else get_viewport().get_visible_rect().size

# The art fills what's left of the space this page is given: the width beside
# the two visualizers, and the height after the info panel, buttons and some
# room for lyrics. It's worked out from sizes the art doesn't change, so
# running it again gives the same answer and resizing can't feed back into it.
func _portrait_art_size() -> float:
	var side: float = $Layout/Top/ArtRow/ArtFrame.custom_minimum_size.y
	var own_min := get_combined_minimum_size()
	var space := _available_size(own_min)
	# The width is the page's, minus its side margins and the visualizers
	# beside the art. (Not the page's minimum width, which is the buttons'
	# when they're wider than the art row.)
	var margins := get_theme_constant("margin_left") + get_theme_constant("margin_right")
	var beside: float = $Layout/Top/ArtRow.get_combined_minimum_size().x - side
	var free_width := space.x - margins - beside
	# The height is everything on the page apart from the art itself.
	var free_height := space.y - (own_min.y - side) - LYRIC_ROOM
	return clampf(floorf(minf(free_width, free_height)), ART_SIZE, PORTRAIT_ART_MAX)

# The space the app gives this page. Its own size is right unless the art has
# made the page bigger than that space (after the window shrinks), when it's
# stuck at its minimum. So it's also worked out from the app's screen: minus
# what the rest of the app (header, footer, margins) needs around this page.
func _available_size(own_min: Vector2) -> Vector2:
	var screen: Control = UiHelper.transform_container
	var outer: Control = self
	while outer.get_parent() is Control and outer.get_parent() != screen:
		outer = outer.get_parent()
	if screen == null or outer == self: return size
	# Only when stuck at its minimum is the page's own size in doubt.
	var around := outer.get_combined_minimum_size() - own_min
	var space := size
	if size.x <= own_min.x + 0.5: space.x = minf(size.x, screen.size.x - around.x)
	if size.y <= own_min.y + 0.5: space.y = minf(size.y, screen.size.y - around.y)
	return space

func _set_art_size(side: float) -> void:
	if $Layout/Top/ArtRow/ArtFrame.custom_minimum_size.y == side and $Layout/Top/InfoPanel.custom_minimum_size.x == (side if $Layout/Top.vertical else 0.0):
		return
	$Layout/Top/ArtRow/ArtFrame.custom_minimum_size = Vector2(side, side)
	$Layout/Top/ArtRow/Visualizer.custom_minimum_size.y = side
	$Layout/Top/ArtRow/VisualizerRight.custom_minimum_size.y = side
	$Layout/Top/InfoPanel.custom_minimum_size.x = side if $Layout/Top.vertical else 0.0

##############################
#           SIGNALS          #
##############################

func _on_play_button_pressed() -> void:
	SongoPlayer.resume()
	display_play_button()

func _on_pause_button_pressed() -> void:
	SongoPlayer.pause()
	display_pause_button()

# The skip pills are for the mouse; on a controller L1 / R1 (and left /
# right) already do this, so the pills never take focus. They follow the
# app's own L1 / R1 handling (ThemeMainSongView.handle_input): a stream only
# moves between streams, and only when there's more than one, and previous
# restarts the song when it's 3 seconds or more in.
func _can_skip() -> bool:
	if DeviceOS.inputs_locked: return false
	return not SongoPlayer.is_current_stream() or SongoPlayer.music_files.size() > 1

func _on_prev_button_pressed() -> void:
	if not _can_skip(): return
	if SongoPlayer.get_playback_position() >= 3.0 and not SongoPlayer.is_current_stream():
		SongoPlayer.play_from_start()
	else:
		SongoPlayer.play_previous()

func _on_next_button_pressed() -> void:
	if not _can_skip(): return
	SongoPlayer.play_next()

func _on_tree_entered() -> void:
	SongoPlayer.updated_repeat.connect(_on_updated_repeat)
	await get_tree().process_frame
	update_play_mode_icons()

func _on_tree_exited() -> void:
	SongoPlayer.updated_repeat.disconnect(_on_updated_repeat)

func _on_updated_repeat() -> void:
	update_play_mode_icons()
	setup_playlist_info()

func _on_theme_settings_updated() -> void:
	%Progress.fill_color = P.selection()
