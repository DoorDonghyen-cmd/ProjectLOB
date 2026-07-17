extends RefCounted
## 메타 세이브/로드 검증 — 저장 → 리셋(재시작 모사) → 로드 복원, 세이브 부재 시 기본값 유지.
## 실제 세이브 파일을 건드리지 않도록 전용 임시 경로를 사용한다.
## 정본: scripts/core/run_manager.gd save_meta/load_meta

const SL_PATH := "user://__test_save_load.cfg"


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

	# ── 정리 ──
	DirAccess.remove_absolute(SL_PATH)
