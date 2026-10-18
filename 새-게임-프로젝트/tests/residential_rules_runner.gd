extends "res://tests/heat_rules_runner.gd"
const Roster = preload("res://redesign/residential_roster.gd")

func node_at(depth: int, seed_value: int = 731042) -> Dictionary:
	return Data.nodes(0, seed_value, 2).filter(func(n): return int(n.floor) == depth and n.kind in ["combat", "boss"])[0]

func check_reload_warning(model, expected: String) -> void:
	var before := JSON.stringify(model.s)
	var predicted := Forecast.reload_now(model.s, true)
	check(JSON.stringify(model.s) == before, "reload warning preserves state and RNG")
	check(Forecast.reload_consequence(predicted) == expected, "reload consequence " + expected)
	check(model.reload_magazine(), "execute predicted reload")
	check(predicted.enemies == model.s.enemies and predicted.projectiles == model.s.projectiles and predicted.phase == model.s.phase, "warning follows actual reload outcome")

func decision_checks() -> void:
	# Real early armor pack: a direct breakthrough and a slower burn/push route.
	var armor := Data.encounter_pack(node_at(2), 731042, "single", 0, 0, 2)
	var outcomes: Array = []
	for order in [["charge", "pierce", "basic"], ["bore", "push", "basic", "basic"]]:
		var m = fixture(order)
		m.s.enemies = armor.active.duplicate(true)
		m.assign_opening_lanes()
		fire(m, order)
		for tick in range(2):
			if m.s.enemies[0].hp > 0: check(m.reload_magazine(), "burn route paid reload")
		check(m.s.enemies[0].hp == 0 and m.s.phase != "lost", "armor has an alternative response " + str(order))
		outcomes.append({"order":order, "turns":m.s.turns, "heat":m.s.heat})
	print("ARMOR RESPONSES ", JSON.stringify(outcomes))
	var ranged := Data.encounter_pack(node_at(3), 731042, "single", 0, 0, 2)
	var quick = fixture(["charge", "precise", "pierce", "basic"])
	quick.s.enemies = ranged.active.duplicate(true)
	quick.assign_opening_lanes()
	fire(quick, ["charge", "precise", "pierce", "basic"])
	check(quick.s.phase in ["reward", "won"] and quick.s.projectile_serial == 0, "ordinary starter combination can stop launch without bypass or disruption")
	# A two-turn reload must warn even when the shooter is two ticks away.
	var m = fixture(["basic"], [["spitter", 6, 0, 0, 19]], "burst")
	check_reload_warning(m, "적 발사")
	# One-turn reload does not claim an early launch.
	m = fixture(["basic"], [["spitter", 6, 0, 0, 19]])
	check_reload_warning(m, "")
	check_reload_warning(m, "적 발사")
	check_reload_warning(m, "")
	check_reload_warning(m, "")
	check_reload_warning(m, "압력탄 임박")
	check_reload_warning(m, "피격 위험")
	# Actual burn damage and a live disruption suppress the apparent countdown.
	for burning in [true, false]:
		m = fixture(["basic"], [["spitter", 1 if burning else 6, 0, 0, 19]])
		m.s.enemies[0].ranged_left = 1
		if burning: m.s.enemies[0].burn = 1
		else:
			m.s.enemies[0].jammed = 1
			m.s.enemies[0].disrupted = true
		check_reload_warning(m, "")
	# An ordinary round can intercept; stopping the source is not mandatory.
	m = fixture(["basic"], [["spitter", 6, 0, 0, 19]])
	check(m.reload_magazine() and m.reload_magazine(), "allow actual projectile launch")
	# Keep the conserved, owned round in the next hand for the focused shot.
	if not m.s.hand.has("basic"):
		var replacement: String = m.s.hand[0]
		if m.s.draw.has("basic"):
			m.s.draw.erase("basic"); m.s.draw.append(replacement)
		else:
			m.s.discard.erase("basic"); m.s.discard.append(replacement)
		m.s.hand[0] = "basic"
	var result := fire(m, ["basic"])
	check(result[0].target >= Ranged.TARGET_BASE and Ranged.active(m.s).is_empty(), "basic intercepts pressure without a special card")
	# Same four owned rounds against an actual six-enemy wave: cooling order
	# retains a shot and avoids compulsory extra enemy actions.
	var waves := Data.encounter_pack(node_at(4), 731042, "single", 0, 0, 2)
	check(waves.active.size() == 4 and waves.reserve.size() == 2, "wave has two visible reserves in encounter count")
	var heat_results: Array = []
	for order in [["charge", "precise", "pierce", "cool"], ["charge", "precise", "cool", "pierce"]]:
		m = fixture(order)
		m.s.enemies = waves.active.duplicate(true)
		m.s.reinforcements = waves.reserve.duplicate(true)
		m.s.encounter_total = waves.total
		m.s.deployed = waves.active.size()
		m.assign_opening_lanes()
		m.s.heat = 2
		var shots := fire(m, order)
		heat_results.append({"shots":shots.size(), "turns":m.s.turns, "heat":m.s.heat})
	check(heat_results[0].shots < heat_results[1].shots and heat_results[0].turns > heat_results[1].turns, "early wave cooling order changes shots and enemy actions")
	print("EARLY WAVE RESPONSES ", JSON.stringify(heat_results))

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/residential/"):
		quit(1)
		return
	decision_checks()
	for seed_value in [17, 731042, 9182, 34021, 99]:
		for region in range(5):
			for node in Data.nodes(region, seed_value, 2):
				if node.kind not in ["combat", "boss"]: continue
				for pressure in [0, 2]:
					var pack := Data.encounter_pack(node, seed_value, "burst", 0, pressure, 2)
					check(pack == Data.encounter_pack(node, seed_value, "burst", 0, pressure, 2), "deterministic roster")
					check(pack.total == pack.active.size() + pack.reserve.size() and pack.active.size() <= 4, "four visible actors and complete reserve")
					if region > 0:
						check(pack == Data.encounter_pack(node, seed_value, "burst", 0, pressure, 1), "upper regions unchanged")
						continue
					for e in pack.active + pack.reserve:
						check(e.kind in Roster.SPECIES and e.species == Roster.SPECIES[e.kind].id, "only first-region species")
						check(not e.name.contains("시안") and not e.has("barrier"), "production name, no early barrier")
						check(e.distance >= 6 and e.distance <= 34, "approach bounds")
					if int(node.floor) < 3: check(not (pack.active + pack.reserve).any(func(e): return e.kind == "spitter"), "projectiles introduced after armor lesson")
	# New-run marker and old-run preservation including a partially loaded combat.
	var campaign = Campaign.new()
	campaign.start("burst", 731042)
	check(campaign.s.roster_version == Roster.VERSION and campaign.enter(int(campaign.choices()[0].id)), "new run enters residential encounter")
	check(campaign.model.load_round(str(campaign.model.s.hand[0])), "partial plan")
	check(campaign.save("user://new_roster.json") == OK, "save partial residential combat")
	var restored = Campaign.new()
	check(restored.restore("user://new_roster.json"), "restore residential combat")
	check(JSON.stringify(JSON.parse_string(JSON.stringify(restored.model.s))) == JSON.stringify(JSON.parse_string(JSON.stringify(campaign.model.s))), "species, plan, RNG and enemies preserved")
	var legacy: Dictionary = {"campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
	legacy.campaign.erase("roster_version")
	for e in legacy.combat.enemies:
		e.erase("species")
		e.name = Ammo.ENEMY_NAMES[e.kind]
	check(restored.restore_state(legacy) and restored.s.roster_version == 1, "markerless save keeps legacy roster")
	check(restored.model.s.enemies == legacy.combat.enemies and restored.model.s.plan == legacy.combat.plan, "old active combat untouched")
	for version in [0, Roster.VERSION + 1, 1.5, "2"]:
		legacy.campaign.roster_version = version
		check(not Campaign.new().restore_state(legacy), "bad roster marker rejected")
	# Real first-region roles, same weapon, matched rounds: armor and conductivity matter.
	var notes: Array = []
	for role in ["wall", "evader"]:
		var outcomes: Array = []
		for id in ["basic", "pierce" if role == "wall" else "arc"]:
			var model = fixture([id], [[role, 10, 3 if role == "wall" else 0, 1, 18]])
			Roster.identify(model.s.enemies[0])
			fire(model, [id])
			outcomes.append(10 - int(model.s.enemies[0].hp))
		check(outcomes[1] > outcomes[0], "matching ammunition beats basic against " + role)
		notes.append({"role": role, "basic_damage": outcomes[0], "matching_damage": outcomes[1]})
	# Exact same four cards against the actual late pack: order and initial heat.
	var pack := Data.encounter_pack(node_at(6), 731042, "single", 0, 0, 2)
	var comparisons: Array = []
	for order in [["charge_hot", "precise", "pierce", "cool"], ["charge_hot", "cool", "pierce", "precise"], ["charge_hot", "cool", "pierce"]]:
		var model = fixture(order)
		model.s.enemies = pack.active.duplicate(true)
		model.s.reinforcements = pack.reserve.duplicate(true)
		model.s.encounter_total = pack.total
		model.s.deployed = pack.active.size()
		model.assign_opening_lanes()
		model.s.heat = 2
		var results := fire(model, order)
		comparisons.append({"order": order, "shots": results.size(), "turns": model.s.turns, "reloads": model.s.reloads, "heat": model.s.heat, "kills": model.s.enemies.filter(func(e): return e.hp == 0).size(), "projectiles": model.s.projectiles.duplicate(true)})
	check(comparisons[0].shots == 2 and comparisons[1].shots == 4 and comparisons[0].turns == comparisons[1].turns, "cooling preserves shots but full overload still pays forced reload")
	check(comparisons[2].shots == 3 and comparisons[2].turns == 1 and comparisons[2].reloads == 0, "shorter cooled magazine avoids overload tempo cost")
	var report := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("choices.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"roles": notes, "heat_order": comparisons}, "  "))
	print("RESIDENTIAL RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
