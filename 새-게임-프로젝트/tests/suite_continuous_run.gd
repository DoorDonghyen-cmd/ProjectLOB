extends RefCounted
## 연속 런 구조 검증 — 계층 체이닝 · 자원 유지 · 런 종료 시점.
##
## 설계 정본: docs/gdd/20_ascension_intention.md §3
##   한 런 = 1계층부터 **해금된 최고 계층**까지 연속.
##   계층이 바뀌어도 덱·파츠·가방·크레딧은 유지되고, 더 오를 계층이 없을 때만 런이 끝난다.
##   구역 순차 해금은 난이도 사다리가 아니라 **런 길이 램프**로 작동한다.

const SL_PATH := "user://__test_continuous.cfg"
const GUN := "res://resources/guns/revolver.tres"
const B_BASIC := "res://resources/bullets/basic_pistol.tres"
const B_KB := "res://resources/bullets/knockback_pistol.tres"
const B_OPEN := "res://resources/bullets/opening_pistol.tres"


static func _unlock(sections: Array) -> void:
	RunManager.meta_unlocked_sections = [] as Array[String]
	for s in sections:
		RunManager.meta_unlocked_sections.append(String(s))


static func _fresh_run() -> RunManager:
	var gun: GunData = load(GUN)
	var rm := RunManager.new()
	rm.start_new_run("section_a", gun, load(B_BASIC), load(B_KB), load(B_OPEN))
	return rm


static func run(t) -> void:
	t.section("ContinuousRun")

	var prev_override: String = RunManager.save_path_override
	RunManager.save_path_override = SL_PATH
	RunManager.infiltration_risk_level = 1
	RunManager.meta_backpack_lvl = 0
	RunManager.meta_hp_armor_lvl = 0

	# ── 해금 상태가 런의 도달 상한을 정한다 (온보딩 램프) ──
	_unlock(["section_a"])
	var rm1 := _fresh_run()
	t.eq(rm1.current_section, "section_a", "런은 항상 최하 계층에서 시작")
	t.eq(rm1.get_next_unlocked_section(), "", "a만 해금: 다음 계층 없음 → 여기서 런 종료")

	_unlock(["section_a", "section_b"])
	var rm2 := _fresh_run()
	t.eq(rm2.get_next_unlocked_section(), "section_b", "a+b 해금: a 완주 후 b로 이어짐")

	_unlock(["section_a", "section_b", "section_c", "section_d", "section_e"])
	var rm3 := _fresh_run()
	t.eq(rm3.get_next_unlocked_section(), "section_b", "전체 해금: a 다음은 b")

	# ── 계층을 넘어도 런 자원이 유지된다 (핵심) ──
	var deck_before := rm3.deck.size()
	rm3.credits = 120
	rm3.add_to_deck(load(B_KB))          # 드래프트로 얻은 탄
	rm3.backpack_items.append(load(B_KB)) # 가방 물자
	var deck_mid := rm3.deck.size()
	t.eq(deck_mid, deck_before + 1, "런 도중 덱이 늘어남(사전 조건)")

	rm3.enter_section("section_b")
	t.eq(rm3.current_section, "section_b", "계층 전환 완료")
	t.eq(rm3.current_floor, 1, "새 계층은 1층부터")
	t.eq(rm3.current_node_id, 0, "새 계층 진입 시 노드 위치 초기화")
	t.eq(rm3.deck.size(), deck_mid, "⭐ 계층을 넘어도 덱 유지(리셋되지 않음)")
	t.eq(rm3.credits, 120, "⭐ 계층을 넘어도 크레딧 유지")
	t.eq(rm3.backpack_items.size(), 1, "⭐ 계층을 넘어도 가방 유지")

	# 새 계층의 맵이 실제로 생성되었는가
	t.check(rm3.map_nodes.size() > 0, "새 계층 맵 생성됨(%d 노드)" % rm3.map_nodes.size())
	t.check(rm3.floor_connections.has(1), "새 계층 1층 연결 존재")

	# 환기 압박은 계층 경계를 넘기지 않는다
	rm3.select_route("air_duct")
	rm3.enter_section("section_c")
	t.eq(rm3.consume_pending_combat_distance_modifier(), 0, "환기 압박은 계층 경계를 넘겨 이월되지 않음")

	# ── 최종 계층에서는 더 오를 곳이 없다 → 런 완주 ──
	rm3.enter_section("section_e")
	t.eq(rm3.get_next_unlocked_section(), "", "최종 계층: 다음 없음 → 런 완주 지점")

	# ── 미해금 계층에서는 런이 조기 종료된다 ──
	_unlock(["section_a", "section_b"])
	var rm4 := _fresh_run()
	rm4.enter_section("section_b")
	t.eq(rm4.get_next_unlocked_section(), "", "c 미해금: b에서 런 종료(램프 상한)")

	# ── 전 계층 누적 층수(연속 런 총 길이) ──
	# 설계 목표: 약 35층 ≈ 1시간. 장르 평균(45~60분)과 모바일 타겟을 넘지 않아야 한다.
	# 이 값이 크게 늘면 "완전 리셋 구조에서 사망 손실 과대" 문제가 재발한다.
	var total := 0
	for sec in RunManager.SECTION_ORDER:
		total += int(MapGenerator.section_info(sec).floors)
	t.eq(total, 35, "연속 런 총 층수 = 35층 (설계 목표)")

	# ── 정산은 누적 등반 층수 기준이어야 한다 (계층 내 층 번호가 아니라) ──
	# 회귀 배경: end_run이 current_floor를 쓰면 계층이 바뀔 때 1로 리셋되므로,
	# 더 높이 오른 플레이어가 보상을 적게 받는 역전이 생긴다.
	_unlock(["section_a", "section_b", "section_c", "section_d", "section_e"])
	var rm5 := _fresh_run()
	rm5.current_floor = 5
	t.eq(rm5.total_floors_climbed(), 5, "침전 5층 = 누적 5층")

	rm5.enter_section("section_b")
	rm5.current_floor = 2
	t.eq(rm5.total_floors_climbed(), 8, "공역 2층 = 누적 8층 (침전 6 + 2)")
	t.check(rm5.total_floors_climbed() > 5, "⭐ 더 높이 오른 쪽이 더 큰 값 — 보상 역전 없음")

	rm5.enter_section("section_e")
	rm5.current_floor = int(MapGenerator.section_info("section_e").floors)
	t.eq(rm5.total_floors_climbed(), 35, "정점 최상층 = 누적 35층 (런 완주)")

	# ── 해금 진행에 따른 런 길이 램프 ──
	var ramp := 0
	var ramp_desc: Array[String] = []
	for sec in RunManager.SECTION_ORDER:
		ramp += int(MapGenerator.section_info(sec).floors)
		ramp_desc.append("%d" % ramp)
	t.check(ramp_desc.size() == 5, "런 길이 램프: %s층 (해금이 진행될수록 런이 길어짐)" % " → ".join(ramp_desc))

	# ── 정리 ──
	DirAccess.remove_absolute(SL_PATH)
	RunManager.save_path_override = prev_override
	_unlock(["section_a"])
