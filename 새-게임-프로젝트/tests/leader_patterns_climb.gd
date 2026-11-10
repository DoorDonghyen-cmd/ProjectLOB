extends "res://tests/ammo_upgrade_balance.gd"

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/leader_patterns_20261106/") and not output.replace("\\", "/").contains("/qa_runtime/boss_skills_20261106/"): quit(2); return
	solver = preload("res://tests/fire_control_solver.gd").new()
	route_policy = OS.get_environment("QA_ROUTE"); acquisition_policy = "refit"; rule_version = 3
	run_gun = OS.get_environment("QA_GUN"); run_seed = int(OS.get_environment("QA_SEED")); outfit_id = OS.get_environment("QA_OUTFIT")
	build_kind = {"single":"direct","burst":"control","scatter":"control","heavy":"fire","amplifier":"direct"}[run_gun]
	role_build = build_kind == "fire"
	preferred_core = {"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[run_gun]
	if not OS.get_environment("QA_CORE").is_empty(): preferred_core = OS.get_environment("QA_CORE")
	for tag in ["after_"+run_gun+"17", "after_"+run_gun+"731042scout"]:
		var file: String = ProjectSettings.globalize_path("res://../qa_runtime/balance_review_20261106/"+tag+"/balance.json")
		if not FileAccess.file_exists(file): continue
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
		for entry in report.battles:
			if entry.get("solved",false): cached_paths["%s/%d/%d/refit" % [entry.gun,int(entry.seed),int(entry.node)]] = entry.path
	var c = Campaign.new(); c.start(run_gun,run_seed,0,"balanced",4,outfit_id,true)
	roundtrip(c)
	var won: bool = await play_run(c)
	endpoints.append({"gun":run_gun,"seed":run_seed,"outfit":outfit_id,"route":route_policy,"core_preference":preferred_core,"won":won,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"commands":commands.duplicate(true)})
	check(won,"earned new-pattern route completes")
	write_report()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"endpoints":endpoints},"  "))
	print("LEADER PATTERNS COMPLETE checks=%d failures=%d" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
