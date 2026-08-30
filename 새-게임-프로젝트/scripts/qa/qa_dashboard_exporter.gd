class_name QADashboardExporter
extends RefCounted

const SCHEMA_VERSION := 1
const STATUSES := ["PASS", "FAIL", "REVIEW", "BLOCKED"]
const CLASSIFICATION_SOURCES := {
	"FAIL": "confirmed_bugs",
	"CANDIDATE": "candidate_bugs",
	"SEEDED": "seeded_detections",
	"SIGNAL": "experience_signals",
	"INFRA": "infrastructure",
	"BLOCKED": "blocked",
	"PASS": "passes",
}


static func create_run(
	metadata: Dictionary,
	summary: Dictionary,
	regression: Dictionary = {},
	combat_metrics: Dictionary = {},
	evidence_links: Array = []
) -> Dictionary:
	var counts := {
		"pass": summary.get("passes", []).size(),
		"fail": summary.get("confirmed_bugs", []).size(),
		"candidate": summary.get("candidate_bugs", []).size(),
		"seeded": summary.get("seeded_detections", []).size(),
		"signal": summary.get("experience_signals", []).size(),
		"infra": summary.get("infrastructure", []).size(),
		"blocked": summary.get("blocked", []).size(),
		"conflict": summary.get("conflicts", []).size(),
	}
	var run := {
		"schema_version": SCHEMA_VERSION,
		"run_id": str(metadata.get("run_id", metadata.get("session_id", ""))),
		"created_at": str(metadata.get(
			"created_at", Time.get_datetime_string_from_system(false, true))),
		"status": _resolve_status(metadata, counts, regression),
		"mode": str(metadata.get("mode", "focused")),
		"scope": str(metadata.get("scope", metadata.get("scenario_id", ""))),
		"build": {
			"commit": str(metadata.get("commit", "")),
			"dirty_worktree": bool(metadata.get("dirty_worktree", false)),
			"gameplay_seed": int(metadata.get("gameplay_seed", 0)),
			"platform": str(metadata.get("platform", OS.get_name())),
			"engine": str(metadata.get("engine", Engine.get_version_info().get("string", ""))),
		},
		"counts": counts,
		"regression": {
			"passed": int(regression.get("passed", 0)),
			"failed": int(regression.get("failed", 0)),
			"warnings": int(regression.get("warnings", 0)),
		},
		"combat_metrics": combat_metrics.duplicate(true),
		"core_fun": metadata.get("core_fun", {}).duplicate(true),
		"roles": _role_summaries(summary),
		"findings": _flatten_findings(summary),
		"evidence_links": evidence_links.duplicate(true),
	}
	return run


static func validation_errors(run: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(run.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("지원하지 않는 dashboard schema_version")
	for field in ["run_id", "created_at", "status", "scope"]:
		if str(run.get(field, "")).strip_edges().is_empty():
			errors.append("%s가 비어 있음" % field)
	if not STATUSES.has(str(run.get("status", ""))):
		errors.append("status가 PASS/FAIL/REVIEW/BLOCKED가 아님")
	if not run.get("build", null) is Dictionary:
		errors.append("build가 객체가 아님")
	elif str(run.build.get("commit", "")).strip_edges().is_empty():
		errors.append("build.commit이 비어 있음")
	for field in ["counts", "regression", "combat_metrics"]:
		if not run.get(field, null) is Dictionary:
			errors.append("%s가 객체가 아님" % field)
	for field in ["roles", "findings", "evidence_links"]:
		if not run.get(field, null) is Array:
			errors.append("%s가 배열이 아님" % field)
	for finding in run.get("findings", []):
		if not finding is Dictionary:
			errors.append("finding이 객체가 아님")
			continue
		if not ["PASS", "FAIL", "CANDIDATE", "SEEDED", "SIGNAL", "INFRA", "BLOCKED"].has(
				str(finding.get("classification", ""))):
			errors.append("finding classification이 잘못됨")
	return errors


static func is_valid(run: Dictionary) -> bool:
	return validation_errors(run).is_empty()


static func save_run(run: Dictionary, path: String) -> Error:
	if not is_valid(run):
		return ERR_INVALID_DATA
	return _save_text(path, JSON.stringify(run, "\t") + "\n")


static func load_runs(directory: String) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var absolute := ProjectSettings.globalize_path(directory)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return runs
	var files: Array[String] = []
	for file_name in dir.get_files():
		if file_name.to_lower().ends_with(".json"):
			files.append(file_name)
	files.sort()
	for file_name in files:
		var file := FileAccess.open(directory.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and is_valid(parsed):
			runs.append(parsed)
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.created_at) > str(b.created_at))
	return runs


static func save_data_script(runs: Array, path: String) -> Error:
	var valid_runs: Array = []
	for run in runs:
		if run is Dictionary and is_valid(run):
			valid_runs.append(run.duplicate(true))
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"runs": valid_runs,
	}
	return _save_text(path, "window.QA_DASHBOARD_DATA = %s;\n" % JSON.stringify(payload, "\t"))


