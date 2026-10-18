extends "res://tests/ammo_expansion_rules_runner.gd"
## Independent early encounters, actual starter deck/scout bag, no growth or save I/O.
var rows: Array = []
var audit_outfit := "scout"

func copy_model(base):
	var m = Model.new()
	m.s = base.s.duplicate(true)
	return m

func plans(hand: Array, capacity_value: int, prefix: Array = []) -> Array:
	var result: Array = [prefix] if not prefix.is_empty() else []
	var used: Array = []
	for i in range(hand.size()):
		var id = hand[i]
		if used.has(id) or Ammo.slots_used(prefix) + Ammo.slot_cost(id) > capacity_value: continue
		used.append(id)
		var rest := hand.duplicate()
		rest.remove_at(i)
		result.append_array(plans(rest, capacity_value, prefix + [id]))
	return result

func execute(m, order: Array) -> void:
	for id in Ammo.loading_order(order): check(m.load_round(id), "audit legal load")
	check(m.confirm(), "audit confirm")
	while m.s.phase == "ready" and not m.s.magazine.is_empty(): check(m.fire(), "audit fire")

func score(m) -> float:
	if m.s.phase == "lost": return -100000.0
	if m.s.phase in ["won", "reward"]: return 100000.0 - m.s.turns
	var value := -float(m.s.turns) * 4
	for e in m.s.enemies:
		value += (e.max_hp - e.hp) * 2 + (25 if e.hp == 0 else 0)
		if e.hp > 0: value += e.distance * 0.1 + int(e.get("burn", 0))
	return value

func simulate(base, guided: bool, seed_value: int) -> Dictionary:
	var m = copy_model(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for cycle in range(32):
		if m.s.phase not in ["plan", "ready"]: break
		if m.s.phase == "ready": check(m.reload_magazine(), "audit reload")
		if m.s.phase != "plan": break
		var order: Array = []
		if guided:
			var best := -INF
			for candidate in plans(m.s.hand, m.capacity()):
				var trial = copy_model(m)
				execute(trial, candidate)
				var value := score(trial)
				if value > best: best = value; order = candidate
		else:
			var hand: Array = m.s.hand.duplicate()
			while not hand.is_empty():
				var index := rng.randi_range(0, hand.size()-1)
				var id = hand.pop_at(index)
				if Ammo.slots_used(order) + Ammo.slot_cost(id) <= m.capacity(): order.append(id)
		if order.is_empty(): check(m.reload_magazine(), "empty hand reload")
		else: execute(m, order)
	check(m.s.phase in ["lost", "won", "reward"], "audit terminates")
	return {"won":m.s.phase in ["won", "reward"], "turns":m.s.turns, "reloads":m.s.reloads}

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/early_ammo/"): quit(1); return
	if Ammo.OUTFITS.has(OS.get_environment("AUDIT_OUTFIT")): audit_outfit = OS.get_environment("AUDIT_OUTFIT")
	for gun in Ammo.GUNS:
		for seed_value in [17, 42, 109, 913, 2048, 731042]:
			var c = Campaign.new()
			c.start(gun, seed_value, 0, "balanced", Data.RouteMap.VERSION, audit_outfit)
			var seen: Array = []
			for node in c.current_nodes():
				if node.kind != "combat" or seen.has(node.floor): continue
				if OS.get_environment("AUDIT_ENCOUNTERS") == "decision" and int(node.floor) not in [2,3,4,5]: continue
				seen.append(node.floor)
				if seen.size() > 3: break
				var encounter = Campaign.new()
				encounter.start(gun, seed_value, 0, "balanced", Data.RouteMap.VERSION, audit_outfit)
				encounter.s.floor = int(node.floor)-1
				check(encounter.enter(node.id), "production node entry")
				for guided in [false, true] if gun != "scatter" else [false]:
					var result := simulate(encounter.model, guided, seed_value + node.id)
					result.merge({"gun":gun,"seed":seed_value,"floor":node.floor,"guided":guided,"outfit":audit_outfit})
					rows.append(result)
		print("AUDIT gun=",gun," rows=",rows.size())
	var path := OS.get_environment("QA_OUTPUT_DIR").path_join(OS.get_environment("AUDIT_TAG") + ".json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures}, "\t"))
	print("EARLY AUDIT COMPLETE rows=%d failures=%d" % [rows.size(), failures])
	quit(0 if failures == 0 else 1)
