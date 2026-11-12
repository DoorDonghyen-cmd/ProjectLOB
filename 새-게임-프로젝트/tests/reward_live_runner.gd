extends "res://tests/campaign_magazine_ui.gd"

const Focus = preload("res://redesign/focus_build.gd")

func view():
	return host.body.get_node_or_null("CampaignReward")

func field(key: String):
	return view().get_node("%" + key)

func resize_view(extent: Vector2i) -> void:
	root.size = extent
	await settle()

func capture(label: String) -> void:
	var tween: Tween = view().reveal
	if tween != null and tween.is_running():
		await tween.finished
	await super.capture(label)

func escape() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = pressed
		root.push_input(key, true)
		await process_frame
	await settle()

func verify_save(phase: String) -> Campaign:
	var restored := Campaign.new()
	if check(restored.restore(), "production reward save restores"):
		check(restored.s.phase == phase, "save preserves destination " + phase)
		check(restored.model.s.deck == host.model.s.deck, "save preserves exact deck")
		check(restored.s.equipped_parts == host.campaign.s.equipped_parts, "save preserves equipped parts")
	return restored

func stage_reward(kind: String, region: int = 0, capped: bool = false) -> void:
	var c := Campaign.new()
	c.start("burst", 251025, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	c.s.departure_step = 3
	c.s.region = region
	c.s.clears = 2
	c.s.opening_reward_step = 2
	c.s.parts = ["volley_drive"]
	c.s.equipped_parts = ["volley_drive"]
	c.model.s.deck = Focus.replace_opening(c.model.s.deck, "precise")
	if capped:
		while c.model.s.deck.size() < c.model.deck_limit():
			c.model.s.deck.append("basic_p1")
	var local_nodes := c.current_nodes()
	var current: Dictionary = local_nodes.filter(func(node):
		if kind == "boss":
			return node.kind == "boss"
		return node.kind == "combat" and bool(node.get("elite", false)) == (kind == "elite")
	)[0]
	var preceding: Dictionary = {}
	if current.floor > 1:
		preceding = local_nodes.filter(func(node): return node.next.has(current.id))[0]
		c.s.node = preceding.id
		c.s.floor = preceding.floor
	for index in range(region + 1):
		var nodes: Array = Campaign.Content.nodes(index, int(c.s.seed), int(c.s.map_version))
		var last: Dictionary = preceding if index == region else nodes.filter(func(node): return node.kind == "boss")[0]
		var path: Array = []
		while not last.is_empty():
			path.push_front(last.id)
			last = {} if int(last.floor) == 1 else nodes.filter(func(node): return node.next.has(last.id))[0]
		c.s.visited.append_array(path)
	await mount(c)
	var entered: bool = host._campaign_action("enter", current.id)
	await settle()
	check(entered and c.s.phase == "combat" and is_instance_valid(host.campaign_hud), "fixture enters a real combat node")
	# Stage the terminal state for these variants. Focus-build UI replays a legal win.
	c.model.s.phase = "won"
	host._changed()
	await settle()
	check(c.s.phase == "reward" and is_instance_valid(view()), "production transition opens reward")

func check_bounds() -> void:
	check(root.get_visible_rect().grow(1).encloses(field("Tray").get_global_rect()), "tray stays on screen")
	for key in ["Confirm", "Skip", "RewardRecord", "RewardDetails", "Trade", "RewardTools"]:
		var button := field(key) as Control
		if button.is_visible_in_tree():
			check(field("Tray").get_global_rect().encloses(button.get_global_rect()), "action stays in tray " + key)

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/reward_live_20261105/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch = true
	await resize_view(Vector2i(1280, 800))
	await stage_reward("elite")
	var chosen := "third_striker"
	var balance: int = host.campaign.s.credits
	await tap("city_reward_" + chosen)
	check(view().selected == chosen and not host.campaign.s.parts.has(chosen), "selection previews without granting a part")
	await tap("RewardDetails")
	check(host.find_child("PartDetails", true, false) != null, "part details are reachable")
	await escape()
	await tap("RewardRecord")
	check(is_instance_valid(host.workspace_overlay), "combat record is reachable")
	await escape()
	await tap("RewardTools")
	check(host.workspace_overlay.find_child("settings", true, false) != null, "menu retains settings access")
	await escape()
	await capture("elite_1280x800")
	check_bounds()
	await tap("Confirm")
	check(view() == null and host.campaign.is_equipped(chosen) and host.campaign.s.credits == balance, "part claim equips and goes to map")
	verify_save("map")
	host._to_menu()
	await settle()
	host._resume()
	await settle()
	check(host.campaign.s.phase == "map" and host.campaign.is_equipped(chosen), "title continue restores the acquired part")

	await resize_view(Vector2i(1008, 454))
	await stage_reward("combat", 1, true)
	var old_deck: Array = host.model.s.deck.duplicate()
	var incoming := str(host.campaign.reward_options().back())
	await tap("city_reward_" + incoming)
	var claim_padding: float = field("Confirm").get_theme_stylebox("normal").get_content_margin(SIDE_LEFT)
	await tap("Confirm")
	check(view().choosing_outgoing and field("Confirm").disabled, "full bag waits for removal choice")
	await escape()
	check(not view().choosing_outgoing and view().selected == incoming and host.model.s.deck == old_deck, "cancel preserves selected offer and deck")
	check(field("Confirm").theme == null and field("Confirm").theme_type_variation == &"Claim", "cancel restores the regular claim button")
	await tap("Confirm")
	var outgoing := str(view().cards.keys()[0])
	await tap("ammo_replace_" + outgoing)
	var exchange_face := field("Confirm").get_theme_stylebox("normal") as StyleBoxFlat
	check(exchange_face.bg_color.is_equal_approx(Color("252b23")) and exchange_face.get_content_margin(SIDE_LEFT) == claim_padding, "exchange uses dark iron and keeps reward padding")
	check_bounds()
	await capture("exchange_1008x454")
	var same_view = view()
	await resize_view(Vector2i(2340, 1080))
	check(view() == same_view and view().selected == incoming and view().outgoing == outgoing, "resize preserves both sides of exchange")
	check_bounds()
	await capture("exchange_2340x1080")
	await tap("Confirm")
	check(host.campaign.s.phase == "map" and host.model.s.deck.size() == old_deck.size(), "full bag replaces one without expanding")
	check(host.model.s.deck.count(incoming) == old_deck.count(incoming) + 1 and host.model.s.deck.count(outgoing) == old_deck.count(outgoing) - 1, "exact outgoing and incoming counts")
	verify_save("map")

	await resize_view(Vector2i(1280, 800))
	await stage_reward("combat")
	await tap("Trade")
	check(view().choosing_outgoing, "optional exchange remains available with room")
	await tap("Skip")
	var deck_size: int = host.model.s.deck.size()
	await tap("Confirm")
	check(host.campaign.s.phase == "map" and host.model.s.deck.size() == deck_size + 1, "direct claim adds one when room")
	verify_save("map")

	await resize_view(Vector2i(740, 454))
	await stage_reward("combat")
	check_bounds()
	await resize_view(Vector2i(1280, 800))
	await stage_reward("boss")
	balance = host.campaign.s.credits
	check(host.campaign.s.boss_loot_paid and not field("Credits").visible and field("Receipt").text.contains("+30 Cr"), "boss receipt reflects already-paid credits")
	await capture("boss_1280x800")
	verify_save("reward")
	host._to_menu()
	await settle()
	host._resume()
	await settle()
	check(view() != null and host.campaign.s.credits == balance, "continuing boss loot does not pay twice")
	await tap("Skip")
	check(host.campaign.s.phase == "gate" and host.campaign.s.credits == balance, "boss defer enters gate without another payment")
	verify_save("gate")

	await stage_reward("boss", 4)
	await tap("Skip")
	check(host.campaign.s.phase == "won" and host.campaign.restoration_pending(), "final boss reward leads to restoration")
	verify_save("won")

	var old_run := Campaign.new()
	old_run.start("single", 731042, 0, "balanced", 2, "carrier")
	old_run.advance_departure(true)
	check(old_run.enter(int(old_run.choices()[0].id)), "old map fixture enters combat")
	old_run.model.s.phase = "reward"
	old_run.sync_combat()
	await mount(old_run)
	check(view() == null and host.find_child("RewardGrid", true, false) != null, "old map keeps the legacy reward route")
	host.free()
	await settle()
	print("REWARD LIVE COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
