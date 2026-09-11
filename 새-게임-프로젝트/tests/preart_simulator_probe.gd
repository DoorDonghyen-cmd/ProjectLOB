extends SceneTree
## Independent pre-art audit. Writes only to the isolated user:// selected by its launcher.
const CM := preload("res://scripts/core/combat_manager.gd")
const LobTest := preload("res://tests/lob_test.gd")

func _initialize() -> void:
	RunManager.save_path_override = "user://preart_simulator_meta.cfg"
	preload("res://scripts/core/playtest_logger.gd").enabled = false
	RunManager.meta_ascension_level = 0
	RunManager.infiltration_risk_level = 1
	if "--experience" in OS.get_cmdline_user_args():
		_experience()
		return
	var t := LobTest.new()
	preload("res://tests/suite_full_run.gd").run(t)
	preload("res://tests/suite_ammo_specialization.gd").run(t)
	preload("res://tests/suite_ascension.gd").run(t)
	preload("res://tests/suite_difficulty_curve.gd").run(t)
	preload("res://tests/suite_parts.gd").run(t)
	var suite_exit := t.summary()
	RunManager.meta_ascension_level = 0
	RunManager.infiltration_risk_level = 1
	var cases: Array[Dictionary] = []
	for gun_id in ["smg", "suppressor"]:
		cases.append(_burst(gun_id, ["impact"], false))
		cases.append(_burst(gun_id, ["opener", "impact"], false))
		cases.append(_burst(gun_id, ["impact"], true))
	var report := {"focused_suites": {"passed": t.passed, "failed": t.failed, "warned": t.warned}, "burst_cases": cases, "runtime_economy": _economy()}
	var f := FileAccess.open("user://preart_simulator_probe.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("PREART_PROBE=" + JSON.stringify(report))
	quit(suite_exit)

func _burst(gun_id: String, order: Array, underflow: bool) -> Dictionary:
	var cm := CM.new()
	var gun := load("res://resources/guns/%s.tres" % gun_id) as GunData
	var enemy := load("res://resources/enemies/neuro_caster.tres") as EnemyData
	var loadout: Array[BulletData] = []
	for i in range(order.size() - 1, -1, -1):
		loadout.append((load("res://resources/bullets/%s.tres" % order[i]) as BulletData).duplicate())
	var parts: Array[PartData] = []
	if underflow:
		parts.append(load("res://resources/parts/underflow.tres") as PartData)
	cm.start_encounter(gun, [enemy] as Array[EnemyData], loadout, parts)
	cm.confirm_loading(loadout)
	var target: EnemyInstance = cm.enemies[0]
	var before := target.current_distance
	var kb_events: Array[int] = []
	cm.enemy_knocked_back.connect(func(_target, _distance, amount): kb_events.append(amount))
	cm.fire()
	var result := {"gun": gun_id, "fire_order": order, "underflow": underflow,
		"enemy": "neuro_caster", "knockback_events": kb_events,
		"distance_before": before, "distance_after": target.current_distance,
		"total_knockback": target.current_distance - before,
		"remaining_hp": target.current_hp, "state": cm.state}
	cm.free()
	return result

func _economy() -> Dictionary:
	RunManager.meta_credits = 1000
	RunManager.meta_backpack_lvl = 0
	RunManager.meta_hp_armor_lvl = 0
	RunManager.meta_discount_unlocked = false
	RunManager.meta_vault_lvl = 0
	var purchases := 0
	for i in range(3):
		if RunManager.upgrade_meta_backpack(): purchases += 1
	for i in range(2):
		if RunManager.upgrade_meta_hp_armor(): purchases += 1
	if RunManager.upgrade_meta_discount(): purchases += 1
	for i in range(3):
		if RunManager.upgrade_meta_vault(): purchases += 1
	var spent := 1000 - RunManager.meta_credits
	var rm := RunManager.new()
	rm.current_section = "section_e"
	rm.current_floor = 8
	RunManager.meta_ascension_level = 0
	var income_base := rm.end_run(true)
	RunManager.meta_ascension_level = 10
	var income_top := rm.end_run(true)
	return {"purchases": purchases, "meta_cost": spent, "full_run_income_a0": income_base, "full_run_income_a10": income_top, "actual_total_floors": rm.total_floors_climbed()}

const EXPERIENCE_ROOT := "D:/ProjectLoB/qa_runtime/preart_20260911/experience/"

func _experience() -> void:
	var results: Array[Dictionary] = []
	for spec in [
		["902113-experimental", "experimental", "checkpoint_0017_017_combat.json", 17, ["경량탄", "경량탄", "경량탄", "경량탄", "장약 증폭탄"]],
		["731042-beginner", "beginner", "checkpoint_0030_030_combat.json", 30, ["경량탄", "경량탄", "경량탄", "천공탄", "천공탄"]],
	]:
		var base := EXPERIENCE_ROOT + str(spec[0]) + "/artifacts/"
		var checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "ui/" + str(spec[2])))
		var view: Dictionary = checkpoint.player_view
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "reports/" + str(spec[1]) + ".json"))
		var original = _from_public(view)
		var pending: Array[String] = []
		for action in report.actions:
			if int(action.step) < int(spec[3]): continue
			match str(action.action):
				"load": pending.append(str(action.choice_id))
				"confirm_load":
					_load_named(original, pending)
					pending.clear()
				"fire": original.fire()
				"reload": original.request_reload()
		var original_result := _combat_result(original)
		original.free()
		var firsts: Array[Array] = []
		_permute_unique(spec[4], [], firsts)
		var seconds: Array[Array] = []
		_permute_unique(["경량탄", "경량탄", "경량탄", "천공탄", "천공탄"], [], seconds)
		var tested := 0
		var wins := 0
		var witness: Dictionary = {}
		for first in firsts:
			for second in seconds:
				var cm = _from_public(view)
				var legal := _fire_named(cm, first)
				if legal and cm.state != CM.State.LOST and cm.state != CM.State.WON:
					cm.request_reload()
					if cm.state != CM.State.LOST: legal = _fire_named(cm, second)
				tested += 1
				if legal and cm.state == CM.State.WON:
					wins += 1
					if witness.is_empty() or int(cm.battle_stats.shots_fired) < int(witness.shots):
						witness = _combat_result(cm)
						witness["fire_orders"] = [first, second]
				cm.free()
		results.append({"case": spec[0], "checkpoint": base + "ui/" + str(spec[2]), "public_enemies": view.enemies,
			"public_available_ammo": view.available_ammo, "parts": [], "original_replay": original_result,
			"candidate_paths": tested, "winning_paths": wins, "winning_witness": witness})
	var f := FileAccess.open("user://preart_experience_counterexamples.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "\t"))
	f.close()
	for result in results:
		print("COUNTEREXAMPLE=" + JSON.stringify({"case": result.case, "original_replay": result.original_replay,
			"candidate_paths": result.candidate_paths, "winning_paths": result.winning_paths, "winning_witness": result.winning_witness}))
	quit(0)

func _from_public(view: Dictionary):
	var cm := CM.new()
	var enemies: Array[EnemyData] = []
	var type_ids := {"광학 굴절병": "dodger", "진압 방패병": "tank", "폭동 돌격병": "rusher"}
	for slot in range(view.enemies.size()):
		var row: Dictionary = view.enemies[slot]
		var data := (load("res://resources/enemies/%s.tres" % type_ids[row.display_name]) as EnemyData).duplicate()
		data.max_hp = int(row.hp)
		data.defense = int(row.defense)
		data.evasion = int(row.evasion)
		data.speed = int(row.speed)
		data.start_distance = int(row.distance) - slot * 2
		enemies.append(data)
	var deck: Array[BulletData] = []
	var basic: BulletData = null
	for item in view.available_ammo:
		var bullet := BulletData.new()
		for key in ["display_name", "accuracy", "damage", "penetration", "knockback", "slow", "effect_type", "effect_value", "is_basic", "role", "specialty", "weapon_class"]:
			bullet.set(key, item.bullet[key])
		if bool(item.bullet.is_basic): basic = bullet
		else:
			for i in range(int(item.count)): deck.append(bullet.duplicate())
	cm.start_encounter(load("res://resources/guns/revolver.tres") as GunData, enemies, deck, [] as Array[PartData], basic)
	return cm

func _load_named(cm, load_order: Array) -> bool:
	var available: Array[BulletData] = cm.draw_pile.duplicate()
	var loadout: Array[BulletData] = []
	var basics := 0
	for bullet_name in load_order:
		if str(bullet_name) == str(cm.basic_supply_bullet.display_name):
			basics += 1
			if basics > cm.basic_supply_current: return false
			loadout.append(cm.basic_supply_bullet)
		else:
			var found := false
			for i in range(available.size()):
				if available[i].display_name == str(bullet_name):
					loadout.append(available[i])
					available.remove_at(i)
					found = true
					break
			if not found: return false
	cm.confirm_loading(loadout)
	return cm.magazine.get_remaining() == loadout.size()

func _fire_named(cm, fire_order: Array) -> bool:
	var reverse := fire_order.duplicate()
	reverse.reverse()
	if not _load_named(cm, reverse): return false
	while not cm.magazine.is_empty() and cm.state == CM.State.PLAYER_TURN:
		cm.fire()
	return true

func _combat_result(cm) -> Dictionary:
	var snapshots: Array[Dictionary] = []
	for enemy in cm.enemies:
		snapshots.append({"name": enemy.data.display_name, "hp": enemy.current_hp, "distance": enemy.current_distance,
			"defense": enemy.current_def, "evasion": enemy.current_evasion})
	return {"state": CM.State.keys()[cm.state], "shots": cm.battle_stats.shots_fired,
		"reloads": cm.telemetry_reload_count, "misses": cm.battle_stats.misses,
		"zero_damage_hits": cm.battle_stats.zero_damage_hits, "enemies": snapshots}

func _permute_unique(remaining: Array, current: Array, output: Array[Array]) -> void:
	if remaining.is_empty():
		output.append(current.duplicate())
		return
	var used := {}
	for i in range(remaining.size()):
		if used.has(remaining[i]): continue
		used[remaining[i]] = true
		var rest := remaining.duplicate()
		var item = rest.pop_at(i)
		current.append(item)
		_permute_unique(rest, current, output)
		current.pop_back()
