class_name SectionSelectorOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 작전 구역 선택 (Section Selector) 오버레이
## ═══════════════════════════════════════════════════

const SECTION_PROFILES := {
	"section_a": {
		"name": "지하 주차장",
		"emoji": "🚗",
		"desc": "폐쇄된 지하 주차장의 치안 병력을 돌파하십시오.\n기본 좀비와 방패병이 주로 출현합니다.",
		"floors": "10층 구조",
		"difficulty": "★☆☆☆☆ (입문)"
	},
	"section_b": {
		"name": "사무동 하층",
		"emoji": "🏢",
		"desc": "복잡한 격실과 오피스 구역을 돌파합니다.\n경보 장치 및 순찰 드론과 술사 기동대가 출현합니다.",
		"floors": "12층 구조",
		"difficulty": "★★☆☆☆ (초급)"
	},
	"section_c": {
		"name": "연구소 중층",
		"emoji": "🧪",
		"desc": "중장갑 병기와 독성 화학 실험 구역입니다.\n충격을 흡수하는 기계화 몬스터가 첫 배치됩니다.",
		"floors": "12층 구조",
		"difficulty": "★★★☆☆ (중급)"
	},
	"section_d": {
		"name": "펜트하우스",
		"emoji": "🌇",
		"desc": "최상층 상류층 거주 구역의 삼엄한 사설 경비대.\n최고 등급의 좀비들과 교란 드론이 방어를 강화합니다.",
		"floors": "15층 구조",
		"difficulty": "★★★★☆ (상급)"
	},
	"section_e": {
		"name": "무한 루프",
		"emoji": "♾️",
		"desc": "끝을 알 수 없는 루프 기믹의 극한 봉쇄 시뮬레이터.\n모든 유형의 정예 병력이 한꺼번에 몰아칩니다.",
		"floors": "15층 구조",
		"difficulty": "★★★★★ (도전)"
	}
}

const C_BORDER := Color(0.2, 0.2, 0.25, 1.0)
const C_NEON_GOLD := Color(0.83, 0.69, 0.22, 1.0)
const C_PANEL_BG := Color(0.08, 0.08, 0.12, 1.0)

var parent_scene: Control
var run_manager: RunManager

var selected_section_key: String = "section_a"
var _section_cards: Dictionary = {}
var _desc_label: Label
var _floors_label: Label
var _diff_label: Label
var _btn_confirm: Button


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	# 풀 화면 오버레이 어두운 스타일 적용
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	add_theme_stylebox_override("panel", style)
	
	_build_ui()
	refresh_unlocked_sections()
	_select_section("section_a")


