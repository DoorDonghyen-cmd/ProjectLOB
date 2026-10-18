extends "res://tests/ammo_expansion_ui_runner.gd"
const Forecast = preload("res://redesign/forecast.gd")

func press_without_wait(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "responsive input " + key)
	if button == null or button.disabled: return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/heat_builds/"):
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
		await combat(["charge_hot", "thermal", "vent", "cool", "pierce"])
		screen.model.s.equipped_parts = ["ember_core"]
		screen.redraw()
		await settle()
		for id in Ammo.loading_order(["charge_hot", "thermal", "vent"]): await tap("load_" + id)
		check(screen.model.s.plan == ["charge_hot", "thermal", "vent"], "anchored vent inserts correctly through public buttons")
		check(screen.full_forecast.shots[1].thermal_bonus == 4 and screen.full_forecast.shots[2].vent_bonus == 8, "visible forecast applies both new bullets")
		var gauge := screen.find_child("HeatGauge", true, false)
		check(gauge.limit == 10 and gauge.threshold == 5, "equipped core updates gauge and hot marker")
		fit()
		for button in screen.find_child("AmmoGrid", true, false).get_children():
			for child in button.get_children():
				if child is Card and child.ammo_id in ["vent", "thermal"]:
					check(child.FONT.get_string_size(child.effect_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= child.size.x - 20, "new conditional card footer fits " + child.ammo_id)
		await capture("thermal_combo_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		check(screen.battle_view.heat_debt == screen.model.s.heat, "thermal conversion animation temperature settles exactly")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "thermal combo animation matches damage")
		await combat(["pierce", "cool"])
		screen.model.s.equipped_parts = ["reclaimer"]
		screen.model.s.heat = 10
		screen.model.s.enemies[0].hp = 5
		screen.model.s.enemies[0].def = 0
		screen.redraw()
		await settle()
		for id in Ammo.loading_order(["pierce", "cool"]): await tap("load_" + id)
		check(screen.full_forecast.shots[0].kill_cooled == 2 and screen.full_forecast.heat.forced_probability == 0, "public kill saves the planned chain")
		await capture("kill_cooling_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		check(screen.battle_view.heat_debt == screen.model.s.heat, "kill cooling animation uses final temperature")
		check(screen.last_presentation.events.any(func(e): return e.kind == "kill_cooling"), "kill cooling feedback occurs on impact")
	# Worst-case eight-round exact preview runs off the UI thread.
	root.size = Vector2i(1008, 630)
	await settle()
	var ids: Array = ["charge_hot", "thermal", "cool", "shatter", "bore", "vent"]
	await combat(ids, "scatter")
	screen.model.s.capacity_bonus = 2
	screen.model.s.equipped_parts = ["supply", "radiator", "ember_core"]
	screen.model.s.enemies = []
	for i in range(4): screen.model.s.enemies.append(Data._enemy(["wall", 40, 4, 1, 26 + 2 * i]))
	screen.model.assign_opening_lanes()
	screen.model.s.encounter_total = 4
	screen.model.s.deployed = 4
	for id in Ammo.loading_order(["charge_hot", "thermal", "cool", "shatter", "bore", "basic", "basic", "vent"]): check(screen.model.load_round(id), "eight legal slots")
	var start := Time.get_ticks_usec()
	screen.redraw()
	var redraw_ms := float(Time.get_ticks_usec() - start) / 1000.0
	check(screen.forecast_pending and screen.find_child("confirm", true, false).disabled, "pending exact preview cannot be mistaken for ready")
	check(screen.magazine_view.forecast.is_empty(), "pending preview hides stale round outcomes")
	for i in range(3): await process_frame
	await press_without_wait("undo")
	await process_frame
	check(screen.model.s.plan.size() == 7, "undo accepted while exact worker is running")
	var frames := 0
	var prediction_start := Time.get_ticks_msec()
	while screen.forecast_pending and Time.get_ticks_msec() - prediction_start < 20000:
		frames += 1
		await process_frame
	check(not screen.forecast_pending and frames > 0, "render frames continue until exact result arrives")
	check(screen.full_forecast.shots.size() == 7, "old eight-round result never replaces new seven-round request")
	check(screen.full_forecast == Forecast.analyze(screen.model.s, true, true), "async result equals synchronous exact forecast")
	check(not screen.find_child("confirm", true, false).disabled, "confirm enabled after exact result")
	await capture("responsive_scatter")
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("responsiveness.json"), FileAccess.WRITE).store_string(JSON.stringify({"redraw_ms": redraw_ms, "prediction_wait_ms": Time.get_ticks_msec() - prediction_start, "rendered_frames_during_calculation": frames, "latest_shots": screen.full_forecast.shots.size()}, "\t"))
	# A result arriving while reading a workspace must not close that workspace.
	check(screen.model.load_round("charge_hot"), "restore eighth round for workspace test")
	screen.redraw()
	check(screen.forecast_pending, "new workspace test calculation starts")
	screen._workspace("예측 중 빌드 확인")
	var overlay = screen.workspace_overlay
	var workspace_deadline := Time.get_ticks_msec() + 20000
	while not screen.forecast_refresh_waiting and Time.get_ticks_msec() < workspace_deadline: await process_frame
	check(screen.forecast_refresh_waiting and is_instance_valid(overlay) and overlay.is_visible_in_tree(), "worker result preserves open workspace")
	await press_without_wait("workspace_close")
	await settle()
	check(not screen.forecast_pending and screen.full_forecast.shots.size() == 8, "closing workspace applies completed latest result")
	# Leaving combat cancels work and does not reopen the battle later.
	check(screen.model.remove_planned(7), "edit before leaving battle")
	screen.redraw()
	screen._to_menu()
	await settle()
	check(screen.page == "menu" and not screen.forecast_pending, "menu navigation cancels pending preview")
	# Purchase actual rotating stock, then remove/re-equip through the build screen.
	screen._debug_city("shop")
	screen.campaign.s.region = 1
	screen.campaign.s.floor = 4
	screen.campaign.s.node = 10401
	screen.campaign.s.credits = 1000
	screen.campaign._stock_shop(screen.campaign.node())
	screen.redraw()
	await settle()
	var bought: Array = []
	for revision in range(28):
		for index in range(screen.campaign.s.offers.size()):
			var offer: Dictionary = screen.campaign.s.offers[index]
			if offer.id not in ["vent", "thermal", "radiator", "reclaimer", "ember_core"] or bought.has(offer.id): continue
			await tap(("city_offer_compare_" if offer.type == "ammo" else "city_part_info_") + str(index))
			await capture("shop_" + str(offer.id))
			await tap("city_compare_buy_" + str(index))
			bought.append(str(offer.id))
		if bought.size() == 5: break
		await tap("city_reroll")
	check(bought.size() == 5, "all thermal content visible and purchasable")
	await tap("city_deck")
	var equipped: Array = screen.campaign.equipped_parts()
	await tap("equipped_part_detail_" + str(equipped.find("radiator")))
	check(screen.find_child("PartChangePreview", true, false).text.contains("열 한계"), "equipment displays actual limit delta before applying")
	await capture("equipment_thermal_compare")
	var old_limit := Ammo.heat_limit(screen.model.s)
	await tap("city_deck_equip_radiator")
	check(Ammo.heat_limit(screen.model.s) == old_limit - 3, "public unequip removes capacity")
	await tap("city_part_select_radiator")
	await tap("city_deck_equip_radiator")
	check(Ammo.heat_limit(screen.model.s) == old_limit, "public re-equip restores capacity")
	await capture("equipment_thermal_set")
	screen._close_workspace()
	# Worker shutdown while a calculation exists must join without touching freed nodes.
	screen.queue_free()
	await process_frame
	print("HEAT BUILDS UI COMPLETE checks=%d failures=%d redraw_ms=%.2f frames=%d" % [checks, failures, redraw_ms, frames])
	quit(0 if failures == 0 else 1)
