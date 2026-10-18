extends "res://tests/ammo_choice_audit.gd"
## Two public, fixed policies. Neither reads target RNG, draw order or outcomes.
const PACKAGES := {
	"baseline": [], "firepower": ["opening", "duplex"],
	"cooling": ["radiator", "reclaimer"], "hot": ["ember_core", "duplex"],
	"buffered_hot": ["ember_core", "radiator"]
}
const DECKS := {
	"combo": ["charge", "charge", "precise", "precise", "pierce", "pierce", "bore", "detonate", "arc", "push"],
	"thermal": ["charge_hot", "charge_hot", "thermal", "thermal", "vent", "vent", "precise", "pierce", "cool", "push"],
	"elemental": ["bore", "bore", "detonate", "detonate", "arc", "arc", "charge", "pierce", "cool", "push"]
}

func heat_plan(model) -> Array:
	var plan: Array = []
	var heat := int(model.s.heat)
	var limit := Ammo.heat_limit(model.s)
	var hot := Ammo.hot_threshold(model.s)
	var pool: Array = model.s.hand.duplicate()
	for i in range(model.s.supply): pool.append("basic")
	# Conservative temperature accounting: kill cooling is never assumed.
	# No enemy/shot simulation, no hidden RNG, no future hand inspection.
	while not pool.is_empty() and plan.size() < model.capacity():
		var best := ""
		var value := -INF
		var left: int = model.capacity() - plan.size()
		for id_value in pool:
			var id := str(id_value)
			if not Ammo.valid_stack(plan + [id], model.capacity()): continue
			var weight := float(Ammo.damage(id, model.s) * Ammo.hit_count(id, model.s))
			match id:
				"charge", "charge_hot": weight += 13 if left >= 3 else -8
				"bore": weight += 7 if not plan.has("bore") else 0
				"detonate": weight += 10 if plan.has("bore") else -5
				"thermal": weight += Ammo.effect_value(id, model.s) if heat >= hot else -4
				"arc": weight += 3
				"vent": weight += mini(heat, 4) * Ammo.effect_value(id, model.s) if left == 1 else -20
				"cool": weight += 20 if heat >= limit - 4 and left >= 2 else -20
			if heat + Ammo.heat_delta(id, model.s) >= limit and left >= 2: weight -= 16
			if weight > value:
				value = weight
				best = id
		if best.is_empty(): break
		pool.erase(best)
		plan.append(best)
		heat = maxi(0, heat + Ammo.heat_delta(best, model.s))
		if best == "vent": heat = maxi(0, heat - 4)
		if heat >= limit: break
	return plan

func run_case(base, policy: String, policy_seed: int) -> Dictionary:
	var model = clone(base)
	var random := RandomNumberGenerator.new()
	random.seed = policy_seed
	var first: Array = []
	for cycle in range(40):
		if model.s.phase == "ready": require(model.reload_magazine(), "reload")
		if model.s.phase != "plan": break
		var plan := heat_plan(model) if policy == "heat_order" else random_plan(model, random)
		if first.is_empty(): first = plan.duplicate()
		execute(model, plan)
	require(model.s.phase in ["reward", "won", "lost"], "terminal")
	var metrics := {"forced": 0, "cooling": 0, "vented": 0, "vent_shots": 0, "thermal_hot": 0, "thermal_shots": 0, "ember_shots": 0, "unfired": 0}
	var loaded := 0
	for event in model.s.history:
		var detail: Dictionary = event.detail
		if event.action == "load": loaded += detail.load_order.size()
		if event.action != "fire": continue
		if not detail.get("forced_reload", {}).is_empty(): metrics.forced += 1
		for shot in detail.results:
			metrics.cooling += int(shot.get("kill_cooled", 0))
			metrics.vented += int(shot.get("vented", 0))
			if shot.id == "vent": metrics.vent_shots += 1
			if shot.id == "thermal":
				metrics.thermal_shots += 1
				if int(shot.get("thermal_bonus", 0)) > 0: metrics.thermal_hot += 1
			for effect in shot.get("part_effects", []):
				if effect.id == "ember_core": metrics.ember_shots += 1
	metrics.unfired = loaded - int(model.s.shots)
	return {"policy": policy, "won": model.s.phase in ["reward", "won"], "turns": model.s.turns, "shots": model.s.shots, "reloads": model.s.reloads, "opening": first, "metrics": metrics}

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/heat_polish/"):
		quit(1)
		return
	for gun in Ammo.GUNS:
		for seed_value in [17, 42, 109, 731042]:
			for location in [[0, 5], [1, 7], [3, 5], [4, 7]]:
				var nodes: Array = Data.nodes(location[0], seed_value).filter(func(n): return int(n.floor) == int(location[1]) and n.kind in ["combat", "boss"])
				require(not nodes.is_empty(), "production node exists")
				if nodes.is_empty(): continue
				var node: Dictionary = nodes[0]
				for deck in DECKS:
					for package in PACKAGES:
						var campaign = Campaign.new()
						campaign.start(gun, seed_value)
						campaign.model.s.deck = DECKS[deck].duplicate()
						campaign.s.parts = PACKAGES[package].duplicate()
						campaign.s.equipped_parts = PACKAGES[package].duplicate()
						campaign.s.region = node.region
						campaign.s.floor = int(node.floor) - 1
						require(campaign.enter(int(node.id)), "enter real encounter")
						require(Ammo.equipped_parts(campaign.model.s) == PACKAGES[package], "fixture equipment")
						for policy in ["random", "heat_order"]:
							var result := run_case(campaign.model, policy, seed_value + int(node.id) * 7)
							result.merge({"gun": gun, "seed": seed_value, "node": node.id, "region": node.region, "floor": node.floor, "deck": deck, "package": package, "hand": campaign.model.s.hand})
							rows.append(result)
		print("HEAT AUDIT " + gun + " rows=" + str(rows.size()))
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("heat_build_audit.json"), FileAccess.WRITE).store_string(JSON.stringify({"method": "Four seeds, five guns, four real production encounters with reserves, three identical ten-card decks per matched package. Four equal two-part packages plus zero-part diagnostic baseline. Independent encounters, not a campaign/economy simulation. Random shuffle versus fixed heat-aware hand heuristic; neither reads hidden RNG, future draw or outcomes. No exchange/compression/upgrade search. Policies are probes, not optimal players or human win rates. Cooling estimate ignores kill cooling; unfired includes terminal unused ammo, not just heat loss.", "rows": rows, "failures": failures}, "\t"))
	print("HEAT AUDIT COMPLETE rows=%d failures=%d" % [rows.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
