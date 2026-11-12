extends SceneTree

const Trial = preload("res://redesign/samples/opening_build/early_parts_campaign.gd")
const Solver = preload("res://tests/fire_control_solver.gd")
const Commands = preload("res://tests/weapon_magazine_solver.gd")
const FIRST_ROUTES := {17: [301, 402, 503, 603, 703, 802], 23: [302, 402, 502, 603, 703, 802]}
const SHOP_ROUTES := {17: [10201, 10301, 10401, 10502, 10603], 23: [10202, 10302, 10403, 10503, 10603]}
const NEXT_REGION_FIRST := 10101
const PART := Trial.StrikerUpgrade.PART
const BUY_PRIORITY := [PART, "lens", "opening", "afterburner", "radiator", "reclaimer", "chain_sink"]

var output: String
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/"):
		quit(2)
		return
	var comparisons := []
	for seed in FIRST_ROUTES:
		var row := {"seed": seed, "first_reward": {}, "investments": {}}
		for choice in ["part", "ammo", "credits", "credits_buy"]:
			var trial := Trial.new()
			trial.offer_enabled = true
			if not trial.prepare_checkpoint("single", seed): return fail("Earned first reward %d" % seed)
			var id: String = PART if choice == "part" else str(trial.reward_options()[0]) if choice == "ammo" else "credits"
			if not trial.reward(id): return fail("Reward rejected %s/%d" % [choice, seed])
			var stats := {"reward": id, "first_credits": trial.s.credits, "first_deck": trial.model.s.deck.duplicate(), "visits": []}
			if not follow(trial, FIRST_ROUTES[seed], stats.visits, choice == "credits_buy"): return fail("Region 1 route %s/%d" % [choice, seed])
			if not trial.gate("cadence") or not trial.depart_gate(): return fail("Same gate choice %s/%d" % [choice, seed])
			if not follow(trial, [NEXT_REGION_FIRST], stats.visits): return fail("Region 2 opening %s/%d" % [choice, seed])
			stats.end_credits = trial.s.credits
			stats.end_deck = trial.model.s.deck.duplicate()
			stats.end_parts = trial.equipped_parts()
			row.first_reward[choice] = stats
			print("EARLY ROUTE ", seed, " ", choice, " credits ", stats.end_credits)
			if choice == "part":
				row.investments = compare_shop(trial, seed)
				if row.investments.is_empty(): return fail("Region 2 shop %d" % seed)
		comparisons.append(row)
	FileAccess.open(output.path_join("investment.json"), FileAccess.WRITE).store_string(JSON.stringify(comparisons, "  "))
	print("EARLY PARTS INVESTMENT COMPLETE seeds=%d failures=%d" % [comparisons.size(), failures])
	quit(failures)

func follow(trial: Trial, route: Array, visits: Array, buy_first_part := false) -> bool:
	for node in route:
		if not trial.enter(node): return false
		var room := trial.node()
		var visit := {"id":node, "name":room.name, "kind":room.kind, "region":int(trial.s.region)+1}
		match str(trial.s.phase):
			"combat":
				var start: Dictionary = trial.model.s
				var path := Solver.new().ranged(start, 72, 42, true)
				if path.is_empty(): path = Solver.new().solve(trial.model)
				if path.is_empty():
					print("No winning path for ", node, " deck ", start.deck)
					return false
				visit.battle = replay(start, path, trial.model)
				trial.sync_combat()
				if trial.s.phase != "reward" or not trial.reward("skip" if trial.boss_loot() else "credits"): return false
			"shop":
				visit.offers = trial.s.offers.duplicate(true)
				if buy_first_part:
					var index := part_offer(trial)
					if index < 0 or not trial.buy(index): return false
					visit.purchase = trial.s.offers[index].duplicate(true)
				if not trial.leave(): return false
			"event", "supply":
				if not trial.resolve("skip") or not trial.leave(): return false
			_:
				if not trial.leave(): return false
		visit.credits = trial.s.credits
		visits.append(visit)
	return true

