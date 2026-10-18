extends "res://tests/heat_rules_runner.gd"

func conserved(model) -> void:
	var owned: Array = model.s.hand + model.s.draw + model.s.discard
	for id in model.s.magazine:
		if id == "basic": continue
		if Ammo.is_temporary(id): owned.append_array([Ammo.source_id(id), Ammo.source_id(id)])
		else: owned.append(id)
	owned.sort()
	var deck: Array = model.s.deck.duplicate()
	deck.sort()
	check(owned == deck, "cycling neither duplicates nor destroys cards")
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(model.s))), "temperature and expanded hand restore")
	check(JSON.stringify(JSON.parse_string(JSON.stringify(restored.s))) == JSON.stringify(JSON.parse_string(JSON.stringify(model.s))), "restore changes no order, heat or RNG")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/decision_revision/"):
		quit(1)
		return
	for gun in Ammo.GUNS:
		for slots in range(3):
			for parts in [[], ["supply"], ["field_press"], ["radiator", "reclaimer"]]:
				var model = Model.new()
				model.start(gun, 731042)
				model.s.capacity_bonus = slots
				model.s.equipped_parts = parts.duplicate()
				model.begin_encounter()
				check(model.s.hand.size() == mini(model.s.deck.size(), Ammo.hand_capacity(model.s)), "outfit hand independent from magazine growth and slot penalties")
				conserved(model)
				model.load_round("basic")
				model.confirm()
				model.s.heat = Ammo.heat_limit(model.s) - 1
				var before: Dictionary = model.s.duplicate(true)
				var next: Array = model.s.draw.duplicate()
				var prediction := Forecast.reload_now(model.s)
				check(model.s == before, "reload preview pure, including unused hand and RNG")
				check(model.reload_magazine(), "manual reload legal")
				check(model.s.heat == maxi(0, int(before.heat) - int(Ammo.GUNS[gun].reload_cooling)), "weapon-specific cooling leaves exact remainder")
				check(prediction.temperature_after == model.s.heat and prediction.enemies == model.s.enemies, "reload preview matches temperature and threats")
				check(model.s.hand.slice(0, next.size()) == next, "known draw pile is drawn first, unused hand is not retained")
				check(model.s.hand.size() == mini(model.s.deck.size(), Ammo.hand_capacity(model.s)), "full new hand after cycling")
				conserved(model)
	# Exact public alternatives from the same hot state. Putting coolant first
	# buys four shots; putting it last cannot undo the first shot's overheat.
	var variants: Array = []
	for order in [["pierce", "basic", "basic", "cool"], ["cool", "pierce", "basic", "basic"]]:
		var model = fixture(["pierce", "cool"], [["wall", 60, 3, 1, 30]], "heavy")
		model.s.heat = 10
		conserved(model)
		var results := fire(model, order)
		variants.append({"shots": results.size(), "turns": model.s.turns, "heat": model.s.heat, "hp": model.s.enemies[0].hp})
		conserved(model)
	check(variants[0].shots == 1 and variants[0].turns == 3 and variants[0].heat == 0, "hot careless order stops with three rounds unfired")
	check(variants[1].shots == 4 and variants[1].turns == 1 and variants[1].heat == 12, "cool-first keeps chain at price of little damage in one slot")
	check(variants[1].hp < variants[0].hp, "same hand and heat have different damage and tempo")
	# Previously saved firing order and hand are kept. New draw rules apply on
	# reload, never by adding/reordering cards during a version migration.
	for phase in ["plan", "ready"]:
		var model = fixture(["pierce", "charge", "precise"])
		model.load_round("pierce")
		model.load_round("charge")
		if phase == "ready": model.confirm()
		var legacy: Dictionary = model.s.duplicate(true)
		legacy.version = 10
		var restored = Model.new()
		check(restored.restore_state(legacy), "v10 save accepted")
		check(restored.s.version == Model.VERSION and restored.s.hand == model.s.hand and restored.s.plan == model.s.plan and restored.s.magazine == model.s.magazine, "v10 ordered arrays and small hands preserved")
	# Random outcomes also include a temperature interval after manual reload.
	var scatter = fixture(["bore", "arc", "precise"], [], "scatter")
	scatter.s.heat = 8
	for id in Ammo.loading_order(["arc", "bore", "precise"]): scatter.load_round(id)
	var snapshot: Dictionary = scatter.s.duplicate(true)
	var forecast := Forecast.analyze(scatter.s, true, true)
	check(scatter.s == snapshot, "scatter branching leaves hand and RNG unchanged")
	check(forecast.reload.has("temperature_min") and forecast.reload.has("temperature_max"), "random reload temperature bounds public")
	print("DECISION REVISION RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
