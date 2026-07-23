extends RefCounted
## 스크립트 컴파일 검사 — 프로젝트의 모든 .gd가 실제로 로드되는가.
##
## 배경: GDScript의 파싱/컴파일 실패는 **엔진 오류로 콘솔에 찍힐 뿐 실행을 중단시키지 않는다.**
##   그래서 깨진 스크립트를 참조하는 코드가 그냥 null을 받고 계속 진행하고,
##   테스트는 초록불을 유지한다. 실제로 두 번 겪었다.
##     · combat_scene의 타입 추론 파싱 오류 — 962 체크 그린 상태에서 UI가 뜨지 않았다
##     · DragScroll class_name 미등록 — 8개 오버레이가 통째로 로드 실패했는데 PASS였다
##
## 이 스위트는 모든 스크립트를 직접 load()해서 null이면 실패시킨다.
## 다른 어떤 검증보다 먼저 돌아야 한다 — 여기가 깨지면 뒤의 결과는 전부 의미가 없다.

const SCAN_DIRS := ["res://scripts", "res://tests"]


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


static func run(t) -> void:
	t.section("ScriptParse")

	var files: Array[String] = []
	for dir_path in SCAN_DIRS:
		_gd_files(dir_path, files)

	t.check(files.size() > 0, "스크립트 스캔 대상 %d개" % files.size())

	# ⚠️ `load() != null`로는 부족하다. 파싱에 실패한 GDScript도 **껍데기 객체는 반환된다.**
	#    (실제로 이 검사를 그렇게 짰다가, 스크립트를 일부러 깨뜨렸는데도 통과했다.)
	#    컴파일 성공 여부는 `can_instantiate()`로 판별한다.
	var broken: Array[String] = []
	for path in files:
		var res = load(path)
		if res == null:
			broken.append(path)
		elif res is GDScript and not res.can_instantiate():
			broken.append(path)

	t.check(broken.is_empty(),
		"전 스크립트 컴파일 성공%s" % ("" if broken.is_empty() else " ← 실패: " + ", ".join(broken)))

	# ── 씬 파일도 같은 이유로 확인한다 ──
	# 씬은 스크립트를 참조하므로, 스크립트가 깨지면 씬 인스턴스가 껍데기가 된다.
	var scenes: Array[String] = []
	_scene_files("res://scenes", scenes)
	var broken_scenes: Array[String] = []
	for path in scenes:
		var packed = load(path)
		if packed == null or not (packed is PackedScene):
			broken_scenes.append(path)
	t.check(broken_scenes.is_empty(),
		"전 씬 로드 성공(%d개)%s" % [scenes.size(),
			"" if broken_scenes.is_empty() else " ← 실패: " + ", ".join(broken_scenes)])


static func _scene_files(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if d.current_is_dir():
			_scene_files(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
