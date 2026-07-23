extends RefCounted
## UI 스모크 — 메인 씬을 실제로 인스턴스화하고 오버레이를 호출해 런타임 오류를 잡는다.
##
## 배경(2026-07-24): 기존 스위트는 전부 RefCounted 로직 층위만 검증해서,
##   오버레이 안의 런타임 오류(예: Dictionary 필드에 String() 생성자 호출)를 통과시켰다.
##   같은 이유로 과거 combat_scene의 파싱 오류도 962 그린 상태에서 발견되지 않았다.
##   → 화면을 그리지는 않되, **노드를 실제로 만들고 함수를 실제로 부른다.**
##
## 헤드리스에서도 Control 노드 생성·시그널·문자열 포맷은 전부 실행되므로
## 렌더링 없이 이 계층의 오류를 잡을 수 있다.

const MAIN_SCENE := "res://scenes/combat/combat_scene.tscn"


static func run(t, tree: SceneTree) -> void:
	t.section("UISmoke")

	var packed: PackedScene = load(MAIN_SCENE)
	t.check(packed != null, "메인 씬 로드됨")
	if packed == null:
		return

	var scene: Node = packed.instantiate()
	t.check(scene != null, "메인 씬 인스턴스화 성공")
	if scene == null:
		return

	tree.root.add_child(scene)
	t.check(scene.is_inside_tree(), "메인 씬이 트리에 진입(_ready 실행됨)")

	# ── 상승 브리핑: 해금 상태별로 갱신이 오류 없이 도는가 ──
	# 오버레이는 _ready()에서 이미 만들어져 있다. 표시 갱신 경로를 직접 때린다.
	var prev_unlocked: Array[String] = RunManager.meta_unlocked_sections.duplicate()

	var cases := [
		["최초 상태(최하 계층만)", ["section_a"]],
		["중간 진행", ["section_a", "section_b", "section_c"]],
		["전 계층 해금", ["section_a", "section_b", "section_c", "section_d", "section_e"]],
	]
	for case in cases:
		var label: String = str(case[0])
		var unlocked: Array[String] = []
		for s in case[1]:
			unlocked.append(str(s))
		RunManager.meta_unlocked_sections = unlocked

		scene.show_section_selector()
		t.check(true, "상승 브리핑 갱신 — %s" % label)

	# 로비 복귀 경로
	scene.handle_section_selector_closed()
	t.check(true, "브리핑 → 로비 복귀 경로 정상")

	# ── 준비실: 시작 계층 표기 갱신 ──
	scene.show_loadout_screen(str(RunManager.SECTION_ORDER[0]))
	t.check(true, "요원 준비실 진입 + 시작 계층 표기 갱신 정상")

	# ── 정리 ──
	RunManager.meta_unlocked_sections = prev_unlocked
	tree.root.remove_child(scene)
	scene.free()
	t.check(true, "메인 씬 정리 완료")
