extends "res://tests/challenge_campaign_runner.gd"

func replacement(c, id: String) -> String:
	return "" if c.can_acquire_ammo(id) else super.replacement(c,id)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/reserve/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	test_map_version=3
	solver.candidate_limit=700
	for row in [["burst","volley_drive"],["heavy","thermal_drive"],["amplifier","siege_drive"]]:
		preferred_core=row[1]
		print("RESERVE CAMPAIGN START ",row[0])
		await first_region(row[0],731042,"safe")
		check(reports.back().combat.reserve_version==1,"real run keeps finite policy")
	var file=FileAccess.open(output.path_join("campaign.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":reports,"wider_searches":wider_searches},"  "));file.close()
	print("RESERVE CAMPAIGN COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
