class_name SectionSelectorOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 상승 브리핑 (Ascent Briefing) 오버레이
##
## ⚠️ 연속 런 구조(docs/gdd/20_ascension_intention.md §3)에서 **시작 계층은 선택하지 않는다.**
##    런은 항상 최하 계층에서 시작해 정점까지 35층을 이어 오른다.
##    따라서 이 화면은 "어디로 갈지 고르는 곳"이 아니라
##    "이번 런이 어디까지 이어지는지 보여주는 곳"이다.
##
##    과거에는 구역 선택 화면이었으나, 고른 값이 실제 런에 반영되지 않아
##    UI가 거짓 선택지를 제시하는 상태였다. (2026-07-24 브리핑으로 전환)
##
## 계층 이름·층수·설명은 MapGenerator.section_info()가 유일한 출처다. 여기에 복사하지 말 것.
## ═══════════════════════════════════════════════════

const C_BORDER := Color(0.2, 0.2, 0.25, 1.0)
const C_NEON_GOLD := Color(0.83, 0.69, 0.22, 1.0)
const C_PANEL_BG := Color(0.08, 0.08, 0.12, 1.0)
const C_LOCKED := Color(1.0, 1.0, 1.0, 0.32)

var parent_scene: Control
var run_manager: RunManager

const C_ASCENSION := Color(0.8, 0.55, 1.0)

var _rows_vbox: VBoxContainer
var _summary_label: Label
var _brief_label: Label

