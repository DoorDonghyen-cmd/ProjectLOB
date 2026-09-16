extends RefCounted
## QA-only bounded search. Reads model state and executes real commands on copies.
## Future draw/RNG state is available here: this is functional reachability QA,
## not a player-only black-box experience test.
const Model = preload("res://redesign/model.gd")
var candidates: Array = []
var explored := 0

func clone(model):
	var result = Model.new()
	result.s = model.s.duplicate()
	result.s.history = []
	result.s = result.s.duplicate(true)
	return result

func enumerate(model, stack: Array = []) -> void:
	if not stack.is_empty(): candidates.append(stack.duplicate())
	if stack.size() >= model.capacity(): return
	var ids: Array = []
	# Try combo pieces early; all permutations and partial magazines remain legal.
	for id in ["charge", "precise", "pierce", "bore", "arc", "push", "basic"]:
		if model.available(id) > 0: ids.append(id)
	for id in ids:
		if stack.count(id) >= model.available(id): continue
		stack.append(id)
		enumerate(model, stack)
		stack.pop_back()

func score(model) -> float:
	var total := 0.0
	for enemy in model.s.enemies:
		total += (int(enemy.max_hp) - int(enemy.hp)) * 10.0
		if int(enemy.hp) == 0: total += 75
		else: total += float(enemy.distance) / maxi(1, int(enemy.speed)) * 1.5 + int(enemy.burn) * 2.0
	total -= int(model.s.turns) * 0.4
	return total

func solve(model, width: int = 3, max_depth: int = 7) -> Array:
	var beam: Array = [{"model": clone(model), "path": []}]
	for depth in range(max_depth):
		var next: Array = []
		var seen := {}
		for branch in beam:
			var base = clone(branch.model)
			var prefix: Array = branch.path.duplicate(true)
			if base.s.phase == "ready":
				base.reload_magazine()
				prefix.append({"action": "reload"})
			if base.s.phase in ["reward", "won"]: return prefix
			if base.s.phase == "lost": continue
			candidates = []
			enumerate(base)
			for stack in candidates:
				explored += 1
				var simulation = clone(base)
				var path: Array = prefix.duplicate(true)
				for id in stack:
					simulation.load_round(id)
					path.append({"action": "load", "id": id})
				simulation.confirm()
				path.append({"action": "confirm"})
				while simulation.s.phase == "ready" and not simulation.s.magazine.is_empty():
					simulation.fire()
					path.append({"action": "fire"})
					if simulation.s.phase in ["reward", "won"]: return path
					if simulation.s.phase == "lost": break
					var key := JSON.stringify([simulation.s.enemies, simulation.s.hand, simulation.s.draw, simulation.s.magazine, simulation.s.rng_state, simulation.s.target_rng_state, simulation.s.buff, simulation.s.push_left])
					if seen.has(key): continue
					seen[key] = true
					next.append({"model": clone(simulation), "path": path.duplicate(true), "score": score(simulation)})
					if next.size() > width * 8:
						next.sort_custom(func(a, b): return a.score > b.score)
						next.resize(width)
		next.sort_custom(func(a, b): return a.score > b.score)
		if next.size() > width: next.resize(width)
		beam = next
		if beam.is_empty(): break
	return []
