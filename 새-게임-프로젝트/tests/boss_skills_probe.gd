extends "res://tests/boss_skills_rules.gd"
const Solver = preload("res://tests/fire_control_solver.gd")
var observations: Array = []

func execute(m, command: Dictionary) -> bool:
	match str(command.action):
		"fire": m.s.fire_heat_trial.rounds=int(command.get("rounds",0)); return m.fire()
		"reload": return m.reload_magazine()
		"cool": return m.cool_magazine()
		"emergency": return m.emergency_resupply()
		"eject": return m.eject_magazine_rounds(command.indices)
	return false

func battle(state: Dictionary, policy: String, previous: Array) -> Dictionary:
	var m=Model.new(); m.s=Model.simulation_state(state)
	var row := {"policy":policy,"actions":[],"launches":0,"peak_projectiles":0,"intercept_events":0,"calls":0,"reserved_deployed":0,"cool":0,"reload":0,"emergency":0}
	var start: int=m.s.turns; var path: Array=[]
	if policy=="oracle_rng_known":
		var replay=Model.new(); replay.s=Model.simulation_state(state); var legal:=true
		for command in previous:
			if not execute(replay,command): legal=false; break
		path=previous if legal and replay.s.phase in ["reward","won"] else Solver.new().solve(m,4,18)
		row.search_unresolved=path.is_empty()
	for index in range(150):
		if m.s.phase!="ready": break
		var command := {"action":"fire","rounds":0}
		if policy=="oracle_rng_known":
			if index>=path.size(): break
			command=path[index]
		elif m.can_emergency_resupply(): command.action="emergency"
		elif m.s.magazine.is_empty(): command.action="reload"
		elif policy=="visible_heat_single":
			if int(m.s.heat)>=Content.hot_threshold(m.s): command.action="cool"
			else: command.rounds=1
		if not execute(m,command): check(false,"illegal policy command "+str(command)); break
		row.actions.append(command.duplicate(true))
		if command.action in ["cool","reload","emergency"]: row[command.action]+=1
		var detail: Dictionary=m.last_reload_detail if command.action in ["reload","emergency"] else m.s.history.back().detail
		for event in detail.get("advance_events",[])+detail.get("forced_cooling",{}).get("advance_events",[]):
			if event.kind=="projectile_launch":
				row.launches+=1; row.peak_projectiles=maxi(int(row.peak_projectiles),event.get("projectiles",[event.projectile]).size())
			elif event.kind=="brood_call" and event.released: row.calls+=1
		for deployment in detail.get("deployments",[])+detail.get("forced_cooling",{}).get("deployments",[]):
			if deployment.enemy.get("brood_reserve",false): row.reserved_deployed+=1
		for hit in detail.get("results",[]):
			if hit.get("intercept",false): row.intercept_events+=1
			for secondary in hit.get("secondary",[]):
				if secondary.get("intercept",false): row.intercept_events+=1
	row.phase=m.s.phase; row.won=m.s.phase in ["reward","won"]; row.turns=int(m.s.turns)-start; row.remaining=m.Reserve.remaining(m.s)
	row.loss_reason=m.s.get("loss_reason","")
	return row

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/boss_skills_20261106/"): quit(2); return
	for tag in ["single_safe","burst_safe","scatter_safe","heavy_elite","amplifier_safe","heavy_scout"]:
		var folder: String=ProjectSettings.globalize_path("res://../qa_runtime/leader_patterns_20261106/"+tag)
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("balance.json")))
		for entry in report.battles:
			if not entry.boss or int(entry.region) not in [1,3]: continue
			var file := "combat_%s_%d_r%d_n%d.json" % [entry.gun,int(entry.seed),int(entry.region),int(entry.node)]
			var c=Campaign.new(); check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))),"actual acquired boss state restores")
			for changed in [false,true]:
				var state: Dictionary=c.model.s.duplicate(true)
				if changed: state.boss_skills_version=1; Skills.prepare(state,c.node())
				check(Model.new().restore_state(canonical(state)),"same-state skill branch restores")
				for policy in ["full_fire","visible_heat_single","oracle_rng_known"]:
					var result: Dictionary=battle(state,policy,entry.path)
					result.source=tag; result.region=entry.region; result.gun=entry.gun; result.changed=changed
					observations.append(result)
	FileAccess.open(output.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"battles":observations},"  "))
	print("BOSS SKILLS COMPLETE checks=%d failures=%d" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