## 승천 등급 선택 — 해금 전에는 통째로 숨긴다(있는 줄도 모르게).
var _asc_panel: PanelContainer
var _asc_level_label: Label
var _asc_cond_label: Label


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	add_theme_stylebox_override("panel", style)

	_build_ui()
	refresh_unlocked_sections()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)

	# ── 1. 헤더 ──
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(header_vbox)

	var title_lbl: Label = parent_scene.make_label("▲ ASCENT BRIEFING ▲", 24, C_NEON_GOLD)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(title_lbl)

	var subtitle_lbl: Label = parent_scene.make_label(
		"도시는 약 3000층이다. 이번 상승은 그중 한 조각이다.", 11, parent_scene.C_DIM)
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(subtitle_lbl)

	# ── 2. 계층 사다리 (위 = 상층) ──
	var ladder_panel := PanelContainer.new()
	_apply_custom_panel_style(ladder_panel, C_PANEL_BG, C_BORDER)
	main_vbox.add_child(ladder_panel)

	var ladder_margin := MarginContainer.new()
	ladder_margin.add_theme_constant_override("margin_left", 24)
	ladder_margin.add_theme_constant_override("margin_right", 24)
	ladder_margin.add_theme_constant_override("margin_top", 16)
	ladder_margin.add_theme_constant_override("margin_bottom", 16)
	ladder_panel.add_child(ladder_margin)

	_rows_vbox = VBoxContainer.new()
	_rows_vbox.add_theme_constant_override("separation", 6)
	ladder_margin.add_child(_rows_vbox)

	# ── 3. 이번 런 요약 ──
	var summary_panel := PanelContainer.new()
	_apply_custom_panel_style(summary_panel, Color(0.12, 0.10, 0.04), C_NEON_GOLD)
	main_vbox.add_child(summary_panel)

	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 20)
	summary_margin.add_theme_constant_override("margin_right", 20)
	summary_margin.add_theme_constant_override("margin_top", 12)
	summary_margin.add_theme_constant_override("margin_bottom", 12)
	summary_panel.add_child(summary_margin)

	var summary_vbox := VBoxContainer.new()
	summary_vbox.add_theme_constant_override("separation", 6)
	summary_margin.add_child(summary_vbox)

	_summary_label = parent_scene.make_label("", 13, C_NEON_GOLD)
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_vbox.add_child(_summary_label)

	_brief_label = parent_scene.make_label("", 10, parent_scene.C_DIM)
	_brief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_vbox.add_child(_brief_label)

	# ── 3-B. 승천 등급 선택 (해금 후에만 나타난다) ──
	_asc_panel = PanelContainer.new()
	_apply_custom_panel_style(_asc_panel, Color(0.09, 0.06, 0.13), Color(0.55, 0.35, 0.75))
	main_vbox.add_child(_asc_panel)

	var asc_margin := MarginContainer.new()
	asc_margin.add_theme_constant_override("margin_left", 20)
	asc_margin.add_theme_constant_override("margin_right", 20)
	asc_margin.add_theme_constant_override("margin_top", 10)
	asc_margin.add_theme_constant_override("margin_bottom", 10)
	_asc_panel.add_child(asc_margin)

	var asc_vbox := VBoxContainer.new()
	asc_vbox.add_theme_constant_override("separation", 6)
	asc_margin.add_child(asc_vbox)

	var asc_row := HBoxContainer.new()
	asc_row.add_theme_constant_override("separation", 10)
	asc_vbox.add_child(asc_row)

	asc_row.add_child(parent_scene.make_label("🔺 승천", 13, C_ASCENSION))

	var btn_down: Button = parent_scene.make_button("◀", func(): _shift_ascension(-1), C_ASCENSION)
	btn_down.custom_minimum_size = Vector2(40, 28)
	asc_row.add_child(btn_down)

	_asc_level_label = parent_scene.make_label("", 13, C_ASCENSION)
	_asc_level_label.custom_minimum_size = Vector2(150, 0)
	_asc_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_row.add_child(_asc_level_label)

	var btn_up: Button = parent_scene.make_button("▶", func(): _shift_ascension(1), C_ASCENSION)
	btn_up.custom_minimum_size = Vector2(40, 28)
	asc_row.add_child(btn_up)

	var asc_spacer := Control.new()
	asc_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asc_row.add_child(asc_spacer)

	# 누적 조건 목록 — 등급이 곧 난이도라는 신뢰를 위해 **적용 중인 전부**를 보여준다.
	_asc_cond_label = parent_scene.make_label("", 10, parent_scene.C_DIM)
	_asc_cond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asc_vbox.add_child(_asc_cond_label)

	# ── 4. 액션바 ──
	var action_hbox := HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(action_hbox)

	var btn_back: Button = parent_scene.make_button("❌ 로비로 (Cancel)", _on_back_pressed, parent_scene.C_DANGER)
	btn_back.custom_minimum_size = Vector2(160, 40)
	action_hbox.add_child(btn_back)

	var btn_start: Button = parent_scene.make_button("🚀 상승 개시 (Ascend)", _on_confirm_pressed, C_NEON_GOLD)
	btn_start.custom_minimum_size = Vector2(240, 40)
	btn_start.add_theme_font_size_override("font_size", 12)
	action_hbox.add_child(btn_start)


## 해금 상태를 다시 읽어 사다리와 요약을 갱신한다.
func refresh_unlocked_sections() -> void:
	for child in _rows_vbox.get_children():
		child.queue_free()

	var order: Array = RunManager.SECTION_ORDER
	var reach_floors := 0
	var reach_key := ""

	# 공개 현황은 행 표시에 사용하되, 이번 상승 길이는 항상 전체 35층이다.
	for sec in order:
		if RunManager.meta_unlocked_sections.has(sec):
			reach_floors += int(MapGenerator.section_info(sec).floors)
			reach_key = str(sec)

	# 위층이 위에 오도록 역순 출력
	for i in range(order.size() - 1, -1, -1):
		var sec: String = str(order[i])
		var info: Dictionary = MapGenerator.section_info(sec)
		var unlocked: bool = RunManager.meta_unlocked_sections.has(sec)
		_rows_vbox.add_child(_make_row(sec, info, unlocked, i == 0, sec == reach_key))

	var total_floors := 0
	for sec in order:
		total_floors += int(MapGenerator.section_info(sec).floors)
	var summit_name: String = str(MapGenerator.section_info(str(order[order.size() - 1])).name)
	_summary_label.text = "이번 상승: %d층 · 보스 %d체 · %s까지" % [total_floors, order.size(), summit_name]
	_brief_label.text = "관문을 돌파하면 다음 계층이 즉시 열립니다. 덱과 장비를 유지한 채 정점까지 계속 오릅니다."

	_refresh_ascension()


