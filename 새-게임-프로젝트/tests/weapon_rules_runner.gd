extends SceneTree
## Boundary tests execute actual commands; scatter forecast is audited as a distribution.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Readability = preload("res://redesign/readability.gd")
const Insight = preload("res://redesign/run_insight.gd")
var checks := 0
var failures: Array = []
var measurements: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: " + label)

func enemy(hp: int = 100, armor: int = 0, distance: int = 20) -> Dictionary:
	return {"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": hp, "max_hp": hp, "def": armor, "speed": 1, "distance": distance, "burn": 0}

func fixture(gun: String, enemies: Array, rounds: Array = ["basic"], seed_value: int = 731042):
	var model = Model.new()
	model.start(gun, seed_value)
	model.s.deck = ["charge", "precise", "pierce", "bore", "arc", "push"]
	model.s.hand = []
	for id in rounds:
		if id == "basic": continue
		if model.s.hand.count(id) >= model.s.deck.count(id): model.s.deck.append(id)
		model.s.hand.append(id)
	for id in model.s.deck:
		if model.s.hand.size() < 5 and not model.s.hand.has(id): model.s.hand.append(id)
	model.s.draw = model.s.deck.duplicate()
	for id in model.s.hand: model.s.draw.erase(id)
	model.s.discard = []
	model.s.enemies = enemies.duplicate(true)
	for id in rounds: check(model.load_round(id), "fixture load " + gun + "/" + id)
	return model

