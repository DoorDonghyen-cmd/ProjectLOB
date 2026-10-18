extends "res://tests/ammo_expansion_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/build_synergy/"):
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
		await combat(["prepare", "disrupt", "spread", "sequence", "bore", "pierce"])
		screen.model.s.equipped_parts = ["indexer", "chain_sink"]
		screen.redraw()
		await settle()
		fit()
		for card in screen.find_children("CardInfo", "Control", true, false):
			if card is Card:
				check(card.FONT.get_string_size(card.effect_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= card.size.x - 20, "new role footer readable: " + card.ammo_id)
		await capture("new_roles_%d" % resolution.x)
		for id in Ammo.loading_order(["prepare", "bore", "pierce", "sequence"]): await tap("load_" + id)
		check(screen.full_forecast.shots[0].prepared_rounds == ["bore", "pierce"], "reservation preview uses indexer and trailing slots")
		check(screen.full_forecast.shots[2].chain_cooled == 3 and screen.full_forecast.shots[3].sequence_bonus == 6, "chain part and varied magazine forecast")
		await capture("prepared_chain_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.prepared == ["bore", "pierce"], "real shot earns public reservation")
		var reservation = screen.find_child("ReservationStatus", true, false)
		check(reservation != null and reservation.is_visible_in_tree() and reservation.text.contains("소이탄 / 철갑탄"), "earned reservation is visible with actual names")
		check(Rect2(Vector2.ZERO, screen.get_viewport_rect().size).encloses(reservation.get_global_rect()), "reserved hand promise stays on screen")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "new bullet and part presentation ends at model state")
		await capture("reservation_earned_%d" % resolution.x)
		await tap("reload")
		check(screen.model.s.hand.slice(0, 2) == ["bore", "pierce"], "public reload brings reserved cards first")
		fit()
		await combat(["disrupt", "bore", "spread", "pierce"], "amplifier", true)
		screen.model.s.enemies.reverse()
		screen.model.s.enemies[0].distance = 18
		screen.model.s.enemies[0].hp = 30
		screen.model.s.enemies[0].max_hp = 30
		screen.model.assign_opening_lanes()
		screen.redraw()
		await settle()
		await tap("load_disrupt")
		check(screen.full_forecast.shots[0].interrupted == 2, "amplifier doubles useful interruption duration")
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.enemies[0].jammed == 1 and screen.model.s.projectiles.is_empty(), "remaining interrupted turn after real fire")
		await capture("interrupted_%d" % resolution.x)
		await combat(["bore", "spread", "detonate", "cool"], "heavy")
		for id in Ammo.loading_order(["bore", "spread"]): await tap("load_" + id)
		check(screen.full_forecast.shots[1].transferred == 2, "transfer forecast distinct from instant damage")
		await tap("confirm")
		await tap("fire")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "source and recipient burn stay in sync")
		await capture("spread_%d" % resolution.x)
	# Real shop generation and purchase, including the three new parts.
	root.size = Vector2i(1008, 630)
	screen._debug_city("shop")
	screen.campaign.s.region = 1
	screen.campaign.s.floor = 4
	screen.campaign.s.node = 10401
	screen.campaign.s.credits = 2000
	screen.campaign._stock_shop(screen.campaign.node())
	screen.redraw()
	await settle()
	var bought: Array = []
	for revision in range(36):
		for index in range(screen.campaign.s.offers.size()):
			var offer: Dictionary = screen.campaign.s.offers[index]
			if offer.id not in ["prepare", "disrupt", "spread", "sequence", "cooling_breech", "chain_sink", "indexer"] or bought.has(offer.id): continue
			await tap(("city_offer_compare_" if offer.type == "ammo" else "city_part_info_") + str(index))
			await capture("shop_" + str(offer.id))
			await tap("city_compare_buy_" + str(index))
			bought.append(str(offer.id))
		if bought.size() == 7: break
		await tap("city_reroll")
	check(bought.size() == 7, "new ammunition and parts purchasable from rotating shop")
	await tap("city_deck")
	var equipped: Array = screen.campaign.equipped_parts()
	if equipped.has("cooling_breech"): await tap("equipped_part_detail_" + str(equipped.find("cooling_breech")))
	else: await tap("city_part_select_cooling_breech")
	var preview = screen.find_child("PartChangePreview", true, false)
	check(preview != null and preview.text.contains("재장전 냉각") and preview.text.contains("탄창"), "part choice exposes both slot and cooling tradeoff")
	await capture("equipment_tradeoff")
	await tap("city_deck_equip_cooling_breech")
	check(Ammo.has_part(screen.model.s, "cooling_breech") != equipped.has("cooling_breech"), "public part toggle changes actual weapon configuration")
	await tap("workspace_close")
	# Long random magazine remains asynchronous and public probabilities stay honest.
	await combat(["prepare", "disrupt", "spread", "sequence", "bore", "cool"], "scatter", true)
	screen.model.s.capacity_bonus = 2
	screen.model.s.equipped_parts = ["supply", "chain_sink", "indexer", "radiator"]
	for id in Ammo.loading_order(["prepare", "bore", "spread", "cool", "disrupt", "basic", "basic", "sequence"]): check(screen.model.load_round(id), "eight-slot legal new-role plan")
	var started := Time.get_ticks_msec()
	screen.redraw()
	check(screen.forecast_pending, "large scatter computation runs off main thread")
	while screen.forecast_pending and Time.get_ticks_msec() - started < 20000: await process_frame
	check(not screen.forecast_pending, "new branch state calculation completes")
	print("BUILD SYNERGY SCATTER FORECAST elapsed_ms=%d" % (Time.get_ticks_msec() - started))
	fit()
	await capture("scatter_eight_slots")
	screen.queue_free()
	await process_frame
	print("BUILD SYNERGY UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
