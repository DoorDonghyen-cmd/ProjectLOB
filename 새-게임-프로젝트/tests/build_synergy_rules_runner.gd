extends "res://tests/heat_rules_runner.gd"

func round_trip(model) -> void:
	var copy = Model.new()
	check(copy.restore_state(JSON.parse_string(JSON.stringify(model.s))), "v12 state and inventory valid")
	check(JSON.parse_string(JSON.stringify(copy.s)) == JSON.parse_string(JSON.stringify(model.s)), "reservations, timers, order and RNG survive restore")

func finish_volley(model) -> void:
	while model.s.phase == "ready" and not model.s.magazine.is_empty():
		var predicted := Forecast.analyze(model.s, true)
		check(model.fire(), "next amplifier trigger legal")
		check(predicted.enemies == model.s.enemies, "partial trigger forecast exact")
		round_trip(model)

func reservation_edges() -> void:
	var model = fixture(["prepare", "charge_hot", "pierce"])
	model.s.heat = 8
	var shots := fire(model, ["prepare", "charge_hot", "pierce"])
	check(shots.size() == 2 and model.s.phase == "plan", "reservation survives actual forced reload")
	check(model.s.hand[0] == "charge_hot" and model.s.prepared.is_empty(), "forced reload redeals one owned reserved card")
	round_trip(model)
	model = fixture(["prepare", "prepare", "pierce", "pierce"])
	model.s.equipped_parts = ["indexer"]
	fire(model, ["prepare", "prepare", "pierce", "pierce"])
	check(model.s.prepared == ["prepare", "pierce", "pierce"], "overlapping reservations distinguish physical duplicate cards")
	check(model.reload_magazine() and model.s.hand.slice(0, 3) == ["prepare", "pierce", "pierce"], "duplicate reservations draw exactly owned count")
	round_trip(model)
	model = fixture(["prepare", "push", "push", "pierce"])
	model.s.field_compression_left = 1
	check(model.field_compress("push") and model.load_round("prepare"), "temporary compressed round follows prepare")
	check(model.confirm() and model.fire(), "temporary reservation volley legal")
	check(model.s.prepared.is_empty(), "temporary field round cannot become permanent owned card")
	round_trip(model)
	model = fixture(["prepare", "pierce"], [["wall", 80, 4, 1, 2]])
	fire(model, ["prepare", "pierce"])
	check(model.reload_magazine() and model.s.phase == "lost" and model.s.prepared.is_empty(), "terminal reload clears next-hand promises")
	round_trip(model)

