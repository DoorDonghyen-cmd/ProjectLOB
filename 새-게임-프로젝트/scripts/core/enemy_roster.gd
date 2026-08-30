class_name EnemyRoster
extends RefCounted

const RandomStreamsScript := preload("res://scripts/core/random_streams.gd")

## 35층 연속 캠페인의 일반전 편성 정본.
## 관문은 CampaignContent가 담당하며, 이 파일은 일반·변종 9종의 학습 순서와 밀도만 관리한다.

const REGULAR_ENEMY_IDS: Array[String] = [
	"rusher", "tank", "dodger", "sentry_drone", "caster",
	"absorber_mech", "scrambler_drone", "nano_stalker", "neuro_caster",
]

const INTRODUCED_ENEMY_IDS := {
	"section_a": ["rusher", "tank", "dodger"],
	"section_b": ["sentry_drone", "caster"],
	"section_c": ["absorber_mech"],
	"section_d": ["scrambler_drone", "nano_stalker", "neuro_caster"],
	"section_e": [],
}

## section -> tier(초/중/종반) -> 후보 편성.
## 정점은 신규 자물쇠를 추가하지 않고 관리 계층까지 배운 상위 자물쇠를 고밀도로 재조합한다.
const REGULAR_ENCOUNTER_IDS := {
	"section_a": [
		[["rusher"], ["rusher", "dodger"]],
		[["rusher", "tank"], ["dodger", "tank"]],
		[["rusher", "tank", "dodger"]],
	],
	"section_b": [
		[["rusher", "dodger"]],
		[["rusher", "tank", "sentry_drone"]],
		[["tank", "caster", "sentry_drone"]],
	],
	"section_c": [
		[["rusher", "tank", "dodger"]],
		[["tank", "caster", "sentry_drone"]],
		[["absorber_mech", "rusher", "caster"]],
	],
	"section_d": [
		[
			["rusher", "sentry_drone", "caster"],
			["scrambler_drone", "dodger"],
			["tank", "sentry_drone", "scrambler_drone"],
		],
		[
			["scrambler_drone", "sentry_drone", "caster"],
			["nano_stalker", "scrambler_drone", "tank"],
			["absorber_mech", "dodger", "caster"],
		],
		[
			["absorber_mech", "scrambler_drone", "neuro_caster"],
			["tank", "nano_stalker", "caster"],
			["scrambler_drone", "nano_stalker", "sentry_drone", "neuro_caster"],
		],
	],
	"section_e": [
		[
			["scrambler_drone", "sentry_drone", "absorber_mech"],
			["nano_stalker", "sentry_drone", "tank"],
			["neuro_caster", "dodger", "scrambler_drone"],
		],
		[
			["absorber_mech", "scrambler_drone", "neuro_caster"],
			["tank", "nano_stalker", "sentry_drone", "scrambler_drone"],
			["dodger", "sentry_drone", "absorber_mech", "neuro_caster"],
		],
		[
			["absorber_mech", "nano_stalker", "scrambler_drone", "neuro_caster"],
			["tank", "dodger", "sentry_drone", "caster"],
			["rusher", "tank", "dodger", "absorber_mech"],
		],
	],
}

## 개발자 메뉴에서 상층 전투 호흡을 즉시 비교할 대표 4체 편성.
## 실제 종반 후보 중 하나를 그대로 사용해 QA와 캠페인 정본이 어긋나지 않게 한다.
const UPPER_QA_ENCOUNTER_IDS := {
	"section_d": ["scrambler_drone", "nano_stalker", "sentry_drone", "neuro_caster"],
	"section_e": ["absorber_mech", "nano_stalker", "scrambler_drone", "neuro_caster"],
}

## 증원은 기존 편성에 없는 적을 앞에서부터 채운다. 상층일수록 비인간형 자물쇠가 먼저 온다.
const DENSITY_CANDIDATE_IDS := {
	"section_a": ["rusher", "dodger", "tank"],
	"section_b": ["rusher", "dodger", "sentry_drone", "caster", "tank"],
	"section_c": ["rusher", "sentry_drone", "dodger", "caster", "tank", "absorber_mech"],
	"section_d": [
		"scrambler_drone", "sentry_drone", "nano_stalker", "caster",
		"neuro_caster", "tank", "absorber_mech", "dodger", "rusher",
	],
	"section_e": [
		"scrambler_drone", "absorber_mech", "nano_stalker", "neuro_caster",
		"sentry_drone", "caster", "tank", "dodger", "rusher",
	],
}


static func encounter_variants(section: String, tier: int) -> Array:
	var tiers: Array = REGULAR_ENCOUNTER_IDS.get(section, [])
	if tiers.is_empty():
		return []
	return tiers[clampi(tier, 0, tiers.size() - 1)] as Array


static func regular_encounter_ids(section: String, tier: int, roll: float = -1.0) -> Array[String]:
	var variants := encounter_variants(section, tier)
	var result: Array[String] = []
	if variants.is_empty():
		return result
	var choice_roll := RandomStreamsScript.gameplay_float("encounter") \
		if roll < 0.0 else clampf(roll, 0.0, 1.0)
	var index := mini(int(floor(choice_roll * variants.size())), variants.size() - 1)
	for enemy_id in variants[index]:
		result.append(str(enemy_id))
	return result


static func load_regular_encounter(section: String, tier: int, roll: float = -1.0) -> Array[EnemyData]:
	return load_enemy_ids(regular_encounter_ids(section, tier, roll))


static func upper_qa_encounter_ids(section: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in UPPER_QA_ENCOUNTER_IDS.get(section, []):
		result.append(str(enemy_id))
	return result


static func load_upper_qa_encounter(section: String) -> Array[EnemyData]:
	return load_enemy_ids(upper_qa_encounter_ids(section))


static func density_candidate_ids(section: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in DENSITY_CANDIDATE_IDS.get(section, []):
		result.append(str(enemy_id))
	return result


static func load_density_candidates(section: String) -> Array[EnemyData]:
	return load_enemy_ids(density_candidate_ids(section))


static func target_count(section: String, tier: int, current_count: int, roll: float) -> int:
	var density_roll := clampf(roll, 0.0, 1.0)
	match section:
		"section_a":
			return 3 if tier == 1 and density_roll >= 0.67 else current_count
		"section_b":
			if tier == 0:
				return 3
			if tier == 1:
				return 4 if density_roll >= 0.5 else 3
			return 4
		"section_c":
			return 3 if tier == 0 else 4
		"section_d", "section_e":
			return 3 if tier == 0 else 4
		_:
			return current_count


static func introduced_enemy_ids(section: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in INTRODUCED_ENEMY_IDS.get(section, []):
		result.append(str(enemy_id))
	return result


static func regular_enemy_ids_for_section(section: String) -> Array[String]:
	var result: Array[String] = []
	for tier in range(3):
		for formation in encounter_variants(section, tier):
			for enemy_id in formation:
				var id := str(enemy_id)
				if not result.has(id):
					result.append(id)
	for enemy_id in density_candidate_ids(section):
		if not result.has(enemy_id):
			result.append(enemy_id)
	return result


static func all_reachable_regular_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for section in REGULAR_ENCOUNTER_IDS:
		for enemy_id in regular_enemy_ids_for_section(str(section)):
			if not result.has(enemy_id):
				result.append(enemy_id)
	result.sort()
	return result


static func load_enemy_ids(enemy_ids: Array[String]) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for enemy_id in enemy_ids:
		var enemy := load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData
		if enemy != null:
			result.append(enemy)
	return result
