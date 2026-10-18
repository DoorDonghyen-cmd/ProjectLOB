extends "res://tests/heat_build_audit.gd"
## Review-only probe. Runtime data/rules are never modified.
## Full campaigns use legal commands and fixed, non-oracular policies.
var campaigns: Array = []
var choices: Array = []
var independent: Array = []

func fixed_plan(model) -> Array:
	# Screen groups duplicate copies at the first occurrence of each family.
	# Ignore the renewable basic button until all tactical cards were considered.
	var pool: Array = []
	var seen: Array = []
	for id in model.s.hand:
		if seen.has(id): continue
		seen.append(id)
		for i in range(model.s.hand.count(id)): pool.append(id)
	for i in range(model.s.supply): pool.append("basic")
	var plan: Array = []
	for id in pool:
		if Ammo.can_insert(plan, id, model.capacity()): plan.push_front(id)
	return plan

func choose(model, policy: String, random: RandomNumberGenerator) -> Array:
	match policy:
		"fixed": return fixed_plan(model)
		"heat_order": return heat_plan(model)
	return random_plan(model, random)

func metrics(model, start_history: int, start_turn: int, start_shots: int, start_reloads: int) -> Dictionary:
	var result := {"won": model.s.phase in ["reward", "won"], "turns": int(model.s.turns) - start_turn, "shots": int(model.s.shots) - start_shots, "reloads": int(model.s.reloads) - start_reloads,
		"volleys": 0, "loads": 0, "full_loads": 0, "all_tactical_fit": 0, "forced": 0, "overheated": 0, "terminal_heat_waived": 0, "forced_no_unfired": 0, "unfired_heat": 0,
		"peak_heat_ratio": 0.0, "direct_hp": 0, "burn_hp": 0, "arc_hp": 0, "shots_boosted": 0, "one_hit_floor": 0, "conditional": {}}
	var outstanding := 0
	for event in model.s.history.slice(start_history):
		var detail: Dictionary = event.detail
		if event.action == "load":
			result.loads += 1
			outstanding = detail.load_order.size()
			if Ammo.slots_used(detail.load_order) == model.capacity(): result.full_loads += 1
			if detail.hand_left.is_empty(): result.all_tactical_fit += 1
		if event.action in ["fire", "reload"]:
			for step in detail.get("advance_events", []):
				if step.kind == "burn": result.burn_hp += int(step.damage)
		if event.action != "fire": continue
		result.volleys += 1
		outstanding -= detail.results.size()
		result.peak_heat_ratio = maxf(result.peak_heat_ratio, float(detail.heat_peak) / Ammo.heat_limit(model.s))
		if detail.overheated:
			result.overheated += 1
			if detail.phase in ["reward", "won"] and detail.forced_reload.is_empty(): result.terminal_heat_waived += 1
		if not detail.forced_reload.is_empty():
			result.forced += 1
			result.unfired_heat += outstanding
			if outstanding == 0: result.forced_no_unfired += 1
			outstanding = 0
		for shot in detail.results:
			result.direct_hp += int(shot.damage)
			for secondary in shot.secondary: result.arc_hp += int(secondary.damage)
			if int(shot.math.boost) > 0: result.shots_boosted += 1
			if int(shot.math.raw) > 0 and int(shot.math.raw) <= int(shot.math.armor): result.one_hit_floor += int(shot.hits) - int(shot.blocked_hits)
			var effect := str(Ammo.AMMO[shot.id].effect)
			if effect not in ["cool", "shatter", "detonate", "chase", "thermal"]: continue
			if not result.conditional.has(effect): result.conditional[effect] = {"fired": 0, "active": 0}
			result.conditional[effect].fired += 1
			var key: String = {"cool": "cooled", "shatter": "armor_removed", "detonate": "detonation", "chase": "chase_bonus", "thermal": "thermal_bonus"}[effect]
			# cooled includes part cooling; subtract that to isolate the coolant round.
			var amount := int(shot.get(key, 0)) - (int(shot.kill_cooled) if effect == "cool" else 0)
			if amount > 0: result.conditional[effect].active += 1
	return result

