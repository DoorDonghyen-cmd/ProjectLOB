extends RefCounted
## 탄환 v6 튜닝 후보를 런타임에 적용하지 않고 검증하는 순수 결정론 프로브.
##
## - 후보 기반탄의 총기 시그니처 포함 사이클 화력을 계산한다.
## - v6 DEF 상한 3 계약을 적용한 적 상태에서 거리별 도달성을 측정한다.
## - 기반탄 + 보조탄 6종으로 만들 수 있는 탄창 순서를 전수 조사한다.

const CANDIDATE_CSV := "res://tests/reference/bullet_stats_v6_tuned_candidate.csv"
const DPT_MIN := 2.14
const DPT_MAX := 3.33

const GUN_IDS: Array[String] = [
	"revolver", "trickster", "smg", "gambler", "heavy",
	"stance_hunter", "suppressor", "dmr", "shotgun",
]
const ENEMY_IDS: Array[String] = [
	"rusher", "tank", "dodger", "caster", "absorber_mech", "scrambler_drone",
	"sentry_drone", "nano_stalker", "neuro_caster",
	"boss_director", "boss_seraph", "boss_omega", "boss_lob_core",
]
const ORDINARY_ENEMY_IDS: Array[String] = [
	"rusher", "tank", "dodger", "caster", "absorber_mech", "scrambler_drone",
	"sentry_drone", "neuro_caster",
]
const SIGNATURE_ENEMY_IDS: Array[String] = [
	"nano_stalker", "boss_director", "boss_seraph", "boss_omega", "boss_lob_core",
]
const FIRST_ARMORY_ENEMY_IDS: Array[String] = ["rusher", "tank", "dodger"]
const SUPPORT_IDS: Array[String] = [
	"marker", "borer", "jammer", "shred", "guide", "align",
]
const CONTROL_IDS: Array[String] = ["impact", "adhesive"]
const BASE_BY_CLASS := {
	Enums.WeaponClass.PISTOL: "cal_9mm",
	Enums.WeaponClass.SMG: "cal_45acp",
	Enums.WeaponClass.RIFLE: "cal_556",
	Enums.WeaponClass.DMR: "cal_762",
	Enums.WeaponClass.SHOTGUN: "cal_12g",
}
## 현행 시작 덱의 "특수A 2발 + 특수B 1발" 수량 계약을 유지한 v6 안전 패키지 후보.
const START_PACKAGE_BY_CLASS := {
	Enums.WeaponClass.PISTOL: {"borer": 2, "shred": 1},
	Enums.WeaponClass.SMG: {"borer": 2, "shred": 1},
	Enums.WeaponClass.RIFLE: {"borer": 2, "marker": 1},
	Enums.WeaponClass.DMR: {"borer": 2, "shred": 1},
	Enums.WeaponClass.SHOTGUN: {"borer": 2, "impact": 1},
}

static var _order_cache: Dictionary = {}


static func _csv_rows() -> Dictionary:
	var file := FileAccess.open(CANDIDATE_CSV, FileAccess.READ)
	var headers := file.get_csv_line()
	var columns := {}
	for i in range(headers.size()):
		columns[str(headers[i])] = i
	var rows := {}
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < headers.size() or str(line[0]).is_empty():
			continue
		var id := str(line[columns["id"]])
		rows[id] = {
			"id": id,
			"class": str(line[columns["class"]]),
			"is_basic": str(line[columns["is_basic"]]) == "true",
			"damage": int(line[columns["damage"]]),
			"penetration": int(line[columns["penetration"]]),
			"accuracy": int(line[columns["accuracy"]]),
			"knockback": int(line[columns["knockback"]]),
			"slow": int(line[columns["slow"]]),
		}
	file.close()
	return rows


