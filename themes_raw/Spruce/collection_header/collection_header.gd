extends MarginContainer
## Above a list: what kind of list it is and how it's sorted, in gray, with
## the list type's icon, and spruce's page counter on the right: where you are
## in cream, the total in orange.

const P = preload("../assets/palette.gd")

const TYPE_ICONS := {
	"ALBUM": preload("../assets/icons/record.svg"),
	"ARTIST": preload("../assets/icons/user.svg"),
	"PLAYLIST": preload("../assets/icons/playlist.svg"),
	"SETTING": preload("../assets/icons/gear.svg"),
}
const DEFAULT_ICON := preload("../assets/icons/music.svg")

var _shown_index := -1

func _ready() -> void:
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)

func _apply_settings() -> void:
	%Total.add_theme_color_override("font_color", P.ORANGE)

func setup(sort_key) -> void:
	var kind: String = CollectionHelper.collection_type
	%TypeIcon.texture = DEFAULT_ICON
	for key in TYPE_ICONS:
		if key in kind:
			%TypeIcon.texture = TYPE_ICONS[key]
			break

	var kind_text := kind.replace("_", " ").capitalize()
	if sort_key is String and SongoSort.TYPES.has(sort_key):
		var direction := "descending" if "_desc" in sort_key else "ascending"
		# Shown here rather than as a flash message: the header always has room.
		kind_text += "  ·  %s, %s" % [str(SongoSort.TYPES[sort_key]), direction]
	%KindLabel.text = kind_text
	%Total.text = str(int(CollectionHelper.collection_size))
	_shown_index = -1
	_process(0)

# The focused row changes without telling the header, so it's checked here.
func _process(_delta: float) -> void:
	var index: int = CollectionHelper.target_item_index
	if index == _shown_index: return
	_shown_index = index
	%Current.text = str(clampi(index + 1, 1, maxi(1, int(CollectionHelper.collection_size))))
