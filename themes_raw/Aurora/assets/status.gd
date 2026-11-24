extends HBoxContainer
## The status glyphs, as Aurora shows them in its header: the wifi mark when
## Songo is online, the battery percentage (a setting) and the battery.
## Hidden on devices without a battery.

const P = preload("palette.gd")

func show_status(level: int, charging: bool, connected: bool) -> void:
	%Wifi.visible = connected
	var known := level >= 0
	%Battery.visible = known
	%Percent.visible = known and P.show_battery_percentage()
	if known:
		%Battery.level = level
		%Battery.charging = charging
		%Percent.text = "%d%%" % level
