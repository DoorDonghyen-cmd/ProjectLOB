extends "res://tests/city_campaign_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/maps/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	test_map_version = 2
	solver.candidate_limit = 800
	for gun in Ammo.GUNS:
		print("NEW MAP COMBAT " + str(gun))
		await play(str(gun), 731042, "mixed" if gun in ["burst", "heavy"] else "safe")
	finish()
