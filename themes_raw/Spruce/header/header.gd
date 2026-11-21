extends MarginContainer
## spruce's top bar: the spruce tree on the left, the page's name in the
## middle (empty on the main menu, as in spruce), and the clock, wifi and
## battery on the right.

const P = preload("../assets/palette.gd")

var _battery_thread: Thread

func _ready() -> void:
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	Controller.page_changed.connect(_update_title)
	_update_title()
	_update_widgets()

func _apply_settings() -> void:
	%Clock.visible = P.show_clock()
	%BatteryLabel.visible = P.show_battery_percentage() and not %Battery.unknown
	_update_clock()

func _on_timer_timeout() -> void:
	_update_widgets()

func _update_widgets() -> void:
	_update_clock()
	_check_network()
	if DeviceOS.battery_info_path != "":
		_update_battery_async()
	else:
		_show_battery("", "")

func _update_clock() -> void:
	%Clock.text = P.clock_text()

func _update_title() -> void:
	var title := ""
	if Controller.is_song_view(Controller.active_container):
		title = "Now Playing"
	elif Controller.nav_label.size() > 1:
		title = str(Controller.nav_label.back())
	%Title.text = title

func _check_network() -> void:
	var checker := NetworkStatus.new()
	checker.status_checked.connect(func(connected): %Wifi.visible = connected)
	checker.is_connected_to_network()

func _update_battery_async() -> void:
	# Still reading from the last refresh; it's joined in _show_battery.
	if _battery_thread and _battery_thread.is_started(): return
	_battery_thread = Thread.new()
	_battery_thread.start(_read_battery)

func _read_battery() -> void:
	var capacity = DeviceOS.get_battery_info("capacity")
	var status = DeviceOS.get_battery_info("status")
	call_deferred("_show_battery", capacity, status)

func _show_battery(capacity, status) -> void:
	if _battery_thread and _battery_thread.is_started(): _battery_thread.wait_to_finish()
	# The battery script prints nothing when the device has no battery.
	var known := str(capacity).strip_edges() != ""
	%Battery.unknown = not known
	%BatteryLabel.visible = known and P.show_battery_percentage()
	if not known: return
	%Battery.level = int(capacity)
	%Battery.charging = str(status).to_lower() == "charging"
	%BatteryLabel.text = str(int(capacity))

func _exit_tree() -> void:
	if _battery_thread and _battery_thread.is_started():
		_battery_thread.wait_to_finish()
