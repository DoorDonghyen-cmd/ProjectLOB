extends "res://tests/supply_live_ui.gd"
## Normal-fight reward row "remove one round" (2026-11-11, reward_trim.gd). Earned region-2
## fights are won by the solver to reach the real reward screen; rules and screen taps.
const RewardTrim = preload("res://redesign/reward_trim.gd")
const FireSolver = preload("res://tests/fire_control_solver.gd")

func won_fight(file: String, flag := true):
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))), "earned fight restores " + file)
	if flag: c.model.s.reward_trim_version = RewardTrim.VERSION
	var path: Array = FireSolver.new().solve(c.model)
	for item in path:
		match str(item.action):
			"fire":
				c.model.s.fire_heat_trial.rounds = int(item.get("rounds", 0)); c.model.fire()
			"reload": c.model.reload_magazine()
			"cool": c.model.cool_magazine()
			"eject": c.model.eject_magazine_rounds(item.indices)
			"emergency": c.model.emergency_resupply()
		c.sync_combat()
	check(c.s.phase == "reward", "fight won into the reward " + file)
	return c

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	# Rules.
	check(RewardTrim.options(["pierce", "basic_p2", "basic_p3", "basic_p2", "charge"]) == ["basic_p2", "basic_p3", "charge", "pierce"], "options: basic first, then most held")
	var fresh = Campaign.new(); fresh.start("single", 731042, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	check(RewardTrim.enabled(fresh.model.s), "new runs carry the trim reward")
	var plain = won_fight("combat_burst_17_r2_n10101.json", false)
	check(not plain.can_trim_reward() and not plain.reward("trim", "basic_p2"), "older saves keep the old reward")
	var rules = won_fight("combat_burst_17_r2_n10101.json")
	check(rules.can_trim_reward() and not rules.trim_reward_options().is_empty(), "normal fight offers the trim row")
	var before: Array = rules.model.s.deck.duplicate()
	var target := str(rules.trim_reward_options()[0])
	check(not rules.reward("trim", "not_a_round"), "trim needs an owned round")
	check(rules.reward("trim", target) and rules.model.s.deck.size() == before.size() - 1 and rules.model.s.deck.count(target) == before.count(target) - 1 and rules.s.phase == "map", "trim removes one owned round and ends the reward")
	var low = won_fight("combat_burst_17_r2_n10101.json")
	while low.model.s.deck.size() > low.minimum_deck(): low.model.s.deck.pop_back()
	check(not low.can_trim_reward() and not low.reward("trim", str(low.model.s.deck[0])), "never below the deck minimum")
	# Screen.
	# 844x390 diagnostic: is the bottom row cut without the new button too (an older layout limit)?
	root.size = Vector2i(844, 390)
	var old_layout = won_fight("combat_burst_17_r2_n10101.json", false)
	await mount(old_layout)
	var old_confirm := find("Confirm") as Control
	print("DIAG 844x390 without trim: Confirm on screen = ", old_confirm != null and root.get_visible_rect().grow(1).encloses(old_confirm.get_global_rect()))
	await capture("reward_old_844x390")
	# Sizes the reward screen is checked at (reward_live_runner): phone landscape and desktop.
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454), Vector2i(2340, 1080), Vector2i(740, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var c = won_fight("combat_burst_17_r2_n10101.json")
		await mount(c)
		# The trim choice is the last reward card (the card row scrolls on narrow screens).
		var trim := find("city_reward_trim") as Button
		check(trim != null and trim.is_visible_in_tree() and trim.get_index() == 0 and root.get_visible_rect().grow(1).encloses(trim.get_global_rect()), "탄 1장 빼기 is the first card, on screen without scrolling " + suffix)
		check(not trim.button_pressed and find("Confirm").text != "뺄 탄 고르기", "the first round stays selected " + suffix)
		var tray := find("Tray") as Control
		check(tray != null and root.get_visible_rect().grow(1).encloses(tray.get_global_rect()), "tray stays on screen " + suffix)
		await capture("reward_rows_" + suffix)
		await tap("city_reward_trim")
		check(find("Confirm").text == "뺄 탄 고르기", "trim card leads to picking " + suffix)
		await tap("Confirm")
		var first := str(c.trim_reward_options()[0])
		check(find("ammo_replace_" + first) != null, "trim list starts with " + first + " " + suffix)
		await tap("ammo_replace_" + first)
		await capture("reward_trim_pick_" + suffix)
		var count: int = c.model.s.deck.count(first)
		var size: int = c.model.s.deck.size()
		await tap("Confirm")
		check(c.s.phase == "map" and c.model.s.deck.count(first) == count - 1 and c.model.s.deck.size() == size - 1, "screen trim removed one " + first + " " + suffix)
		check(saved().model.s.deck.size() == size - 1, "trim saved " + suffix)
		# Elites keep their parts-or-credits reward without the row.
	print("REWARD TRIM UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
