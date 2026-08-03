extends RefCounted
## 런 단위 플레이테스트 JSON과 탄·파츠·집중 지표 회귀 검증.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")
const TEST_LOG_DIR := "user://__test_playtest_logs"


static func run(t) -> void:
	t.section("PlaytestLogging")
	_cleanup_test_logs()
	PlaytestLoggerScript.log_dir_override = TEST_LOG_DIR
	PlaytestLoggerScript.enabled = true
	RunManager.infiltration_risk_level = 1

	var gun: GunData = load("res://resources/guns/revolver.tres")
	var basic: BulletData = load("res://resources/bullets/cal_9mm.tres")
	var borer: BulletData = load("res://resources/bullets/borer.tres")
	var shred: BulletData = load("res://resources/bullets/shred.tres")
	var inertia: PartData = load("res://resources/parts/inertia_fire.tres")
	var enemy: EnemyData = load("res://resources/enemies/neuro_caster.tres")

	var rm := RunManager.new()
	rm.start_new_run("section_a", gun, basic, borer, shred)
	rm.equipped_parts = [inertia] as Array[PartData]
	var log_path := rm.playtest_log_path()
	t.check(not log_path.is_empty(), "런 시작 시 플레이테스트 로그 경로 생성")
	t.check(FileAccess.file_exists(log_path), "런 시작 JSON 즉시 저장")

	var rhythm: PartData = load("res://resources/parts/rhythm_chamber.tres")
	var interrupter: PartData = load("res://resources/parts/interrupter.tres")
	var shop_offers := [
		PlaytestLoggerScript.resource_snapshot(rhythm),
		PlaytestLoggerScript.resource_snapshot(interrupter),
	]
	t.eq(rm.record_playtest_event("shop_offers", {
		"source": "initial",
		"reroll_count": 0,
		"offers": shop_offers,
	}), OK, "상점 분기 이벤트 런 JSON 추가")

	var bullets: Array[BulletData] = [basic, basic, basic]
	var enemies: Array[EnemyData] = [enemy]
	var parts: Array[PartData] = [inertia]
	var cm := CombatManagerScript.new()
	cm.start_encounter(gun, enemies, bullets, parts, basic)
	cm.confirm_loading(bullets)
	cm.fire()
	cm.fire()
	cm.fire()
	var encounter := cm.build_playtest_report()
	t.eq(encounter.result, "won", "9mm 3발+관성 격발 테스트 전투 승리 기록")
	t.eq(int(encounter.summary.shots), 3, "격발 3회 구조화")
	t.eq(int(encounter.summary.bullets.cal_9mm.shots), 3, "9mm 사용량 집계")
	t.eq(int(encounter.summary.bullets.cal_9mm.primary_damage), 12,
		"9mm 주 피해에 집중+관성 격발 포함")
	t.eq(int(encounter.summary.ammo_families.focus.triggers), 1, "집중 폭발 1회 집계")
	t.eq(int(encounter.summary.ammo_families.focus.value_total), 1, "9mm 집중 추가 피해 +1 집계")
	t.eq(int(encounter.summary.parts.inertia_fire.effect_events), 1, "관성 격발 효과 1회 집계")
	t.eq(int(encounter.summary.parts.inertia_fire.declared_bonus_damage), 2,
		"관성 격발 명시 추가 피해 +2 집계")

	t.eq(rm.record_playtest_encounter(encounter), OK, "전투 보고서 런 JSON 추가")
	var file := FileAccess.open(log_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	t.check(parsed is Dictionary, "플레이테스트 로그 JSON 파싱")
	if parsed is Dictionary:
		t.eq(int(parsed.schema_version), 2, "플레이테스트 로그 스키마 v2")
		t.eq(parsed.events.size(), 1, "런 로그에 비전투 선택 이벤트 1건 누적")
		t.eq(str(parsed.events[0].type), "shop_offers", "상점 진열 이벤트 유형 저장")
		t.eq(str(parsed.events[0].details.offers[0].id), "rhythm_chamber", "상점 파츠 후보 스냅샷")
		t.eq(int(parsed.events[0].context.credits), rm.credits, "상점 이벤트 시점 런 문맥 저장")
		t.eq(parsed.encounters.size(), 1, "런 로그에 전투 1건 누적")
		t.eq(str(parsed.encounters[0].context.equipped_parts[0].id), "inertia_fire",
			"전투 시점 장착 파츠 스냅샷")
		t.eq(int(parsed.encounters[0].summary.parts.inertia_fire.declared_bonus_damage), 2,
			"저장 JSON에서도 파츠 피해 기여 유지")

	t.eq(rm.finish_playtest_log("won"), OK, "런 결과 마감 저장")
	file = FileAccess.open(log_path, FileAccess.READ)
	parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	if parsed is Dictionary:
		t.eq(str(parsed.result), "won", "런 최종 결과 저장")

	cm.free()
	PlaytestLoggerScript.enabled = false
	PlaytestLoggerScript.log_dir_override = ""
	_cleanup_test_logs()


static func _cleanup_test_logs() -> void:
	var global_dir := ProjectSettings.globalize_path(TEST_LOG_DIR)
	if not DirAccess.dir_exists_absolute(global_dir):
		return
	var dir := DirAccess.open(global_dir)
	if dir != null:
		for file_name in dir.get_files():
			DirAccess.remove_absolute(global_dir.path_join(file_name))
	DirAccess.remove_absolute(global_dir)
