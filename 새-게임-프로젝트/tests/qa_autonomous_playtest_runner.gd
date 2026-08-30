extends SceneTree
## 실제 메인 씬과 CombatManager를 플레이어 공개 정보만으로 조작하는 프로필 실행기.
## 수치 최적해를 찾는 봇이 아니라 서로 다른 선택 성향의 행동 증거를 만드는 블랙박스 QA다.

const MAIN_SCENE := "res://scenes/combat/combat_scene.tscn"
const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const BridgeScript := preload("res://scripts/qa/qa_ui_bridge.gd")
const ReportScript := preload("res://scripts/qa/qa_experience_report.gd")
const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")

var _scene = null
var _bridge = null
var _report: Dictionary = {}
var _profile := "beginner"
var _output_directory := ""
var _report_directory := ""
var _seed := 424242
var _session_id := ""
var _commit_hash := "working-tree"
var _target_encounters := 3
var _max_actions := 240
var _started_at_msec := 0
var _last_screen := ""
var _completed_encounters := 0
var _encounter_active := false
var _reward_seen := false
var _shop_rerolled := false
var _used_choices: Dictionary = {}
var _issue_keys: Dictionary = {}
var _abandonment_events: Array = []
var _finished := false


func _initialize() -> void:
	_profile = OS.get_environment("QA_PROFILE")
	if not ReportScript.PROFILES.has(_profile):
		_profile = "beginner"
	_output_directory = OS.get_environment("QA_OUTPUT_DIR")
	if _output_directory.is_empty():
		_output_directory = "user://qa_runtime/autonomous/%s" % _profile
	_report_directory = OS.get_environment("QA_REPORT_DIR")
	if _report_directory.is_empty():
		_report_directory = "%s/reports" % _output_directory.trim_suffix("/")
	_seed = int(OS.get_environment("QA_GAMEPLAY_SEED")) \
		if not OS.get_environment("QA_GAMEPLAY_SEED").is_empty() else 424242
	_target_encounters = clampi(int(OS.get_environment("QA_TARGET_ENCOUNTERS")) \
		if not OS.get_environment("QA_TARGET_ENCOUNTERS").is_empty() else 3, 1, 12)
	_max_actions = clampi(int(OS.get_environment("QA_MAX_ACTIONS")) \
		if not OS.get_environment("QA_MAX_ACTIONS").is_empty() else 240, 40, 1000)
	RunManager.save_path_override = "%s/meta_override.cfg" % _output_directory.trim_suffix("/")
	PlaytestLoggerScript.enabled = true
	PlaytestLoggerScript.log_dir_override = "%s/raw_logs" % _output_directory.trim_suffix("/")
	_session_id = OS.get_environment("QA_SESSION_ID")
	if _session_id.is_empty():
		_session_id = "qa-autonomous-%s-%d" % [_profile, _seed]
	_commit_hash = OS.get_environment("QA_COMMIT")
	if _commit_hash.is_empty():
		_commit_hash = "working-tree"
	var manifest := ManifestScript.create(
		_session_id, _commit_hash, "experience", "autonomous_actual_play", true, _seed)
	_report = ReportScript.create(manifest, _profile, {
		"save_fixture": "clean_qa_save",
		"gun_id": "revolver",
		"section": "section_a",
		"target_encounters": _target_encounters,
		"tactical_ammo_ids": ["marker", "borer", "chain", "finale"],
	})
	_started_at_msec = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _finished:
		return false
	if _scene == null:
		return _start()
	if Time.get_ticks_msec() - _started_at_msec > 120000:
		return _abort("timeout", "120초 동안 목표 전투를 완료하지 못함")
	if _report.get("actions", []).size() >= _max_actions:
		return _abort("action_limit", "최대 행동 수 %d에 도달" % _max_actions)

	var state: Dictionary = _bridge.state_bundle("profile_%s" % _profile)
	var screen := str(state.get("screen", "unknown"))
	if screen != _last_screen:
		_bridge.checkpoint("%03d_%s" % [_bridge.step, screen], _capture_enabled())
		_last_screen = screen
		_reward_seen = false if screen != "reward" else _reward_seen
		if screen == "combat":
			_encounter_active = true
	_detect_public_issues(state)

	if screen == "combat" and state.get("legal_actions", []).is_empty():
		return false
	if screen == "reward" and not _reward_seen:
		_reward_seen = true
		if _encounter_active:
			_completed_encounters += 1
			_encounter_active = false
	if screen in ["debriefing", "combat_result"]:
		if _encounter_active:
			_completed_encounters += 1
			_encounter_active = false
		return _finish("run_ended", 0)
	if screen == "map" and _completed_encounters >= _target_encounters:
		return _finish("target_reached", 0)

	var action := _choose_action(state)
	if action.is_empty():
		return _abort("no_legal_action", "%s 화면에서 합법 행동을 선택할 수 없음" % screen)
	return _submit(state, action)


