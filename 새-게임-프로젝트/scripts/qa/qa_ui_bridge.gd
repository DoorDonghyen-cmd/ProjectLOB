class_name QAUIBridge
extends RefCounted

const StateSerializerScript := preload("res://scripts/qa/qa_ui_state_serializer.gd")
const ActionExecutorScript := preload("res://scripts/qa/qa_ui_action_executor.gd")
const CaptureScript := preload("res://scripts/qa/qa_capture.gd")

var scene = null
var executor = null
var output_directory: String = ""
var step: int = 0
var last_result: Dictionary = {}


func configure(scene_root, directory: String, allow_fixtures: bool = false) -> Error:
	if scene_root == null or directory.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	scene = scene_root
	output_directory = directory.trim_suffix("/")
	executor = ActionExecutorScript.new(scene, allow_fixtures)
	step = 0
	last_result = {"accepted": true, "action": "configure"}
	return OK


func submit_action(action: Dictionary) -> Dictionary:
	if executor == null:
		return {"accepted": false, "error": "UI 브리지가 구성되지 않음", "step": step}
	if int(action.get("step", -1)) != step:
		return {"accepted": false, "error": "단계 번호 불일치", "step": step}
	var result: Dictionary = executor.execute(action)
	result["submitted_step"] = step
	if not bool(result.get("accepted", false)):
		return result
	step += 1
	result["next_step"] = step
	last_result = result.duplicate(true)
	return result


func state_bundle(checkpoint_id: String) -> Dictionary:
	if executor == null:
		return {}
	var state := StateSerializerScript.serialize(scene, checkpoint_id, executor.legal_actions())
	state["step"] = step
	state["last_result"] = last_result.duplicate(true)
	if str(state.get("screen", "")) == "combat":
		state["player_view"] = executor.combat_player_view(step, last_result)
	return state


func checkpoint(checkpoint_id: String, capture_requested: bool = true) -> Dictionary:
	var state := state_bundle(checkpoint_id)
	if state.is_empty():
		return {"accepted": false, "error": "UI 상태를 만들 수 없음"}

	var capture_result: Dictionary
	if capture_requested:
		capture_result = CaptureScript.capture(
			scene.get_viewport(), "%s/screenshots" % output_directory, checkpoint_id)
	else:
		capture_result = CaptureScript.unavailable("캡처 요청이 비활성화됨")
	state["capture"] = capture_result
	var file_name := "checkpoint_%04d_%s.json" % [step, _safe_file_name(checkpoint_id)]
	var error := _write_json(file_name, state)
	return {
		"accepted": error == OK,
		"error": "" if error == OK else "체크포인트 JSON 저장 실패: %d" % error,
		"state": state,
	}


func _write_json(file_name: String, value: Variant) -> Error:
	var path := "%s/%s" % [output_directory, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t") + "\n")
	return OK


func _safe_file_name(value: String) -> String:
	var safe := ""
	for character in value.to_lower():
		if character in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			safe += character
		else:
			safe += "_"
	return safe if not safe.is_empty() else "checkpoint"
