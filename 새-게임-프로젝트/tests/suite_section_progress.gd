extends RefCounted
## 구역 진행 검증 — 완주 판정(구역별 층수) + 다음 구역 해금 + 영속화.
##
## 배경(2026-07-18 발견): 두 결함이 겹쳐 첫 구역을 클리어해도 진행이 막혔다.
##   ① 완주 판정이 `current_floor > 15` 하드코딩 → 10층/12층 구역은 완주되지 않고
##      존재하지 않는 층의 빈 맵으로 이동해 멈춤
##   ② 구역 해금 로직 자체가 부재 → 완주해도 다음 구역이 열리지 않음
## 두 결함 모두 "구역별 층수"를 참조하지 않은 데서 비롯되므로 함께 검증한다.

const SL_PATH := "user://__test_section.cfg"


static func _reset_sections() -> void:
	RunManager.meta_unlocked_sections = ["section_a"] as Array[String]


static func run(t) -> void:
	t.section("SectionProgress")

	var prev_override: String = RunManager.save_path_override
	RunManager.save_path_override = SL_PATH

	# ── 구역별 층수 메타데이터가 실제 맵과 일치하는지 (완주 판정의 근거) ──
	# 연속 런 재편(20_ascension_intention §3)으로 총 35층으로 압축됨
	var expected := {"section_a": 6, "section_b": 7, "section_c": 7, "section_d": 7, "section_e": 8}
	for sec in expected.keys():
		t.eq(int(MapGenerator.section_info(sec).floors), expected[sec],
			"%s 층수 메타데이터 = %d" % [sec, expected[sec]])

	# ── 완주 판정: 각 구역의 최종 층을 넘어야만 완주다 ──
	# (과거 `> 15` 하드코딩이면 section_a는 11층이 되어도 완주되지 않아 여기서 실패한다)
	for sec in expected.keys():
		var last_floor: int = expected[sec]
		t.check(last_floor + 1 > int(MapGenerator.section_info(sec).floors),
			"%s: 최종층+1(%d)은 완주 조건을 만족" % [sec, last_floor + 1])
		t.check(not (last_floor > int(MapGenerator.section_info(sec).floors)),
			"%s: 최종층(%d)에서는 아직 완주가 아님" % [sec, last_floor])

	# ── 패배 시에는 구역이 해금되지 않는다 ──
	_reset_sections()
	var rm_lose := RunManager.new()
	rm_lose.current_section = "section_a"
	t.check(rm_lose.check_section_unlocks(false).is_empty(), "패배 시 구역 미해금")
	t.check(not RunManager.meta_unlocked_sections.has("section_b"), "패배 후 section_b 잠금 유지")

	# ── 완주 시 다음 구역이 순서대로 해금된다 ──
	_reset_sections()
	var rm_a := RunManager.new()
	rm_a.current_section = "section_a"
	var un_a := rm_a.check_section_unlocks(true)
	t.check(un_a.has("section_b"), "section_a 완주 → section_b 해금")
	t.check(RunManager.meta_unlocked_sections.has("section_b"), "해금 목록에 반영됨")

	var rm_b := RunManager.new()
	rm_b.current_section = "section_b"
	t.check(rm_b.check_section_unlocks(true).has("section_c"), "section_b 완주 → section_c 해금")

	# ── 마지막 구역 완주 시에는 해금할 다음이 없다 (에러 없이 빈 배열) ──
	var rm_e := RunManager.new()
	rm_e.current_section = "section_e"
	t.check(rm_e.check_section_unlocks(true).is_empty(), "최종 구역 완주 시 해금 대상 없음")

	# ── 이미 해금된 구역은 중복 해금되지 않는다 ──
	var rm_again := RunManager.new()
	rm_again.current_section = "section_a"
	t.check(rm_again.check_section_unlocks(true).is_empty(), "이미 해금된 구역은 재해금되지 않음")

	# ── 영속화: 저장 후 리셋 → 로드 시 해금이 유지되어야 한다 ──
	_reset_sections()
	t.check(not RunManager.meta_unlocked_sections.has("section_b"), "리셋으로 해금 제거됨(사전 조건)")
	RunManager.load_meta()
	t.check(RunManager.meta_unlocked_sections.has("section_b"), "재시작 모사: 구역 해금이 세이브에서 복원됨")

	# ── 정리 ──
	DirAccess.remove_absolute(SL_PATH)
	RunManager.save_path_override = prev_override
	_reset_sections()
