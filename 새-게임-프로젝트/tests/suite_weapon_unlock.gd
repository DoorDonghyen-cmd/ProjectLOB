extends RefCounted
## 무기 해금 검증 — 조건 판정 + 영구 저장(persist).
##
## 배경: 디브리핑이 end_run()(내부 save_meta) → check_weapon_unlocks() 순서로 호출해
##       해금이 저장 이후에 일어나 재시작 시 유실되던 버그(2026-07-18 수정).
##       check_weapon_unlocks가 자체 저장하도록 고친 뒤 영속을 못박는다.

const SL_PATH := "user://__test_unlock.cfg"


## 해금 상태를 기본값으로 리셋한다.
static func _reset_unlocks() -> void:
	RunManager.meta_unlocked_weapons = ["workhorse"] as Array[String]


static func run(t) -> void:
	t.section("WeaponUnlock")

	var prev_override: String = RunManager.save_path_override
	RunManager.save_path_override = SL_PATH

	# ── 조건 미달 시 해금되지 않는다 ──
	_reset_unlocks()
	var rm := RunManager.new()
	rm.run_stats.max_kills_in_single_turn = 2   # bruiser 조건은 3 이상
	rm.run_stats.lead_bullets_fired = 1         # tempo 조건(0발) 불충족
	rm.run_stats.min_dist_allowed = 1           # gambler 조건(>1) 불충족
	var none_unlocked := rm.check_weapon_unlocks()
	t.check(not none_unlocked.has("bruiser"), "한 턴 2킬로는 돌격형(bruiser) 미해금")
	t.check(not none_unlocked.has("tempo"), "납탄 격발 시 발사형(tempo) 미해금")
	t.check(not none_unlocked.has("gambler"), "최소 거리 1이면 도박형(gambler) 미해금")

	# ── 조건 충족 시 해금된다 ──
	_reset_unlocks()
	var rm2 := RunManager.new()
	rm2.run_stats.max_kills_in_single_turn = 3          # bruiser 충족
	rm2.run_stats.tanks_killed_by_shred_only = 1        # heavy 충족
	rm2.run_stats.stance_shifts_killed_without_slow = 1 # stance_hunter 충족
	rm2.run_stats.lead_bullets_fired = 1                # tempo 제외(격리)
	rm2.run_stats.min_dist_allowed = 1                  # gambler 제외(격리)
	var unlocked := rm2.check_weapon_unlocks()
	t.check(unlocked.has("bruiser"), "한 턴 3킬 → 돌격형(bruiser) 해금")
	t.check(unlocked.has("heavy"), "파쇄만으로 탱커 처치 → 중장형(heavy) 해금")
	t.check(unlocked.has("stance_hunter"), "슬로우 없이 태세병 처치 → 태세 사냥꾼 해금")
	t.check(RunManager.meta_unlocked_weapons.has("bruiser"), "해금 목록에 반영됨")

	# ── 영속화: 저장 후 리셋 → 로드 시 해금이 유지되어야 한다 ──
	_reset_unlocks()
	t.check(not RunManager.meta_unlocked_weapons.has("bruiser"), "리셋으로 해금 제거됨(사전 조건)")
	RunManager.load_meta()
	t.check(RunManager.meta_unlocked_weapons.has("bruiser"), "재시작 모사: 해금이 세이브에서 복원됨")
	t.check(RunManager.meta_unlocked_weapons.has("heavy"), "재시작 모사: 다중 해금 복원됨")

	# ── 이미 해금된 무기는 중복 해금되지 않는다 ──
	var rm3 := RunManager.new()
	rm3.run_stats.max_kills_in_single_turn = 5
	var again := rm3.check_weapon_unlocks()
	t.check(not again.has("bruiser"), "이미 해금된 무기는 재해금되지 않음")

	# ── 정리 ──
	DirAccess.remove_absolute(SL_PATH)
	RunManager.save_path_override = prev_override
	_reset_unlocks()
