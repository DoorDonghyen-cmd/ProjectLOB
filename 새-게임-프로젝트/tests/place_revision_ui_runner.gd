extends "res://tests/ammo_risk_ui_runner.gd"
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")

func fixture(kind: String, seed_value: int = 17, event_kind: String = "", map_version: int = 3):
	var c = Campaign.new()
	c.start("burst", seed_value, 0, "balanced", map_version)
	c.advance_departure(true)
	var rooms: Array = c.current_nodes()
	var parents := {}
	for room in rooms:
		if room.floor == 1: parents[int(room.id)] = 0
		for next_id in room.next:
			if not parents.has(int(next_id)): parents[int(next_id)] = int(room.id)
	var targets: Array = rooms.filter(func(n): return Data.room_kind(n) == kind and (event_kind.is_empty() or n.event == event_kind))
	if targets.is_empty(): return null
	var path: Array = []
	var id: int = targets[0].id
	while id != 0:
		path.push_front(id)
		id = parents[id]
	for step in path:
		if c.s.phase == "combat":
			for enemy in c.model.s.enemies: enemy.hp = 0
			c.model.s.reinforcements = []
			c.model.s.phase = "reward"
			c.sync_combat()
		while c.s.phase == "reward":
			var parts: Array = c.part_rewards()
			c.reward(str(parts[0]) if not parts.is_empty() else "credits")
		if c.s.phase in ["supply", "event"] and not c.s.resolved: c.resolve("skip")
		if c.s.phase in ["shop", "supply", "event", "bypass"]: c.leave()
		c.enter(step)
	return c

func present(c) -> void:
	screen.campaign = c
	screen.model = c.model
	screen.page = "run"
	screen.redraw()
	await settle()

func press(key: String) -> void:
	var button := screen.find_child(key, true, false) as Control
	if button == null:
		check(false, "missing " + key)
		return
	var parent := button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await settle()
	await tap(key)

func fit_check() -> void:
	check(not screen.main_scroll.get_h_scroll_bar().visible, "no horizontal page overflow")
	var buttons: Array[Node] = screen.find_children("city_*", "Button", true, false)
	for button in buttons:
		if not button.is_visible_in_tree(): continue
		check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= screen.size.x + 1, "button width " + button.name)
		check(button.size.y >= 44, "touch height " + button.name)