static func _gun_profile(gun_id: String, tuned: bool) -> Dictionary:
	var row: Dictionary = DataLoader.get_gun(gun_id)
	var profile := {
		"id": gun_id,
		"class": int(row["class"]),
		"fire_mode": int(row["fire_mode"]),
		"capacity": int(row["magazine_capacity"]) + (1 if bool(row["has_chamber"]) else 0),
		"reload_turns": int(row["reload_turns"]),
		"dmg_bonus": int(row["passive_dmg_bonus"]),
		"pen_bonus": int(row["passive_pen_bonus"]),
		"acc_bonus": int(row["passive_acc_bonus"]),
		"knockback_bonus": int(row["passive_knockback_bonus"]),
		"gambler_tuned": false,
	}
	if tuned:
		# 기반탄만 낮춰서는 현재 깊이×2와 제압형 3턴 리로드를 같은 화력 밴드에 넣을 수 없다.
		if gun_id == "gambler":
			profile["dmg_bonus"] = 0
			profile["gambler_tuned"] = true
		elif gun_id == "suppressor":
			profile["reload_turns"] = 4
	return profile


static func _cycle_profile(gun_id: String, ammo_rows: Dictionary, tuned: bool) -> Dictionary:
	var gun := _gun_profile(gun_id, tuned)
	var base_id := str(BASE_BY_CLASS[int(gun["class"])])
	var base: Dictionary = ammo_rows[base_id]
	var shots := int(gun["capacity"])
	var total_damage := 0
	for shot_index in range(shots):
		var remaining_before_fire := shots - shot_index
		var shot_damage := int(base["damage"]) + int(gun["dmg_bonus"])
		if gun_id == "gambler":
			var depth := remaining_before_fire - 1
			shot_damage += floori(float(depth) / 2.0) \
				if bool(gun["gambler_tuned"]) else depth * 2
		total_damage += maxi(shot_damage, 0)
	var cycle_turns := (1 + int(gun["reload_turns"])) \
		if int(gun["fire_mode"]) == Enums.FireMode.FULL_AUTO \
		else shots + int(gun["reload_turns"])
	var dpt := snappedf(float(total_damage) / float(cycle_turns), 0.01)
	var in_band := dpt >= DPT_MIN and dpt <= DPT_MAX + 0.001
	# 샷건은 시작 거리 ACC -4 때문에 기반탄 직통이 0/13이다.
	# 종이 DPT를 맞추려고 DMG를 깎으면 유일 최대 피해 정체성만 사라지므로 거리 게이트 예외로 둔다.
	var range_gated_exception := gun_id == "shotgun" and dpt > DPT_MAX
	return {
		"gun_id": gun_id,
		"base_id": base_id,
		"shots": shots,
		"reload_turns": int(gun["reload_turns"]),
		"cycle_turns": cycle_turns,
		"cycle_damage": total_damage,
		"cycle_dpt": dpt,
		"in_band": in_band,
		"range_gated_exception": range_gated_exception,
		"accepted": in_band or range_gated_exception,
		"dmg_bonus": int(gun["dmg_bonus"]),
		"gambler_tuned": bool(gun["gambler_tuned"]),
	}