static func _resolve_status(metadata: Dictionary, counts: Dictionary, regression: Dictionary) -> String:
	if int(counts.fail) > 0 or int(regression.get("failed", 0)) > 0:
		return "FAIL"
	var requested := str(metadata.get("status", ""))
	if int(counts.blocked) > 0 or requested == "BLOCKED":
		return "BLOCKED"
	if int(counts.candidate) > 0 or int(counts.signal) > 0:
		return "REVIEW"
	if STATUSES.has(requested):
		return requested
	return "PASS"


static func _role_summaries(summary: Dictionary) -> Array:
	var roles: Array = []
	for report in summary.get("source_reports", []):
		if not report is Dictionary:
			continue
		var role_counts := {"PASS": 0, "FAIL": 0, "SIGNAL": 0, "INFRA": 0, "BLOCKED": 0}
		for finding in report.get("findings", []):
			if finding is Dictionary:
				var classification := str(finding.get("classification", ""))
				if role_counts.has(classification):
					role_counts[classification] += 1
		roles.append({
			"role": str(report.get("role", "unknown")),
			"completed_at": str(report.get("completed_at", "")),
			"counts": role_counts,
		})
	return roles


static func _flatten_findings(summary: Dictionary) -> Array:
	var findings: Array = []
	for classification in CLASSIFICATION_SOURCES:
		var source_key: String = CLASSIFICATION_SOURCES[classification]
		for entry in summary.get(source_key, []):
			if not entry is Dictionary:
				continue
			var sources := _finding_sources(entry)
			var primary: Dictionary = sources[0] if not sources.is_empty() else entry
			var roles: Array[String] = []
			for source in sources:
				var role := str(source.get("role", ""))
				if not role.is_empty() and not roles.has(role):
					roles.append(role)
			var category := str(primary.get("category", "general"))
			findings.append({
				"key": str(entry.get("finding_key", primary.get("finding_key", "unknown"))),
				"classification": classification,
				"severity": str(entry.get("severity", primary.get("severity", "none"))),
				"category": category,
				"issue_type": str(entry.get("issue_type", primary.get("issue_type", _default_issue_type(classification, category)))),
				"observation": str(primary.get("observation", "")),
				"roles": roles,
				"artifact_path": str(entry.get("artifact_path", primary.get("artifact_path", ""))),
				"expected": str(entry.get("expected", primary.get("expected", ""))),
				"actual": str(entry.get("actual", primary.get("actual", ""))),
				"reproduction_steps": entry.get("reproduction_steps", primary.get("reproduction_steps", [])).duplicate(true),
				"reproduction": entry.get("reproduction", primary.get("reproduction", {})).duplicate(true),
				"defect_fingerprint": str(entry.get("defect_fingerprint", primary.get("defect_fingerprint", ""))),
				"confirmation_state": str(entry.get("confirmation_state", primary.get("confirmation_state", ""))),
				"confidence": str(entry.get("confidence", primary.get("confidence", "observation"))),
			})
	return findings


static func _default_issue_type(classification: String, category: String) -> String:
	if classification in ["FAIL", "CANDIDATE", "SEEDED"]:
		return "functional_bug"
	if classification == "INFRA":
		return "infrastructure"
	if classification == "PASS":
		return "pass"
	if category == "ui":
		return "ux_issue"
	if category == "balance":
		return "balance_risk"
	return "fun_issue"


static func _finding_sources(entry: Dictionary) -> Array:
	for field in ["supporting_findings", "findings"]:
		var value = entry.get(field, null)
		if value is Array and not value.is_empty():
			return value
	return [entry]


static func _save_text(path: String, content: String) -> Error:
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	return OK
