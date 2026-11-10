extends "res://tests/challenge_balance_runner.gd"

func finite_case(kind: String, gun: String, core: String, seed_value: int) -> RefCounted:
	var m = built_model(kind,gun,core,seed_value)
	m.s.reserve_version = 1
	var pack: Array = m.s.enemies.duplicate(true)
	var reinforcements: Array = m.s.reinforcements.duplicate(true)
	m.s.deck = Model.Reserve.start_deck()
	if core != "none":
		for id in ["charge","charge_hot","pierce_p3","precise_p2","cool","bore"]:
			m.s.deck.append(id)
	m.begin_encounter()
	m.s.enemies=pack;m.s.reinforcements=reinforcements
	m.s.encounter_total=pack.size()+reinforcements.size();m.s.deployed=pack.size()
	m.assign_opening_lanes()
	return m

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/reserve/"): quit(1);return
	var results: Array=[]
	var solver=Solver.new()
	solver.candidate_limit=250
	for kind in ["elite","boss"]:
		for gun in Ammo.GUNS:
			for seed_value in [17,731042]:
				var core: String = {"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
				var m=finite_case(kind,gun,core,seed_value)
				check(Model.new().restore_state(m.s),"legal finite challenge")
				var path: Array=solver.solve(m,4,14)
				for command in path:
					var accepted:=false
					match str(command.action):
						"load":accepted=m.load_round(str(command.id))
						"confirm":accepted=m.confirm()
						"fire":accepted=m.fire()
						"reload":accepted=m.reload_magazine()
					check(accepted,"bounded solution legal")
				if not path.is_empty():check(m.s.phase in ["won","reward"],"path wins")
				results.append({"kind":kind,"gun":gun,"seed":seed_value,"core":core,"solved":not path.is_empty(),"turns":m.s.turns,"used":m.s.discard.size(),"remaining":m.s.deck.size()-m.s.discard.size()})
				print("CASE ",results.back())
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("matrix.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"note":"Bounded search sees future draws. Reachability only; not win rate or human experience.","checks":checks,"failures":failures,"runs":results},"  "));file.close()
	print("RESERVE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
