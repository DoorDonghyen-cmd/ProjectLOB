extends "res://tests/eavesback_ui_runner.gd"

func bounds(key: String) -> void:
	var node := screen.find_child(key, true, false) as Control
	check(node != null and node.is_visible_in_tree() and Rect2(Vector2.ZERO, screen.size).encloses(node.get_global_rect()), "visible bounds " + key)
	check(not screen.main_scroll.get_h_scroll_bar().visible, "no horizontal overflow")

func cards_fit() -> void:
	fit()
	var grid := screen.find_child("AmmoGrid", true, false)
	for button in grid.get_children():
		if not button.visible: continue
		if not button.has_node("CardInfo"): continue
		var card := button.get_node("CardInfo")
		if card.hand_skin:
			check(card.FONT.get_string_size(Ammo.AMMO[card.ammo_id].name,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<=card.size.x-29,"compact title fits "+card.ammo_id)
			check(card.size.y>=132 and card.size.x>=108,"compact face has readable footprint")
			continue
		check(card.FONT.get_string_size(Ammo.AMMO[card.ammo_id].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= card.header_title_width(), "grade title clears heat " + card.ammo_id)
		check(card.FONT.get_string_size(card.footer_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= card.size.x - 20, "grade effect fits " + card.ammo_id)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_grade/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1440, 630)]:
		root.size = resolution
		screen._debug_city("shop")
		screen.campaign.model.s.deck = ["cool", "cool", "shatter", "shatter", "bore", "precise", "pierce", "charge", "arc", "push"]
		screen.campaign.s.credits = 100
		screen.redraw()
		await settle()
		bounds("city_shop_press")
		bounds("city_buy_compressor")
		await capture("shop_%d" % resolution.x)
		await tap("city_shop_press")
		bounds("city_compress_cool")
		bounds("city_compress_shatter")
		await capture("permanent_%d" % resolution.x)
		await tap("city_compress_cool")
		check(screen.model.s.deck.has("cool_c") and screen.campaign.s.credits == 82, "public paid grade-up")
		check(screen.find_child("city_shop_press", true, false).disabled, "visit lock shown")
		await capture("purchased_%d" % resolution.x)
		screen._debug_city("shop")
		screen.campaign.s.offers[0] = {"id": "detonate_c", "type": "ammo", "price": 24, "sold": false}
		screen.campaign.s.credits = 100
		screen.redraw()
		await settle()
		bounds("city_compare_buy_0")
		await capture("advanced_shop_%d" % resolution.x)
		await tap("city_compare_buy_0")
		check(screen.model.s.deck.has("detonate_c") and screen.campaign.s.credits == 76, "advanced shop purchase")
		screen._debug_city("reward")
		screen.campaign.s.region = 1
		screen.campaign.s.node = 10101
		screen.campaign.s.floor = 1
		var advanced_reward := ""
		for seed_value in range(200):
			screen.campaign.s.seed = str(seed_value)
			for id in screen.campaign.reward_options():
				if Ammo.is_compressed(id): advanced_reward = id
			if not advanced_reward.is_empty(): break
		check(not advanced_reward.is_empty(), "later region offers advanced reward")
		screen.redraw()
		await settle()
		bounds("city_reward_" + advanced_reward)
		await capture("advanced_reward_%d" % resolution.x)
		await tap("city_reward_" + advanced_reward)
		check(screen.model.s.deck.has(advanced_reward), "advanced reward enters deck")
		screen._debug_eavesback(true)
		screen.model.s.hand = ["cool", "cool", "shatter", "shatter", "detonate", "sequence"]
		screen.model.s.field_compression_left = 1
		screen.hand_layout_key = ""
		screen.redraw()
		await settle()
		cards_fit()
		await tap("compress_pair_cool")
		check(screen.model.s.plan == ["cool_f"] and not screen.model.s.deck.has("cool_f"), "public temporary grade-up")
		cards_fit()
		await capture("field_%d" % resolution.x)
		await tap("undo")
		check(screen.model.s.hand.count("cool") == 2 and screen.model.s.field_compression_left == 1, "public grade undo returns pair and charge")
		await tap("compress_pair_shatter")
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.field_compression.is_empty(), "temporary ends after public fire")
		screen._debug_eavesback(true)
		screen.model.s.hand = ["pierce", "pierce", "cool", "cool", "bore", "bore", "shatter", "shatter"]
		screen.model.s.field_compression_left = 1
		screen.hand_layout_key = ""
		screen.redraw()
		await settle()
		cards_fit()
		bounds("compress_more")
		await tap("compress_more")
		await capture("field_choices_%d" % resolution.x)
		await tap("field_choose_cool")
		check(screen.model.s.plan == ["cool_f"], "overflow menu compresses hidden pair")
	root.size = Vector2i(1008, 630)
	var ids: Array = []
	for source in Ammo.COMPRESSIONS:
		ids.append(source)
		ids.append(Ammo.compressed_id(source))
	for offset in range(0, ids.size(), 6):
		screen._debug_eavesback(true)
		screen.model.s.hand = ids.slice(offset, offset + 6)
		screen.hand_layout_key = ""
		screen.redraw()
		await settle()
		cards_fit()
		await capture("grades_%d" % offset)
	check(not screen.save_enabled, "isolated UI never saves user run")
	screen.queue_free()
	await process_frame
	print("AMMO GRADE UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
