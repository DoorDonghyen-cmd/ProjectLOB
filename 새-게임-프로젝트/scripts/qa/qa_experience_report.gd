class_name QAExperienceReport
extends RefCounted

const SCHEMA_VERSION := 1
const PROFILES := ["beginner", "aggressive", "conservative", "experimental"]
const FUN_AXES := ["understanding", "choice", "order", "pressure", "pacing", "feedback", "diversity"]
const ISSUE_TYPES := ["possible_functional_anomaly", "ux_issue", "fun_issue", "balance_risk", "improvement"]
const MISMATCH_CLASSES := ["information_gap", "wording_misread", "possible_functional_anomaly"]
const MAJOR_DECISIONS := [
	"load", "fire", "choose_route", "choose_reward", "buy", "reroll_shop",
	"use_maintenance",
]


static func create(manifest: Dictionary, profile: String, start_condition: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": str(manifest.get("session_id", "")),
		"commit": str(manifest.get("commit", "")),
		"dirty_worktree": bool(manifest.get("dirty_worktree", false)),
		"scenario_id": str(manifest.get("scenario_id", "")),
		"gameplay_seed": int(manifest.get("gameplay_seed", 0)),
		"profile": profile,
		"start_condition": start_condition.duplicate(true),
		"actions": [],
		"observations": [],
		"issue_candidates": [],
		"session_summary": {
			"result": "in_progress",
			"completed_encounters": 0,
			"abandonment_events": [],
			"human_confirmation": ["impact_feel", "audio_feel", "animation_pacing", "long_session_fatigue"],
		},
		"created_at": Time.get_datetime_string_from_system(false, true),
	}


static func record_action(
	report: Dictionary,
	state_bundle: Dictionary,
	action: Dictionary,
	result: Dictionary,
	expected: String,
	reason: String,
	alternatives: Array = [],
	category: String = "",
	choice_id: String = "",
	tags: Array = [],
	outcome: Dictionary = {}
) -> Error:
	if not report.get("actions", []) is Array:
		return ERR_INVALID_DATA
	var player_view: Dictionary = state_bundle.get("player_view", state_bundle).duplicate(true)
	var resolved_choice := choice_id if not choice_id.is_empty() else _choice_id(action)
	var resolved_category := category if not category.is_empty() else _category(str(action.get("action", "")))
	var record := {
		"step": int(state_bundle.get("step", player_view.get("step", -1))),
		"screen": str(player_view.get("screen", "unknown")),
		"action": str(action.get("action", "")),
		"choice_id": resolved_choice,
		"category": resolved_category,
		"expected": expected.strip_edges(),
		"reason": reason.strip_edges(),
		"alternatives": alternatives.duplicate(true),
		"accepted": bool(result.get("accepted", false)),
		"player_view": player_view,
		"result": result.duplicate(true),
		"tags": tags.duplicate(true),
		"outcome": outcome.duplicate(true),
	}
	report["actions"].append(record)
	return OK


static func add_observation(
	report: Dictionary,
	signal_key: String,
	axis: String,
	observation: String,
	evidence_steps: Array,
	confidence: String = "observation"
) -> Error:
	if not report.get("observations", []) is Array:
		return ERR_INVALID_DATA
	report["observations"].append({
		"signal_key": signal_key.strip_edges(),
		"axis": axis.strip_edges(),
		"observation": observation.strip_edges(),
		"evidence_steps": evidence_steps.duplicate(true),
		"confidence": confidence,
	})
	return OK


static func add_issue_candidate(
	report: Dictionary,
	issue_key: String,
	issue_type: String,
	observation: String,
	expected: String,
	actual: String,
	evidence_steps: Array,
	reproduction_steps: Array,
	mismatch_class: String = "possible_functional_anomaly",
	severity: String = "moderate",
	artifact_path: String = ""
) -> Error:
	if not report.get("issue_candidates", null) is Array:
		return ERR_INVALID_DATA
	report.issue_candidates.append({
		"issue_key": issue_key.strip_edges(),
		"issue_type": issue_type,
		"mismatch_class": mismatch_class,
		"severity": severity,
		"observation": observation.strip_edges(),
		"expected": expected.strip_edges(),
		"actual": actual.strip_edges(),
		"evidence_steps": evidence_steps.duplicate(true),
		"reproduction_steps": reproduction_steps.duplicate(true),
		"artifact_path": artifact_path.strip_edges(),
	})
	return OK


static func finish(report: Dictionary, result: String, completed_encounters: int, abandonment_events: Array = []) -> void:
	report["session_summary"] = {
		"result": result,
		"completed_encounters": completed_encounters,
		"abandonment_events": abandonment_events.duplicate(true),
		"human_confirmation": ["impact_feel", "audio_feel", "animation_pacing", "long_session_fatigue"],
	}


