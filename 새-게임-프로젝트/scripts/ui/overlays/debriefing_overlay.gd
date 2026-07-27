class_name DebriefingOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 상승 종료 정산 오버레이
##
## 세계관 정본: docs/gdd/01_game_overview.md §1.3
##   무드는 **비장한 절차 + 고독**. 주인공은 훈련받은 전문가가 아니고
##   지원도 보급도 회수 계획도 없다 — 아무도 이런 사람을 위해 오지 않는다.
##   결말은 물리적 탈출이 아니라 **정점에서의 개조 거부**다.
##   서사는 3층으로 통제되며(§1.3-③) 결말은 장황한 폭로 대신 **짧은 한 컷**으로 처리한다.
##
## ⚠️ 폐기된 설정(혼동 주의). 되살리지 말 것: [drift-allow]
##    봉쇄된 기업 빌딩 · 특수작전 요원 · 좀비/감염 · 탈출 헬기 · 기지 복귀 · [drift-allow]
##    나노 자율 머신 'L.O.B' 통제 실패 · 열핵 정화. [drift-allow]
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager

var _debrief_title: Label
var _debrief_log: RichTextLabel
var _debrief_confirm_btn: Button


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	add_theme_stylebox_override("panel", style)
	
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	_debrief_title = parent_scene.make_label("작전 보고서 (Debriefing)", 32, parent_scene.C_SUCCESS)
	_debrief_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_debrief_title)

	var panel: PanelContainer = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(panel)

	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 20)
	log_margin.add_theme_constant_override("margin_right", 20)
	log_margin.add_theme_constant_override("margin_top", 12)
	log_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(log_margin)

	_debrief_log = RichTextLabel.new()
	_debrief_log.bbcode_enabled = true
	_debrief_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debrief_log.add_theme_font_size_override("normal_font_size", 16)
	log_margin.add_child(_debrief_log)

	_debrief_confirm_btn = parent_scene.make_button("내려간다", _on_debrief_confirm_pressed, parent_scene.C_ACCENT)
	_debrief_confirm_btn.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(_debrief_confirm_btn)


