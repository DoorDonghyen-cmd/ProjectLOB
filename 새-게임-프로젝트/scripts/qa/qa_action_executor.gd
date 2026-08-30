class_name QAActionExecutor
extends RefCounted

const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")
const StateSerializerScript := preload("res://scripts/qa/qa_state_serializer.gd")

var combat_manager: CombatManager
var pending_load: Array[BulletData] = []


func _init(cm: CombatManager) -> void:
	combat_manager = cm


func legal_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if combat_manager == null:
		return actions
	match combat_manager.state:
		CombatManager.State.LOADING:
			var available: Array[Dictionary] = StateSerializerScript.available_ammo(combat_manager, pending_load)
			var ids: Array[String] = []
			for entry in available:
				ids.append(str(entry.id))
			if not ids.is_empty() and pending_load.size() < _max_load_capacity():
				actions.append({"action": "load", "bullet_ids": ids})
			if not pending_load.is_empty():
				actions.append({"action": "undo_load"})
				actions.append({"action": "confirm_load"})
		CombatManager.State.PLAYER_TURN:
			if combat_manager.magazine != null and not combat_manager.magazine.is_empty():
				var fire_action: Dictionary = {"action": "fire"}
				var next_bullet: BulletData = combat_manager.magazine.peek()
				if next_bullet != null and next_bullet.slow > 0:
					var slots: Array[int] = []
					for i in range(combat_manager.enemies.size()):
						if not combat_manager.enemies[i].is_dead():
							slots.append(i)
					fire_action["target_slots"] = slots
				actions.append(fire_action)
				actions.append({"action": "unload"})
				if combat_manager.gun_is("trickster"):
					actions.append({"action": "eject"})
			actions.append({"action": "reload"})
	return actions


func execute(action: Dictionary) -> Dictionary:
	if combat_manager == null:
		return _rejected("combat_manager가 없음")
	var action_type := str(action.get("action", ""))
	match action_type:
		"load":
			return _load(str(action.get("bullet_id", "")))
		"undo_load":
			return _undo_load()
		"confirm_load":
			return _confirm_load()
		"fire":
			return _fire(action)
		"reload":
			return _reload()
		"unload":
			return _unload()
		"eject":
			return _eject()
	return _rejected("지원하지 않는 행동: %s" % action_type)


func _load(bullet_id: String) -> Dictionary:
	if combat_manager.state != CombatManager.State.LOADING:
		return _rejected("장전 단계가 아님")
	if pending_load.size() >= _max_load_capacity():
		return _rejected("장전 용량 초과")
	var bullet: BulletData = _find_available_bullet(bullet_id)
	if bullet == null:
		return _rejected("사용 가능한 탄환이 아님: %s" % bullet_id)
	pending_load.append(bullet)
	return _accepted("load", {"bullet_id": bullet_id})


func _undo_load() -> Dictionary:
	if combat_manager.state != CombatManager.State.LOADING or pending_load.is_empty():
		return _rejected("되돌릴 장전이 없음")
	var bullet: BulletData = pending_load.pop_back()
	return _accepted("undo_load", {"bullet_id": PlaytestLoggerScript.resource_id(bullet)})


func _confirm_load() -> Dictionary:
	if combat_manager.state != CombatManager.State.LOADING:
		return _rejected("장전 단계가 아님")
	if pending_load.is_empty():
		return _rejected("빈 탄창은 확정할 수 없음")
	var confirmed: Array[BulletData] = pending_load.duplicate()
	combat_manager.confirm_loading(confirmed)
	pending_load.clear()
	return _accepted("confirm_load", {"loaded": confirmed.size()})


func _fire(action: Dictionary) -> Dictionary:
	if combat_manager.state != CombatManager.State.PLAYER_TURN:
		return _rejected("플레이어 행동 단계가 아님")
	if combat_manager.magazine == null or combat_manager.magazine.is_empty():
		return _rejected("탄창이 비어 있음")
	if action.has("target_slot"):
		var target_slot := int(action.target_slot)
		if target_slot < 0 or target_slot >= combat_manager.enemies.size():
			return _rejected("유효하지 않은 대상 슬롯")
		var target: EnemyInstance = combat_manager.enemies[target_slot]
		if target.is_dead():
			return _rejected("이미 처치된 대상")
		var next_bullet: BulletData = combat_manager.magazine.peek()
		var nearest: EnemyInstance = combat_manager.enemy
		if next_bullet == null or (next_bullet.slow <= 0 and target != nearest):
			return _rejected("현재 탄환은 최근접 적만 조준 가능")
		combat_manager.fire_at_target(target)
	else:
		combat_manager.fire()
	return _accepted("fire", {})


func _reload() -> Dictionary:
	if combat_manager.state != CombatManager.State.PLAYER_TURN:
		return _rejected("플레이어 행동 단계가 아님")
	combat_manager.request_reload()
	return _accepted("reload", {})


func _unload() -> Dictionary:
	if combat_manager.state != CombatManager.State.PLAYER_TURN:
		return _rejected("플레이어 행동 단계가 아님")
	if combat_manager.magazine == null or combat_manager.magazine.is_empty():
		return _rejected("빼낼 탄환이 없음")
	combat_manager.request_unload()
	return _accepted("unload", {})


func _eject() -> Dictionary:
	if combat_manager.state != CombatManager.State.PLAYER_TURN:
		return _rejected("플레이어 행동 단계가 아님")
	if not combat_manager.gun_is("trickster"):
		return _rejected("현재 총기는 이젝트를 지원하지 않음")
	if combat_manager.magazine == null or combat_manager.magazine.is_empty():
		return _rejected("이젝트할 탄환이 없음")
	if combat_manager.eject_used_this_turn:
		return _rejected("이번 턴에 이미 이젝트를 사용함")
	combat_manager.request_eject()
	return _accepted("eject", {})


func _find_available_bullet(bullet_id: String) -> BulletData:
	if bullet_id.is_empty():
		return null
	var pending_count := 0
	for bullet in pending_load:
		if PlaytestLoggerScript.resource_id(bullet) == bullet_id:
			pending_count += 1

	var candidates: Array[BulletData] = []
	for bullet in combat_manager.draw_pile:
		if PlaytestLoggerScript.resource_id(bullet) == bullet_id:
			candidates.append(bullet)
	if combat_manager.basic_supply_bullet != null \
			and PlaytestLoggerScript.resource_id(combat_manager.basic_supply_bullet) == bullet_id:
		for i in range(combat_manager.basic_supply_current):
			candidates.append(combat_manager.basic_supply_bullet)
	if pending_count >= candidates.size():
		return null
	return candidates[pending_count]


func _max_load_capacity() -> int:
	if combat_manager == null or combat_manager.gun == null:
		return 0
	return combat_manager.gun.magazine_capacity + (1 if combat_manager.gun.has_chamber else 0)


func _accepted(action_type: String, details: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"action": action_type,
		"details": details.duplicate(true),
	}


func _rejected(error: String) -> Dictionary:
	return {
		"accepted": false,
		"error": error,
	}
