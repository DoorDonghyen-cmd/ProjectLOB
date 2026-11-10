extends "res://tests/late_balance_climb.gd"
func _run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/late_balance_20261103/"):quit(2);return
	var result: Array=[]
	for label in ["climb_fire_v1","climb_fire_v2","climb_fire_v2_reference","legacy_fire"]:
		var file: String=ProjectSettings.globalize_path("res://../qa_runtime/late_balance_20261103/")+label+"/balance.json"
		if label=="legacy_fire":file=ProjectSettings.globalize_path("res://../qa_runtime/playtest_rework_20261103/climb_incendiary/balance.json")
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
		for endpoint in report.endpoints:
			run_gun=endpoint.gun;run_seed=int(endpoint.seed);rule_version=int(endpoint.get("role_version",1))
			var c=Campaign.new();c.start(run_gun,run_seed,0,"balanced",4,"carrier",true)
			c.s.combat_roles_version=rule_version;c.model.s.combat_roles_version=rule_version
			commands=[];metrics={};var fights:=0
			for step in endpoint.commands:
				var phase: String=c.s.phase
				if not command(c,step.duplicate(true)):break
				if step.has("turns"):check(c.model.s.turns==int(step.turns),"exact earned command timing")
				if phase=="combat" and c.s.phase=="reward":fights+=1
			check(c.s.phase=="won" and c.profile.wins==1,"one completed ending per replay")
			check(c.model.s.deck==endpoint.deck and JSON.parse_string(JSON.stringify(c.model.s.gate_mods))==endpoint.gate_mods,"same final deck and investments")
			var emergency:=0
			for row in metrics.values():emergency+=int(row.emergency)
			result.append({"source":label,"seed":run_seed,"version":rule_version,"won":c.s.phase=="won","turns":c.model.s.turns,"fights":fights,"emergency":emergency})
			print("LATE REPLAY ",JSON.stringify(result.back()))
			FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":result},"  "))
	print("LATE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
