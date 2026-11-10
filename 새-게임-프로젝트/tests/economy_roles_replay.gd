extends "res://tests/economy_roles_climb.gd"
func _run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/economy_roles_20261103/"):quit(2);return
	var folder:=OS.get_environment("QA_REPLAY_FOLDER")
	var file:="res://../qa_runtime/economy_roles_20261103/"+folder+"/balance.json"
	if folder=="legacy":file="res://../qa_runtime/build_roles_20261103/climb_earned/balance.json"
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file));var runs: Array=[]
	for endpoint in report.endpoints:
		if folder=="legacy" and endpoint.gun!="heavy":continue
		run_gun=endpoint.gun;run_seed=int(endpoint.seed);outfit_id=endpoint.get("outfit","carrier");copy_policy=false
		economy_version=int(endpoint.get("economy_version",0))
		var c=Campaign.new();c.start(run_gun,run_seed,0,"balanced",4,outfit_id,true)
		if economy_version==0:
			for key in ["economy_version","intro_part_bought","gate_bag_used","gate_ammo_used"]:c.s.erase(key)
		commands=[];metrics={};var fights:=0
		for step in endpoint.commands:
			var phase: String=c.s.phase
			if not command(c,step.duplicate(true)):break
			if step.has("turns"):check(c.model.s.turns==int(step.turns),"recorded action timing")
			if step.has("credits"):check(c.s.credits==int(step.credits),"recorded wallet after every command")
			if phase=="combat" and c.s.phase=="reward":fights+=1
		check(c.s.phase=="won" and c.profile.wins==1,"single earned ending")
		check(c.model.s.deck==endpoint.deck and c.s.equipped_parts==endpoint.parts,"same final inventory")
		check(JSON.parse_string(JSON.stringify(c.model.s.gate_mods))==endpoint.gate_mods,"same free gate investments")
		if endpoint.has("bag_upgrades"):check(c.s.bag_upgrades==int(endpoint.bag_upgrades) and c.s.credits==int(endpoint.credits),"same paid investments and remaining money")
		runs.append({"folder":folder,"gun":run_gun,"outfit":outfit_id,"seed":run_seed,"economy_version":economy_version,"fights":fights,"won":c.s.phase=="won"})
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":runs},"  "))
	print("ECONOMY ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
