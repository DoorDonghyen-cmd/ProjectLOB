extends SceneTree
## Bounded search uses the real commands and resolver. Replays the selected path
## from a fresh seed without enemy edits, forced wins, or debug entry points.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
var reports: Array = []
var candidates: Array = []

func _initialize() -> void:
	_run.call_deferred()

func clone(m):
	var copy = Model.new()
	copy.s = m.s.duplicate(true)
	copy.s.history = []
	return copy

func enumerate(m, stack: Array = []) -> void:
	if not stack.is_empty():
		candidates.append(stack.duplicate())
	if stack.size() == m.capacity():
		return
	var ids: Array = ["basic"]
	for id in m.s.hand:
		if not ids.has(id): ids.append(id)
	for id in ids:
		var count: int = int(m.s.supply) if id == "basic" else m.s.hand.count(id)
		if stack.count(id) >= count: continue
		stack.append(id)
		enumerate(m, stack)
		stack.pop_back()

func score(m) -> float:
	var value := 0.0
	for e in m.s.enemies:
		value += (int(e.max_hp) - int(e.hp)) * 8.0
		if int(e.hp) == 0: value += 50.0
		else: value += float(e.distance) * 0.6
	value -= float(m.s.turns) * 0.5
	return value

func solve(m) -> Array:
	var beam: Array = [{"m": clone(m), "path": []}]
	for depth in range(7):
		var next: Array = []
		var seen := {}
		for node in beam:
			var base = clone(node.m)
			if base.s.phase == "ready":
				base.reload_magazine()
			if base.s.phase == "lost": continue
			candidates = []
			enumerate(base)
			for stack in candidates:
				var sim = clone(base)
				for id in stack: sim.load_round(id)
				sim.confirm()
				var fires := 0
				while sim.s.phase == "ready" and not sim.s.magazine.is_empty():
					sim.fire()
					fires += 1
					var path: Array = node.path.duplicate(true)
					path.append({"reload": depth > 0, "load": stack.duplicate(), "fires": fires})
					if sim.s.phase in ["reward", "won"]: return path
					if sim.s.phase == "lost": break
					var key := JSON.stringify([sim.s.enemies, sim.s.hand, sim.s.magazine, sim.s.discard])
					if seen.has(key): continue
					seen[key] = true
					next.append({"m": clone(sim), "path": path, "score": score(sim)})
			next.sort_custom(func(a, b): return a.score > b.score)
			if next.size() > 12: next.resize(12)
		beam = next
		if beam.is_empty(): break
	return []

func _run() -> void:
	var failures := 0
	for gun in ["single", "burst"]:
		for run_seed in [731042, 42, 901]:
			var m = Model.new()
			m.start(gun, run_seed)
			var paths: Array = []
			while m.s.phase != "won":
				var path := solve(m)
				if path.is_empty(): break
				for step in path:
					if step.reload: m.reload_magazine()
					for id in step.load: assert(m.load_round(id))
					assert(m.confirm())
					for i in range(step.fires): assert(m.fire())
				paths.append(path)
				if m.s.phase == "reward":
					var options: Array = m.reward_options()
					var reward: String = options[0]
					if options.has("lens"): reward = "lens"
					assert(m.choose_reward(reward))
				elif m.s.phase != "won": break
			var won: bool = m.s.phase == "won"
			if not won: failures += 1
			var report := {"gun": gun, "seed": run_seed, "won": won, "floor": m.s.floor, "turns": m.s.turns, "shots": m.s.shots, "paths": paths, "history": m.s.history}
			reports.append(report)
			print("CAMPAIGN %s seed=%d won=%s floor=%d turns=%d" % [gun, run_seed, won, m.s.floor, m.s.turns])
			await process_frame
	var file := FileAccess.open("user://redesign_campaign_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": "bounded search, real command replay, no forced wins; not human win rate", "reports": reports, "failures": failures}, "\t"))
	file.close()
	quit(1 if failures else 0)
