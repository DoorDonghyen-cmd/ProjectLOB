extends "res://tests/ammo_expansion_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/decision_revision/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		await settle()
		await combat(["charge", "precise", "pierce", "bore", "arc", "push"])
		fit()
		var grid := screen.find_child("AmmoGrid", true, false)
		check(grid.columns == 7 and grid.get_children().all(func(card): return card.visible), "all six starter candidates visible beside basic")
		await capture("choices_%d" % resolution.x)
		await combat(["charge", "precise", "pierce", "bore", "arc", "push", "cool", "thermal", "bypass", "shatter"], "scatter")
		screen.model.s.capacity_bonus = 2
		screen.model.s.equipped_parts = ["supply"]
		screen.redraw()
		await settle()
		fit()
		check(not screen.find_child("load_shatter", true, false).is_visible_in_tree(), "second page starts hidden")
		await tap("hand_next")
		check(screen.find_child("load_shatter", true, false).is_visible_in_tree(), "tenth candidate reachable through visible next button")
		check(screen.find_child("HandPageNumber", true, false).text == "2/2", "visible candidate page count")
		await tap("load_shatter")
		check(screen.model.s.plan == ["shatter"] and screen.hand_page == 1, "late candidate loads with LIFO and preserves page")
		await capture("expanded_hand_%d" % resolution.x)
		await tap("hand_previous")
		await tap("load_pierce")
		check(screen.model.s.plan == ["pierce", "shatter"], "page navigation changes neither input order nor queued rounds")
		fit()
		await combat(["bore", "arc", "pierce", "cool", "push", "thermal"], "heavy", true)
		screen.model.s.heat = 10
		screen.redraw()
		await settle()
		for id in Ammo.loading_order(["cool", "pierce", "bore"]): await tap("load_" + id)
		check(screen.find_child("ConfirmCost", true, false).text.contains("열 6"), "carried heat shown before confirmation")
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.heat == 12, "safe hot volley ends at twelve")
		check(screen.find_child("reload", true, false).text.contains("열 6"), "reload button shows remaining heat")
		await capture("hot_reload_%d" % resolution.x)
		await tap("reload")
		check(screen.model.s.heat == 6 and screen.find_child("HeatGauge", true, false).current == 6, "normal reload carries heat into plan and gauge")
		check(screen.battle_view.heat_debt == 6, "weapon visual retains actual heat")
		check(screen.model.s.hand.size() == 6, "new full hand after reload")
		fit()
		await capture("cycled_hot_hand_%d" % resolution.x)
	root.size = Vector2i(1008, 630)
	screen.preferences.data.text_scale = 1.1
	await combat(["charge", "precise", "pierce", "bore", "arc", "push", "cool", "thermal"], "scatter")
	screen.model.s.capacity_bonus = 1
	screen.redraw()
	await settle()
	await tap("hand_next")
	fit()
	await capture("expanded_large_text")
	screen.preferences.data.text_scale = 1.0
	screen.page = "loadout"
	screen.selected_weapon_id = "heavy"
	screen.redraw()
	await settle()
	check(not screen.main_scroll.get_h_scroll_bar().visible, "weapon heat and cooling metrics do not overflow horizontally")
	await capture("weapon_cooling")
	print("DECISION REVISION UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
