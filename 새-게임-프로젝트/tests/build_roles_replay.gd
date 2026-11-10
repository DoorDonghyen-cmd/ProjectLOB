extends "res://tests/build_roles_climb.gd"
func _run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/build_roles_20261103/"):quit(2);return
	var result: Array=[]
	for file in ["build_roles_20261103/climb_earned/balance.json","late_balance_20261103/climb_fire_v2/balance.json"]:
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/"+file))
		for endpoint in report.endpoints:
			if int(endpoint.seed)!=17:continue
			var role_filter:=OS.get_environment("QA_REPLAY_ROLE")
			if not role_filter.is_empty() and int(endpoint.role_version)!=int(role_filter):continue
			var filter:=OS.get_environment("QA_REPLAY_GUN")
			if not filter.is_empty() and (endpoint.gun!=filter or int(endpoint.role_version)!=3):continue
			run_gun=endpoint.gun;run_seed=int(endpoint.seed);rule_version=int(endpoint.role_version)
			var c=Campaign.new();c.start(run_gun,run_seed,0,"balanced",4,"carrier",true)
			c.s.combat_roles_version=rule_version;c.model.s.combat_roles_version=rule_version
			# Historical records predate both acquisition support and specialist inheritance.
			for key in ["economy_version","intro_part_bought","gate_bag_used","gate_ammo_used"]:c.s.erase(key)
			c.s.erase("specialist_core_version");c.model.s.erase("specialist_core_version")
			commands=[];metrics={};var fights:=0
			for step in endpoint.commands:
				var phase: String=c.s.phase
				if not command(c,step.duplicate(true)):break
				if step.has("turns"):check(c.model.s.turns==int(step.turns),"exact recorded command timing")
				if phase=="combat" and c.s.phase=="reward":fights+=1
			check(c.s.phase=="won" and c.profile.wins==1,"one ending after replay")
			check(c.model.s.deck==endpoint.deck and c.s.equipped_parts==endpoint.parts and JSON.parse_string(JSON.stringify(c.model.s.gate_mods))==endpoint.gate_mods,"same final deck, parts and investment")
			result.append({"source":file,"seed":run_seed,"gun":run_gun,"version":rule_version,"won":c.s.phase=="won","fights":fights})
			print("BUILD REPLAY ",JSON.stringify(result.back()))
			FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":result},"  "))
	print("BUILD ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
