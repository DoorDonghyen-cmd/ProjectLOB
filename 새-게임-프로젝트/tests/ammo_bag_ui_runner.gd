extends "res://tests/ammo_cycle_ui_runner.gd"
const Bag = preload("res://redesign/ammo_bag_view.gd")

func view():
	return screen.find_child("AmmoBagView", true, false)

func check_snapshot() -> void:
	var m = screen.model
	var before := JSON.stringify(m.s)
	var zones: Dictionary = Bag.snapshot(m.s)
	var owned: Array = zones.hand + zones.draw + zones.discard
	for id in zones.loaded:
		if Ammo.is_temporary(str(id)):
			owned.append(Ammo.source_id(str(id)))
			owned.append(Ammo.source_id(str(id)))
		elif id != "basic" or Ammo.uses_ammo_cards(m.s): owned.append(id)
	var expected: Array = m.s.deck.duplicate()
	owned.sort()
	expected.sort()
	check(owned == expected, "bag zones count every owned card exactly once")
	check(JSON.stringify(m.s) == before, "snapshot is pure")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_bag/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1440, 630)]:
		root.size = resolution
		await setup_hand(["basic", "basic", "charge", "pierce", "push"])
		fit()
		bounds("ammo_bag")
		await capture("entry_%d" % resolution.x)
		await tap("load_basic_2")
		check_snapshot()
		var before := JSON.stringify(screen.model.s)
		screen.find_child("ammo_bag", true, false).grab_focus()
		await tap("ammo_bag")
		check(view().inventory.hand.size() == 4 and view().inventory.loaded == ["basic"], "planned card removed from bag hand count")
		for key in Bag.TABS: bounds("bag_tab_" + key)
		bounds("workspace_close")
		check(view().cards.size() == 4, "owned duplicate types grouped")
		await capture("all_%d" % resolution.x)
		for key in Bag.TABS:
			await tap("bag_tab_" + key)
			check(view().active_tab == key, "real tab switching " + key)
			check(not screen.find_child("WorkspaceScroll", true, false).get_h_scroll_bar().visible, "bag has no horizontal scroll")
			if not view().cards.is_empty():
				var card_key: String = view().cards.keys()[0]
				await tap("bag_card_" + card_key)
				check(view().details.text.contains(" · "), "tap reveals round details")
			else: bounds("bag_empty")
			check(JSON.stringify(screen.model.s) == before, "browsing never changes turn/plan/deck/RNG")
		await tap("bag_tab_draw")
		await capture("draw_%d" % resolution.x)
		await tap("workspace_close")
		check(not is_instance_valid(screen.workspace_overlay), "close returns to battle")
		check(screen.get_viewport().gui_get_focus_owner() == screen.find_child("ammo_bag", true, false), "focus returns to bag button")
		await tap("confirm")
		check_snapshot()
		await tap("fire")
		check_snapshot()
		await tap("ammo_bag")
		await tap("bag_tab_discard")
		check(view().inventory.discard.count("basic") == 1, "fired basic appears in used pile")
		await capture("used_%d" % resolution.x)
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		Input.parse_input_event(escape)
		await settle()
		check(not is_instance_valid(screen.workspace_overlay) and screen.page == "run", "back closes bag without leaving run")
		await tap("reload")
		check_snapshot()
		await tap("ammo_bag")
		check(view().inventory.discard.size() == 5 and view().inventory.draw.is_empty(), "reload moves both used and leftover cards")
		await tap("bag_tab_draw")
		check(screen.find_child("bag_empty", true, false).text.contains("섞어서"), "empty draw explains reshuffle")
		await tap("workspace_close")
		await setup_hand(["pierce", "pierce", "basic", "charge", "push"])
		check(screen.model.field_compress("pierce"), "temporary compression setup")
		screen.redraw()
		await settle()
		check_snapshot()
		await tap("ammo_bag")
		await tap("bag_tab_loaded")
		check(view().inventory.loaded == ["pierce_f"] and view().inventory.all.count("pierce") == 7, "temporary card does not change permanent ownership")
		await capture("temporary_%d" % resolution.x)
		await tap("workspace_close")
		# Maximum owned deck, all distinct: internal scrolling must preserve the close button.
		await setup_hand(["basic", "charge", "pierce", "push", "arc"])
		screen.model.s.deck = Ammo.TACTICAL_AMMO.slice(0, 14)
		screen.model.begin_encounter()
		screen.redraw()
		await settle()
		await tap("ammo_bag")
		check(view().cards.size() == 14, "all fourteen owned types visible in scroll content")
		var last: String = view().cards.keys().back()
		await tap("bag_card_" + last)
		bounds("BagCardDetails")
		for tab in Bag.TABS: bounds("bag_tab_" + tab)
		bounds("workspace_close")
		await capture("maximum_%d" % resolution.x)
		await tap("workspace_close")
	# Legacy supply remains distinct from deck ownership.
	await setup_hand(["charge", "pierce", "push", "arc", "precise"])
	screen.model.s.erase("ammo_cycle")
	screen.model.begin_encounter()
	check_snapshot()
	screen.redraw()
	await settle()
	await tap("ammo_bag")
	check(not view().inventory.all.has("basic"), "legacy supply is not reported as an owned card")
	await tap("workspace_close")
	check(not screen.save_enabled, "personal save never written")
	screen.queue_free()
	await process_frame
	print("AMMO BAG UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
