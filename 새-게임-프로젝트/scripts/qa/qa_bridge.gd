class_name QABridge
extends RefCounted

const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const ExecutorScript := preload("res://scripts/qa/qa_action_executor.gd")
const StateSerializerScript := preload("res://scripts/qa/qa_state_serializer.gd")

var manifest: Dictionary = {}
var output_directory: String = ""
var combat_manager: CombatManager
var executor = null
var step: int = 0
var last_result: Dictionary = {}
var active: bool = false


func configure(session_manifest: Dictionary, directory: String) -> Error:
	if not ManifestScript.is_valid(session_manifest):
		return ERR_INVALID_DATA
	if directory.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var global_directory := ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(global_directory)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	manifest = session_manifest.duplicate(true)
	output_directory = directory.trim_suffix("/")
	return _write_json("manifest.json", manifest)


func start_fixed_combat(
	gun: GunData,
	enemy_datas: Array[EnemyData],
	deck_bullets: Array[BulletData],
	parts: Array[PartData] = [],
	supply_bullet: BulletData = null
) -> Error:
	if manifest.is_empty() or output_directory.is_empty():
		return ERR_UNCONFIGURED
	if gun == null or enemy_datas.is_empty():
		return ERR_INVALID_PARAMETER
	if combat_manager != null:
		combat_manager.free()
	combat_manager = CombatManager.new()
	combat_manager.start_encounter(gun, enemy_datas, deck_bullets, parts, supply_bullet)
	executor = ExecutorScript.new(combat_manager)
	step = 0
	last_result = {"accepted": true, "action": "start_fixed_combat"}
	active = true
	return _write_current_state()


func submit_action(action: Dictionary) -> Dictionary:
	if not active or executor == null:
		return {"accepted": false, "error": "활성 QA 전투가 없음", "step": step}
	if int(action.get("step", -1)) != step:
		return {"accepted": false, "error": "단계 번호 불일치", "step": step}

	var submitted_step := step
	var write_error := _write_json("action_%04d.json" % submitted_step, action)
	if write_error != OK:
		return {"accepted": false, "error": "행동 파일 저장 실패", "code": write_error, "step": step}

	var result: Dictionary = executor.execute(action)
	result["submitted_step"] = submitted_step
	if not bool(result.get("accepted", false)):
		_write_json("result_%04d.json" % submitted_step, result)
		return result

	step += 1
	result["next_step"] = step
	last_result = result.duplicate(true)
	_write_json("result_%04d.json" % submitted_step, result)
	var state_error := _write_current_state()
	if state_error != OK:
		return {"accepted": false, "error": "다음 상태 저장 실패", "code": state_error, "step": step}
	return result


func state_bundle() -> Dictionary:
	if combat_manager == null or executor == null:
		return {}
	return {
		"schema_version": 1,
		"session_id": str(manifest.get("session_id", "")),
		"scenario_id": str(manifest.get("scenario_id", "")),
		"step": step,
		"player_view": StateSerializerScript.player_view(
			combat_manager,
			executor.pending_load,
			step,
			executor.legal_actions(),
			last_result
		),
		"oracle_state": StateSerializerScript.oracle_state(combat_manager, executor.pending_load, step),
	}


func close() -> void:
	active = false
	if combat_manager != null:
		combat_manager.free()
		combat_manager = null
	executor = null


func _write_current_state() -> Error:
	return _write_json("state_%04d.json" % step, state_bundle())


func _write_json(file_name: String, value: Variant) -> Error:
	if output_directory.is_empty():
		return ERR_UNCONFIGURED
	var path := "%s/%s" % [output_directory, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t") + "\n")
	return OK
