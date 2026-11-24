@tool
extends Control
## The face of one of Aurora's cards: its four-corner gradient with the soft
## light in the middle, or a picture (a cover) filling it, rounded either
## way. (Godot has no node that draws either, so this one does.)

const Card = preload("card_drawing.gd")

## Top left, top right, bottom left, bottom right.
@export var corners: Array[Color] = [Color("7635e1"), Color("4ad1e0"), Color("e943b0"), Color("b5ec87")]:
	set(value):
		corners = value
		queue_redraw()
## Shown instead of the gradient when set.
@export var picture: Texture2D:
	set(value):
		picture = value
		queue_redraw()
@export var radius := 12.0:
	set(value):
		radius = value
		queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0 or rect.size.y <= 0: return
	if picture:
		Card.draw_picture(self, picture, rect, radius)
	elif corners.size() == 4:
		Card.draw_gradient(self, rect, corners, radius)