static func _enemy_state(enemy_id: String, distance_delta: int = 0) -> Dictionary:
	var row: Dictionary = DataLoader.get_enemy(enemy_id)
	var resource := load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData
	var archetype := int(row["archetype"])
	var state := {
		"id": enemy_id,
		"archetype": archetype,
		"hp": int(row["max_hp"]),
		"max_hp": int(row["max_hp"]),
		# v6 계약: 정적·태세 DEF 모두 3을 상한으로 정규화한다.
		"def": mini(int(row["defense"]), 3),
		"eva": int(row["evasion"]),
		"speed": int(row["speed"]),
		"distance": maxi(int(row["start_distance"]) + distance_delta, 1),
		"start_distance": maxi(int(row["start_distance"]) + distance_delta, 1),
		"knockback_resistance": int(row["knockback_resistance"]),
		"stance": "none",
		"shot_counter": 0,
		"stance_interval": int(resource.stance_shift_interval) if resource else 3,
		"triple_stance": false,
		"barrier_mode": false,
		"barrier": 0,
		"barrier_initial": 0,
		"lob_phase": 0,
		"slow": 0,
		"buttstroke_used": false,
		"lost": false,
	}
	match archetype:
		Enums.EnemyArchetype.TANK:
			state["stance"] = "shield"
		Enums.EnemyArchetype.DODGER:
			state["stance"] = "dodger"
		Enums.EnemyArchetype.CASTER:
			state["speed"] = 0
		Enums.EnemyArchetype.ABSORBER:
			state["barrier_mode"] = true
			state["barrier"] = 3
			state["barrier_initial"] = 3
			state["hp"] = 99
		Enums.EnemyArchetype.SCRAMBLER:
			state["stance"] = "shield"
			state["def"] = 3
			state["eva"] = 1
			state["speed"] = 1
		Enums.EnemyArchetype.BOSS_TANK_DODGE:
			state["stance"] = "shield"
		Enums.EnemyArchetype.BOSS_CASTER_SPONGE:
			state["barrier_mode"] = true
			state["barrier"] = 4
			state["barrier_initial"] = 4
			state["hp"] = 99
			state["speed"] = 0
		Enums.EnemyArchetype.BOSS_SCRAMBLER:
			state["stance"] = "shield"
			state["triple_stance"] = true
			state["def"] = 3
		Enums.EnemyArchetype.BOSS_FINAL:
			state["barrier_mode"] = true
			state["barrier"] = 5
			state["barrier_initial"] = 5
			state["lob_phase"] = 1
			state["hp"] = 99
			state["speed"] = 0
	return state


static func _is_dead(state: Dictionary) -> bool:
	if bool(state["barrier_mode"]):
		return int(state["barrier"]) <= 0 and int(state["lob_phase"]) == 0
	return int(state["hp"]) <= 0


static func _apply_effective_damage(state: Dictionary, damage: int) -> void:
	# v6 의도 계약은 "유효 적중" 배리어다. 현행 런타임의 단순 명중 차감은 별도 드리프트로 보고한다.
	if damage <= 0:
		return
	if bool(state["barrier_mode"]):
		state["barrier"] = maxi(int(state["barrier"]) - 1, 0)
		if int(state["barrier"]) == 0 and int(state["lob_phase"]) == 1:
			state["lob_phase"] = 2
			state["barrier_mode"] = false
			state["hp"] = 30
			state["max_hp"] = 30
			state["speed"] = 1
			state["stance"] = "shield"
			state["def"] = 3
			state["eva"] = 1
			state["knockback_resistance"] = 2
	else:
		state["hp"] = maxi(int(state["hp"]) - damage, 0)


static func _shift_stance(state: Dictionary) -> void:
	if str(state["stance"]) == "none":
		return
	state["shot_counter"] = int(state["shot_counter"]) + 1
	if int(state["shot_counter"]) < int(state["stance_interval"]):
		return
	state["shot_counter"] = 0
	if bool(state["triple_stance"]):
		match str(state["stance"]):
			"shield":
				state["stance"] = "dodger"
				state["def"] = 0
				state["eva"] = 7
				state["speed"] = 2
			"dodger":
				state["stance"] = "rush"
				state["def"] = 1
				state["eva"] = 2
				state["speed"] = 4
			_:
				state["stance"] = "shield"
				state["def"] = 3
				state["eva"] = 1
				state["speed"] = 1
	else:
		if str(state["stance"]) == "shield":
			state["stance"] = "dodger"
			state["def"] = 0
			state["eva"] = 7
			state["speed"] = 3
		else:
			state["stance"] = "shield"
			state["def"] = 3
			state["eva"] = 1
			state["speed"] = 1


static func _advance(state: Dictionary) -> void:
	var movement := maxi(int(state["speed"]) - int(state["slow"]), 0)
	state["slow"] = 0
	state["distance"] = maxi(int(state["distance"]) - movement, 0)
	if int(state["distance"]) == 1 and not bool(state["buttstroke_used"]):
		state["buttstroke_used"] = true
		state["distance"] = 3
		state["slow"] = 99
	elif int(state["distance"]) <= 0:
		state["lost"] = true


