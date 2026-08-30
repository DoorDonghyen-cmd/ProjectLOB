class_name QASessionManifest
extends RefCounted

## QA 실행의 재현 단위를 정의한다. Git 조회나 사용자 경로 추론은 외부 실행기가 맡고,
## 게임은 전달받은 manifest가 완전한지만 검증한다.

const SCHEMA_VERSION := 2
const MODES := ["quick_smoke", "focused", "experience", "release_gate"]


static func create(
	session_id: String,
	commit_hash: String,
	mode: String,
	scenario_id: String,
	dirty_worktree: bool = false,
	gameplay_seed: int = 0
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": session_id.strip_edges(),
		"commit": commit_hash.strip_edges(),
		"dirty_worktree": dirty_worktree,
		"mode": mode,
		"scenario_id": scenario_id.strip_edges(),
		"gameplay_seed": gameplay_seed,
		"created_at": Time.get_datetime_string_from_system(false, true),
	}


static func validation_errors(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(manifest.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("지원하지 않는 QA manifest schema_version")
	if str(manifest.get("session_id", "")).strip_edges().is_empty():
		errors.append("session_id가 비어 있음")
	if str(manifest.get("commit", "")).strip_edges().is_empty():
		errors.append("commit이 비어 있음")
	if not MODES.has(str(manifest.get("mode", ""))):
		errors.append("알 수 없는 QA mode")
	if str(manifest.get("scenario_id", "")).strip_edges().is_empty():
		errors.append("scenario_id가 비어 있음")
	if int(manifest.get("gameplay_seed", -1)) < 0:
		errors.append("gameplay_seed는 0 이상이어야 함")
	return errors


static func is_valid(manifest: Dictionary) -> bool:
	return validation_errors(manifest).is_empty()
