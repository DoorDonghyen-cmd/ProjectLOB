class_name QAUIActionExecutor
extends RefCounted

const StateSerializerScript := preload("res://scripts/qa/qa_ui_state_serializer.gd")
const CombatExecutorScript := preload("res://scripts/qa/qa_action_executor.gd")
const CombatStateSerializerScript := preload("res://scripts/qa/qa_state_serializer.gd")

var scene = null
var allow_fixtures: bool = false
var combat_executor = null


func _init(scene_root, fixtures_enabled: bool = false) -> void:
	scene = scene_root
	allow_fixtures = fixtures_enabled


func legal_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if scene == null:
		return actions
	match StateSerializerScript.screen_id(scene):
		"title":
			actions.append({"action": "open_section_selector"})
		"section_selector":
			actions.append({"action": "confirm_section"})
			actions.append({"action": "back"})
		"loadout":
			if is_instance_valid(scene._loadout_overlay._bonus_popup) \
					and scene._loadout_overlay._bonus_popup.visible:
				actions.append({"action": "choose_starting_bonus", "choices": ["credits", "part"]})
			if not scene._loadout_overlay._btn_start_run.disabled:
				actions.append({"action": "start_run"})
		"map":
			var node_ids := _selectable_map_node_ids()
			if not node_ids.is_empty():
				actions.append({"action": "choose_route", "node_ids": node_ids})
			if allow_fixtures:
				actions.append({"action": "present_victory_fixture"})
				actions.append({"action": "open_shop_fixture"})
		"combat":
			var executor = _combat_executor()
			if executor != null and not scene._combat_overlay._is_action_resolution_locked():
				actions.append_array(executor.legal_actions())
			if allow_fixtures:
				actions.append({"action": "present_victory_fixture"})
		"reward":
			actions.append({"action": "choose_reward", "choices": ["bullet", "credits", "skip"]})
			actions.append({"action": "skip_reward"})
		"shop":
			if is_instance_valid(scene._maintenance_overlay._reroll_cost_btn) \
					and not scene._maintenance_overlay._reroll_cost_btn.disabled:
				actions.append({"action": "reroll_shop"})
			var buy_slots: Array[int] = []
			for i in range(scene._maintenance_overlay._shop_items.size()):
				var entry: Dictionary = scene._maintenance_overlay._shop_items[i]
				if not bool(entry.get("sold_out", false)) \
						and scene._rm.credits >= int(entry.get("price", 0)):
					buy_slots.append(i)
			if not buy_slots.is_empty():
				actions.append({"action": "buy", "offer_slots": buy_slots})
			actions.append({"action": "use_maintenance"})
			if allow_fixtures:
				actions.append({"action": "open_shop_fixture"})
		"maintenance":
			actions.append({"action": "use_maintenance"})
		"section_transition":
			actions.append({"action": "continue_section"})
	return actions


func execute(action: Dictionary) -> Dictionary:
	if scene == null:
		return _rejected("scene이 없음")
	var action_type := str(action.get("action", ""))
	var before := StateSerializerScript.screen_id(scene)
	var result: Dictionary
	match action_type:
		"open_section_selector": result = _open_section_selector(before)
		"confirm_section": result = _confirm_section(before)
		"back": result = _back(before)
		"choose_starting_bonus": result = _choose_starting_bonus(before, str(action.get("choice", "")))
		"start_run": result = _start_run(before)
		"choose_route": result = _choose_route(before, int(action.get("node_id", -1)))
		"choose_reward": result = _choose_reward(before, str(action.get("choice", "skip")), int(action.get("slot", 0)))
		"skip_reward": result = _skip_reward(before)
		"reroll_shop": result = _reroll_shop(before)
		"buy": result = _buy(before, int(action.get("offer_slot", -1)))
		"use_maintenance": result = _use_maintenance(before)
		"continue_section": result = _continue_section(before)
		"present_victory_fixture": result = _present_victory_fixture(before)
		"open_shop_fixture": result = _open_shop_fixture()
		_:
			if action_type in ["load", "undo_load", "confirm_load", "fire", "reload", "unload", "eject"]:
				result = _execute_combat(action, before)
			else:
				result = _rejected("지원하지 않는 UI 행동: %s" % action_type)
	result["screen_before"] = before
	result["screen_after"] = StateSerializerScript.screen_id(scene)
	return result


