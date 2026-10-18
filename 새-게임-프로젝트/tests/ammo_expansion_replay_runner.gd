extends "res://tests/city_campaign_runner.gd"
## Re-execute the full current campaign evidence after reward/UI follow-up fixes.
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_expansion/"):
		quit(1)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	var source := OS.get_environment("QA_CAMPAIGN_SOURCE")
	if not FileAccess.file_exists(source):
		push_error("Run current campaign search before replay: " + source)
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not check(data.get("failures", ["missing"]).is_empty() and data.get("runs", []).size() == 10, "ten complete source runs"):
		quit(1)
		return
	for run in data.runs: await replay_previous(run)
	finish()
