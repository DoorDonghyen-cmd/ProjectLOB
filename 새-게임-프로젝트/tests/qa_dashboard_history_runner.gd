extends SceneTree
## 보관한 dashboard run JSON을 최신순으로 묶어 file:// 호환 dashboard_data.js를 생성한다.

const ExporterScript := preload("res://scripts/qa/qa_dashboard_exporter.gd")


func _initialize() -> void:
	var runs_directory := OS.get_environment("QA_DASHBOARD_RUNS_DIR")
	if runs_directory.is_empty():
		runs_directory = "res://../docs/qa/dashboard/runs"
	var output_path := OS.get_environment("QA_DASHBOARD_DATA_PATH")
	if output_path.is_empty():
		output_path = "res://../docs/qa/dashboard/dashboard_data.js"
	var runs := ExporterScript.load_runs(runs_directory)
	if runs.is_empty():
		push_error("대시보드 실행 이력이 없음: %s" % ProjectSettings.globalize_path(runs_directory))
		quit(1)
		return
	var error := ExporterScript.save_data_script(runs, output_path)
	if error != OK:
		push_error("대시보드 데이터 생성 실패: %d" % error)
		quit(1)
		return
	print("[QA DASHBOARD] runs=%d output=%s" % [
		runs.size(), ProjectSettings.globalize_path(output_path)])
	quit(0)