static func validation_errors(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(report.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("지원하지 않는 경험 리포트 schema_version")
	if str(report.get("session_id", "")).strip_edges().is_empty():
		errors.append("session_id가 비어 있음")
	if str(report.get("commit", "")).strip_edges().is_empty():
		errors.append("commit이 비어 있음")
	if str(report.get("scenario_id", "")).strip_edges().is_empty():
		errors.append("scenario_id가 비어 있음")
	if not PROFILES.has(str(report.get("profile", ""))):
		errors.append("알 수 없는 플레이 프로필")
	if not report.get("start_condition", null) is Dictionary:
		errors.append("시작 조건이 없음")
	if _contains_forbidden_key(report, "oracle_state"):
		errors.append("블랙박스 리포트에 oracle_state가 포함됨")

	var actions = report.get("actions", null)
	if not actions is Array:
		errors.append("actions가 배열이 아님")
	else:
		var previous_step := -1
		for i in range(actions.size()):
			var record = actions[i]
			if not record is Dictionary:
				errors.append("actions[%d]가 객체가 아님" % i)
				continue
			var step := int(record.get("step", -1))
			if step < previous_step:
				errors.append("actions[%d] 단계가 역행함" % i)
			previous_step = step
			var action_name := str(record.get("action", ""))
			if action_name.is_empty():
				errors.append("actions[%d] action이 비어 있음" % i)
			if not record.has("accepted"):
				errors.append("actions[%d] accepted가 없음" % i)
			if not record.get("player_view", null) is Dictionary:
				errors.append("actions[%d] player_view가 없음" % i)
			if bool(record.get("accepted", false)) and MAJOR_DECISIONS.has(action_name):
				if str(record.get("expected", "")).strip_edges().is_empty():
					errors.append("actions[%d] 예상 결과가 없음" % i)
				if str(record.get("reason", "")).strip_edges().is_empty():
					errors.append("actions[%d] 선택 이유가 없음" % i)
			if not record.get("alternatives", []) is Array:
				errors.append("actions[%d] alternatives가 배열이 아님" % i)

	var observations = report.get("observations", null)
	if not observations is Array:
		errors.append("observations가 배열이 아님")
	else:
		for i in range(observations.size()):
			var observation = observations[i]
			if not observation is Dictionary:
				errors.append("observations[%d]가 객체가 아님" % i)
				continue
			if str(observation.get("signal_key", "")).strip_edges().is_empty():
				errors.append("observations[%d] signal_key가 비어 있음" % i)
			if not ["observation", "repeat_signal", "strong_signal", "human_confirmation"].has(
					str(observation.get("confidence", ""))):
				errors.append("observations[%d] confidence가 잘못됨" % i)
			if not FUN_AXES.has(str(observation.get("axis", ""))):
				errors.append("observations[%d] 재미 축이 잘못됨" % i)

	var candidates = report.get("issue_candidates", null)
	if not candidates is Array:
		errors.append("issue_candidates가 배열이 아님")
	else:
		for i in range(candidates.size()):
			var candidate = candidates[i]
			if not candidate is Dictionary:
				errors.append("issue_candidates[%d]가 객체가 아님" % i)
				continue
			if str(candidate.get("issue_key", "")).strip_edges().is_empty():
				errors.append("issue_candidates[%d] issue_key가 비어 있음" % i)
			if not ISSUE_TYPES.has(str(candidate.get("issue_type", ""))):
				errors.append("issue_candidates[%d] issue_type이 잘못됨" % i)
			if not MISMATCH_CLASSES.has(str(candidate.get("mismatch_class", ""))):
				errors.append("issue_candidates[%d] mismatch_class가 잘못됨" % i)
			for field in ["observation", "expected", "actual"]:
				if str(candidate.get(field, "")).strip_edges().is_empty():
					errors.append("issue_candidates[%d] %s가 비어 있음" % [i, field])
			if not candidate.get("evidence_steps", null) is Array or candidate.evidence_steps.is_empty():
				errors.append("issue_candidates[%d] 증거 단계가 없음" % i)
			if not candidate.get("reproduction_steps", null) is Array or candidate.reproduction_steps.is_empty():
				errors.append("issue_candidates[%d] 재현 단계가 없음" % i)

	if not report.get("session_summary", null) is Dictionary:
		errors.append("session_summary가 객체가 아님")
	return errors


static func is_valid(report: Dictionary) -> bool:
	return validation_errors(report).is_empty()


static func action_signature(report: Dictionary) -> Array[String]:
	var signature: Array[String] = []
	for record in report.get("actions", []):
		if record is Dictionary:
			signature.append("%s|%s|%s" % [
				str(record.get("action", "")),
				str(record.get("choice_id", "")),
				str(bool(record.get("accepted", false))),
			])
	return signature


static func save(report: Dictionary, path: String) -> Error:
	var directory := path.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(report, "\t") + "\n")
	return OK


static func _choice_id(action: Dictionary) -> String:
	for key in ["choice_id", "bullet_id", "node_id", "choice", "offer_slot", "target_slot"]:
		if action.has(key):
			return str(action[key])
	return str(action.get("action", ""))


static func _category(action_name: String) -> String:
	match action_name:
		"load": return "ammo"
		"fire", "reload", "eject", "confirm_load": return "combat"
		"choose_route": return "route"
		"choose_reward": return "reward"
		"buy", "reroll_shop": return "shop"
		"use_maintenance": return "maintenance"
	return "flow"


static func _contains_forbidden_key(value: Variant, forbidden: String) -> bool:
	if value is Dictionary:
		if value.has(forbidden):
			return true
		for child in value.values():
			if _contains_forbidden_key(child, forbidden):
				return true
	elif value is Array:
		for child in value:
			if _contains_forbidden_key(child, forbidden):
				return true
	return false
