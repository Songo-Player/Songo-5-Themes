extends MarginContainer
## Above a list: what kind of list it is and how it's sorted, in grey, and
## Aurora's counter on the right, a navy pill with where you are out of how
## many.

const P = preload("../assets/palette.gd")

var _shown_index := -1

func setup(sort_key) -> void:
	var kind: String = CollectionHelper.collection_type
	var kind_text := kind.replace("_", " ").capitalize()
	if sort_key is String and SongoSort.TYPES.has(sort_key):
		var direction := "descending" if "_desc" in sort_key else "ascending"
		kind_text += "  ·  %s, %s" % [str(SongoSort.TYPES[sort_key]), direction]
	%KindLabel.text = kind_text
	_shown_index = -1
	_process(0)

# The focused row changes without telling the header, so it's checked here.
func _process(_delta: float) -> void:
	var index: int = CollectionHelper.target_item_index
	if index == _shown_index: return
	_shown_index = index
	var total := maxi(1, int(CollectionHelper.collection_size))
	%Counter.text = "%d / %d" % [clampi(index + 1, 1, total), int(CollectionHelper.collection_size)]
