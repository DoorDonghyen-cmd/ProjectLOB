extends "res://tests/build_roles_rules.gd"
func earned_branches()->Array:
	var result: Array=[]
	var search=preload("res://tests/fire_control_solver.gd").new()
	for region in [3,4]:
		var file:="res://../qa_runtime/build_roles_20261103/climb_earned/gate_heavy_17_r%d.json"%region
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
		for core in ["thermal_drive","inferno" if region==3 else "momentum"]:
			var c=Campaign.new();check(c.restore_state(source),"earned gate restores for legal core comparison")
			if core!="thermal_drive":check(c.replace_part("thermal_drive",core),"swap only an actually owned specialist core")
			check(c.gate("skip") and c.depart_gate(),"same unincreased next region for both core choices")
			check(c.enter(int(c.choices()[0].id)),"enter the same next battle through a legal map link")
			var start: int=c.model.s.turns
			var path: Array=search.solve(c.model)
			check(not path.is_empty(),"owned specialist has a reachable next battle")
			var actions: Array=[];var last: Dictionary={}
			for step in path:
				if step.action=="fire":c.model.s.fire_heat_trial.rounds=int(step.get("rounds",0))
				var ok: bool
				match step.action:
					"fire":ok=c.model.fire()
					"cool":ok=c.model.cool_magazine()
					"reload":ok=c.model.reload_magazine()
					"emergency":ok=c.model.emergency_resupply()
					"eject":ok=c.model.eject_magazine_rounds(step.indices)
				check(ok,"legal earned core combat input")
				last=c.model.s.duplicate(true);actions.append(step)
				c.sync_combat();check(c.save()==OK,"earned branch saves")
				var resumed=Campaign.new();check(resumed.restore(),"earned branch save restores")
				check(canonical(resumed.model.s)==canonical(c.model.s),"branch resume preserves exact combat")
			check(c.s.phase=="reward","owned core reaches actual battle reward")
			result.append({"source":file,"core":core,"node":c.s.node,"won":c.s.phase=="reward","turns":int(last.get("turns",start))-start,"parts":c.s.equipped_parts,"deck":c.model.s.deck,"commands":actions})
	return result
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/build_roles_20261103/"):quit(2);return
	for kind in ["fire","control","relay","direct"]:
		for version in [2,3]:
			var rounds: Array={"fire":["bore","basic_p1","basic_p1","basic_p1"],"control":["disrupt_c","precise_p1","basic_p1","basic_p1"],"relay":["precise_p2"],"direct":["basic_p2","charge","precise_p2"]}[kind]
			var parts: Array={"fire":["inferno","coil"],"control":["momentum","rammer"],"relay":["volley_drive","duplex","capacitor"],"direct":["volley_drive","third_striker","opening"]}[kind]
			var m=build(rounds,parts,"single",version)
			targets(m,4 if kind=="relay" else 3,1 if kind=="relay" else 1000,3)
			for enemy in m.s.enemies:enemy.speed=0 if kind=="fire" else 2
			var events: Array=[]
			for i in range(rounds.size()):events.append(shot(m))
			restore_check(m)
			records.append({"kind":kind,"version":version,"hp":m.s.enemies.map(func(e):return e.hp),"distances":m.s.enemies.map(func(e):return e.distance),"turns":m.s.turns,"reload_cost":m.reload_cost(),"direct":events.map(func(e):return e.damage),"alive":m.alive_count()})
	check(records[1].hp[1]<records[0].hp[1] and records[1].hp[2]==records[0].hp[2],"area specialist improves bounded adjacent damage")
	check(records[3].direct[1]>records[2].direct[1] and records[3].distances[0]>records[2].distances[0],"setup buys actual attack payoff and approach time")
	check(records[5].alive==records[4].alive-1,"legal relay module gains one target")
	check(records[7].direct==records[6].direct and records[7].hp==records[6].hp and records[7].turns==records[6].turns,"existing first/third direct combination is mechanically unchanged")
	var earned:=earned_branches()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"note":"Controlled fixtures separated from legal owned-core branches. Search sees future RNG; not human win rate.","checks":checks,"failures":failures,"comparisons":records,"earned_core_branches":earned},"  "))
	print("BUILD ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
