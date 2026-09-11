extends SceneTree
## Bounded oracle QA: ten declared late-gate fixtures, 193 deterministic policies each.
const CM := preload("res://scripts/core/combat_manager.gd")
const DECK := ["borer", "borer", "jammer", "jammer", "chain", "chain", "adhesive", "adhesive", "shred", "shred"]
const PARTS := ["armor_piercing", "interrupter"]
const POLICY_COUNT := 193
const MAX_MAGAZINES := 5
var _bullets := {}
var _bullet_names := {}
var _guns := {}
var _gates := {}
var _parts: Array[PartData] = []

func _initialize() -> void:
	RunManager.save_path_override = "user://tactical_combat_meta.cfg"
	preload("res://scripts/core/playtest_logger.gd").enabled = false
	RunManager.infiltration_risk_level = 1
	for id in DECK + ["cal_556", "cal_9mm"]:
		_bullets[id] = load("res://resources/bullets/%s.tres" % id)
		_bullet_names[_bullets[id].display_name] = id
	for id in ["stance_hunter", "suppressor", "revolver"]:
		_guns[id] = load("res://resources/guns/%s.tres" % id)
	for id in ["section_c", "section_d", "section_e"]:
		_gates[id] = CampaignContent.load_gate_encounter(id)
	for id in PARTS: _parts.append(load("res://resources/parts/%s.tres" % id) as PartData)
	var reports: Array[Dictionary] = []
	for spec in [
		["section_c", 0, "stance_hunter"], ["section_c", 5, "stance_hunter"], ["section_c", 10, "stance_hunter"],
		["section_d", 0, "suppressor"], ["section_d", 3, "suppressor"], ["section_d", 8, "suppressor"],
		["section_e", 0, "revolver"], ["section_e", 3, "revolver"], ["section_e", 8, "revolver"], ["section_e", 10, "revolver"],
	]:
		var wins := 0
		var losses := 0
		var bounded := 0
		var best: Dictionary = {}
		var best_policy := 0
		for policy in range(POLICY_COUNT):
			var result := _simulate(spec, policy)
			if result.state == "WON": wins += 1
			elif result.state == "LOST": losses += 1
			else: bounded += 1
			if best.is_empty() or _score(result) > _score(best):
				best = result
				best_policy = policy
		var repeat := _simulate(spec, best_policy)
		reports.append({"section": spec[0], "ascension": spec[1], "gun": spec[2], "deck": DECK, "parts": PARTS,
			"policies": POLICY_COUNT, "max_magazines": MAX_MAGAZINES, "wins": wins, "losses": losses, "bounded": bounded,
			"witness_policy": best_policy, "reproduced_identically": best == repeat, "witness": best, "repeat": repeat})
		print("TACTICAL_CASE=" + JSON.stringify({"section": spec[0], "ascension": spec[1], "wins": wins,
			"losses": losses, "bounded": bounded, "repeat_equal": best == repeat, "policy": best_policy, "witness": best}))
	var f := FileAccess.open("user://tactical_combat_probe_after.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(reports, "\t"))
	f.close()
	var contracts := _enemy_data_contract()
	var contracts_repeat := _enemy_data_contract()
	var cf := FileAccess.open("user://tactical_enemy_data_contract_after.json", FileAccess.WRITE)
	cf.store_string(JSON.stringify({"first": contracts, "second": contracts_repeat, "identical": contracts == contracts_repeat}, "\t"))
	cf.close()
	print("ENEMY_DATA_CONTRACT=" + JSON.stringify(contracts))
	quit(0)

func _enemy_data_contract() -> Array[Dictionary]:
	RunManager.meta_ascension_level = 0
	RunManager.infiltration_risk_level = 1
	var results: Array[Dictionary] = []
	for id in ["rusher", "dodger", "tank"]:
		var source := load("res://resources/enemies/%s.tres" % id) as EnemyData
		var direct := EnemyInstance.new(source)
		var copied := EnemyInstance.new(source.duplicate())
		var prepared := EnemyInstance.new(source.for_encounter())
		var adjusted := EnemyInstance.new(source.for_encounter(-2))
		results.append({"id": id, "csv": DataLoader.get_enemy(id),
			"direct_resource": _instance_stats(direct), "duplicated_resource": _instance_stats(copied),
			"prepared_zero": _instance_stats(prepared), "prepared_minus2": _instance_stats(adjusted),
			"prepared_matches_csv": _instance_stats(direct) == _instance_stats(prepared),
			"distance_applied_once": adjusted.current_distance == maxi(direct.current_distance - 2, 4)})
	var synthetic := EnemyData.new()
	synthetic.max_hp = 17
	synthetic.defense = 2
	synthetic.evasion = 4
	synthetic.speed = 2
	synthetic.start_distance = 3
	var prepared_synthetic := synthetic.for_encounter(-2)
	results.append({"id": "synthetic", "hp_preserved": prepared_synthetic.max_hp == 17,
		"other_stats_preserved": prepared_synthetic.defense == 2 and prepared_synthetic.evasion == 4 and prepared_synthetic.speed == 2,
		"prepared_distance": prepared_synthetic.start_distance, "source_distance_unchanged": synthetic.start_distance == 3})
	RunManager.meta_ascension_level = 10
	RunManager.infiltration_risk_level = 3
	for modifier in [-4, -20]:
		var rusher := load("res://resources/enemies/rusher.tres") as EnemyData
		var cm := CM.new()
		cm.start_encounter(_guns.revolver, [rusher.for_encounter(modifier), rusher.for_encounter(modifier)] as Array[EnemyData], [] as Array[BulletData], [] as Array[PartData], _bullets.cal_9mm)
		results.append({"id": "distance_order", "modifier": modifier, "risk": 3, "ascension": 10,
			"prepared_distance": rusher.for_encounter(modifier).start_distance,
			"final_distances": [cm.enemies[0].current_distance, cm.enemies[1].current_distance],
			"expected_distances": [2, 4] if modifier == -4 else [1, 3]})
		cm.free()
	RunManager.infiltration_risk_level = 1
	return results

func _instance_stats(enemy: EnemyInstance) -> Dictionary:
	return {"hp": enemy.current_hp, "distance": enemy.current_distance, "def": enemy.current_def,
		"eva": enemy.current_evasion, "speed": enemy.current_speed, "knockback_resistance": enemy.knockback_resistance}

func _score(result: Dictionary) -> float:
	return (100000.0 if result.state == "WON" else 0.0) + float(result.kills) * 1000.0 - float(result.durability_remaining) * 10.0 - float(result.shots)

func _simulate(spec: Array, policy: int) -> Dictionary:
	RunManager.meta_ascension_level = int(spec[1])
	RandomStreams.begin_run(6610911, 991166)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6610911 + policy
	var gun: GunData = _guns[spec[2]]
	var rm := RunManager.new()
	rm.current_section = str(spec[0])
	rm.current_floor = int(MapGenerator.section_info(rm.current_section).floors)
	var floor_delta := rm.floor_distance_modifier()
	var enemy_datas: Array[EnemyData] = []
	for data in _gates[spec[0]]:
		enemy_datas.append(data.for_encounter(floor_delta))
	var deck: Array[BulletData] = []
	for id in DECK: deck.append(_bullets[id].duplicate())
	var base_id: String = RunManager.STARTING_AMMO_IDS[gun.weapon_class][0]
	var basic: BulletData = _bullets[base_id]
	var cm := CM.new()
	cm.start_encounter(gun, enemy_datas, deck, _parts, basic)
	var initial := _enemies(cm)
	var orders: Array[Array] = []
	var trace: Array[Dictionary] = []
	var legal := true
	var actual_reload_turns := 0
	var fire_actions := 0
	for magazine_index in range(MAX_MAGAZINES):
		if cm.state in [CM.State.WON, CM.State.LOST]: break
		var order := _pick_order(cm, rng, policy, magazine_index, base_id)
		var ids: Array = []
		for bullet in order: ids.append(_bullet_id(bullet))
		orders.append(ids)
		order.reverse()
		cm.confirm_loading(order)
		if cm.magazine.get_remaining() != order.size():
			legal = false
			break
		while cm.state == CM.State.PLAYER_TURN and not cm.magazine.is_empty():
			cm.fire()
			fire_actions += 1
			trace.append({"action": "fire", "shots": cm.battle_stats.shots_fired, "state": CM.State.keys()[cm.state], "enemies": _enemies(cm)})
		if cm.state == CM.State.PLAYER_TURN and magazine_index + 1 < MAX_MAGAZINES:
			cm.request_reload()
			actual_reload_turns += gun.reload_turns - cm.reload_turns_remaining
			trace.append({"action": "reload", "cost": gun.reload_turns, "state": CM.State.keys()[cm.state], "enemies": _enemies(cm)})
	var durability := 0
	for enemy in cm.enemies:
		if not enemy.is_dead(): durability += enemy.barrier_cells if enemy.is_stack_sponge else enemy.current_hp
	var result := {"state": CM.State.keys()[cm.state], "legal": legal, "supply": base_id,
		"capacity": gun.magazine_capacity + (1 if gun.has_chamber else 0), "reload_cost": gun.reload_turns,
		"floor_delta": floor_delta, "initial": initial, "shots": cm.battle_stats.shots_fired,
		"reloads": cm.telemetry_reload_count, "reload_turns": cm.telemetry_reload_turns,
		"actual_reload_turns": actual_reload_turns, "fire_actions": fire_actions,
		"kills": cm.battle_stats.total_kills, "durability_remaining": durability,
		"misses": cm.battle_stats.misses, "zero_damage_hits": cm.battle_stats.zero_damage_hits,
		"emergency_used": cm.buttstroke_used_this_encounter, "fire_orders": orders, "final": _enemies(cm), "trace": trace}
	cm.free()
	return result

func _pick_order(cm, rng: RandomNumberGenerator, policy: int, magazine_index: int, base_id: String) -> Array[BulletData]:
	var pool: Array[BulletData] = cm.draw_pile.duplicate()
	for i in range(cm.basic_supply_current): pool.append(cm.basic_supply_bullet)
	var result: Array[BulletData] = []
	var patterns := [
		[base_id, base_id, "borer", base_id, "jammer"],
		["borer", base_id, "jammer", base_id, "chain"],
		[base_id, "borer", base_id, "borer", base_id],
		["shred", base_id, "jammer", "chain", base_id],
		[base_id, base_id, base_id, base_id, base_id],
		["borer", base_id, "adhesive", "jammer", base_id],
	]
	for slot in range(cm.basic_supply_capacity):
		if pool.is_empty(): break
		var pick := rng.randi_range(0, pool.size() - 1)
		if policy == 192:
			var targeted: Array = [base_id, base_id, "jammer", "chain", "borer"] if magazine_index == 0 else [base_id, "borer", base_id, "borer", base_id]
			for i in range(pool.size()):
				if _bullet_id(pool[i]) == str(targeted[slot % targeted.size()]):
					pick = i
					break
		elif policy < 36:
			var pattern: Array = patterns[(policy + magazine_index * (policy / 6)) % patterns.size()]
			var desired := str(pattern[slot % pattern.size()])
			for i in range(pool.size()):
				if _bullet_id(pool[i]) == desired:
					pick = i
					break
		result.append(pool[pick])
		pool.remove_at(pick)
	return result

func _bullet_id(bullet: BulletData) -> String:
	if not bullet.resource_path.is_empty(): return bullet.resource_path.get_file().get_basename()
	return str(_bullet_names.get(bullet.display_name, bullet.display_name))

func _enemies(cm) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in cm.enemies:
		result.append({"name": enemy.data.display_name, "hp": enemy.current_hp, "barrier": enemy.barrier_cells if enemy.is_stack_sponge else 0,
			"distance": enemy.current_distance, "def": enemy.current_def, "eva": enemy.current_evasion,
			"speed": enemy.current_speed, "phase": enemy.current_phase, "dead": enemy.is_dead()})
	return result