func _start() -> bool:
	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		return _abort("scene_load", "메인 씬 로드 실패")
	_scene = packed.instantiate()
	root.add_child(_scene)
	_scene.configure_qa_run(_seed, _session_id)
	_bridge = BridgeScript.new()
	var error: Error = _bridge.configure(_scene, "%s/ui" % _output_directory.trim_suffix("/"), false)
	if error != OK:
		return _abort("bridge_configure", "UI 브리지 구성 실패: %d" % error)
	return false


func _choose_action(state: Dictionary) -> Dictionary:
	var legal: Array = state.get("legal_actions", [])
	var screen := str(state.get("screen", "unknown"))
	match screen:
		"title": return _simple_action(legal, "open_section_selector")
		"section_selector": return _simple_action(legal, "confirm_section")
		"loadout":
			if _has_action(legal, "choose_starting_bonus"):
				return {"action": "choose_starting_bonus", "choice": "part" if _profile in ["aggressive", "experimental"] else "credits"}
			return _simple_action(legal, "start_run")
		"map": return _route_action(legal)
		"combat": return _combat_action(state.get("player_view", {}), legal)
		"reward": return _reward_action(legal)
		"shop": return _shop_action(state, legal)
		"maintenance": return _simple_action(legal, "use_maintenance")
		"section_transition": return _simple_action(legal, "continue_section")
	return {}


func _route_action(legal: Array) -> Dictionary:
	var entry := _action_entry(legal, "choose_route")
	var ids: Array = entry.get("node_ids", [])
	if ids.is_empty():
		return {}
	var index := 0
	match _profile:
		"aggressive": index = ids.size() - 1
		"conservative": index = mini(1, ids.size() - 1)
		"experimental": index = _completed_encounters % ids.size()
	return {"action": "choose_route", "node_id": int(ids[index])}


func _combat_action(player_view: Dictionary, legal: Array) -> Dictionary:
	if player_view.is_empty():
		return {}
	var load_entry := _action_entry(legal, "load")
	if not load_entry.is_empty():
		var pending: Array = player_view.get("pending_load_order", [])
		var capacity := int(player_view.get("magazine", {}).get("capacity", 0))
		if pending.size() < capacity:
			var bullet_id := _choose_bullet(player_view)
			if not bullet_id.is_empty():
				return {"action": "load", "bullet_id": bullet_id}
	if _has_action(legal, "confirm_load"):
		return {"action": "confirm_load"}
	if _has_action(legal, "fire"):
		return {"action": "fire"}
	if _has_action(legal, "reload"):
		return {"action": "reload"}
	if _has_action(legal, "unload") and _profile == "experimental":
		return {"action": "unload"}
	return {}


func _choose_bullet(player_view: Dictionary) -> String:
	var available: Array = player_view.get("available_ammo", [])
	if available.is_empty():
		return ""
	var target := _nearest_enemy(player_view.get("enemies", []))
	var pending: Array = player_view.get("pending_load_order", [])
	if _profile == "beginner":
		for entry in available:
			if bool(entry.get("bullet", {}).get("is_basic", false)):
				return str(entry.get("id", ""))
	# LIFO이므로 공격탄을 먼저 넣고 셋업탄을 나중에 넣으면 셋업→공격 순서로 발사된다.
	if pending.size() % 2 == 1:
		var setup_id := _matching_setup(available, pending[-1], target)
		if not setup_id.is_empty():
			return setup_id
	var ordered: Array = available.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _bullet_score(a, target) > _bullet_score(b, target))
	return str(ordered[0].get("id", ""))


