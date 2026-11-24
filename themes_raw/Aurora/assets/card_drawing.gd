@tool
extends RefCounted
## The drawing behind Aurora's cards, shared by the main menu and Now
## Playing: a four-corner gradient with a soft white light in the middle,
## and pictures (covers) cut to a rounded shape.

static var _gradients := {}
static var _glow: GradientTexture2D

## Draws a card's gradient face (corners: top left, top right, bottom left,
## bottom right) with its glow, rounded at radius.
static func draw_gradient(ci: CanvasItem, rect: Rect2, corners: Array, radius: float) -> void:
	var shape := rounded_rect(rect, radius)
	ci.draw_colored_polygon(shape, Color.WHITE, uvs(shape, rect, 0.25, 0.5), gradient(corners))
	ci.draw_colored_polygon(shape, Color(1, 1, 1, 0.55), uvs(shape, rect, 0.0, 1.0), glow())

## Draws a picture filling rect (cropped to its shape, not stretched),
## rounded at radius.
static func draw_picture(ci: CanvasItem, texture: Texture2D, rect: Rect2, radius: float) -> void:
	var shape := rounded_rect(rect, radius)
	var tex_size := texture.get_size()
	var crop := Vector2.ONE
	if tex_size.x > 0 and tex_size.y > 0:
		var ratio := (rect.size.x / rect.size.y) / (tex_size.x / tex_size.y)
		crop = Vector2(minf(1.0, ratio), minf(1.0, 1.0 / ratio))
	var points_uv := PackedVector2Array()
	for p in shape:
		var t := (p - rect.position) / rect.size
		points_uv.append((Vector2.ONE - crop) / 2.0 + t * crop)
	ci.draw_colored_polygon(shape, Color.WHITE, points_uv, texture)

## A card's four-corner gradient: a 2x2 image, stretched with filtering, so
## the colours blend between the corners (the canvas item needs linear
## texture filtering).
static func gradient(corners: Array) -> Texture2D:
	var key := str(corners)
	if _gradients.has(key): return _gradients[key]
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, corners[0])
	image.set_pixel(1, 0, corners[1])
	image.set_pixel(0, 1, corners[2])
	image.set_pixel(1, 1, corners[3])
	var texture := ImageTexture.create_from_image(image)
	_gradients[key] = texture
	return texture

## The soft white light in the middle of each of Aurora's cards.
static func glow() -> GradientTexture2D:
	if _glow: return _glow
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(0.5, 0.0)
	_glow.width = 64
	_glow.height = 64
	return _glow

static func rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	radius = minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var points := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(radius, radius), 180.0],
		[Vector2(rect.end.x - radius, rect.position.y + radius), 270.0],
		[rect.end - Vector2(radius, radius), 0.0],
		[Vector2(rect.position.x + radius, rect.end.y - radius), 90.0],
	]
	for corner in corners:
		for step in 7:
			var angle := deg_to_rad(corner[1] + step * 15.0)
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius)
	return points

## UVs over rect, from uv_from to uv_from + uv_size (a 2x2 texture's pixel
## centres are at 0.25 and 0.75, so 0.25..0.75 blends corner to corner).
static func uvs(points: PackedVector2Array, rect: Rect2, uv_from: float, uv_size: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(Vector2(uv_from, uv_from) + (p - rect.position) / rect.size * uv_size)
	return result