func random_effects() -> void:
	var model = fixture(["disrupt", "disrupt"], [["spitter", 40, 0, 0, 40], ["runner", 40, 0, 1, 50]], "scatter")
	for id in Ammo.loading_order(["disrupt", "disrupt"]): model.load_round(id)
	var predicted := Forecast.analyze(model.s, true, true)
	check(is_equal_approx(predicted.shots[0].effect_probability, 0.5), "random interruption only on eligible half of targets")
	check(is_equal_approx(predicted.shots[1].effect_probability, 0.25), "used interruption flag survives random branch merging")
	model = fixture(["spread", "spread"], [["wall", 40, 0, 1, 40], ["runner", 40, 0, 1, 50]], "scatter")
	model.s.enemies[0].burn = 3
	for id in Ammo.loading_order(["spread", "spread"]): model.load_round(id)
	predicted = Forecast.analyze(model.s, true, true)
	check(is_equal_approx(predicted.shots[0].effect_probability, 0.5), "unburnt random target gives no transfer")
	check(is_equal_approx(predicted.shots[1].effect_probability, 0.75), "transfer branch retains both source and recipient burn")
	for order in [["disrupt", "spread", "sequence"], ["prepare", "bore", "spread", "sequence"]]:
		for seed_value in range(1, 25):
			model = fixture(order, [["spitter", 20, 0, 0, 40], ["runner", 12, 0, 1, 50]], "scatter")
			model.s.enemies[0].ranged_left = 1
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			model.s.target_rng_state = str(rng.state)
			for id in Ammo.loading_order(order): model.load_round(id)
			predicted = Forecast.analyze(model.s, true, true)
			check(model.confirm() and model.fire(), "seeded random effects execute")
			for i in range(model.s.enemies.size()):
				check(model.s.enemies[i].hp >= predicted.enemies[i].hp_min and model.s.enemies[i].hp <= predicted.enemies[i].hp_max, "actual random HP stays inside public range")
			for projectile in model.s.projectiles:
				var matching: Array = predicted.projectiles.filter(func(p): return int(p.uid) == int(projectile.uid))
				check(matching.size() == 1 and projectile.distance >= matching[0].distance_min and projectile.distance <= matching[0].distance_max, "interruption timing stays inside projectile range")
			for projectile in predicted.projectiles:
				if float(projectile.alive_probability) >= 0.999999:
					check(model.s.projectiles.any(func(p): return int(p.uid) == int(projectile.uid)), "guaranteed ranged shot exists")
			round_trip(model)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/build_synergy/"):
		quit(1)
		return
	check(Ammo.TACTICAL_AMMO.size() == 18 and Ammo.PARTS.size() == 29, "18 tactical choices and 28 collectible parts")
	reservation_edges()
	random_effects()
	for gun in Ammo.GUNS:
		for expansion in range(3):
			for parts in [[], ["supply"], ["cooling_breech"], ["chain_sink"], ["supply", "indexer", "chain_sink", "radiator", "cooling_breech"]]:
				for id in ["prepare", "disrupt", "spread", "sequence"]:
					var model = fixture([id, "bore", "pierce"], [["spitter", 50, 0, 0, 60], ["wall", 80, 2, 1, 70]], gun)
					model.s.capacity_bonus = expansion
					model.s.equipped_parts = parts.duplicate()
					model.s.supply = model.supply_capacity()
					var order: Array = [id, "bore", "pierce"].slice(0, model.capacity())
					if id in ["spread", "sequence"] and order.size() > 1: order = ["bore", id, "pierce"].slice(0, model.capacity())
					fire(model, order)
					if gun == "amplifier": finish_volley(model)
					round_trip(model)
					if model.s.phase == "ready":
						var reservations: Array = model.s.prepared.duplicate()
						var expected_heat := Ammo.heat_after_reload(model.s)
						check(model.reload_magazine(), "reload with magazine configuration")
						check(model.s.heat == expected_heat, "part cooling uses weapon base")
						check(model.s.hand.slice(0, reservations.size()) == reservations, "reserved cards lead next hand")
						round_trip(model)
	# Slot investment controls how much the same preparation can secure.
	for gun in ["single", "amplifier"]:
		for parts in [[], ["indexer"], ["indexer", "supply"]]:
			var model = fixture(["prepare", "charge", "precise", "bore"], [], gun)
			model.s.equipped_parts = parts.duplicate()
			model.s.supply = model.supply_capacity()
			var order := ["prepare", "charge", "precise", "bore"].slice(0, model.capacity())
			var shots := fire(model, order)
			check(shots[0].prepared_rounds.size() == mini(order.size() - 1, Ammo.effect_value("prepare", model.s)), "reservation count is bounded by actual trailing slots")
			finish_volley(model)
			if model.s.phase == "ready": check(model.reload_magazine(), "reserved high-heat reload")
			round_trip(model)
	var model = fixture(["prepare", "pierce"])
	var shots := fire(model, ["pierce", "prepare"])
	check(shots.back().prepared_rounds.is_empty(), "preparation last has no free value")
	model = fixture(["prepare", "pierce_c"])
	shots = fire(model, ["prepare", "pierce_c"])
	check(shots[0].prepared_rounds == ["pierce_c"], "permanent compressed round stays one owned reservation")
	check(model.reload_magazine() and model.s.hand[0] == "pierce_c", "compressed reservation drawn intact")
	round_trip(model)
	model = fixture(["prepare", "pierce"])
	fire(model, ["prepare", "basic", "pierce"])
	check(model.s.prepared == ["pierce"], "supply is not copied into next tactical hand")
	var invalid: Dictionary = model.s.duplicate(true)
	invalid.prepared = ["basic"]
	check(not Model.new().restore_state(invalid), "invalid reserved supply rejected")
	invalid.prepared = ["pierce", "pierce", "pierce", "pierce"]
	check(not Model.new().restore_state(invalid), "reservation cap validated")
	# Delays only the announced special action, and cannot permanently lock it.
	model = fixture(["disrupt", "disrupt"], [["spitter", 40, 0, 0, 50]])
	model.s.enemies[0].ranged_left = 1
	shots = fire(model, ["disrupt", "disrupt"])
	check(shots[0].interrupted == 1 and shots[1].interrupted == 0, "one interruption per enemy")
	check(model.s.projectiles.is_empty() and model.s.enemies[0].ranged_left == 1, "interruption buys firing turn")
	check(model.reload_magazine() and model.s.projectiles.size() == 1, "enemy resumes normally on reload")
	model = fixture(["disrupt"], [["caster", 40, 0, 2, 50], ["runner", 40, 0, 1, 60]])
	model.s.enemies[0].charge = 2
	fire(model, ["disrupt"])
	check(model.s.enemies[0].charge == 2 and model.s.enemies[0].distance == 48 and model.s.enemies[1].distance == 59, "charge paused but ordinary movement continues")
	model = fixture(["disrupt"], [["runner", 40, 0, 2, 50]])
	check(fire(model, ["disrupt"])[0].interrupted == 0, "ordinary enemies give no interruption benefit")
	for gun in Ammo.GUNS:
		model = fixture(["bore", "spread"], [["wall", 60, 0, 1, 50], ["runner", 60, 0, 1, 60]], gun)
		shots = fire(model, ["bore", "spread"])
		if gun == "amplifier":
			finish_volley(model)
			shots = model.s.history.back().detail.results
		if gun != "scatter": check(shots.back().transferred > 0, "spread moves existing heat on each deterministic gun")
		round_trip(model)
	model = fixture(["spread", "bore"])
	check(fire(model, ["spread", "bore"])[0].transferred == 0, "unprimed spread is weak")
	model = fixture(["sequence", "cool", "shatter", "pierce"])
	shots = fire(model, ["cool", "shatter", "pierce", "sequence"])
	check(shots.back().sequence_bonus == 6, "four slots support three distinct setup types")
	model = fixture(["sequence", "pierce", "pierce"])
	shots = fire(model, ["pierce", "pierce", "sequence"])
	check(shots.back().sequence_bonus == 2, "repeated rounds do not fake diversity")
	model = fixture(["charge_hot", "precise", "sequence"])
	model.s.equipped_parts = ["chain_sink"]
	shots = fire(model, ["charge_hot", "precise", "sequence"])
	check(shots.size() == 3 and shots.back().chain_cooled == 3 and model.s.heat == 9, "third-shot sink rescues threshold before overheat")
	model = fixture(["charge_hot", "precise", "sequence"])
	model.s.equipped_parts = ["chain_sink"]
	model.s.heat = 2
	shots = fire(model, ["charge_hot", "precise", "sequence"])
	check(shots.size() == 2 and shots.back().overheated, "sink cannot rescue overheat before third round")
	# Saves from the preceding mobile build keep arrays, heat and RNG unchanged.
	model = fixture(["pierce", "charge"])
	model.load_round("pierce")
	var legacy: Dictionary = model.s.duplicate(true)
	legacy.version = 11
	legacy.erase("prepared")
	var restored = Model.new()
	check(restored.restore_state(legacy) and restored.s.version == Model.VERSION, "v11 mobile save migration")
	check(restored.s.hand == model.s.hand and restored.s.plan == model.s.plan and restored.s.rng_state == model.s.rng_state, "migration does not redraw or reverse order")
	var discovered: Array = []
	for seed_value in range(120):
		var node := {"id": 305, "region": 2, "floor": 5}
		for id in Data.rewards(node, seed_value, ["bore", "prepare", "cool"]):
			if not discovered.has(id): discovered.append(id)
	for id in ["prepare", "disrupt", "spread", "sequence"]: check(discovered.has(id), "new role available through public rewards: " + id)
	print("BUILD SYNERGY RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
