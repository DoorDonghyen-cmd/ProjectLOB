class_name PlaytestLogger
extends RefCounted

## 플레이테스트 런을 로컬 JSON으로 남긴다.
## 게임 세이브와 분리해 초기화·손상이 진행 데이터에 영향을 주지 않는다.

const SCHEMA_VERSION := 3
const DEFAULT_LOG_DIR := "user://playtest_logs"

## 헤드리스 테스트가 실제 사용자 로그 폴더를 오염시키지 않게 한다.
static var enabled: bool = true
static var log_dir_override: String = ""

var report: Dictionary = {}
var current_file_path: String = ""


static func log_directory() -> String:
	return log_dir_override if not log_dir_override.is_empty() else DEFAULT_LOG_DIR


static func global_log_directory() -> String:
	return ProjectSettings.globalize_path(log_directory())


static func resource_id(resource: Resource) -> String:
	if resource == null:
		return ""
	if not resource.resource_path.is_empty():
		return resource.resource_path.get_file().get_basename()
	var display = resource.get("display_name")
	if display != null and not str(display).is_empty():
		return str(display)
	return "runtime_resource"


static func resource_snapshot(resource: Resource) -> Dictionary:
	if resource == null:
		return {}
	var result := {
		"id": resource_id(resource),
		"resource_path": resource.resource_path,
	}
	var display = resource.get("display_name")
	if display != null:
		result["display_name"] = str(display)
	if resource is PartData:
		result["part_id"] = int(resource.part_id)
	if resource is GunData or resource is BulletData:
		result["weapon_class"] = int(resource.weapon_class)
	if resource is BulletData:
		result["role"] = resource.role
		result["specialty"] = resource.specialty
	return result


static func open_log_directory() -> Error:
	var error := _ensure_log_directory()
	if error != OK:
		return error
	return OS.shell_open(global_log_directory())


func begin_run(run_context: Dictionary) -> Error:
	if not enabled:
		return OK
	var error := _ensure_log_directory()
	if error != OK:
		return error
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var suffix := str(Time.get_ticks_msec())
	var run_id := "%s_%s" % [stamp, suffix]
	current_file_path = "%s/playtest_run_%s.json" % [log_directory(), run_id]
	report = {
		"schema_version": SCHEMA_VERSION,
		"run_id": run_id,
		"session_id": str(run_context.get("qa_session_id", "")),
		"gameplay_seed": int(run_context.get("gameplay_seed", 0)),
		"started_at": Time.get_datetime_string_from_system(false, true),
		"updated_at": Time.get_datetime_string_from_system(false, true),
		"result": "in_progress",
		"run_start": run_context.duplicate(true),
		"events": [],
		"encounters": [],
		"run_end": {},
	}
	return _flush()


## 전투 밖의 의사결정(상점 진열·리롤·구매 등)을 런 타임라인에 기록한다.
func append_event(event_type: String, context: Dictionary, details: Dictionary) -> Error:
	if not enabled:
		return OK
	if report.is_empty():
		var error := begin_run(context)
		if error != OK:
			return error
	if not report.has("events"):
		report["events"] = []
	report.events.append({
		"type": event_type,
		"at": Time.get_datetime_string_from_system(false, true),
		"context": context.duplicate(true),
		"details": details.duplicate(true),
	})
	report.updated_at = Time.get_datetime_string_from_system(false, true)
	return _flush()


func append_encounter(context: Dictionary, encounter_report: Dictionary) -> Error:
	if not enabled:
		return OK
	if report.is_empty():
		var error := begin_run(context)
		if error != OK:
			return error
	var entry := encounter_report.duplicate(true)
	entry["context"] = context.duplicate(true)
	report.encounters.append(entry)
	report.updated_at = Time.get_datetime_string_from_system(false, true)
	return _flush()


func finish_run(result: String, run_context: Dictionary) -> Error:
	if not enabled or report.is_empty():
		return OK
	report.result = result
	report.updated_at = Time.get_datetime_string_from_system(false, true)
	report.run_end = run_context.duplicate(true)
	return _flush()


func latest_file_path() -> String:
	return current_file_path


static func _ensure_log_directory() -> Error:
	var global_path := global_log_directory()
	if DirAccess.dir_exists_absolute(global_path):
		return OK
	return DirAccess.make_dir_recursive_absolute(global_path)


func _flush() -> Error:
	if current_file_path.is_empty():
		return ERR_INVALID_PARAMETER
	var file := FileAccess.open(current_file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(report, "\t") + "\n")
	return OK
