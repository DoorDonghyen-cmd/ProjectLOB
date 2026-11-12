extends SceneTree

const Trial = preload("res://redesign/samples/opening_build/early_parts_campaign.gd")
const Solver = preload("res://tests/fire_control_solver.gd")
const Commands = preload("res://tests/weapon_magazine_solver.gd")
const DECISIONS := {
	"single": {"keep_support": [2, 2], "eject_support": [[1], 2, 2]},
	"burst": {"short_first": [1, 2], "burst_first": [2, 1]},
	"heavy": {"fire_again": [3, 1], "cool_then_fire": [3, "cool", 1]},
}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/"):
		quit(2)
		return
	var pairs := []
	for seed in [17, 23]:
		for gun: String in Trial.FIRST_PARTS:
			var current := Trial.new()
			var with_part := Trial.new()
			with_part.offer_enabled = true
			var part: String = Trial.FIRST_PARTS[gun]
			if not current.prepare_checkpoint(gun, seed) or not with_part.prepare_checkpoint(gun, seed):
				return fail("Could not earn both starting rewards: %s/%d" % [gun, seed])
			if current.s != with_part.s or current.model.s != with_part.model.s or not current.part_rewards().is_empty() or with_part.part_rewards() != [part]:
				return fail("Starting states or offer differ: %s/%d" % [gun, seed])
			if not current.reward("skip") or not with_part.reward(part):
				return fail("Could not claim the normal reward: %s/%d" % [gun, seed])
			var node := current.next_normal_encounter()
			if not current.enter(node) or not with_part.enter(node):
				return fail("Could not enter the same fight: %s/%d" % [gun, seed])
			var before: Dictionary = current.model.s
			var after: Dictionary = with_part.model.s
			if before.deck != after.deck or before.enemies != after.enemies or before.rng_state != after.rng_state or before.target_rng_state != after.target_rng_state:
				return fail("Deck, encounter, or RNG changed across the pair: %s/%d" % [gun, seed])
			var plans: Dictionary = DECISIONS[gun].duplicate(true)
			for branch in [["search_current", before], ["search_part", after]]:
				var path := Solver.new().ranged(branch[1], 64, 26, true)
				if path.is_empty(): return fail("Search found no winning replay: %s/%d" % [gun, seed])
				plans[branch[0]] = path.map(step_action)
			var results := {}
			for label in plans:
				results[label] = {"actions": plans[label], "current": replay(before, plans[label], part), "part": replay(after, plans[label], part)}
				if str(label).begins_with("search"):
					var own: Dictionary = results[label].current if label == "search_current" else results[label].part
					if own.phase != "reward": return fail("Winning route did not replay: %s/%d" % [gun, seed])
			pairs.append({"gun":gun, "seed":seed, "part":part, "node":node, "deck":before.deck,
				"enemies":before.enemies.map(func(enemy): return [enemy.name, enemy.hp, enemy.distance]),
				"current_magazine":before.magazine, "part_magazine":after.magazine, "results":results})
	FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE).store_string(JSON.stringify(pairs, "  "))
	print("EARLY PARTS COMPARISON pairs=%d failures=0" % pairs.size())
	quit()

func step_action(step: Dictionary) -> Variant:
	match str(step.action):
		"fire": return int(step.rounds)
		"eject": return step.indices
		_: return str(step.action)

func replay(start: Dictionary, actions: Array, part: String) -> Dictionary:
	var model = Trial.Model.new()
	model.s = start.duplicate(true)
	var accepted := true
	for action in actions:
		if model.s.phase != "ready": break
		if action is int:
			model.s.fire_heat_trial.rounds = action
			accepted = model.fire()
		elif action is Array:
			accepted = model.eject_magazine_rounds(action)
		else:
			accepted = Commands.command(model, "swap" if action == "reload" else str(action))
		if not accepted: break
	var shots := []
	for event in model.s.history.slice(start.history.size()):
		if event.action != "fire": continue
		for shot in event.detail.results:
			shots.append({"round":shot.id, "damage":shot.get("damage", 0), "target":shot.get("target", -1),
				"effect":shot.get("part_effects", []).filter(func(effect): return effect.id == part)})
	return {"accepted":accepted, "phase":model.s.phase, "heat":model.s.heat,
		"turns":int(model.s.turns) - int(start.turns), "rounds":int(model.s.shots) - int(start.shots),
		"hp":model.s.enemies.map(func(enemy): return int(enemy.hp)), "shots":shots}

func fail(message: String) -> void:
	print("FAIL: ", message)
	quit(1)
