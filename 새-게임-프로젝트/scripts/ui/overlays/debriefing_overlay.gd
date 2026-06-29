class_name DebriefingOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 작전 종료 및 크레딧 정산 오버레이
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

	_debrief_confirm_btn = parent_scene.make_button("기지 복귀", _on_debrief_confirm_pressed, parent_scene.C_ACCENT)
	_debrief_confirm_btn.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(_debrief_confirm_btn)


func show_debriefing(won: bool) -> void:
	visible = true
	if won:
		_debrief_title.text = "★ 작전 종료: 탈출 헬기 탑승 성공!"
		_debrief_title.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
	else:
		_debrief_title.text = "💀 작전 실패: 요원 무력화됨..."
		_debrief_title.add_theme_color_override("font_color", parent_scene.C_DANGER)
		
	var earned := run_manager.end_run(won)
	
	var log_text := "── 작전 디브리핑 정산 내역 ──\n\n"
	log_text += "- 도달한 층수: %d 층 (x15 Cr) = %d Cr\n" % [run_manager.current_floor, run_manager.current_floor * 15]
	log_text += "- 보유한 렐릭 보너스: %d 개 (x20 Cr) = %d Cr\n" % [run_manager.active_relics.size(), run_manager.active_relics.size() * 20]
	if won:
		log_text += "- 헬기 보딩 성공 보너스 = 50 Cr\n"
	log_text += "──────────────────────────\n"
	log_text += "[color=#ffff44]총 환전된 크레딧: +%d Cr[/color]\n\n" % earned
	log_text += "누적 보유 크레딧: %d Cr\n" % RunManager.meta_credits
	log_text += "다음 작전을 준비하기 위해 영구 메타 상점에서 기량을 해금하세요."
	
	_debrief_log.text = log_text


func _on_debrief_confirm_pressed() -> void:
	visible = false
	parent_scene.handle_debrief_confirmed()
