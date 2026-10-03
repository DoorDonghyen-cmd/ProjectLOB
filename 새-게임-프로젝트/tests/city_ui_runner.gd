extends SceneTree
## Replay successful full-city real commands through the visible Godot controls.
const Campaign = preload("res://redesign/campaign.gd")
const Ammo = preload("res://redesign/content.gd")
var screen: Control
var checks := 0
var failures: Array = []
var clicks := 0
var captures: Array = []
var output := ""

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	return condition

func settle() -> void:
	for i in range(4): await process_frame
	while is_instance_valid(screen) and screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func fresh() -> void:
	if is_instance_valid(screen): screen.free()
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.01
	root.add_child(screen)
	await settle()

func input_point(control: Control) -> Vector2:
	return root.get_final_transform() * (control.get_screen_transform() * (control.size * 0.5) - Vector2(DisplayServer.window_get_position()))

func click(key: String, touch: bool = false) -> bool:
	var control := screen.find_child(key, true, false) as Button
	if not check(control != null and not control.disabled and control.is_visible_in_tree(), "usable button " + key): return false
	if control.get_parent().is_ancestor_of(screen.body) or screen.body.is_ancestor_of(control):
		(screen.get_child(0) as ScrollContainer).ensure_control_visible(control)
		await settle()
	if touch:
		var point := input_point(control)
		for pressed in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = point
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
	else: control.pressed.emit()
	clicks += 1
	await settle()
	return check(screen.save_error.is_empty(), "save after " + key)

func drag_pair(source_key: String, target_key: String, touch: bool = true) -> bool:
	var source := screen.find_child(source_key, true, false) as Control
	var target := screen.find_child(target_key, true, false) as Control
	if not check(source != null and target != null and source.is_visible_in_tree() and target.is_visible_in_tree(), "visible drag pair " + source_key + " -> " + target_key): return false
	(screen.get_child(0) as ScrollContainer).ensure_control_visible(source)
	await settle()
	var from := input_point(source)
	var to := input_point(target)
	if touch:
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = from
		press.pressed = true
		Input.parse_input_event(press)
		await process_frame
		var previous := from
		for step in range(1, 9):
			var motion := InputEventScreenDrag.new()
			motion.index = 0
			motion.position = from.lerp(to, float(step) / 8.0)
			motion.relative = motion.position - previous
			motion.pressure = 1.0
			Input.parse_input_event(motion)
			previous = motion.position
			await process_frame
		var release := InputEventScreenTouch.new()
		release.index = 0
		release.position = to
		release.pressed = false
		Input.parse_input_event(release)
	else:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = from
		press.global_position = from
		press.pressed = true
		Input.parse_input_event(press)
		await process_frame
		var previous := from
		for step in range(1, 9):
			var motion := InputEventMouseMotion.new()
			motion.position = from.lerp(to, float(step) / 8.0)
			motion.global_position = motion.position
			motion.relative = motion.position - previous
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(motion)
			previous = motion.position
			await process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = to
		release.global_position = to
		release.pressed = false
		Input.parse_input_event(release)
	clicks += 1
	await settle()
	return check(screen.save_error.is_empty(), "save after drag " + source_key)

func normalized(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

func capture(label: String) -> void:
	await settle()
	var path := output.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)
	captures.append(path)
	check(screen.body.size.x <= screen.size.x, "no horizontal overflow " + label)

func key(command: Dictionary) -> String:
	match str(command.action):
		"enter": return "city_enter_" + str(int(command.id))
		"reward": return "city_reward_" + str(command.id)
		"gate": return "city_gate_" + str(command.id)
		"buy": return "city_compare_buy_" + str(int(command.id))
		"reroll": return "city_reroll"
		"resolve":
			if screen.campaign.s.phase == "supply" and command.id == "ammo": return "city_supply_" + str(command.ammo)
			if command.id == "skip": return "city_service_skip"
			if command.id == "sell": return "city_sell_" + str(command.ammo)
			return "city_event_" + str(command.id)
		"leave": return "city_leave"
		"load":
			for candidate in screen.find_children("load_*", "Button", true, false):
				if not candidate.disabled and candidate.get("ammo_id") == str(command.id): return str(candidate.name)
			return "load_" + str(command.id)
		"confirm": return "confirm"
		"fire": return "fire"
		"reload": return "reload"
	return ""

