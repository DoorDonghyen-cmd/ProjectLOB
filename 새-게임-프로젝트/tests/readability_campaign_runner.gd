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
var gun_values: Array = ["single", "burst"]
var scenario_started := 0
var explored := 0
var failed_commands := 0
var basic_only := false
var require_situational := true
var course_enabled := false
var course_values: Array = [true, false]
var integrity_checks := 0
var integrity_failures: Array = []
var removal_probes: Array = []
const EXPECTED_GRANTS := [["charge", "charge"], ["pierce"], ["bore"], ["precise"], ["push"], ["arc"], []]

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
			value += float(e.distance) * 0.7 + int(e.burn) * 2.0
	value -= float(m.s.turns) * 0.6
	return value

func exchange_candidate(m) -> String:
	# Fixed, declared heuristic: cycle a support round before a damage combo piece.
	for id in ["push", "arc", "basic", "pierce", "bore", "charge", "precise"]:
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
	var previous_deck: Array = m.s.deck.duplicate()
	var previous_floor: int = m.s.floor
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
	if accepted:
		validate_inventory(m)
		if command.action == "reward":
			if command.id == "remove": previous_deck.erase(command.remove_id)
			elif Content.AMMO.has(command.id): previous_deck.append(command.id)
			if course_enabled: previous_deck.append_array(EXPECTED_GRANTS[previous_floor + 1])
			verify(sorted_copy(previous_deck) == sorted_copy(m.s.deck), "reward plus exact automatic grant", m)
	if not accepted:
		failed_commands += 1
		printerr("COMMAND REJECTED " + JSON.stringify(command))
	return accepted

func choose_reward(m) -> Dictionary:
	var options: Array = m.reward_options()
	if policy == "skip": return {"action": "reward", "id": "skip", "remove_id": "", "options": options.duplicate()}
	if policy == "remove":
		return {"action": "reward", "id": "remove" if m.s.deck.size() > m.minimum_deck() else "skip", "remove_id": str(m.s.deck[0]), "options": options.duplicate()}
	# A declared part preference keeps that build once acquired instead of
	# replacing it with a fallback at the next part-only reward.
	if Content.PARTS.has(policy) and str(m.s.part) == policy:
		for option in options:
			if Content.PARTS.has(option):
				return {"action": "reward", "id": "skip", "remove_id": "", "options": options.duplicate()}
	var preferred: Array = [policy, "coil", "supply", "lens", "loader", "charge", "precise", "bore", "pierce", "arc", "push"]
	for id in preferred:
		if options.has(id):
			if Content.AMMO.has(id) and m.s.deck.size() >= m.deck_limit(): continue
			return {"action": "reward", "id": id, "remove_id": "", "options": options.duplicate()}
	return {"action": "reward", "id": "skip", "remove_id": "", "options": options.duplicate()}

func run_scenario(gun: String, run_seed: int) -> void:
	scenario_started = Time.get_ticks_msec()
	explored = 0
	var m = Model.new()
	m.start(gun, run_seed, course_enabled)
	var failure_start := integrity_failures.size()
	validate_inventory(m)
	verify(m.s.deck == (EXPECTED_GRANTS[0] if course_enabled else Content.START_DECK), "starting deck", m)
	var paths: Array = []
	var commands: Array = []
	var encountered: Array = []
	while m.s.phase != "won":
		validate_entry(m)
		encountered.append({"floor": m.s.floor, "enemies": m.s.enemies.duplicate(true), "part": m.s.part, "capacity": m.capacity(), "deck": m.s.deck.duplicate(), "hand": m.s.hand.duplicate(), "deck_limit": m.deck_limit()})
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
			validate_reward(m)
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
	var report := {"gun": gun, "seed": str(run_seed), "course": course_enabled, "policy": policy, "exchange_mode": exchange_mode,
		"integrity_failures": integrity_failures.slice(failure_start),
		"won": m.s.phase == "won", "status": "completed" if m.s.phase == "won" else ("defeated_by_simple_policy" if basic_only and m.s.phase == "lost" else "path_not_found_within_bounds"),
		"basic_only": basic_only, "final_enemies": m.s.enemies.duplicate(true),
		"floor": m.s.floor, "turns": m.s.turns, "shots": m.s.shots, "reloads": m.s.reloads,
		"paths": paths, "commands": commands, "history": m.s.history, "encountered": encountered,
		"shots_by_ammo": shots_by_ammo, "combos": combos, "exchange_count": exchanges, "rewards": rewards,
		"final_part": m.s.part, "deck": m.s.deck, "explored_stacks": explored,
		"elapsed_ms": Time.get_ticks_msec() - scenario_started}
	reports.append(report)
	write_report()
	print("READABILITY CAMPAIGN gun=%s seed=%d course=%s policy=%s won=%s turns=%d shots=%d" % [gun, run_seed, course_enabled, policy, report.won, report.turns, report.shots])
	await process_frame

