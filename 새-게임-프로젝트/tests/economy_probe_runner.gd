extends "res://tests/reactor_rules_runner.gd"
const Solver = preload("res://tests/central_combat_solver.gd")

func apply(m, item: Dictionary) -> bool:
	match str(item.action):
		"load":return m.load_round(str(item.id))
		"confirm":return m.confirm()
		"fire":return m.fire()
		"reload":return m.reload_magazine()
		"emergency":return m.emergency_resupply()
		"exchange":return m.exchange(str(item.id))
		"field_compress":return m.field_compress(str(item.id))
	return false

func preparations(m) -> Array:
	var result: Array = [{"model":m,"path":[]}]
	var frontier: Array = result.duplicate()
	for count in range(int(m.s.exchange_left)):
		var next: Array = []
		for branch in frontier:
			var ids: Array = []
			for id in branch.model.s.hand:
				if ids.has(id):continue
				ids.append(id)
				var copy = Solver.new().clone(branch.model)
				if copy.exchange(id):next.append({"model":copy,"path":branch.path+[{"action":"exchange","id":id}]})
		result.append_array(next);frontier = next
	for branch in result.duplicate():
		for id in branch.model.field_compressible_ids():
			var copy = Solver.new().clone(branch.model)
			if copy.field_compress(id):result.append({"model":copy,"path":branch.path+[{"action":"field_compress","id":id}]})
	return result

func _run() -> void:
	var user_path := ProjectSettings.globalize_path("user://").replace("\\","/")
	if not user_path.contains("/qa_runtime/economy_20261029/") and not user_path.contains("/qa_runtime/late_growth_20261030/"):quit(2);return
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_ECONOMY_SOURCE")))
	var c = Campaign.new();check(c.restore_state(payload),"earned failure state restores")
	var report: Array = []
	var cached: Array = []
	var previous_file := OS.get_environment("QA_OUTPUT_DIR").path_join("probe.json")
	if FileAccess.file_exists(previous_file):
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(previous_file))
		for row in previous.get("rows",[]):
			if row.mode == "current_wide" and row.solved:cached = row.path
	for mode in ["current_wide","prior_heat","preparation_options","without_afterburner","lens_for_afterburner","capacitor_for_afterburner"]:
		if not OS.get_environment("QA_PROBE_MODES").is_empty() and not OS.get_environment("QA_PROBE_MODES").split(",").has(mode):continue
		var m = Model.new();check(m.restore_state(payload.combat),"identical starting model")
		if mode == "prior_heat":m.s.sustained_version = 0;m.s.sustained_attacks = 0
		if mode == "preparation_options" and int(m.s.exchange_left) == 0 and m.field_compressible_ids().is_empty():continue
		if mode.ends_with("afterburner"):
			if not m.s.equipped_parts.has("afterburner"):continue
			m.s.equipped_parts.erase("afterburner")
			var replacement := "lens" if mode == "lens_for_afterburner" else "capacitor" if mode == "capacitor_for_afterburner" else ""
			if not replacement.is_empty():
				if not c.s.parts.has(replacement) or m.s.equipped_parts.has(replacement):continue
				m.s.equipped_parts.append(replacement)
		check(Ammo.valid_part_set(str(m.s.gun),m.s.equipped_parts) and Model.new().restore_state(m.s),"counterfactual starts with a valid owned part set")
		var search = Solver.new();search.candidate_limit = 1800
		var started := Time.get_ticks_msec()
		var path: Array = []
		if mode == "current_wide" and not cached.is_empty():
			var trial = search.clone(m)
			var legal := true
			for item in cached:
				if not apply(trial,item):legal = false;break
			if legal and trial.s.phase in ["reward","won"]:path = cached.duplicate(true)
		if mode == "preparation_options":
			var choices: Array = preparations(m)
			for choice in choices.slice(1):
				var option_search = preload("res://tests/economy_options_solver.gd").new();option_search.candidate_limit = 1800
				var continuation: Array = option_search.solve(choice.model,12,30)
				if not continuation.is_empty():path = choice.path + continuation;break
		elif path.is_empty():path = search.solve(m,12,30)
		if path.is_empty() and mode == "current_wide":
			search.candidate_limit = 5000;path = search.solve(m,40,36)
		var initial: Dictionary = m.s.duplicate(true)
		var forced := 0;var extra := 0
		for item in path:
			check(apply(m,item),"probe path uses legal combat commands")
			if item.action == "fire":
				var detail: Dictionary = m.s.history.back().detail
				forced += int(detail.forced_reload.get("cost",0))
				for shot in detail.results:extra += int(shot.get("sustained_heat",0))
		check(Model.new().restore_state(JSON.parse_string(JSON.stringify(m.s))),"probe result restores")
		var row := {"mode":mode,"solved":m.s.phase in ["reward","won"],"search_ms":Time.get_ticks_msec()-started,"turns":int(m.s.turns)-int(initial.turns),"fired":int(m.s.shots)-int(initial.shots),"remaining":Model.Reserve.remaining(m.s),"forced_turns":forced,"extra_heat":extra,"parts":m.s.equipped_parts,"path":path,"initial":initial,"end":m.s,"best_state":search.best_state if path.is_empty() else {}}
		report.append(row)
		print("ECONOMY PROBE ",mode," solved=",row.solved," turns=",row.turns," remaining=",row.remaining," ms=",row.search_ms)
		FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"note":"Identical earned combat state. Owned part substitutions and prior heat are isolated counterfactuals; validate any selected loadout through legal map preparation before adopting it. Search is bounded and knows hidden draws/RNG.","checks":checks,"failures":failures,"rows":report},"  "))
	print("ECONOMY PROBE COMPLETE checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
