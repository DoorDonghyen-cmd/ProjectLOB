extends "res://tests/ammo_expansion_rules_runner.gd"

func fire(model: RefCounted, ids: Array) -> Array:
	for id in Ammo.loading_order(ids): check(model.load_round(id), "legal heat load " + str(id))
	var original := JSON.stringify(model.s)
	var prediction := Forecast.analyze(model.s, true, true)
	check(JSON.stringify(model.s) == original, "heat forecast leaves state and RNG intact")
	check(model.confirm() and model.fire(), "heat confirm/fire")
	var detail: Dictionary = model.s.history.back().detail
	if model.s.gun != "scatter":
		check(prediction.enemies == model.s.enemies, "heat forecast exact enemy state")
		check(prediction.projectiles == model.s.projectiles, "heat forecast exact projectile state")
		check(prediction.phase == model.s.phase, "heat forecast phase including forced reload")
		check(prediction.heat.end_max == model.s.heat, "heat forecast final temperature")
		check(prediction.heat.peak_max == detail.heat_peak, "heat forecast peak before cooling")
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(model.s))), "heat save conserves inventory")
	check(restored.s.get("heat", -1) == model.s.heat, "heat persistence")
	return detail.results

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/heat/"):
		quit(1)
		return
	for id in Ammo.AMMO: check(Ammo.AMMO[id].has("heat"), "every round has explicit heat " + id)
	var limits: Array = []
	for gun in Ammo.GUNS:
		limits.append(Ammo.heat_limit({"gun": gun}))
	check(limits == [12, 14, 16, 13, 10], "weapon heat capacities")
	var model = fixture(["charge_hot", "precise", "pierce", "cool"])
	var shots := fire(model, ["charge_hot", "precise", "pierce", "cool"])
	check(shots.size() == 2 and shots.back().overheated, "exact threshold fires triggering round then stops")
	check(model.s.phase == "plan" and model.s.turns == 3 and model.s.reloads == 1 and model.s.heat == 0, "one firing turn plus obligatory two-turn reload")
	check(not model.s.history.back().detail.forced_reload.is_empty(), "automatic reload is part of the fire result")
	model = fixture(["charge_hot", "precise", "pierce", "cool"])
	shots = fire(model, ["charge_hot", "cool", "precise"])
	check(shots.size() == 3 and model.s.heat == 9 and model.s.turns == 1 and model.s.phase == "ready", "same hand cools before empowered attack and leaves last shot unloaded")
	check(model.reload_magazine() and model.s.heat == 1 and model.s.turns == 2, "normal reload removes eight heat and carries one without extra turn")
	for start_heat in [8, 9, 10]:
		model = fixture(["pierce", "cool"])
		model.load_round("cool")
		model.load_round("pierce")
		model.confirm()
		model.s.heat = start_heat
		var predicted := Forecast.analyze(model.s, true)
		check(model.fire(), "boundary fire")
		check(model.s.phase == ("ready" if start_heat == 8 else "plan"), "below/exact/above threshold")
		check(predicted.enemies == model.s.enemies and predicted.phase == model.s.phase, "boundary forecast")
	model = fixture(["cool", "charge_hot"])
	shots = fire(model, ["cool", "charge_hot"])
	check(shots[0].damage == 0 and shots[0].cooled == 0 and model.s.heat == 5, "cold cooling neither attacks nor banks future cooling")
	model = fixture(["charge_hot", "precise", "cool"], [], "amplifier")
	shots = fire(model, ["charge_hot", "cool", "precise"])
	check(model.s.heat == 5 and model.s.magazine.size() == 2, "amplifier heat survives trigger interruption")
	check(model.fire() and model.s.heat == 0, "amplifier cooling intensity doubled")
	check(model.fire() and model.s.heat == 7, "multihit heat plus overload paid once, not doubled by amplifier")
	model = fixture(["charge_hot", "charge_hot", "cool"], [], "amplifier")
	fire(model, ["charge_hot", "charge_hot", "cool"])
	check(model.fire() and model.s.phase == "plan" and model.s.shots == 2, "amplifier cannot postpone overheat with later cooling")
	model = fixture(["pierce", "cool"], [["runner", 3, 0, 1, 10]])
	model.load_round("cool")
	model.load_round("pierce")
	model.confirm()
	model.s.heat = 9
	check(model.fire() and model.s.phase in ["reward", "won"] and model.s.reloads == 0, "last kill waives obligatory wait")
	model = fixture(["charge_hot", "precise", "pierce", "cool"], [["wall", 40, 4, 2, 6]])
	fire(model, ["charge_hot", "precise", "pierce", "cool"])
	check(model.s.phase == "lost" and model.s.turns == 3, "forced reload can cause contact defeat")
	model = fixture(["charge_hot", "precise", "pierce", "cool"], [["wall", 40, 4, 2, 6]])
	fire(model, ["charge_hot", "cool", "precise"])
	check(model.s.phase == "ready" and model.s.enemies[0].distance == 4, "same hand cooling and shorter magazine prevent forced defeat")
	# Legacy extra-turn debt is not reinterpreted as temperature or silently removed.
	model = fixture(["pierce"])
	model.load_round("pierce")
	model.confirm()
	var old: Dictionary = model.s.duplicate(true)
	old.version = 8
	old.erase("heat")
	old.erase("legacy_reload_penalty")
	old.reload_heat = 2
	var restored = Model.new()
	check(restored.restore_state(old) and restored.s.heat == 0 and restored.reload_cost() == 3, "v8 migration preserves pending debt once")
	check(restored.reload_magazine() and restored.reload_cost() == 1, "legacy debt clears after actual reload")
	var invalid: Dictionary = model.s.duplicate(true)
	invalid.heat = Ammo.heat_limit(invalid)
	check(not restored.restore_state(invalid), "cannot restore a skipped compulsory reload")
	for temperature in [-1, 0.5, 100]:
		invalid = model.s.duplicate(true)
		invalid.heat = temperature
		check(not restored.restore_state(invalid), "invalid temperature rejected")
	# Burn, reserves and already-fired projectiles continue during compulsory cooling.
	model = fixture(["bore"], [["runner", 7, 0, 1, 20]], "heavy")
	model.load_round("bore")
	model.confirm()
	model.s.heat = 11
	var predicted_burn := Forecast.analyze(model.s, true)
	check(model.fire() and model.s.phase in ["reward", "won"] and model.s.turns == 3, "forced reload can end in burn victory")
	check(predicted_burn.enemies == model.s.enemies and predicted_burn.turns == 3, "forced burn victory forecast")
	model = fixture(["pierce"], [["runner", 5, 0, 1, 10]])
	model.s.reinforcements = [Data._enemy(["runner", 6, 0, 2, 12])]
	model.s.encounter_total = 2
	model.assign_opening_lanes()
	model.load_round("pierce")
	model.confirm()
	model.s.heat = 9
	var predicted_wave := Forecast.analyze(model.s, true)
	check(model.fire() and model.s.phase == "plan" and model.s.enemies[1].distance == 8, "reinforcements skip birth movement then take forced reload turns")
	check(predicted_wave.enemies == model.s.enemies, "heat wave prediction exact")
	check(Model.new().restore_state(model.s), "reinforcements after automatic reload restore")
	model = fixture(["bypass"], [["spitter", 5, 0, 0, 25]])
	model._advance(2)
	model.s.projectiles[0].distance = 30
	model.load_round("bypass")
	model.confirm()
	model.s.heat = 10
	check(model.fire() and model.s.phase == "plan", "surviving projectile prevents final-kill cooling waiver")
	check(model.s.projectiles[0].distance == 12, "projectile moves during firing and compulsory reload")
	model = fixture(["charge_hot", "precise", "pierce", "push", "push"])
	check(model.field_compress("push"), "compress last-slot round")
	for id in Ammo.loading_order(["charge_hot", "precise", "pierce"]): check(model.load_round(id), "load before anchored temporary compression")
	check(model.confirm() and model.fire() and model.s.phase == "plan", "overheat interrupts before compressed last round")
	check(model.s.field_compression.is_empty() and Model.new().restore_state(model.s), "unfired compression restores source inventory through forced reload")
	model = fixture(["pierce"], [], "burst")
	model.s.equipped_parts = ["afterburner", "loader"]
	model.load_round("pierce")
	model.confirm()
	model.s.heat = 11
	check(model.fire() and model.s.turns == 4, "part reload modifiers plus exactly one overheat turn")
	# Exact scatter forecast: stopped branches, forced reload, ranged shots and late victory.
	for sequence in [["charge_hot", "precise", "arc", "precise", "cool"], ["charge_hot", "precise", "cool", "arc", "precise"]]:
		for seed_value in range(1, 31):
			model = fixture(sequence, [["wall", 12, 4, 1, 9], ["runner", 5, 0, 2, 11], ["spitter", 9, 0, 0, 25]], "scatter")
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			model.s.target_rng_state = str(rng.state)
			for id in Ammo.loading_order(sequence): model.load_round(id)
			var before := JSON.stringify(model.s)
			var predicted := Forecast.analyze(model.s, true, true)
			check(before == JSON.stringify(model.s), "scatter forecast is pure")
			model.confirm()
			model.fire()
			for i in range(predicted.enemies.size()):
				check(model.s.enemies[i].hp >= predicted.enemies[i].hp_min and model.s.enemies[i].hp <= predicted.enemies[i].hp_max, "scatter HP inside exact bounds")
				check(model.s.enemies[i].distance >= predicted.enemies[i].distance_min and model.s.enemies[i].distance <= predicted.enemies[i].distance_max, "scatter forced movement inside exact bounds")
			check(model.s.heat >= predicted.heat.end_min and model.s.heat <= predicted.heat.end_max, "scatter temperature bounds")
			check(model.s.turns >= predicted.heat.turns_min and model.s.turns <= predicted.heat.turns_max, "scatter elapsed turn bounds")
			check(Model.new().restore_state(JSON.parse_string(JSON.stringify(model.s))), "scatter save after automatic reload")
	print("HEAT RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
