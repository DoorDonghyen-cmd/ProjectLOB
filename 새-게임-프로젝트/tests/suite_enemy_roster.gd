extends RefCounted
## 13종 적의 캠페인 도달성·계층별 학습 순서·표기명 정합 회귀.

const EnemyRosterScript := preload("res://scripts/core/enemy_roster.gd")
const CampaignContentScript := preload("res://scripts/core/campaign_content.gd")
const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const SECTION_ORDER: Array[String] = [
	"section_a", "section_b", "section_c", "section_d", "section_e",
]

const EXPECTED_DISPLAY_NAMES := {
	"rusher": "폭동 돌격병",
	"tank": "진압 방패병",
	"dodger": "광학 굴절병",
	"caster": "신경 교란 부유체",
	"absorber_mech": "흡수 장갑 구체",
	"scrambler_drone": "태세 교란 드론",
	"sentry_drone": "경보 순찰 드론",
	"nano_stalker": "광학 추적체 03",
	"neuro_caster": "상위 신경 통제체",
	"boss_director": "보안부장 \"디렉터 강\"",
	"boss_seraph": "세라프 방어 프로토콜",
	"boss_omega": "적합성 개조체 Ω",
	"boss_lob_core": "L.O.B 코어 \"프로젝트 라스트\"",
}

const RETIRED_NAME_TERMS: Array[String] = [
	"좀비", "오염", "나노", "스토커", "실험체", "수석연구원",
]


static func _sorted(values: Array[String]) -> Array[String]:
	var result := values.duplicate()
	result.sort()
	return result


static func _resource_ids() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("res://resources/enemies")
	if dir == null:
		return result
	for file_name in dir.get_files():
		var clean_name := file_name.trim_suffix(".remap")
		if clean_name.ends_with(".tres"):
			var enemy_id := clean_name.get_basename()
			if not result.has(enemy_id):
				result.append(enemy_id)
	result.sort()
	return result


static func _csv_display_names() -> Dictionary:
	var result := {}
	var file := FileAccess.open("res://data/enemy_stats.csv", FileAccess.READ)
	if file == null:
		return result
	var headers := file.get_csv_line()
	var id_col := headers.find("id")
	var name_col := headers.find("display_name")
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= maxi(id_col, name_col):
			continue
		var enemy_id := str(row[id_col]).strip_edges()
		if not enemy_id.is_empty():
			result[enemy_id] = str(row[name_col]).strip_edges()
	return result


## 실제 CombatManager의 전진·차징·긴급 격퇴 경로를 그대로 반복해,
## 플레이어가 아무 적도 처리하지 않았을 때 몇 행동 뒤 패배하는지 측정한다.
static func _unanswered_loss_turns(enemy_ids: Array[String]) -> int:
	var cm = CombatManagerScript.new()
	var lost := [false]
	cm.player_died.connect(func(): lost[0] = true)
	var gun: GunData = load("res://resources/guns/revolver.tres")
	var no_bullets: Array[BulletData] = []
	var no_parts: Array[PartData] = []
	cm.start_encounter(gun, EnemyRosterScript.load_enemy_ids(enemy_ids), no_bullets, no_parts)
	var turns := 0
	while not lost[0] and turns < 12:
		turns += 1
		cm._all_enemies_advance()
	cm.free()
	return turns if lost[0] else 99


