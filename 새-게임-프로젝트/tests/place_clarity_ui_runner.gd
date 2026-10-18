extends "res://tests/place_layout_ui_runner.gd"
const CardFace = preload("res://redesign/ammo_card_view.gd")
const Lore = preload("res://redesign/city_story.gd")

func bounded_cards(context: String) -> void:
	var count := 0
	for view in screen.find_children("*", "Control", true, false):
		if view.get_script() != CardFace or not view.is_visible_in_tree(): continue
		count += 1
		check(view.size.x >= 220 and view.size.x <= 246, context + " fixed card width " + str(view.size))
		check(view.size.y >= 154 and view.size.y <= 221, context + " bounded card height " + str(view.size))
	check(count > 0, context + " cards rendered")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/place_clarity/"): quit(2); return
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
		for region in range(5):
			var c = fixture("shop")
			c.s.region = region
			var shops: Array = c.current_nodes().filter(func(n): return n.kind == "shop")
			check(not shops.is_empty(), "regional shop fixture")
			c.s.node = shops[0].id
			await present(c)
			layout_check("shop region %d %s" % [region, tag])
			var story := screen.find_child("ShopStoryText", true, false) as Label
			check(story != null and story.text == Lore.SHOPS[region].story, "full story directly visible")
			check(story.get_global_rect().end.y < screen.size.y, "story in first viewport")
			check(screen.find_child("story_shop", true, false) == null, "no reading gate")
			bounded_cards("shop " + tag)
			await capture("shop_%d_%s" % [region,tag])
		var c = fixture("supply")
		await present(c)
		bounded_cards("supply " + tag)
		layout_check("supply " + tag)
		await capture("supply_" + tag)
		await press("city_supply_" + str(c.reward_options()[0]))
		bounded_cards("acquisition " + tag)
		await capture("acquisition_" + tag)
		await press("ammo_acquire_add")
		check(c.s.resolved, "smaller acquisition works")
		c = fixture("workshop")
		await present(c)
		await press("city_workshop_tune")
		bounded_cards("tune collection " + tag)
		await capture("tune_choices_" + tag)
		await press("city_tune_select_0")
		bounded_cards("tune preview " + tag)
		var power := screen.find_child("city_tune_power",true,false) as Control
		var cool := screen.find_child("city_tune_cool",true,false) as Control
		check(absf(power.get_global_rect().end.y - cool.get_global_rect().end.y) < 1, "preview buttons align")
		await capture("tune_" + tag)
		await press("workspace_close")
		await press("city_workshop_trim")
		bounded_cards("remove " + tag)
		await capture("remove_" + tag)
		await press("workspace_close")
		check(not c.s.resolved, "inspection keeps operation")
		await press("city_deck")
		await press("AmmoTab")
		bounded_cards("deck " + tag)
		await capture("deck_" + tag)
		await press("workspace_close")
		# Campaign transition fixture to exercise the public first-ammo reward screen.
		var reward_campaign = Campaign.new()
		reward_campaign.start("burst",17)
		reward_campaign.advance_departure(true)
		reward_campaign.enter(int(reward_campaign.choices()[0].id))
		for enemy in reward_campaign.model.s.enemies: enemy.hp = 0
		reward_campaign.model.s.reinforcements = []
		reward_campaign.model.s.phase = "reward"
		reward_campaign.sync_combat()
		reward_campaign.reward(str(reward_campaign.part_rewards()[0]))
		await present(reward_campaign)
		bounded_cards("reward " + tag)
		await capture("reward_" + tag)
		# Select a real shortcut and follow the same link through the map action.
		c = Campaign.new()
		c.start("burst",17)
		c.s.departure_step = 3
		var origin: Dictionary = c.current_nodes().filter(func(n): return not n.shortcuts.is_empty())[0]
		c.s.node = origin.id
		c.s.floor = origin.floor
		c.s.visited = [origin.id]
		await present(c)
		var map := screen.find_child("CityMap",true,false)
		var dest: int = origin.shortcuts[0]
		await press("map_node_" + str(dest))
		var points: PackedVector2Array = map.shortcut_path(map.positions[int(origin.id)],map.positions[dest])
		var left: float = minf(map.positions[int(origin.id)].x,map.positions[dest].x) - 100
		var right: float = maxf(map.positions[int(origin.id)].x,map.positions[dest].x) + 100
		for point in points: check(point.x >= left and point.x <= right, "shortcut stays near its connected nodes")
		check(screen.find_child("MapRouteDetail",true,false).text.contains("전투 한 곳 건너뜀"), "selected shortcut explains tradeoff")
		await capture("shortcut_" + tag)
		await press("city_enter_" + str(dest))
		check(c.s.node == dest, "new route drawing preserves navigation")
	# The public large-text setting must still show the longest story and actions.
	root.size = Vector2i(1008,630)
	screen.preferences.data.text_scale = 1.1
	var c = fixture("shop")
	c.s.region = 1
	c.s.node = c.current_nodes().filter(func(n): return n.kind == "shop")[0].id
	await present(c)
	layout_check("long story large text")
	await capture("shop_large_text")
	print("PLACE CLARITY COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