func fire(model) -> Array:
	if model.s.phase == "plan": check(model.confirm(), "confirm fixture")
	check(model.fire(), "fire fixture")
	return model.s.history.back().detail.results

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(Content.GUNS.size() == 5, "five playable weapon archetypes")
	for gun in Content.GUNS:
		var campaign = Campaign.new()
		campaign.start(gun, 731042)
		check(campaign.model.s.deck == Content.start_deck(gun) and campaign.model.s.deck.size() == 10, "weapon starting deck " + gun)
		campaign.profile.unlocks = Data.LOADOUTS.keys()
		for loadout in Data.LOADOUTS:
			campaign.start(gun, 731042, 0, loadout)
			check(campaign.model.s.deck == (Content.start_deck(gun) if loadout == "balanced" else Data.LOADOUTS[loadout].deck), "sidegrades " + gun)
		for bonus in range(3):
			campaign.model.s.capacity_bonus = bonus
			check(campaign.model.capacity() == int(Content.GUNS[gun].capacity) + bonus, "capacity growth " + gun)
		var seen_parts: Array = []
		for revision in range(12):
			for offer in Data.offers({"id": 401}, 731042, revision, gun, []):
				if offer.type == "part":
					check(Content.accepts_part(gun, offer.id) and offer.id != "supply", "eligible city shop " + gun)
					if not seen_parts.has(offer.id): seen_parts.append(offer.id)
		check(seen_parts.has("loader") == (gun in ["burst", "scatter"]), "loader useful shop stock " + gun)
		check(Content.accepts_part(gun, "loader") == (gun in ["burst", "scatter"]), "loader eligibility " + gun)
		var tempo = fixture(gun, [enemy()], ["basic", "basic", "basic"])
		var shots := fire(tempo)
		check(shots.size() == (1 if gun == "amplifier" else 3), "whole magazine versus single " + gun)
		check(tempo.s.turns == 1 and tempo.s.enemies[0].distance == 19, "one enemy advance per fire " + gun)
		var model = fixture(gun, [enemy(), enemy(100, 1, 22), enemy(100, 2, 23)], ["charge", "precise", "arc"])
		for part in ["none", "lens", "coil"]:
			model.s.part = part
			var before := JSON.stringify(model.s)
			var prediction := Forecast.analyze(model.s)
			check(JSON.stringify(model.s) == before, "forecast never changes state or RNG " + gun)
			var actual = Model.new()
			actual.s = model.s.duplicate(true)
			check(actual.confirm(), "confirm clone")
			var actual_shots: Array = []
			while actual.fire():
				actual_shots.append_array(actual.s.history.back().detail.results)
			if gun == "scatter":
				check(prediction.random and prediction.shots[0].target == -1 and prediction.shots[0].secondary.is_empty(), "random preview conceals future target")
				for i in range(actual.s.enemies.size()):
					check(actual.s.enemies[i].hp >= prediction.enemies[i].hp_min and actual.s.enemies[i].hp <= prediction.enemies[i].hp_max, "random actual HP lies in forecast")
			else:
				check(actual_shots.size() == prediction.shots.size(), "exact forecast shot count " + gun)
				for i in range(actual_shots.size()):
					var expected: Dictionary = prediction.shots[i].duplicate(true)
					expected.erase("action")
					check(actual_shots[i] == expected, "exact shot forecast " + gun)
				check(actual.s.enemies == prediction.enemies and actual.s.phase == prediction.phase, "exact final forecast " + gun)
			check(Model.new().restore_state(actual.s), "battle restores " + gun)
	# Independent numeric contracts, including part stacking and armor subtraction.
	for gun in Content.GUNS:
		for armor in range(8):
			for id in ["basic", "pierce", "precise"]:
				var model = fixture(gun, [enemy(100, armor)], [id])
				model.s.part = "lens"
				var shot: Dictionary = fire(model)[0]
				var raw: int = {"basic": 4, "pierce": 3, "precise": 2}[id] * (2 if gun == "amplifier" else 1) + (1 if gun == "single" else 0)
				var pen: int = (3 if id == "pierce" else 0) * (2 if gun == "amplifier" else 1) + 1
				var expected := maxi(1, raw - maxi(0, armor - pen)) * (2 if id == "precise" else 1)
				check(shot.damage == expected and shot.pen == pen, "raw/armor/lens contract " + gun + "/" + id + "/" + str(armor))
	# Focus counts actual primary hits, retains across reload, and never spills on death.
	var focus = fixture("burst", [enemy()], ["precise", "basic"])
	var focused := fire(focus)
	check(focused[0].hits == 2 and focused[0].focus_after == 2 and focused[1].focus_damage == 4 and focused[1].focus_after == 0, "double hit completes focus with third main hit")
	check(focus.s.enemies[0].hp == 88 and focused[1].damage == 8, "focus fixed four damage")
	check(Insight.combat_report(focus.s).focus == 4, "debrief focus is subset of direct damage")
	focus = fixture("burst", [enemy()], ["basic", "basic"])
	fire(focus)
	check(focus.reload_magazine(), "focus reload")
	check(focus.s.enemies[0].focus_hits == 2, "focus survives reload")
	check(focus.load_round("basic"), "focus reload bullet")
	check(fire(focus)[0].focus_damage == 4, "focus resumes after reload")
	focus = fixture("burst", [enemy(1), enemy(30, 0, 22)], ["precise", "precise", "basic"])
	focused = fire(focus)
	check(focused[0].hits == 1 and focused[0].focus_after == 1 and focused[0].damage == 1, "dead target gets no phantom second hit")
	check(focused[1].focus_after == 2 and focused[2].focus_damage == 4, "new target has independent focus")
	focus = fixture("burst", [enemy(8), enemy(30, 0, 22)], ["precise", "basic"])
	focused = fire(focus)
	check(focused[1].focus_triggers == 1 and focused[1].focus_damage == 0 and focus.s.enemies[1].hp == 30, "lethal third hit bonus cannot spill")
	focus = fixture("burst", [enemy(), enemy(100, 0, 22)], ["bore", "arc"])
	fire(focus)
	check(focus.s.enemies[0].focus_hits == 2 and focus.s.enemies[1].get("focus_hits", 0) == 0, "burn and transferred damage never increment focus")
	focus = fixture("burst", [enemy(), enemy(100, 0, 21)], ["push", "basic", "basic"])
	focused = fire(focus)
	check(focused[0].target == 0 and focused[1].target == 1 and focus.s.enemies[0].focus_hits == 1 and focus.s.enemies[1].focus_hits == 2, "focus retains separate target counters when push changes closest")
	# Element specialist and amplifier change strength, never duration or hit count.
	for gun in ["single", "heavy", "amplifier"]:
		var burning = fixture(gun, [enemy()], ["bore"])
		var shot: Dictionary = fire(burning)[0]
		check(shot.burn_added == 3 and burning.s.enemies[0].burn == 2, "burn duration stays three " + gun)
		check(burning.s.enemies[0].hp == 100 - shot.damage - (1 if gun == "single" else 2), "burn tick strength " + gun)
		burning = fixture(gun, [enemy()], ["bore"])
		burning.s.part = "coil"
		check(fire(burning)[0].burn_added == 4, "coil increases duration by one " + gun)
		var transfer = fixture(gun, [enemy(), enemy(100, 9, 22)], ["arc"])
		shot = fire(transfer)[0]
		check(shot.secondary.size() == 1 and shot.secondary[0].damage == {"single": 2, "heavy": 3, "amplifier": 4}[gun], "fixed transfer ignores secondary armor " + gun)
	var amplified = fixture("amplifier", [enemy()], ["charge", "precise", "basic"])
	var first: Dictionary = fire(amplified)[0]
	var second: Dictionary = fire(amplified)[0]
	var third: Dictionary = fire(amplified)[0]
	check(first.damage == 2 and first.boost_granted == 4 and second.hits == 2 and second.damage == 16 and third.damage == 12, "amplifier base double and next-two buff applied once")
	check(not amplified.s.buff.has("dmg") and amplified.s.turns == 3, "amplifier keeps hit count, buff count and single timing")
	var pushing = fixture("amplifier", [enemy()], ["push"])
	check(fire(pushing)[0].push == 4 and pushing.s.push_left == 0 and pushing.s.enemies[0].distance == 23, "amplifier four meter shared magazine budget")
	check(pushing.reload_magazine() and pushing.s.push_left == 4, "amplifier push budget resets on reload")
	# Random bullets choose living enemies at each bullet, not distance spread.
	var random = fixture("scatter", [enemy(4), enemy(4, 0, 22)], ["basic", "basic"])
	var prediction := Forecast.analyze(random.s)
	check(is_equal_approx(float(prediction.win_probability), 1.0) and prediction.enemies[0].hp_max == 0, "lethal rounds always retarget survivors")
	var random_shots := fire(random)
	check(random_shots.size() == 2 and random_shots[0].target != random_shots[1].target and random.s.phase == "reward", "actual lethal bullet retargets survivor")
	check(random.s.history.back().detail.advance_events.is_empty(), "clear has no extra enemy advance")
	random = fixture("scatter", [enemy(8), enemy(8, 0, 100)], ["basic", "basic"])
	prediction = Forecast.analyze(random.s)
	check(is_equal_approx(float(prediction.win_probability), 0.0) and is_equal_approx(float(prediction.enemies[0].kill_probability), 0.25), "two shots exact one-enemy kill probability quarter")
	check(prediction.enemies[0].hp_min == 0 and prediction.enemies[0].hp_max == 8 and prediction.shots[0].damage_min == 4, "exact random HP ranges")
	check(is_equal_approx(float(prediction.shots[0].targets[0].probability), 0.5), "primary uniform independent of distance")
	var concealed: Dictionary = random.s.duplicate(true)
	concealed.target_rng_state = "12345"
	check(Forecast.analyze(concealed) == prediction and random.preview().is_empty(), "different hidden target RNG gives identical public forecast")
	random = fixture("scatter", [enemy(8, 0, 1), enemy(8, 0, 100)], ["basic", "basic"])
	prediction = Forecast.analyze(random.s)
	check(is_equal_approx(float(prediction.lost_probability), 0.75), "random contact risk exact including lethal closest branch")
	var hits_by_target := [0, 0, 0]
	for seed_value in range(240):
		random = fixture("scatter", [enemy(), enemy(100, 0, 100), enemy(100, 0, 200)], ["precise"], seed_value)
		var draw_rng: String = random.s.rng_state
		var shot: Dictionary = fire(random)[0]
		hits_by_target[shot.target] += 1
		check(shot.hits == 2 and shot.damage == 4 and shot.secondary.is_empty(), "double stays one target without spread")
		check(random.s.rng_state == draw_rng, "target RNG never consumes draw RNG")
		check(random.s.enemies.filter(func(e): return e.hp == 96).size() == 1, "double changes exactly one enemy")
	check(hits_by_target.min() > 45 and hits_by_target.max() < 115, "seeded random target coverage")
	measurements.target_counts = hits_by_target
	for seed_value in range(60):
		random = fixture("scatter", [enemy(8), enemy(8, 2, 22), enemy(5, 0, 23)], ["charge", "precise", "arc"], seed_value)
		var before: Dictionary = random.s.duplicate(true)
		prediction = Forecast.analyze(random.s)
		var restored = Model.new()
		check(restored.restore_state(before), "scatter restore before fire")
		fire(random)
		fire(restored)
		check(random.s.enemies == restored.s.enemies and random.s.target_rng_state == restored.s.target_rng_state, "saved scatter RNG replays exact results")
		for i in range(3):
			check(random.s.enemies[i].hp >= prediction.enemies[i].hp_min and random.s.enemies[i].hp <= prediction.enemies[i].hp_max, "many-seed random forecast contains actual")
	# Maximum-size scatter distribution and cached redraw cost.
	random = fixture("scatter", [enemy(), enemy(100, 2, 22), enemy(100, 1, 23)], ["charge", "precise", "bore", "arc", "push"])
	random.s.capacity_bonus = 2
	random.s.supply = 7
	for id in ["basic", "basic"]: check(random.load_round(id), "seven slot fixture")
	var started := Time.get_ticks_msec()
	prediction = Forecast.analyze(random.s)
	measurements.seven_slot_ms = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	for i in range(100): Forecast.analyze(random.s)
	measurements.cached_100_ms = Time.get_ticks_msec() - started
	check(prediction.shots.size() == 7 and measurements.seven_slot_ms < 2000 and measurements.cached_100_ms < 1000, "seven slot forecast bounded and redraw cached")
	measurements.seven_slot_branches = prediction.branches
	# Legacy combat-only supply part may add an eighth slot; city excludes this part.
	random.s.part = "supply"
	random.s.supply = 8
	check(random.load_round("basic") and random.capacity() == 8, "legacy eighth scatter slot")
	started = Time.get_ticks_msec()
	prediction = Forecast.analyze(random.s)
	measurements.legacy_eight_slot_ms = Time.get_ticks_msec() - started
	check(prediction.shots.size() == 8 and measurements.legacy_eight_slot_ms < 3000, "legacy eight slot forecast bounded")
	for phase in ["lost", "reward", "won"]:
		var terminal: Dictionary = random.s.duplicate(true)
		terminal.magazine = terminal.plan.duplicate()
		terminal.plan = []
		terminal.phase = phase
		var terminal_forecast := Forecast.analyze(terminal)
		check(terminal_forecast.shots.is_empty() and terminal_forecast.turns == 0 and terminal_forecast.enemies == terminal.enemies and terminal_forecast.phase == phase, "terminal random state cannot forecast future firing")
	var amp_note = fixture("amplifier", [enemy()], ["charge"])
	check(Forecast.note(Forecast.analyze(amp_note.s), 0) == "다음 2발 +4", "amplifier forecast shows actual boost strength")
	for gun in ["heavy", "amplifier"]:
		var lesson_state := {"gun": gun, "floor": 2}
		check(Content.lesson(lesson_state).contains("턴당 2피해"), "lesson reflects enhanced burn " + gun)
	# Save migration and corrupt state rejection are transactional.
	var saved: Dictionary = random.s.duplicate(true)
	for old_version in [2, 3]:
		var legacy: Dictionary = saved.duplicate(true)
		legacy.version = old_version
		legacy.erase("target_rng_state")
		var migrated = Model.new()
		check(migrated.restore_state(legacy) and migrated.s.version == 4 and migrated.s.has("target_rng_state"), "legacy battle migration v" + str(old_version))
	var survivor = Model.new()
	check(survivor.restore_state(saved), "current v4 restores")
	for bad_counter in [-1, 3, 1.5]:
		var bad: Dictionary = saved.duplicate(true)
		bad.enemies[0].focus_hits = bad_counter
		check(not survivor.restore_state(bad) and survivor.s == saved, "reject corrupt focus transactionally")
	var bad: Dictionary = saved.duplicate(true)
	bad.target_rng_state = "not-an-integer"
	check(not survivor.restore_state(bad) and survivor.s == saved, "reject corrupt target RNG transactionally")
	for field in ["seed", "floor"]:
		for value in [[], {}, null, "oops"]:
			bad = saved.duplicate(true)
			bad.version = 3
			bad.erase("target_rng_state")
			bad[field] = value
			check(not survivor.restore_state(bad) and survivor.s == saved, "malformed legacy seed/floor rejected before conversion")
	var path := OS.get_environment("QA_OUTPUT_DIR")
	if not path.is_empty():
		DirAccess.make_dir_recursive_absolute(path)
		var file := FileAccess.open(path.path_join("weapon_rules_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "measurements": measurements}, "\t"))
		file.close()
	print("WEAPON RULES COMPLETE checks=" + str(checks) + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