func _build_ui() -> void:
	# 마진 설정
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 24)
	margin.add_child(main_vbox)
	
	# 1. 헤더 영역
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(header_vbox)
	
	var title_lbl = parent_scene.make_label("◀ SELECT DEPLOYMENT ZONE ▶", 24, C_NEON_GOLD)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(title_lbl)
	
	var subtitle_lbl = parent_scene.make_label("작전을 개시할 침투 구역을 지정하십시오.", 11, parent_scene.C_DIM)
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(subtitle_lbl)
	
	# 2. 중앙 구역 카드 리스트 영역
	var cards_hbox := HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(cards_hbox)
	
	for sec_key in SECTION_PROFILES.keys():
		var profile = SECTION_PROFILES[sec_key]
		
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(160, 200)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		cards_hbox.add_child(card)
		_section_cards[sec_key] = card
		
		# 카드 내부 레이아웃
		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 12)
		card_margin.add_theme_constant_override("margin_right", 12)
		card_margin.add_theme_constant_override("margin_top", 16)
		card_margin.add_theme_constant_override("margin_bottom", 16)
		card.add_child(card_margin)
		
		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 12)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_margin.add_child(card_vbox)
		
		# 이모지 아이콘
		var emoji_lbl = parent_scene.make_label(profile.emoji, 32, parent_scene.C_TEXT)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(emoji_lbl)
		
		# 구역 이름
		var name_lbl = parent_scene.make_label(profile.name, 14, parent_scene.C_TEXT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(name_lbl)
		
		# 잠금 레이블 (초기 숨김)
		var lock_lbl = parent_scene.make_label("🔒 LOCKED", 10, parent_scene.C_DANGER)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.name = "LockLabel"
		card_vbox.add_child(lock_lbl)
		
		# 클릭 이벤트 바인딩
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var is_unlocked := RunManager.meta_unlocked_sections.has(sec_key)
				if is_unlocked:
					_select_section(sec_key)
		)
		
	# 3. 구역 상세 스펙 패널
	var spec_panel := PanelContainer.new()
	_apply_custom_panel_style(spec_panel, C_PANEL_BG, C_BORDER)
	spec_panel.custom_minimum_size = Vector2(0, 100)
	main_vbox.add_child(spec_panel)
	
	var spec_margin := MarginContainer.new()
	spec_margin.add_theme_constant_override("margin_left", 20)
	spec_margin.add_theme_constant_override("margin_right", 20)
	spec_margin.add_theme_constant_override("margin_top", 12)
	spec_margin.add_theme_constant_override("margin_bottom", 12)
	spec_panel.add_child(spec_margin)
	
	var spec_hbox := HBoxContainer.new()
	spec_hbox.add_theme_constant_override("separation", 24)
	spec_margin.add_child(spec_hbox)
	
	var spec_left_vbox := VBoxContainer.new()
	spec_left_vbox.add_theme_constant_override("separation", 6)
	spec_left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spec_hbox.add_child(spec_left_vbox)
	
	spec_left_vbox.add_child(parent_scene.make_label("▶ ZONE TACTICAL BRIEFING", 10, parent_scene.C_DIM))
	_desc_label = parent_scene.make_label("구역에 대한 전술 브리핑 정보가 표시됩니다.", 11, parent_scene.C_TEXT)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spec_left_vbox.add_child(_desc_label)
	
	var spec_right_vbox := VBoxContainer.new()
	spec_right_vbox.add_theme_constant_override("separation", 8)
	spec_right_vbox.custom_minimum_size = Vector2(200, 0)
	spec_hbox.add_child(spec_right_vbox)
	
	# 층 규모 정보
	var floors_hbox := HBoxContainer.new()
	spec_right_vbox.add_child(floors_hbox)
	floors_hbox.add_child(parent_scene.make_label("구역 규모:", 10, parent_scene.C_DIM))
	_floors_label = parent_scene.make_label("10층", 11, parent_scene.C_TEXT)
	floors_hbox.add_child(_floors_label)
	
	# 위험도 난이도 정보
	var diff_hbox := HBoxContainer.new()
	spec_right_vbox.add_child(diff_hbox)
	diff_hbox.add_child(parent_scene.make_label("침투 위험:", 10, parent_scene.C_DIM))
	_diff_label = parent_scene.make_label("★☆☆☆☆", 11, parent_scene.C_TEXT)
	diff_hbox.add_child(_diff_label)
	
	# 4. 하단 제어 액션바
	var action_hbox := HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(action_hbox)
	
	var btn_back = parent_scene.make_button("❌ 로비로 (Cancel)", _on_back_pressed, parent_scene.C_DANGER)
	btn_back.custom_minimum_size = Vector2(160, 40)
	action_hbox.add_child(btn_back)
	
	_btn_confirm = parent_scene.make_button("🚀 침투 구역 확정 (Confirm)", _on_confirm_pressed, C_NEON_GOLD)
	_btn_confirm.custom_minimum_size = Vector2(240, 40)
	_btn_confirm.add_theme_font_size_override("font_size", 12)
	action_hbox.add_child(_btn_confirm)


func refresh_unlocked_sections() -> void:
	for sec_key in _section_cards.keys():
		var card = _section_cards[sec_key]
		var is_unlocked := RunManager.meta_unlocked_sections.has(sec_key)
		var lock_lbl = card.find_child("LockLabel", true, false)
		
		if is_unlocked:
			card.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if lock_lbl: lock_lbl.visible = false
		else:
			card.modulate = Color(1.0, 1.0, 1.0, 0.45)
			if lock_lbl: lock_lbl.visible = true
			
		# 선택 상태 갱신
		_update_card_style(sec_key)


func _select_section(sec_key: String) -> void:
	selected_section_key = sec_key
	
	# 모든 카드 스타일 갱신
	for k in _section_cards.keys():
		_update_card_style(k)
		
	# 상세 정보 반영
	var profile = SECTION_PROFILES[sec_key]
	_desc_label.text = profile.desc
	_floors_label.text = profile.floors
	_diff_label.text = profile.difficulty


func _update_card_style(sec_key: String) -> void:
	var card = _section_cards[sec_key]
	var is_unlocked := RunManager.meta_unlocked_sections.has(sec_key)
	
	if sec_key == selected_section_key:
		_apply_custom_panel_style(card, Color(0.18, 0.18, 0.22), C_NEON_GOLD)
	else:
		if is_unlocked:
			_apply_custom_panel_style(card, Color.BLACK, Color(0.2, 0.2, 0.25))
		else:
			_apply_custom_panel_style(card, Color(0.04, 0.04, 0.06), Color(0.15, 0.15, 0.15))


func _on_back_pressed() -> void:
	# 로비 타이틀 화면으로 돌아감
	self.visible = false
	parent_scene.handle_section_selector_closed()


func _on_confirm_pressed() -> void:
	# 구역 확정 -> 요원 준비실 진입
	self.visible = false
	parent_scene.show_loadout_screen(selected_section_key)


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