func combat_player_view(step: int, last_result: Dictionary) -> Dictionary:
	var executor = _combat_executor()
	if executor == null:
		return {}
	return CombatStateSerializerScript.player_view(
		scene._cm, executor.pending_load, step, executor.legal_actions(), last_result)


func _combat_executor():
	if scene == null or scene._cm == null:
		combat_executor = null
		return null
	if combat_executor == null or combat_executor.combat_manager != scene._cm:
		combat_executor = CombatExecutorScript.new(scene._cm)
	return combat_executor


func _execute_combat(action: Dictionary, screen: String) -> Dictionary:
	if screen != "combat":
		return _rejected("전투 화면이 아님")
	if scene._combat_overlay._is_action_resolution_locked():
		return _rejected("전투 결과 연출이 진행 중임")
	var executor = _combat_executor()
	if executor == null:
		return _rejected("활성 전투가 없음")
	var result: Dictionary = executor.execute(action)
	if bool(result.get("accepted", false)):
		scene._combat_overlay._update_action_buttons()
	return result


func _open_section_selector(screen: String) -> Dictionary:
	if screen != "title":
		return _rejected("타이틀 화면이 아님")
	scene._title_overlay._on_start_run_pressed()
	return _accepted("open_section_selector")


func _confirm_section(screen: String) -> Dictionary:
	if screen != "section_selector":
		return _rejected("구역 선택 화면이 아님")
	scene._section_selector_overlay._on_confirm_pressed()
	return _accepted("confirm_section")


func _back(screen: String) -> Dictionary:
	if screen != "section_selector":
		return _rejected("뒤로가기를 지원하지 않는 화면")
	scene._section_selector_overlay._on_back_pressed()
	return _accepted("back")


func _choose_starting_bonus(screen: String, choice: String) -> Dictionary:
	if screen != "loadout":
		return _rejected("준비실 화면이 아님")
	if not is_instance_valid(scene._loadout_overlay._bonus_popup) \
			or not scene._loadout_overlay._bonus_popup.visible:
		return _rejected("선택할 시작 보너스가 없음")
	match choice:
		"credits": scene._loadout_overlay._on_bonus_credits_selected()
		"part": scene._loadout_overlay._on_bonus_part_selected()
		_: return _rejected("알 수 없는 시작 보너스")
	return _accepted("choose_starting_bonus", {"choice": choice})


func _start_run(screen: String) -> Dictionary:
	if screen != "loadout":
		return _rejected("준비실 화면이 아님")
	if scene._loadout_overlay._btn_start_run.disabled:
		return _rejected("상승 개시 버튼이 비활성화됨")
	scene._loadout_overlay._on_start_run_pressed()
	return _accepted("start_run")


func _choose_route(screen: String, node_id: int) -> Dictionary:
	if screen != "map":
		return _rejected("지도 화면이 아님")
	if not scene._rm.map_nodes.has(node_id):
		return _rejected("존재하지 않는 노드")
	if not _selectable_map_node_ids().has(node_id):
		return _rejected("현재 선택할 수 없는 노드")
	var node: RunManager.RunNode = scene._rm.map_nodes[node_id]
	scene._map_overlay._on_node_selected(node)
	return _accepted("choose_route", {"node_id": node_id})


func _choose_reward(screen: String, choice: String, slot: int) -> Dictionary:
	if screen != "reward":
		return _rejected("보상 화면이 아님")
	var draft = scene._combat_overlay._draft_container
	if choice == "skip":
		return _skip_reward(screen)
	var cards: Array = draft._draft_cards_hbox.get_children()
	if cards.is_empty():
		return _rejected("보상 카드가 없음")
	var card_index := cards.size() - 1 if choice == "credits" else slot
	if card_index < 0 or card_index >= cards.size():
		return _rejected("유효하지 않은 보상 슬롯")
	if choice == "credits":
		draft._on_credit_card_selected(cards[card_index])
	elif choice == "bullet":
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		cards[card_index].gui_input.emit(event)
	else:
		return _rejected("알 수 없는 보상 선택")
	draft._on_btn_add_pressed()
	return _accepted("choose_reward", {"choice": choice, "slot": card_index})


func _skip_reward(screen: String) -> Dictionary:
	if screen != "reward":
		return _rejected("보상 화면이 아님")
	scene._combat_overlay._draft_container._on_btn_skip_pressed()
	return _accepted("skip_reward")


