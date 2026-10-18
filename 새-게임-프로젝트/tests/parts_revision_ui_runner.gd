extends "res://tests/ammo_grade_ui_runner.gd"
const PartCard = preload("res://redesign/part_card_view.gd")
const PartFeedback = preload("res://redesign/part_feedback.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/parts_revision/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	# Developer samples are reachable by real input and keep the personal save untouched.
	await tap("dev")
	await tap("debug_parts_ordinary")
	check(screen.debug_session and screen.model.s.equipped_parts.has("ordinary_chain"), "public ordinary build sample")
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1440, 630)]:
		root.size = resolution
		for kind in ["ordinary", "compressed", "burn"]:
			screen._debug_part_build(kind)
			await settle()
			cards_fit()
			var order: Array = ["charge", "precise", "pierce"] if kind == "ordinary" else (["shatter", "pierce_c"] if kind == "compressed" else ["bore", "precise", "chase"])
			for id in Ammo.loading_order(order): await tap("load_" + str(id))
			var part: String = "ordinary_chain" if kind == "ordinary" else ("compression_sink" if kind == "compressed" else "igniter")
			check(not PartFeedback.slots(screen.full_forecast, part).is_empty(), "preview exposes relevant part trigger")
			await capture("%s_plan_%d" % [kind, resolution.x])
			await tap("confirm")
			await tap("fire")
			check(screen.model.s.history.back().action == "fire", "real sample firing")
			var fired: Array = screen.model.s.history.back().detail.results
			check(fired.any(func(shot): return shot.get("part_effects", []).any(func(effect): return effect.id == part)), "actual sample part feedback")
			await capture("%s_fired_%d" % [kind, resolution.x])
		for id in ["ordinary_chain", "compression_sink", "overbore", "lens"]:
			screen._debug_city("shop")
			screen.campaign.s.parts = []
			screen.campaign.s.equipped_parts = []
			screen.model.s.equipped_parts = []
			screen.model.s.deck = ["charge", "precise", "pierce", "cool", "shatter", "pierce_c", "bore", "detonate", "push", "arc"]
			screen.campaign.s.offers = [{"id": "pierce", "type": "ammo", "price": 12, "sold": false}, {"id": id, "type": "part", "price": 30, "sold": false}, {"id": "reserve", "type": "part", "price": 30, "sold": false}]
			screen.campaign.s.shop_part_bought = false
			screen.campaign.s.credits = 100
			screen.redraw()
			await settle()
			await tap("city_part_info_1")
			bounds("city_compare_buy_1")
			check(not screen.main_scroll.get_v_scroll_bar().visible, "shop comparison keeps equipment visible " + id)
			await capture("shop_%s_%d" % [id, resolution.x])
			await tap("city_compare_buy_1")
			check(screen.campaign.s.parts.has(id) and screen.campaign.equipped_parts().has(id) and screen.campaign.s.credits == 70, "public purchase equips new or revised part")
			check(PartCard.COLORS.has(id), "part has own icon palette")
		# Full five-slot inventory: select, remove, then re-equip without changing the deck.
		screen._debug_city("deck")
		screen.campaign.s.parts = ["ordinary_chain", "compression_sink", "lens", "overbore", "reclaimer"]
		screen.campaign.s.equipped_parts = screen.campaign.s.parts.duplicate()
		screen.model.s.equipped_parts = screen.campaign.s.parts.duplicate()
		screen.city_ui.deck()
		await settle()
		await tap("equipped_part_detail_1")
		bounds("city_deck_equip_compression_sink")
		await capture("equipment_%d" % resolution.x)
		await tap("city_deck_equip_compression_sink")
		check(not screen.campaign.is_equipped("compression_sink"), "public remove revised module")
		await tap("city_part_select_compression_sink")
		await tap("city_deck_equip_compression_sink")
		check(screen.campaign.is_equipped("compression_sink"), "public re-equip revised module")
	check(not screen.save_enabled, "all UI tests use isolated saves")
	screen.queue_free()
	await process_frame
	print("PARTS REVISION UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
