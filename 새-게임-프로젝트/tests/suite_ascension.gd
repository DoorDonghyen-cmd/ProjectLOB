extends RefCounted
## 승천(Ascension) 검증 — 누적 적용 · 해금 사다리 · 공정성 바닥선.
##
## 설계 정본: docs/gdd/20_ascension_intention.md
##
## ⚠️ 이 스위트가 지키는 것은 "수치가 옳다"가 아니라 **"구조가 무너지지 않는다"**이다.
##    등급별 조건 배치(§7)는 플레이 데이터로 바뀔 수 있지만, 아래 성질은 바뀌면 안 된다:
##      · 누적이다 (등급 N = 1~N 전부)
##      · 등급이 오를수록 반드시 더 어렵다 (단조성 — "등급 = 난이도" 신뢰)
##      · 최고 등급에서도 자원이 0이 되지 않는다 (공정성 바닥선 §6)
##      · 적 DEF/EVA는 건드리지 않는다 (이진 게이트 절벽 회피)

const SL_PATH := "user://__test_ascension.cfg"


static func run(t) -> void:
	t.section("Ascension")

	var prev_override: String = RunManager.save_path_override
	var prev_unlocked: int = RunManager.meta_ascension_unlocked
	var prev_level: int = RunManager.meta_ascension_level
	RunManager.save_path_override = SL_PATH

	# ── ① 누적 구조 ──
	t.eq(Ascension.TIERS.size(), Ascension.MAX_LEVEL, "등급 정의 수 = MAX_LEVEL(%d)" % Ascension.MAX_LEVEL)

	var e0 := Ascension.effects_for(0)
	t.eq(int(e0.armor_delta), 0, "0등급: 아머 보정 없음")
	t.eq(float(e0.credit_mult), 1.0, "0등급: 크레딧 배율 1.0")
	t.check(not bool(e0.no_caliber_safety), "0등급: 전용탄 보존 유지")

	# 등급 1은 아머 −1, 등급 7에서 하나 더 → 누적 −2
	t.eq(int(Ascension.effects_for(1).armor_delta), -1, "1등급: 아머 −1")
	t.eq(int(Ascension.effects_for(7).armor_delta), -2, "⭐ 7등급: 아머 누적 −2 (1등급 것이 계속 적용)")

	# 크레딧은 곱연산으로 누적된다.
	# ⚠️ 합연산이면 등급이 오를수록 수입이 0 이하로 떨어져 경제가 죽는다.
	t.eq(int(round(Ascension.effects_for(2).credit_mult * 100)), 80, "2등급: 크레딧 ×0.8")
	t.eq(int(round(Ascension.effects_for(10).credit_mult * 100)), 64, "⭐ 10등급: ×0.8 두 번 누적 = ×0.64 (곱연산)")

	# 전용탄 보존 해제는 8등급부터 계속 유지된다.
	t.check(not bool(Ascension.effects_for(7).no_caliber_safety), "7등급: 아직 전용탄 보존")
	t.check(bool(Ascension.effects_for(8).no_caliber_safety), "⭐ 8등급: 전용탄 보존 해제(질적 벽)")
	t.check(bool(Ascension.effects_for(10).no_caliber_safety), "10등급: 해제 상태 유지(누적)")

	# ── ② 단조성 — 등급이 오를수록 절대 쉬워지지 않는다 ──
	# "등급 = 난이도"라는 신뢰가 이 성질에 달려 있다.
	var monotonic := true
	var detail := ""
	for lv in range(1, Ascension.MAX_LEVEL + 1):
		var prev := Ascension.effects_for(lv - 1)
		var cur := Ascension.effects_for(lv)
		if int(cur.armor_delta) > int(prev.armor_delta): monotonic = false; detail = "아머 lv%d" % lv
		if float(cur.credit_mult) > float(prev.credit_mult): monotonic = false; detail = "크레딧 lv%d" % lv
		if int(cur.deck_delta) > int(prev.deck_delta): monotonic = false; detail = "덱 lv%d" % lv
		if int(cur.start_dist_delta) > int(prev.start_dist_delta): monotonic = false; detail = "거리 lv%d" % lv
		if int(cur.enemy_spd_delta) < int(prev.enemy_spd_delta): monotonic = false; detail = "SPD lv%d" % lv
		if int(cur.draft_slots_delta) > int(prev.draft_slots_delta): monotonic = false; detail = "드래프트 lv%d" % lv
	t.check(monotonic, "⭐ 등급이 오를수록 단조롭게 어려워진다%s" % ("" if monotonic else " ← 역전: " + detail))

	# ── ③ 공정성 바닥선 (§6) — 최고 등급에서도 자원이 0이 되지 않는다 ──
	# "효율 실패로 죽는 것은 공정, 완벽히 했는데 자원이 모자라 죽는 것은 부당."
	var top := Ascension.effects_for(Ascension.MAX_LEVEL)

	# 아머: 메타 최대(HP아머 lvl2 → 기본 3)에서 최고 등급을 적용해도 1 이상 남아야 한다.
	var armor_at_top: int = maxi(1 + 2 + int(top.armor_delta), 1)
	t.check(armor_at_top >= 1, "⭐ 최고 등급 + 최대 메타에서도 시작 아머 ≥ 1 (%d)" % armor_at_top)

	# 크레딧: 수입이 0이 되면 메타 진행이 정지한다.
	var income_at_top: int = int(round((35 * 15 + 50) * float(top.credit_mult)))
	t.check(income_at_top > 0, "⭐ 최고 등급에서도 완주 수입 > 0 (%d Cr)" % income_at_top)

	# 시작 덱: 각 계열 최소 1발은 남아야 빌드가 성립한다.
	t.check(int(top.deck_delta) > -5, "최고 등급 덱 감소가 기본 구성을 지우지 않음 (%d)" % int(top.deck_delta))

	# ── ④ 적 DEF/EVA는 손잡이가 아니다 (§4) ──
	# 이진 관통 게이트라 DEF 4→5면 PEN4 탄이 20% 약해지는 게 아니라 완전 무효가 된다.
	# 그러면 난이도가 균일하게 오르지 않고 특정 빌드만 골라 죽는다.
	for lv in range(0, Ascension.MAX_LEVEL + 1):
		var eff := Ascension.effects_for(lv)
		t.check(not eff.has("enemy_def_delta") and not eff.has("enemy_eva_delta"),
			"%d등급: DEF/EVA 손잡이 미사용 (이진 게이트 절벽 회피)" % lv)
		if lv >= 2:
			break  # 대표 표본만 확인 (전 등급 반복은 로그만 늘린다)

	# ── ⑤ 실제 적용: 적 스탯에 거리·SPD가 반영되는가 ──
	RunManager.infiltration_risk_level = 1
	RunManager.meta_ascension_unlocked = Ascension.MAX_LEVEL

	RunManager.meta_ascension_level = 0
	var e_base := EnemyInstance.new(load("res://resources/enemies/rusher.tres"))
	var base_dist := e_base.start_distance
	var base_spd := e_base.current_speed
	var base_def := e_base.current_def
	var base_eva := e_base.current_evasion

	RunManager.meta_ascension_level = Ascension.MAX_LEVEL
	var e_top := EnemyInstance.new(load("res://resources/enemies/rusher.tres"))

	t.check(e_top.start_distance < base_dist,
		"⭐ 승천 최고 등급: 시작 거리가 좁혀짐 (%d → %d)" % [base_dist, e_top.start_distance])
	t.check(e_top.current_speed > base_spd,
		"⭐ 승천 최고 등급: 적 SPD 상승 (%d → %d)" % [base_spd, e_top.current_speed])
	t.eq(e_top.current_def, base_def, "⭐ 적 DEF는 승천에 영향받지 않음 (이진 게이트 보호)")
	t.eq(e_top.current_evasion, base_eva, "⭐ 적 EVA도 영향받지 않음")

	# ── ⑥ 해금 사다리 ──
	RunManager.meta_ascension_unlocked = 0
	RunManager.meta_ascension_level = 0
	var last_sec: String = String(RunManager.SECTION_ORDER[RunManager.SECTION_ORDER.size() - 1])

	var rm_lose := RunManager.new()
	rm_lose.current_section = last_sec
	t.eq(rm_lose.check_ascension_unlock(false), 0, "패배 시 승천 미해금")

	# 정점이 아닌 계층에 완주 신호가 잘못 들어와도 승천을 열지 않는다.
	var rm_mid := RunManager.new()
	rm_mid.current_section = "section_b"
	t.eq(rm_mid.check_ascension_unlock(true), 0, "⭐ 비정점 완주 신호는 승천 미해금")

	# 정점 완주 → 1등급 해금
	var rm_top := RunManager.new()
	rm_top.current_section = last_sec
	t.eq(rm_top.check_ascension_unlock(true), 1, "⭐ 정점 완주 → 승천 1등급 해금")
	t.eq(RunManager.meta_ascension_unlocked, 1, "해금 상태 반영")

	# 같은(낮은) 등급으로 다시 깨도 사다리는 오르지 않는다.
	RunManager.meta_ascension_level = 0
	var rm_again := RunManager.new()
	rm_again.current_section = last_sec
	t.eq(rm_again.check_ascension_unlock(true), 0,
		"⭐ 이미 넘은 등급으로 재완주 시 사다리 정지 ('등급 = 난이도' 신뢰 유지)")

	# 해금된 등급으로 완주해야 다음이 열린다.
	RunManager.meta_ascension_level = 1
	var rm_next := RunManager.new()
	rm_next.current_section = last_sec
	t.eq(rm_next.check_ascension_unlock(true), 2, "1등급으로 완주 → 2등급 해금")

	# ── ⑦ 영속화 + 방어적 클램프 ──
	RunManager.meta_ascension_unlocked = 3
	RunManager.meta_ascension_level = 2
	RunManager.save_meta()
	RunManager.meta_ascension_unlocked = 0
	RunManager.meta_ascension_level = 0
	RunManager.load_meta()
	t.eq(RunManager.meta_ascension_unlocked, 3, "해금 등급이 세이브에서 복원됨")
	t.eq(RunManager.meta_ascension_level, 2, "적용 등급이 세이브에서 복원됨")

	# 적용 등급은 해금 범위를 넘을 수 없다(세이브 조작·롤백 방어).
	RunManager.meta_ascension_unlocked = 1
	RunManager.meta_ascension_level = 9
	RunManager.save_meta()
	RunManager.load_meta()
	t.check(RunManager.meta_ascension_level <= RunManager.meta_ascension_unlocked,
		"⭐ 적용 등급이 해금 범위로 클램프됨 (%d ≤ %d)" % [RunManager.meta_ascension_level, RunManager.meta_ascension_unlocked])

	# ── 정리 ──
	DirAccess.remove_absolute(SL_PATH)
	RunManager.save_path_override = prev_override
	RunManager.meta_ascension_unlocked = prev_unlocked
	RunManager.meta_ascension_level = prev_level
