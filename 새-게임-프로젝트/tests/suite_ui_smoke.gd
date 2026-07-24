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

		# ⚠️ `t.check(true, ...)`로 "안 죽었다"만 확인하면 안 된다.
		#    GDScript 오류는 실행을 멈추지 않으므로, 오버레이가 통째로 깨져 있어도
		#    그런 단언은 통과한다. 실제로 화면에 들어간 값을 본다.
		var brief_ok: bool = scene._section_selector_overlay != null 			and scene._section_selector_overlay.visible 			and scene._section_selector_overlay._summary_label.text.contains("이번 상승")
		t.check(brief_ok, "상승 브리핑 갱신 — %s" % label)

		var expected_len := 0
		for s2 in unlocked:
			expected_len += int(MapGenerator.section_info(s2).floors)
		t.check(scene._section_selector_overlay._summary_label.text.contains("%d층" % expected_len),
			"브리핑 요약에 이번 런 길이 %d층 표시" % expected_len)

	# 로비 복귀 경로
	scene.handle_section_selector_closed()
	t.check(scene._title_overlay.visible and not scene._section_selector_overlay.visible,
		"브리핑 → 로비 복귀 (타이틀 표시 / 브리핑 숨김)")

	# ── 준비실: 시작 계층 표기 갱신 ──
	scene.show_loadout_screen(str(RunManager.SECTION_ORDER[0]))
	var start_name: String = str(MapGenerator.section_info(RunManager.SECTION_ORDER[0]).name)
	t.check(scene._loadout_overlay.visible, "요원 준비실 진입")
	t.check(scene._loadout_overlay._target_zone_label.text.contains(start_name),
		"준비실이 시작 계층을 %s로 표기" % start_name)

	# ── 지도: 런 전체(35층)가 한 화면에 그려지는가 ──
	# 지도는 계층 단위가 아니라 **런 전체**를 보여준다. 계층마다 리셋되면
	# "얼마나 남았는가"를 알 수 없기 때문이다.
	# 과거 map_overlay가 end_floor를 15로 하드코딩해 어느 계층에서든 15개 층이 그려졌다.
	# 숫자 리터럴이라 소스 검사로는 잡히지 않으므로 실제로 그려서 센다.
	# ⚠️ 해금 상태와 무관하게 **항상 35층**이 그려져야 한다. 잠긴 계층은 자물쇠로 표시된다.
	#    첫 런에서 6층만 보이면 "얼마나 남았는가"도, 목표도 전달되지 않는다.
	for case2 in [
		["section_a"],
		["section_a", "section_b"],
		["section_a", "section_b", "section_c", "section_d", "section_e"],
	]:
		var unlocked2: Array[String] = []
		for s in case2:
			unlocked2.append(str(s))
		RunManager.meta_unlocked_sections = unlocked2
		scene.handle_loadout_finished()  # 런 개시 → 지도 표시

		# queue_free()된 이전 행은 아직 트리에 남아 있으므로 제외한다.
		# 층 행은 HBoxContainer, 계층 헤더·상한 마커는 PanelContainer다.
		var floor_rows := 0
		var panels := 0
		for row in scene._map_overlay._floors_vbox.get_children():
			if row.is_queued_for_deletion():
				continue
			if row is HBoxContainer:
				floor_rows += 1
			elif row is PanelContainer:
				panels += 1
		t.eq(floor_rows, 35, "⭐ 해금 %d계층에서도 지도는 35층 전체 표시" % unlocked2.size())

		# 헤더 5개 + (도달 상한이 정점이 아니면) 상한 마커 1개
		var expected_panels: int = 5 + (0 if unlocked2.size() == 5 else 1)
		t.eq(panels, expected_panels, "계층 헤더 5 + 상한 마커 %d" % (expected_panels - 5))

	# 상위 계층으로 이동해도 지도 전체 길이는 그대로여야 한다(런은 하나이므로).
	scene._rm.enter_section("section_c")
	scene._show_map_screen()
	var rows_mid := 0
	for row in scene._map_overlay._floors_vbox.get_children():
		if not row.is_queued_for_deletion() and row is HBoxContainer:
			rows_mid += 1
	t.eq(rows_mid, 35, "⭐ 계층을 넘어가도 지도는 런 전체 35층을 유지")

	# ── 개발자 테스트: 연발 전투 숏컷이 실제로 도는가 ──
	# ⚠️ 숏컷은 QA 진입점이라 깨져도 본 게임 흐름에서는 드러나지 않는다.
	#    전투를 실제로 시작시켜 CombatManager가 연발 총으로 붙는지 확인한다.
	scene.trigger_full_auto_test()
	t.check(scene._cm != null, "연발 전투 테스트 — CombatManager 생성됨")
	if scene._cm != null:
		t.check(scene._cm.is_full_auto(), "⭐ 연발 전투 테스트가 제압형(연발)으로 시작됨")
		t.eq(scene._cm.enemies.size(), 3, "적 3체 배치(다수전 이월 + 중장갑 관문)")
	scene._is_shortcut_mode = false

	# ── 디브리핑: 세 가지 종료 분기가 모두 오류 없이 렌더되는가 ──
	# 사망 / 해금 상한 도달 / 정점 도달(결말). 결말 분기는 로어 20개 유무로 한 번 더 갈린다.
	var prev_credits: int = RunManager.meta_credits
	var prev_lore: Array[int] = RunManager.meta_lore_fragments.duplicate()

	scene._rm.enter_section(str(RunManager.SECTION_ORDER[0]))
	scene._debriefing_overlay.show_debriefing(false)
	t.check(scene._debriefing_overlay._debrief_log.text.length() > 0, "디브리핑 — 사망 분기 렌더")

	RunManager.meta_unlocked_sections = ["section_a", "section_b"]
	scene._rm.enter_section("section_b")
	scene._debriefing_overlay.show_debriefing(true)
	t.check(scene._debriefing_overlay._debrief_log.text.length() > 0, "디브리핑 — 해금 상한 도달 분기 렌더")

	var last_sec: String = str(RunManager.SECTION_ORDER[RunManager.SECTION_ORDER.size() - 1])
	RunManager.meta_unlocked_sections = ["section_a", "section_b", "section_c", "section_d", "section_e"]
	scene._rm.enter_section(last_sec)
	RunManager.meta_lore_fragments = [] as Array[int]
	scene._debriefing_overlay.show_debriefing(true)
	var summit_text: String = scene._debriefing_overlay._debrief_log.text
	t.check(summit_text.find("총을 내려놓지 않았다") != -1, "디브리핑 — 정점 결말(개조 거부) 출력됨")

	# 로어 20개를 모으면 심화 한 컷이 덧붙는다. 20개 미만에서는 나오면 안 된다.
	t.check(summit_text.find("이전 도달자") == -1, "로어 미완성 시 심화 파편 미출력")
	var full_lore: Array[int] = []
	for i in range(1, 21):
		full_lore.append(i)
	RunManager.meta_lore_fragments = full_lore
	scene._rm.enter_section(last_sec)
	scene._debriefing_overlay.show_debriefing(true)
	t.check(scene._debriefing_overlay._debrief_log.text.find("이전 도달자") != -1,
		"⭐ 로어 20/20 + 정점 도달 → 심화 파편 출력(과거 조건 `floor >= 15`로 도달 불가였음)")

	RunManager.meta_credits = prev_credits
	RunManager.meta_lore_fragments = prev_lore

	# ── 정리 ──
	# free()는 쓰지 않는다. 지도 갱신이 이전 층 행들을 queue_free()로 예약해 두므로,
	# 삭제 대기 중인 자식을 가진 씬을 즉시 free()하면 엔진이 종료 시 크래시한다(signal 11).
	# queue_free()로 넘기고, 호출부가 다음 프레임에 종료하도록 한다.
	RunManager.meta_unlocked_sections = prev_unlocked
	scene.queue_free()
	t.check(scene.is_queued_for_deletion(), "메인 씬 정리 예약 완료")