func part_offer(trial: Trial) -> int:
	var offers: Array = trial.s.offers
	var first := -1
	for index in range(offers.size()):
		var item: Dictionary = offers[index]
		if item.type != "part" or item.sold or int(item.price) > int(trial.s.credits) or trial.s.parts.has(item.id): continue
		if not Trial.Ammo.valid_part_set(str(trial.s.gun), trial.equipped_parts() + [item.id], trial.model.s): continue
		if first < 0: first = index
		if BUY_PRIORITY.has(item.id) and (not BUY_PRIORITY.has(offers[first].id) or BUY_PRIORITY.find(item.id) < BUY_PRIORITY.find(offers[first].id)): first = index
	return first

func compare_shop(trial: Trial, seed: int) -> Dictionary:
	var route: Array = SHOP_ROUTES[seed]
	var visits := []
	if not follow(trial, route.slice(0, -2), visits) or not trial.enter(int(route[-2])) or trial.s.phase != "shop": return {}
	var shop_path := output.path_join("shop_%d.json" % seed)
	if trial.save(shop_path) != OK: return {}
	var shop := {"id":trial.s.node, "name":trial.node().name, "credits":trial.s.credits, "offers":trial.s.offers.duplicate(true), "visits":visits}
	var item_index := part_offer(trial)
	if item_index < 0: return {}
	shop.purchase = trial.s.offers[item_index].duplicate(true)
	var starts := {}
	var path_candidates := []
	for choice in ["keep", "upgrade", "buy"]:
		var branch := Trial.new()
		if not branch.restore(shop_path): return {}
		if branch.can_upgrade_striker(): return {}
		branch.upgrade_enabled = true
		if choice == "upgrade" and (not branch.upgrade_striker() or branch.upgrade_striker()): return {}
		if choice == "buy" and not branch.buy(item_index): return {}
		if not branch.leave() or not branch.enter(int(route.back())): return {}
		var state: Dictionary = branch.model.s
		var path := Solver.new().ranged(state, 72, 42, true)
		if path.is_empty(): path = Solver.new().solve(branch.model)
		if path.is_empty(): return {}
		path_candidates.append(path)
		starts[choice] = {"state":state, "credits":branch.s.credits, "parts":branch.equipped_parts()}
	var results := {}
	for choice in starts:
		var entry: Dictionary = starts[choice]
		var outcomes := []
		for path in path_candidates:
			var model = Trial.Model.new()
			outcomes.append(replay(entry.state, path, model))
		results[choice] = {"credits":entry.credits, "parts":entry.parts, "magazine":entry.state.magazine, "outcomes":outcomes}
	shop.results = results
	shop.next_node = int(route.back())
	shop.paths = path_candidates
	return shop

func replay(start: Dictionary, path: Array, model) -> Dictionary:
	var state := start.duplicate(true)
	model.s = state
	var history: int = state.history.size()
	var turns := int(state.turns)
	var shots := int(state.shots)
	var accepted := true
	for step in path:
		if str(state.phase) != "ready": break
		match str(step.action):
			"fire":
				state.fire_heat_trial.rounds = int(step.get("rounds", 0))
				accepted = model.fire()
			"eject": accepted = model.eject_magazine_rounds(step.indices)
			_: accepted = Commands.command(model, "swap" if step.action == "reload" else str(step.action))
		if not accepted: break
	var forced := 0
	var heat_peak := 0
	var strikes := []
	for event in state.history.slice(history):
		if event.action != "fire": continue
		if not event.detail.get("forced_cooling", {}).is_empty(): forced += 1
		heat_peak = maxi(heat_peak, int(event.detail.get("heat_peak", 0)))
		for shot in event.detail.results:
			if not shot.get("part_effects", []).any(func(effect): return effect.id == PART): continue
			strikes.append({"round":shot.id,"damage":shot.get("damage",0),"factor":shot.get("part_factor",1),"hp":shot.get("hp",0),"math":shot.get("math",{})})
	return {"accepted":accepted,"phase":state.phase,"turns":int(state.turns)-turns,"rounds":int(state.shots)-shots,
		"forced_cooling":forced,"heat_peak":heat_peak,"strikes":strikes,"path":path}

func fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
	quit(1)
