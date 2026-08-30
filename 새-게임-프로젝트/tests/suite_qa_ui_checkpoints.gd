extends RefCounted

const MAIN_SCENE := "res://scenes/combat/combat_scene.tscn"
const StateSerializerScript := preload("res://scripts/qa/qa_ui_state_serializer.gd")
const ActionExecutorScript := preload("res://scripts/qa/qa_ui_action_executor.gd")
const CaptureScript := preload("res://scripts/qa/qa_capture.gd")


static func run(t, tree: SceneTree) -> void:
	t.section("QAUI checkpoints")
	var packed: PackedScene = load(MAIN_SCENE)
	t.check(packed != null, "Phase C 메인 씬 로드")
	if packed == null:
		return
	var scene = packed.instantiate()
	tree.root.add_child(scene)
	var qa_seed := 314159
	scene.configure_qa_run(qa_seed, "qa-ui-seed-forwarding")
	var executor = ActionExecutorScript.new(scene, true)

	var title_state := StateSerializerScript.serialize(scene, "title", executor.legal_actions())
	t.eq(str(title_state.screen), "title", "실제 씬 첫 체크포인트는 타이틀")
	t.check(title_state.controls.size() > 0, "타이틀 공개 컨트롤 상태 직렬화")
	t.check(_has_action(title_state.legal_actions, "open_section_selector"),
		"타이틀 의미 행동은 구역 선택 열기")

	var rejected := executor.execute({"action": "reroll_shop"})
	t.check(not bool(rejected.accepted), "다른 화면의 의미 행동 거절")
	t.eq(StateSerializerScript.screen_id(scene), "title", "거절된 UI 행동은 화면을 바꾸지 않음")

	var open_result := executor.execute({"action": "open_section_selector"})
	t.check(bool(open_result.accepted), "실제 시작 버튼 콜백 실행")
	t.eq(StateSerializerScript.screen_id(scene), "section_selector", "구역 선택 체크포인트")

	var confirm_result := executor.execute({"action": "confirm_section"})
	t.check(bool(confirm_result.accepted), "실제 구역 확정 콜백 실행")
	t.eq(StateSerializerScript.screen_id(scene), "loadout", "준비실 체크포인트")

	if scene._loadout_overlay._bonus_popup.visible:
		var bonus_result := executor.execute({"action": "choose_starting_bonus", "choice": "credits"})
		t.check(bool(bonus_result.accepted), "QA 전용 세이브의 시작 보너스 선택")
	var start_result := executor.execute({"action": "start_run"})
	t.check(bool(start_result.accepted), "실제 상승 개시 콜백 실행")
	t.eq(StateSerializerScript.screen_id(scene), "map", "지도 체크포인트")
	t.eq(scene._rm.gameplay_seed, qa_seed, "QA manifest seed가 준비실 완료 경로로 실제 런에 전달")
	t.eq(scene._rm.qa_session_id, "qa-ui-seed-forwarding", "QA session ID가 실제 런에 전달")

	var combat_node_id := _first_combat_node_id(scene)
	t.check(combat_node_id > 0, "현재 층에 실제 전투 노드 존재")
	if combat_node_id > 0:
		var route_result := executor.execute({"action": "choose_route", "node_id": combat_node_id})
		t.check(bool(route_result.accepted), "실제 지도 노드 선택 콜백 실행")
		t.eq(StateSerializerScript.screen_id(scene), "combat", "전투 장전 체크포인트")

		var victory_result := executor.execute({"action": "present_victory_fixture"})
		t.check(bool(victory_result.accepted), "QA 고정 승리로 실제 보상 패널 진입")
		var reward_state := StateSerializerScript.serialize(scene, "reward", executor.legal_actions())
		t.eq(str(reward_state.screen), "reward", "보상 체크포인트")
		t.check(int(reward_state.reward.card_count) >= 2, "보상 선택 카드 공개 상태 직렬화")

		var skip_result := executor.execute({"action": "skip_reward"})
		t.check(bool(skip_result.accepted), "실제 보상 건너뛰기 콜백 실행")
		t.eq(StateSerializerScript.screen_id(scene), "map", "보상 뒤 지도 복귀")

	var shop_result := executor.execute({"action": "open_shop_fixture"})
	t.check(bool(shop_result.accepted), "실제 상점 오버레이 고정 체크포인트 진입")
	var shop_before := StateSerializerScript.serialize(scene, "shop_initial", executor.legal_actions())
	t.eq(str(shop_before.screen), "shop", "상점 최초 진열 체크포인트")
	t.check(bool(shop_before.shop.render_integrity.valid), "상점 데이터와 렌더 카드 설명 일치")
	t.eq(shop_before.shop.offers.size(), 3, "상점 공개 카드 3개 직렬화")

	var old_center_id := str(shop_before.shop.center_slot.get("id", ""))
	var old_center_description := str(shop_before.shop.center_slot.get("description", ""))
	var reroll_result := executor.execute({"action": "reroll_shop"})
	t.check(bool(reroll_result.accepted), "실제 주파수 재요청 콜백 실행")
	var shop_after := StateSerializerScript.serialize(scene, "shop_reroll", executor.legal_actions())
	t.eq(int(shop_after.shop.reroll_count), 1, "리롤 횟수 공개 상태 갱신")
	t.check(bool(shop_after.shop.render_integrity.valid),
		"⭐ 리롤 뒤 가운데 카드를 포함한 데이터·설명 정합")
	var new_center_text := str(shop_after.shop.center_slot.get("rendered_text", ""))
	var new_center_id := str(shop_after.shop.center_slot.get("id", ""))
	var new_center_description := str(shop_after.shop.center_slot.get("description", ""))
	if old_center_id != new_center_id and old_center_description != new_center_description \
			and not old_center_description.is_empty():
		t.check(not new_center_text.contains(old_center_description),
			"⭐ 가운데 카드 교체 시 이전 선택 설명이 남지 않음")

	# 검사기가 구 카드가 한 프레임 겹치는 상태를 실제로 잡는지 결함 fixture로 검증한다.
	var stale_card := PanelContainer.new()
	var stale_label := Label.new()
	stale_label.text = "이전 가운데 카드 설명"
	stale_card.add_child(stale_label)
	scene._maintenance_overlay._shop_grid.add_child(stale_card)
	var stale_state := StateSerializerScript.shop_state(scene._maintenance_overlay)
	t.check(not bool(stale_state.render_integrity.valid), "중복·잔존 상점 카드 검출기")
	stale_card.free()

	var no_capture := CaptureScript.unavailable("headless fallback test")
	t.check(not bool(no_capture.captured) and str(no_capture.classification) == "qa_infrastructure",
		"캡처 불가를 게임 버그가 아닌 QA 인프라 상태로 분류")

	scene.queue_free()


static func _has_action(actions: Array, action_type: String) -> bool:
	for action in actions:
		if str(action.get("action", "")) == action_type:
			return true
	return false


static func _first_combat_node_id(scene) -> int:
	var ids: Array[int] = []
	for node_id in scene._rm.map_nodes.keys():
		var id := int(node_id)
		if id / 100 != scene._rm.current_floor or not scene._rm.is_node_reachable(id):
			continue
		var node: RunManager.RunNode = scene._rm.map_nodes[id]
		var resolved := node.hidden_type if node.type_name.begins_with("???") else node.type_name
		if resolved.contains("전투") or CampaignContent.is_major_gate_type(resolved):
			ids.append(id)
	ids.sort()
	return ids[0] if not ids.is_empty() else -1
