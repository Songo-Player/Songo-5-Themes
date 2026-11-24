extends MarginContainer
## Top strip: the app's name with the theme's beside it, then the wire
## (network), the battery and the time.

const P = preload("../assets/palette.gd")

var _battery_thread: Thread

func _ready() -> void:
	_show_network_status(DeviceOS.network_connected)
	DeviceOS.network_status_checked.connect(_show_network_status)
	_apply_settings()
	ThemeManager.theme_settings_updated.connect(_apply_settings)
	_update_widgets()

func _apply_settings() -> void:
	%Gem.gem_color = P.accent()
	_update_widgets()

func _on_timer_timeout() -> void:
	_update_widgets()

func _update_widgets() -> void:
	var now := Time.get_datetime_dict_from_system()
	%Clock.text = P.clock_text(now.hour, now.minute)
	if DeviceOS.battery_info_path != "":
		_update_battery_async()
	else:
		%BatteryLabel.text = "BATT --"

# Songo checks for internet once after boot (see DeviceOS.network_status_checked)
func _show_network_status(connected: bool) -> void:
	%NetLabel.visible = connected
	%Sep.visible = connected

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
	if _battery_thread.is_started(): _battery_thread.wait_to_finish()
	# The battery script prints nothing when the device has no battery.
	if str(capacity) == "":
		%BatteryLabel.text = "BATT --"
		return
	var charging := str(status).to_lower() == "charging"
	%BatteryLabel.text = ("CHARGING %s%%" if charging else "BATT %s%%") % str(capacity)
	if int(capacity) < 20 and not charging:
		%BatteryLabel.add_theme_color_override("font_color", P.accent_ink())
	else:
		%BatteryLabel.remove_theme_color_override("font_color")

func _exit_tree() -> void:
	if _battery_thread and _battery_thread.is_started():
		_battery_thread.wait_to_finish()
