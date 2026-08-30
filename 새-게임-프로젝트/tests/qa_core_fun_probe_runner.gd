extends SceneTree

const ProbeScript := preload("res://scripts/qa/qa_core_fun_probe.gd")


func _initialize() -> void:
	var output_path := OS.get_environment("QA_CORE_FUN_OUTPUT")
	if output_path.is_empty():
		output_path = "user://qa_runtime/core_fun_probe.json"
	var report := ProbeScript.generate_report()
	var error := ProbeScript.save(report, output_path)
	if error != OK:
		printerr("QA core fun probe save failed: %d" % error)
		quit(2)
		return
	print("[QA CORE FUN] order=%d/%d planned=%d mixed=%d output=%s" % [
		int(report.order_sensitive_scenarios), int(report.scenario_count),
		int(report.planned_better_scenarios), int(report.mixed_better_than_basic_scenarios),
		ProjectSettings.globalize_path(output_path)])
	quit(0)
