extends "res://tests/parts_revision_ui_runner.gd"

func setup_service(region: int, upgrades: int = 0) -> void:
	screen.campaign = Campaign.new()
	screen.campaign.start("single", 731042)
	screen.campaign.s.region = region
	var room: Dictionary = screen.campaign.current_nodes().filter(func(n): return n.get("workshop", false))[0]
	screen.campaign.s.node = room.id
	screen.campaign.s.floor = room.floor
	screen.campaign.s.phase = "supply"
	screen.campaign.s.bag_upgrades = upgrades
	screen.model = screen.campaign.model
	screen.model.s.bag_upgrades = upgrades
	screen.page = "run"
	screen.debug_session = true
	screen.redraw()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/bag_growth/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1440, 630)]:
		root.size = resolution
		screen._open_preparation(false)
		await settle()

		for id in Ammo.OUTFITS: bounds("outfit_select_" + id)
		await capture("starting_bags_%d" % resolution.x)
		await tap("outfit_select_work")
		await setup_service(0)
		for id in ["press", "trim", "core", "bag"]: bounds("city_workshop_" + id)
		check(not screen.main_scroll.get_h_scroll_bar().visible, "four services fit width")
		await capture("workshop_%d" % resolution.x)
		await tap("city_workshop_bag")
		check(screen.campaign.s.resolved and Ammo.hand_capacity(screen.model.s) == 6, "public workshop grows exactly one")
		check(not screen.campaign.resolve("core"), "growth spends service choice")
		await setup_service(0, 1)
		check(screen.find_child("city_workshop_bag", true, false).disabled, "region cap disclosed and disabled")
		await capture("regional_cap_%d" % resolution.x)
		screen._debug_city("gate")
		await settle()
		for id in ["slot", "compress", "credits", "bag"]: bounds("city_gate_" + id)
		await capture("gate_%d" % resolution.x)
		await tap("city_gate_bag")
		check(screen.campaign.s.phase == "map" and screen.campaign.s.region == 1 and screen.campaign.s.bag_upgrades == 1 and screen.campaign.s.slots == 0, "gate applies bag instead of slot")
		await setup_service(4, 5)
		check(screen.find_child("city_workshop_bag", true, false).disabled, "absolute maximum disables growth")
		await capture("maximum_%d" % resolution.x)
		screen.campaign.s.phase = "combat"
		screen.model.s.deck = ["charge", "precise", "pierce", "bore", "arc", "push", "cool", "shatter", "bypass", "detonate"]
		screen.model.begin_encounter()
		screen.hand_layout_key = ""
		screen.redraw()
		await settle()
		fit()
		check(screen.model.s.hand.size() == 10, "ten cards in hand")
		await tap("hand_next")
		var late: Array = []
		for b in screen.find_child("AmmoGrid", true, false).get_children():
			if b.visible and b.name != "load_basic": late.append(str(b.name))
		check(late.size() == 4, "all four remaining candidates accessible")
		await tap(late.back())
		check(screen.model.s.plan.size() == 1, "last-page candidate loads")
		await capture("ten_cards_%d" % resolution.x)
	check(not screen.save_enabled, "isolated saves")
	screen.queue_free()
	await process_frame
	print("BAG GROWTH UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
