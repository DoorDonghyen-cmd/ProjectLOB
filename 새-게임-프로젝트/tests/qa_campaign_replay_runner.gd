extends SceneTree
## QA 전용 깨끗한 세이브에서 실제 UI 흐름으로 첫 두 계층을 재생한다.
## 전투 정산 자체는 Phase B가 담당하므로 이 실행기는 명시적 승리 fixture로 캠페인 흐름을 빠르게 통과한다.

const MAIN_SCENE := "res://scenes/combat/combat_scene.tscn"
const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const BridgeScript := preload("res://scripts/qa/qa_ui_bridge.gd")
const JournalScript := preload("res://scripts/qa/qa_run_journal.gd")
const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")

var _scene = null
var _bridge = null
var _journal = null
var _manifest: Dictionary = {}
var _output_directory: String = ""
var _seed: int = 424242
var _target_sections: int = 2
var _started: bool = false
var _failed: bool = false
var _actions: Array[Dictionary] = []
var _completed_nodes: Array[Dictionary] = []
var _shop_rerolled: Dictionary = {}
var _shop_bought: Dictionary = {}


func _initialize() -> void:
	_output_directory = OS.get_environment("QA_OUTPUT_DIR")
	if _output_directory.is_empty():
		_output_directory = "user://qa_runtime/campaign_replay"
	_seed = int(OS.get_environment("QA_GAMEPLAY_SEED")) \
		if not OS.get_environment("QA_GAMEPLAY_SEED").is_empty() else 424242
	_target_sections = clampi(int(OS.get_environment("QA_TARGET_SECTIONS")) \
		if not OS.get_environment("QA_TARGET_SECTIONS").is_empty() else 2, 1, 2)
	var session_id := OS.get_environment("QA_SESSION_ID")
	if session_id.is_empty():
		session_id = "qa-campaign-%d" % _seed
	_manifest = ManifestScript.create(
		session_id, OS.get_environment("QA_COMMIT") if not OS.get_environment("QA_COMMIT").is_empty() \
		else "working-tree", "focused", "campaign_%d_sections" % _target_sections, true, _seed)
	RunManager.save_path_override = "%s/meta_override.cfg" % _output_directory.trim_suffix("/")
	PlaytestLoggerScript.enabled = true
	PlaytestLoggerScript.log_dir_override = "%s/raw_logs" % _output_directory.trim_suffix("/")


func _process(_delta: float) -> bool:
	if not _started:
		return _start()
	if _failed:
		return _finish(1)

	var screen := str(_bridge.state_bundle("campaign").get("screen", "unknown"))
	match screen:
		"title":
			_act({"action": "open_section_selector"})
		"section_selector":
			_act({"action": "confirm_section"})
		"loadout":
			if _scene._loadout_overlay._bonus_popup.visible:
				_act({"action": "choose_starting_bonus", "choice": "credits"})
			_act({"action": "start_run"})
		"map":
			if RunManager.SECTION_ORDER.find(_scene._rm.current_section) >= _target_sections:
				return _finish(0)
			var node_id := _first_legal_node_id()
			if node_id < 0:
				return _abort("선택 가능한 지도 노드가 없음")
			_act({"action": "choose_route", "node_id": node_id})
		"combat":
			_act({"action": "present_victory_fixture"})
		"reward":
			_record_completed_node()
			_act({"action": "choose_reward", "choice": "credits"})
		"shop":
			var visit_key := _visit_key()
			if not _shop_rerolled.has(visit_key) and _has_legal_action("reroll_shop"):
				_shop_rerolled[visit_key] = true
				_act({"action": "reroll_shop"})
			elif not _shop_bought.has(visit_key):
				_shop_bought[visit_key] = true
				var buy_slot := _first_buy_slot()
				if buy_slot >= 0:
					_act({"action": "buy", "offer_slot": buy_slot})
				else:
					_record_completed_node()
					_act({"action": "use_maintenance"})
			else:
				_record_completed_node()
				_act({"action": "use_maintenance"})
		"maintenance":
			_record_completed_node()
			_act({"action": "use_maintenance"})
		"section_transition":
			_act({"action": "continue_section"})
		_:
			return _abort("지원하지 않는 캠페인 화면: %s" % screen)
	return false


