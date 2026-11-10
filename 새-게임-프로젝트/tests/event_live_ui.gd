extends "res://tests/supply_live_ui.gd"
## Event (조우) scene in the main game (2026-11-08). Fresh runs walk to the first
## region-1 event through real combats and rewards (save-valid states). Seeds are
## scanned until a result choice (credits/lore), an ambush and a found-rounds choice
## are all available; every event input is a touch on the real screen.
const Encounters = preload("res://redesign/encounter_scenes.gd")
const EventView = preload("res://redesign/samples/event_review/preview.gd")

func find(id: String) -> Control:
	var scene: Node = host.find_child("EventScreen", true, false)
	if scene != null and id != "EventScreen":
		var inside: Node = scene.find_child(id, true, false)
		if inside != null: return inside as Control
	return host.find_child(id, true, false) as Control

func reach_event(seed_value: int):
	var c = Campaign.new()
	c.start("single", seed_value, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	while c.departure_pending(): c.advance_departure(true)
	var nodes: Array = c.current_nodes()
	var events: Array = nodes.filter(func(n): return n.kind == "event")
	if events.is_empty(): return null
	var target: int = int(events[0].id)
	for step in range(60):
		if c.s.phase == "event" and int(c.s.node) == target: return c
		match str(c.s.phase):
			"map":
				var next: Array = c.choices().filter(func(n): return reaches(nodes, int(n.id), target))
				if next.is_empty() or not c.enter(int(next[0].id)): return null
			"combat":
				var path: Array = solver.solve(c.model, 4, 18)
				if path.is_empty(): return null
				for item in path:
					match str(item.action):
						"fire": c.model.fire()
						"reload": c.model.reload_magazine()
						"cool": c.model.cool_magazine()
						"eject": c.model.eject_magazine_rounds(item.indices)
						"emergency": c.model.emergency_resupply()
					c.sync_combat()
			"reward":
				var parts: Array = c.part_rewards()
				var ammo: Array = c.reward_options()
				var taken := false
				if not parts.is_empty(): taken = c.reward(str(parts[0]), "")
				elif not ammo.is_empty() and c.first_ammo_reward(): taken = c.reward(str(ammo[0]), "")
				if not taken: taken = c.reward("credits", "")
				if not taken: return null
			_:
				if c.s.phase in ["supply", "event"] and not c.s.resolved: c.resolve("skip")
				if not c.leave(): return null
	return null

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	# case name -> {data, choice}
	var cases: Dictionary = {}
	for seed_value in range(251107, 251147):
		if cases.has("result") and cases.has("combat") and cases.has("ammo"): break
		var c = reach_event(seed_value)
		if c == null: continue
		var kind := str(c.node().event)
		for option in Encounters.scene(kind).choices:
			if int(c.s.credits) < int(option.cost): continue
			var type := str(Encounters.outcome(kind, str(option.id), int(c.s.seed), int(c.s.node)).get("type", ""))
			var case_name := "result" if type in ["credits", "lore"] else type
			if case_name in ["result", "combat", "ammo"] and not cases.has(case_name):
				cases[case_name] = {"data": snapshot(c), "choice": str(option.id), "kind": kind, "seed": seed_value}
	print("EVENT CASES ", cases.keys(), " ", cases.values().map(func(v): return [v.kind, v.choice, v.seed]))
	for case_name in ["result", "combat", "ammo"]: check(cases.has(case_name), "found a walked event with a %s choice" % case_name)
	if cases.has("result"):
		var data: Dictionary = cases.result.data
		check(Campaign.new().restore_state(data.duplicate(true)), "walked event state is save-valid")
		for extent in [Vector2i(1280, 800), Vector2i(844, 390), Vector2i(1008, 454)]:
			root.size = extent
			var suffix := "%dx%d" % [extent.x, extent.y]
			var c = restored(data)
			await mount(c)
			var scene := find("EventScreen")
			check(scene != null and scene.is_visible_in_tree(), "event scene replaces the old event screen " + suffix)
			check(find("CampaignShellHeader") == null, "old shell header is gone")
			check(scene != null and root.get_visible_rect().grow(1).encloses(scene.get_global_rect()), "event fits the screen " + suffix)
			check(find("Choices").get_child_count() == 2, "two real choices")
			await capture("choose_" + suffix)
			await tap("Choice_" + cases.result.choice)
			check(c.s.resolved and find("Primary").text == "지도로 계속", "result shows one way on")
			check(saved().s.resolved, "choice is autosaved")
			await capture("result_" + suffix)
			await tap("Primary")
			check(c.s.phase == "map" and find("PipeMapScreen") != null, "leaving returns to the map " + suffix)
		root.size = Vector2i(1280, 800)
		var passing = restored(data)
		await mount(passing)
		await tap("Pass")
		check(passing.s.resolved and passing.s.encounter.choice == "skip", "passing by resolves")
		var menu = restored(data)
		await mount(menu)
		await tap("Menu")
		check(find("UtilityMenu").is_visible_in_tree(), "utility menu opens")
		await tap("Build")
		check(find("WorkspaceOverlay") != null, "build workspace opens over the event")
		host._close_workspace(); await settle()
		check(find("EventScreen") != null, "event stays after closing build")
	root.size = Vector2i(1280, 800)
	if cases.has("combat"):
		var ambush = restored(cases.combat.data)
		await mount(ambush)
		await tap("Choice_" + cases.combat.choice)
		check(ambush.s.encounter.stage == "ambush" and find("Primary").text == "전투 준비", "risky choice reveals an ambush")
		await capture("ambush_1280x800")
		check(saved().s.encounter.stage == "ambush", "ambush is autosaved")
		var resumed = saved()
		await mount(resumed)
		check(find("EventScreen").encounter_stage() == "ambush" and find("Primary").text == "전투 준비", "resume opens on the ambush")
		await tap("Primary")
		check(resumed.s.phase == "combat" and is_instance_valid(host.campaign_hud), "fight starts the real battle HUD")
		await capture("ambush_battle_1280x800")
	if cases.has("ammo"):
		var loot = restored(cases.ammo.data)
		await mount(loot)
		await tap("Choice_" + cases.ammo.choice)
		check(loot.s.encounter.stage == "loot" and find("Shelf").is_visible_in_tree(), "found rounds on the shelf")
		var offer: String = str(loot.reward_options()[0])
		var count: int = loot.model.s.deck.size()
		await tap("Offer_" + offer)
		await capture("loot_1280x800")
		await tap("Primary")
		check(loot.s.resolved and loot.model.s.deck.size() == count + 1, "found round added once")
		check(saved().model.s.deck.size() == count + 1, "found round is autosaved")
		# Swap with a full bag.
		var filler = restored(cases.ammo.data)
		check(filler.resolve("encounter", cases.ammo.choice), "stage the loot")
		while filler.model.s.deck.size() < filler.model.deck_limit(): filler.model.s.deck.append("basic_p2")
		filler.normalize_for_save()
		var full = Campaign.new()
		if check(full.restore_state(snapshot(filler)), "full-bag loot restores"):
			await mount(full)
			var pick: String = str(full.reward_options()[0])
			var total: int = full.model.s.deck.size()
			var basics: int = full.model.s.deck.count("basic_p2")
			await tap("Offer_" + pick)
			check(find("Primary").disabled and find("Secondary").text == "교체해서 확보", "full bag offers swap only")
			await tap("Secondary")
			await tap("Stack_basic_p2")
			await capture("loot_swap_1280x800")
			await tap("Primary")
			check(full.s.resolved and full.model.s.deck.size() == total and full.model.s.deck.count("basic_p2") == basics - 1, "swap keeps the total")
	print("EVENT LIVE UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
