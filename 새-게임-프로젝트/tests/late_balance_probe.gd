extends SceneTree
const Model=preload("res://redesign/model.gd")
const Solver=preload("res://tests/fire_control_solver.gd")
const Search=preload("res://tests/weapon_magazine_solver.gd")
var output: String
var rows: Array=[]
var failures: Array=[]
func _initialize()->void:call_deferred("run")
func execute(m,step: Dictionary)->bool:
	if step.action=="fire":m.s.fire_heat_trial.rounds=int(step.get("rounds",0))
	return m.eject_magazine_rounds(step.indices) if step.action=="eject" else Search.command(m,"swap" if step.action=="reload" else step.action)
func measure(state: Dictionary,path: Array)->Dictionary:
	var m=Model.new()
	if not m.restore_state(state):failures.append("invalid fixture");return {}
	var row:={"turns":0,"forced_turns":0,"forced_count":0,"reload_turns":0,"reload_unfired_returned":0,"cool_turns":0,"fire_actions":0,"shots":0,"direct":0,"burn":0,"ground":0,"emergencies":0,"margin":1000000,"path":path}
	var started: int=m.s.turns
	for step in path:
		var before: int=m.s.turns
		var held: int=m.s.magazine.size()
		if not execute(m,step):row.invalid=step;break
		if step.action!="eject":
			var detail: Dictionary=m.s.history.back().detail
			var elapsed: int=m.s.turns-before
			if step.action=="reload":row.reload_turns+=elapsed;row.reload_unfired_returned+=held
			if step.action=="cool":row.cool_turns+=elapsed
			if step.action=="emergency":row.emergencies+=1
			if step.action=="fire":
				row.fire_actions+=1
				var forced: Dictionary=detail.get("forced_cooling",{})
				if not forced.is_empty():row.forced_turns+=int(forced.get("elapsed",0));row.forced_count+=1
				for shot in detail.get("results",[]):row.shots+=1;row.direct+=int(shot.get("damage",0))
			for event in detail.get("advance_events",[])+detail.get("forced_cooling",{}).get("advance_events",[]):
				if event.kind=="burn":row.burn+=int(event.damage);row.ground+=int(event.damage) if event.get("ground",false) else 0
		for enemy in m.s.enemies:
			if int(enemy.hp)>0:row.margin=mini(row.margin,int(enemy.distance))
		if m.s.phase in ["reward","won","lost"]:break
	row.turns=int(m.s.turns)-started;row.won=m.s.phase in ["reward","won"];row.used=m.s.discard.size();row.remaining=m.Reserve.remaining(m.s)
	return row
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/late_balance_20261103/"):quit(2);return
	var mode:=OS.get_environment("QA_MODE")
	for label in ["climb_primary","climb_incendiary"]:
		var source: String=ProjectSettings.globalize_path("res://../qa_runtime/playtest_rework_20261103/")+label
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.path_join("balance.json")))
		for battle in report.battles:
			if battle.gun!="heavy":continue
			if mode=="range" and (int(battle.region)<4 or not (battle.elite or battle.boss)):continue
			var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.path_join("combat_heavy_731042_r%d_n%d.json"%[int(battle.region),int(battle.node)])))
			var row:=measure(snapshot.combat,battle.path)
			row.source=label;row.region=battle.region;row.node=battle.node
			if mode=="growth":
				var candidate: Dictionary=snapshot.combat.duplicate(true)
				candidate.combat_roles_version=2
				row.growth=measure(candidate,battle.path)
				if int(battle.region)>=4 and (battle.elite or battle.boss):
					var solver=Solver.new()
					var prior_path: Array=solver.ranged(snapshot.combat,40,64,false)
					var new_path: Array=solver.ranged(candidate,40,64,false)
					row.range=measure(snapshot.combat,prior_path) if not prior_path.is_empty() else {"won":false}
					row.growth_range=measure(candidate,new_path) if not new_path.is_empty() else {"won":false}
			if mode=="range":
				var solver=Solver.new()
				var path: Array=solver.ranged(snapshot.combat,40,64,false)
				row.range=measure(snapshot.combat,path) if not path.is_empty() else {"won":false}
			rows.append(row)
			print("LATE PROBE ",JSON.stringify(row))
			FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures},"  "))
			await process_frame
	print("LATE BALANCE COMPLETE failures=",failures.size());quit(0 if failures.is_empty() else 1)