func write_report() -> void:
	var file := FileAccess.open(output_dir.path_join("campaign_report.json"), FileAccess.WRITE)
	if file == null:
		printerr("REPORT WRITE FAILURE")
		quit(2)
		return
	file.store_string(JSON.stringify({"method": "bounded beam search then actual command replay; no forced wins; search failure does not prove impossibility; not human win rate",
		"beam_width": beam_width, "search_depth": search_depth, "scenario_limit_ms": 150000,
		"command_rejections": failed_commands, "integrity_checks": integrity_checks, "integrity_failures": integrity_failures, "removal_probes": removal_probes, "reports": reports}, "\t"))

func _run() -> void:
	output_dir = OS.get_environment("QA_OUTPUT_DIR")
	if output_dir.is_empty(): output_dir = "user://chain_campaign"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if not OS.get_environment("QA_POLICY").is_empty(): policy = OS.get_environment("QA_POLICY")
	if not OS.get_environment("QA_EXCHANGE").is_empty(): exchange_mode = OS.get_environment("QA_EXCHANGE")
	if OS.get_environment("QA_BEAM_WIDTH").is_valid_int(): beam_width = maxi(1, int(OS.get_environment("QA_BEAM_WIDTH")))
	if OS.get_environment("QA_SEARCH_DEPTH").is_valid_int(): search_depth = maxi(1, int(OS.get_environment("QA_SEARCH_DEPTH")))
	if OS.get_environment("QA_COURSE") in ["true", "false"]: course_values = [OS.get_environment("QA_COURSE") == "true"]
	if OS.get_environment("QA_GUN") in ["single", "burst"]: gun_values = [OS.get_environment("QA_GUN")]
	basic_only = OS.get_environment("QA_BASIC_ONLY") == "1"
	if OS.get_environment("QA_REQUIRE_SITUATIONAL") == "0": require_situational = false
	if not OS.get_environment("QA_SEEDS").is_empty():
		seed_values = []
		for value in OS.get_environment("QA_SEEDS").split(","): seed_values.append(int(value))
	for run_seed in seed_values:
		for mode in course_values:
			course_enabled = mode
			for gun in gun_values:
				await run_scenario(gun, int(run_seed))
	var combined_usage := {}
	for report in reports:
		for id in report.shots_by_ammo:
			combined_usage[id] = int(combined_usage.get(id, 0)) + int(report.shots_by_ammo[id])
	if not basic_only and require_situational:
		for required_id in ["push", "arc"]:
			integrity_checks += 1
			if int(combined_usage.get(required_id, 0)) <= 0:
				integrity_failures.append({"label": "campaign uses situational round " + required_id, "usage": combined_usage.duplicate(true)})
				printerr("INTEGRITY FAIL campaign never uses " + required_id)
	write_report()
	print("READABILITY CAMPAIGN COMPLETE reports=%d rejected=%d checks=%d failed=%d output=%s" % [reports.size(), failed_commands, integrity_checks, integrity_failures.size(), output_dir])
	quit(1 if failed_commands > 0 or not integrity_failures.is_empty() else 0)

