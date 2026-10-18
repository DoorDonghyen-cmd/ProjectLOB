extends "res://tests/challenge_rules_runner.gd"
const Solver = preload("res://tests/city_combat_solver.gd")

func built_model(kind: String, gun: String, core: String, seed_value: int) -> RefCounted:
	var m = Model.new()
	m.start(gun,seed_value,false,"carrier")
	m.s.deck = ["basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p3","charge","precise_p2","pierce_p2","cool"]
	if core == "thermal_drive": m.s.deck = ["basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p3","charge_heat","thermal","pierce_p2","cool"]
	if core == "siege_drive": m.s.deck = ["basic_p2","basic_p2","basic_p2","basic_p2","basic_p3","basic_p3","charge","charge_hot","pierce_p3","cool"]
	if core != "none":
		m.s.equipped_parts = [core,"radiator"]
		m.s.engine.levels[core] = 2
	else: m.s.deck = Data.Acquisition.start_deck()
	m.begin_encounter()
	var pack := Data.encounter_pack({"id":801,"region":0,"floor":8,"kind":"boss" if kind == "boss" else "combat","elite":kind == "elite","name":kind},seed_value,gun,0,0,5)
	m.s.enemies = pack.active;m.s.reinforcements = pack.reserve;m.s.encounter_total = pack.total;m.s.deployed = pack.active.size()
	m.assign_opening_lanes()
	return m

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/elite_boss/"): quit(1);return
	var results: Array = []
	var solver = Solver.new()
	solver.candidate_limit = 350
	for kind in ["elite","boss"]:
		for core in ["volley_drive","thermal_drive","siege_drive","none"]:
			for gun in Ammo.GUNS:
				for seed_value in [17,731042]:
					var m = built_model(kind,gun,core,seed_value)
					check(Model.new().restore_state(m.s),"legal build fixture")
					var path: Array = solver.solve(m,4,12)
					var margin := 1000000
					for command in path:
						var accepted := false
						match str(command.action):
							"load": accepted = m.load_round(str(command.id))
							"confirm": accepted = m.confirm()
							"fire": accepted = m.fire()
							"reload": accepted = m.reload_magazine()
						check(accepted,"bounded solution replays legally")
						for e in m.s.enemies + Ranged.active(m.s):
							if int(e.hp) > 0: margin = mini(margin,int(e.distance))
					if not path.is_empty(): check(m.s.phase in ["reward","won"],"replayed solution wins")
					results.append({"kind":kind,"gun":gun,"core":core,"seed":seed_value,"solved":not path.is_empty(),"turns":m.s.turns,"reloads":m.s.reloads,"margin":margin if margin < 1000000 else -1,"path":path})
				print("MATRIX ",kind," ",core," ",gun," solved=",results[-2].solved,"/",results[-1].solved)
	var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("matrix.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"note":"Bounded search sees future RNG; reachability evidence, not win rate or player experience.","runs":results},"  "));file.close()
	print("CHALLENGE BALANCE COMPLETE checks=%d failures=%d runs=%d" % [checks,failures,results.size()])
	quit(0 if failures == 0 else 1)
