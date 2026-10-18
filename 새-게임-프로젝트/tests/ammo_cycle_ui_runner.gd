extends "res://tests/ammo_grade_ui_runner.gd"

func setup_hand(ids: Array, full: bool = false) -> void:
	screen.campaign = Campaign.new()
	screen.campaign.start("single", 731042)
	screen.campaign.enter(int(screen.campaign.choices()[0].id))
	screen.campaign.s.phase = "combat"
	screen.model = screen.campaign.model
	screen.model.s.deck = ids.duplicate()
	while screen.model.s.deck.size() < 10: screen.model.s.deck.append("pierce")
	if full:
		screen.model.s.bag_upgrades = 5
		screen.campaign.s.bag_upgrades = 5
	screen.model.begin_encounter()
	screen.model.s.hand = ids.duplicate()
	screen.model.s.draw = screen.model.s.deck.duplicate()
	for id in ids: screen.model.s.draw.erase(id)
	screen.model.s.enemies = [Data._enemy(["wall", 90, 0, 1, 24])]
	screen.model.s.encounter_total = 1
	screen.model.s.deployed = 1
	screen.model.assign_opening_lanes()
	screen.page = "run"
	screen.debug_session = true
	screen.hand_layout_key = ""
	screen.redraw()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_cycle/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1440, 630)]:
		root.size = resolution
		screen._open_preparation(false)
		await settle()
		bounds("starting_detail_basic")
		await capture("starter_%d" % resolution.x)
		await setup_hand(["basic", "basic", "charge", "pierce", "push"])
		cards_fit()
		bounds("reload")
		bounds("load_basic")
		bounds("load_basic_2")
		check(screen._hand_entries().size() == 5, "five cards include both basic copies")
		await capture("hand_%d" % resolution.x)
		await tap("load_basic_2")
		check(screen.model.s.plan == ["basic"], "second basic is one bullet")
		check(screen.find_child("load_basic_2", true, false).disabled and not screen.find_child("load_basic", true, false).disabled, "chosen copy alone becomes held")
		await tap("load_basic")
		check(screen.model.available("basic") == 0 and screen.model.s.plan.size() == 2, "two copies limit two shots")
		await tap("remove_selected")
		check(screen.model.available("basic") == 1, "one copy returned")
		await tap("load_charge")
		check(screen.model.s.plan == ["charge", "basic"], "LIFO retained")
		await capture("planned_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.discard.has("basic"), "fired basic cycles")
		await tap("reload")
		check(screen.model.s.hand.size() == 5 and screen.model.s.supply == 0, "normal reload finite hand")
		await setup_hand(["basic", "basic", "charge", "pierce", "push"])
		screen._exchange_dialog()
		await settle()
		await tap("exchange_basic")
		check(screen.model.s.hand.count("basic") == 1 and screen.model.s.discard.count("basic") == 1, "basic exchanges through real input")
		await setup_hand(["charge", "charge", "cool", "shatter", "prepare"])
		check(screen.find_child("load_basic", true, false) == null, "no guaranteed basic card")
		var turns_before: int = screen.model.s.turns
		await capture("support_hand_%d" % resolution.x)
		await tap("reload")
		check(screen.model.s.turns == turns_before + 1 and screen.model.s.hand.count("pierce") == 5, "support hand can pay time to cycle")
		await setup_hand(["basic", "basic", "basic", "charge", "precise", "pierce", "arc", "push", "bore", "cool"], true)
		cards_fit()
		await tap("hand_next")
		var visible: Array = []
		for b in screen.find_child("AmmoGrid", true, false).get_children():
			if b.visible: visible.append(str(b.name))
		check(visible.size() == 4, "ten actual cards span six plus four")
		await capture("page2_%d" % resolution.x)
		await tap(visible.back())
		check(screen.model.s.plan.size() == 1, "last card accessible")
	check(not screen.save_enabled, "isolated UI save")
	screen.queue_free()
	await process_frame
	print("AMMO CYCLE UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
