extends "res://tests/heat_rules_runner.gd"

func commands(model, ids: Array) -> void:
	for id in ids: check(model.load_round(id), "actual input " + str(id))

func save_same(model) -> void:
	var saved := JSON.stringify(model.s)
	var copy = Model.new()
	check(copy.restore_state(JSON.parse_string(saved)), "valid LIFO snapshot")
	check(JSON.stringify(JSON.parse_string(JSON.stringify(copy.s))) == JSON.stringify(JSON.parse_string(saved)), "snapshot preserves ordered rounds and ownership")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/lifo/"):
		quit(1)
		return
	var inputs := [["pierce", "precise", "charge"], ["precise", "pierce", "charge"], ["charge", "precise", "pierce"], ["charge", "pierce", "precise"], ["precise", "charge", "pierce"], ["pierce", "charge", "precise"]]
	for gun in Ammo.GUNS:
		for seed_value in [17, 42, 109, 731042]:
			for order in inputs:
				var model = fixture(order, [["wall", 100, 3, 1, 30], ["runner", 100, 0, 2, 34]], gun)
				var random := RandomNumberGenerator.new()
				random.seed = seed_value
				model.s.target_rng_state = str(random.state)
				var expected: Array = []
				for id in order:
					check(model.load_round(id), "load each gun and permutation")
					expected.push_front(id)
					check(model.s.plan == expected, "each new click becomes first firing slot")
					save_same(model)
				check(model.s.plan_load_order == order, "input chronology is distinct from firing order")
				var state_before := JSON.stringify(model.s)
				var prediction := Forecast.analyze(model.s, true, true)
				check(JSON.stringify(model.s) == state_before, "prediction never mutates input or target RNG")
				check(model.confirm() and model.s.magazine == expected, "confirmation does not reverse the firing rail again")
				check(model.fire(), "real LIFO fire")
				var result: Dictionary = model.s.history.back().detail
				for i in range(result.results.size()): check(result.results[i].id == expected[i], "actual emitted order equals visible stack")
				if gun != "scatter":
					check(prediction.enemies == model.s.enemies and prediction.phase == model.s.phase, "LIFO forecast exact deterministic outcome")
				else:
					for i in range(prediction.enemies.size()):
						check(int(model.s.enemies[i].hp) >= int(prediction.enemies[i].hp_min) and int(model.s.enemies[i].hp) <= int(prediction.enemies[i].hp_max), "LIFO scatter actual damage in predicted bounds")
				save_same(model)
	# A visible combination depends on LOADING the amplifier round last.
	var good = fixture(["charge", "precise"], [["wall", 100, 0, 1, 30]])
	commands(good, ["precise", "charge"])
	check(good.confirm() and good.fire(), "last-loaded boost fires first")
	var bad = fixture(["charge", "precise"], [["wall", 100, 0, 1, 30]])
	commands(bad, ["charge", "precise"])
	check(bad.confirm() and bad.fire(), "reverse loading comparison")
	check(good.s.enemies[0].hp < bad.s.enemies[0].hp, "last-loaded boost changes actual combo damage")
	# Every fitting follows strict LIFO, never silently jumps to the other end.
	for id in Ammo.AMMO:
		if Ammo.is_temporary(id) or Ammo.anchor(id).is_empty(): continue
		var model = fixture([id, "pierce"])
		if Ammo.anchor(id) == "last":
			commands(model, ["pierce"])
			var before := JSON.stringify(model.s)
			check(not model.load_round(id) and model.load_block_reason(id) == "먼저 장전", "rear fitting must be loaded first")
			check(JSON.stringify(model.s) == before, "rejected fitting is transactional")
			check(model.undo(), "recall stack top")
			commands(model, [id, "pierce"])
			check(model.s.plan == ["pierce", id] and not model.move_planned(1, 0), "rear fitting stays last fired")
		else:
			commands(model, ["pierce", id])
			var before := JSON.stringify(model.s)
			check(not model.load_round("basic") and not model.move_planned(0, 1), "first firing fitting closes stack until recalled")
			check(JSON.stringify(model.s) == before, "front fitting refusal transactional")
			check(model.undo() and model.load_round("basic"), "recalling front fitting reopens loading")
		save_same(model)
	for source in Ammo.FIELD_COMPRESSIONS:
		var model = fixture([source, source, "basic"])
		# Basic belongs to renewable supply, never the owned deck.
		model.s.deck.erase("basic")
		model.s.deck.append("pierce")
		model.s.hand.erase("basic")
		model.s.draw = model.s.deck.duplicate()
		model.s.draw.erase(source)
		model.s.draw.erase(source)
		var id: String = Ammo.field_id(source)
		if Ammo.anchor(id) == "last":
			commands(model, ["basic"])
			check(not model.can_field_compress(source), "rear compression must be first input")
			check(model.undo(), "recall before rear compression")
		else: commands(model, ["basic"])
		check(model.field_compress(source), "real compression enters top of stack")
		check(model.s.plan[0] == id, "compressed input is most recent and first")
		save_same(model)
		check(model.undo() and model.s.hand.count(source) == 2 and model.s.field_compression_left == 1, "compression recall restores pair and core")
		save_same(model)
	# Duplicate rounds and deliberate edits use visible positions for recall.
	var edited = fixture(["pierce", "charge", "pierce"])
	commands(edited, ["pierce", "charge", "pierce"])
	check(edited.undo() and edited.s.plan == ["charge", "pierce"], "duplicate recall removes newest top occurrence")
	commands(edited, ["pierce"])
	check(edited.move_planned(1, 0) and edited.s.plan == ["charge", "pierce", "pierce"], "manual edit explicitly changes firing order")
	check(edited.undo() and edited.s.plan == ["pierce", "pierce"], "recall after edit removes visible front")
	save_same(edited)
	# v9 plans and partially fired magazines retain the order already shown.
	for phase in ["plan", "ready", "partial"]:
		var original = fixture(["pierce", "precise", "charge"], [], "amplifier")
		original.s.capacity_bonus = 1
		commands(original, ["pierce", "precise", "charge"])
		if phase != "plan": check(original.confirm(), "legacy confirmed fixture")
		if phase == "partial": check(original.fire(), "legacy partial trigger fixture")
		var old: Dictionary = JSON.parse_string(JSON.stringify(original.s))
		old.version = 9
		var restored = Model.new()
		check(restored.restore_state(old) and restored.s.version == Model.VERSION, "v9 to current migration")
		old.version = Model.VERSION
		check(JSON.parse_string(JSON.stringify(restored.s)) == JSON.parse_string(JSON.stringify(old)), "migration preserves firing order, temperature and inventory")
		if phase == "plan":
			check(restored.load_round("basic") and restored.s.plan[0] == "basic", "new LIFO input on existing saved plan")
		else:
			check(restored.fire() and original.fire(), "resume partial or full magazine")
			check(JSON.parse_string(JSON.stringify(restored.s)) == JSON.parse_string(JSON.stringify(original.s)), "restored next shot produces identical state")
	# A real campaign remains restorable after each new loading command.
	for gun in Ammo.GUNS:
		var city = Campaign.new()
		city.start(gun, 731042)
		check(city.enter(101), "campaign entry")
		for id in city.model.s.hand.duplicate():
			if not city.model.can_load(id): continue
			check(city.model.load_round(id), "campaign public load")
			check(city.save("user://lifo_campaign.json") == OK, "campaign atomic save")
			var restored = Campaign.new()
			check(restored.restore("user://lifo_campaign.json") and restored.model.s.plan == city.model.s.plan, "campaign pending order resumes")
		check(city.model.confirm() and city.model.fire(), "campaign LIFO combat")
		city.sync_combat()
		check(city.save("user://lifo_campaign.json") == OK, "campaign save after fire")
		check(Campaign.new().restore("user://lifo_campaign.json"), "campaign result resumes")
	print("LIFO RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
