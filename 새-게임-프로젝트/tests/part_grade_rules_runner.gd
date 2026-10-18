extends "res://tests/progression_rules_runner.gd"

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/part_grade/rules"):
		quit(1)
		return
	var counts := [0, 0, 0]
	for id in Ammo.PARTS:
		if id == "none": continue
		check(Ammo.PARTS[id].has("grade") and Ammo.part_grade(id) in [0, 1, 2], "explicit valid grade " + id)
		counts[Ammo.part_grade(id)] += 1
	check(counts == [8, 13, 7], "deliberate distribution")
	check(Ammo.part_grade("cooling_breech") == 1 and Ammo.is_core_part("cooling_breech"), "grade independent from core")
	check(not Ammo.valid_part_set("burst", ["cooling_breech", "overbore"]), "different grades cannot bypass core cap")
	check(Ammo.valid_part_set("burst", ["lens", "ordinary_chain", "overbore", "coil", "reserve"]), "mixed grades use existing five slots")
	for node in [{"id": 401, "region": 0}, {"id": 10401, "region": 2}, {"id": 10501, "region": 2, "elite": true}]:
		var observed := [0, 0, 0]
		var actual := [0, 0, 0]
		var random := Data.rng(731042, int(node.id))
		var pool: Array = Data.eligible_parts("burst")
		for i in range(10000): observed[Ammo.part_grade(Data.pick_part(pool, node, random))] += 1
		var weights: Array = Data.part_grade_weights(node)
		for grade in range(3): check(absf(observed[grade] / 100.0 - weights[grade]) < 2.0, "grade draw distribution")
		for seed_value in range(1000):
			var offers: Array = Data.offers(node, seed_value, 0, "burst", ["lens"])
			check(offers == Data.offers(node, seed_value, 0, "burst", ["lens"]), "stable seeded shelf")
			var ids: Array = []
			for offer in offers:
				if offer.type != "part": continue
				check(offer.id != "lens" and not ids.has(offer.id), "owned excluded and no duplicate")
				ids.append(offer.id)
				actual[Ammo.part_grade(offer.id)] += 1
		print("GRADE DISTRIBUTION node=%s draw=%s actual_shelf=%s" % [node, observed, actual])
	# Depleted grades and unseen priority must never strand the remaining part.
	var owned: Array = Data.eligible_parts("burst")
	owned.erase("field_press")
	var last := Data.offers({"id": 401, "region": 0}, 77, 0, "burst", owned)
	check(last.size() == 2 and last[1].id == "field_press", "fallback offers last rare core even in opening")
	check(Data.offers({"id": 401}, 77, 0, "burst", Data.eligible_parts("burst")).size() == 1, "fully owned pool safe")
	var campaign = shop()
	var snapshot: Dictionary = {"campaign": campaign.s, "combat": campaign.model.s, "profile": campaign.profile}
	var restored = Campaign.new()
	check(restored.restore_state(snapshot), "existing save schema restores without stored grade")
	check(restored.s.offers == campaign.s.offers and restored.s.parts == campaign.s.parts, "pending offers and inventory preserved")
	print("PART GRADE RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