func _bullet_score(entry: Dictionary, target: Dictionary) -> float:
	var bullet: Dictionary = entry.get("bullet", {})
	var choice_id := str(entry.get("id", ""))
	var novelty := 1000.0 if int(_used_choices.get(choice_id, 0)) == 0 else 0.0
	var hits := int(bullet.get("accuracy", 0)) >= int(target.get("evasion", 0))
	var penetrates := int(bullet.get("penetration", 0)) >= int(target.get("defense", 0))
	var effective := hits and penetrates
	match _profile:
		"aggressive": return (10000.0 if effective else 0.0) + float(bullet.get("damage", 0)) * 100.0
		"conservative": return (10000.0 if effective else 0.0) + float(bullet.get("accuracy", 0)) * 100.0 + float(bullet.get("penetration", 0)) * 10.0 + float(bullet.get("knockback", 0))
		"experimental": return (5000.0 if effective else 0.0) + novelty + (500.0 if not bool(bullet.get("is_basic", false)) else 0.0) + float(bullet.get("damage", 0)) * 10.0
	return 1000.0 if bool(bullet.get("is_basic", false)) else 100.0


func _matching_setup(available: Array, payoff: Dictionary, target: Dictionary) -> String:
	var need_acc := int(payoff.get("accuracy", 0)) < int(target.get("evasion", 0))
	var need_pen := int(payoff.get("penetration", 0)) < int(target.get("defense", 0))
	var preferred_effects: Array[int] = []
	if need_acc: preferred_effects.append(Enums.BulletEffect.BUFF_ACC)
	if need_pen: preferred_effects.append(Enums.BulletEffect.BUFF_PEN)
	if _profile in ["aggressive", "experimental"] and not need_acc and not need_pen:
		preferred_effects.append(Enums.BulletEffect.BUFF_DMG)
	for effect in preferred_effects:
		for entry in available:
			if int(entry.get("bullet", {}).get("effect_type", 0)) == effect:
				return str(entry.get("id", ""))
	return ""


func _nearest_enemy(enemies: Array) -> Dictionary:
	var nearest: Dictionary = {}
	for enemy in enemies:
		if not enemy is Dictionary or bool(enemy.get("is_dead", false)):
			continue
		if nearest.is_empty() or int(enemy.get("distance", 999)) < int(nearest.get("distance", 999)):
			nearest = enemy
	return nearest


func _reward_action(legal: Array) -> Dictionary:
	if not _has_action(legal, "choose_reward"):
		return _simple_action(legal, "skip_reward")
	var choice := "credits"
	if _profile == "aggressive":
		choice = "bullet"
	elif _profile == "experimental":
		choice = "bullet" if _completed_encounters % 2 == 1 else "credits"
	return {"action": "choose_reward", "choice": choice, "slot": _completed_encounters % 2}


func _shop_action(state: Dictionary, legal: Array) -> Dictionary:
	if _profile == "experimental" and not _shop_rerolled and _has_action(legal, "reroll_shop"):
		_shop_rerolled = true
		return {"action": "reroll_shop"}
	var buy := _action_entry(legal, "buy")
	var slots: Array = buy.get("offer_slots", [])
	if not slots.is_empty():
		var index := 0
		if _profile == "conservative": index = mini(1, slots.size() - 1)
		elif _profile == "experimental": index = slots.size() - 1
		return {"action": "buy", "offer_slot": int(slots[index])}
	_abandonment_events.append({
		"step": int(state.get("step", -1)), "screen": "shop", "abandonment_type": "shop_exit_without_purchase",
		"visible_trigger": "구매 가능한 제안 없음", "chosen_fallback": "use_maintenance",
		"reason": "현재 공개 가격과 보유 크레딧에서 구매 행동이 제공되지 않음",
	})
	return _simple_action(legal, "use_maintenance")


