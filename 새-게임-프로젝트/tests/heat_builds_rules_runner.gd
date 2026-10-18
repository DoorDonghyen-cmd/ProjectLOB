extends "res://tests/heat_rules_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/heat_builds/"):
		quit(1)
		return
	var summary: Array = []
	for gun in Ammo.GUNS:
		var state := {"gun": gun, "equipped_parts": ["radiator", "ember_core"]}
		check(Ammo.heat_limit(state) == int(Ammo.GUNS[gun].heat_limit) + 1, "stacked heat capacity " + gun)
		check(Ammo.hot_threshold(state) == ceili(Ammo.heat_limit(state) * 0.5), "rounded public hot threshold " + gun)
		check(Ammo.valid_part_set(gun, ["radiator", "reclaimer", "ember_core"]), "three thermal parts can coexist " + gun)
		check(not Ammo.valid_part_set(gun, ["ember_core", "overbore"]), "one core restriction " + gun)
		check(not Ammo.start_deck(gun).has("thermal") and not Ammo.start_deck(gun).has("vent"), "initial learning load unchanged " + gun)
	var model = fixture(["charge_hot", "precise", "pierce", "cool"])
	model.s.equipped_parts = ["radiator"]
	var shots := fire(model, ["charge_hot", "precise", "pierce", "cool"])
	check(shots.size() == 4 and model.s.turns == 1 and model.s.heat == 9, "radiator lets the cooling fourth round fire")
	summary.append({"build": "radiator", "shots": shots.size(), "turns": model.s.turns, "heat": model.s.heat})
	model = fixture(["charge_hot", "precise", "pierce", "cool"])
	shots = fire(model, ["charge_hot", "precise", "pierce", "cool"])
	check(shots.size() == 3 and model.s.turns == 3, "identical unmodified hand stops before cooling")
	for lethal in [true, false]:
		model = fixture(["pierce", "cool"], [["runner", 5 if lethal else 40, 0, 1, 30], ["wall", 40, 4, 1, 34]])
		model.s.equipped_parts = ["reclaimer"]
		model.s.heat = 10
		shots = fire(model, ["pierce", "cool"])
		check(shots[0].kill_cooled == (2 if lethal else 0), "only a kill earns cooling")
		check(shots.size() == (2 if lethal else 1), "kill cooling resolves before thermal stop")
		check(model.s.turns == (1 if lethal else 3), "failed kill has real reload cost")
		summary.append({"build": "reclaimer", "kill": lethal, "shots": shots.size(), "turns": model.s.turns})
	model = fixture(["arc"], [["wall", 40, 4, 1, 30], ["runner", 1, 0, 1, 34], ["runner", 1, 0, 1, 36]])
	model.s.equipped_parts = ["reclaimer", "arc_splitter"]
	model.s.heat = 5
	shots = fire(model, ["arc"])
	check(shots[0].secondary.size() == 2 and shots[0].kill_cooled == 2 and model.s.heat == 6, "two secondary kills cool once per bullet")
	model = fixture(["cool"], [["runner", 1, 0, 1, 30], ["wall", 40, 4, 1, 34]])
	model.s.equipped_parts = ["reclaimer"]
	model.s.enemies[0].burn = 1
	model.s.heat = 6
	shots = fire(model, ["cool"])
	check(shots[0].kill_cooled == 0 and model.s.enemies[0].hp == 0 and model.s.heat == 3, "burn tick kill does not cool the gun")
	model = fixture(["pierce"])
	model.s.equipped_parts = ["reclaimer"]
	model.s.heat = 8
	model.s.projectiles = [{"uid": 0, "source": 0, "kind": "pressure", "name": "압력탄", "hp": 1, "max_hp": 1, "def": 0, "speed": 1, "distance": 4, "burn": 0, "barrier": 0, "focus_hits": 0, "lane": 0}]
	model.s.projectile_serial = 1
	var intercepted: Dictionary = model._shot("pierce", Ranged.target_id(model.s.projectiles[0]))
	check(intercepted.kill_cooled == 0 and model.s.heat == 11, "projectile interception cannot farm cooling")
	# Cooling and extra heat capacity are not unconditional damage upgrades.
	for parts in [["ember_core"], ["ember_core", "reclaimer"]]:
		model = fixture(["thermal"], [["runner", 4, 0, 1, 30], ["wall", 40, 4, 1, 34]])
		model.s.equipped_parts = parts
		model.s.heat = 5
		shots = fire(model, ["basic", "thermal"])
		check(shots[1].thermal_bonus == (0 if parts.has("reclaimer") else 4), "kill cooling can give up next high-heat damage")
		check(model.s.turns == (1 if parts.has("reclaimer") else 3), "high heat damage trades against compulsory reload")
	for parts in [["radiator"], ["opening"]]:
		model = fixture([])
		model.s.equipped_parts = parts
		shots = fire(model, ["basic", "basic", "basic", "basic"])
		check(model.s.turns == 1, "low heat hand needs no thermal part")
		check(int(shots[0].math.part_bonus) == (2 if parts.has("opening") else 0), "low heat hand benefits from another module instead")
	# Explicit before-shot thresholds: own heat never activates its own damage bonus.
	for gun in Ammo.GUNS:
		for parts in [[], ["ember_core"], ["ember_core", "radiator", "reclaimer"]]:
			for offset in [-1, 0]:
				model = fixture(["thermal"], [], gun)
				model.s.equipped_parts = parts
				model.s.heat = Ammo.hot_threshold(model.s) + offset
				shots = fire(model, ["thermal"])
				check(shots[0].thermal_bonus == (Ammo.effect_value("thermal", model.s) if offset == 0 else 0), "thermal threshold before firing " + gun)
				check(int(shots[0].math.part_bonus) == (2 if parts.has("ember_core") and offset == 0 else 0), "core threshold before firing " + gun)
	# A cold-to-hot order gains damage, while early venting gives up heat conversion.
	for sequence in [["charge_hot", "thermal", "vent"], ["thermal", "charge_hot", "vent"]]:
		model = fixture(sequence)
		model.s.equipped_parts = ["ember_core"]
		shots = fire(model, sequence)
		var thermal_index: int = sequence.find("thermal")
		check(shots[thermal_index].thermal_bonus == (4 if thermal_index == 1 else 0), "same hand order activates high heat")
		check(shots.back().vented == 4 and shots.back().vent_bonus == 8 and model.s.heat == 5, "final shot consumes bounded heat")
		summary.append({"build": "ember_core", "sequence": sequence, "damage": 40 - int(model.s.enemies[0].hp), "heat": model.s.heat})
	model = fixture(["charge_hot", "thermal", "vent"])
	check(model.load_round("vent") and model.load_round("thermal") and model.load_round("charge_hot"), "vent may be selected first")
	check(model.s.plan == ["charge_hot", "thermal", "vent"], "later selections insert before anchored vent")
	check(not model.move_planned(2, 0), "vent cannot be dragged out of the final position")
	model = fixture(["vent"], [], "amplifier")
	model.s.heat = 4
	shots = fire(model, ["vent"])
	check(shots[0].vented == 4 and shots[0].vent_bonus == 16 and model.s.heat == 0, "amplifier doubles conversion, not heat spent")
	model = fixture(["charge_hot", "precise", "pierce", "vent"])
	shots = fire(model, ["charge_hot", "precise", "pierce", "vent"])
	check(shots.size() == 3 and model.s.turns == 3, "vent cannot rescue an earlier overheat")
	# Compare full and optimized resolution at every temperature for the new parts.
	for gun in Ammo.GUNS:
		for id in Ammo.TACTICAL_AMMO:
			for parts in [["radiator", "reclaimer", "ember_core"], ["reclaimer", "arc_splitter"]]:
				for heat in range(Ammo.heat_limit({"gun": gun, "equipped_parts": parts})):
					model = fixture([id], [["absorber", 10, 4, 1, 24], ["runner", 2, 0, 1, 26]], gun)
					model.s.equipped_parts = parts
					model.s.heat = heat
					var light = Model.new()
					light.s = model.s.duplicate(true)
					var full_result: Dictionary = model._shot(id, 0)
					var light_result: Dictionary = light._shot(id, 0, {"forecast_minimal": true, "profile": Model.shot_profile(id, light.s)})
					check(full_result.damage == light_result.damage and model.s == light.s, "thermal optimized shot exactly equivalent")
	# Exhaust every target path, independently of forecast merging and preview flags.
	for parts in [["reclaimer"], ["radiator", "reclaimer", "ember_core"]]:
		model = fixture(["thermal", "pierce", "vent"], [["runner", 6, 0, 1, 30], ["wall", 40, 4, 1, 34]], "scatter")
		model.s.equipped_parts = parts
		model.s.heat = 11
		for id in Ammo.loading_order(["thermal", "pierce", "vent"]): check(model.load_round(id), "exhaustive legal load")
		var original := JSON.stringify(model.s)
		var prediction := Forecast.analyze(model.s, true, true)
		check(JSON.stringify(model.s) == original, "conditional scatter forecast is pure")
		model.confirm()
		var outcomes: Array = []
		walk(model.s, 1.0, 11, 0, outcomes)
		var probability := 0.0
		var forced := 0.0
		var peaks: Array = []
		var fired: Array = []
		for outcome in outcomes:
			probability += float(outcome.p)
			if outcome.forced: forced += float(outcome.p)
			peaks.append(outcome.peak)
			fired.append(outcome.fired)
		check(is_equal_approx(probability, 1.0), "exhaustive probability mass")
		check(is_equal_approx(forced, float(prediction.heat.forced_probability)), "exact conditional forced reload probability")
		check(prediction.heat.peak_min == peaks.min() and prediction.heat.peak_max == peaks.max(), "branch-specific peak ranges")
		check(prediction.heat.fired_min == fired.min() and prediction.heat.fired_max == fired.max(), "conditional stopping shot range")
		for index in range(model.s.enemies.size()):
			var hp: Array = []
			var kills := 0.0
			for outcome in outcomes:
				hp.append(outcome.state.enemies[index].hp)
				if int(outcome.state.enemies[index].hp) == 0: kills += float(outcome.p)
			check(prediction.enemies[index].hp_min == hp.min() and prediction.enemies[index].hp_max == hp.max(), "exact scatter HP bounds")
			check(is_equal_approx(prediction.enemies[index].kill_probability, kills), "exact scatter kill probability")
	# Full shop rotation, legitimate purchase/equip, and save round trip for every item.
	var campaign = Campaign.new()
	campaign.start("single", 731042)
	campaign.s.phase = "shop"
	campaign.s.region = 1
	campaign.s.floor = 4
	campaign.s.node = 10401
	campaign.s.credits = 1000
	for region in range(2):
		for floor_number in range(1, int(Data.info(region).floors) + 1 if region == 0 else 5):
			campaign.s.visited.append(region * 10000 + floor_number * 100 + 1)
	campaign._stock_shop(campaign.node())
	var bought: Array = []
	for revision in range(28):
		for i in range(campaign.s.offers.size()):
			var id: String = campaign.s.offers[i].id
			if id in ["vent", "thermal", "radiator", "reclaimer", "ember_core"] and not bought.has(id):
				check(campaign.buy(i), "buy thermal item " + id)
				bought.append(id)
		if bought.size() == 5: break
		check(campaign.reroll(), "legal shop rotation")
	check(bought.size() == 5, "all five thermal items obtainable")
	var restored = Campaign.new()
	check(campaign.save("user://thermal_roundtrip.json") == OK, "save thermal campaign")
	var loaded: bool = restored.restore("user://thermal_roundtrip.json")
	check(loaded, "new inventory and equipment save round trip")
	if not loaded:
		print("HEAT BUILDS RULES COMPLETE checks=%d failures=%d" % [checks, failures])
		quit(1)
		return
	check(restored.s.parts == campaign.s.parts and restored.model.s.deck == campaign.model.s.deck, "no thermal content lost in save")
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("thermal_cases.json"), FileAccess.WRITE).store_string(JSON.stringify(summary, "\t"))
	print("HEAT BUILDS RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func walk(state: Dictionary, probability: float, peak: int, fired: int, outcomes: Array) -> void:
	var model = Model.new()
	model.s = state.duplicate(true)
	if model.s.magazine.is_empty() or not model.has_remaining_enemies() or int(model.s.heat) >= Ammo.heat_limit(model.s):
		var detail: Dictionary = model.finish_fire()
		outcomes.append({"state": model.s, "p": probability, "peak": peak, "fired": fired, "forced": not detail.forced_reload.is_empty()})
		return
	var id := str(model.s.magazine[0])
	var targets: Array = model.scatter_targets(id)
	for target in targets:
		var branch = Model.new()
		branch.s = model.s.duplicate(true)
		branch.s.magazine.pop_front()
		branch._shot(id, target)
		branch._discard_fired_round(id)
		walk(branch.s, probability / targets.size(), maxi(peak, int(branch.s.heat)), fired + 1, outcomes)
