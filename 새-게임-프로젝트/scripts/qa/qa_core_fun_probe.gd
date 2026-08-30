class_name QACoreFunProbe
extends RefCounted
## 동일 탄환 멀티셋의 순서만 바꿔 실제 CombatManager 결과가 달라지는지 측정한다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const SCENARIOS := [
	{
		"id": "accuracy_gate",
		"label": "회피 자물쇠",
		"enemy_id": "dodger",
		"setup_axis": "accuracy",
		"planned": ["marker", "cal_12g"],
		"reversed": ["cal_12g", "marker"],
		"basic": ["cal_12g", "cal_12g"],
	},
	{
		"id": "penetration_gate",
		"label": "장갑 자물쇠",
		"enemy_id": "tank",
		"setup_axis": "penetration",
		"planned": ["borer", "cal_9mm"],
		"reversed": ["cal_9mm", "borer"],
		"basic": ["cal_9mm", "cal_9mm"],
	},
	{
		"id": "damage_payoff",
		"label": "피해 증폭 결산",
		"enemy_id": "rusher",
		"setup_axis": "damage",
		"planned": ["chain", "cal_9mm"],
		"reversed": ["cal_9mm", "chain"],
		"basic": ["cal_9mm", "cal_9mm"],
	},
	{
		"id": "last_shot_payoff",
		"label": "마지막 탄 결산",
		"enemy_id": "rusher",
		"setup_axis": "position",
		"planned": ["cal_9mm", "finale"],
		"reversed": ["finale", "cal_9mm"],
		"basic": ["cal_9mm", "cal_9mm"],
	},
]


static func generate_report() -> Dictionary:
	RunManager.infiltration_risk_level = 1
	var results: Array[Dictionary] = []
	var order_sensitive := 0
	var planned_better := 0
	var mixed_better_than_basic := 0
	var axes: Dictionary = {}
	for scenario_variant in SCENARIOS:
		var scenario: Dictionary = scenario_variant
		var planned := _fight(str(scenario.enemy_id), scenario.planned)
		var reversed := _fight(str(scenario.enemy_id), scenario.reversed)
		var basic := _fight(str(scenario.enemy_id), scenario.basic)
		var sensitive := _outcome_signature(planned) != _outcome_signature(reversed)
		var planned_wins := _rank(planned) > _rank(reversed)
		var mixed_wins := _rank(planned) > _rank(basic)
		if sensitive: order_sensitive += 1
		if planned_wins: planned_better += 1
		if mixed_wins: mixed_better_than_basic += 1
		axes[str(scenario.setup_axis)] = true
		results.append({
			"scenario_id": str(scenario.id),
			"label": str(scenario.label),
			"enemy_id": str(scenario.enemy_id),
			"setup_axis": str(scenario.setup_axis),
			"same_multiset": _same_multiset(scenario.planned, scenario.reversed),
			"planned_fire_order": scenario.planned.duplicate(true),
			"reversed_fire_order": scenario.reversed.duplicate(true),
			"basic_fire_order": scenario.basic.duplicate(true),
			"planned": planned,
			"reversed": reversed,
			"basic": basic,
			"order_sensitive": sensitive,
			"planned_beats_reversed": planned_wins,
			"mixed_beats_basic": mixed_wins,
		})
	return {
		"schema_version": 1,
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"scenario_count": results.size(),
		"order_sensitive_scenarios": order_sensitive,
		"planned_better_scenarios": planned_better,
		"mixed_better_than_basic_scenarios": mixed_better_than_basic,
		"distinct_setup_axes": axes.keys(),
		"scenarios": results,
	}


static func save(report: Dictionary, path: String) -> Error:
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(report, "\t") + "\n")
	return OK


static func _fight(enemy_id: String, fire_order_variant: Array) -> Dictionary:
	var fire_order: Array = fire_order_variant
	var loadout: Array[BulletData] = []
	for index in range(fire_order.size() - 1, -1, -1):
		var source := load("res://resources/bullets/%s.tres" % str(fire_order[index])) as BulletData
		loadout.append(source.duplicate())
	var gun := (load("res://resources/guns/revolver.tres") as GunData).duplicate()
	var enemy_source := load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData
	var enemies: Array[EnemyData] = [enemy_source.duplicate()]
	var no_parts: Array[PartData] = []
	var observed := {"shots": 0, "hits": 0, "damage": 0, "damages": []}
	var cm = CombatManagerScript.new()
	cm.bullet_fired.connect(func(_bullet: BulletData, hit: bool, damage: int, _target: EnemyInstance, _remaining: int):
		observed.shots = int(observed.shots) + 1
		if hit: observed.hits = int(observed.hits) + 1
		observed.damage = int(observed.damage) + damage
		observed.damages.append(damage)
	)
	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)
	var guard := 0
	while cm.state not in [CombatManagerScript.State.WON, CombatManagerScript.State.LOST] \
			and not cm.magazine.is_empty() and guard < 12:
		guard += 1
		cm.fire()
	var target: EnemyInstance = cm.enemies[0]
	var result := {
		"won": target.is_dead(),
		"lost": cm.state == CombatManagerScript.State.LOST,
		"shots": int(observed.shots),
		"hits": int(observed.hits),
		"damage": int(observed.damage),
		"damages": observed.damages.duplicate(),
		"remaining_hp": int(target.current_hp),
		"final_distance": int(target.current_distance),
		"remaining_ammo": int(cm.magazine.get_remaining()),
	}
	cm.free()
	return result


static func _rank(outcome: Dictionary) -> int:
	if bool(outcome.won):
		return 1000000 + int(outcome.remaining_ammo) * 10000 + int(outcome.final_distance) * 100 - int(outcome.shots)
	return int(outcome.damage) * 10000 + int(outcome.final_distance) * 100 - int(outcome.remaining_hp)


static func _outcome_signature(outcome: Dictionary) -> String:
	return JSON.stringify([
		bool(outcome.won), bool(outcome.lost), int(outcome.damage), int(outcome.remaining_hp),
		int(outcome.final_distance), int(outcome.remaining_ammo), outcome.damages,
	])


static func _same_multiset(first: Array, second: Array) -> bool:
	var a := first.duplicate()
	var b := second.duplicate()
	a.sort()
	b.sort()
	return a == b
