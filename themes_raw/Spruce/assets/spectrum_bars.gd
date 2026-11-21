extends Control
## A small bar visualizer: log-spaced bands from the engine's spectrum,
## smoothed and drawn bottom up as rounded bars. (After the Departures
## theme's, which follows SongoClassic's MusicVisualizer.)

const P = preload("palette.gd")

const BAR_WIDTH := 5.0
const BAR_GAP := 3.0
const MIN_HZ := 20.0
const MAX_HZ := 16000.0
const DB_FLOOR := 60.0  # energy below -60 dB draws as an empty bar
const SMOOTHING := 0.25

@export var bar_color := P.YELLOW
## Stacks the bands top to bottom (bass at the bottom), each bar growing
## leftward from the right edge, to run down the side of the album art.
@export var vertical := false
## With vertical, grows the bars rightward from the left edge instead, for
## the copy on the art's right side.
@export var mirror := false

var spectrum
var levels := PackedFloat32Array()

func _ready() -> void:
	spectrum = SongoPlayer.get_spectrum()

func _process(_delta: float) -> void:
	if is_visible_in_tree() and not DeviceOS.sleeping:
		queue_redraw()

func _draw() -> void:
	# Bands run along the length; each bar's height grows across the depth.
	var length := size.y if vertical else size.x
	var depth := size.x if vertical else size.y
	var count := int((length + BAR_GAP) / (BAR_WIDTH + BAR_GAP))
	if count <= 0: return
	if levels.size() != count:
		levels.resize(count)
		levels.fill(0.0)
	var playing: bool = spectrum != null and SongoPlayer.is_playing()
	var style := StyleBoxFlat.new()
	style.bg_color = bar_color
	style.set_corner_radius_all(int(BAR_WIDTH / 2))
	# Centre the bars along the length so both ends get the same margin.
	var start := floorf((length - (count * (BAR_WIDTH + BAR_GAP) - BAR_GAP)) / 2.0)
	for i in count:
		var energy := 0.0
		if playing:
			var low := MIN_HZ * pow(MAX_HZ / MIN_HZ, float(i) / count)
			var high := MIN_HZ * pow(MAX_HZ / MIN_HZ, float(i + 1) / count)
			var magnitude: float = spectrum.get_magnitude_for_frequency_range(low, high).length()
			energy = clampf((linear_to_db(magnitude) + DB_FLOOR) / DB_FLOOR, 0.0, 1.0)
		levels[i] = lerpf(levels[i], energy, SMOOTHING)
		# Always at least a dot, so the row reads as a visualizer when quiet.
		var bar := maxf(BAR_WIDTH, roundf(levels[i] * depth))
		var along := start + i * (BAR_WIDTH + BAR_GAP)
		if vertical:
			var y := size.y - along - BAR_WIDTH
			draw_style_box(style, Rect2(0.0 if mirror else size.x - bar, y, bar, BAR_WIDTH))
		else:
			draw_style_box(style, Rect2(along, size.y - bar, BAR_WIDTH, bar))
