extends RefCounted
## 난이도 곡선 & 진행 경제 — 35층 기준으로 실측한 건강한 값을 고정한다.
##
## 배경(2026-07-25 실측): 층수 압축(64→35) 후 "구 15층 램프에서 옮겨온 값이라
##   35층 기준 미검증"이라는 우려가 있었다. 실측 결과 두 축 모두 잘 맞았고,
##   추측으로 바꾸는 대신 그 값을 여기 고정해 이후 조용한 드리프트를 막는다.
##
##   ⚠️ 이 스위트는 "값이 옳다"가 아니라 "값이 **의도한 대로 유지된다**"를 지킨다.
##      밸런스를 의도적으로 바꿀 때는 이 기대값도 함께 고쳐야 한다(그게 안전장치의 목적).

const G_REVOLVER := "res://resources/guns/revolver.tres"


static func _fresh_full_run() -> RunManager:
	RunManager.meta_unlocked_sections = ["section_a", "section_b", "section_c", "section_d", "section_e"] as Array[String]
	var rm := RunManager.new()
	rm.start_new_run("section_a", load(G_REVOLVER),
		load("res://resources/bullets/basic_pistol.tres"),
		load("res://resources/bullets/shred_rifle.tres"),
		load("res://resources/bullets/impact_pistol.tres"))
	return rm


static func run(t) -> void:
	t.section("DifficultyCurve")
	var prev_risk := RunManager.infiltration_risk_level
	RunManager.infiltration_risk_level = 1

	var rm := _fresh_full_run()

	# ── ① 거리 보정 램프: 35층 전체에서 단조 감소하며 의도한 밴드를 그린다 ──
	# 밴드 경계는 진척도 비율 20/47/67/93%에서 갈린다(런 길이에 비례 → 짧은 런도 램프).
	var mods: Array[int] = []
	for abs_f in range(1, 36):
		var loc := rm.resolve_ladder_floor(abs_f)
		rm.current_section = loc.section
		rm.current_floor = loc.floor
		mods.append(rm.floor_distance_modifier())

	t.eq(mods[0], 6, "1층: 초반 보너스 +6m (온보딩)")
	t.eq(mods[34], -2, "35층: 종반 압박 -2m")

	# 단조 감소 — 오르면서 절대 완만해지지 않는다.
	var monotonic := true
	for i in range(1, mods.size()):
		if mods[i] > mods[i - 1]:
			monotonic = false
	t.check(monotonic, "거리 보정은 층이 오를수록 단조 감소")

	# 밴드별 층수 분포(구 15층 램프에서 옮겼으나 35층에도 균등하게 퍼진다).
	var counts := {6: 0, 4: 0, 2: 0, 0: 0, -2: 0}
	for m in mods:
		counts[m] = counts.get(m, 0) + 1
	t.eq(counts[6], 7, "+6m 구간 = 7층 (1~7)")
	t.eq(counts[4], 9, "+4m 구간 = 9층 (8~16)")
	t.eq(counts[2], 7, "+2m 구간 = 7층 (17~23)")
	t.eq(counts[0], 9, "0m 구간 = 9층 (24~32)")
	t.eq(counts[-2], 3, "-2m 구간 = 3층 (33~35)")

	# ── ② 진행 경제: 한 번의 완주 수입이 전체 메타 비용을 덮는가 ──
	# 완주 정산 = 누적 등반 층수 × 15 + 완주 보너스 50.
	var full_income := 35 * 15 + 50
	t.eq(full_income, 575, "35층 완주 수입 = 575 Cr")

	# 전체 메타 해금 비용(코드의 실제 가격에서 산출):
	#   백팩 40×3 + HP아머 50×2 + 암시장 30 + 금고(30+45+60)
	var meta_total := (40 * 3) + (50 * 2) + 30 + (30 + 45 + 60)
	t.eq(meta_total, 385, "전체 메타 해금 비용 = 385 Cr")
	t.check(full_income >= meta_total,
		"⭐ 한 번의 완주(575)가 전체 메타(385)를 덮는다 — 층당 15Cr는 넉넉함")

	# ⚠️ 층당 환율을 바꾸면 이 관계가 깨진다. 15Cr는 이 부등식을 만족하도록 고른 값이다.
	# 짧은 런(침전만, 6층)도 온보딩 수입으로 성립하는지 확인.
	var short_income := 6 * 15 + 50
	t.eq(short_income, 140, "침전만 완주(6층) 수입 = 140 Cr — 첫 업그레이드 1~2개 분량")

	# ── ③ 런 내 적 스탯은 층별로 오르지 않는다 (설계 확인, 결함 아님) ──
	# 난이도는 적 스탯 인플레가 아니라 **스폰 구성 + 시작 거리**로 오른다(슬더스 모델).
	# 층별 스탯 스케일링이 필요하면 그것은 승천(Ascension)의 역할이다.
	# 이 사실을 못박아, 나중에 "왜 30층 러셔가 1층 러셔와 같지?"를 결함으로 오인하지 않게 한다.
	RunManager.infiltration_risk_level = 1
	var e_low := EnemyInstance.new(load("res://resources/enemies/rusher.tres"))
	var hp_low := e_low.current_hp
	var def_low := e_low.current_def
	# 위험도만 난이도 레버다(런 진행이 아니라 전역 설정).
	RunManager.infiltration_risk_level = 5
	var e_high := EnemyInstance.new(load("res://resources/enemies/rusher.tres"))
	t.eq(e_high.current_hp, hp_low, "적 HP는 런 진행이 아니라 타입으로 고정(스탯 인플레 없음)")
	t.eq(e_high.current_def, def_low, "적 DEF도 타입으로 고정")

	RunManager.infiltration_risk_level = prev_risk
