extends RefCounted
## UI 데이터 드리프트 검사 — 오버레이가 계층 정보를 자체 복사해 두지 않았는지 소스 레벨로 확인.
##
## 배경(2026-07-24 발견): 구역 선택/준비실 오버레이가 계층 이름·층수를 자체 상수 테이블로
##   복사해 두고 있었다. 그 결과 세계관 개정(지하 주차장 → 침전 거주구)과
##   층수 압축(10/12/12/15/15 → 6/7/7/7/8)이 로직에는 반영됐는데 **화면에만 구버전이 남았다.**
##   기존 테스트는 RunManager/MapGenerator 층위만 봤기 때문에 전부 통과했다.
##
## 이 스위트는 렌더링이 아니라 **소스 텍스트**를 본다. 하드코딩은 실행하지 않아도 잡을 수 있고,
## 헤드리스에서 UI를 띄우지 않고도 검증할 수 있기 때문이다.

const UI_DIR := "res://scripts/ui"
const SRC_OF_TRUTH := "res://scripts/core/map_generator.gd"

## 세계관 개정 이전 명칭. UI 어디에도 남아 있으면 안 된다.
const RETIRED_TERMS := [
	"지하 주차장", "사무동 하층", "연구소 중층", "펜트하우스", "무한 루프", "봉쇄 빌딩",
]


static func _gd_files(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if d.current_is_dir():
			_gd_files(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


static func run(t) -> void:
	t.section("UIDataDrift")

	var files: Array[String] = []
	_gd_files(UI_DIR, files)
	t.check(files.size() > 0, "UI 스크립트 스캔 대상 %d개" % files.size())

	# ── ① 폐기된 세계관 명칭이 UI에 남아 있지 않은가 ──
	for term in RETIRED_TERMS:
		var hits: Array[String] = []
		for path in files:
			if _read(path).find(term) != -1:
				hits.append(path.get_file())
		t.check(hits.is_empty(),
			"폐기 명칭 \"%s\" 미사용%s" % [term, "" if hits.is_empty() else " ← 잔존: " + ", ".join(hits)])

	# ── ② 계층 표시명이 UI에 하드코딩되지 않았는가 ──
	# 이름은 MapGenerator가 유일한 출처여야 한다. UI에 리터럴로 박히면 개정 시 또 어긋난다.
	for sec in RunManager.SECTION_ORDER:
		var sec_name: String = str(MapGenerator.section_info(sec).name)
		var hits2: Array[String] = []
		for path in files:
			if _read(path).find("\"" + sec_name + "\"") != -1:
				hits2.append(path.get_file())
		t.check(hits2.is_empty(),
			"계층명 \"%s\" UI 하드코딩 없음%s" % [sec_name, "" if hits2.is_empty() else " ← " + ", ".join(hits2)])

	# ── ③ 압축 이전 층수 문자열이 UI에 남아 있지 않은가 ──
	# "10층 구조" 같은 표기는 로직과 무관하게 화면에서만 거짓말을 한다.
	var live_floors: Array[int] = []
	for sec in RunManager.SECTION_ORDER:
		live_floors.append(int(MapGenerator.section_info(sec).floors))
	for stale in [10, 12, 15]:
		if stale in live_floors:
			continue  # 현행 층수와 겹치면 검사 대상에서 제외
		var needle := "%d층 구조" % stale
		var hits3: Array[String] = []
		for path in files:
			if _read(path).find(needle) != -1:
				hits3.append(path.get_file())
		t.check(hits3.is_empty(),
			"구버전 층수 표기 \"%s\" 없음%s" % [needle, "" if hits3.is_empty() else " ← " + ", ".join(hits3)])

	# ── ④ 정본 자체는 살아 있는가 (검사가 헛돌지 않도록) ──
	var truth := _read(SRC_OF_TRUTH)
	for sec in RunManager.SECTION_ORDER:
		var nm: String = str(MapGenerator.section_info(sec).name)
		t.check(truth.find("\"" + nm + "\"") != -1, "정본(map_generator)에 %s 정의 존재" % nm)

	# ── ⑤ section_info가 UI 표시에 필요한 필드를 모두 제공하는가 ──
	for sec in RunManager.SECTION_ORDER:
		var info: Dictionary = MapGenerator.section_info(sec)
		for key in ["name", "floors", "base_level", "icon", "brief"]:
			t.check(info.has(key) and str(info[key]) != "", "%s.%s 제공됨" % [sec, key])