func show_debriefing(won: bool) -> void:
	visible = true

	# 상승의 끝은 두 가지다 — 죽거나 정점을 돌파하거나.
	# 구역 관문은 다음 계층을 즉시 해금하고 같은 런으로 이어지므로 디브리핑 지점이 아니다.
	var reached_summit: bool = won and run_manager.current_section == RunManager.SECTION_ORDER[RunManager.SECTION_ORDER.size() - 1]

	if reached_summit:
		_debrief_title.text = "▲ 정점"
		_debrief_title.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
	else:
		_debrief_title.text = "상승 중단"
		_debrief_title.add_theme_color_override("font_color", parent_scene.C_DANGER)

	var earned := run_manager.end_run(won)
	var unlocked_weapons := run_manager.check_weapon_unlocks()
	# 계층 해금은 관문 돌파 순간 처리한다. 정산에서 다시 해금하면 런 경계가 뒤틀린다.
	var new_ascension := run_manager.check_ascension_unlock(reached_summit)

	var log_text := "── 상승 기록 ──\n\n"
	if RunManager.meta_ascension_level > 0:
		log_text += "[color=#cc88ff]🔺 승천 %d등급 — %s[/color]\n" % [
			RunManager.meta_ascension_level, Ascension.tier_title(RunManager.meta_ascension_level)]
	# 연속 런이므로 계층 내 층 번호(current_floor)가 아니라 누적 등반 층수로 정산한다.
	var climbed: int = run_manager.total_floors_climbed()
	log_text += "- 오른 층수: %d 층 (x15 Cr) = %d Cr\n" % [climbed, climbed * 15]
	if won:
		log_text += "- 계층 돌파 보상 = 50 Cr\n"
	log_text += "- 획득한 전술 데이터 코어 (TDC): %d 개\n" % run_manager.tactical_data_cores
	log_text += "──────────────────────────\n"
	log_text += "[color=#ffff44]총 환전된 크레딧: +%d Cr[/color]\n" % earned
	log_text += "누적 보유 크레딧: %d Cr\n" % RunManager.meta_credits
	log_text += "[color=#aaffaa]누적 보유 데이터 코어 (TDC): %d 개[/color]\n\n" % RunManager.meta_tactical_data_cores
	
	if not unlocked_weapons.is_empty():
		# 무기는 사이보그에게 쓸모없어져 하층에 버려진 인간용 화기다. 해금 = 쓸 수 있게 됨.
		log_text += "[color=#00ff66][b]🆕 인간용 화기 사용법을 익혔다 🆕[/b][/color]\n"
		for w_key in unlocked_weapons:
			var name_kor = "알 수 없음"
			match w_key:
				"marksman": name_kor = "저격형 (MARKSMAN)"
				"bruiser": name_kor = "돌격형 (BRUISER)"
				"tempo": name_kor = "속사형 (TEMPO)"
				"trickster": name_kor = "곡예형 (TRICKSTER)"
				"heavy": name_kor = "중장형 (HEAVY)"
				"stance_hunter": name_kor = "태세사냥꾼 (STANCE HUNTER)"
				"gambler": name_kor = "도박형 (GAMBLER)"
			log_text += "  ★ [b]%s[/b] — 다음 상승부터 고를 수 있다.\n" % name_kor
		log_text += "\n"

	if new_ascension > 0:
		log_text += "[color=#cc88ff][b]🔺 승천 %d등급 개방[/b][/color]\n" % new_ascension
		log_text += "  더 조여진 조건으로 다시 오를 수 있다 — %s\n\n" % Ascension.tier_title(new_ascension)

	log_text += _closing_line(won, reached_summit)

	# ── 결말: 정점에서의 개조 거부 ──
	# 물리적 탈출("탑 밖")은 그리지 않는다. 끝까지 올라간 유일한 인간이 거부하고 그 자리에
	# 선다는 장면만으로 충분하다. (01_game_overview §1.3 결말 채택안)
	if reached_summit:
		log_text += "\n\n"
		log_text += "[color=#cc88ff]────────────────────────[/color]\n"
		log_text += "정점에는 왕좌도, 적도 없었다.\n"
		log_text += "당신을 기다린 것은 시술대와 이미 작성된 서류 한 장이었다.\n\n"
		log_text += "[color=#aaaaaa]\"승인. 개조 대상: 최종 도달자 1인.\"[/color]\n\n"
		log_text += "여기까지 오른 인간은 모두 받아들였다.\n"
		log_text += "그것이 상승의 유일한 목적이었으므로.\n\n"
		log_text += "[color=#ffffff][b]당신은 총을 내려놓지 않았다.[/b][/color]"

		# ── 3층: 로어를 전부 모은 플레이어에게만 주는 심화 (선택) ──
		# ⚠️ 읽지 않아도 이해에 지장이 없어야 한다. 폭로가 아니라 한 줄의 침묵으로 끝낸다.
		if RunManager.meta_lore_fragments.size() == 20:
			log_text += "\n\n"
			log_text += "[color=#33ffff]── 기록 파편 20/20 ──[/color]\n"
			log_text += "당신이 주운 총에는 일련번호가 새겨져 있었다.\n"
			log_text += "같은 번호가 서류의 '이전 도달자' 항목에 적혀 있다.\n\n"
			log_text += "[color=#aaaaaa]날짜는 41년 전이다.[/color]"

	_debrief_log.text = log_text


## 마무리 한 줄. 무드는 비장한 절차 + 고독 — 격려하지 않고, 상황만 말한다.
func _closing_line(won: bool, reached_summit: bool) -> String:
	if reached_summit:
		return "더 오를 곳이 없다."
	return "아무도 회수하러 오지 않는다. 다시 아래에서 시작한다."


func _on_debrief_confirm_pressed() -> void:
	visible = false
	parent_scene.handle_debrief_confirmed()
