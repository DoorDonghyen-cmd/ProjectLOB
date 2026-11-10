extends RefCounted
const Model = preload("res://redesign/model.gd")

static func actions(model) -> Array:
	var result: Array = []
	if model.s.phase not in ["plan", "ready"]: return result
	if model.s.phase == "ready" and not model.s.magazine.is_empty(): result.append("fire")
	if model.s.phase == "ready" and int(model.s.heat) > 0: result.append("cool")
	if model.can_emergency_resupply(): result.append("emergency")
	elif not (model.s.hand + model.s.draw).is_empty(): result.append("swap")
	return result

static func command(model, action: String) -> bool:
	match action:
		"fire": return model.fire()
		"cool": return model.cool_magazine()
		"swap": return model.reload_magazine()
		"emergency": return model.emergency_resupply()
	return false

static func score(state: Dictionary) -> float:
	var value: float = -float(state.turns) * 0.2 - state.discard.size() * 0.1
	for enemy in state.enemies + state.reinforcements:
		if int(enemy.hp) > 0: value -= float(enemy.hp) * 10 + 30
	for p in state.projectiles:
		if int(p.hp) > 0: value -= 15
	return value

static func solve(state: Dictionary, width := 48, depth_limit := 26) -> Array:
	var beam: Array = [{"state": state, "path": []}]
	for depth in range(depth_limit):
		var next: Array = []; var seen: Dictionary = {}
		for branch in beam:
			var base = Model.new(); base.s = branch.state
			for action in actions(base):
				var model = Model.new(); model.s = Model.simulation_state(base.s)
				if not command(model, action): continue
				var path: Array = branch.path + [action]
				if model.s.phase in ["won", "reward"]: return path
				if model.s.phase == "lost": continue
				var key := JSON.stringify([model.s.enemies, model.s.reinforcements, model.s.projectiles, model.s.magazine, model.s.draw, model.s.hand, model.s.discard, model.s.heat, model.s.buff, model.s.push_left, model.s.get("sustained_attacks", 0), model.s.previous_kill, model.s.get("engine", {}), model._recent_part_rounds(), model.s.get("emergency_uses", 0)])
				if seen.has(key): continue
				seen[key] = true
				next.append({"state": model.s, "path": path, "score": score(model.s)})
		next.sort_custom(func(a,b): return a.score > b.score)
		if next.size() > width: next.resize(width)
		beam = next
		if beam.is_empty(): break
	return []
