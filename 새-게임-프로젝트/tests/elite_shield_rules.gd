extends "res://tests/fire_heat_rules.gd"

const ShieldData = preload("res://redesign/samples/elite_shield_trial_data.gd")
const House = ShieldData.House

func fire_one(m) -> Dictionary:
	m.s.fire_heat_trial.rounds = 1
	return verify_fire(m).results[0]

func no_iron_victory() -> void:
	var m = ShieldData.make(House.PIERCE_ONLY, ["basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p2"]).model
	check(m.reload_magazine() and m.s.enemies[0].barrier == 0, "a normal two-action magazine swap opens strict shield with no iron")
	for action in range(14):
		if m.s.phase != "ready": break
		if m.s.magazine.is_empty() or (m.s.enemies[0].hp > 0 and m.s.enemies[0].barrier > 0):
			if m.s.heat > 0 and not m.s.magazine.is_empty():
				check(m.cool_magazine(), "basic deck waits with real cooling")
			else:
				check(m.reload_magazine(), "basic deck waits with real replacement")
		else:
			m.s.fire_heat_trial.rounds = 2
			verify_fire(m)
	check(m.s.phase == "reward" and not m.s.deck.any(func(id): return Content.source_id(id) == "pierce"), "strict trial is winnable with a legal deck of only basic rounds")

func check_campaign_elite() -> void:
	var campaign := ShieldData.enter_elite()
	check(campaign != null, "enter a real elite node")
	if campaign == null: return
	var model = campaign.model
	var elite: Dictionary = model.s.enemies[0]
	check(model.s.encounter_total == 6 and elite.species == House.ELITE and not elite.has("shield_trial"), "campaign enters the full elite formation without a trial marker")
	check(elite.barrier == 3 and elite.shield_open_left == 2, "live elite spawns with three shield stacks and two actions")
	var other_enemies: Array = model.s.enemies.slice(1) + model.s.reinforcements
	check(other_enemies.all(func(e): return House.shield_rule(e).is_empty()), "other enemies retain their original shield rules")
	var legacy_path := output.path_join("live_elite_legacy.json")
	elite.erase("shield_open_left")
	check(campaign.save(legacy_path) == OK, "previous mid-encounter shape can be saved")
	var legacy := ShieldData.Campaign.new()
	check(legacy.restore(legacy_path) and House.strip(legacy.model.s.enemies[0], 1, "basic") == 1, "an already-started legacy battle resumes with its original shield")
	elite.shield_open_left = House.SHIELD_OPEN_DELAY
	fire_one(model)
	check(elite.barrier == 3 and elite.shield_open_left == 1, "first live action advances the countdown")
	var path := output.path_join("live_elite_countdown.json")
	check(campaign.save(path) == OK, "live elite countdown saves through campaign")
	var resumed := ShieldData.Campaign.new()
	var restored := resumed.restore(path)
	check(restored, "live elite save resumes")
	if not restored: return
	var resumed_elite: Dictionary = resumed.model.s.enemies[0]
	check(resumed_elite.shield_open_left == 1 and resumed.model.cool_magazine(), "cooling after resuming spends the remaining guard action")
	check(resumed_elite.barrier == 0 and resumed_elite.exposure_left == 3, "resumed live elite opens on schedule")

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/elite_shield_trial/"): quit(2); return
	var a := ShieldData.make(House.PIERCE_WEAK)
	var b := ShieldData.make(House.PIERCE_ONLY)
	if a == null or b == null: push_error("could not enter the elite trial room"); quit(2); return
	check(a.s.node == b.s.node and a.model.s.magazine == b.model.s.magazine and a.model.s.enemies[0].hp == b.model.s.enemies[0].hp, "A/B starts with identical room, magazine and HP")
	var a_round := fire_one(a.model)
	var b_round := fire_one(b.model)
	check(a_round.barrier_removed == 1 and a_round.damage == 0 and a.model.s.enemies[0].barrier == 2, "A ordinary hit chips one stack")
	check(b_round.barrier_removed == 0 and b_round.damage == 0 and b.model.s.enemies[0].barrier == 3 and b.model.s.enemies[0].shield_open_left == 1, "B ordinary hit leaves shield intact and only elapsed action advances its timer")
	var path := output.path_join("strict_mid_guard.json")
	check(b.save(path) == OK, "campaign saves strict guard countdown")
	var resumed = ShieldData.Campaign.new()
	check(resumed.restore(path) and int(resumed.model.s.enemies[0].shield_open_left) == 1, "campaign restores the exact countdown")
	check(b.model.cool_magazine() and int(b.model.s.enemies[0].exposure_left) == 3, "second enemy action opens strict shield for three actions")
	check(fire_one(b.model).damage > 0, "normal bullet damages the exposed body")
	var events: Array = b.model._advance(2)
	check(b.model.s.enemies[0].barrier == 3 and b.model.s.enemies[0].shield_open_left == 2 and events.any(func(event): return event.kind == "noble_state" and event.action == "rearm"), "rearm resets all stacks and starts a fresh countdown")
	for variant in [House.PIERCE_WEAK, House.PIERCE_ONLY]:
		for id in ["pierce", "pierce_p2", "pierce_c"]:
			var m = ShieldData.make(variant, [id, "basic_p2"]).model
			var shot := fire_one(m)
			check(shot.barrier_removed == 2 and shot.damage == 0, "%s strips two without carrying through in %s" % [id, variant])
	var m = ShieldData.make(House.PIERCE_WEAK, ["precise", "basic_p2"]).model
	m.s.enemies[0].barrier = 1
	var partial := fire_one(m)
	check(partial.barrier_removed == 1 and partial.blocked_hits == 1 and partial.damage > 0, "following hit of one multi-hit round damages the opened body")
	m = ShieldData.make(House.PIERCE_ONLY, ["arc", "basic_p2"]).model
	m.s.equipped_parts = ["breaker"]
	check(fire_one(m).barrier_removed == 0, "electric hit and breaker cannot strip a strict shield")
	var invalid: Dictionary = canonical(m.s)
	invalid.enemies[0].shield_open_left = 0
	check(not Model.new().restore_state(invalid), "a closed strict shield with zero countdown is invalid")
	no_iron_victory()
	check_campaign_elite()
	print("ELITE SHIELD RULES COMPLETE checks=%d failures=%d" % [checks, failures.size()]); quit(0 if failures.is_empty() else 1)
