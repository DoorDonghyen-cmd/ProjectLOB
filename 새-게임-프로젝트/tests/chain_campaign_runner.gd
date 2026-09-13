extends SceneTree
## Independent bounded search plus fresh, real-command replay. No forced wins.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
var reports: Array = []
var candidates: Array = []
var output_dir := ""
var policy := "supply"
var exchange_mode := "optional"
var beam_width := 5
var search_depth := 6
var seed_values: Array = [731042]
var scenario_started := 0
var explored := 0
var failed_commands := 0
var basic_only := false

func _initialize() -> void:
	_run.call_deferred()

func clone(m):
	var copy = Model.new()
	copy.s = m.s.duplicate(true)
	copy.s.history = []
	return copy

func enumerate(m, stack: Array = []) -> void:
	if not stack.is_empty(): candidates.append(stack.duplicate())
	if stack.size() == m.capacity(): return
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
		value += (int(e.max_hp) - int(e.hp)) * 10.0
		if int(e.hp) == 0: value += 75.0
		else:
			value += float(e.distance) * 0.7 + int(e.crack) * 2.0
	value -= float(m.s.turns) * 0.6
	return value

func exchange_candidate(m) -> String:
	# Fixed, declared heuristic: cycle a support round before a damage combo piece.
	for id in ["mark", "push", "slow", "arc", "finish", "basic", "pierce", "bore", "charge", "precise"]:
		if id != "basic" and m.available(id) > 0: return id
	return ""

func solve(m) -> Array:
	if basic_only: return solve_basic(m)
	var beam: Array = [{"m": clone(m), "path": []}]
	for depth in range(search_depth):
		var next: Array = []
		var seen := {}
		for node in beam:
			if Time.get_ticks_msec() - scenario_started > 150000: return []
			var base = clone(node.m)
			if base.s.phase == "ready": base.reload_magazine()
			if base.s.phase == "lost": continue
			var variants: Array = [{"m": base, "exchange": ""}]
			if exchange_mode != "off":
				var exchanged = clone(base)
				var id := exchange_candidate(exchanged)
				if not id.is_empty() and exchanged.exchange(id):
					if exchange_mode == "force": variants.clear()
					variants.append({"m": exchanged, "exchange": id})
			for variant in variants:
				candidates = []
				enumerate(variant.m)
				for stack in candidates:
					explored += 1
					var sim = clone(variant.m)
					for id in stack: sim.load_round(id)
					sim.confirm()
					var fires := 0
					while sim.s.phase == "ready" and not sim.s.magazine.is_empty():
						sim.fire()
						fires += 1
						var path: Array = node.path.duplicate(true)
						path.append({"reload": depth > 0, "exchange": variant.exchange, "load": stack.duplicate(), "fires": fires})
						if sim.s.phase in ["reward", "won"]: return path
						if sim.s.phase == "lost": break
						var key := JSON.stringify([sim.s.enemies, sim.s.hand, sim.s.draw, sim.s.discard, sim.s.magazine, sim.s.supply, sim.s.rng_state])
						if seen.has(key): continue
						seen[key] = true
						next.append({"m": clone(sim), "path": path, "score": score(sim)})
						if next.size() > beam_width * 8:
							next.sort_custom(func(a, b): return a.score > b.score)
							next.resize(beam_width)
			next.sort_custom(func(a, b): return a.score > b.score)
			if next.size() > beam_width: next.resize(beam_width)
		beam = next
		if beam.is_empty(): break
		await process_frame
	return []

func solve_basic(m) -> Array:
	# Declared simple policy: fill with basic supply, empty magazine, reload.
	var sim = clone(m)
	var path: Array = []
	for depth in range(30):
		if sim.s.phase == "ready":
			sim.reload_magazine()
			if sim.s.phase == "lost":
				path.append({"reload": true, "exchange": "", "load": [], "fires": 0, "lethal_reload": true})
				return path
		var stack: Array = []
		while sim.available("basic") > 0 and sim.s.plan.size() < sim.capacity():
			sim.load_round("basic")
			stack.append("basic")
		sim.confirm()
		var fires := 0
		while sim.s.phase == "ready" and not sim.s.magazine.is_empty():
			sim.fire()
			fires += 1
		path.append({"reload": depth > 0, "exchange": "", "load": stack, "fires": fires})
		if sim.s.phase in ["reward", "won", "lost"]: return path
	return []

func apply_command(m, command: Dictionary, commands: Array) -> bool:
	var accepted := false
	match command.action:
		"load": accepted = m.load_round(str(command.id))
		"confirm": accepted = m.confirm()
		"fire": accepted = m.fire()
		"reload": accepted = m.reload_magazine()
		"exchange": accepted = m.exchange(str(command.id))
		"reward": accepted = m.choose_reward(str(command.id), str(command.get("remove_id", "")))
	command["accepted"] = accepted
	command["phase_after"] = m.s.phase
	command["floor_after"] = m.s.floor
	command["turn_after"] = m.s.turns
	commands.append(command)
	if not accepted:
		failed_commands += 1
		printerr("COMMAND REJECTED " + JSON.stringify(command))
	return accepted