func swipe_content(target: ScrollContainer = null) -> void:
	var scroll: ScrollContainer = screen.main_scroll if target == null else target
	scroll.scroll_vertical = 0
	await settle()
	var point := scroll.get_global_rect().position + Vector2(scroll.size.x * 0.3, scroll.size.y * 0.55)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.window_id = root.get_window_id()
	touch.position = root.get_final_transform() * point
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	for step in range(1, 13):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.window_id = root.get_window_id()
		drag.position = root.get_final_transform() * (point + Vector2(0, -step * 12))
		drag.relative = root.get_final_transform().basis_xform(Vector2(0, -12))
		drag.screen_relative = drag.relative
		Input.parse_input_event(drag)
		await create_timer(0.018).timeout
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.window_id = root.get_window_id()
	touch.position = root.get_final_transform() * (point + Vector2(0, -144))
	touch.pressed = false
	Input.parse_input_event(touch)
	await create_timer(0.25).timeout
	check(scroll.scroll_vertical > 0, "touch swipe scrolls content (max=%s page=%s value=%s)" % [scroll.get_v_scroll_bar().max_value, scroll.get_v_scroll_bar().page, scroll.scroll_vertical])
	check(not screen.campaign.s.resolved, "scroll does not spend operation")
	scroll.scroll_vertical = 0
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/place_revision/"): quit(2); return
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
		var c = fixture("shop")
		await present(c)
		check(screen.find_child("city_shop_press", true, false) == null and screen.find_child("city_shop_tune", true, false) == null, "shop has purchases only")
		fit_check()
		await capture("shop_" + tag)
		check(screen.find_child("ShopStoryText", true, false) != null, "shop story visible on arrival")
		check(screen.find_child("story_shop", true, false) == null, "no extra shop reading action")
		await press("city_buy_compressor")
		check(c.s.compressor_charges == 2, "shop charge input")
		await press("city_leave")
		check(c.s.phase == "map", "shop exit input")
		c = fixture("workshop")
		c.s.credits = 0
		await present(c)
		check(screen.find_child("city_workshop_core", true, false) == null, "workshop no charge refill")
		fit_check()
		await capture("workshop_" + tag)
		if resolution.x == 1008 and screen.main_scroll.get_v_scroll_bar().max_value > screen.main_scroll.get_v_scroll_bar().page: await swipe_content()
		await press("city_workshop_tune")
		await press("city_tune_select_0")
		await capture("tune_" + tag)
		await press("workspace_close")
		check(not c.s.resolved, "cancel tune preserves free operation")
		await press("city_workshop_tune")
		await press("city_tune_select_0")
		await press("city_tune_power")
		check(c.s.resolved and c.s.credits == 0, "free tune input")
		await press("city_leave")
		check(c.s.phase == "map", "workshop exit input")
		c = fixture("supply")
		await present(c)
		fit_check()
		await capture("supply_" + tag)
		var chosen: String = c.reward_options()[0]
		var before: int = c.model.s.deck.size()
		await press("city_supply_" + chosen)
		# Earned-ammo acquisition opens a replacement/add choice.
		await press("ammo_acquire_add")
		check(c.s.resolved and c.model.s.deck.size() == before + 1, "supply add input")
		await press("city_leave")
		c = fixture("event", 17, "archive")
		if c == null: c = fixture("event", 2, "archive")
		await present(c)
		fit_check()
		await capture("encounter_" + tag)
		await press("city_encounter_record")
		check(c.s.resolved, "safe lore encounter resolves")
		await capture("encounter_result_" + tag)
		await press("city_leave")
	# Find both an ambush and an ammo reveal through seeded real choices.
	root.size = Vector2i(1280,800)
	for wanted in ["combat", "ammo"]:
		var c
		for seed_value in range(1,50):
			c = fixture("event", seed_value, "salvage")
			if c != null and Campaign.Encounters.outcome("salvage", "pull", seed_value, int(c.s.node)).type == wanted: break
		await present(c)
		await press("city_encounter_pull")
		await capture("reveal_" + wanted)
		if wanted == "combat":
			await press("city_encounter_fight")
			check(c.s.phase == "combat" and c.model.s.phase == "plan", "ambush planning screen")
			await capture("ambush_plan")
			# Exercise an actual normal firing cycle, without mutating enemy HP.
			for id in c.model.s.hand.duplicate():
				if c.model.can_load(id): c.model.load_round(id)
			screen.redraw()
			await settle()
			await press("confirm")
			await press("fire")
			check(c.model.s.shots > 0, "real event volley")
		else:
			var id: String = c.reward_options()[0]
			await press("city_event_ammo_" + id)
			await press("ammo_acquire_add")
			check(c.s.resolved, "revealed ammo acquisition input")
			await press("city_leave")
	# Show a new shortcut and select it through the actual map buttons.
	var c = Campaign.new()
	c.start("burst", 17)
	c.s.departure_step = 3
	var origin: Dictionary = c.current_nodes().filter(func(n): return not n.shortcuts.is_empty())[0]
	c.s.node = origin.id
	c.s.floor = origin.floor
	c.s.visited = [origin.id]
	await present(c)
	var dest: int = origin.shortcuts[0]
	await press("map_node_" + str(dest))
	check(screen.find_child("city_enter_" + str(dest), true, false).text == "전투 건너뛰기", "shortcut is explicit in confirmation")
	check(screen.find_child("MapSelectionPrompt", true, false).text.begins_with("샛길 → "), "shortcut names its destination")
	check(screen.find_child("MapRouteDetail", true, false).text.contains("보상과 코어 성장 포기"), "shortcut exposes the growth tradeoff")
	await capture("shortcut_map")
	await press("city_enter_" + str(dest))
	check(c.s.node == dest, "shortcut destination entered")
	print("PLACE UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
