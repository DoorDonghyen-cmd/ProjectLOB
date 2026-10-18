extends "res://tests/earned_ammo_campaign_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/earned_ammo/"): quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR");solver.candidate_limit=1500
	var results: Array=[]
	for seed_value in [17,1001,731042,8888]:
		for gun in Ammo.GUNS:
			for outfit in ["scout","work","carrier"]:
				var c=Campaign.new();c.start(gun,seed_value,0,"balanced",2,outfit)
				check(command(c,{"action":"enter","id":c.choices()[0].id}),"opening entry")
				var path: Array=solver.solve(c.model,14,12)
				check(not path.is_empty(),"basic opening path %s/%s/%d"%[gun,outfit,seed_value])
				for step in path: command(c,step)
				check(c.engine_reward(),"basic-only victory opens first reward")
				results.append({"gun":gun,"outfit":outfit,"seed":seed_value,"phase":c.s.phase,"turns":c.model.s.turns,"commands":path.size()})
	var file=FileAccess.open(output.path_join("opening.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":results},"  "));file.close()
	print("EARNED AMMO OPENING COMPLETE checks=%d failures=%d runs=%d"%[checks,failures.size(),results.size()])
	quit(0 if failures.is_empty() else 1)