func choose_reward(m) -> Dictionary:
	var options: Array = m.reward_options()
	if policy == "skip": return {"action": "reward", "id": "skip", "remove_id": "", "options": options.duplicate()}
	var preferred: Array = [policy, "coil", "supply", "lens", "loader", "charge", "precise", "bore", "pierce", "arc", "finish", "slow", "push", "mark"]
	for id in preferred:
		if options.has(id):
			if Content.AMMO.has(id) and m.s.deck.size() >= 14: continue
			return {"action": "reward", "id": id, "remove_id": "", "options": options.duplicate()}
	return {"action": "reward", "id": "skip", "remove_id": "", "options": options.duplicate()}

func run_scenario(gun: String, run_seed: int) -> void:
	scenario_started = Time.get_ticks_msec()
	explored = 0
	var m = Model.new()
	m.start(gun, run_seed)
	var paths: Array = []
	var commands: Array = []
	var encountered: Array = []
	while m.s.phase != "won":
		encountered.append({"floor": m.s.floor, "enemies": m.s.enemies.duplicate(true), "part": m.s.part, "capacity": m.capacity()})
		var path: Array = await solve(m)
		if path.is_empty(): break
		var command_ok := true
		for step in path:
			if step.reload: command_ok = apply_command(m, {"action": "reload"}, commands) and command_ok
			if bool(step.get("lethal_reload", false)): break
			if not str(step.exchange).is_empty(): command_ok = apply_command(m, {"action": "exchange", "id": step.exchange}, commands) and command_ok
			for id in step.load: command_ok = apply_command(m, {"action": "load", "id": id}, commands) and command_ok
			command_ok = apply_command(m, {"action": "confirm"}, commands) and command_ok
			for i in range(int(step.fires)): command_ok = apply_command(m, {"action": "fire"}, commands) and command_ok
		paths.append(path)
		if not command_ok: break
		if m.s.phase == "reward":
			if not apply_command(m, choose_reward(m), commands): break
		elif m.s.phase != "won": break
	var shots_by_ammo := {}
	var combos := {}
	var exchanges := 0
	var rewards: Array = []
	for entry in m.s.history:
		if entry.action == "fire":
			for shot in entry.detail.results:
				shots_by_ammo[shot.id] = int(shots_by_ammo.get(shot.id, 0)) + 1
				for combo in shot.combo: combos[combo] = int(combos.get(combo, 0)) + 1
		elif entry.action == "exchange": exchanges += 1
		elif entry.action == "reward": rewards.append(entry.detail.duplicate(true))
	var report := {"gun": gun, "seed": str(run_seed), "policy": policy, "exchange_mode": exchange_mode,
		"won": m.s.phase == "won", "status": "completed" if m.s.phase == "won" else ("defeated_by_simple_policy" if basic_only and m.s.phase == "lost" else "path_not_found_within_bounds"),
		"basic_only": basic_only, "final_enemies": m.s.enemies.duplicate(true),
		"floor": m.s.floor, "turns": m.s.turns, "shots": m.s.shots, "reloads": m.s.reloads,
		"paths": paths, "commands": commands, "history": m.s.history, "encountered": encountered,
		"shots_by_ammo": shots_by_ammo, "combos": combos, "exchange_count": exchanges, "rewards": rewards,
		"final_part": m.s.part, "deck": m.s.deck, "explored_stacks": explored,
		"elapsed_ms": Time.get_ticks_msec() - scenario_started}
	reports.append(report)
	write_report()
	print("CHAIN CAMPAIGN gun=%s seed=%d policy=%s exchange=%s won=%s floor=%d turns=%d shots=%d candidates=%d ms=%d" % [gun, run_seed, policy, exchange_mode, report.won, report.floor, report.turns, report.shots, explored, report.elapsed_ms])
	await process_frame

func write_report() -> void:
	var file := FileAccess.open(output_dir.path_join("campaign_report.json"), FileAccess.WRITE)
	if file == null:
		printerr("REPORT WRITE FAILURE")
		quit(2)
		return
	file.store_string(JSON.stringify({"method": "bounded beam search then actual command replay; no forced wins; search failure does not prove impossibility; not human win rate",
		"beam_width": beam_width, "search_depth": search_depth, "scenario_limit_ms": 150000,
		"command_rejections": failed_commands, "reports": reports}, "\t"))

func _run() -> void:
	output_dir = OS.get_environment("QA_OUTPUT_DIR")
	if output_dir.is_empty(): output_dir = "user://chain_campaign"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if not OS.get_environment("QA_POLICY").is_empty(): policy = OS.get_environment("QA_POLICY")
	if not OS.get_environment("QA_EXCHANGE").is_empty(): exchange_mode = OS.get_environment("QA_EXCHANGE")
	basic_only = OS.get_environment("QA_BASIC_ONLY") == "1"
	if not OS.get_environment("QA_SEEDS").is_empty():
		seed_values = []
		for value in OS.get_environment("QA_SEEDS").split(","): seed_values.append(int(value))
	for run_seed in seed_values:
		for gun in ["single", "burst"]:
			await run_scenario(gun, int(run_seed))
	print("CHAIN CAMPAIGN COMPLETE reports=%d rejected=%d output=%s" % [reports.size(), failed_commands, output_dir])
	quit(1 if failed_commands > 0 else 0)
