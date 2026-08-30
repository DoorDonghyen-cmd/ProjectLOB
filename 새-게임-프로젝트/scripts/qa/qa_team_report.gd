class_name QATeamReport
extends RefCounted

const SCHEMA_VERSION := 1
const CLASSIFICATIONS := ["PASS", "FAIL", "INFRA", "SIGNAL", "BLOCKED"]
const SEVERITIES := ["none", "low", "moderate", "high"]
const ISSUE_TYPES := ["functional_bug", "ux_issue", "fun_issue", "balance_risk", "improvement", "pass", "infrastructure"]
const ORIGINS := ["product_runtime", "seeded_fixture", "synthetic", "infra"]
const CONFIDENCE_STATES := ["observation", "repeated_signal", "strong_signal", "human_confirmation", "confirmed"]
const PacketScript := preload("res://scripts/qa/qa_role_packet.gd")


static func create(packet: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": str(packet.get("session_id", "")),
		"commit": str(packet.get("commit", "")),
		"scenario_id": str(packet.get("scenario_id", "")),
		"gameplay_seed": int(packet.get("gameplay_seed", 0)),
		"role": str(packet.get("role", "")),
		"independent_context": true,
		"shared_results_received": false,
		"findings": [],
		"artifact_paths": packet.get("artifact_paths", []).duplicate(true),
		"completed_at": "",
	}


static func add_finding(
	report: Dictionary,
	finding_key: String,
	category: String,
	classification: String,
	severity: String,
	observation: String,
	evidence: Array,
	details: Dictionary = {}
) -> Error:
	if not report.get("findings", []) is Array:
		return ERR_INVALID_DATA
	var finding := {
		"finding_key": finding_key.strip_edges(),
		"category": category.strip_edges(),
		"classification": classification,
		"severity": severity,
		"observation": observation.strip_edges(),
		"evidence": evidence.duplicate(true),
		"issue_type": _default_issue_type(category, classification),
		"origin": "infra" if classification == "INFRA" else "product_runtime",
		"registration_eligible": classification == "FAIL",
		"confidence": "confirmed" if classification in ["PASS", "FAIL"] else "observation",
		"reproduction": {"attempts": 0, "reproduced": 0, "deterministic": false, "seeds": []},
		"defect_fingerprint": "",
		"confirmation_state": "candidate" if classification == "FAIL" else "not_applicable",
	}
	for key in details:
		finding[key] = details[key]
	report.findings.append(finding)
	return OK


static func complete(report: Dictionary) -> void:
	report["completed_at"] = Time.get_datetime_string_from_system(false, true)


static func validation_errors(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(report.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("지원하지 않는 team report schema_version")
	for field in ["session_id", "commit", "scenario_id", "role", "completed_at"]:
		if str(report.get(field, "")).strip_edges().is_empty():
			errors.append("%s가 비어 있음" % field)
	if not PacketScript.ROLES.has(str(report.get("role", ""))):
		errors.append("알 수 없는 보고 역할")
	if not bool(report.get("independent_context", false)):
		errors.append("독립 컨텍스트 실행이 아님")
	if bool(report.get("shared_results_received", true)):
		errors.append("원본 보고 완료 전 다른 역할 결과를 받음")
	var findings = report.get("findings", null)
	if not findings is Array:
		errors.append("findings가 배열이 아님")
		return errors
	for i in range(findings.size()):
		var finding = findings[i]
		if not finding is Dictionary:
			errors.append("findings[%d]가 객체가 아님" % i)
			continue
		if str(finding.get("finding_key", "")).strip_edges().is_empty():
			errors.append("findings[%d] finding_key가 비어 있음" % i)
		var classification := str(finding.get("classification", ""))
		if not CLASSIFICATIONS.has(classification):
			errors.append("findings[%d] classification이 잘못됨" % i)
		if not SEVERITIES.has(str(finding.get("severity", ""))):
			errors.append("findings[%d] severity가 잘못됨" % i)
		if not ISSUE_TYPES.has(str(finding.get("issue_type", ""))):
			errors.append("findings[%d] issue_type이 잘못됨" % i)
		if not ORIGINS.has(str(finding.get("origin", ""))):
			errors.append("findings[%d] origin이 잘못됨" % i)
		if not CONFIDENCE_STATES.has(str(finding.get("confidence", ""))):
			errors.append("findings[%d] confidence가 잘못됨" % i)
		if str(finding.get("observation", "")).strip_edges().is_empty():
			errors.append("findings[%d] observation이 비어 있음" % i)
		if not finding.get("evidence", null) is Array or finding.get("evidence", []).is_empty():
			errors.append("findings[%d] evidence가 없음" % i)
		if classification == "FAIL":
			if str(finding.get("severity", "none")) == "none":
				errors.append("findings[%d] FAIL severity가 none임" % i)
			for field in ["expected", "actual", "artifact_path"]:
				if str(finding.get(field, "")).strip_edges().is_empty():
					errors.append("findings[%d] FAIL의 %s가 없음" % [i, field])
			if not finding.get("reproduction_steps", null) is Array \
					or finding.get("reproduction_steps", []).is_empty():
				errors.append("findings[%d] FAIL 재현 단계가 없음" % i)
			var reproduction = finding.get("reproduction", null)
			if not reproduction is Dictionary:
				errors.append("findings[%d] FAIL reproduction이 없음" % i)
			elif int(reproduction.get("reproduced", 0)) > int(reproduction.get("attempts", 0)):
				errors.append("findings[%d] 재현 수가 시도 수보다 큼" % i)
			if str(finding.get("origin", "")) != "product_runtime" \
					and bool(finding.get("registration_eligible", false)):
				errors.append("findings[%d] fixture/synthetic 결함은 제품 등록 대상이 아님" % i)
		if str(report.get("role", "")) == "experience_qa" and classification == "FAIL":
			errors.append("경험 QA는 기능 결함을 FAIL로 확정할 수 없음")
		if str(report.get("role", "")) == "combat_simulator" \
				and str(finding.get("category", "")) == "ui" and classification == "FAIL":
			errors.append("전투 시뮬레이터는 UI 결함을 FAIL로 확정할 수 없음")
	return errors


static func _default_issue_type(category: String, classification: String) -> String:
	if classification == "PASS":
		return "pass"
	if classification == "INFRA":
		return "infrastructure"
	if classification == "FAIL":
		return "functional_bug"
	if category == "ui":
		return "ux_issue"
	if category == "balance":
		return "balance_risk"
	return "fun_issue"


static func is_valid(report: Dictionary) -> bool:
	return validation_errors(report).is_empty()


static func save(report: Dictionary, path: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(report, "\t") + "\n")
	return OK
