class_name QATeamOrchestrator
extends RefCounted

const PacketScript := preload("res://scripts/qa/qa_role_packet.gd")
const ReportScript := preload("res://scripts/qa/qa_team_report.gd")
const IntegratorScript := preload("res://scripts/qa/qa_team_integrator.gd")
const DashboardScript := preload("res://scripts/qa/qa_dashboard_exporter.gd")


static func prepare(
	manifest: Dictionary,
	output_directory: String,
	artifacts_by_role: Dictionary,
	instructions_by_role: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var packets: Dictionary = {}
	for role in PacketScript.ROLES:
		var instruction_values: Array[String] = []
		for instruction in instructions_by_role.get(role, []):
			instruction_values.append(str(instruction))
		var packet := PacketScript.create(
			manifest, role, artifacts_by_role.get(role, []), instruction_values)
		for error in PacketScript.validation_errors(packet):
			errors.append("%s: %s" % [role, error])
		packets[role] = packet
	if not errors.is_empty():
		return {"prepared": false, "errors": errors, "packets": packets}
	for role in PacketScript.ROLES:
		var error := PacketScript.save(packets[role], "%s/packets/%s.json" % [output_directory, role])
		if error != OK:
			errors.append("%s packet 저장 실패: %d" % [role, error])
	return {"prepared": errors.is_empty(), "errors": errors, "packets": packets}


static func integrate_from_directory(output_directory: String) -> Dictionary:
	var reports: Array = []
	for role in PacketScript.ROLES:
		var path := "%s/reports/%s.json" % [output_directory, role]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"ready": false, "errors": ["원본 보고 누락: %s" % role]}
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			return {"ready": false, "errors": ["원본 보고 JSON 오류: %s" % role]}
		reports.append(parsed)
	var summary := IntegratorScript.integrate(reports)
	if bool(summary.ready):
		var dashboard_run := _create_dashboard_run(output_directory, reports, summary)
		var dashboard_errors: Array[String] = []
		var run_error := DashboardScript.save_run(
			dashboard_run, "%s/dashboard_run.json" % output_directory)
		if run_error != OK:
			dashboard_errors.append("dashboard run 저장 실패: %d" % run_error)
		var data_error := DashboardScript.save_data_script(
			[dashboard_run], "%s/dashboard_data.js" % output_directory)
		if data_error != OK:
			dashboard_errors.append("dashboard data 저장 실패: %d" % data_error)
		summary["dashboard"] = {
			"exported": dashboard_errors.is_empty(),
			"run_path": "%s/dashboard_run.json" % output_directory,
			"data_path": "%s/dashboard_data.js" % output_directory,
			"errors": dashboard_errors,
		}
		var error := IntegratorScript.save(summary, "%s/integrated_summary.json" % output_directory)
		if error != OK:
			return {"ready": false, "errors": ["통합 리포트 저장 실패: %d" % error]}
	return summary


static func _create_dashboard_run(
	output_directory: String,
	reports: Array,
	summary: Dictionary
) -> Dictionary:
	var first: Dictionary = reports[0]
	var packet := _read_json("%s/packets/functional_qa.json" % output_directory)
	return DashboardScript.create_run({
		"session_id": str(first.get("session_id", "")),
		"commit": str(first.get("commit", "")),
		"dirty_worktree": bool(packet.get("dirty_worktree", false)),
		"scenario_id": str(first.get("scenario_id", "")),
		"gameplay_seed": int(first.get("gameplay_seed", 0)),
		"mode": "qa_team",
		"status": "BLOCKED" if not summary.get("blocked", []).is_empty() else "PASS",
	}, summary)


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
