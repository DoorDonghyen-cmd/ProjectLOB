class_name QAStateSerializer
extends RefCounted

const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")


static func state_name(state: int) -> String:
	match state:
		CombatManager.State.INACTIVE:
			return "inactive"
		CombatManager.State.LOADING:
			return "loading"
		CombatManager.State.PLAYER_TURN:
			return "player_turn"
		CombatManager.State.RELOADING:
			return "reloading"
		CombatManager.State.WON:
			return "won"
		CombatManager.State.LOST:
			return "lost"
	return "unknown"


static func bullet_snapshot(bullet: BulletData) -> Dictionary:
	if bullet == null:
		return {}
	var result := PlaytestLoggerScript.resource_snapshot(bullet)
	result["damage"] = bullet.damage
	result["accuracy"] = bullet.accuracy
	result["penetration"] = bullet.penetration
	result["knockback"] = bullet.knockback
	result["slow"] = bullet.slow
	result["effect_type"] = int(bullet.effect_type)
	result["effect_value"] = bullet.effect_value
	result["is_basic"] = bullet.is_basic
	return result


static func enemy_public_snapshot(enemy: EnemyInstance, slot: int) -> Dictionary:
	return {
		"slot": slot,
		"id": PlaytestLoggerScript.resource_id(enemy.data),
		"display_name": enemy.data.display_name,
		"hp": enemy.current_hp,
		"max_hp": enemy.max_hp,
		"defense": enemy.current_def,
		"evasion": enemy.current_evasion,
		"speed": enemy.current_speed,
		"distance": enemy.current_distance,
		"stance": int(enemy.current_stance),
		"barrier_cells": enemy.barrier_cells if enemy.is_stack_sponge else 0,
		"is_dead": enemy.is_dead(),
	}


static func enemy_oracle_snapshot(enemy: EnemyInstance, slot: int) -> Dictionary:
	var result := enemy_public_snapshot(enemy, slot)
	result["start_distance"] = enemy.start_distance
	result["shot_counter"] = enemy.shot_counter
	result["stance_shift_interval"] = enemy.stance_shift_interval
	result["slow_stacks"] = enemy.slow_stacks
	result["knockback_resistance"] = enemy.knockback_resistance
	result["charge_turns_current"] = enemy.charge_turns_current
	result["charge_turns_max"] = enemy.charge_turns_max
	result["current_phase"] = enemy.current_phase
	return result


static func player_view(
	cm: CombatManager,
	pending_load: Array[BulletData],
	step: int,
	legal_actions: Array[Dictionary],
	last_result: Dictionary = {}
) -> Dictionary:
	var public_enemies: Array[Dictionary] = []
	for i in range(cm.enemies.size()):
		public_enemies.append(enemy_public_snapshot(cm.enemies[i], i))

	var loaded_visible: Array[Dictionary] = []
	var remaining := 0
	var capacity := 0
	if cm.magazine != null:
		var loaded := cm.magazine.get_loaded_bullets()
		remaining = loaded.size()
		capacity = cm.magazine.get_capacity() + (1 if cm.gun != null and cm.gun.has_chamber else 0)
		var visible_count := mini(cm.visible_magazine_slots, loaded.size())
		for offset in range(visible_count):
			loaded_visible.append(bullet_snapshot(loaded[loaded.size() - 1 - offset]))

	var pending: Array[Dictionary] = []
	for bullet in pending_load:
		pending.append(bullet_snapshot(bullet))

	return {
		"step": step,
		"screen": "combat",
		"combat_state": state_name(cm.state),
		"gun": PlaytestLoggerScript.resource_snapshot(cm.gun),
		"enemies": public_enemies,
		"magazine": {
			"remaining": remaining,
			"capacity": capacity,
			"visible_fire_order": loaded_visible,
			"hidden_count": maxi(remaining - loaded_visible.size(), 0),
		},
		"pending_load_order": pending,
		"available_ammo": available_ammo(cm, pending_load),
		"legal_actions": legal_actions,
		"last_result": last_result.duplicate(true),
	}


static func oracle_state(cm: CombatManager, pending_load: Array[BulletData], step: int) -> Dictionary:
	var oracle_enemies: Array[Dictionary] = []
	for i in range(cm.enemies.size()):
		oracle_enemies.append(enemy_oracle_snapshot(cm.enemies[i], i))

	var load_order: Array[Dictionary] = []
	var fire_order: Array[Dictionary] = []
	if cm.magazine != null:
		var loaded := cm.magazine.get_loaded_bullets()
		for bullet in loaded:
			load_order.append(bullet_snapshot(bullet))
		for i in range(loaded.size() - 1, -1, -1):
			fire_order.append(bullet_snapshot(loaded[i]))

	var pending: Array[Dictionary] = []
	for bullet in pending_load:
		pending.append(bullet_snapshot(bullet))

	return {
		"step": step,
		"combat_state": state_name(cm.state),
		"enemies": oracle_enemies,
		"magazine_load_order": load_order,
		"magazine_fire_order": fire_order,
		"pending_load_order": pending,
		"draw_pile": _bullet_list(cm.draw_pile),
		"discard_pile": _bullet_list(cm.discard_pile),
		"exile_pile": _bullet_list(cm.exile_pile),
		"basic_supply_current": cm.basic_supply_current,
		"basic_supply_capacity": cm.basic_supply_capacity,
		"pending_buff_acc": cm.pending_buff_acc,
		"pending_buff_pen": cm.pending_buff_pen,
		"pending_buff_dmg": cm.pending_buff_dmg,
		"battle_stats": cm.battle_stats.duplicate(true),
	}


static func available_ammo(cm: CombatManager, pending_load: Array[BulletData]) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for bullet in cm.draw_pile:
		_add_available(grouped, bullet, 1)
	if cm.basic_supply_bullet != null:
		_add_available(grouped, cm.basic_supply_bullet, cm.basic_supply_current)
	for bullet in pending_load:
		var id := PlaytestLoggerScript.resource_id(bullet)
		if grouped.has(id):
			grouped[id]["count"] = maxi(int(grouped[id].count) - 1, 0)

	var result: Array[Dictionary] = []
	var ids := grouped.keys()
	ids.sort()
	for id in ids:
		var entry: Dictionary = grouped[id]
		if int(entry.count) > 0:
			result.append(entry)
	return result


static func _add_available(grouped: Dictionary, bullet: BulletData, amount: int) -> void:
	if bullet == null or amount <= 0:
		return
	var id := PlaytestLoggerScript.resource_id(bullet)
	if not grouped.has(id):
		grouped[id] = {
			"id": id,
			"display_name": bullet.display_name,
			"count": 0,
			"bullet": bullet_snapshot(bullet),
		}
	grouped[id]["count"] = int(grouped[id].count) + amount


static func _bullet_list(bullets: Array[BulletData]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bullet in bullets:
		result.append(bullet_snapshot(bullet))
	return result