func fight(model, policy: String, policy_seed: int) -> Dictionary:
	var start := [model.s.history.size(), int(model.s.turns), int(model.s.shots), int(model.s.reloads)]
	var random := RandomNumberGenerator.new()
	random.seed = policy_seed
	var minimum := contact_margin(model)
	var opening: Array = []
	for cycle in range(60):
		if model.s.phase == "ready": require(model.reload_magazine(), "reload legal")
		if model.s.phase != "plan": break
		minimum = minf(minimum, contact_margin(model))
		var plan := choose(model, policy, random)
		require(not plan.is_empty(), "a legal nonempty plan")
		if plan.is_empty(): break
		if opening.is_empty(): opening = plan.duplicate()
		execute(model, plan)
		minimum = minf(minimum, contact_margin(model))
	require(model.s.phase in ["reward", "won", "lost"], "fight terminates")
	var result := metrics(model, start[0], start[1], start[2], start[3])
	result.opening = opening
	result.min_decision_contact = minimum
	result.loss_reason = str(model.s.get("loss_reason", ""))
	return result

func play_campaign(gun: String, seed_value: int, policy: String, growth: String) -> void:
	var c = Campaign.new()
	c.start(gun, seed_value)
	var encounters: Array = []
	var moves := 0
	for iteration in range(350):
		moves += 1
		match str(c.s.phase):
			"map":
				var available: Array = c.choices()
				require(not available.is_empty(), "route exists")
				if available.is_empty(): break
				require(c.enter(int(available[0].id)), "enter legal next node")
			"combat":
				var opening := {"node": c.s.node, "region": c.s.region, "floor": c.s.floor, "deck": c.model.s.deck.duplicate(), "hand": c.model.s.hand.duplicate(), "parts": c.equipped_parts().duplicate(), "capacity": c.model.capacity(), "heat_limit": Ammo.heat_limit(c.model.s)}
				var result := fight(c.model, policy, seed_value + int(c.s.node) * 7)
				result.merge(opening)
				result.credit_offer = c.credit_reward() if result.won else 0
				encounters.append(result)
				c.sync_combat()
			"reward":
				var reward := "credits"
				if growth != "starter" and c.model.s.deck.size() < 12 and int(c.s.clears) % 3 == 0: reward = str(c.reward_options()[0])
				require(c.reward(reward), "reward legal")
			"gate":
				var eligible: Array = c.compressible_ids()
				if growth == "compress" and not eligible.is_empty(): require(c.gate("compress", str(eligible[0])), "gate compression legal")
				else: require(c.gate("slot" if growth == "expand" and int(c.s.slots) < 2 else "credits"), "gate legal")
			"shop":
				if growth != "starter":
					for i in range(c.s.offers.size()):
						var offer: Dictionary = c.s.offers[i]
						if offer.type == "part" and not c.s.parts.has(offer.id) and int(c.s.credits) >= int(offer.price) and Ammo.valid_part_set(str(c.s.gun), c.equipped_parts() + [offer.id]):
							require(c.buy(i), "shop purchase legal")
				require(c.leave(), "leave shop")
			"supply":
				require(c.resolve("skip"), "skip supply")
				require(c.leave(), "leave supply")
			"won", "lost": break
			_: require(false, "unexpected fixed-route phase " + str(c.s.phase)); break
	require(c.s.phase in ["won", "lost"], "campaign terminates")
	# Audit the actual resulting state once per campaign, with no player save I/O.
	var copy = Campaign.new()
	require(copy.restore_state({"campaign": c.s.duplicate(true), "combat": c.model.s.duplicate(true), "profile": c.profile.duplicate(true)}), "campaign final state valid")
	campaigns.append({"gun": gun, "seed": seed_value, "policy": policy, "growth": growth, "won": c.s.phase == "won", "visited": c.s.visited.size(), "credits": c.s.credits, "parts": c.equipped_parts(), "deck": c.model.s.deck, "slots": c.s.slots, "encounters": encounters, "phase_iterations": moves})

func full_plans(pool: Array, capacity_value: int, plan: Array = []) -> Array:
	var result: Array = []
	var used: Array = []
	for i in range(pool.size()):
		var id: String = pool[i]
		if used.has(id) or not Ammo.can_insert(plan, id, capacity_value): continue
		used.append(id)
		var rest := pool.duplicate()
		rest.remove_at(i)
		result.append_array(full_plans(rest, capacity_value, [id] + plan))
	if used.is_empty() and not plan.is_empty(): result.append(plan)
	return result