static func _fire_one(
	gun: Dictionary,
	bullet: Dictionary,
	state: Dictionary,
	remaining_before_fire: int,
	links: Dictionary
) -> Dictionary:
	var next_acc := int(links["next_acc"])
	var next_pen := int(links["next_pen"])
	links["next_acc"] = 0
	links["next_pen"] = 0

	var stance_bypass := str(gun["id"]) == "stance_hunter" \
		and str(state["stance"]) != "none" and int(state["shot_counter"]) == 2
	var target_eva := 0 if (str(gun["id"]) == "dmr" and int(state["distance"]) > 1) \
		or stance_bypass else int(state["eva"])
	var distance_acc_penalty := -4 \
		if str(gun["id"]) == "shotgun" and int(state["distance"]) >= 4 else 0
	var natural_acc := int(bullet["accuracy"]) + int(gun["acc_bonus"]) \
		+ int(links["mag_acc"]) + distance_acc_penalty
	var natural_pen := int(bullet["penetration"]) + int(gun["pen_bonus"]) \
		+ int(links["mag_pen"]) + (99 if stance_bypass else 0)
	var total_acc := natural_acc + next_acc
	var total_pen := natural_pen + next_pen
	var hit := total_acc >= target_eva
	var penetrated := total_pen >= int(state["def"])
	var damage := 0
	var critical := false
	if hit and penetrated:
		damage = int(bullet["damage"]) + int(gun["dmg_bonus"])
		if str(gun["id"]) == "gambler":
			var depth := remaining_before_fire - 1
			damage += floori(float(depth) / 2.0) \
				if bool(gun["gambler_tuned"]) else depth * 2
		if str(gun["id"]) == "shotgun" and int(state["distance"]) <= 2:
			damage += 4
		if str(gun["id"]) == "dmr" and int(state["distance"]) <= 1:
			damage -= 2
		damage = maxi(damage, 0)
		var natural_effective := natural_acc >= target_eva and natural_pen >= int(state["def"])
		critical = (next_acc > 0 or next_pen > 0) and not natural_effective
		if critical:
			damage = floori(float(damage) * 1.5)

	_apply_effective_damage(state, damage)

	# 지원탄 트리거. 다음 1발 버프는 유효 적중, 적 디버프는 명중, 잔여 버프는 유효 적중.
	match str(bullet["id"]):
		"marker":
			if damage > 0:
				links["next_acc"] = 3
		"borer":
			if damage > 0:
				links["next_pen"] = 3
		"jammer":
			if hit:
				state["eva"] = maxi(int(state["eva"]) - 2, 0)
		"shred":
			if hit:
				state["def"] = maxi(int(state["def"]) - 2, 0)
		"guide":
			if damage > 0:
				links["mag_acc"] = int(links["mag_acc"]) + 1
		"align":
			if damage > 0:
				links["mag_pen"] = int(links["mag_pen"]) + 1

	if hit:
		var knockback := int(bullet["knockback"]) + int(gun["knockback_bonus"])
		if str(gun["id"]) == "shotgun" and int(state["distance"]) <= 2:
			knockback = maxi(knockback - int(gun["knockback_bonus"]), 0)
		var effective_kb := maxi(knockback - int(state["knockback_resistance"]), 0)
		state["distance"] = int(state["distance"]) + effective_kb
		if int(bullet["slow"]) > 0:
			state["slow"] = int(state["slow"]) + int(bullet["slow"])

	return {
		"id": str(bullet["id"]),
		"hit": hit,
		"penetrated": penetrated if hit else false,
		"damage": damage,
		"critical": critical,
		"distance_before_advance": int(state["distance"]),
		"def_after": int(state["def"]),
		"eva_after": int(state["eva"]),
	}


