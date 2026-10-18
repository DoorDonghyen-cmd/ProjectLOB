extends "res://tests/heat_rules_runner.gd"

func store_fixture():
	var campaign = Campaign.new()
	campaign.start("burst", 731042, 0, "balanced", 1)
	campaign.s.floor = 3
	campaign.s.node = 301
	campaign.s.visited = [101, 201, 301]
	check(campaign.enter(401), "legal shop entry")
	campaign.s.credits = 100
	return campaign

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_grade/rules"):
		quit(1)
		return
	check(Ammo.COMPRESSIONS.size() == 17, "all ordinary tactical families can grow")
	check(Ammo.grade("basic") == -1 and not Ammo.COMPRESSIONS.has("basic"), "supply is outside grade growth")
	for source in Ammo.COMPRESSIONS:
		var result: String = Ammo.compressed_id(source)
		var temporary: String = Ammo.field_id(source)
		check(Ammo.grade(source) == 0 and Ammo.grade(result) == 1 and Ammo.grade(temporary) == 1, "one grade transition " + source)
		check(not Ammo.COMPRESSIONS.has(result) and not Ammo.COMPRESSIONS.has(temporary), "advanced and temporary cannot be recompressed")
		for key in Ammo.AMMO[result]:
			if key != "text": check(Ammo.AMMO[result][key] == Ammo.AMMO[temporary][key], "field profile equals permanent " + source + " " + key)
		for gun in Ammo.GUNS:
			var model = fixture([result], [], gun)
			model.s.heat = 4
			model.s.enemies[0].burn = 3
			fire(model, [result])
			model = fixture([source, source], [], gun)
			var original: Array = model.s.deck.duplicate()
			check(model.field_compress(source), "field grade-up " + gun + " " + source)
			check(model.s.plan == [temporary] and model.s.deck == original, "temporary never mutates collection")
			var loaded = Model.new()
			check(loaded.restore_state(JSON.parse_string(JSON.stringify(model.s))), "pending temporary save roundtrip")
			check(model.undo() and model.s.hand.count(source) == 2 and model.s.field_compression_left == 1, "cancel restores two inputs and charge")
			check(model.field_compress(source) and model.confirm() and model.fire(), "temporary actually fires")
			check(not model.s.discard.has(temporary) and model.s.field_compression.is_empty(), "temporary spent into ordinary sources")
			check(model.s.discard.count(source) == 2 or model.s.hand.count(source) + model.s.draw.count(source) + model.s.discard.count(source) == 2, "two sources conserved through forced reload")
			check(loaded.restore_state(JSON.parse_string(JSON.stringify(model.s))), "spent temporary save roundtrip")
		var campaign = store_fixture()
		campaign.model.s.deck = [source, source, "pierce", "bore", "charge", "precise", "cool", "push", "arc", "shatter"]
		check(campaign.shop_compress(source), "paid permanent grade-up " + source)
		check(campaign.model.s.deck.size() == 9 and campaign.model.s.deck.has(result) and campaign.s.credits == 82, "permanent pays exact pair and price")
		check(not campaign.shop_compress(source), "shop compression visit lock")
		check(campaign.reroll() and not campaign.shop_compress(source), "reroll cannot clear visit lock")
		check(campaign.save("user://grade_run.json") == OK, "save permanent grade")
		var restored = Campaign.new()
		check(restored.restore("user://grade_run.json") and restored.model.s.deck == campaign.model.s.deck and restored.s.shop_refined, "permanent grade and lock roundtrip")
	var campaign = store_fixture()
	var before := JSON.stringify(campaign.model.s.deck)
	campaign.s.credits = 0
	check(not campaign.shop_compress("charge") and JSON.stringify(campaign.model.s.deck) == before, "insufficient currency is atomic")
	campaign.s.credits = 100
	campaign.model.s.deck = ["cool", "cool", "pierce", "bore", "charge", "push", "arc", "shatter"]
	check(not campaign.shop_compress("cool"), "minimum deck remains eight")
	var model = fixture(["detonate_c"], [["wall", 100, 20, 1, 30]])
	model.s.enemies[0].burn = 3
	var shots := fire(model, ["detonate_c"])
	var primed_damage: int = shots[0].damage
	check(shots[0].detonation == 6, "advanced ignition doubles remaining burn through armor")
	model = fixture(["detonate_c"], [["wall", 100, 20, 1, 30]])
	shots = fire(model, ["detonate_c"])
	check(shots[0].detonation == 0 and primed_damage - int(shots[0].damage) == 6, "advanced ignition without prerequisite has no extra payoff")
	model = fixture(["cool_c", "charge_hot"])
	model.s.heat = 4
	shots = fire(model, ["cool_c", "charge_hot"])
	check(shots[0].cooled == 4 and model.s.heat == 5, "advanced cooling cannot bank cold for later heat")
	check(not Ammo.valid_stack(["charge_hot", "cool_c"], 4), "cooling grade has meaningful first-shot restriction")
	model = fixture(["shatter_c", "precise"])
	shots = fire(model, ["shatter_c", "precise"])
	check(shots[0].armor_removed == 4 and shots[1].damage > shots[0].damage, "opening armor break supports follow-up")
	model = fixture(["thermal_c"])
	model.s.heat = 6
	shots = fire(model, ["thermal_c"])
	check(shots[0].overheated and model.s.reloads == 1, "advanced high heat pays mandatory reload at boundary")
	model = fixture(["disrupt_c"], [["spitter", 100, 0, 0, 30]])
	shots = fire(model, ["disrupt_c"])
	check(shots[0].interrupted == 2, "advanced disrupt pauses actual preparation for two turns")
	model = fixture(["spread_c"])
	model.s.enemies[0].burn = 5
	shots = fire(model, ["spread_c"])
	check(shots[0].transferred == 4, "advanced ember transfers four burn without duplication")
	model = fixture(["prepare_c", "charge", "pierce"])
	shots = fire(model, ["prepare_c", "charge", "pierce"])
	check(shots[0].prepared_rounds == ["charge", "pierce"], "two-slot reservation actually retains two follow-up cards")
	check(model.reload_magazine() and model.s.hand.has("charge") and model.s.hand.has("pierce"), "reserved cards return on reload")
	model = fixture(["shatter", "cool", "sequence_c"])
	shots = fire(model, ["shatter", "cool", "sequence_c"])
	check(shots[2].sequence_bonus == 6, "advanced finisher counts distinct earlier families")
	model = fixture(["vent_c"])
	model.s.heat = 6
	shots = fire(model, ["vent_c"])
	check(shots[0].vented == 6 and shots[0].vent_bonus == 18 and model.s.heat == 0, "two-slot vent trades six real heat for eighteen damage")
	model = fixture(["chase_c"], [["runner", 1, 0, 1, 30], ["wall", 100, 0, 1, 34]])
	shots = fire(model, ["basic", "chase_c"])
	check(shots[1].chase_bonus == 7, "advanced chase pays off after actual preceding kill")
	model = fixture(["precise", "precise", "pierce", "pierce"])
	check(model.load_round("precise") and model.load_round("precise") and model.load_round("basic") and not model.can_field_compress("pierce"), "two-slot field upgrade cannot overfill magazine")
	var normal_count := 0
	var advanced_count := 0
	for seed_value in range(200):
		var early := Data.rewards({"id": 101, "region": 0, "floor": 1}, seed_value)
		check(early[0] == "pierce" and Ammo.grade(early[1]) == 0, "opening keeps ordinary ingredients")
		var node := {"id": 10401, "region": 1, "floor": 4}
		var offers := Data.offers(node, seed_value, 0, "single", [])
		for offer in offers:
			if offer.type != "ammo": continue
			check(not Ammo.is_temporary(offer.id), "temporary grades never sold")
			check(offer.price == (24 if Ammo.grade(offer.id) == 1 else 12), "grade price")
			if Ammo.grade(offer.id) == 1: advanced_count += 1
			else: normal_count += 1
	check(normal_count > advanced_count and advanced_count > 0, "ordinary majority plus occasional advanced finds")
	# Old stored high-output offer keeps its original price on load.
	campaign = store_fixture()
	campaign.s.offers = [{"id": "charge_hot", "type": "ammo", "price": 12, "sold": false}]
	check(campaign.save("user://legacy_offer.json") == OK, "save legacy shelf")
	var restored = Campaign.new()
	check(restored.restore("user://legacy_offer.json") and restored.s.offers[0].price == 12, "legacy shelf price is not silently rewritten")
	print("AMMO GRADE RULES COMPLETE checks=%d failures=%d ordinary=%d advanced=%d" % [checks, failures, normal_count, advanced_count])
	quit(0 if failures == 0 else 1)