func _reroll_shop(screen: String) -> Dictionary:
	if screen != "shop":
		return _rejected("상점 화면이 아님")
	if scene._maintenance_overlay._reroll_cost_btn.disabled:
		return _rejected("주파수 재요청 버튼이 비활성화됨")
	var previous_count := int(scene._maintenance_overlay._reroll_count)
	scene._maintenance_overlay._on_reroll_pressed()
	if int(scene._maintenance_overlay._reroll_count) != previous_count + 1:
		return _rejected("주파수 재요청 횟수가 증가하지 않음")
	return _accepted("reroll_shop", {"reroll_count": previous_count + 1})


func _buy(screen: String, offer_slot: int) -> Dictionary:
	if screen != "shop":
		return _rejected("상점 화면이 아님")
	if offer_slot < 0 or offer_slot >= scene._maintenance_overlay._shop_items.size():
		return _rejected("유효하지 않은 상점 슬롯")
	var entry: Dictionary = scene._maintenance_overlay._shop_items[offer_slot]
	if bool(entry.get("sold_out", false)) or scene._rm.credits < int(entry.get("price", 0)):
		return _rejected("구매할 수 없는 제안")
	scene._maintenance_overlay._on_buy_item_pressed(offer_slot)
	return _accepted("buy", {"offer_slot": offer_slot})


func _use_maintenance(screen: String) -> Dictionary:
	if screen != "shop" and screen != "maintenance":
		return _rejected("정비 화면이 아님")
	var maintenance = scene._maintenance_overlay
	if int(maintenance._node_kind) == int(maintenance.NodeKind.EVENT) and not maintenance._event_used:
		maintenance._on_event_skip()
	maintenance._on_exit_pressed()
	return _accepted("use_maintenance")


func _continue_section(screen: String) -> Dictionary:
	if screen != "section_transition":
		return _rejected("계층 전환 화면이 아님")
	var button := StateSerializerScript.find_visible_button(scene, "계속 오른다")
	if button == null or button.disabled:
		return _rejected("계속 진행 버튼이 없음")
	button.pressed.emit()
	return _accepted("continue_section")


func _present_victory_fixture(screen: String) -> Dictionary:
	if not allow_fixtures:
		return _rejected("QA fixture 행동이 비활성화됨")
	if screen != "combat" or scene._cm == null or not is_instance_valid(scene._combat_overlay):
		return _rejected("승리 보상을 열 수 있는 전투 화면이 아님")
	scene._cm.battle_stats.total_kills = maxi(int(scene._cm.battle_stats.total_kills), 1)
	scene._cm.battle_stats.shots_fired = maxi(int(scene._cm.battle_stats.shots_fired), 1)
	scene._combat_overlay._present_encounter_won()
	return _accepted("present_victory_fixture")


func _open_shop_fixture() -> Dictionary:
	if not allow_fixtures:
		return _rejected("QA fixture 행동이 비활성화됨")
	if scene._rm == null or not scene._rm.map_nodes.has(401):
		return _rejected("고정 상점 노드가 없음")
	if is_instance_valid(scene._combat_overlay._result_overlay):
		scene._combat_overlay._result_overlay.visible = false
	scene._combat_margin.visible = false
	scene._map_overlay.visible = false
	scene._rm.credits = maxi(scene._rm.credits, 100)
	var shop_node: RunManager.RunNode = scene._rm.map_nodes[401]
	scene._current_node = shop_node
	scene._rm.current_node_id = shop_node.id
	scene._rm.current_floor = 4
	scene._start_maintenance_phase(shop_node)
	return _accepted("open_shop_fixture", {"node_id": 401})


func _selectable_map_node_ids() -> Array[int]:
	var node_ids: Array[int] = []
	for node_id in scene._rm.map_nodes.keys():
		var id := int(node_id)
		if id / 100 != scene._rm.current_floor or not scene._rm.is_node_reachable(id):
			continue
		var button: Button = scene._map_overlay._node_buttons.get("%s:%d" % [scene._rm.current_section, id])
		if button != null and not button.disabled:
			node_ids.append(id)
	node_ids.sort()
	return node_ids


func _accepted(action_type: String, details: Dictionary = {}) -> Dictionary:
	return {"accepted": true, "action": action_type, "details": details.duplicate(true)}


func _rejected(error: String) -> Dictionary:
	return {"accepted": false, "error": error}