func replay(expected: Dictionary) -> void:
	# Overwrite only this test's isolated city file; production/legacy saves remain.
	var clean := FileAccess.open(Campaign.SAVE, FileAccess.WRITE)
	clean.store_string("{}")
	clean.close()
	await fresh()
	if not await click("new_run_setup"): return
	screen.seed_input.text = str(int(expected.seed))
	if str(expected.gun) != "single":
		if not await click("weapon_select_" + str(expected.gun)): return
	if not await click("start_" + str(expected.gun)): return
	check(screen.campaign != null and screen.campaign.s.phase == "map", "normal start opens city map")
	await capture("city_start_" + str(expected.gun))
	var captured: Array = []
	var resumed := false
	for command in expected.commands:
		var phase: String = screen.campaign.s.phase
		if not captured.has(phase) and phase != "combat":
			captured.append(phase)
			await capture("city_" + str(expected.gun) + "_" + phase)
		if command.action == "enter":
			if not await click("map_node_" + str(int(command.id))): return
			check(screen.campaign.s.phase == "map", "map selection waits for explicit movement confirmation")
		if command.action == "buy":
			var offer: Dictionary = screen.campaign.s.offers[int(command.id)]
			if not await click(("city_part_info_" if offer.type == "part" else "city_offer_compare_") + str(int(command.id))): return
		if not await click(key(command)): return
		if command.action == "gate" and command.id == "compress":
			if not await click("city_compress_" + str(command.ammo), true): return
		var actual_state := {"phase": screen.campaign.s.phase, "node": int(screen.campaign.s.node), "credits": int(screen.campaign.s.credits), "turns": int(screen.model.s.turns)}
		var expected_state := {"phase": command.phase, "node": int(command.node), "credits": int(command.credits), "turns": int(command.turns)}
		if not check(actual_state == expected_state, "UI command agrees %s · expected %s · actual %s" % [key(command), str(expected_state), str(actual_state)]): return
		if not resumed and int(screen.campaign.s.region) >= 2 and screen.campaign.s.phase == "combat":
			var before := normalized({"campaign": screen.campaign.s, "combat": screen.model.s, "profile": screen.campaign.profile})
			await fresh()
			if not await click("resume"): return
			check(normalized({"campaign": screen.campaign.s, "combat": screen.model.s, "profile": screen.campaign.profile}) == before, "full city disk resume exact")
			resumed = true
		if screen.campaign.s.phase == "combat" and screen.model.capacity() == 6 and command.action == "confirm" and not captured.has("six"):
			captured.append("six")
			await capture("city_six_slot_" + str(expected.gun))
		if screen.campaign.s.phase == "map" and int(screen.campaign.s.region) == 4 and int(screen.campaign.s.floor) == 0:
			await capture("city_summit_map_" + str(expected.gun))
	check(screen.campaign.s.phase == "won", "actual UI reaches final core")
	check(normalized(screen.campaign.s) == normalized(expected.campaign), "full city history agrees")
	var rules_snapshot = preload("res://tests/combat_rules_snapshot.gd")
	check(normalized(rules_snapshot.state(screen.model.s)) == normalized(rules_snapshot.state(expected.combat)), "full combat history agrees (optional presentation observations excluded)")
	check(normalized(screen.campaign.profile) == normalized(expected.profile), "full profile awards agree")
	await capture("city_complete_" + str(expected.gun))
	if await click("city_archive"):
		await capture("city_archive_" + str(expected.gun))
		await click("city_unlock_thermal")
		check(screen.campaign.profile.unlocks.has("thermal"), "UI unlocks next-run loadout")
		for child in screen.get_children():
			if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
		await settle()
	if await click("retry"):
		check(screen.campaign.s.phase == "map" and screen.campaign.absolute_floor() == 0 and screen.model.s.turns == 0, "retry resets whole city")
		check(int(screen.campaign.s.seed) == int(expected.seed), "retry keeps route seed")
		check(screen.campaign.profile.unlocks.has("thermal"), "retry retains profile unlock")
	print("CITY UI RUN " + str(expected.gun) + " complete")

