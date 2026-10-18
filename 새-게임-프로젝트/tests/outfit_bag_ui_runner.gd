extends "res://tests/parts_revision_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/outfit_bag/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	await tap("new_run_setup")
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1440, 630)]:
		root.size = resolution
		for outfit in Ammo.OUTFITS:
			screen._open_preparation(false)
			await settle()

			for id in Ammo.OUTFITS: bounds("outfit_select_" + id)
			await capture("outfits_%s_%d" % [outfit, resolution.x])
			await tap("outfit_select_" + outfit)
			check(screen.selected_outfit_id == outfit and not is_instance_valid(screen.workspace_overlay), "selection returns to preparation")
			bounds("OutfitSelection")
			bounds("start_single")
			await capture("preparation_%s_%d" % [outfit, resolution.x])
			await tap("start_single")
			check(screen.campaign.s.outfit == outfit and screen.model.s.outfit == outfit, "public departure applies outfit")
			# Enter an isolated combat and give a legal diverse deck to exercise page two.
			var entry: Dictionary = screen.campaign.current_nodes().filter(func(n): return n.floor == 1)[0]
			check(screen.campaign.enter(int(entry.id)), "enter real route battle")
			screen.model.s.deck = ["charge", "precise", "pierce", "bore", "arc", "push", "cool", "shatter", "bypass", "detonate"]
			screen.model.begin_encounter()
			screen.redraw()
			await settle()
			check(screen.model.s.hand.size() == Ammo.OUTFITS[outfit].hand, "visible outfit hand")
			check(screen.find_child("exchange", true, false).disabled == (outfit == "carrier"), "carrier exchange disabled honestly")
			fit()
			if Ammo.hand_capacity(screen.model.s) > 6:
				bounds("hand_next")
				await tap("hand_next")
				check(screen.hand_page == 1, "seventh distinct candidate reachable")
				var grid = screen.find_child("AmmoGrid", true, false)
				var late: Array = grid.get_children().filter(func(b): return b.visible and b.name != "load_basic")
				check(late.size() == 1, "one candidate on second page")
				await tap(str(late[0].name))
				check(screen.model.s.plan.size() == 1, "seventh candidate loads")
			await capture("combat_%s_%d" % [outfit, resolution.x])
			screen.city_ui.deck()
			await settle()
			bounds("workspace_close")
			await capture("build_%s_%d" % [outfit, resolution.x])
			await tap("workspace_close")
	check(not screen.save_enabled, "isolated UI never writes personal save")
	screen.queue_free()
	await process_frame
	print("OUTFIT BAG UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
