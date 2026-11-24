extends MarginContainer
## A row in a list, drawn over the host's own button, whose ListButton style
## is Aurora's: a full pill, filled with the accent when it has focus. Songs
## are a name and a running time; albums, artists and playlists add their
## cover in a rounded frame, over a second line in grey. When the row has
## focus its cover grows a little and turns round. The host strips the
## containers this row doesn't use, so everything is looked up with
## get_node_or_null.

const P = preload("../assets/palette.gd")

# Secondary text, which brightens a step while the row is selected.
const DIM_LABELS := ["%Duration", "%ArtistName", "%ArtistSummary", "%PlaylistSummary"]
const FALLBACKS := ["%AlbumFallbackCover", "%ArtistFallbackCover", "%PlaylistFallbackCover"]
const FRAMES := ["AlbumButtonContainer/Row/Frame", "ArtistButtonContainer/Row/Frame", "PlaylistButtonContainer/Row/Frame"]
const FRAME_RADIUS := 8
const FOCUS_SCALE := 1.2

var _focused := false
var _frame: PanelContainer
var _frame_style: StyleBoxFlat
# The cover, drawn by card_face.gd so it can be rounded.
var _cover: Control

func _ready() -> void:
	_fit_settings_row()
	ThemeManager.theme_settings_updated.connect(_apply_colors)
	for path in FRAMES:
		_frame = get_node_or_null(path) as PanelContainer
		if _frame: break
	if _frame:
		# Every row's frame starts from the same style; this one gets its own
		# copy, as its corners change with focus.
		_frame_style = (_frame.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		_frame.add_theme_stylebox_override("panel", _frame_style)
		for path in ["%AlbumCover", "%ArtistImage", "%PlaylistImage"]:
			_cover = get_node_or_null(path)
			if _cover: break

# Focused: a little bigger (scaled about its centre, so the row keeps its
# height and the cover stays centred in it) and round. Otherwise its
# rounded square.
func _show_frame_focus() -> void:
	if _frame == null: return
	_frame.pivot_offset = _frame.size / 2.0
	_frame.scale = Vector2.ONE * (FOCUS_SCALE if _focused else 1.0)
	_set_frame_radius(ceilf(_frame.size.x / 2.0) if _focused else float(FRAME_RADIUS))

func _set_frame_radius(radius: float) -> void:
	_frame_style.set_corner_radius_all(int(radius))
	if _cover: _cover.radius = radius

func _apply_colors() -> void:
	for path in DIM_LABELS:
		var label := get_node_or_null(path) as Label
		if label: label.add_theme_color_override("font_color", P.TEXT if _focused else P.TEXT_DIM)
	for path in FALLBACKS:
		var icon := get_node_or_null(path) as TextureRect
		if icon: icon.modulate = P.TEXT if _focused else P.TEXT_DIM

func setup_music_record(record) -> void:
	$SongButtonContainer.show()
	if Controller.nav_label.has("Albums"):
		%SongName.text = record.get_title_with_track()
	else:
		%SongName.text = record.title
	%Duration.text = record.get_length_string()
	_apply_colors()

func setup_album_record(record) -> void:
	$AlbumButtonContainer.show()
	%AlbumName.text = record.name
	%ArtistName.text = str(record.album_artist)
	_load_cover(%AlbumCover, %AlbumFallbackCover, Artwork.album_image_path(record.asset_id))

func setup_artist_record(record) -> void:
	$ArtistButtonContainer.show()
	%RecordArtistName.text = record.name
	%ArtistSummary.text = get_song_summary(record.music_records)
	_load_cover(%ArtistImage, %ArtistFallbackCover, Artwork.artist_image_path(record.asset_id))

func setup_playlist_record(record) -> void:
	$PlaylistButtonContainer.show()
	%PlaylistName.text = record.name
	%PlaylistSummary.text = get_song_summary(record.music_records)
	_load_cover(%PlaylistImage, %PlaylistFallbackCover, record.img_path if record.img_path else "")

# cover is a card_face.gd, which draws its picture with rounded corners.
func _load_cover(cover: Control, fallback: TextureRect, path) -> void:
	_apply_colors()
	fallback.get_parent().show()
	cover.hide()
	if not path: return
	var loader = AsyncImageLoader.load_async(path)
	loader.image_loaded.connect(func(texture):
		if not is_instance_valid(cover): return
		cover.picture = texture
		cover.show()
		fallback.get_parent().hide()
	)

func _on_button_focus_entered() -> void:
	_focused = true
	_apply_colors()
	_show_frame_focus()

func _on_button_focus_exited() -> void:
	_focused = false
	_apply_colors()
	_show_frame_focus()

func get_song_summary(songs: Array) -> String:
	if songs.is_empty():
		return "No songs"
	var total_seconds := 0.0
	for song in songs:
		total_seconds += song.raw_length
	var hours := int(total_seconds / 3600)
	var minutes := int((int(total_seconds) % 3600) / 60)
	var duration := "%dh %02dm" % [hours, minutes] if hours > 0 else "%dm" % minutes
	return "%d song%s  ·  %s" % [songs.size(), "" if songs.size() == 1 else "s", duration]

# A settings row keeps none of this scene's containers: the host draws it
# with its own button, sized by the button's text. At some global UI scales
# that comes out a fraction of a pixel taller than the spacing the list lays
# rows at, so neighbouring rows overlap and up/down focus skips every other
# one. Holding the row to the button's height rounded up to a whole pixel
# keeps them apart. (Same fix as the Departures theme.)
func _fit_settings_row() -> void:
	if get_child_count() > 0: return
	var host_button := get_parent().get_node_or_null("%Button") as Control
	if host_button == null: return
	var fit := func():
		custom_minimum_size.y = ceilf(host_button.get_combined_minimum_size().y)
	host_button.minimum_size_changed.connect(fit)
	fit.call()