static func _simulate(
	gun: Dictionary,
	enemy_template: Dictionary,
	fire_order: Array,
	ammo_rows: Dictionary,
	capture_trace: bool = false
) -> Dictionary:
	var state: Dictionary = enemy_template.duplicate(true)
	var links := {"next_acc": 0, "next_pen": 0, "mag_acc": 0, "mag_pen": 0}
	var total_damage := 0
	var effective_hits := 0
	var criticals := 0
	var trace: Array = []
	var fired := 0
	var full_auto := int(gun["fire_mode"]) == Enums.FireMode.FULL_AUTO
	for ammo_id_variant in fire_order:
		if _is_dead(state) or bool(state["lost"]):
			break
		var ammo_id := str(ammo_id_variant)
		var remaining_before_fire := fire_order.size() - fired
		var shot := _fire_one(gun, ammo_rows[ammo_id], state, remaining_before_fire, links)
		fired += 1
		total_damage += int(shot["damage"])
		if int(shot["damage"]) > 0:
			effective_hits += 1
		if bool(shot["critical"]):
			criticals += 1
		if capture_trace:
			trace.append(shot)
		if _is_dead(state):
			break
		if not full_auto:
			_advance(state)
			if bool(state["lost"]):
				break
		_shift_stance(state)
	if full_auto and not _is_dead(state) and not bool(state["lost"]):
		_advance(state)

	var reload_state: Dictionary = state.duplicate(true)
	if not _is_dead(reload_state) and not bool(reload_state["lost"]):
		for _turn in range(int(gun["reload_turns"])):
			_advance(reload_state)
			if bool(reload_state["lost"]):
				break
	var outcome := {
		"dead": _is_dead(state),
		"lost": bool(state["lost"]),
		"hp": int(state["hp"]),
		"barrier": int(state["barrier"]),
		"barrier_initial": int(state["barrier_initial"]),
		"phase": int(state["lob_phase"]),
		"distance": int(state["distance"]),
		"remaining_ammo": fire_order.size() - fired,
		"fired": fired,
		"effective_hits": effective_hits,
		"criticals": criticals,
		"total_damage": total_damage,
		"final_def": int(state["def"]),
		"final_eva": int(state["eva"]),
		"reload_survivable": not bool(reload_state["lost"]),
		"distance_after_reload": int(reload_state["distance"]),
	}
	if capture_trace:
		outcome["trace"] = trace
	return outcome


static func _order_rank(outcome: Dictionary) -> int:
	if bool(outcome["dead"]) and not bool(outcome["lost"]):
		return 1000000000 \
			+ int(outcome["remaining_ammo"]) * 1000000 \
			+ int(outcome["distance"]) * 10000 \
			+ int(outcome["total_damage"])
	var barrier_progress := int(outcome["barrier_initial"]) - int(outcome["barrier"])
	return (500000000 if bool(outcome["reload_survivable"]) else 0) \
		+ barrier_progress * 10000000 \
		+ int(outcome["effective_hits"]) * 1000000 \
		+ int(outcome["total_damage"]) * 10000 \
		+ int(outcome["distance"]) * 10 \
		- (100000000 if bool(outcome["lost"]) else 0)


static func _build_orders(
	base_id: String,
	capacity: int,
	option_ids: Array,
	current: Array,
	used_supports: Dictionary,
	result: Array
) -> void:
	if current.size() == capacity:
		result.append(current.duplicate())
		return
	current.append(base_id)
	_build_orders(base_id, capacity, option_ids, current, used_supports, result)
	current.pop_back()
	for support_id_variant in option_ids:
		var support_id := str(support_id_variant)
		if bool(used_supports.get(support_id, false)):
			continue
		used_supports[support_id] = true
		current.append(support_id)
		_build_orders(base_id, capacity, option_ids, current, used_supports, result)
		current.pop_back()
		used_supports.erase(support_id)


