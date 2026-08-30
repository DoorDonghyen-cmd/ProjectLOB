class_name QARolePacket
extends RefCounted

const SCHEMA_VERSION := 1
const ROLES := ["functional_qa", "experience_qa", "combat_simulator"]


static func create(
	manifest: Dictionary,
	role: String,
	artifact_paths: Array,
	instructions: Array[String]
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": str(manifest.get("session_id", "")),
		"commit": str(manifest.get("commit", "")),
		"dirty_worktree": bool(manifest.get("dirty_worktree", false)),
		"scenario_id": str(manifest.get("scenario_id", "")),
		"gameplay_seed": int(manifest.get("gameplay_seed", 0)),
		"role": role,
		"artifact_paths": artifact_paths.duplicate(true),
		"instructions": instructions.duplicate(),
		"shared_results_received": false,
		"created_at": Time.get_datetime_string_from_system(false, true),
	}


static func validation_errors(packet: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(packet.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("지원하지 않는 role packet schema_version")
	for field in ["session_id", "commit", "scenario_id"]:
		if str(packet.get(field, "")).strip_edges().is_empty():
			errors.append("%s가 비어 있음" % field)
	var role := str(packet.get("role", ""))
	if not ROLES.has(role):
		errors.append("알 수 없는 QA role")
	if bool(packet.get("shared_results_received", true)):
		errors.append("독립 실행 전에 다른 역할 결과가 공유됨")
	if packet.has("prior_conclusions") or packet.has("expected_findings"):
		errors.append("역할 패킷에 사전 결론이 포함됨")
	var artifacts = packet.get("artifact_paths", null)
	if not artifacts is Array or artifacts.is_empty():
		errors.append("원본 artifact 경로가 없음")
	elif role == "experience_qa":
		for path in artifacts:
			var lowered := str(path).to_lower().replace("\\", "/")
			if _experience_forbidden(lowered):
				errors.append("경험 QA 패킷에 비공개 artifact가 포함됨: %s" % path)
	var instructions = packet.get("instructions", null)
	if not instructions is Array or instructions.is_empty():
		errors.append("역할 실행 지침이 없음")
	return errors


static func is_valid(packet: Dictionary) -> bool:
	return validation_errors(packet).is_empty()


static func save(packet: Dictionary, path: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(packet, "\t") + "\n")
	return OK


static func _experience_forbidden(path: String) -> bool:
	return path.contains("oracle") \
		or path.contains("raw_logs") \
		or path.contains("playtest_run_") \
		or path.contains("/scripts/") \
		or path.contains("/tests/") \
		or path.ends_with(".gd") \
		or path.ends_with(".tres")