func developer() -> void:
	await fresh()
	await capture("preart_menu")
	await click("new_run_setup")
	await capture("preart_weapon_selection")
	await click("loadout_back")
	await click("guide")
	await capture("preart_first_guide")
	for child in screen.get_children():
		if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
	await settle()
	await click("settings")
	await capture("preart_settings")
	var text_scale := screen.find_child("TextScaleSetting", true, false) as OptionButton
	check(text_scale != null, "text scale control exists")
	if text_scale != null:
		text_scale.select(2)
		text_scale.item_selected.emit(2)
		await settle()
	for child in screen.get_children():
		if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
	await settle()
	root.size = Vector2i(1008, 630)
	await capture("preart_menu_large_text_phone")
	check(screen.body.size.x <= screen.size.x, "large text menu keeps logical width")
	screen.preferences.reset()
	screen._apply_preferences()
	root.size = Vector2i(1280, 800)
	await settle()
	await click("dev")
	await click("debug_first_guide")
	check(screen.find_child("FirstGuide", true, false) != null, "developer shortcut opens first guide without nested modal conflict")
	for child in screen.get_children():
		if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
	await settle()
	await click("dev")
	await click("debug_settings")
	check(screen.find_child("SettingsDialog", true, false) != null, "developer shortcut opens settings without nested modal conflict")
	for child in screen.get_children():
		if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
	await settle()
	await click("dev")
	await click("debug_part_cards")
	check(screen.find_child("PartGallery", true, false) != null, "developer shortcut opens the part icon gallery")
	for id in Ammo.PARTS:
		if id == "none": continue
		check(screen.find_child("PartGallery_" + id, true, false) != null, "part gallery exposes " + id)
	await capture("part_icon_gallery")
	for child in screen.get_children():
		if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
	await settle()
	var saved: String = FileAccess.get_file_as_string(Campaign.SAVE)
	for scenario in ["map", "shop", "supply", "event", "gate", "ending", "loss", "reward", "deck", "archive"]:
		if screen.page != "menu": await click("menu")
		if not await click("dev"): return
		if not await click("debug_city_" + scenario): return
		check(screen.debug_session, "city developer mode protects save")
		await capture("city_debug_" + scenario)
		if scenario == "map":
			check(screen.find_child("CampaignShellHeader", true, false) != null and screen.find_child("MapRouteSheet", true, false) != null, "map uses the compact run shell and one destination sheet")
			await click("map_node_101", true)
			check(screen.campaign.s.phase == "map" and screen.find_child("city_enter_101", true, false) != null, "touch map destination selects without entering")
			await capture("city_map_selected")
			await click("city_enter_101", true)
			check(screen.campaign.s.phase == "combat", "explicit map confirmation enters actual combat")
		elif scenario == "shop":
			check(screen.find_child("ShopWorkbench", true, false) != null, "shop uses the authored workbench scene")
			var shop_equipment := screen.find_child("EquipmentPanel", true, false) as Control
			check(screen.find_child("CurrentBuildPanel", true, false) != null and screen.find_child("OfferComparePanel", true, false) != null and shop_equipment == null, "shop focuses on build summary, offers, and comparison without duplicating the equipment editor")
			await click("city_shop_build", true)
			var shop_workspace := screen.find_child("WorkspaceOverlay", true, false) as Control
			check(shop_workspace != null and shop_workspace.size.is_equal_approx(screen.size), "shop opens equipment management as a full-screen build workspace")
			await click("workspace_close", true)
			check(screen.find_child("ShopCompressorGlyph", true, false) != null, "shop compression core has a compact graphical charge indicator")
			var part_info := screen.find_children("city_part_info_*", "Button", true, false)
			check(not part_info.is_empty(), "shop exposes icon-first part detail buttons")
			if not part_info.is_empty():
				part_info[0].pressed.emit()
				await settle()
				var compare_body := screen.find_child("OfferCompareBody", true, false) as Label
				check(compare_body != null and compare_body.text.contains("▲"), "part selection shows an in-place before and after comparison")
				await capture("city_part_compare")
				await click("city_offer_detail_1", true)
				check(screen.find_child("PartDetails", true, false) != null, "optional part detail keeps the same visual language")
				await capture("city_part_detail")
				for child in screen.get_children():
					if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
				await settle()
			await click("city_compare_buy_1", true)
			check(screen.campaign.s.parts.size() == 1, "touch shop buys a part")
			check(not (screen.find_child("ShopHint", true, false) as Label).text.is_empty(), "shop confirms the result immediately after purchase")
			var equipped_id := str(screen.campaign.equipped_parts()[0]) if not screen.campaign.equipped_parts().is_empty() else "none"
			check(equipped_id != "none" and screen.find_child("PartCard_" + equipped_id, true, false) != null, "purchased part fills one of five equipped slots")
			await capture("city_shop_equipped_part")
			await click("city_reroll")
			var candidate := screen.find_child("city_compare_buy_1", true, false) as Button
			check(candidate != null and not candidate.disabled, "UI allows another affordable part after reroll")
			await click("city_buy_compressor", true)
			check(screen.campaign.s.compressor_charges == 2 and screen.campaign.s.shop_compressor_bought, "shop UI charges one persistent compression core")
			var core_button := screen.find_child("city_buy_compressor", true, false) as Button
			check(core_button != null and core_button.disabled, "shop compression core respects visit and capacity lock")
		elif scenario == "supply":
			var deck_before: Array = screen.model.s.deck.duplicate()
			await click("city_service_skip")
			check(screen.model.s.deck == deck_before, "supply skip keeps the deck intact")
		elif scenario == "event": await click("city_service_skip")
		elif scenario == "reward":
			await click("city_reward_credits")
			check(screen.model.s.deck.size() == 10 and screen.campaign.s.credits > 75 and screen.campaign.s.phase == "map", "UI credit reward advances without thinning the deck")
		elif scenario == "gate":
			check(screen.find_child("UpgradeChoice_slot", true, false) != null and screen.find_child("UpgradeChoice_compress", true, false) != null and screen.find_child("UpgradeChoice_credits", true, false) != null, "gate choices use three distinct graphical cards")
			await click("city_gate_compress")
			await capture("city_compression_dialog")
			root.size = Vector2i(1008, 630)
			await capture("city_compression_dialog_phone")
			root.size = Vector2i(1280, 800)
			await settle()
			await click("city_compress_bore", true)
			check(screen.campaign.s.region == 1 and screen.model.s.deck.size() == 9 and screen.model.s.deck.has("bore_c"), "gate visual compression enters next region with transformed round")
		elif scenario == "deck":
			check(screen.find_child("DeckLoadout", true, false) != null, "deck uses the authored loadout scene")
			var deck_workspace := screen.find_child("WorkspaceOverlay", true, false) as Control
			check(deck_workspace != null and deck_workspace.size.is_equal_approx(screen.size), "deck and equipment use a full-screen workspace instead of a dialog")
			check(screen.find_child("PartsTab", true, false) != null and screen.find_child("AmmoTab", true, false) != null, "deck separates parts configuration and ammunition library")
			await click("AmmoTab", true)
			check((screen.find_child("DeckPanel", true, false) as Control).visible, "ammunition tab focuses the deck library")
			await capture("city_deck_ammo_tab")
			await click("PartsTab", true)
			check((screen.find_child("InventoryPanel", true, false) as Control).visible, "parts workspace keeps the inventory visible")
			await capture("city_deck_inventory_tab")
			await click("equipped_part_detail_1", true)
			check(screen.find_child("PartCard_capacitor", true, false) != null and screen.find_child("city_deck_equip_rammer", true, false) != null, "deck equipment shows equipped and stored part cards")
			await click("city_deck_equip_rammer", true)
			check(not screen.campaign.is_equipped("rammer") and screen.campaign.equipped_parts().size() == 4, "deck equipment toggles one part without replacing the rest")
			check((screen.find_child("InventoryPanel", true, false) as Control).visible and not (screen.find_child("BuildFeedback", true, false) as Label).text.is_empty(), "equipment change preserves the active workspace tab and confirms the result")
		check(FileAccess.get_file_as_string(Campaign.SAVE) == saved, "developer never writes real city save")
		for child in screen.get_children():
			if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
		await settle()
	await click("menu")
	await click("dev")
	await click("debug_enemy_locks")
	await capture("upper_enemy_locks")
	await click("enemy_info_0", true)
	await capture("upper_enemy_lock_detail")
	for child in screen.get_children():
		if child is AcceptDialog or child.name == "WorkspaceOverlay": child.queue_free()
	await settle()
	await click("menu")
	root.size = Vector2i(1008, 630)
	await settle()

	for scenario in ["map", "shop", "event"]:
		await click("dev")
		await click("debug_city_" + scenario)
		await capture("city_phone_" + scenario)
		check(screen.body.size.x <= screen.size.x, "small landscape fits logical viewport width")
		if scenario == "shop":
			var shop_grid := screen.find_child("ShopOfferGrid", true, false) as GridContainer
			check(shop_grid != null and shop_grid.columns == 3, "landscape shop shows all three offers together")
			check(screen.find_child("city_shop_build", true, false) != null, "small landscape shop keeps build management one tap away")
		for key_name in ["menu", "CityMap", "city_leave", "city_compare_buy_1"]:
			var control := screen.find_child(key_name, true, false) as Control
			if control:
				var logical: Rect2 = control.get_global_rect()
				var transform: Transform2D = root.get_final_transform()
				var pixels := Rect2(transform * logical.position, transform.basis_xform(logical.size))
				check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(pixels), "small landscape physical bounds " + key_name)
		await click("menu")
	root.size = Vector2i(1280, 800)
	await settle()
	await click("dev")
	await click("debug_compressed_ammo")
	check(screen.find_child("CombatWorkbench", true, false) != null, "combat uses the authored tactical workbench scene")
	check(screen.find_child("CandidatesPanel", true, false) != null and screen.find_child("QueuePanel", true, false) != null, "combat separates ammunition candidates from firing order")
	check(screen.model.s.plan == ["precise_c", "pierce_c", "push_c"] and Ammo.slots_used(screen.model.s.plan) == 4, "compressed debug shortcut exposes first, two-cell, and last placement")
	await capture("compressed_ammo_loading")
	root.size = Vector2i(1008, 630)
	await settle()
	var tactical_grid := screen.find_child("TacticalGrid", true, false) as GridContainer
	var compact_ammo_grid := screen.find_child("AmmoGrid", true, false) as GridContainer
	check(tactical_grid != null and tactical_grid.columns == 1, "phone landscape gives firing order the full width")
	check(compact_ammo_grid != null and compact_ammo_grid.columns == 6, "phone landscape keeps the full ammunition row visible")
	await capture("compressed_ammo_loading_phone")
	root.size = Vector2i(840, 630)
	await settle()
	tactical_grid = screen.find_child("TacticalGrid", true, false) as GridContainer
	compact_ammo_grid = screen.find_child("AmmoGrid", true, false) as GridContainer
	check(tactical_grid != null and tactical_grid.columns == 1, "extra-narrow combat stacks candidates and firing order")
	check(compact_ammo_grid != null and compact_ammo_grid.columns == 3, "extra-narrow combat keeps ammunition cards readable")
	root.size = Vector2i(1280, 800)
	await settle()
	await click("menu")
	await click("dev")
	await click("debug_field_compression")
	check(screen.model.field_compressible_ids().has("precise") and screen.model.field_compressible_ids().has("charge"), "field compression shortcut exposes two eligible pairs")
	var compressor_status := screen.find_child("field_compressor_status", true, false) as Control
	var compressor_glyph := screen.find_child("CompressorGlyph", true, false) as Control
	var reserve_status := screen.find_child("ReserveAmmo", true, false) as Control
	var precise_first = screen.find_child("load_precise", true, false)
	var precise_second = screen.find_child("load_precise_2", true, false)
	check(compressor_status != null and compressor_glyph != null and reserve_status != null and precise_first != null and precise_second != null, "compressor reserve and individual duplicate cards are visible")
	check(compressor_status.size.y <= 48.0 and compressor_glyph.size.x <= 58.0, "compression core glyph stays inside the compact tool row")
	var pair_button := screen.find_child("compress_pair_precise", true, false) as Button
	check(pair_button != null and pair_button.size.y <= 52.0, "graphical pair action does not stretch the candidate layout")
	check(screen.find_child("DecisionPrompt", true, false) != null and screen.find_child("CompressionActions", true, false) != null, "combat exposes a staged decision prompt and explicit compression actions")
	check(screen.find_child("reserve_next_bore", true, false) != null and screen.find_child("reserve_next_push", true, false) != null and screen.find_child("reserve_wait_pierce", true, false) != null, "combat reserve exposes next two and every remaining tactical family")
	check(bool(precise_first.compression_ready) and bool(precise_second.compression_ready), "both matching cards expose the cyan compression affordance")
	await capture("field_compression_ready")
	root.size = Vector2i(1008, 630)
	await capture("field_compression_ready_phone")
	root.size = Vector2i(1280, 800)
	await settle()
	if not await drag_pair("load_precise", "load_charge", true): return
	check(screen.model.s.plan.is_empty() and screen.model.s.field_compression_left == 1, "dragging onto a different round does not compress or load")
	await click("load_charge", true)
	check(screen.model.s.plan == ["charge"] and screen.model.s.field_compression_left == 1, "short touch still loads exactly one ordinary round")
	await click("undo", true)
	check(screen.model.s.plan.is_empty() and screen.model.s.hand.count("charge") == 2, "undo after short touch restores the individual pair")
	await click("compress_pair_charge", true)
	check(screen.model.s.plan == ["charge_f"] and screen.model.s.field_compression_left == 0, "explicit compression button supports touch without drag precision")
	await click("undo", true)
	check(screen.model.s.plan.is_empty() and screen.model.s.hand.count("charge") == 2 and screen.model.s.field_compression_left == 1, "undo restores an explicitly compressed pair and core")
	if not await drag_pair("load_precise", "load_precise_2", true): return
	check(screen.model.s.plan == ["precise_f"] and screen.model.s.exchange_left == 1 and screen.model.s.field_compression_left == 0, "touch drag between matching cards spends a core but preserves hand exchange")
	await capture("field_compression_combined")
	await click("undo", true)
	check(screen.model.s.plan.is_empty() and screen.model.s.hand.count("precise") == 2 and screen.model.s.exchange_left == 1 and screen.model.s.field_compression_left == 1, "visible undo restores pair and compression core")
	await click("menu")