func _start() -> bool:
	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		return _abort("메인 씬 로드 실패")
	_scene = packed.instantiate()
	root.add_child(_scene)
	_scene.configure_qa_run(_seed, str(_manifest.session_id))
	_bridge = BridgeScript.new()
	var bridge_error: Error = _bridge.configure(_scene, "%s/ui" % _output_directory, true)
	if bridge_error != OK:
		return _abort("UI 브리지 구성 실패: %d" % bridge_error)
	_journal = JournalScript.new()
	var journal_error: Error = _journal.configure(_manifest, _output_directory)
	if journal_error != OK:
		return _abort("진행 저널 구성 실패: %d" % journal_error)
	_started = true
	return false


func _act(action: Dictionary) -> void:
	action["step"] = _bridge.step
	var result: Dictionary = _bridge.submit_action(action)
	_actions.append({"action": action.duplicate(true), "result": result.duplicate(true)})
	if not bool(result.get("accepted", false)):
		_failed = true
		push_error("캠페인 행동 거절: %s" % str(result.get("error", "")))
		return
	var journal_error: Error = _journal.record(action, _progress())
	if journal_error != OK:
		_failed = true
		push_error("캠페인 진행 저널 저장 실패: %d" % journal_error)


func _first_legal_node_id() -> int:
	for action in _bridge.executor.legal_actions():
		if str(action.get("action", "")) == "choose_route":
			var ids: Array = action.get("node_ids", [])
			return int(ids[0]) if not ids.is_empty() else -1
	return -1


func _has_legal_action(action_type: String) -> bool:
	for action in _bridge.executor.legal_actions():
		if str(action.get("action", "")) == action_type:
			return true
	return false


func _first_buy_slot() -> int:
	for action in _bridge.executor.legal_actions():
		if str(action.get("action", "")) == "buy":
			var slots: Array = action.get("offer_slots", [])
			return int(slots[0]) if not slots.is_empty() else -1
	return -1


func _record_completed_node() -> void:
	if _scene._current_node == null:
		return
	var entry := {
		"section": _scene._rm.current_section,
		"floor": _scene._rm.current_floor,
		"node_id": _scene._current_node.id,
		"type": _scene._current_node.type_name,
	}
	if _completed_nodes.is_empty() or _completed_nodes[-1] != entry:
		_completed_nodes.append(entry)


func _visit_key() -> String:
	return "%s:%d" % [_scene._rm.current_section, _scene._rm.current_node_id]


func _progress() -> Dictionary:
	return {
		"section": _scene._rm.current_section,
		"floor": _scene._rm.current_floor,
		"node_id": _scene._rm.current_node_id,
		"screen": _bridge.state_bundle("journal").get("screen", "unknown"),
		"credits": _scene._rm.credits,
		"hp_buffer": _scene._rm.hp_buffer,
		"completed_nodes": _completed_nodes.duplicate(true),
	}


func _abort(message: String) -> bool:
	_failed = true
	push_error(message)
	return _finish(1)


func _finish(code: int) -> bool:
	if _scene != null and _scene._rm != null:
		_scene._rm.finish_playtest_log("qa_target_reached" if code == 0 else "qa_infrastructure_failed")
	var report := {
		"schema_version": 1,
		"manifest": _manifest,
		"result": "passed" if code == 0 else "failed",
		"target_sections": _target_sections,
		"actions": _actions,
		"progress": _progress() if _started else {},
	}
	var file := FileAccess.open("%s/replay_result.json" % _output_directory, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	RunManager.save_path_override = ""
	PlaytestLoggerScript.log_dir_override = ""
	print("[QA CAMPAIGN] result=%s actions=%d nodes=%d output=%s" % [
		report.result, _actions.size(), _completed_nodes.size(),
		ProjectSettings.globalize_path(_output_directory)])
	quit(code)
	return true