static func _orders(base_id: String, capacity: int, option_ids: Array) -> Array:
	var key := "%s:%d:%s" % [base_id, capacity, ",".join(option_ids)]
	if _order_cache.has(key):
		return _order_cache[key]
	var result: Array = []
	_build_orders(base_id, capacity, option_ids, [], {}, result)
	_order_cache[key] = result
	return result


static func _build_limited_orders(
	base_id: String,
	capacity: int,
	limits: Dictionary,
	current: Array,
	result: Array
) -> void:
	if current.size() == capacity:
		result.append(current.duplicate())
		return
	current.append(base_id)
	_build_limited_orders(base_id, capacity, limits, current, result)
	current.pop_back()
	for ammo_id_variant in limits.keys():
		var ammo_id := str(ammo_id_variant)
		var count := int(limits[ammo_id])
		if count <= 0:
			continue
		limits[ammo_id] = count - 1
		current.append(ammo_id)
		_build_limited_orders(base_id, capacity, limits, current, result)
		current.pop_back()
		limits[ammo_id] = count


static func _limited_orders(base_id: String, capacity: int, limits: Dictionary) -> Array:
	var result: Array = []
	_build_limited_orders(base_id, capacity, limits.duplicate(), [], result)
	return result


static func _support_set(order: Array, base_id: String) -> Array:
	var result: Array = []
	for ammo_id_variant in order:
		var ammo_id := str(ammo_id_variant)
		if ammo_id != base_id and not result.has(ammo_id):
			result.append(ammo_id)
	result.sort()
	return result


static func _solution_entry(
	gun: Dictionary,
	enemy_id: String,
	distance_delta: int,
	ammo_rows: Dictionary,
	orders: Array
) -> Dictionary:
	var enemy := _enemy_state(enemy_id, distance_delta)
	var best_rank := -1000000000
	var best_order: Array = []
	var best_outcome := {}
	var winning_orders := 0
	var safe_progress_orders := 0
	var continuable_orders := 0
	for order in orders:
		var outcome := _simulate(gun, enemy, order, ammo_rows)
		if bool(outcome["dead"]) and not bool(outcome["lost"]):
			winning_orders += 1
		if int(outcome["effective_hits"]) > 0 and not bool(outcome["lost"]):
			safe_progress_orders += 1
			if bool(outcome["reload_survivable"]):
				continuable_orders += 1
		var rank := _order_rank(outcome)
		if rank > best_rank:
			best_rank = rank
			best_order = order.duplicate()
			best_outcome = outcome
	# 최적 경로만 추적을 다시 떠 JSON을 사람이 읽을 수 있게 한다.
	if not best_order.is_empty():
		best_outcome = _simulate(gun, enemy, best_order, ammo_rows, true)
	return {
		"enemy_id": enemy_id,
		"distance_delta": distance_delta,
		"winning_orders": winning_orders,
		"safe_progress_orders": safe_progress_orders,
		"continuable_orders": continuable_orders,
		"best_order": best_order,
		"best_supports": _support_set(best_order, str(BASE_BY_CLASS[int(gun["class"])])),
		"best_outcome": best_outcome,
	}


static func _first_shot_entry(
	gun: Dictionary,
	enemy_id: String,
	distance: int,
	ammo_rows: Dictionary
) -> Dictionary:
	var enemy := _enemy_state(enemy_id)
	enemy["distance"] = distance
	enemy["start_distance"] = distance
	var base_id := str(BASE_BY_CLASS[int(gun["class"])])
	var outcome := _simulate(gun, enemy, [base_id], ammo_rows, true)
	var shot: Dictionary = outcome["trace"][0]
	return {
		"distance": distance,
		"hit": bool(shot["hit"]),
		"penetrated": bool(shot["penetrated"]),
		"damage": int(shot["damage"]),
		"critical": bool(shot["critical"]),
	}