func _submit(state: Dictionary, action: Dictionary) -> bool:
	action["step"] = _bridge.step
	var expected := _expected_for(action, state)
	var reason := _reason_for(action, state)
	var alternatives := _alternatives(state.get("legal_actions", []), action)
	var result: Dictionary = _bridge.submit_action(action)
	var category := _category_for(str(action.get("action", "")))
	var choice_id := _choice_id(action)
	_used_choices[choice_id] = int(_used_choices.get(choice_id, 0)) + 1
	var tags: Array = []
	if str(action.get("action", "")) == "load":
		var selected := _ammo_entry(state.get("player_view", {}).get("available_ammo", []), str(action.get("bullet_id", "")))
		if not selected.is_empty() and not bool(selected.get("bullet", {}).get("is_basic", false)):
			tags.append("tactical_ammo")
		tags.append("planned_sequence")
	ReportScript.record_action(
		_report, state, action, result, expected, reason, alternatives, category, choice_id, tags)
	if not bool(result.get("accepted", false)):
		var artifact := "%s/ui/checkpoint_%04d_action_rejected.json" % [_output_directory, int(state.get("step", 0))]
		ReportScript.add_issue_candidate(
			_report, "legal_action_rejected_%s" % str(action.get("action", "")),
			"possible_functional_anomaly", "합법 행동 목록에서 선택한 행동이 거절됨",
			"공개 합법 행동은 승인되어야 함", str(result.get("error", "알 수 없는 거절")),
			[int(state.get("step", 0))], ["같은 공개 상태 진입", JSON.stringify(action), "거절 결과 확인"],
			"possible_functional_anomaly", "high", artifact)
		return _abort("legal_action_rejected", str(result.get("error", "행동 거절")))
	return false


func _detect_public_issues(state: Dictionary) -> void:
	if str(state.get("screen", "")) != "shop":
		return
	var integrity: Dictionary = state.get("shop", {}).get("render_integrity", {})
	if bool(integrity.get("valid", true)):
		return
	var issue_key := "shop_render_integrity"
	if _issue_keys.has(issue_key):
		return
	_issue_keys[issue_key] = true
	var artifact := "%s/ui/checkpoint_%04d_shop.json" % [_output_directory, int(state.get("step", 0))]
	ReportScript.add_issue_candidate(
		_report, issue_key, "possible_functional_anomaly",
		"상점 제안 데이터와 실제 렌더 카드가 일치하지 않음",
		"각 제안 슬롯의 제목·설명·개수가 현재 제안 데이터와 일치",
		JSON.stringify(integrity.get("mismatches", [])), [int(state.get("step", 0))],
		["상점 진입", "현재 제안과 렌더 텍스트 비교", "불일치 목록 확인"],
		"possible_functional_anomaly", "moderate", artifact)


func _finish(result: String, code: int) -> bool:
	if _finished:
		return true
	_finished = true
	ReportScript.add_observation(_report, "physical_feel_requires_human", "feedback",
		"타격감·사운드·애니메이션 속도와 장시간 피로는 자동 확정하지 않음", [], "human_confirmation")
	ReportScript.finish(_report, result, _completed_encounters, _abandonment_events)
	var save_error := ReportScript.save(_report, "%s/%s.json" % [_report_directory.trim_suffix("/"), _profile])
	if save_error != OK:
		code = 3
		push_error("경험 리포트 저장 실패: %d" % save_error)
	if _scene != null and _scene._rm != null:
		_scene._rm.finish_playtest_log(result)
	RunManager.save_path_override = ""
	PlaytestLoggerScript.log_dir_override = ""
	print("[QA AUTONOMOUS] profile=%s result=%s encounters=%d actions=%d output=%s" % [
		_profile, result, _completed_encounters, _report.get("actions", []).size(),
		ProjectSettings.globalize_path(_report_directory)])
	quit(code)
	return true


func _abort(kind: String, message: String) -> bool:
	_abandonment_events.append({
		"step": _bridge.step if _bridge != null else -1,
		"screen": _last_screen,
		"abandonment_type": kind,
		"visible_trigger": message,
		"chosen_fallback": "abort",
		"reason": "진행 가능한 공개 행동을 확인할 수 없음",
	})
	if not _report.is_empty():
		ReportScript.add_observation(_report, "play_blocked", "understanding", message,
			[_bridge.step if _bridge != null else -1])
	return _finish("blocked", 2)


func _simple_action(legal: Array, action_name: String) -> Dictionary:
	return {"action": action_name} if _has_action(legal, action_name) else {}


func _action_entry(legal: Array, action_name: String) -> Dictionary:
	for entry in legal:
		if entry is Dictionary and str(entry.get("action", "")) == action_name:
			return entry
	return {}


func _has_action(legal: Array, action_name: String) -> bool:
	return not _action_entry(legal, action_name).is_empty()