## 승천 등급을 올리고 내린다. 해금 범위를 벗어날 수 없다.
func _shift_ascension(delta: int) -> void:
	RunManager.meta_ascension_level = clampi(
		RunManager.meta_ascension_level + delta, 0, RunManager.meta_ascension_unlocked)
	RunManager.save_meta()
	_refresh_ascension()


func _refresh_ascension() -> void:
	if not is_instance_valid(_asc_panel):
		return
	# 아직 정점을 못 밟았으면 승천은 존재하지 않는다 — 클리어 이후 콘텐츠이므로 미리 노출하지 않는다.
	_asc_panel.visible = RunManager.meta_ascension_unlocked > 0
	if not _asc_panel.visible:
		return

	var lv: int = RunManager.meta_ascension_level
	if lv <= 0:
		_asc_level_label.text = "없음"
		_asc_cond_label.text = "기본 난이도. ▶로 등급을 올리면 조건이 누적된다. (해금 %d등급까지)" % RunManager.meta_ascension_unlocked
	else:
		_asc_level_label.text = "%d등급 · %s" % [lv, Ascension.tier_title(lv)]
		# 누적된 조건을 전부 나열한다. 등급 N은 1~N이 동시에 걸리므로 일부만 보이면 오해가 생긴다.
		_asc_cond_label.text = "적용 중: " + "  /  ".join(Ascension.active_conditions(lv))


## 계층 한 줄. 해금되지 않은 계층은 흐리게 표시하되 존재는 보여준다(목표 각인).
func _make_row(sec: String, info: Dictionary, unlocked: bool, is_start: bool, is_top: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var col: Color = parent_scene.C_TEXT if unlocked else C_LOCKED

	var icon_lbl: Label = parent_scene.make_label(str(info.icon), 16, col)
	icon_lbl.custom_minimum_size = Vector2(28, 0)
	row.add_child(icon_lbl)

	var name_lbl: Label = parent_scene.make_label(str(info.name), 13, col)
	name_lbl.custom_minimum_size = Vector2(140, 0)
	row.add_child(name_lbl)

	var floors_lbl: Label = parent_scene.make_label("%d층" % int(info.floors), 11, col)
	floors_lbl.custom_minimum_size = Vector2(48, 0)
	floors_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(floors_lbl)

	var lv_lbl: Label = parent_scene.make_label(
		"LV.%d" % MapGenerator.absolute_level(sec, int(info.floors)), 10, parent_scene.C_DIM)
	lv_lbl.custom_minimum_size = Vector2(72, 0)
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lv_lbl)

	var tag := ""
	if not unlocked:
		tag = "🔒"
	elif is_start:
		tag = "← 시작"
	elif is_top:
		tag = "← 도달"
	var tag_lbl: Label = parent_scene.make_label(tag, 10, C_NEON_GOLD if unlocked else parent_scene.C_DIM)
	tag_lbl.custom_minimum_size = Vector2(64, 0)
	row.add_child(tag_lbl)

	var brief_lbl: Label = parent_scene.make_label(str(info.brief) if unlocked else "미확인 구역", 10, parent_scene.C_DIM)
	brief_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brief_lbl)

	return row


func _on_back_pressed() -> void:
	self.visible = false
	parent_scene.handle_section_selector_closed()


func _on_confirm_pressed() -> void:
	# 시작 계층은 고르는 것이 아니라 항상 최하 계층이다.
	self.visible = false
	parent_scene.show_loadout_screen(str(RunManager.SECTION_ORDER[0]))


func _apply_custom_panel_style(panel: PanelContainer, bg_color: Color, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
