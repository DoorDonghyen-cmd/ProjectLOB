class_name QATeamIntegrator
extends RefCounted

const ReportScript := preload("res://scripts/qa/qa_team_report.gd")
const PacketScript := preload("res://scripts/qa/qa_role_packet.gd")


static func integrate(reports: Array) -> Dictionary:
	var errors: Array[String] = []
	var by_role: Dictionary = {}
	for i in range(reports.size()):
		var report = reports[i]
		if not report is Dictionary:
			errors.append("reports[%d]가 객체가 아님" % i)
			continue
		for error in ReportScript.validation_errors(report):
			errors.append("%s: %s" % [str(report.get("role", i)), error])
		var role := str(report.get("role", ""))
		if by_role.has(role):
			errors.append("중복 역할 보고: %s" % role)
		by_role[role] = report
	for role in PacketScript.ROLES:
		if not by_role.has(role):
			errors.append("누락 역할 보고: %s" % role)
	if errors.is_empty():
		_validate_same_session(by_role, errors)

	var result := {
		"schema_version": 1,
		"ready": errors.is_empty(),
		"errors": errors,
		"confirmed_bugs": [],
		"candidate_bugs": [],
		"seeded_detections": [],
		"experience_signals": [],
		"passes": [],
		"infrastructure": [],
		"blocked": [],
		"conflicts": [],
		"source_reports": reports.duplicate(true),
		"integrated_at": Time.get_datetime_string_from_system(false, true),
	}
	if not errors.is_empty():
		return result

	var grouped: Dictionary = {}
	for role in PacketScript.ROLES:
		for finding in by_role[role].findings:
			var key := _group_key(finding)
			if not grouped.has(key):
				grouped[key] = []
			var copy: Dictionary = finding.duplicate(true)
			copy["role"] = role
			grouped[key].append(copy)

	for finding_key in grouped:
		var findings: Array = grouped[finding_key]
		var logical_key := str(findings[0].get("finding_key", finding_key)) if not findings.is_empty() else str(finding_key)
		var classifications: Array[String] = []
		for finding in findings:
			classifications.append(str(finding.classification))
		if classifications.has("FAIL") and classifications.has("PASS"):
			result.conflicts.append({"finding_key": logical_key, "findings": findings.duplicate(true)})
			continue
		var confirmed := _confirmed_bug(findings)
		if not confirmed.is_empty():
			result.confirmed_bugs.append(confirmed)
			continue
		var seeded := _seeded_detection(findings)
		if not seeded.is_empty():
			result.seeded_detections.append(seeded)
			continue
		var candidate := _candidate_bug(findings)
		if not candidate.is_empty():
			result.candidate_bugs.append(candidate)
			continue
		if classifications.has("INFRA"):
			result.infrastructure.append({"finding_key": logical_key, "findings": findings.duplicate(true)})
		elif classifications.has("BLOCKED"):
			result.blocked.append({"finding_key": logical_key, "findings": findings.duplicate(true)})
		elif classifications.has("SIGNAL"):
			result.experience_signals.append({
				"finding_key": logical_key,
				"classification": "strong_signal" if _role_count(findings) >= 2 else "hypothesis",
				"findings": findings.duplicate(true),
			})
		elif classifications.has("PASS"):
			result.passes.append({"finding_key": logical_key, "findings": findings.duplicate(true)})
	return result


static func save(summary: Dictionary, path: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(summary, "\t") + "\n")
	return OK


static func _validate_same_session(by_role: Dictionary, errors: Array[String]) -> void:
	var baseline: Dictionary = by_role[PacketScript.ROLES[0]]
	for role in PacketScript.ROLES.slice(1):
		var report: Dictionary = by_role[role]
		for field in ["session_id", "commit", "scenario_id", "gameplay_seed"]:
			if report.get(field) != baseline.get(field):
				errors.append("역할 보고 %s 불일치: %s" % [field, role])


static func _confirmed_bug(findings: Array) -> Dictionary:
	for finding in findings:
		var reproduction: Dictionary = finding.get("reproduction", {})
		if str(finding.classification) == "FAIL" \
				and str(finding.role) in ["functional_qa", "combat_simulator"] \
				and str(finding.get("origin", "")) == "product_runtime" \
				and bool(finding.get("registration_eligible", false)) \
				and int(reproduction.get("attempts", 0)) >= 2 \
				and int(reproduction.get("reproduced", 0)) >= 2 \
				and not str(finding.get("defect_fingerprint", "")).is_empty():
			return {
				"finding_key": str(finding.finding_key),
				"severity": str(finding.severity),
				"primary_role": str(finding.role),
				"expected": str(finding.expected),
				"actual": str(finding.actual),
				"reproduction_steps": finding.reproduction_steps.duplicate(true),
				"artifact_path": str(finding.artifact_path),
				"issue_type": str(finding.get("issue_type", "functional_bug")),
				"origin": "product_runtime",
				"confidence": "confirmed",
				"reproduction": reproduction.duplicate(true),
				"defect_fingerprint": str(finding.get("defect_fingerprint", "")),
				"confirmation_state": "confirmed",
				"supporting_findings": findings.duplicate(true),
			}
	return {}


static func _candidate_bug(findings: Array) -> Dictionary:
	for finding in findings:
		if str(finding.get("classification", "")) == "FAIL" \
				and str(finding.get("origin", "")) == "product_runtime":
			return {
				"finding_key": str(finding.get("finding_key", "")),
				"severity": str(finding.get("severity", "moderate")),
				"issue_type": str(finding.get("issue_type", "functional_bug")),
				"observation": str(finding.get("observation", "")),
				"artifact_path": str(finding.get("artifact_path", "")),
				"confirmation_state": "candidate",
				"supporting_findings": findings.duplicate(true),
			}
	return {}


static func _seeded_detection(findings: Array) -> Dictionary:
	for finding in findings:
		if str(finding.get("classification", "")) == "FAIL" \
				and str(finding.get("origin", "")) in ["seeded_fixture", "synthetic"]:
			return {
				"finding_key": str(finding.get("finding_key", "")),
				"severity": str(finding.get("severity", "moderate")),
				"issue_type": str(finding.get("issue_type", "functional_bug")),
				"observation": str(finding.get("observation", "")),
				"origin": str(finding.get("origin", "seeded_fixture")),
				"artifact_path": str(finding.get("artifact_path", "")),
				"confirmation_state": "test_detection",
				"supporting_findings": findings.duplicate(true),
			}
	return {}


static func _group_key(finding: Dictionary) -> String:
	var fingerprint := str(finding.get("defect_fingerprint", "")).strip_edges()
	return "fingerprint:%s" % fingerprint if not fingerprint.is_empty() else "key:%s" % str(finding.get("finding_key", ""))


static func _role_count(findings: Array) -> int:
	var roles: Dictionary = {}
	for finding in findings:
		roles[str(finding.role)] = true
	return roles.size()