func sorted_copy(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort()
	return copy

func verify(ok: bool, label: String, m) -> void:
	integrity_checks += 1
	if not ok:
		integrity_failures.append({"label": label, "gun": m.s.gun, "seed": m.s.seed, "course": course_enabled, "floor": m.s.floor})
		printerr("INTEGRITY FAIL " + label)

func validate_inventory(m) -> void:
	var owned: Array = m.s.hand + m.s.draw + m.s.discard
	for id in m.s.magazine:
		if id != "basic": owned.append(id)
	verify(sorted_copy(owned) == sorted_copy(m.s.deck), "inventory conservation", m)
	verify(m.s.deck.size() >= m.minimum_deck() and m.s.deck.size() <= m.deck_limit(), "deck bounds reserve future grants", m)
	verify(m.s.hand.size() <= 5 and m.s.plan.size() <= m.capacity() and m.s.magazine.size() <= m.capacity(), "hand and magazine capacity", m)
	if course_enabled:
		var allowed: Array = []
		for stage in range(int(m.s.floor) + 1): allowed.append_array(EXPECTED_GRANTS[stage])
		for id in m.s.deck: verify(allowed.has(id), "no untaught ammo in course inventory", m)

func validate_entry(m) -> void:
	validate_inventory(m)
	if course_enabled:
		for id in EXPECTED_GRANTS[int(m.s.floor)]:
			verify(m.s.hand.count(id) >= EXPECTED_GRANTS[int(m.s.floor)].count(id), "new lesson ammo in first hand", m)
		for enemy in m.s.enemies:
			verify(not enemy.has("eva") and not enemy.has("slow") and not enemy.has("crack"), "removed defense and status axes absent", m)
			if int(m.s.floor) == 0: verify(int(enemy.def) == 0, "stage 0 no armor", m)
		if int(m.s.floor) in [4, 5]: verify(m.s.enemies.size() > 1, "late lesson multiple targets", m)
	# Disk round-trip in a QA-owned path; preserve the actual campaign instance.
	var save_path := output_dir.path_join("roundtrip_%s_%s_%s_%d.json" % [m.s.seed, m.s.gun, str(course_enabled), m.s.floor])
	verify(m.save_run(save_path) == OK, "save current course state", m)
	var loaded = Model.new()
	var restored: bool = loaded.restore_run(save_path)
	verify(restored, "restore current course state", m)
	if restored: verify(JSON.parse_string(JSON.stringify(loaded.s)) == JSON.parse_string(JSON.stringify(m.s)), "restore full state equality", m)
	if not course_enabled and int(m.s.floor) == 0:
		var legacy: Dictionary = m.s.duplicate(true)
		legacy.erase("course")
		var file := FileAccess.open(save_path + ".legacy", FileAccess.WRITE)
		file.store_string(JSON.stringify(legacy))
		file.close()
		var old = Model.new()
		verify(old.restore_run(save_path + ".legacy") and not old.s.get("course", true), "missing course legacy save defaults false", m)

func validate_reward(m) -> void:
	if course_enabled:
		var allowed: Array = []
		for stage in range(int(m.s.floor) + 1): allowed.append_array(EXPECTED_GRANTS[stage])
		for id in m.reward_options():
			verify(allowed.has(id) if Content.AMMO.has(id) else int(m.s.floor) == 4, "reward only introduced mechanics", m)
	# Probe declared removal bounds on an isolated copy, never alter replay path.
	if m.s.deck.size() > m.minimum_deck():
		var probe = clone(m)
		var accepted: bool = probe.choose_reward("remove", str(m.s.deck[0]))
		removal_probes.append({"gun": m.s.gun, "seed": m.s.seed, "course": course_enabled, "floor": m.s.floor, "deck_size": m.s.deck.size(), "declared_minimum": m.minimum_deck(), "accepted": accepted})
		verify(accepted, "removal honors declared minimum", m)
