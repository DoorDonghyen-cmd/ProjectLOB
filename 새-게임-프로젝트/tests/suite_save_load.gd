extends RefCounted
## 메타 세이브/로드 검증 — 저장 → 리셋(재시작 모사) → 로드 복원, 세이브 부재 시 기본값 유지.
## 실제 세이브 파일을 건드리지 않도록 전용 임시 경로를 사용한다.
## 정본: scripts/core/run_manager.gd save_meta/load_meta

const SL_PATH := "user://__test_save_load.cfg"
const RESET_PATH := "user://__test_reset_all.cfg"


static func run(t) -> void:
	t.section("SaveLoad")

	# ── 값 세팅 → 저장 ──
	RunManager.meta_credits = 777
	RunManager.meta_backpack_lvl = 2
	RunManager.meta_vault_lvl = 3
	RunManager.meta_discount_unlocked = true
	RunManager.meta_unlocked_weapons = ["workhorse", "smg"] as Array[String]
	RunManager.meta_lore_fragments = [1, 5, 9] as Array[int]
	RunManager.save_meta(SL_PATH)

	# ── 리셋 (게임 재시작 모사) ──
	RunManager.meta_credits = 0
	RunManager.meta_backpack_lvl = 0
	RunManager.meta_vault_lvl = 0
	RunManager.meta_discount_unlocked = false
	RunManager.meta_unlocked_weapons = [] as Array[String]
	RunManager.meta_lore_fragments = [] as Array[int]

	# ── 로드 → 복원 검증 ──
	RunManager.load_meta(SL_PATH)
	t.eq(RunManager.meta_credits, 777, "크레딧 복원")
	t.eq(RunManager.meta_backpack_lvl, 2, "가방 레벨 복원")
	t.eq(RunManager.meta_vault_lvl, 3, "금고 레벨 복원")
	t.check(RunManager.meta_discount_unlocked, "할인 해금 플래그 복원")
	t.eq(RunManager.meta_unlocked_weapons, ["workhorse", "smg"], "해금 무기 배열 복원")
	t.eq(RunManager.meta_lore_fragments, [1, 5, 9], "로어 파편 배열 복원")

	# ── 세이브 부재 시 기존값 유지 (에러 없이 무동작) ──
	RunManager.meta_credits = 123
	RunManager.load_meta("user://__nonexistent_save__.cfg")
	t.eq(RunManager.meta_credits, 123, "세이브 없으면 기존값 유지")

	# ── 개발자 전체 초기화: 영구 메타 + 현재 런 + 세이브 파일 ──
	var rm := RunManager.new()
	RunManager.meta_credits = 999
	RunManager.meta_backpack_lvl = 3
	RunManager.meta_hp_armor_lvl = 2
	RunManager.meta_discount_unlocked = true
	RunManager.meta_tactical_data_cores = 42
	RunManager.meta_vault_lvl = 3
	RunManager.saved_vault_credits = 88
	RunManager.starting_bonus_available = true
	RunManager.meta_unlocked_weapons = ["workhorse", "tempo", "heavy"] as Array[String]
	RunManager.meta_unlocked_sections = ["section_a", "section_b", "section_c"] as Array[String]
	RunManager.meta_lore_fragments = [1, 2, 3] as Array[int]
	RunManager.meta_ascension_unlocked = 5
	RunManager.meta_ascension_level = 4
	RunManager.infiltration_risk_level = 5
	rm.credits = 321
	rm.current_floor = 9
	rm.current_section = "section_c"
	rm.current_node_id = 903
	rm.pending_combat_distance_modifier = -2
	rm.backpack_items.append(Resource.new())
	rm.run_stats.total_kills = 7
	RunManager.save_meta(RESET_PATH)
	t.check(FileAccess.file_exists(RESET_PATH), "전체 초기화 검증용 세이브 생성")

	var reset_error := rm.reset_all_progress(RESET_PATH)
	t.eq(reset_error, OK, "전체 초기화 세이브 처리 성공")
	t.check(not FileAccess.file_exists(RESET_PATH), "전체 초기화가 기존 세이브 파일 제거")
	t.eq(RunManager.meta_credits, RunManager.DEFAULT_META_CREDITS, "크레딧 첫 실행값 복원")
	t.eq(RunManager.meta_backpack_lvl, 0, "백팩 레벨 초기화")
	t.eq(RunManager.meta_hp_armor_lvl, 0, "아머 레벨 초기화")
	t.check(not RunManager.meta_discount_unlocked, "할인 해금 초기화")
	t.eq(RunManager.meta_tactical_data_cores, 0, "TDC 초기화")
	t.eq(RunManager.meta_vault_lvl, 0, "금고 레벨 초기화")
	t.eq(RunManager.saved_vault_credits, 0, "금고 이월 크레딧 초기화")
	t.check(not RunManager.starting_bonus_available, "시작 보너스 초기화")
	t.eq(RunManager.meta_unlocked_weapons, ["workhorse"], "기본 무기만 해금")
	t.eq(RunManager.meta_unlocked_sections, ["section_a"], "최하 계층만 해금")
	t.check(RunManager.meta_lore_fragments.is_empty(), "로어 파편 초기화")
	t.eq(RunManager.meta_ascension_unlocked, 0, "승천 해금 초기화")
	t.eq(RunManager.meta_ascension_level, 0, "적용 승천 초기화")
	t.eq(RunManager.infiltration_risk_level, 1, "침투 위험도 초기화")
	t.eq(rm.credits, 0, "현재 런 크레딧 초기화")
	t.eq(rm.current_floor, 1, "현재 런 층 초기화")
	t.eq(rm.current_section, "section_a", "현재 런 계층 초기화")
	t.eq(rm.current_node_id, 0, "현재 런 노드 초기화")
	t.eq(rm.pending_combat_distance_modifier, 0, "현재 런 거리 페널티 초기화")
	t.check(rm.backpack_items.is_empty(), "현재 런 가방 초기화")
	t.eq(int(rm.run_stats.total_kills), 0, "현재 런 통계 초기화")

	# ── 정리 ──
	DirAccess.remove_absolute(SL_PATH)
	DirAccess.remove_absolute(RESET_PATH)
