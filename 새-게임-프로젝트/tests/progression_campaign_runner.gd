extends "res://tests/city_campaign_runner.gd"
## Rebuild command evidence with current content, never replay incompatible old rules.
func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	solver.candidate_limit = 800
	rules()
	for gun in Ammo.GUNS:
		for route in ["safe", "mixed"]:
			print("PROGRESSION START " + str(gun) + " " + route)
			await play(gun, 731042, route)
	finish()