func opening_choices() -> void:
	# Deterministic guns only: do not rank alternatives with hidden scatter RNG.
	for gun in ["single", "burst", "heavy", "amplifier"]:
		for seed_value in SEEDS:
			for floor_value in [1, 2, 3]:
				var node: Dictionary = Data.nodes(0, seed_value).filter(func(n): return int(n.floor) == floor_value and n.kind == "combat")[0]
				var base = encounter(gun, node, seed_value)
				var pool: Array = base.s.hand.duplicate()
				for i in range(base.s.supply): pool.append("basic")
				var records: Array = []
				for plan in full_plans(pool, base.capacity()):
					var copy = clone(base)
					execute(copy, plan)
					var record := metrics(copy, base.s.history.size(), int(base.s.turns), int(base.s.shots), int(base.s.reloads))
					record.plan = plan
					record.kills = base.alive_count() - copy.alive_count()
					record.remaining_hp = 0
					for e in copy.s.enemies: record.remaining_hp += int(e.hp)
					record.phase = copy.s.phase
					var next = clone(copy)
					record.next_reload_safe = true
					if next.s.phase == "ready":
						require(next.reload_magazine(), "one extra real reload")
						record.next_reload_safe = next.s.phase != "lost"
					records.append(record)
				choices.append({"gun": gun, "seed": seed_value, "floor": floor_value, "hand": base.s.hand, "enemies": base.s.enemies, "records": records})
		print("DEPTH OPENINGS " + gun + " states=" + str(choices.size()))

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/decision_depth/"):
		quit(1)
		return
	opening_choices()
	for gun in Ammo.GUNS:
		for seed_value in SEEDS:
			for growth in ["starter", "expand", "compress"]:
				for policy in ["random", "fixed", "heat_order"]: play_campaign(gun, seed_value, policy, growth)
		print("DEPTH CAMPAIGNS " + gun + " runs=" + str(campaigns.size()))
	# Paired thermal/content comparisons, equal two-part budgets plus bare baseline.
	for gun in Ammo.GUNS:
		for seed_value in [17, 42, 109, 731042]:
			for location in [[0, 5], [1, 7], [3, 5], [4, 7]]:
				var node: Dictionary = Data.nodes(location[0], seed_value).filter(func(n): return int(n.floor) == int(location[1]) and n.kind in ["combat", "boss"])[0]
				for deck in DECKS:
					for package in PACKAGES:
						var c = Campaign.new()
						c.start(gun, seed_value)
						c.model.s.deck = DECKS[deck].duplicate()
						c.s.parts = PACKAGES[package].duplicate()
						c.s.equipped_parts = PACKAGES[package].duplicate()
						c.s.region = node.region
						c.s.floor = int(node.floor) - 1
						require(c.enter(int(node.id)), "paired node entry")
						for policy in ["random", "heat_order"]:
							var copy = clone(c.model)
							var result := fight(copy, policy, seed_value + int(node.id) * 7)
							result.merge({"gun": gun, "seed": seed_value, "node": node.id, "region": node.region, "floor": node.floor, "deck": deck, "package": package, "policy": policy})
							independent.append(result)
		print("DEPTH BUILDS " + gun + " rows=" + str(independent.size()))
	var report := {"version": Model.VERSION, "method": "Actual current LIFO model. Six seeds; 270 fixed-route legal campaigns with three non-oracular combat policies and three fixed economies. Fixed clicks actual hand left-to-right; random shuffles that hand; heat_order reads public hand and current heat only. Starter takes credits and skips all growth; expand adds at most two reward rounds, buys affordable equip-eligible parts in display order and expands twice; compress buys/rewards similarly and compresses first eligible family at gates. No exchange, field compression, reroll or replacement search. Opening enumeration covers all maximal legal load sequences of the real five-card starting hands plus renewable basic for deterministic guns; executes the whole magazine, including multiple amplifier triggers. 2400 paired independent build encounters use authored decks/two-part packages, not organically acquired inventories. Not human win rates, not optimal policies. Min contact measured only between magazine/reload decisions.", "campaigns": campaigns, "opening_choices": choices, "independent": independent, "failures": failures}
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("decision_depth.json"), FileAccess.WRITE).store_string(JSON.stringify(report))
	print("DECISION DEPTH COMPLETE campaigns=%d openings=%d independent=%d failures=%d" % [campaigns.size(), choices.size(), independent.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