static func run(t) -> void:
	t.section("EnemyRoster")

	# ── 일반·변종 9종이 실제 일반전 편성 정본에서 모두 도달하는가 ──
	var expected_regular := _sorted(EnemyRosterScript.REGULAR_ENEMY_IDS)
	var reachable_regular := EnemyRosterScript.all_reachable_regular_enemy_ids()
	t.eq(reachable_regular, expected_regular, "⭐ 일반·변종 9종 전체가 일반전 편성에서 도달")

	# 각 계층에서 새 자물쇠가 계획된 시점보다 일찍 새지 않는지 검사한다.
	var seen: Array[String] = []
	for section in SECTION_ORDER:
		var section_ids := EnemyRosterScript.regular_enemy_ids_for_section(section)
		var actual_new: Array[String] = []
		for enemy_id in section_ids:
			if not seen.has(enemy_id):
				actual_new.append(enemy_id)
		for enemy_id in section_ids:
			if not seen.has(enemy_id):
				seen.append(enemy_id)
		t.eq(_sorted(actual_new), _sorted(EnemyRosterScript.introduced_enemy_ids(section)),
			"%s 신규 자물쇠 도입 순서" % section)

	# ── 편성 안전선: 최대 4체, 중복 없음, 고속 적 2중첩 금지, 최소 한 턴 대응 여유 ──
	for section in SECTION_ORDER:
		for tier in range(3):
			var variants := EnemyRosterScript.encounter_variants(section, tier)
			t.check(not variants.is_empty(), "%s T%d 편성 후보 존재" % [section, tier])
			for formation_variant in variants:
				var formation: Array = formation_variant
				t.check(formation.size() >= 1 and formation.size() <= 4,
					"%s T%d 일반전 1~4체" % [section, tier])
				var unique := {}
				var fast_count := 0
				for enemy_id_variant in formation:
					var enemy_id := str(enemy_id_variant)
					t.check(not unique.has(enemy_id), "%s T%d 동일 적 중복 없음" % [section, tier])
					unique[enemy_id] = true
					var enemy := load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData
					t.check(enemy != null and not enemy.is_boss,
						"%s T%d 일반전 ID %s 유효" % [section, tier, enemy_id])
					if enemy != null:
						fast_count += 1 if enemy.speed >= 3 else 0
						t.check(enemy.start_distance - enemy.speed > 0,
							"%s는 첫 적 전진 전 대응 여유 보유" % enemy_id)
				t.check(fast_count <= 1, "%s T%d 고속 적 중첩 최대 1" % [section, tier])

	# ── 상층 전투 호흡: 동일 강제전진 중복 금지 + 4~8행동 압력 ──
	var previous_risk := RunManager.infiltration_risk_level
	var previous_ascension := RunManager.meta_ascension_level
	RunManager.infiltration_risk_level = 1
	RunManager.meta_ascension_level = 0
	for section in ["section_d", "section_e"]:
		for tier in range(3):
			for formation_variant in EnemyRosterScript.encounter_variants(section, tier):
				var formation: Array = formation_variant
				var typed_ids: Array[String] = []
				var charger_count := 0
				for enemy_id_variant in formation:
					var enemy_id := str(enemy_id_variant)
					typed_ids.append(enemy_id)
					var enemy := load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData
					if enemy != null and enemy.archetype == Enums.EnemyArchetype.CASTER:
						charger_count += 1
				t.check(charger_count <= 1,
					"%s T%d 강제전진 차저 중첩 최대 1" % [section, tier])
				var loss_turns := _unanswered_loss_turns(typed_ids)
				t.check(loss_turns >= 4 and loss_turns <= 8,
					"%s T%d 무대응 패배 %d행동 — 계획 여유와 상층 압력 범위" % [
						section, tier, loss_turns])

		var qa_ids := EnemyRosterScript.upper_qa_encounter_ids(section)
		t.eq(qa_ids.size(), 4, "%s 수동 QA 대표 편성 4체" % section)
		t.check(EnemyRosterScript.encounter_variants(section, 2).has(qa_ids),
			"%s 수동 QA 편성은 실제 종반 후보" % section)
	RunManager.infiltration_risk_level = previous_risk
	RunManager.meta_ascension_level = previous_ascension

	# ── 일반전 9종 + 기존 관문 보스 4종 = 리소스 13종 정확히 도달 ──
	var campaign_ids := reachable_regular.duplicate()
	for section in SECTION_ORDER:
		for enemy_id in CampaignContentScript.gate_enemy_ids(section):
			if not campaign_ids.has(enemy_id):
				campaign_ids.append(enemy_id)
	campaign_ids.sort()
	var resource_ids := _resource_ids()
	t.eq(resource_ids.size(), 13, "적 리소스 총 13종")
	t.eq(campaign_ids, resource_ids, "⭐ 캠페인 일반전·관문 합집합 = 적 리소스 13종")

	# ── CSV와 실제 리소스가 같은 현행 세계관 이름을 쓰는가 ──
	var csv_names := _csv_display_names()
	t.eq(csv_names.size(), 13, "enemy_stats.csv 적 13종")
	var used_names := {}
	for enemy_id_variant in EXPECTED_DISPLAY_NAMES:
		var enemy_id := str(enemy_id_variant)
		var enemy := load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData
		var expected_name := str(EXPECTED_DISPLAY_NAMES[enemy_id])
		t.check(enemy != null, "%s 리소스 로드" % enemy_id)
		if enemy == null:
			continue
		t.eq(enemy.display_name, expected_name, "%s 현행 표시명" % enemy_id)
		t.eq(str(csv_names.get(enemy_id, "")), expected_name, "%s CSV↔리소스 표시명 일치" % enemy_id)
		t.check(not used_names.has(expected_name), "적 표시명 중복 없음: %s" % expected_name)
		used_names[expected_name] = true
		for retired_term in RETIRED_NAME_TERMS:
			t.check(not enemy.display_name.contains(retired_term),
				"%s 표시명에 폐기 명칭 '%s' 없음" % [enemy_id, retired_term])
