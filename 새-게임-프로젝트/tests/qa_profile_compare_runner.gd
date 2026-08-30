extends SceneTree

const ReportScript := preload("res://scripts/qa/qa_experience_report.gd")
const ComparatorScript := preload("res://scripts/qa/qa_profile_comparator.gd")


func _initialize() -> void:
	var report_directory := OS.get_environment("QA_REPORT_DIR")
	if report_directory.is_empty():
		report_directory = "user://qa_runtime/profile_reports"
	var output_path := OS.get_environment("QA_COMPARISON_OUTPUT")
	if output_path.is_empty():
		output_path = "%s/profile_comparison.json" % report_directory.trim_suffix("/")

	var reports: Array = []
	for profile in ReportScript.PROFILES:
		var path := "%s/%s.json" % [report_directory.trim_suffix("/"), profile]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr("QA profile report missing: %s" % ProjectSettings.globalize_path(path))
			quit(1)
			return
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			printerr("QA profile report invalid JSON: %s" % ProjectSettings.globalize_path(path))
			quit(1)
			return
		reports.append(parsed)

	var comparison := ComparatorScript.compare(reports)
	var error := ComparatorScript.save(comparison, output_path)
	if error != OK:
		printerr("QA profile comparison write failed: %d" % error)
		quit(1)
		return
	print("[QA PROFILE] comparable=%s output=%s" % [
		str(comparison.comparable), ProjectSettings.globalize_path(output_path)])
	quit(0 if bool(comparison.comparable) else 1)
