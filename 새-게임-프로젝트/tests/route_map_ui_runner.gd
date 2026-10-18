extends "res://tests/story_flow_runner.gd"

func fixture_for(role: String):
	var c = Campaign.new()
	c.start("burst", 17)
	c.advance_departure(true)
	var rooms: Array = c.current_nodes()
	var wanted: Dictionary = {}
	for room in rooms:
		if Data.room_kind(room) == role:
			wanted = room
			break
	var path: Array = [wanted]
	while int(path[0].floor) > 1:
		for previous in rooms:
			if previous.next.has(path[0].id):
				path.push_front(previous)
				break
	for room in path:
		check(c.enter(int(room.id)), "fixture follows graph")
		if int(room.id) == int(wanted.id): break
		match str(c.s.phase):
			"combat":
				for enemy in c.model.s.enemies: enemy.hp = 0
				c.model.s.reinforcements = []
				c.model.s.phase = "reward"
				c.sync_combat()
				c.reward("credits")
			"supply", "event": c.resolve("skip"); c.leave()
			_: c.leave()
	return c

func show_campaign(c) -> void:
	screen.campaign = c
	screen.model = c.model
	screen.page = "run"
	screen.debug_session = true
	screen.redraw()
	await settle()

func check_map_fill() -> void:
	var sheet: Control = screen.find_child("MapRouteSheet", true, false)
	var map_scroll: Control = screen.find_child("MapScroll", true, false)
	check(absf(sheet.get_global_rect().end.y - screen.body.get_global_rect().end.y) < 2.0, "destination strip fills body to safe bottom margin")
	check(map_scroll.get_global_rect().end.y <= sheet.get_global_rect().position.y, "expanded map does not overlap destination controls")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/maps/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	root.size = Vector2i(1280, 900)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	for dimensions in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = dimensions
		screen.preferences.data.text_scale = 1.1 if dimensions.x == 1008 else 1.0
		var c = Campaign.new()
		c.start("burst", 17)
		c.advance_departure(true)
		await show_campaign(c)
		var label := "%dx%d" % [dimensions.x, dimensions.y]
		await capture("map_" + label, "city_enter_101")
		check_map_fill()
		var map: Control = screen.find_child("CityMap", true, false)
		var scroll: Control = screen.find_child("MapScroll", true, false)
		check(scroll.get_global_rect().encloses(screen.find_child("map_node_101", true, false).get_global_rect()), "first available room visible on entry")
		for child in map.get_children():
			check(child.size.x >= 48 and child.size.y >= 48, "map target size")
			check(Rect2(Vector2.ZERO, map.size).encloses(child.get_rect()), "node inside map")
		await tap("map_node_104")
		check(screen.find_child("city_enter_104", true, false).visible, "fourth branch selection")
		await capture("selected_" + label, "city_enter_104")
		await tap("city_map_details")
		check(screen.find_child("FormationCount", true, false) != null and int(c.s.node) == 0, "optional details reveal formation without entering")
		await capture("optional_details_" + label)
		await tap("workspace_close")
		check(screen.find_child("city_enter_104", true, false).visible, "closing details retains selected destination")
		var future: Dictionary = c.current_nodes().filter(func(n): return n.kind == "shop")[0]
		await tap("map_node_" + str(future.id))
		check(not screen.find_child("city_enter_104", true, false).visible, "future preview cannot enter")
		await capture("future_" + label)
		await tap("map_node_104")
		await tap("city_enter_104")
		check(c.s.phase == "combat" and int(c.s.node) == 104, "touch enters selected branch")
		var workshop = fixture_for("workshop")
		await show_campaign(workshop)
		await capture("workshop_" + label)
		await tap("city_workshop_press")
		await capture("compression_choices_" + label)
		await tap("workspace_close")
		check(not workshop.s.resolved, "closing compression does not spend service")
		await tap("city_workshop_core")
		check(workshop.s.resolved and int(workshop.s.compressor_charges) == 2, "touch workshop recharge")
		await tap("city_leave")
		check(workshop.s.phase == "map", "workshop returns to map")
		await capture("traveled_" + label)
		check_map_fill()
		var current_marker = screen.find_child("map_node_" + str(workshop.s.node), true, false)
		check(current_marker.get_node("Status").text == "●", "current place has a shape marker distinct from selection")
		for facility in screen.find_child("CityMap", true, false).get_children():
			check(facility.get_node("Picture").texture != null, "facility image is loaded")
			check(facility.get_node("Picture").mouse_filter == Control.MOUSE_FILTER_IGNORE, "art does not intercept map touch")
		var elite = fixture_for("elite")
		for enemy in elite.model.s.enemies: enemy.hp = 0
		elite.model.s.reinforcements = []
		elite.model.s.phase = "reward"
		elite.sync_combat()
		var part := str(elite.part_rewards()[0])
		await show_campaign(elite)
		await capture("elite_reward_" + label)
		await tap("city_reward_" + part)
		check(elite.s.phase == "map" and elite.s.parts.has(part), "touch takes elite part")
	# Exercise both deck mutations through their explicit confirmation buttons.
	for operation in ["compress", "remove"]:
		var workshop = fixture_for("workshop")
		await show_campaign(workshop)
		var id := str(workshop.compressible_ids()[0]) if operation == "compress" else str(workshop.model.s.deck[0])
		var size_before: int = workshop.model.s.deck.size()
		await tap("city_workshop_press" if operation == "compress" else "city_workshop_trim")
		await tap("city_workshop_" + operation + "_" + id)
		check(workshop.s.resolved and workshop.model.s.deck.size() == size_before - 1, "confirmed " + operation + " changes deck once")
		roundtrip(workshop)
	# Deep region uses its own scroll, leaving the decision sheet available.
	var upper = Campaign.new()
	upper.start("single", 90210)
	upper.s.departure_step = 3
	upper.s.region = 4
	await show_campaign(upper)
	await capture("upper_region", "city_enter_40101")
	await tap("map_node_41002")
	await capture("upper_gate_preview")
	# Existing version-one saves still use two lanes with the same art/input.
	var legacy = Campaign.new()
	legacy.start("single", 17, 0, "balanced", 1)
	legacy.advance_departure(true)
	await show_campaign(legacy)
	await capture("legacy_map", "city_enter_101")
	await tap("map_node_102")
	check(screen.find_child("city_enter_102", true, false).visible, "legacy second lane remains selectable")
	await tap("city_enter_102")
	check(int(legacy.s.node) == 102, "legacy map art preserves entry")
	# Region treatment and motion settings share the same selectable graph.
	for region in range(5):
		var regional = Campaign.new()
		regional.start("single", 17)
		regional.advance_departure(true)
		regional.s.region = region
		screen.preferences.data.motion = ["normal", "fast", "instant"][region % 3]
		await show_campaign(regional)
		var room_id: int = int(regional.choices()[1].id)
		await tap("map_node_" + str(room_id))
		await capture("region_" + str(region), "city_enter_" + str(room_id))
		check_map_fill()
		var chart = screen.find_child("CityMap", true, false)
		check(chart.region_index == region, "region chart palette matches campaign")
		var facility = screen.find_child("map_node_" + str(room_id), true, false)
		if str(screen.preferences.data.motion) == "instant":
			check(facility.selection_feedback == null, "instant skips selection feedback")
		var depth_before: int = regional.s.visited.size()
		await tap("city_enter_" + str(room_id))
		check(regional.s.visited.size() == depth_before + 1 and int(regional.s.node) == room_id, "entry feedback preserves exactly one move")
		for frame in range(20): await process_frame
		check(screen.get_node_or_null("MapArrivalFeedback") == null, "entry feedback leaves no overlay")
	screen.preferences.data.motion = "normal"
	print("MAP UI COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