static func _search_starting_packages(ammo_rows: Dictionary) -> Array:
	var option_ids: Array = SUPPORT_IDS.duplicate()
	option_ids.append_array(CONTROL_IDS)
	var result: Array = []
	for cls_variant in BASE_BY_CLASS:
		var cls := int(cls_variant)
		var base_id := str(BASE_BY_CLASS[cls])
		var class_guns: Array = []
		for gun_id in GUN_IDS:
			var gun := _gun_profile(gun_id, true)
			if int(gun["class"]) == cls:
				class_guns.append(gun)
		var best_failures := 999999
		var best_robustness := -1
		var best_package := {}
		for primary_variant in option_ids:
			var primary := str(primary_variant)
			for secondary_variant in option_ids:
				var secondary := str(secondary_variant)
				if secondary == primary:
					continue
				var limits := {primary: 2, secondary: 1}
				var failures := 0
				var robustness := 0
				for gun_variant in class_guns:
					var gun: Dictionary = gun_variant
					var orders := _limited_orders(base_id, int(gun["capacity"]), limits)
					for enemy_id in FIRST_ARMORY_ENEMY_IDS:
						for distance_delta in [0, -2]:
							var entry := _solution_entry(
								gun, enemy_id, distance_delta, ammo_rows, orders
							)
							var solved := int(entry["winning_orders"]) > 0 \
								or int(entry["continuable_orders"]) > 0
							if not solved:
								failures += 1
							robustness += int(entry["winning_orders"]) \
								+ int(entry["continuable_orders"])
				if failures < best_failures \
						or (failures == best_failures and robustness > best_robustness):
					best_failures = failures
					best_robustness = robustness
					best_package = limits.duplicate()
		result.append({
			"class": cls,
			"base_id": base_id,
			"gun_ids": class_guns.map(func(g): return str(g["id"])),
			"best_package": best_package,
			"failures": best_failures,
			"robustness": best_robustness,
		})
	return result


