class_name CampaignContent
extends RefCounted

## 5개 계층의 관문 편성 정본.
## 보스는 4종(A/B/C/E)이며 D는 기존 자물쇠를 종합하는 정예 관문이다.

const GATE_ENEMY_IDS := {
	"section_a": ["boss_director"],
	"section_b": ["rusher", "tank", "boss_seraph"],
	"section_c": ["boss_omega"],
	"section_d": ["absorber_mech", "rusher", "neuro_caster"],
	"section_e": ["rusher", "dodger", "tank", "boss_lob_core"],
}

const BOSS_IDS_BY_SECTION := {
	"section_a": "boss_director",
	"section_b": "boss_seraph",
	"section_c": "boss_omega",
	"section_e": "boss_lob_core",
}


static func gate_enemy_ids(section: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in GATE_ENEMY_IDS.get(section, []):
		result.append(str(enemy_id))
	return result


static func load_gate_encounter(section: String) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for enemy_id in gate_enemy_ids(section):
		var enemy := load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData
		if enemy != null:
			result.append(enemy)
	return result


static func section_for_boss(boss_id: String) -> String:
	for section in BOSS_IDS_BY_SECTION:
		if BOSS_IDS_BY_SECTION[section] == boss_id:
			return str(section)
	return "section_a"


static func is_boss_section(section: String) -> bool:
	return BOSS_IDS_BY_SECTION.has(section)


static func boss_count() -> int:
	return BOSS_IDS_BY_SECTION.size()


static func is_major_gate_type(type_name: String) -> bool:
	return type_name.contains("보스") or type_name.to_lower().contains("boss") \
		or type_name.contains("정예 관문")
