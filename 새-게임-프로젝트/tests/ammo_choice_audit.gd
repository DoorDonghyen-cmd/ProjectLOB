extends SceneTree
## Decision-value audit: production formations and real commands, no gameplay edits.
## Isolated encounters keep starting decks fixed to avoid mixing combat and growth.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const SEEDS := [17, 42, 109, 731042, 913, 2048]
var rows: Array = []
var failures: Array = []
var comparisons: Array = []

func _initialize() -> void:
	run.call_deferred()

func clone(model):
	var result = Model.new()
	result.s = model.s.duplicate(true)
	return result

func require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func shuffled(values: Array, random: RandomNumberGenerator) -> Array:
	var result := values.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var value = result[i]
		result[i] = result[j]
		result[j] = value
	return result

func random_plan(model, random: RandomNumberGenerator) -> Array:
	var candidates := shuffled(model.s.hand, random)
	for i in range(model.s.supply): candidates.append("basic")
	var plan: Array = []
	for id in candidates:
		if Ammo.can_insert(plan, id, model.capacity()):
			plan.insert(Ammo.insertion_index(plan, id), id)
	return plan

func execute(model, plan: Array) -> void:
	for id in Ammo.loading_order(plan): require(model.load_round(id), "legal load " + str(id))
	require(model.confirm(), "legal confirm")
	while model.s.phase == "ready" and not model.s.magazine.is_empty():
		require(model.fire(), "legal fire")

func score(model) -> float:
	if model.s.phase == "lost": return -1000000.0
	if model.s.phase in ["reward", "won"]: return 1000000.0 - float(model.s.turns)
	var value := 0.0
	for enemy in model.s.enemies:
		value += (int(enemy.max_hp) - int(enemy.hp)) * 10
		value += (int(enemy.get("barrier_max", 0)) - int(enemy.get("barrier", 0))) * 12
		if int(enemy.hp) <= 0: value += 60
		else: value += int(enemy.burn) * 2 + float(enemy.distance) / maxi(1, int(enemy.speed))
	return value - float(model.s.turns) * 2

func guided_plan(model, random: RandomNumberGenerator) -> Array:
	# Only deterministic guns. One-magazine public consequences, no future draw search.
	var best: Array = []
	var best_score := -INF
	for i in range(32):
		var plan := random_plan(model, random)
		var copy = clone(model)
		execute(copy, plan)
		var value := score(copy)
		if value > best_score:
			best_score = value
			best = plan
	return best

func contact_margin(model) -> float:
	var result := 999.0
	for enemy in model.s.enemies:
		if int(enemy.hp) > 0 and int(enemy.speed) > 0:
			result = minf(result, float(enemy.distance) / int(enemy.speed))
	for projectile in model.s.get("projectiles", []):
		if int(projectile.hp) > 0:
			result = minf(result, float(projectile.distance) / int(projectile.speed))
	return result

func encounter(gun: String, node: Dictionary, seed_value: int):
	var campaign = Campaign.new()
	campaign.start(gun, seed_value)
	# Fixture only: enter each real node independently with no purchased upgrades.
	campaign.s.region = node.region
	campaign.s.floor = int(node.floor) - 1
	require(campaign.enter(int(node.id)), "real campaign entry")
	return campaign.model

func simulate(base, policy: String, policy_seed: int) -> Dictionary:
	var model = clone(base)
	var random := RandomNumberGenerator.new()
	random.seed = policy_seed
	var margin := contact_margin(model)
	var first_plan: Array = []
	for cycle in range(40):
		if model.s.phase not in ["plan", "ready"]: break
		margin = minf(margin, contact_margin(model))
		if model.s.phase == "ready":
			require(model.reload_magazine(), "legal reload")
			margin = minf(margin, contact_margin(model))
		if model.s.phase != "plan": break
		var plan: Array = []
		if policy == "basic":
			for i in range(model.capacity()): plan.append("basic")
		elif policy == "guided": plan = guided_plan(model, random)
		else: plan = random_plan(model, random)
		if first_plan.is_empty(): first_plan = plan.duplicate()
		execute(model, plan)
		margin = minf(margin, contact_margin(model))
	require(model.s.phase in ["reward", "won", "lost"], "encounter terminates")
	return {"policy": policy, "won": model.s.phase in ["reward", "won"], "turns": model.s.turns, "reloads": model.s.reloads, "shots": model.s.shots, "min_contact_turns": margin, "opening": first_plan}

func permutations(values: Array, prefix: Array = []) -> Array:
	if values.is_empty(): return [prefix]
	var result: Array = []
	var used: Array = []
	for i in range(values.size()):
		if used.has(values[i]): continue
		used.append(values[i])
		var rest := values.duplicate()
		rest.remove_at(i)
		result.append_array(permutations(rest, prefix + [values[i]]))
	return result

func opening_order_comparison() -> void:
	for f in [1, 2, 3]:
		var nodes: Array = Data.nodes(0, 17).filter(func(n): return int(n.floor) == f and n.kind == "combat")
		var base = encounter("single", nodes[0], 17)
		# These four cards are all owned in the unmodified starting deck.
		base.s.hand = ["charge", "precise", "pierce", "push"]
		base.s.draw = base.s.deck.duplicate()
		for id in base.s.hand: base.s.draw.erase(id)
		var results: Array = []
		for plan in permutations(base.s.hand):
			var model = clone(base)
			execute(model, plan)
			var killed := 0
			var damage := 0
			for e in model.s.enemies:
				if int(e.hp) == 0: killed += 1
				damage += int(e.max_hp) - int(e.hp)
			results.append({"plan": plan, "kills": killed, "damage": damage, "won": model.s.phase in ["reward", "won"]})
		comparisons.append({"floor": f, "fixed_owned_hand": base.s.hand, "results": results})

func run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_choice/"):
		quit(1)
		return
	opening_order_comparison()
	for gun in Ammo.GUNS:
		for seed_value in SEEDS:
			for region in range(5):
				for node in Data.nodes(region, seed_value):
					if node.kind not in ["combat", "boss"]: continue
					var base = encounter(gun, node, seed_value)
					var policies := ["random", "basic"]
					if gun in ["single", "heavy"]: policies.append("guided")
					for policy in policies:
						var result := simulate(base, policy, seed_value + int(node.id) * 7)
						result.merge({"gun": gun, "seed": seed_value, "region": region, "floor": node.floor, "node": node.id, "kind": node.kind, "route": node.route, "enemies": base.s.enemies, "reserve": base.s.reinforcements, "hand": base.s.hand})
						rows.append(result)
			print("AUDIT " + gun + " seed=" + str(seed_value) + " rows=" + str(rows.size()))
	var file := FileAccess.open(output.path_join("ammo_choice_audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": "Independent production encounters; six seeds; each gun's starting deck; no parts, growth, exchange or compression; legal load/confirm/fire/reload. Random shuffles actual tactical hand, fills with basic only if needed. Basic uses only renewable basic. Guided selects among 32 random full magazines by immediate actual deterministic consequences, no future draw or random target search. Not full-run or human win rates. Contact margin ignores future support pulls and projectile spawns.", "rows": rows, "opening_orders": comparisons, "failures": failures}, "\t"))
	print("CHOICE AUDIT COMPLETE rows=%d failures=%d" % [rows.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
