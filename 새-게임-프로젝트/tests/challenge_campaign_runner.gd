extends "res://tests/earned_ammo_campaign_runner.gd"

func command(c, item: Dictionary) -> bool:
	var step := item.duplicate(true)
	if step.action == "enter":
		for option in c.choices():
			if bool(option.get("elite",false)):
				step.id = option.id
				break
	# The run audit tests boss progression, not optional encounter branches.
	if step.action == "resolve" and c.s.phase == "event": step = {"action":"resolve","id":"skip"}
	return super.command(c,step)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/elite_boss/"): quit(1);return
	output = OS.get_environment("QA_OUTPUT_DIR")
	test_map_version = 3
	solver.candidate_limit = 1000
	for core in ["volley_drive","thermal_drive","siege_drive"]:
		preferred_core = core
		for gun in ["burst","amplifier"]:
			print("CHALLENGE CAMPAIGN START ",core," ",gun)
			await first_region(gun,731042,"safe")
			check(reports.back().state.roster_version == 5,"campaign retains new roster")
			check(reports.back().combat.enemies[0].get("species","") == "closure_watch","real route reaches new boss")
	var file := FileAccess.open(output.path_join("campaign.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":reports,"wider_searches":wider_searches},"  "));file.close()
	print("CHALLENGE CAMPAIGN COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
