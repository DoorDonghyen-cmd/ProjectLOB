extends "res://tests/route_map_ui_runner.gd"
var entry_checked := false

func show_campaign(c) -> void:
	if not entry_checked:
		entry_checked = true
		await tap("dev")
		await tap("debug_city_map")
		check(screen.debug_session and screen.find_child("CityMap", true, false).get_script() == load("res://redesign/city_map_chart_view.gd"), "developer entry uses production chart")
		check(int(screen.campaign.s.map_version) == 2, "chart uses current generated map")
	await super.show_campaign(c)
	# Exercise the normal player route, with writes still disabled by the suite.
	screen.debug_session = false
	screen.redraw()
	await settle()
	if str(c.s.phase) == "map":
		check(screen.find_child("CityMap", true, false).get_script() == load("res://redesign/city_map_chart_view.gd"), "normal play uses adopted chart without preview flag")