func six_slot_layout(expected: Dictionary) -> void:
	var campaign = Campaign.new()
	campaign.start(str(expected.gun), int(expected.seed))
	var final_capacity := int(Ammo.GUNS[expected.gun].capacity) + 2
	var found := false
	for command in expected.commands:
		var accepted := false
		match str(command.action):
			"enter": accepted = campaign.enter(int(command.id))
			"reward": accepted = campaign.reward(str(command.id))
			"gate": accepted = campaign.gate(str(command.id), str(command.get("ammo", "")))
			"buy": accepted = campaign.buy(int(command.id))
			"reroll": accepted = campaign.reroll()
			"resolve": accepted = campaign.resolve(str(command.id), str(command.get("ammo", "")))
			"leave": accepted = campaign.leave()
			"load": accepted = campaign.model.load_round(str(command.id))
			"confirm": accepted = campaign.model.confirm()
			"fire": accepted = campaign.model.fire()
			"reload": accepted = campaign.model.reload_magazine()
		campaign.sync_combat()
		if not check(accepted, "actual path to six-slot layout"): return
		campaign.save("user://layout_probe.json")
		if campaign.s.phase == "combat" and campaign.model.capacity() == final_capacity and command.action == "confirm":
			found = true
			break
	if not check(found, "genuine final-capacity state available"): return
	await fresh()
	screen.save_enabled = false
	screen.debug_session = true
	screen.campaign = campaign
	screen.model = campaign.model
	screen.page = "run"
	screen.redraw()
	await settle()
	await capture("city_six_slot_final_" + str(expected.gun))
	var magazine = screen.magazine_view
	var font: Font = load("res://redesign/ui_font.tres")
	var width: float = magazine.size.x / float(final_capacity) - 8
	for i in range(magazine.forecast.shots.size()):
		var lines: PackedStringArray = magazine.compact_lines(magazine.forecast, i)
		var shot: Dictionary = magazine.forecast.shots[i]
		if shot.get("random", false):
			check(lines[0] == "무작위" and lines[1] == "%d~%d" % [shot.damage_min, shot.damage_max], "compact random slot retains public damage range")
		else: check(lines[1] == ("처치" if int(shot.hp) == 0 else "HP%d" % int(shot.hp)), "compact line retains exact remaining HP")
		for line in range(3): check(font.get_string_size(lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if line == 0 else 14).x <= width, "compact result stays inside its slot")
	for key_name in ["fire", "reload"]:
		var control := screen.find_child(key_name, true, false) as Control
		check(control != null and screen.get_global_rect().encloses(control.get_global_rect()), "six-slot action within viewport")
	root.size = Vector2i(1008, 630)
	await capture("city_six_slot_phone_" + str(expected.gun))
	root.size = Vector2i(1280, 800)
	await settle()
