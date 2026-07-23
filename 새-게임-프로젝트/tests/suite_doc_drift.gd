extends RefCounted
## 문서 드리프트 검사 — GDD·스킬 문서에 폐기된 세계관 설정이 남아 있지 않은지 확인.
##
## 배경(2026-07-24): 코드는 새 세계관으로 정리됐는데 GDD가 구버전으로 남아 있었다.
##   문서를 근거로 작업하면 폐기된 설정이 코드로 다시 유입되므로, 코드만 고쳐서는 재발을 못 막는다.
##   실제로 아트 매니페스토는 §1(구 세계관: 테라-호러)과 §1-B(신 세계관: 계층 팔레트)가
##   한 문서 안에 공존하고 있었다. 개정 때 새 절을 덧붙이고 구 절을 남기는 습관이 원인이다.
##
## ⚠️ 문서는 Godot 프로젝트 밖(`<repo>/docs`)에 있어 `res://`로 닿지 않는다.
##    globalize_path로 프로젝트 루트를 구해 한 단계 위를 본다.
##
## 폐기어를 **의도적으로** 적어야 하는 자리(“되살리지 말 것” 경고 등)에는
## 해당 줄에 `<!-- drift-allow -->`를 붙인다.

const UIDrift := preload("res://tests/suite_ui_data_drift.gd")

## 검사 대상 디렉터리(리포지토리 루트 기준 상대 경로).
const DOC_DIRS := ["docs", ".agents"]

## 검사 제외 디렉터리 — **이력 보관 문서**.
## 일일 로그와 히스토리 아카이브는 "그때 그렇게 했다"는 기록이므로,
## 당시 표기를 현재 정본에 맞춰 고쳐 쓰면 기록으로서의 가치가 사라진다.
## 살아 있는 지침(SKILL·트래커·GDD)만 정합성을 강제한다.
const EXCLUDE_DIRS := ["04-daily-logs", "06-history-archive"]


static func _repo_root() -> String:
	# res:// → <repo>/새-게임-프로젝트/ 이므로 한 단계 위가 리포지토리 루트다.
	var proj := ProjectSettings.globalize_path("res://")
	return proj.trim_suffix("/").get_base_dir()


static func _md_files(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if entry.begins_with(".") and entry != ".agents":
			entry = d.get_next()
			continue
		var full := dir_path + "/" + entry
		if d.current_is_dir():
			if entry in EXCLUDE_DIRS:
				entry = d.get_next()
				continue
			_md_files(full, out)
		elif entry.ends_with(".md"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


static func run(t) -> void:
	t.section("DocDrift")

	var root := _repo_root()
	var files: Array[String] = []
	for sub in DOC_DIRS:
		_md_files(root + "/" + sub, files)

	t.check(files.size() > 0, "문서 스캔 대상 %d개 (%s)" % [files.size(), root])
	if files.is_empty():
		return

	# ── 폐기된 세계관 설정이 문서에 남아 있지 않은가 ──
	# 용어 목록은 UI 검사와 같은 것을 쓴다. 정본이 갈라지면 두 검사가 어긋난다.
	for term in UIDrift.RETIRED_TERMS:
		var hits: Array[String] = []
		for path in files:
			for line in _read(path).split("\n"):
				if line.find(term) != -1 and line.find(UIDrift.ALLOW_MARK) == -1:
					hits.append(path.get_file())
					break
		t.check(hits.is_empty(),
			"문서 폐기 설정 \"%s\" 미사용%s" % [term, "" if hits.is_empty() else " ← 잔존: " + ", ".join(hits)])

	# ── 구 층수 표기가 남아 있지 않은가 ──
	# 층수 압축(64→35층) 이전 값이 문서에 남으면, 그 표를 보고 구현이 되돌아간다.
	var live_floors: Array[int] = []
	for sec in RunManager.SECTION_ORDER:
		live_floors.append(int(MapGenerator.section_info(sec).floors))
	for stale in [10, 12, 15]:
		if stale in live_floors:
			continue
		for needle in ["**%d층**" % stale, "%d층 구조" % stale]:
			var hits2: Array[String] = []
			for path in files:
				for line in _read(path).split("\n"):
					if line.find(needle) != -1 and line.find(UIDrift.ALLOW_MARK) == -1:
						hits2.append(path.get_file())
						break
			t.check(hits2.is_empty(),
				"문서 구 층수 \"%s\" 미사용%s" % [needle, "" if hits2.is_empty() else " ← " + ", ".join(hits2)])

	# ── 현행 계층명이 문서에 실제로 존재하는가 (검사가 헛돌지 않도록) ──
	var joined := ""
	for path in files:
		joined += _read(path)
	for sec in RunManager.SECTION_ORDER:
		var nm: String = str(MapGenerator.section_info(sec).name)
		t.check(joined.find(nm) != -1, "문서에 현행 계층명 \"%s\" 존재" % nm)
