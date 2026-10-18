extends "res://tests/place_revision_ui_runner.gd"

func layout_check(tag: String) -> void:
	fit_check()
	var footer := screen.find_child("PlaceFooter", true, false) as Control
	check(footer != null, tag + " has footer")
	if footer == null: return
	var bounds := footer.get_global_rect()
	check(bounds.end.y <= screen.size.y - 10, tag + " exit visible without scrolling " + str(bounds))
	check(not screen.main_scroll.get_v_scroll_bar().visible, tag + " default page fits " + str(screen.main_scroll.get_v_scroll_bar().max_value))
	var content := screen.find_child("PlaceContent", true, false) as Control
	check(content != null, tag + " coherent place composition")
	if content != null:
		var frame := content.get_global_rect()
		check(frame.size.x <= 1201, tag + " place stays bounded on wide displays")
		check(absf(frame.position.x - bounds.position.x) <= 1 and absf(frame.end.x - bounds.end.x) <= 1, tag + " exit shares content edges")
		var siblings := content.get_children()
		var previous := siblings[siblings.size() - 3] as Control
		check(bounds.position.y - previous.get_global_rect().end.y <= 40, tag + " exit stays next to the choices")
		for button in content.find_children("city_*", "Button", true, false):
			if button.is_visible_in_tree():
				check(button.size.x <= 321, tag + " action does not stretch " + str(button.name))
	for child in footer.get_children():
		if child is Button:
			check(child.size.y >= 52, tag + " footer touch height")
			check(child.size.y <= 54, tag + " footer label stays on one line")
	var grid := screen.find_child("WorkshopOperations", true, false) as GridContainer
	if grid != null:
		for start in [0, 2]:
			var a: Button = grid.get_child(start).find_children("city_*", "Button", true, false)[0]
			var b: Button = grid.get_child(start + 1).find_children("city_*", "Button", true, false)[0]
			check(absf(a.get_global_rect().end.y - b.get_global_rect().end.y) <= 1, tag + " operation baselines")
	var choices := screen.find_child("EncounterChoices", true, false) as Control
	if choices != null:
		var actions := choices.find_children("city_encounter_*", "Button", true, false)
		for button in actions:
			check(absf(button.get_global_rect().position.y - actions[0].get_global_rect().position.y) <= 1, tag + " encounter action tops align")
			check(button.size.y <= 54, tag + " encounter caption stays compact")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/place_layout/"): quit(2); return
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = true
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen.preferences.data.motion = "instant"
	for resolution in [Vector2i(1008,630), Vector2i(1280,800), Vector2i(1440,630)]:
		root.size = resolution
		var tag := str(resolution.x)
		for kind in ["workshop", "supply", "shop", "event"]:
			var c = fixture(kind)
			await present(c)
			layout_check(kind + tag)
			await capture(kind + "_" + tag)
			if kind == "workshop":
				await press("city_workshop_tune")
				await press("city_tune_select_0")
				var power := screen.find_child("city_tune_power", true, false) as Control
				var cool := screen.find_child("city_tune_cool", true, false) as Control
				check(absf(power.get_global_rect().end.y - cool.get_global_rect().end.y) <= 1, "tune actions align " + tag)
				await capture("tune_" + tag)
				await press("workspace_close")
				await press("city_workshop_press")
				await capture("compression_" + tag)
				await press("workspace_close")
				check(not c.s.resolved, "cancel subtools preserves operation")
			elif kind == "shop":
				for index in range(c.s.offers.size()):
					await press(("city_offer_compare_" if c.s.offers[index].type == "ammo" else "city_part_info_") + str(index))
					layout_check("shop offer %d %s" % [index, tag])
				await capture("shop_part_" + tag)
				await press("city_buy_compressor")
				check(c.s.compressor_charges == 2, "relocated charge works")
				layout_check("shop purchase " + tag)
				await capture("shop_purchase_" + tag)
				await press("city_shop_build")
				await press("workspace_close")
				await press("city_leave")
				check(c.s.phase == "map", "relocated exit works")
	# Result states and an actual revealed reward keep the same exit position.
	root.size = Vector2i(1280,800)
	for wanted in ["combat", "ammo"]:
		var c
		for seed_value in range(1,50):
			c = fixture("event", seed_value, "salvage")
			if c != null and Campaign.Encounters.outcome("salvage", "pull", seed_value, int(c.s.node)).type == wanted: break
		await present(c)
		await press("city_encounter_pull")
		layout_check("reveal " + wanted)
		await capture("reveal_" + wanted)
		await press("city_encounter_fight" if wanted == "combat" else "city_service_skip")
		if wanted == "combat": check(c.s.phase == "combat", "ambush action works")
		else:
			layout_check("resolved loot")
			await capture("result")
	# Public 110% text setting: preserve one-screen decisions and single-line nav.
	root.size = Vector2i(1008,630)
	screen.preferences.data.text_scale = 1.1
	for kind in ["workshop", "supply", "shop", "event"]:
		await present(fixture(kind))
		layout_check(kind + " large text")
		await capture(kind + "_large_text")
	for event_kind in ["siphon", "salvage"]:
		var encounter
		for seed_value in range(1, 50):
			encounter = fixture("event", seed_value, event_kind)
			if encounter != null: break
		check(encounter != null, "encounter fixture " + event_kind)
		if encounter == null: continue
		await present(encounter)
		layout_check(event_kind + " large text")
		await capture(event_kind + "_large_text")
	# A full, diverse deck uses a real scrolling workspace; swipe must not remove a card.
	var full = fixture("workshop")
	full.model.s.deck.clear()
	for family in Ammo.Variants.FAMILIES:
		for power in range(1,6):
			if full.model.s.deck.size() < 14: full.model.s.deck.append(Ammo.Variants.key(family,power))
	await present(full)
	await press("city_workshop_trim")
	await swipe_content(screen.find_child("WorkspaceScroll", true, false))
	check(full.model.s.deck.size() == 14, "touch drag does not remove ammunition")
	await capture("remove_scroll")
	await press("workspace_close")
	screen.preferences.data.text_scale = 1.0
	# Legacy saves retain the original service UI/operations.
	for kind in ["shop", "workshop", "supply"]:
		var old = fixture(kind,17,"",2)
		await present(old)
		check(not old.modern_places(), "legacy fixture")
		if kind == "shop": check(screen.find_child("city_shop_press",true,false) != null, "legacy paid compression")
		if kind == "workshop": check(screen.find_child("city_workshop_core",true,false) != null, "legacy core charge")
		await capture("legacy_" + kind)
	print("PLACE LAYOUT COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
