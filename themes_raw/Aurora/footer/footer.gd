extends MarginContainer
## Aurora's footer: the page's button hints in a navy pill at the left, and
## Back in a pill of its own at the right (not on the main menu). The hints
## are all in the scene; this shows the ones for the page that's open.

func _ready() -> void:
	Controller.page_changed.connect(_update_hints)
	SongoPlayer.updated_repeat.connect(_update_hints)
	_update_hints()

func _update_hints() -> void:
	var song_view: bool = Controller.is_song_view(Controller.active_container)
	var main_menu: bool = Controller.nav_label.size() <= 1 and not song_view
	%SelectHint.visible = not song_view
	%PauseHint.visible = song_view
	%RepeatHint.visible = song_view
	%InfoHint.visible = song_view
	%BackPill.visible = not main_menu
	# On Now Playing, X turns repeat on and off: the hint names what X
	# switches to.
	var x_action := "Repeat"
	if SongoPlayer.repeating:
		x_action = "Shuffle" if SongoPlayer.play_mode == SongoPlayer.MODE.SHUFFLE else "Linear"
	%RepeatHint.action = x_action
