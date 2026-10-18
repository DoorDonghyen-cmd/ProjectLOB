extends "res://tests/heat_rules_runner.gd"
const Guide = preload("res://redesign/build_guide.gd")
const Feedback = preload("res://redesign/part_feedback.gd")

func equipped(ids: Array, parts: Array, gun: String = "single") -> RefCounted:
	var model = fixture(ids, [["wall", 300, 0, 1, 50], ["runner", 300, 0, 1, 54]], gun)
	model.s.equipped_parts = parts
	return model

func triggered(shot: Dictionary, id: String) -> bool:
	return shot.get("part_effects", []).any(func(effect): return effect.id == id)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/parts_revision/rules"):
		quit(1)
		return
	check(Ammo.PARTS.size() == 29, "28 collectible parts")
	for id in Ammo.PARTS:
		if id != "none": check(Guide.FAMILIES.has(id), "every part has deliberate role " + id)
	for gun in Ammo.GUNS:
		for id in Ammo.AMMO:
			var bare := {"gun": gun}
			var lens := {"gun": gun, "equipped_parts": ["lens"]}
			check(Ammo.penetration(id, lens) - Ammo.penetration(id, bare) == (2 if int(Ammo.AMMO[id].pen) > 0 else 0), "lens preserves native penetration identity")
			var heavy := {"gun": gun, "equipped_parts": ["overbore"]}
			var eligible := Ammo.slot_cost(id) >= 2 and int(Ammo.AMMO[id].dmg) > 0
			check(Ammo.damage(id, heavy) - Ammo.damage(id, bare) == (3 if eligible else 0), "heavy barrel never turns utility or supply into attack")
			check(Ammo.penetration(id, heavy) - Ammo.penetration(id, bare) == (2 if eligible else 0), "heavy penetration gated by slot and attack")
	var model = equipped(["charge", "precise"], ["ordinary_chain"])
	var shots := fire(model, ["charge", "precise"])
	check(shots[0].ordinary_bonus == 0 and shots[1].ordinary_bonus == 2 and triggered(shots[1], "ordinary_chain"), "different ordinary after real setup gains bonus")
	check(shots[1].damage == 16, "ordinary multihit applies two per real hit plus boost")
	for pair in [["precise", "precise"], ["basic", "precise"], ["precise_c", "pierce"], ["charge", "pierce_c"], ["pierce", "cool"]]:
		model = equipped(pair, ["ordinary_chain"])
		shots = fire(model, pair)
		check(shots.back().ordinary_bonus == 0 and not triggered(shots.back(), "ordinary_chain"), "same, supply, advanced or zero-damage cannot exploit ordinary chain")
	model = equipped(["shatter", "pierce_c"], ["compression_sink"])
	model.s.heat = 5
	shots = fire(model, ["shatter", "pierce_c"])
	check(shots[1].relay_saved == 2 and shots[1].heat_added == 3 and model.s.heat == 9 and model.s.reloads == 0, "prepared compression stays below threshold")
	model = equipped(["shatter", "pierce_c"], ["compression_sink"])
	model.s.heat = 5
	shots = fire(model, ["pierce_c", "shatter"])
	check(shots[0].relay_saved == 0 and shots.back().overheated and model.s.reloads == 1, "reversed order incurs actual compulsory reload")
	for pair in [["basic", "pierce_c"], ["charge_hot", "pierce_c"], ["pierce", "cool_c"]]:
		model = equipped(pair, ["compression_sink"])
		if pair[1] == "cool_c":
			check(model.load_round("cool_c") and not model.load_round("pierce"), "stabilizer cannot bypass first-shot anchor")
			continue
		shots = fire(model, pair)
		check(shots.back().relay_saved == 0, "supply and native high-output are not ordinary setup")
	model = equipped(["shatter", "pierce", "pierce"], ["compression_sink"])
	check(model.field_compress("pierce") and model.load_round("shatter"), "ordinary before temporary compressed shot")
	var prediction := Forecast.analyze(model.s, true, true)
	check(model.confirm() and model.fire(), "field grade fire")
	shots = model.s.history.back().detail.results
	check(shots[1].relay_saved == 2 and model.s.discard.count("pierce") == 2 and model.s.field_compression.is_empty(), "field recovery unchanged by stabilizer")
	check(prediction.enemies == model.s.enemies and Model.new().restore_state(model.s), "temporary forecast and save")
	# A single-shot gun retains adjacency across triggers and save/load, but not reloads.
	model = equipped(["charge", "precise"], ["ordinary_chain"], "amplifier")
	shots = fire(model, ["charge", "precise"])
	check(shots.size() == 1, "amplifier first survivor pauses")
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(model.s))), "partial magazine restores")
	prediction = Forecast.analyze(restored.s, true, true)
	check(restored.preview().ordinary_bonus == 2 and restored.fire(), "single-shot preview sees previous ordinary")
	check(restored.s.history.back().detail.results[0].ordinary_bonus == 2 and prediction.enemies == restored.s.enemies, "second trigger keeps adjacency")
	check(restored.reload_magazine(), "reload clears adjacency")
	# Public deterministic and scatter commands across all weapons, parts and grades.
	for gun in Ammo.GUNS:
		for parts in [["ordinary_chain", "chain_sink"], ["compression_sink", "overbore", "lens"], ["igniter", "reclaimer", "duplex"]]:
			var order: Array = ["charge", "precise", "pierce"] if parts.has("ordinary_chain") else (["shatter", "pierce_c"] if parts.has("compression_sink") else ["bore", "precise", "detonate"])
			for seed_value in range(12):
				model = equipped(order, parts, gun)
				model.s.capacity_bonus = 2
				model.s.rng_state = str(seed_value + 123456)
				for id in Ammo.loading_order(order): check(model.load_round(id), "cross-weapon legal preparation")
				var before := JSON.stringify(model.s)
				prediction = Forecast.analyze(model.s, true, true)
				check(JSON.stringify(model.s) == before, "forecast and RNG purity")
				check(model.confirm() and model.fire(), "cross-weapon real shot")
				check(Model.new().restore_state(model.s), "part build save roundtrip")
				if gun != "scatter": check(prediction.enemies == model.s.enemies and prediction.heat.end_max == model.s.heat, "deterministic exact replay")
				else:
					for i in range(model.s.enemies.size()): check(model.s.enemies[i].hp >= prediction.enemies[i].hp_min and model.s.enemies[i].hp <= prediction.enemies[i].hp_max, "scatter realised HP within declared distribution")
					for i in range(model.s.history.back().detail.results.size()):
						var actual: Dictionary = model.s.history.back().detail.results[i]
						for part in ["ordinary_chain", "compression_sink"]:
							if triggered(actual, part): check(prediction.shots[i].part_probabilities.get(part, 0) > 0, "random preview includes actual part trigger")
	# Existing useful synergy has both payoff and a real conflict when burn is consumed.
	model = equipped(["bore", "precise", "detonate"], ["igniter", "reclaimer"])
	shots = fire(model, ["bore", "precise", "detonate"])
	check(triggered(shots[1], "igniter"), "burn sets up attack bonus")
	model = equipped(["bore", "detonate", "precise"], ["igniter", "reclaimer"])
	shots = fire(model, ["bore", "detonate", "precise"])
	check(not triggered(shots[2], "igniter"), "detonation removes future ignition bonus")
	var seen: Array = []
	for seed_value in range(100):
		for offer in Data.offers({"id": 10401, "region": 1, "floor": 4}, seed_value, 0, "single", []):
			if offer.type == "part" and not seen.has(offer.id): seen.append(offer.id)
	check(seen.has("ordinary_chain") and seen.has("compression_sink"), "new modules available in real shops")
	print("PARTS REVISION RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