static func generate_report() -> Dictionary:
	RunManager.infiltration_risk_level = 1
	var ammo_rows := _csv_rows()
	var report := {
		"schema": "lob.ammo_v6_tuning",
		"version": 1,
		"candidate_csv": CANDIDATE_CSV,
		"dpt_band": [DPT_MIN, DPT_MAX],
		"base_damage": {},
		"current_signature_cycles": [],
		"tuned_signature_cycles": [],
		"distance_profiles": [],
		"solutions": [],
		"ordinary_failures": [],
		"control_required": [],
		"signature_failures": [],
		"starting_deck_checks": [],
		"starting_deck_failures": [],
		"starting_package_search": [],
		"runtime_contract_drifts": [
			"ABSORBER barrier currently decrements on any ACC hit; v6 solver requires damage > 0.",
			"Stance Hunter bypass checks shot_counter == 2, so Omega interval 2 never receives the bypass.",
		],
	}
	for cls_variant in BASE_BY_CLASS:
		var base_id := str(BASE_BY_CLASS[cls_variant])
		report["base_damage"][base_id] = int(ammo_rows[base_id]["damage"])
	for gun_id in GUN_IDS:
		report["current_signature_cycles"].append(_cycle_profile(gun_id, ammo_rows, false))
		report["tuned_signature_cycles"].append(_cycle_profile(gun_id, ammo_rows, true))

	for gun_id in GUN_IDS:
		var gun := _gun_profile(gun_id, true)
		var base_id := str(BASE_BY_CLASS[int(gun["class"])])
		var orders := _orders(base_id, int(gun["capacity"]), SUPPORT_IDS)
		var distance_entry := {
			"gun_id": gun_id,
			"enemies": [],
		}
		for enemy_id in ENEMY_IDS:
			var start_distance := int(DataLoader.get_enemy(enemy_id)["start_distance"])
			distance_entry["enemies"].append({
				"enemy_id": enemy_id,
				"start": _first_shot_entry(gun, enemy_id, start_distance, ammo_rows),
				"air_duct": _first_shot_entry(gun, enemy_id, maxi(start_distance - 2, 1), ammo_rows),
				"close": _first_shot_entry(gun, enemy_id, 2, ammo_rows),
			})

			var normal := _solution_entry(gun, enemy_id, 0, ammo_rows, orders)
			var pressure := _solution_entry(gun, enemy_id, -2, ammo_rows, orders)
			var solution := {
				"gun_id": gun_id,
				"enemy_id": enemy_id,
				"order_count": orders.size(),
				"normal": normal,
				"air_duct": pressure,
			}
			var normal_solved := int(normal["winning_orders"]) > 0 \
				or int(normal["continuable_orders"]) > 0
			var pressure_solved := int(pressure["winning_orders"]) > 0 \
				or int(pressure["continuable_orders"]) > 0
			if ORDINARY_ENEMY_IDS.has(enemy_id) and (not normal_solved or not pressure_solved):
				var rescue_ids: Array = SUPPORT_IDS.duplicate()
				rescue_ids.append_array(CONTROL_IDS)
				var rescue_orders := _orders(base_id, int(gun["capacity"]), rescue_ids)
				var rescue_normal := _solution_entry(gun, enemy_id, 0, ammo_rows, rescue_orders)
				var rescue_pressure := _solution_entry(gun, enemy_id, -2, ammo_rows, rescue_orders)
				solution["control_rescue"] = {
					"order_count": rescue_orders.size(),
					"normal": rescue_normal,
					"air_duct": rescue_pressure,
				}
				var rescue_normal_solved := int(rescue_normal["winning_orders"]) > 0 \
					or int(rescue_normal["continuable_orders"]) > 0
				var rescue_pressure_solved := int(rescue_pressure["winning_orders"]) > 0 \
					or int(rescue_pressure["continuable_orders"]) > 0
				if rescue_normal_solved and rescue_pressure_solved:
					report["control_required"].append({
						"gun_id": gun_id,
						"enemy_id": enemy_id,
						"normal_best": rescue_normal["best_order"],
						"air_duct_best": rescue_pressure["best_order"],
					})
				else:
					report["ordinary_failures"].append({
						"gun_id": gun_id,
						"enemy_id": enemy_id,
						"normal_wins": int(normal["winning_orders"]),
						"normal_continuable": int(normal["continuable_orders"]),
						"air_duct_wins": int(pressure["winning_orders"]),
						"air_duct_continuable": int(pressure["continuable_orders"]),
					})
			elif SIGNATURE_ENEMY_IDS.has(enemy_id) \
					and int(normal["safe_progress_orders"]) == 0:
				report["signature_failures"].append({
					"gun_id": gun_id,
					"enemy_id": enemy_id,
				})
			report["solutions"].append(solution)
		report["distance_profiles"].append(distance_entry)

		var start_limits: Dictionary = START_PACKAGE_BY_CLASS[int(gun["class"])]
		var starting_orders := _limited_orders(base_id, int(gun["capacity"]), start_limits)
		for first_enemy_id in FIRST_ARMORY_ENEMY_IDS:
			var start_normal := _solution_entry(
				gun, first_enemy_id, 0, ammo_rows, starting_orders
			)
			var start_pressure := _solution_entry(
				gun, first_enemy_id, -2, ammo_rows, starting_orders
			)
			var start_entry := {
				"gun_id": gun_id,
				"enemy_id": first_enemy_id,
				"package": start_limits.duplicate(),
				"order_count": starting_orders.size(),
				"normal": start_normal,
				"air_duct": start_pressure,
			}
			report["starting_deck_checks"].append(start_entry)
			var normal_ok := int(start_normal["winning_orders"]) > 0 \
				or int(start_normal["continuable_orders"]) > 0
			var pressure_ok := int(start_pressure["winning_orders"]) > 0 \
				or int(start_pressure["continuable_orders"]) > 0
			if not normal_ok or not pressure_ok:
				report["starting_deck_failures"].append({
					"gun_id": gun_id,
					"enemy_id": first_enemy_id,
					"normal_ok": normal_ok,
					"air_duct_ok": pressure_ok,
				})
	report["starting_package_search"] = _search_starting_packages(ammo_rows)
	return report
