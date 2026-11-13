extends "res://tests/reward_trim_ui.gd"
## Salvaged rounds (2026-11-11, salvage.gd): earned fights are won by the solver; the enemy
## killed last decides the salvage card (normal: replaces a card, elite: extra upgraded card).
const Salvage = preload("res://redesign/salvage.gd")
const Ammo = preload("res://redesign/content.gd")
const Readout = preload("res://redesign/damage_readout.gd")

func salvaged(file: String):
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))
	data.combat.salvage_version = Salvage.VERSION
	var c = Campaign.new()
	check(c.restore_state(data), "fight restores " + file)
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
	check(c.s.phase == "reward", "fight won " + file)
	return c

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	check(Salvage.round_for("wall") == "pierce" and Salvage.round_for("evader") == "arc" and Salvage.round_for("absorber") == "precise", "each kind drops its answer round")
	for kind in Ammo.ENEMY_NAMES:
		if kind == "runner": check(Salvage.round_for(kind).is_empty(), "runner (fodder) drops nothing")
		else: check(Ammo.AMMO.has(Salvage.round_for(kind)), "drop for " + str(kind))
	var fresh = Campaign.new(); fresh.start("burst", 731042, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	check(Salvage.enabled(fresh.model.s), "new runs carry salvage")
	# Normal fights.
	for file in ["combat_burst_17_r2_n10101.json", "combat_single_17_r2_n10201.json", "combat_heavy_17_r2_n10301.json"]:
		var c = salvaged(file)
		var card: Dictionary = c.salvage_card()
		var last: int = Salvage.last_kill(c.model.s)
		print("SALVAGE %s last %s → %s · cards %s" % [file, c.model.s.enemies[last].kind if last >= 0 else "-", card, c.reward_options()])
		check(last >= 0 and not card.is_empty() and str(card.id) == Salvage.round_for(str(c.model.s.enemies[last].kind)), "last kill decides the card " + file)
		check(c.reward_options().has(card.id) and c.reward_options().size() == 3, "salvage card among three cards " + file)
		var labelled := false
		for event in c.model.s.history:
			for shot in event.get("detail", {}).get("results", []):
				if not str(shot.get("salvage", "")).is_empty() and str(Readout.entry(shot).label).contains("회수 "): labelled = true
		check(labelled, "kill floats name the salvage round " + file)
		var before: int = c.model.s.deck.count(card.id)
		check(c.reward(str(card.id), "") and c.model.s.deck.count(card.id) == before + 1, "taking the salvage card adds the round " + file)
	# Old saves: no salvage.
	var old = won_fight("combat_burst_17_r2_n10101.json", false)
	check(old.salvage_card().is_empty(), "old saves: no salvage")
	# Elite: upgraded salvage next to the parts.
	var elite = salvaged("combat_burst_17_r3_n20201.json")
	if elite.node().get("elite", false):
		var card: Dictionary = elite.salvage_card()
		print("ELITE ", card, " parts ", elite.part_rewards())
		check(not card.is_empty() and elite.reward_options() == [card.id] and str(card.id) != Salvage.round_for(card.kind), "elite drops the upgraded round as an extra card")
	else: print("ELITE fixture is not an elite")
	var broken: Dictionary = JSON.parse_string(fresh.model.serialized_state())
	broken.salvage_version = 2
	check(not Campaign.Model.new().restore_state(broken), "unknown salvage version rejected")
	# Screen.
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var c = salvaged("combat_burst_17_r2_n10101.json")
		await mount(c)
		var card: Dictionary = c.salvage_card()
		var view := find("city_reward_" + str(card.id)) as Control
		# Launch pass (2026-11-12): 회수 is the corner mark; the meta line keeps the round's numbers.
		var mark := view.get_node("Quantity") as Label if view != null else null
		check(view != null and view.is_visible_in_tree() and mark != null and mark.visible and mark.text == "회수" and not (view.get_node("Meta") as Label).text.contains("회수"), "salvage card marked 회수 on screen " + suffix)
		check(view != null and (view.get_parent().get_parent() as Control).get_global_rect().grow(1).encloses(view.get_global_rect()), "salvage card fully inside the card row without scrolling " + suffix)
		await capture("salvage_reward_" + suffix)
	print("SALVAGE UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
