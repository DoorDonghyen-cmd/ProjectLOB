extends "res://tests/playtest_revision_emergency_runner.gd"
const Solver=preload("res://tests/central_combat_solver.gd")

func apply(m, step: Dictionary) -> bool:
	match str(step.action):
		"load":return m.load_round(str(step.id))
		"confirm":return m.confirm()
		"fire":return m.fire()
		"reload":return m.reload_magazine()
		"emergency":return m.emergency_resupply()
	return false

func automatic(m) -> Dictionary:
	var path:Array=[]
	var start:int=m.s.turns
	for i in range(100):
		if m.s.phase in ["lost","reward","won"]:break
		var step:Dictionary={}
		if m.can_emergency_resupply():step={"action":"emergency"}
		elif m.s.phase=="ready":step={"action":"fire" if not m.s.magazine.is_empty() else "reload"}
		else:
			for id in m.s.hand.duplicate():
				if m.can_load(id):
					check(m.load_round(id),"basic policy load");path.append({"action":"load","id":id})
			step={"action":"confirm" if not m.s.plan.is_empty() else "reload"}
		check(apply(m,step),"basic policy real action");path.append(step)
	check(Model.new().restore_state(m.s),"basic policy terminal snapshot valid")
	return {"phase":m.s.phase,"turns":int(m.s.turns)-start,"packs":m.s.get("emergency_uses",0),"hp":m.s.enemies.map(func(e):return e.hp),"distance":m.s.enemies.map(func(e):return e.distance),"remaining":Model.Reserve.remaining(m.s),"path":path}

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	var report:Array=[]
	# Paired synthetic comparisons use identical starting ammo, weapon and enemies.
	# One side has spent every attack; the other still has all twenty rounds.
	for gun in Ammo.GUNS:
		for seed_value in [731042,17]:
			for built in [false,true]:
				for exhausted in [false,true]:
					var c=Campaign.new();c.start(gun,seed_value)
					var m=c.model;m.s.deck=[]
					for i in range(20):m.s.deck.append("basic_p2")
					if built:
						m.s.equipped_parts=["thermal_drive","radiator","supply","chain_sink","compression_sink"]
						m.s.engine.levels.thermal_drive=8
					m.begin_encounter()
					m.s.enemies=[Data._enemy(["wall",18,6,1,26]),Data._enemy(["runner",12,0,2,30])]
					m.assign_opening_lanes();m.s.encounter_total=2;m.s.deployed=2
					if exhausted:m.s.hand=[];m.s.draw=[];m.s.discard=m.s.deck.duplicate()
					var result:=automatic(m)
					result.merge({"gun":gun,"seed":seed_value,"built":built,"exhausted":exhausted,"scenario":"synthetic 18HP armor6 at26m + 12HP speed2 at30m"})
					report.append(result)
	# Replay an actual earned late-game path that previously ran out of attacks.
	# Only the emergency policy is toggled; this is a counterfactual comparison,
	# not a migration of the player's saved run or proof of a fresh campaign win.
	var base:=ProjectSettings.globalize_path("res://../qa_runtime/")
	var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"central_live/balance/pressure_fit_double/combat_heavy_731042_r5_n41002.json"))
	var prior:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"playtest_revision_20261026/pressure_probe/double_prior_path/probe.json"))
	for enabled in [false,true]:
		var c=Campaign.new();check(c.restore_state(payload),"actual earned final encounter restores")
		var m=c.model
		if enabled:c.s.emergency_version=1;m.s.emergency_version=1;m.s.emergency_uses=0
		for step in prior.commands:check(apply(m,step),"replay earned exhaustion path")
		check(Model.new().restore_state(m.s),"actual exhausted state validates")
		var before:Dictionary=m.s.duplicate(true)
		var solver=Solver.new();solver.candidate_limit=700
		var path:Array=solver.solve(m,8,18)
		var solved_by_search:=not path.is_empty()
		if path.is_empty():path=solver.best_path.duplicate(true)
		for step in path:check(apply(m,step),"actual continuation action")
		if not solved_by_search:
			var fallback:=automatic(m);path.append_array(fallback.path)
		report.append({"scenario":"actual heavy 731042 final, identical earned prior path","emergency_enabled":enabled,"solved":m.s.phase in ["reward","won"],"phase":m.s.phase,"packs":m.s.get("emergency_uses",0),"extra_turns":int(m.s.turns)-int(before.turns),"remaining":Model.Reserve.remaining(m.s),"path":path,"before":before,"after":m.s})
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("probe.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"note":"Controlled comparisons and one archived earned-state counterfactual, not human win rates.","comparisons":report},"\t"));file.close()
	print("PLAYTEST REVISION EMERGENCY PROBE COMPLETE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