func _alternatives(legal: Array, chosen: Dictionary) -> Array:
	var result: Array = []
	for entry in legal:
		if not entry is Dictionary or str(entry.get("action", "")) == str(chosen.get("action", "")):
			continue
		result.append({
			"choice_id": str(entry.get("action", "")),
			"reason_not_chosen": "현재 %s 프로필 우선순위보다 낮음" % _profile,
		})
	return result


func _expected_for(action: Dictionary, state: Dictionary) -> String:
	match str(action.get("action", "")):
		"load":
			var entry := _ammo_entry(state.get("player_view", {}).get("available_ammo", []), str(action.get("bullet_id", "")))
			var bullet: Dictionary = entry.get("bullet", {})
			return "%s(DMG %d/ACC %d/PEN %d)를 LIFO 계획에 추가" % [
				str(entry.get("display_name", action.get("bullet_id", "탄환"))), int(bullet.get("damage", 0)),
				int(bullet.get("accuracy", 0)), int(bullet.get("penetration", 0))]
		"confirm_load": return "보이는 LIFO 순서로 탄창이 확정됨"
		"fire": return "가장 가까운 위협에 현재 탄환 효과가 적용됨"
		"reload": return "공개된 재장전 비용만큼 적이 전진한 뒤 다시 장전 가능"
		"choose_route": return "선택한 경로의 다음 노드로 진입"
		"choose_reward": return "선택한 보상이 현재 런에 반영됨"
		"buy": return "표시 가격을 지불하고 선택한 제안을 획득"
		"reroll_shop": return "현재 세 제안이 새 제안으로 교체됨"
	return "선택한 공개 행동에 대응하는 다음 화면 또는 상태로 진행"


func _reason_for(action: Dictionary, state: Dictionary) -> String:
	if str(action.get("action", "")) == "load":
		var view: Dictionary = state.get("player_view", {})
		var target := _nearest_enemy(view.get("enemies", []))
		var entry := _ammo_entry(view.get("available_ammo", []), str(action.get("bullet_id", "")))
		var bullet: Dictionary = entry.get("bullet", {})
		var effect := int(bullet.get("effect_type", 0))
		var tactical_reason := "현재 탄이 대상 DEF %d/EVA %d 게이트를 통과하는지 기준" % [
			int(target.get("defense", 0)), int(target.get("evasion", 0))]
		match effect:
			Enums.BulletEffect.BUFF_ACC: tactical_reason = "대상 EVA %d를 열기 위해 다음 탄 ACC 결산을 먼저 발사" % int(target.get("evasion", 0))
			Enums.BulletEffect.BUFF_PEN: tactical_reason = "대상 DEF %d를 열기 위해 다음 탄 PEN 결산을 먼저 발사" % int(target.get("defense", 0))
			Enums.BulletEffect.BUFF_DMG: tactical_reason = "명중·관통 게이트 통과 뒤 다음 탄 피해 결산을 만들기 위해 배치"
		return "%s: %s" % [_profile, tactical_reason]
	var base: String = {
		"beginner": "첫 플레이어가 이해하기 쉬운 기본·왼쪽 선택을 우선",
		"aggressive": "즉시 피해와 전투 종료 속도를 우선",
		"conservative": "명중·관통·거리 안전성을 우선",
		"experimental": "덜 사용한 탄환과 다른 경로를 우선",
	}.get(_profile, "공개 정보에서 선택")
	return "%s: %s" % [base, str(action.get("action", ""))]


func _ammo_entry(available: Array, choice_id: String) -> Dictionary:
	for entry in available:
		if entry is Dictionary and str(entry.get("id", "")) == choice_id:
			return entry
	return {}


func _choice_id(action: Dictionary) -> String:
	for key in ["bullet_id", "node_id", "choice", "offer_slot", "target_slot"]:
		if action.has(key):
			return str(action[key])
	return str(action.get("action", ""))


func _category_for(action_name: String) -> String:
	match action_name:
		"load": return "ammo"
		"fire", "reload", "unload", "eject", "confirm_load": return "combat"
		"choose_route": return "route"
		"choose_reward": return "reward"
		"buy", "reroll_shop": return "shop"
		"use_maintenance": return "maintenance"
	return "flow"


func _capture_enabled() -> bool:
	return OS.get_environment("QA_CAPTURE").to_lower() in ["1", "true", "yes"]
