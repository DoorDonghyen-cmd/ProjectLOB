extends RefCounted
## LIFO 순서 민감도 프로브.
##
## 같은 6발 멀티셋의 고유 발사 순서를 전부 열거해 실제 CombatManager로 전투하고,
## 적마다 최적 순서·승리 순서 수·피해 범위를 산출한다.
## v5 기준값과 v6 후보를 같은 측정기로 비교하기 위한 도구다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const BASELINE_VERSION := 1
const GUN_ID := "smg"
const AMMO_MULTISET: Array[String] = [
	"tuner_smg",
	"chain_smg",
	"finale_smg",
	"shred_rifle",
	"heavyslug_rifle",
	"heavyslug_rifle",
]
const ENEMY_IDS: Array[String] = [
	"rusher",
	"tank",
	"dodger",
	"caster",
	"absorber_mech",
	"scrambler_drone",
]


static func _enemy_data(id: String) -> EnemyData:
	var row: Dictionary = DataLoader.get_enemy(id)
	var d := EnemyData.new()
	d.display_name = str(row.display_name)
	d.archetype = int(row.archetype)
	d.max_hp = int(row.max_hp)
	d.defense = int(row.defense)
	d.evasion = int(row.evasion)
	d.speed = int(row.speed)
	d.start_distance = int(row.start_distance)
	d.knockback_resistance = int(row.knockback_resistance)
	return d


static func _unique_fire_orders() -> Array:
	var counts := {}
	for id in AMMO_MULTISET:
		counts[id] = int(counts.get(id, 0)) + 1
	var ids: Array = counts.keys()
	ids.sort()
	var result: Array = []
	_permute_unique(ids, counts, [], AMMO_MULTISET.size(), result)
	return result


static func _permute_unique(
	ids: Array,
	counts: Dictionary,
	current: Array,
	remaining: int,
	result: Array
) -> void:
	if remaining == 0:
		result.append(current.duplicate())
		return
	for id_variant in ids:
		var id := str(id_variant)
		var count := int(counts.get(id, 0))
		if count <= 0:
			continue
		counts[id] = count - 1
		current.append(id)
		_permute_unique(ids, counts, current, remaining - 1, result)
		current.pop_back()
		counts[id] = count


## 사람이 읽는 발사 순서를 LIFO 적재 순서로 뒤집어 실제 전투한다.
static func _simulate_order(enemy_id: String, fire_order: Array) -> Dictionary:
	var loadout: Array[BulletData] = []
	for i in range(fire_order.size() - 1, -1, -1):
		var bullet := load("res://resources/bullets/%s.tres" % str(fire_order[i])) as BulletData
		loadout.append(bullet)

	var cm = CombatManagerScript.new()
	var gun := load("res://resources/guns/%s.tres" % GUN_ID) as GunData
	var enemies: Array[EnemyData] = [_enemy_data(enemy_id)]
	var no_parts: Array[PartData] = []
	# 람다에서 정수 지역변수를 직접 증가시키면 캡처된 값만 바뀌고 바깥 값에 반영되지 않는다.
	# 참조형 Dictionary 하나에 누적해 실제 시그널 관측값을 보존한다.
	var observed := {
		"fired_count": 0,
		"hit_count": 0,
		"effective_hit_count": 0,
		"total_damage": 0,
	}
	cm.bullet_fired.connect(func(
		_bullet: BulletData,
		hit: bool,
		damage: int,
		_target: EnemyInstance,
		_remaining: int
	):
		observed.fired_count = int(observed.fired_count) + 1
		if hit:
			observed.hit_count = int(observed.hit_count) + 1
		if damage > 0:
			observed.effective_hit_count = int(observed.effective_hit_count) + 1
		observed.total_damage = int(observed.total_damage) + damage
	)
	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)

	var guard := 0
	while cm.state != CombatManager.State.WON \
			and cm.state != CombatManager.State.LOST \
			and not cm.magazine.is_empty() \
			and guard < 20:
		guard += 1
		cm.fire()

	var enemy: EnemyInstance = cm.enemies[0]
	var outcome := {
		"dead": enemy.is_dead(),
		"remaining_hp": enemy.current_hp,
		"remaining_ammo": cm.magazine.get_remaining(),
		"total_damage": int(observed.total_damage),
		"fired_count": int(observed.fired_count),
		"hit_count": int(observed.hit_count),
		"effective_hit_count": int(observed.effective_hit_count),
		"final_distance": enemy.current_distance,
		"final_def": enemy.current_def,
		"final_eva": enemy.current_evasion,
	}
	outcome["rank"] = _rank(outcome)
	cm.free()
	return outcome


## 처치 우선, 처치 시 탄 보존·거리 마진 우선, 미처치 시 피해·유효타 우선.
static func _rank(outcome: Dictionary) -> int:
	if bool(outcome.dead):
		return 1000000 \
			+ int(outcome.remaining_ammo) * 10000 \
			+ int(outcome.final_distance) * 100 \
			+ int(outcome.total_damage)
	return int(outcome.total_damage) * 10000 \
		+ int(outcome.effective_hit_count) * 100 \
		+ int(outcome.final_distance)


static func _order_key(order: Array) -> String:
	var parts: PackedStringArray = []
	for id in order:
		parts.append(str(id))
	return ">".join(parts)


static func generate_report() -> Dictionary:
	RunManager.infiltration_risk_level = 1
	var orders := _unique_fire_orders()
	var gun_row: Dictionary = DataLoader.get_gun(GUN_ID)
	var report := {
		"schema": "lob.lifo_depth_baseline",
		"version": BASELINE_VERSION,
		"ammo_version": "v5",
		"gun_id": GUN_ID,
		"magazine_capacity": int(gun_row.magazine_capacity),
		"has_chamber": bool(gun_row.has_chamber),
		"effective_capacity": int(gun_row.magazine_capacity) + (1 if bool(gun_row.has_chamber) else 0),
		"ammo_multiset": AMMO_MULTISET.duplicate(),
		"enemy_ids": ENEMY_IDS.duplicate(),
		"permutation_count": orders.size(),
		"enemies": [],
	}

	var best_order_keys := {}
	for enemy_id in ENEMY_IDS:
		var best_rank := -1
		var best_key := ""
		var best_order: Array = []
		var best_outcome := {}
		var winning_orders := 0
		var damage_min := 999999
		var damage_max := -1
		var canonical_outcome := {}

		for order in orders:
			var outcome := _simulate_order(enemy_id, order)
			var key := _order_key(order)
			var damage := int(outcome.total_damage)
			damage_min = mini(damage_min, damage)
			damage_max = maxi(damage_max, damage)
			if bool(outcome.dead):
				winning_orders += 1
			if key == _order_key(AMMO_MULTISET):
				canonical_outcome = outcome
			if int(outcome.rank) > best_rank \
					or (int(outcome.rank) == best_rank and (best_key.is_empty() or key < best_key)):
				best_rank = int(outcome.rank)
				best_key = key
				best_order = order.duplicate()
				best_outcome = outcome

		best_order_keys[best_key] = true
		report.enemies.append({
			"enemy_id": enemy_id,
			"best_order": best_order,
			"best_rank": best_rank,
			"best_outcome": best_outcome,
			"canonical_outcome": canonical_outcome,
			"winning_orders": winning_orders,
			"damage_min": damage_min,
			"damage_max": damage_max,
			"damage_spread": damage_max - damage_min,
		})

	report["distinct_best_orders"] = best_order_keys.size()
	report["enemy_specific_optima"] = best_order_keys.size() > 1
	return report