func _run() -> void:
	root.size = Vector2i(1280, 800)
	output = OS.get_environment("QA_OUTPUT_DIR")
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not check(user_path.contains("/qa_runtime/city/ui/") or user_path.contains("/qa_runtime/city/ui_"), "isolated UI profile"): quit(1); return
	var path := ProjectSettings.globalize_path("res://").path_join("../qa_runtime/city/campaign/city_campaign_report.json")
	if not OS.get_environment("QA_CITY_SOURCE").is_empty(): path = OS.get_environment("QA_CITY_SOURCE")
	elif not FileAccess.file_exists(path): path = ProjectSettings.globalize_path("res://").path_join("../docs/qa/reports/full_city_campaign_2026-09-16_assets/city_campaign_report.json")
	var source = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(source is Dictionary and source.get("failures", []).is_empty(), "validated external source"): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	for expected in source.runs:
		var selected_guns := OS.get_environment("QA_CITY_UI_GUNS")
		if not selected_guns.is_empty() and not selected_guns.split(",").has(str(expected.gun)): continue
		if expected.route == "safe" and int(expected.seed) == 731042 and int(expected.difficulty) == 0:
			if OS.get_environment("QA_CITY_LAYOUT_ONLY") == "1": await six_slot_layout(expected)
			else: await replay(expected)
	if OS.get_environment("QA_CITY_LAYOUT_ONLY") != "1": await developer()
	var report := FileAccess.open(output.path_join("city_ui_report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "clicks": clicks, "captures": captures}, "\t"))
	report.close()
	print("CITY UI COMPLETE checks=" + str(checks) + " failures=" + str(failures.size()) + " buttons=" + str(clicks))
	if is_instance_valid(screen): screen.free()
	quit(0 if failures.is_empty() else 1)
