extends "res://tests/build_payoff_campaign_runner.gd"
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_build_balance/"): quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR");test_map_version=2;solver.candidate_limit=1500
	for core in ["volley_drive","thermal_drive","siege_drive"]:
		preferred_core=core
		for gun in Ammo.GUNS:
			await first_region(str(gun),731042,"safe")
	var file=FileAccess.open(output.path_join("campaign.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":reports,"wider_searches":wider_searches},"  "));file.close()
	print("AMMO BUILD BALANCE CAMPAIGN COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
