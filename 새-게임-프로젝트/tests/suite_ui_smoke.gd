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


static func _has_label_text(root: Node, fragment: String) -> bool:
	if root is Label and fragment in (root as Label).text:
		return true
	for child in root.get_children():
		if _has_label_text(child, fragment):
			return true
	return false


static func _find_button_text(root: Node, fragment: String) -> Button:
	if root is Button and fragment in (root as Button).text:
		return root as Button
	for child in root.get_children():
		var found := _find_button_text(child, fragment)
		if found != null:
			return found
	return null


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

		t.check(scene._section_selector_overlay._summary_label.text.contains("35층"),
			"브리핑 요약은 해금 상태와 무관하게 35층 연속 상승 표시")

	# 로비 복귀 경로
	scene.handle_section_selector_closed()
	t.check(scene._title_overlay.visible and not scene._section_selector_overlay.visible,
		"브리핑 → 로비 복귀 (타이틀 표시 / 브리핑 숨김)")

	# ── 개발자 테스트: 전체 초기화는 확인창을 거쳐야 한다 ──
	scene._title_overlay._on_dev_test_pressed()
	var reset_btn := _find_button_text(scene._title_overlay._dev_test_panel, "전부 초기화")
	t.check(reset_btn != null, "개발자 테스트 메뉴에 전부 초기화 버튼 존재")
	if reset_btn != null:
		reset_btn.pressed.emit()
		t.check(scene._title_overlay._reset_confirmation.visible,
			"전부 초기화는 오작동 방지 확인창을 표시")
		scene._title_overlay._reset_confirmation.hide()
	scene._title_overlay._dev_test_panel.visible = false

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

		t.eq(panels, 5, "계층 헤더 5개 — 조기 종료 상한 마커 없음")

	# 상위 계층으로 이동해도 지도 전체 길이는 그대로여야 한다(런은 하나이므로).
	scene._rm.enter_section("section_c")
	scene._show_map_screen()
	var rows_mid := 0
	for row in scene._map_overlay._floors_vbox.get_children():
		if not row.is_queued_for_deletion() and row is HBoxContainer:
			rows_mid += 1
	t.eq(rows_mid, 35, "⭐ 계층을 넘어가도 지도는 런 전체 35층을 유지")

	# ── #011: 첫 관문 돌파는 디브리핑이 아니라 공역으로 이어져야 한다 ──
	RunManager.meta_unlocked_sections = ["section_a"] as Array[String]
	scene._rm.start_new_run("section_a", scene._current_gun_data,
		scene._bullets_basic, scene._bullets_ap, scene._bullets_kb)
	scene._rm.credits = 77
	var deck_at_gate: int = scene._rm.deck.size()
	scene._rm.backpack_items.append(scene._bullets_kb)
	scene._rm.current_floor = int(MapGenerator.section_info("section_a").floors)
	scene._advance_floor_or_finish()
	t.eq(scene._rm.current_section, "section_b", "⭐ #011 침전 관문 돌파 → 공역 즉시 진입")
	t.check(RunManager.meta_unlocked_sections.has("section_b"), "⭐ #011 공역 해금 즉시 저장 대상 반영")
	t.eq(scene._rm.deck.size(), deck_at_gate, "⭐ #011 계층 전환 시 덱 유지")
	t.eq(scene._rm.credits, 77, "⭐ #011 계층 전환 시 크레딧 유지")
	t.eq(scene._rm.backpack_items.size(), 1, "⭐ #011 계층 전환 시 가방 유지")
	t.check(not scene._debriefing_overlay.visible, "⭐ #011 첫 구역 뒤 디브리핑·메인 복귀 없음")

	# ── 개발자 테스트: 기관단총 연발 체인 숏컷과 역할 UI가 실제로 도는가 ──
	scene.trigger_tempo_full_auto_test()
	t.check(scene._cm != null, "기관단총 연발 체인 테스트 — CombatManager 생성됨")
	if scene._cm != null:
		t.check(scene._cm.gun_is("smg"), "⭐ 기관단총 연발 체인 테스트가 Tempo로 시작됨")
		t.check(scene._cm.is_full_auto(), "기관단총 QA 숏컷도 연발")
	t.check(_has_label_text(scene._combat_overlay, "[연계]"),
		"⭐ 장전 UI에 연계 역할 배지 렌더")
	t.check(_has_label_text(scene._combat_overlay, "[공격]"),
		"⭐ 장전 UI에 공격 역할 배지 렌더")
	scene._combat_overlay._toggle_drawer(true)
	t.check(_has_label_text(scene._combat_overlay, "보급 6/6"),
		"⭐ Tempo 가방 첫 칸에 약실 포함 기본 보급 6/6 표시")
	scene._combat_overlay._toggle_drawer(false)

	# ── 개발자 테스트: 제압형 연발 전투 숏컷이 실제로 도는가 ──
	# ⚠️ 숏컷은 QA 진입점이라 깨져도 본 게임 흐름에서는 드러나지 않는다.
	#    전투를 실제로 시작시켜 CombatManager가 연발 총으로 붙는지 확인한다.
	scene.trigger_full_auto_test()
	t.check(scene._cm != null, "연발 전투 테스트 — CombatManager 생성됨")
	if scene._cm != null:
		t.check(scene._cm.is_full_auto(), "⭐ 연발 전투 테스트가 제압형(연발)으로 시작됨")
		t.eq(scene._cm.enemies.size(), 3, "적 3체 배치(다수전 이월 + 중장갑 관문)")
	scene._is_shortcut_mode = false

	# ── 반동 연출이 액션 바를 밀어내지 않는가 ──
	# 회귀 배경(2026-07-25 보고): 격발 반동이 액션 바의 **현재 위치**를 원점으로 삼아
	#   position.y += 8 했다가 되돌리는 방식이었다. 직전 반동이 끝나기 전에 다음 발이
	#   나가면 밀린 위치가 새 원점이 되어 8px씩 영구 누적됐고, 세 번 쏘면 버튼이
	#   화면 밖으로 사라졌다. 연발은 한 프레임에 5발이라 즉시 40px 밀렸다.
	# ⚠️ 애니메이션 결함이라 로직 테스트로는 잡히지 않는다 — 좌표를 직접 잰다.
	var ov = scene._combat_overlay
	if ov != null and ov._action_row != null:
		var base_y: float = ov._action_row.position.y
		var dummy := BulletData.new()
		dummy.display_name = "테스트탄"
		for i in range(20):
			ov._on_bullet_fired(dummy, true, 1)
		var drift: float = absf(ov._action_row.position.y - base_y)
		t.check(drift <= 8.0,
			"⭐ 20연속 격발 후 액션 바 이동 %.1fpx — 반동 진폭(8px) 내, 누적 없음" % drift)
		t.check(ov._action_row.position.y + ov._action_row.size.y <= ov.size.y + 1.0,
			"⭐ 액션 바가 화면 안에 남아 있음 (버튼이 가려지지 않음)")

	# ── 연발 격발 연출이 순차 재생되는가 ──
	# ⚠️ 시뮬레이션은 1턴에 즉시 끝나지만, 연출을 한 번에 뭉쳐 보여주면
	#    "펑" 하고 끝나 장전 순서가 전혀 읽히지 않는다. 로직은 그대로 두고
	#    bullet_fired를 큐에 쌓아 간격을 두고 재생한다(정본 §21.5).
	if ov != null:
		ov._fire_fx_queue.clear()
		ov._fx_playing = false
		var b1 := BulletData.new()
		b1.display_name = "연출탄"
		# 한 프레임에 5발이 들어와도 큐에 쌓여야 한다(즉시 전부 소비되면 안 된다).
		for i in range(5):
			ov._on_bullet_fired(b1, true, 1)
		t.check(ov._fx_playing, "⭐ 연발 5발 → 연출 큐 재생이 시작됨")
		t.check(ov._fire_fx_queue.size() > 0,
			"⭐ 나머지 %d발이 큐에 남아 순차 대기 (한 번에 소비되지 않음)" % ov._fire_fx_queue.size())

		# 탄창 표시가 재생 진행도를 따라가는가
		ov._mag_display_override = [b1, b1, b1] as Array[BulletData]
		ov._update_cylinder_visuals()
		t.eq(ov._lookahead_container.display_override.size(), 3,
			"연출 중 탄창 표시는 실제 탄창이 아니라 재생 진행도를 그림")

		ov._fire_fx_queue.clear()
		ov._mag_display_override.clear()

		# ── 실린더 카드의 이름 라벨이 클립되는가 (가로 늘어남 방지의 근본) ──
		# 회귀 배경(2026-07-27 보고): 긴 이름 탄("12게이지 밀집탄" 등)을 장착하면 카드
		#   min-width가 211px까지 부풀어 UI가 가로로 늘어났다. 원인은 이름 라벨이 클립되지
		#   않아 전체 텍스트 폭을 최소 폭으로 요구한 것.
		# ⚠️ 픽셀 폭 측정은 헤드리스 레이아웃 타이밍상 불안정하다. 근본 원인(클립 여부)을
		#    구조로 검증한다 — 이게 false가 되면 다시 늘어난다.
		var long_named := load("res://resources/bullets/pierce.tres")
		if long_named != null and is_instance_valid(ov._lookahead_container):
			var card = ov._lookahead_container._create_dynamic_bullet_card(long_named, 1, true, false, false)
			var name_lbl = card.find_child("BulletName", true, false)
			t.check(name_lbl != null, "실린더 카드에 이름 라벨 존재")
			if name_lbl != null:
				t.check(name_lbl.clip_text,
					"⭐ 이름 라벨이 클립됨 — 긴 이름이 카드를 가로로 밀어내지 않음")
				t.check(name_lbl.custom_minimum_size.x <= 60,
					"이름 라벨 최소 폭이 제한됨 (%.0f)" % name_lbl.custom_minimum_size.x)
			card.free()

		# ── 탄환 궤적이 화면을 덮지 않는가 ──
		# 회귀 배경(2026-07-25 보고): "이펙트가 화면 전체를 가득 채워 눈이 아프다".
		#   이 오버레이는 MarginContainer(컨테이너)라 Control 자식의 크기를 강제로
		#   다시 잡는다. 궤적 ColorRect를 여기 직접 붙였더니 **화면 전체로 늘어나**
		#   날아가는 탄이 아니라 거대한 플래시가 됐다.
		#   → 컨테이너가 관리하지 않는 _fx_layer에 붙여야 한다.
		t.check(is_instance_valid(ov._fx_layer), "연출 전용 레이어 존재")
		if is_instance_valid(ov._fx_layer):
			var before_fx: int = ov._fx_layer.get_child_count()
			var tb := BulletData.new()
			tb.display_name = "궤적탄"
			ov._spawn_tracer(Vector2(100, 300), Vector2(600, 320), tb, true)
			t.eq(ov._fx_layer.get_child_count(), before_fx + 1, "궤적이 연출 레이어에 생성됨")

			var slug: Control = ov._fx_layer.get_child(ov._fx_layer.get_child_count() - 1)
			t.check(slug.size.x <= 24 and slug.size.y <= 8,
				"⭐ 궤적이 작은 탄알 크기 %s — 화면을 덮지 않음" % str(slug.size))
			t.check(slug.size.x < ov.size.x * 0.2,
				"⭐ 궤적이 화면 폭으로 늘어나지 않음 (컨테이너 자식이 아님)")
			slug.queue_free()

		# ── 연출이 재생 중이면 전투 결과 화면을 미룬다 ──
		# 회귀 배경(2026-07-25 보고): 마지막 적을 연발로 잡으니 총알 연출도 없이
		#   곧바로 "승리"가 떴다. 버스트가 동기로 돌아 적이 죽는 순간 encounter_won이
		#   즉시 발생하는데, 그 시점엔 총알 연출이 아직 큐에만 있었기 때문이다.
		# ── 적 표시 배치: HP 바는 머리 위, 방어·회피 배지는 발 아래 ──
		# 요청(2026-07-25): HP를 머리 위로, 자물쇠·방어·회피를 아래로.
		var tc = ov._track_control
		if is_instance_valid(tc) and not tc.enemy_sprites.is_empty():
			var any_enemy = null
			for candidate in tc.enemy_sprites.keys():
				if not candidate.is_stack_sponge:
					any_enemy = candidate
					break
			t.check(any_enemy != null, "HP 바 검증용 일반 HP 적 존재")
			if any_enemy == null:
				return
			var es = tc.enemy_sprites[any_enemy]
			var hp_bg = es.get_node_or_null("HpBarBG")
			var badge = es.get_node_or_null("BadgePanel")
			var defp = es.get_node_or_null("DefPanel")
			var focus_label = es.get_node_or_null("FocusLabel") as Label
			var family_hint = es.get_node_or_null("FamilyPreviewLabel") as Label
			t.check(hp_bg != null, "적 머리 위 HP 바 존재")
			t.check(badge != null and defp != null, "아키타입·방어 배지 존재")
			t.check(focus_label != null, "경량탄 집중 스택 라벨 존재")
			t.check(family_hint != null, "소총탄·산탄 보조 타격 예고 라벨 존재")
			if hp_bg and badge:
				t.check(not hp_bg is Container, "⭐ HP 배경이 채움 폭을 자동 재배치하지 않음")
				# 스프라이트는 y=0~80. HP 바는 그 위(음수), 배지는 그 아래(80 초과).
				t.check(hp_bg.position.y < 0, "⭐ HP 바가 머리 위(y=%.0f)" % hp_bg.position.y)
				t.check(badge.position.y >= 80, "⭐ 아키타입 배지가 발 아래(y=%.0f)" % badge.position.y)
				t.check(defp.position.y >= 80, "⭐ 방어 배지가 발 아래(y=%.0f)" % defp.position.y)
				t.check(hp_bg.position.y < badge.position.y, "HP 바가 배지보다 위에 있음")
			if focus_label:
				tc.update_focus(any_enemy, 2, 3, false)
				t.check(focus_label.visible and focus_label.text.find("2/3") != -1,
					"⭐ 경량탄 집중 2/3이 적별로 표시됨")

			# 탄종 이벤트는 동기 정산 시점에 도착한 뒤 정확히 다음 격발 연출에 묶인다.
			ov._fire_fx_queue.clear()
			ov._fx_playing = true
			ov._pending_family_events.clear()
			ov._on_ammo_family_triggered("focus", any_enemy, [any_enemy], 1)
			ov._on_bullet_fired(b1, true, 1, any_enemy, any_enemy.current_hp)
			var family_entry: Dictionary = ov._fire_fx_queue.back()
			t.eq(family_entry.get("family_events", []).size(), 1,
				"⭐ 탄종 이벤트가 해당 격발 연출 큐에 결합됨")
			t.check(ov._pending_family_events.is_empty(),
				"탄종 이벤트가 다음 발로 누출되지 않음")
			ov._fire_fx_queue.clear()

			# HP 바가 체력 변화를 따라가는가
			any_enemy.current_hp = maxi(any_enemy.max_hp / 2, 1)
			tc.refresh_all_hp_bars()
			var fill = hp_bg.get_node_or_null("HpFill") if hp_bg else null
			if fill:
				# 절반이면 채움 막대가 배경 안쪽 폭의 절반쯤 비어 있어야 한다.
				t.check(fill.offset_right < -10.0, "⭐ HP 바가 절반으로 줄어듦 (offset_right=%.0f)" % fill.offset_right)
				t.check(fill.size.x > 0.0, "생존 적의 HP 채움 폭이 남아 있음")
				any_enemy.current_hp = 1
				tc.refresh_all_hp_bars()
				t.check(not any_enemy.is_dead() and fill.size.x > 0.0,
					"⭐ HP 1 생존 적의 채움 막대가 완전히 비지 않음 (폭 %.1fpx)" % fill.size.x)
				tc.refresh_hp_bar_to(any_enemy, any_enemy.max_hp)
				var full_offset: float = fill.offset_right
				ov._on_enemy_damaged(any_enemy, 1, any_enemy.max_hp / 2, true)
				t.check(is_equal_approx(fill.offset_right, full_offset),
					"주 대상 HP는 탄환 도착 전까지 선갱신되지 않음")
				ov._on_enemy_damaged(any_enemy, 1, any_enemy.max_hp / 2, false)
				t.check(fill.offset_right < full_offset - 10.0,
					"과관통·관통 보조 피해 HP는 누락 없이 즉시 갱신")
			# HP 바 안에는 수치를 표기하지 않는다(막대 길이만으로 충분).
			t.check(hp_bg.get_node_or_null("HpText") == null, "HP 바 내 수치 미표기")

			# 마지막 처치탄은 실제 대상을 보존하고, 사망 페이드가 끝날 때까지 결과창을 막는다.
			ov._fire_fx_queue.clear()
			ov._fx_playing = true
			for candidate in tc.enemy_sprites.keys():
				candidate.current_hp = 0
				if candidate.is_stack_sponge:
					candidate.barrier_cells = 0
			ov._on_bullet_fired(b1, true, 5, any_enemy, 0)
			var kill_entry: Dictionary = ov._fire_fx_queue.back()
			t.check(kill_entry.target == any_enemy and bool(kill_entry.final_kill),
				"⭐ 마지막 처치탄 큐가 실제 사망 대상을 보존")
			ov._result_overlay.visible = false
			ov._on_encounter_won()
			t.check(ov._pending_result == "won" and not ov._result_overlay.visible,
				"⭐ 마지막 적 사망 연출 전에는 드래프트 결과창 보류")
			ov._apply_queued_hit_feedback(kill_entry)
			t.check(es.visible and not ov._result_overlay.visible,
				"⭐ 사망 실루엣 페이드 중에도 드래프트가 화면을 덮지 않음")
			t.check(ov.ENEMY_DEATH_FADE + ov.POST_KILL_HOLD >= 0.6,
				"처치 페이드와 후속 여운 시간이 확보됨")

		ov._fire_fx_queue.clear()
		ov._pending_result = ""
		if is_instance_valid(ov._result_overlay):
			ov._result_overlay.visible = false

		# 연출이 재생 중(큐에 남음)일 때 승리가 오면 결과를 보류해야 한다.
		ov._fx_playing = true
		ov._on_encounter_won()
		t.eq(ov._pending_result, "won", "⭐ 연출 재생 중 승리 → 결과 화면 보류")
		t.check(not ov._result_overlay.visible, "⭐ 총알 연출 전에는 승리 화면이 뜨지 않음")

		# 연출이 없을 때 오는 승리는 즉시 표시된다(단발 마지막 발 등).
		ov._fx_playing = false
		ov._pending_result = ""
		ov._on_encounter_won()
		t.check(ov._result_overlay.visible, "연출 없이 온 승리는 즉시 표시")
		ov._result_overlay.visible = false

	# ── 디브리핑: 사망 / 정점 도달(결말). 결말은 로어 20개 유무로 한 번 더 갈린다 ──
	var prev_credits: int = RunManager.meta_credits
	var prev_lore: Array[int] = RunManager.meta_lore_fragments.duplicate()

	scene._rm.enter_section(str(RunManager.SECTION_ORDER[0]))
	scene._debriefing_overlay.show_debriefing(false)
	t.check(scene._debriefing_overlay._debrief_log.text.length() > 0, "디브리핑 — 사망 분기 렌더")

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
