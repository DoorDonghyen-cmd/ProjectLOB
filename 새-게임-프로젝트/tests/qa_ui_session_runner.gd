extends SceneTree
## 실제 combat_scene을 프레임별로 진행하며 UI 상태 JSON과 PNG 체크포인트를 남긴다.
## QA fixture는 전투 보상·상점 진입 시간을 줄일 뿐, 각 화면은 실제 오버레이와 콜백을 사용한다.

const MAIN_SCENE := "res://scenes/combat/combat_scene.tscn"
const BridgeScript := preload("res://scripts/qa/qa_ui_bridge.gd")
const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")

var _scene = null
var _bridge = null
var _phase: int = 0
var _output_directory: String = ""
var _failed: bool = false


func _initialize() -> void:
	_output_directory = OS.get_environment("QA_OUTPUT_DIR")
	if _output_directory.is_empty():
		_output_directory = "user://qa_runtime/ui_phase_c"
	RunManager.save_path_override = "%s/meta_override.cfg" % _output_directory.trim_suffix("/")
	PlaytestLoggerScript.enabled = false


func _process(_delta: float) -> bool:
	if _phase == 0:
		var packed: PackedScene = load(MAIN_SCENE)
		if packed == null:
			return _finish_with_error("메인 씬 로드 실패")
		_scene = packed.instantiate()
		root.add_child(_scene)
		_bridge = BridgeScript.new()
		var configure_error: Error = _bridge.configure(_scene, _output_directory, true)
		if configure_error != OK:
			return _finish_with_error("UI 브리지 구성 실패: %d" % configure_error)
		_phase += 1
		return false

	match _phase:
		1:
			_checkpoint("01_title")
			_act({"action": "open_section_selector"})
		2:
			_checkpoint("02_section_selector")
			_act({"action": "confirm_section"})
		3:
			_checkpoint("03_loadout")
			if _scene._loadout_overlay._bonus_popup.visible:
				_act({"action": "choose_starting_bonus", "choice": "credits"})
			_act({"action": "start_run"})
		4:
			_checkpoint("04_map")
			var node_id := _first_combat_node_id()
			if node_id < 0:
				return _finish_with_error("현재 층 전투 노드 없음")
			_act({"action": "choose_route", "node_id": node_id})
		5:
			_checkpoint("05_combat_loading")
			_act({"action": "present_victory_fixture"})
		6:
			_checkpoint("06_reward")
			_act({"action": "skip_reward"})
		7:
			_checkpoint("07_map_after_reward")
			_act({"action": "open_shop_fixture"})
		8:
			_checkpoint("08_shop_initial")
			_act({"action": "reroll_shop"})
		9:
			_checkpoint("09_shop_reroll")
			return _finish()
	_phase += 1
	return false


func _checkpoint(checkpoint_id: String) -> void:
	var result: Dictionary = _bridge.checkpoint(checkpoint_id, true)
	if not bool(result.get("accepted", false)):
		_failed = true
		push_error("QA UI 체크포인트 실패: %s" % str(result.get("error", "")))
		return
	var state: Dictionary = result.state
	var capture: Dictionary = state.capture
	if not bool(capture.get("captured", false)):
		print("[QA INFRA] %s PNG 생략: %s" % [checkpoint_id, str(capture.get("error", ""))])
	print("[QA UI] %s -> %s" % [checkpoint_id, str(state.screen)])


func _act(action: Dictionary) -> void:
	action["step"] = _bridge.step
	var result: Dictionary = _bridge.submit_action(action)
	if not bool(result.get("accepted", false)):
		_failed = true
		push_error("QA UI 행동 실패: %s" % str(result.get("error", "")))


func _first_combat_node_id() -> int:
	var ids: Array[int] = []
	for node_id in _scene._rm.map_nodes.keys():
		var id := int(node_id)
		if id / 100 != _scene._rm.current_floor or not _scene._rm.is_node_reachable(id):
			continue
		var node: RunManager.RunNode = _scene._rm.map_nodes[id]
		var resolved := node.hidden_type if node.type_name.begins_with("???") else node.type_name
		if resolved.contains("전투") or CampaignContent.is_major_gate_type(resolved):
			ids.append(id)
	ids.sort()
	return ids[0] if not ids.is_empty() else -1


func _finish_with_error(message: String) -> bool:
	_failed = true
	push_error(message)
	return _finish()


func _finish() -> bool:
	RunManager.save_path_override = ""
	PlaytestLoggerScript.enabled = true
	print("[QA UI] artifacts: %s" % ProjectSettings.globalize_path(_output_directory))
	quit(1 if _failed else 0)
	return true
