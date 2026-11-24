@tool
extends HBoxContainer
## One of Aurora's button hints: a light badge with the button's name (round
## for a letter, a wider pill for SELECT, START and MENU), then what it does.

## The button, as printed on the badge.
@export var button := "A":
	set(value):
		button = value
		_update()
## What the button does; empty shows the badge alone.
@export var action := "":
	set(value):
		action = value
		_update()
@export var text_size := 18:
	set(value):
		text_size = value
		_update()

func _ready() -> void:
	_update()

func _update() -> void:
	if not is_node_ready(): return
	var round := button.length() == 1
	%Badge.theme_type_variation = &"AuroraBadge" if round else &"AuroraBadgeWide"
	%Letter.text = button
	%Letter.add_theme_font_size_override("font_size", 13 if round else 10)
	%Action.text = action
	%Action.visible = action != ""
	%Action.add_theme_font_size_override("font_size", text_size)
