extends "res://tests/heat_rules_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/outfit_bag/rules"):
		quit(1)
		return
	for gun in Ammo.GUNS:
		for outfit in Ammo.OUTFITS:
			var spec: Dictionary = Ammo.OUTFITS[outfit]
			for parts in [[], ["reserve"], ["supply"], ["field_press"], ["cooling_breech"], ["overbore", "reserve", "supply"]]:
				var m = Model.new()
				m.start(gun, 731042, false, outfit)
				m.s.capacity_bonus = 2
				m.s.equipped_parts = parts
				m.begin_encounter()
				m.s.enemies = [Data._enemy(["wall", 999, 0, 0, 100])]
				m.assign_opening_lanes()
				m.s.encounter_total = 1
				m.s.deployed = 1
				check(m.s.hand.size() == spec.hand, "outfit hand unaffected by gun/slots/parts")
				var budget: int = int(spec.exchange) + (1 if parts.has("reserve") else 0)
				check(m.s.exchange_left == budget, "reserve adds to outfit exchange")
				for i in range(budget): check(m.exchange(str(m.s.hand[0])), "use each permitted exchange")
				var frozen := JSON.stringify(m.s)
				check(not m.exchange(str(m.s.hand[0])) and JSON.stringify(m.s) == frozen, "no exchanges past budget")
				check(m.load_round("basic") and m.confirm(), "prepare legal reload")
				check(m.reload_magazine() and m.s.hand.size() == spec.hand and m.s.exchange_left == budget, "reload restores selected outfit budgets")
				check(Model.new().restore_state(m.s), "outfit zones save correctly")
				# Even a magazine larger than the bag remains fillable with basic supply.
				while m.s.plan.size() < m.capacity(): check(m.load_round("basic"), "large magazine accepts basic supply")
				check(m.confirm(), "full large magazine confirms")
				check(Model.new().restore_state(m.s), "confirmed plan preserves outfit")
				check(m.fire(), "full magazine fires with outfit")
			for seed_value in range(12):
				var c = Campaign.new()
				c.start(gun, seed_value, 0, "balanced", 1, outfit)
				check(c.enter(101) and c.model.s.outfit == outfit and c.model.s.hand.size() == spec.hand, "room entry preserves selection")
				var copy = Campaign.new()
				var state := {"campaign": c.s, "combat": c.model.s, "profile": c.profile}
				check(copy.restore_state(state) and copy.s.outfit == outfit, "campaign resume preserves outfit")
				state = state.duplicate(true)
				state.combat.outfit = "carrier" if outfit != "carrier" else "work"
				check(not Campaign.new().restore_state(state), "reject mismatched campaign/combat outfits")
	for outfit in Ammo.OUTFITS:
		var hot = fixture(["charge_hot", "precise", "pierce"], [["wall", 999, 0, 0, 100]])
		hot.s.outfit = outfit
		hot.s.heat = Ammo.heat_limit(hot.s) - 1
		hot.s.exchange_left = 0
		var result := fire(hot, ["charge_hot", "precise"])
		check(result.size() == 1 and hot.s.reloads == 1 and hot.s.heat == 0, "overheat fires triggering round then reloads")
		check(hot.s.hand.size() == Ammo.OUTFITS[outfit].hand and hot.s.exchange_left == Ammo.OUTFITS[outfit].exchange, "forced reload uses outfit budgets")
		var saved = Campaign.new()
		saved.start("single", 29, 0, "balanced", 1, outfit)
		saved.enter(101)
		saved.model.load_round("basic")
		var plan: Array = saved.model.s.plan.duplicate()
		var path: String = "user://outfit_" + str(outfit) + ".json"
		check(saved.save(path) == OK, "atomic outfit save")
		var loaded = Campaign.new()
		check(loaded.restore(path) and loaded.model.s.plan == plan and loaded.s.outfit == outfit, "disk resume preserves outfit and pending plan")
	# Legacy in-progress runs keep both their full hand and exhausted exchange state.
	var legacy = Campaign.new()
	legacy.start("scatter", 22, 0, "balanced", 1)
	for key in ["bag_version", "bag_upgrades"]:
		legacy.s.erase(key)
		legacy.model.s.erase(key)
	legacy.s.erase("outfit")
	legacy.model.s.erase("outfit")
	check(legacy.enter(101) and legacy.model.s.hand.size() == 7, "legacy capacity plus two unchanged")
	legacy.model.s.exchange_left = 0
	var old := {"campaign": legacy.s, "combat": legacy.model.s, "profile": legacy.profile}
	var restored = Campaign.new()
	check(restored.restore_state(old), "old campaign loads without outfit")
	check(restored.model.s.hand == legacy.model.s.hand and restored.model.s.exchange_left == 0 and not restored.s.has("outfit"), "no lost hand or free legacy exchanges")
	var invalid: Dictionary = legacy.model.s.duplicate(true)
	invalid.outfit = "unknown"
	check(not Model.new().restore_state(invalid), "reject unknown outfit")
	invalid.outfit = 7
	check(not Model.new().restore_state(invalid), "reject invalid outfit type")
	print("OUTFIT BAG RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
