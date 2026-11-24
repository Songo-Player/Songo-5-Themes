extends Control
## Aurora's top bar, 72 pixels tall. On the main menu (MenuBar): the star at
## the left, the clock in a pill in the middle and the status in a pill at
## the right. Everywhere else (PageBar): one long pill with the page's name,
## then the clock and the status.

const P = preload("../assets/palette.gd")

var _battery_thread: Thread
var _level := -1
var _charging := false
var _connected := false

func _ready() -> void:
	_connected = DeviceOS.network_connected
	DeviceOS.network_status_checked.connect(func(connected): _connected = connected; _update_status())
	ThemeManager.theme_settings_updated.connect(_update_page)
	Controller.page_changed.connect(_update_page)
	_update_page()
	_refresh()

func _on_main_menu() -> bool:
	return Controller.nav_label.size() <= 1 and not Controller.is_song_view(Controller.active_container)

func _update_page() -> void:
	var main_menu := _on_main_menu()
	%MenuBar.visible = main_menu
	%PageBar.visible = not main_menu
	%Title.text = "Now Playing" if Controller.is_song_view(Controller.active_container) else (str(Controller.nav_label.back()) if Controller.nav_label.size() > 1 else "")
	%ClockPill.visible = P.show_clock()
	%PageClock.visible = P.show_clock()
	_update_clock()
	_update_status()

func _update_clock() -> void:
	%MenuClock.text = P.clock_text()
	%PageClock.text = P.clock_text()

func _update_status() -> void:
	%MenuStatus.show_status(_level, _charging, _connected)
	%PageStatus.show_status(_level, _charging, _connected)

func _on_timer_timeout() -> void:
	_refresh()

func _refresh() -> void:
	_update_clock()
	if DeviceOS.battery_info_path == "": return
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
	_level = int(capacity) if known else -1
	_charging = known and str(status).to_lower() == "charging"
	_update_status()

func _exit_tree() -> void:
	if _battery_thread and _battery_thread.is_started():
		_battery_thread.wait_to_finish()
