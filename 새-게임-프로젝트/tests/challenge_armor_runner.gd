extends "res://tests/reserve_balance_runner.gd"
## Damage comparisons use live attacks; finite encounter search is reachability only.

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/elite_boss/"): quit(1);return
	var comparisons: Array=[]
	for armor in [2,4,5,6]:
		for gun in Ammo.GUNS:
			for sequence in [["basic_p3"],["pierce_p3"],["precise_p2"],["charge","basic_p3"],["charge","precise_p2"],["shatter","precise_p2"],["bore"]]:
				for opened in [false,true]:
					var m=challenge_model("boss",sequence,gun)
					m.s.reserve_version=1
					m.s.enemies[0].guard_armor=armor
					m.s.enemies[0].def=0 if opened else armor
					if opened: m.s.enemies[0].ranged_phase="prepare"
					var shots: Array=fire(m,sequence)
					while m.s.phase=="ready" and not m.s.magazine.is_empty():
						check(m.fire(),"remaining single-shot trigger")
						shots.append_array(m.s.history.back().detail.results)
					var direct:=0
					for shot in shots: direct+=int(shot.damage)
					comparisons.append({"armor":armor,"gun":gun,"sequence":sequence,"opened":opened,"direct":direct,"hp_lost":44-int(m.s.enemies[0].hp),"turns":m.s.turns,"heat":m.s.heat})
	var runs: Array=[]
	var solver=Solver.new()
	solver.candidate_limit=250
	for armor in [2,5]:
		for gun in Ammo.GUNS:
			for seed_value in [17,731042]:
				var core: String={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
				var m=finite_case("boss",gun,core,seed_value)
				m.s.enemies[0].guard_armor=armor;m.s.enemies[0].def=armor
				check(Model.new().restore_state(m.s),"finite armored encounter valid")
				var path: Array=solver.solve(m,4,14)
				var margin:=1000000
				var opened_shots:=0
				for command in path:
					var accepted:=false
					match str(command.action):
						"load":accepted=m.load_round(str(command.id))
						"confirm":accepted=m.confirm()
						"reload":accepted=m.reload_magazine()
						"fire":
							if int(m.s.enemies[0].hp)>0 and int(m.s.enemies[0].def)==0: opened_shots+=1
							accepted=m.fire()
					check(accepted,"finite armored encounter commands legal")
					for enemy in m.s.enemies+Ranged.active(m.s):
						if int(enemy.hp)>0:margin=mini(margin,int(enemy.distance))
				if not path.is_empty():check(m.s.phase in ["won","reward"],"armored encounter solution wins")
				runs.append({"armor":armor,"gun":gun,"core":core,"seed":seed_value,"solved":not path.is_empty(),"turns":m.s.turns,"used":m.s.discard.size(),"remaining":m.s.deck.size()-m.s.discard.size(),"margin":margin if margin<1000000 else -1,"opened_shots":opened_shots})
				print("ARMOR CASE ",runs.back())
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("armor.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"note":"Prepared comparative builds; bounded search sees future draws and RNG. No human win-rate claim.","checks":checks,"failures":failures,"damage":comparisons,"runs":runs},"  "));file.close()
	print("CHALLENGE ARMOR COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
