extends MarginContainer

var _battery_thread: Thread

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_show_network_status(DeviceOS.network_connected)
	DeviceOS.network_status_checked.connect(_show_network_status)
	_update_widgets()
	_apply_accent_color()
	ThemeManager.theme_settings_updated.connect(_apply_accent_color)

func _apply_accent_color() -> void:
	var accent = Color(ThemeManager.settings["accent_color"])
	for node in [%NetworkConnection, %CurrentOsTimeContainer, %BatteryPercentContainer]:
		var style = node.get_theme_stylebox("panel")
		if style: style.bg_color = accent

func _on_timer_timeout() -> void:
	_update_widgets()

func _update_widgets():
	update_time()
	if DeviceOS.battery_info_path != "":
		update_battery_async()
	else:
		%BatteryPercent.text = "N/A*"
		
func update_battery_async() -> void:
	# Still reading from the last refresh, it gets joined in _update_battery_ui.
	if _battery_thread and _battery_thread.is_started(): return
	_battery_thread = Thread.new()
	_battery_thread.start(_thread_get_battery)
	
func _thread_get_battery():
	var capacity = DeviceOS.get_battery_info('capacity')
	var status = DeviceOS.get_battery_info('status')
	call_deferred("_update_battery_ui", capacity, status)
	
func _update_battery_ui(capacity, status) -> void:
	if _battery_thread.is_started(): _battery_thread.wait_to_finish()
	# The battery script prints nothing when the device has no battery.
	if capacity == "":
		%BatteryPercent.text = "N/A*"
		return
	%BatteryPercent.text = str(capacity)+"%"
	if int(capacity) >= 90: 
		%BatteryIcon.texture = preload("../assets/battery-full.svg")
	elif int(capacity) >= 70:
		%BatteryIcon.texture = preload("../assets/battery-threequarters.svg")
	elif int(capacity) >= 45:
		%BatteryIcon.texture = preload("../assets/battery-half.svg")
	elif int(capacity) >= 20:
		%BatteryIcon.texture = preload("../assets/battery-quarter.svg")
	else:
		%BatteryIcon.texture = preload("../assets/battery.svg")
	
	#if status.to_lower() == "charging":

func get_time_string() -> String:
	var now = Time.get_datetime_dict_from_system()
	var hour_12 = now.hour % 12
	if hour_12 == 0: hour_12 = 12
	var hour = str(hour_12)
	if ThemeManager.settings["clock_24_hour"]: hour = now.hour
	var minute = str(now.minute).pad_zeros(2)
	return "%s:%s" % [hour, minute]

func update_time():
	%CurrentOsTimeLabel.text = get_time_string()
	
# Songo checks for internet once after boot (see DeviceOS.network_status_checked)
func _show_network_status(connected: bool) -> void:
	%NetworkConnection.visible = connected

func _exit_tree() -> void:
	if _battery_thread and _battery_thread.is_started():
		_battery_thread.wait_to_finish()
