extends "res://tests/leader_patterns_rules.gd"
const Solver = preload("res://tests/fire_control_solver.gd")
var observations: Array = []

func execute(m, action: Dictionary) -> bool:
	match str(action.action):
		"fire": m.s.fire_heat_trial.rounds = int(action.get("rounds",0)); return m.fire()
		"reload": return m.reload_magazine()
		"cool": return m.cool_magazine()
		"emergency": return m.emergency_resupply()
		"eject": return m.eject_magazine_rounds(action.indices)
	return false

func battle(state: Dictionary, policy: String, previous: Array = []) -> Dictionary:
	var m = Model.new(); m.s = Model.simulation_state(state)
	var row := {"policy":policy,"phase":"ready","actions":[],"rushes":0,"recoveries":0,"recovery_rounds":0,"open_rounds":0,"open_damage":0,"closed_rounds":0,"closed_damage":0,"rounds":0,"forced_cooling":0,"cool":0,"reload":0,"emergency":0,"nearest":1000000}
	var start: int = m.s.turns
	var path: Array = []
	if policy == "oracle_rng_known":
		var replay = Model.new(); replay.s = Model.simulation_state(state)
		var accepted := true
		for action in previous:
			if not execute(replay,action): accepted = false; break
		if accepted and replay.s.phase in ["reward","won"]: path = previous
		else: path = Solver.new().solve(m,4,18)
		row.search_unresolved = path.is_empty()
	for index in range(150):
		if m.s.phase != "ready": break
		var action := {"action":"fire","rounds":0}
		if policy == "oracle_rng_known":
			if index >= path.size(): break
			action = path[index]
		elif m.can_emergency_resupply(): action.action = "emergency"
		elif m.s.magazine.is_empty(): action.action = "reload"
		elif policy != "full_fire":
			if int(m.s.heat) >= Content.hot_threshold(m.s): action.action = "cool"
			elif policy == "counter_window":
				var e: Dictionary = m.s.enemies[0]
				if int(e.hp)>0 and not e.recovering and int(e.windup)==1 and int(e.get("jammed",0))==0 and int(m.s.heat)>0: action.action = "cool"
				elif not e.recovering: action.rounds = 1
			else: action.rounds = 1
		var before: Array = m.s.enemies.duplicate(true)
		if not execute(m,action):
			check(false,"policy issued illegal command " + policy + " " + str(action)); break
		row.actions.append(action.duplicate(true))
		if action.action in ["cool","reload","emergency"]: row[action.action] += 1
		var detail: Dictionary = m.s.history.back().detail
		# Reload can append a new load receipt after the actual reload receipt.
		if action.action in ["reload","emergency"]: detail = m.last_reload_detail
		row.forced_cooling += int(detail.get("forced_cooling",{}).get("elapsed",0))
		for hit in detail.get("results",[]):
			row.rounds += 1
			var target: int = hit.get("target",-1)
			if target<0 or target>=before.size() or not Workers.winding(before[target]) or not Content.is_attack(str(hit.id)): continue
			if before[target].recovering: row.recovery_rounds += 1
			var channel := "open" if before[target].recovering and int(before[target].def)==0 else "closed"
			row[channel+"_rounds"] += 1; row[channel+"_damage"] += int(hit.get("damage",0))
		for event in detail.get("advance_events",[]) + detail.get("forced_cooling",{}).get("advance_events",[]):
			if event.kind == "foundry_state":
				if event.action == "surge": row.rushes += 1
				elif event.action == "recover": row.recoveries += 1
			if event.kind in ["move","pull","projectile_move"]: row.nearest = mini(int(row.nearest),int(event.to))
	row.phase = m.s.phase; row.won = m.s.phase in ["reward","won"]
	row.turns = int(m.s.turns)-start; row.remaining = m.Reserve.remaining(m.s)
	row.end_enemies = m.s.enemies.duplicate(true)
	return row

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/leader_patterns_20261106/"): quit(2); return
	for tag in ["after_single17","after_burst17","after_scatter17","after_heavy17","after_amplifier17","after_heavy731042scout","heavy_elite"]:
		var collection := "leader_patterns_20261106" if tag == "heavy_elite" else "balance_review_20261106"
		var folder: String = ProjectSettings.globalize_path("res://../qa_runtime/"+collection+"/"+tag)
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("balance.json")))
		for entry in report.battles:
			if int(entry.region)!=2 or not (entry.boss or entry.elite): continue
			var file := "combat_%s_%d_r2_n%d.json" % [entry.gun,int(entry.seed),int(entry.node)]
			var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))
			var c = Campaign.new(); check(c.restore_state(source), "earned boss snapshot restores "+tag)
			for changed in [false,true]:
				var state: Dictionary = c.model.s.duplicate(true)
				if not changed:
					state.erase("enemy_pattern_version")
					for enemy in state.enemies + state.reinforcements:
						if int(enemy.get("foundry_version",0)) != 3: continue
						enemy.foundry_version = 2; enemy.def = int(enemy.shell_armor); enemy.erase("shell_armor")
						enemy.surge = 3 if str(enemy.species) == Workers.ELITE else 4
				if changed:
					state.enemy_pattern_version = 1; Patterns.prepare(state,{"region":1})
				check(Model.new().restore_state(canonical(state)), "paired starting state is valid")
				for policy in ["full_fire","visible_heat_single","counter_window","oracle_rng_known"]:
					var result: Dictionary = battle(state,policy,entry.path)
					result.source = tag; result.changed = changed; result.gun = entry.gun; result.node = entry.node; result.elite = entry.elite; result.boss = entry.boss
					observations.append(result)
					print("PROBE ",tag," new=",changed," ",policy," ",result.phase," rush=",result.rushes," open=",result.open_rounds," turns=",result.turns)
	FileAccess.open(output.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"battles":observations},"  "))
	print("LEADER PATTERNS COMPLETE checks=%d failures=%d" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
