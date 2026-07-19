class_name MaintenanceOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 듀얼 스크린 복합 무기고 단말기 오버레이 (상점/장비 탭 우측 가방 인벤토리 상시 노출)
## ═══════════════════════════════════════════════════

const ConsumableItem = preload("res://scripts/data/consumable_item.gd")

var parent_scene: Control
var run_manager: RunManager
var current_node: RunManager.RunNode

# ── 전역 가변 상태 ──
var _active_tab: int = 0 # 0: 보급 단말(Shop), 1: 무기 장비(Equip)
var _reroll_count: int = 0
var _shop_items: Array = [] # { "item": Resource, "price": int, "sold_out": bool }
var _selected_bag_idx: int = -1

# ── UI 컨테이너 및 참조 ──
var _tab_nav_hbox: HBoxContainer
var _tab_content_panel: PanelContainer
var _reroll_cost_btn: Button
var _tab_btns: Array[Button] = []

# 1. 🛒 보급 단말 탭 UI 참조
var _shop_vbox: VBoxContainer
var _shop_credit_lbl: Label
var _shop_grid: HBoxContainer
var _shop_bag_grid_container: GridContainer
var _shop_bag_capacity_lbl: Label
# 상점 탭 우측 물자 상세 패널
var _shop_bag_detail_panel: PanelContainer
var _shop_bag_detail_title: Label
var _shop_bag_detail_type: Label
var _shop_bag_detail_desc: Label
var _shop_bag_action_btn: Button
var _shop_bag_discard_btn: Button

# 2. 🛡️ 무기 장비 탭 UI 참조
var _equip_vbox: VBoxContainer
var _equip_weapon_title: Label
var _equip_weapon_icon: TextureRect
var _equip_slots_hbox: HBoxContainer
var _equip_bag_grid_container: GridContainer
var _equip_bag_capacity_lbl: Label
# 무기 예상 스탯 변화 게이지바 및 수치 레이블
var _stat_dmg_bar: ProgressBar
var _stat_dmg_val: Label
var _stat_kb_bar: ProgressBar
var _stat_kb_val: Label
var _stat_reload_bar: ProgressBar
var _stat_reload_val: Label

# ── 색상 상수 ──
const C_BG_COLOR := Color(0.05, 0.06, 0.09, 0.97)
const C_PANEL_BG := Color(0.08, 0.10, 0.15, 1.0)
const C_BORDER := Color(0.18, 0.23, 0.32, 1.0)
const C_GOLD := Color(0.92, 0.76, 0.20, 1.0)
const C_CYAN := Color(0.00, 0.86, 1.00, 1.0)
const C_BLUE := Color(0.00, 0.40, 1.00, 1.0)
const C_RED := Color(0.95, 0.26, 0.26, 1.0)
const C_GREEN := Color(0.22, 0.85, 0.45, 1.0)
const C_SLOT_BG := Color(0.12, 0.15, 0.22, 1.0)


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(960, 540)
	
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG_COLOR
	add_theme_stylebox_override("panel", style)
	
	if get_child_count() == 0:
		_build_ui()
	
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	# ── [1] 상단 헤더 & 탭 네비게이션 (2탭 간결화) ──
	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(header_hbox)
	
	_tab_nav_hbox = HBoxContainer.new()
	_tab_nav_hbox.add_theme_constant_override("separation", 0)
	header_hbox.add_child(_tab_nav_hbox)
	
	var tab_shop = Button.new()
	tab_shop.text = "🛒 보급 단말 (Shop)"
	tab_shop.focus_mode = Control.FOCUS_NONE
	tab_shop.pressed.connect(func(): _switch_tab(0))
	_tab_nav_hbox.add_child(tab_shop)
	_tab_btns.append(tab_shop)
	
	var tab_equip = Button.new()
	tab_equip.text = "🛡️ 무기 장비 (Equip)"
	tab_equip.focus_mode = Control.FOCUS_NONE
	tab_equip.pressed.connect(func(): _switch_tab(1))
	_tab_nav_hbox.add_child(tab_equip)
	_tab_btns.append(tab_equip)
	
	# 중앙 우측 스페이스 및 리롤 버튼
	var spacer_h := Control.new()
	spacer_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer_h)
	
	_reroll_cost_btn = parent_scene.make_button("📡 주파수 재요청 (3c)", _on_reroll_pressed, parent_scene.C_WARNING)
	_reroll_cost_btn.custom_minimum_size = Vector2(180, 36)
	_reroll_cost_btn.add_theme_font_size_override("font_size", 11)
	header_hbox.add_child(_reroll_cost_btn)

	# 구분선
	var separator = ColorRect.new()
	separator.color = C_BORDER
	separator.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(separator)

	# ── [2] 메인 컨텐츠 영역 (탭별 좌우 2분할 듀얼 스크린 배치) ──
	_tab_content_panel = PanelContainer.new()
	_tab_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var content_style := StyleBoxEmpty.new()
	_tab_content_panel.add_theme_stylebox_override("panel", content_style)
	main_vbox.add_child(_tab_content_panel)

	# 탭 구조물 생성
	_build_shop_layout()
	_build_equip_layout()
	
	# ── [3] 하단 네비게이션 액션 바 ──
	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(footer_hbox)
	
	var exit_btn = parent_scene.make_button("계속 탐색 (Proceed) ▸", _on_exit_pressed, parent_scene.C_SUCCESS)
	exit_btn.custom_minimum_size = Vector2(180, 40)
	exit_btn.add_theme_font_size_override("font_size", 14)
	footer_hbox.add_child(exit_btn)


# ── 각 탭 레이아웃 빌딩 함수 ──

## 1. 🛒 보급 단말 탭 빌드 (좌: 상점 진열대 / 우: 8칸 가방 & 상세패널)
func _build_shop_layout() -> void:
	_shop_vbox = VBoxContainer.new()
	_shop_vbox.add_theme_constant_override("separation", 10)
	_shop_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_content_panel.add_child(_shop_vbox)

	var split_hbox := HBoxContainer.new()
	split_hbox.add_theme_constant_override("separation", 20)
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_vbox.add_child(split_hbox)

	# 1) 좌측: 상점 진열 영역
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.55
	split_hbox.add_child(left_vbox)

	var info_hbox := HBoxContainer.new()
	left_vbox.add_child(info_hbox)
	
	var desc_lbl = parent_scene.make_label("보급 단말기: 기업 크레딧으로 파츠/탄환을 구매하고 가방으로 자동 이송시킵니다.", 12, parent_scene.C_DIM)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_hbox.add_child(desc_lbl)
	
	_shop_credit_lbl = parent_scene.make_label("보유 크레딧: 0 Cr", 15, C_GOLD)
	info_hbox.add_child(_shop_credit_lbl)

	_shop_grid = HBoxContainer.new()
	_shop_grid.add_theme_constant_override("separation", 12)
	_shop_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_shop_grid)

	# 2) 우측: 상점 탭 우측 가방 인벤토리
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.45
	_apply_custom_panel_style(right_panel, C_PANEL_BG, C_BORDER)
	split_hbox.add_child(right_panel)
	
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 12)
	right_margin.add_theme_constant_override("margin_right", 12)
	right_margin.add_theme_constant_override("margin_top", 12)
	right_margin.add_theme_constant_override("margin_bottom", 12)
	right_panel.add_child(right_margin)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_margin.add_child(right_vbox)

	var title_hbox := HBoxContainer.new()
	right_vbox.add_child(title_hbox)
	title_hbox.add_child(parent_scene.make_label("🎒 가방 보관함 (상시 대조)", 14, parent_scene.C_TEXT))
	var spacer_b := Control.new(); spacer_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_hbox.add_child(spacer_b)
	_shop_bag_capacity_lbl = parent_scene.make_label("(0/8)", 12, C_GREEN)
	title_hbox.add_child(_shop_bag_capacity_lbl)

	# 가방 8칸 그리드
	_shop_bag_grid_container = GridContainer.new()
	_shop_bag_grid_container.columns = 4
	_shop_bag_grid_container.add_theme_constant_override("h_separation", 8)
	_shop_bag_grid_container.add_theme_constant_override("v_separation", 8)
	right_vbox.add_child(_shop_bag_grid_container)

	# 가방 상세 정보 패널
	_shop_bag_detail_panel = PanelContainer.new()
	_apply_custom_panel_style(_shop_bag_detail_panel, Color(0.06, 0.08, 0.12), C_BORDER)
	_shop_bag_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_shop_bag_detail_panel)
	
	var d_margin := MarginContainer.new()
	d_margin.add_theme_constant_override("margin_left", 10)
	d_margin.add_theme_constant_override("margin_right", 10)
	d_margin.add_theme_constant_override("margin_top", 10)
	d_margin.add_theme_constant_override("margin_bottom", 10)
	_shop_bag_detail_panel.add_child(d_margin)
	
	var d_vbox := VBoxContainer.new()
	d_vbox.add_theme_constant_override("separation", 6)
	d_margin.add_child(d_vbox)

	_shop_bag_detail_title = parent_scene.make_label("물자를 선택해 주십시오", 13, C_GOLD)
	d_vbox.add_child(_shop_bag_detail_title)

	_shop_bag_detail_type = parent_scene.make_label("-", 9.5, parent_scene.C_DIM)
	d_vbox.add_child(_shop_bag_detail_type)

	_shop_bag_detail_desc = parent_scene.make_label("가방 속 물건을 클릭하면 상세 설명 및 덱 추가/사용 버튼이 여기에 활성화됩니다.", 10.5, parent_scene.C_DIM)
	_shop_bag_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_bag_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_vbox.add_child(_shop_bag_detail_desc)

	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	d_vbox.add_child(action_hbox)

	_shop_bag_action_btn = parent_scene.make_button("물자 사용 / 덱 추가", _on_bag_action_pressed, C_GOLD)
	_shop_bag_action_btn.custom_minimum_size = Vector2(0, 30)
	_shop_bag_action_btn.add_theme_font_size_override("font_size", 9.5)
	_shop_bag_action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_bag_action_btn.disabled = true
	action_hbox.add_child(_shop_bag_action_btn)

	_shop_bag_discard_btn = parent_scene.make_button("버리기", _on_bag_discard_pressed, C_RED)
	_shop_bag_discard_btn.custom_minimum_size = Vector2(0, 30)
	_shop_bag_discard_btn.add_theme_font_size_override("font_size", 9.5)
	_shop_bag_discard_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_bag_discard_btn.disabled = true
	action_hbox.add_child(_shop_bag_discard_btn)


## 2. 🛡️ 무기 장비 탭 빌드 (좌: 파츠 장착 및 스탯 시뮬레이션 / 우: 가방 내 파츠 퀵 스왑 장착)
func _build_equip_layout() -> void:
	_equip_vbox = VBoxContainer.new()
	_equip_vbox.add_theme_constant_override("separation", 10)
	_equip_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equip_vbox.visible = false
	_tab_content_panel.add_child(_equip_vbox)

	var split_hbox := HBoxContainer.new()
	split_hbox.add_theme_constant_override("separation", 20)
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equip_vbox.add_child(split_hbox)

	# 1) 좌측: 무기 개조 및 성능 시뮬레이터
	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.55
	_apply_custom_panel_style(left_panel, C_PANEL_BG, C_BORDER)
	split_hbox.add_child(left_panel)
	
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 14)
	left_margin.add_theme_constant_override("margin_right", 14)
	left_margin.add_theme_constant_override("margin_top", 14)
	left_margin.add_theme_constant_override("margin_bottom", 14)
	left_panel.add_child(left_margin)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_margin.add_child(left_vbox)

	_equip_weapon_title = parent_scene.make_label("장착 총기: MK.4 리볼버", 15, C_GOLD)
	left_vbox.add_child(_equip_weapon_title)

	_equip_weapon_icon = TextureRect.new()
	_equip_weapon_icon.custom_minimum_size = Vector2(160, 60)
	_equip_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_equip_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_equip_weapon_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_vbox.add_child(_equip_weapon_icon)

	left_vbox.add_child(parent_scene.make_label("현재 장착된 전술 개조 파츠 (LIFO 스택 역순 작동)", 11, parent_scene.C_DIM))

	_equip_slots_hbox = HBoxContainer.new()
	_equip_slots_hbox.add_theme_constant_override("separation", 16)
	left_vbox.add_child(_equip_slots_hbox)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(spacer)

	# 스탯 시뮬레이터 계측 영역 통합
	var stats_panel := PanelContainer.new()
	_apply_custom_panel_style(stats_panel, Color(0.06, 0.08, 0.12), C_BORDER)
	left_vbox.add_child(stats_panel)
	
	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 12)
	stats_margin.add_theme_constant_override("margin_right", 12)
	stats_margin.add_theme_constant_override("margin_top", 10)
	stats_margin.add_theme_constant_override("margin_bottom", 10)
	stats_panel.add_child(stats_margin)
	
	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 8)
	stats_margin.add_child(stats_vbox)

	stats_vbox.add_child(parent_scene.make_label("📈 개조 파츠 적용에 따른 스탯 변화 실시간 계측", 12, parent_scene.C_TEXT))

	# 스탯 1: 데미지
	var dmg_vbox := VBoxContainer.new()
	stats_vbox.add_child(dmg_vbox)
	var dmg_title_hbox := HBoxContainer.new()
	dmg_vbox.add_child(dmg_title_hbox)
	dmg_title_hbox.add_child(parent_scene.make_label("기본 피해량 (Base Damage)", 10, parent_scene.C_DIM))
	var spacer1 := Control.new(); spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dmg_title_hbox.add_child(spacer1)
	_stat_dmg_val = parent_scene.make_label("10 (+2)", 10, C_CYAN)
	dmg_title_hbox.add_child(_stat_dmg_val)
	_stat_dmg_bar = ProgressBar.new()
	_stat_dmg_bar.max_value = 30
	_stat_dmg_bar.custom_minimum_size = Vector2(0, 10)
	_stat_dmg_bar.show_percentage = false
	dmg_vbox.add_child(_stat_dmg_bar)

	# 스탯 2: 넉백
	var kb_vbox := VBoxContainer.new()
	stats_vbox.add_child(kb_vbox)
	var kb_title_hbox := HBoxContainer.new()
	kb_vbox.add_child(kb_title_hbox)
	kb_title_hbox.add_child(parent_scene.make_label("격퇴력 (Knockback Force)", 10, parent_scene.C_DIM))
	var spacer2 := Control.new(); spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; kb_title_hbox.add_child(spacer2)
	_stat_kb_val = parent_scene.make_label("1 (+1)", 10, C_CYAN)
	kb_title_hbox.add_child(_stat_kb_val)
	_stat_kb_bar = ProgressBar.new()
	_stat_kb_bar.max_value = 6
	_stat_kb_bar.custom_minimum_size = Vector2(0, 10)
	_stat_kb_bar.show_percentage = false
	kb_vbox.add_child(_stat_kb_bar)

	# 스탯 3: 장전 딜레이
	var reload_vbox := VBoxContainer.new()
	stats_vbox.add_child(reload_vbox)
	var reload_title_hbox := HBoxContainer.new()
	reload_vbox.add_child(reload_title_hbox)
	reload_title_hbox.add_child(parent_scene.make_label("장전 소요 턴수 (Reload Turns)", 10, parent_scene.C_DIM))
	var spacer3 := Control.new(); spacer3.size_flags_horizontal = Control.SIZE_EXPAND_FILL; reload_title_hbox.add_child(spacer3)
	_stat_reload_val = parent_scene.make_label("4 (0)", 10, parent_scene.C_TEXT)
	reload_title_hbox.add_child(_stat_reload_val)
	_stat_reload_bar = ProgressBar.new()
	_stat_reload_bar.max_value = 8
	_stat_reload_bar.custom_minimum_size = Vector2(0, 10)
	_stat_reload_bar.show_percentage = false
	reload_vbox.add_child(_stat_reload_bar)

	# 2) 우측: 장비 탭 우측 가방 영역 (파츠 퀵 스왑 장착용)
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.45
	_apply_custom_panel_style(right_panel, C_PANEL_BG, C_BORDER)
	split_hbox.add_child(right_panel)
	
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 12)
	right_margin.add_theme_constant_override("margin_right", 12)
	right_margin.add_theme_constant_override("margin_top", 12)
	right_margin.add_theme_constant_override("margin_bottom", 12)
	right_panel.add_child(right_margin)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_margin.add_child(right_vbox)

	var title_hbox_eq := HBoxContainer.new()
	right_vbox.add_child(title_hbox_eq)
	title_hbox_eq.add_child(parent_scene.make_label("🎒 가방 보관함 (파츠 퀵 장착)", 14, parent_scene.C_TEXT))
	var spacer_b_eq := Control.new(); spacer_b_eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_hbox_eq.add_child(spacer_b_eq)
	_equip_bag_capacity_lbl = parent_scene.make_label("(0/8)", 12, C_GREEN)
	title_hbox_eq.add_child(_equip_bag_capacity_lbl)

	# 가방 8칸 그리드
	_equip_bag_grid_container = GridContainer.new()
	_equip_bag_grid_container.columns = 4
	_equip_bag_grid_container.add_theme_constant_override("h_separation", 8)
	_equip_bag_grid_container.add_theme_constant_override("v_separation", 8)
	right_vbox.add_child(_equip_bag_grid_container)

	# 안내 스펙 패널
	var help_panel = PanelContainer.new()
	_apply_custom_panel_style(help_panel, Color(0.06, 0.08, 0.12), C_BORDER)
	help_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(help_panel)
	
	var h_margin := MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 10)
	h_margin.add_theme_constant_override("margin_right", 10)
	h_margin.add_theme_constant_override("margin_top", 10)
	h_margin.add_theme_constant_override("margin_bottom", 10)
	help_panel.add_child(h_margin)
	
	var h_vbox := VBoxContainer.new()
	h_vbox.add_theme_constant_override("separation", 6)
	h_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	h_margin.add_child(h_vbox)

	h_vbox.add_child(parent_scene.make_label("💡 개조 전술 가이드", 13, C_GOLD))
	var help_txt = parent_scene.make_label("1. 가방 속 개조 파츠를 클릭하면 비어 있는 장착 슬롯에 즉시 조립됩니다.\n\n2. 장착 슬롯이 가득 찬 상태에서 다른 파츠를 장착 신청하면, 1번 슬롯의 이전 파츠가 가방으로 탈거되면서 스왑됩니다.\n\n3. 장착 파츠별 실제 성능 시뮬레이션 결과가 좌측 하단 게이지 바에 실시간 집계됩니다.", 10.5, parent_scene.C_DIM)
	help_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h_vbox.add_child(help_txt)


# ── 데이터 로드 및 상태 동기화 ──

func start_maintenance_phase(node: RunManager.RunNode) -> void:
	visible = true
	current_node = node
	
	_reroll_count = 0
	_selected_bag_idx = -1
	
	_generate_shop_items()
	_switch_tab(0)


func _switch_tab(tab_idx: int) -> void:
	_active_tab = tab_idx
	
	for i in range(_tab_btns.size()):
		_apply_tab_style(_tab_btns[i], i == tab_idx)
		
	_shop_vbox.visible = (tab_idx == 0)
	_equip_vbox.visible = (tab_idx == 1)
	
	_reroll_cost_btn.visible = (tab_idx == 0)
	_refresh_current_tab_ui()


func _refresh_current_tab_ui() -> void:
	if run_manager == null: return
	
	_shop_credit_lbl.text = "보유 크레딧: %d Cr" % run_manager.credits
	_reroll_cost_btn.text = "📡 주파수 재요청 (%dc)" % (3 * (_reroll_count + 1))
	_reroll_cost_btn.disabled = run_manager.credits < (3 * (_reroll_count + 1))
	
	match _active_tab:
		0:
			_refresh_shop_tab()
			_refresh_backpack_view(_shop_bag_grid_container, _shop_bag_capacity_lbl, false)
		1:
			_refresh_equip_tab()
			_refresh_backpack_view(_equip_bag_grid_container, _equip_bag_capacity_lbl, true)


# ── 각 탭별 세부 렌더링 로직 ──

## 1) 🛒 보급 단말 탭 진열대 그리기
func _refresh_shop_tab() -> void:
	for child in _shop_grid.get_children():
		child.queue_free()
		
	for i in range(_shop_items.size()):
		var slot_data = _shop_items[i]
		var item: Resource = slot_data.item
		var price: int = slot_data.price
		var sold_out: bool = slot_data.sold_out
		
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(175, 260) # 듀얼 스크린화에 따른 슬림 조율
		_apply_custom_panel_style(card, C_PANEL_BG, C_GOLD if not sold_out else C_BORDER)
		_shop_grid.add_child(card)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)
		
		var display_name := ""
		var type_str := ""
		var desc_str := ""
		var icon_emoji := "📦"
		
		if item is BulletData:
			display_name = item.display_name
			type_str = "특수 탄환 Box"
			desc_str = "DMG:%d ACC:%d PEN:%d\n효과: %s" % [item.damage, item.accuracy, item.penetration, _get_bullet_effect_desc(item)]
			icon_emoji = "🔴"
		elif item is PartData:
			display_name = item.display_name
			type_str = "개조 파츠"
			desc_str = item.description
			icon_emoji = _get_part_emoji(item.part_id)
		elif item is ConsumableItem:
			display_name = item.display_name
			type_str = "소모성 물자"
			desc_str = item.description
			icon_emoji = item.icon_text
			
		var title_lbl = parent_scene.make_label("%s %s" % [icon_emoji, display_name.split(" ")[0]], 12.5, parent_scene.C_TEXT)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title_lbl)
		
		var type_lbl = parent_scene.make_label(type_str, 9, C_CYAN)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(type_lbl)

		# 아이콘 이미지 렌더링
		var img_rect: Control
		
		if item is BulletData and item.icon:
			var tr := TextureRect.new()
			tr.texture = item.icon
			tr.custom_minimum_size = Vector2(80, 52)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			img_rect = tr
		elif item is PartData and item.icon:
			var tr := TextureRect.new()
			tr.texture = item.icon
			tr.custom_minimum_size = Vector2(80, 52)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			img_rect = tr
		else:
			var placeholder_style := StyleBoxFlat.new()
			placeholder_style.bg_color = Color(0.15, 0.18, 0.24, 0.4)
			placeholder_style.corner_radius_top_left = 4; placeholder_style.corner_radius_top_right = 4
			placeholder_style.corner_radius_bottom_left = 4; placeholder_style.corner_radius_bottom_right = 4
			
			var p_container := PanelContainer.new()
			p_container.custom_minimum_size = Vector2(80, 52)
			p_container.add_theme_stylebox_override("panel", placeholder_style)
			p_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			
			var p_lbl = parent_scene.make_label(icon_emoji, 20, Color.WHITE)
			p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			p_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			p_container.add_child(p_lbl)
			img_rect = p_container
			
		vbox.add_child(img_rect)
		
		var desc_lbl = parent_scene.make_label(desc_str, 9.5, parent_scene.C_DIM)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)
		
		var btn_buy: Button
		if sold_out:
			btn_buy = parent_scene.make_button("SOLD OUT", func(): pass, parent_scene.C_PANEL)
			btn_buy.disabled = true
		else:
			btn_buy = parent_scene.make_button("💳 구매 (%d)" % price, func(): _on_buy_item_pressed(i), C_GOLD)
			btn_buy.disabled = run_manager.credits < price
			
		btn_buy.custom_minimum_size = Vector2(0, 32)
		btn_buy.add_theme_font_size_override("font_size", 9.5)
		vbox.add_child(btn_buy)


## 2) 🛡️ 무기 장비 탭 좌측 스택 렌더링
func _refresh_equip_tab() -> void:
	if run_manager == null or run_manager.current_gun == null: return
	
	var gun := run_manager.current_gun
	_equip_weapon_title.text = "장착 총기: %s (최대 개조슬롯: %d칸)" % [gun.display_name, gun.parts_capacity]
	
	if is_instance_valid(_equip_weapon_icon):
		_equip_weapon_icon.texture = gun.icon
	
	# 장착된 파츠 슬롯 렌더링
	for child in _equip_slots_hbox.get_children():
		child.queue_free()
		
	var has_rhythm := false
	var has_interrupter := false
	for p in run_manager.equipped_parts:
		if p.part_id == Enums.PartID.RHYTHM_CHAMBER: has_rhythm = true
		if p.part_id == Enums.PartID.INTERRUPTER: has_interrupter = true
	var is_conflict = has_rhythm and has_interrupter

	for i in range(gun.parts_capacity):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(80, 90)
		
		var is_equipped := i < run_manager.equipped_parts.size()
		var slot_color = C_SLOT_BG
		var border_color = C_BORDER
		
		if is_equipped:
			var part = run_manager.equipped_parts[i]
			var is_part_conflict = is_conflict and (part.part_id == Enums.PartID.RHYTHM_CHAMBER or part.part_id == Enums.PartID.INTERRUPTER)
			border_color = C_RED if is_part_conflict else C_GOLD
			
		_apply_custom_panel_style(slot, slot_color, border_color)
		_equip_slots_hbox.add_child(slot)
		
		var svbox := VBoxContainer.new()
		svbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(svbox)
		
		if is_equipped:
			var part = run_manager.equipped_parts[i]
			var emoji = _get_part_emoji(part.part_id)
			svbox.add_child(parent_scene.make_label(emoji, 20, parent_scene.C_TEXT))
			
			var name_lbl = parent_scene.make_label(part.display_name.split(" ")[0], 9, parent_scene.C_TEXT)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			svbox.add_child(name_lbl)
			
			if part.part_id != Enums.PartID.POINT_BLANK:
				var idx = i
				var btn_deq = parent_scene.make_button("탈거", func(): _on_dequip_part_pressed(idx), C_RED)
				btn_deq.custom_minimum_size = Vector2(50, 20)
				btn_deq.add_theme_font_size_override("font_size", 8)
				svbox.add_child(btn_deq)
			else:
				var lbl_fixed = parent_scene.make_label("[고정]", 8, parent_scene.C_DIM)
				lbl_fixed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				svbox.add_child(lbl_fixed)
		else:
			svbox.add_child(parent_scene.make_label("🔧", 20, parent_scene.C_DIM))
			var name_lbl = parent_scene.make_label("[ 슬롯 비어있음 ]", 8, parent_scene.C_DIM)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			svbox.add_child(name_lbl)
			
	# 실시간 스탯 변화량 시뮬레이션
	var base_dmg = 10
	var kb_force = 1
	var reload_turns = gun.reload_turns
	
	for part in run_manager.equipped_parts:
		# 1) 대미지 보정 파츠 시뮬레이션
		if part.part_id == Enums.PartID.SHRED_MUZZLE:
			base_dmg += 2 # 적 방어력 영구 파쇄 기여 반영
		elif part.part_id == Enums.PartID.POINT_BLANK:
			base_dmg += 4 # 초근접 DMG +4 반영
		elif part.part_id == Enums.PartID.LONG_SHOT:
			base_dmg += 3 # 원거리 DMG 비례 가산 평균 반영
		elif part.part_id == Enums.PartID.DEEP_LOADER:
			base_dmg += 3 # 바닥 탄 DMG 가산 평균 반영
		elif part.part_id == Enums.PartID.RHYTHM_CHAMBER:
			base_dmg += 2 # 연속 격발 DMG 가산 평균 반영
			
		# 2) 넉백 보정 파츠 시뮬레이션
		if part.part_id == Enums.PartID.RECOIL_PUSH:
			kb_force += 1 # 처치 시 연쇄 넉백 반영
		elif part.part_id == Enums.PartID.SPREAD_SHOT:
			kb_force += 1 # 확산 격발 넉백 분산 반영
			
	_stat_dmg_bar.value = base_dmg
	var dmg_diff = base_dmg - 10
	_stat_dmg_val.text = "%d (%s%d)" % [base_dmg, "+" if dmg_diff >= 0 else "", dmg_diff]
	_stat_dmg_bar.modulate = C_CYAN if dmg_diff > 0 else Color.WHITE

	_stat_kb_bar.value = kb_force
	var kb_diff = kb_force - 1
	_stat_kb_val.text = "%d (%s%d)" % [kb_force, "+" if kb_diff >= 0 else "", kb_diff]
	_stat_kb_bar.modulate = C_CYAN if kb_diff > 0 else Color.WHITE

	_stat_reload_bar.value = reload_turns
	var reload_diff = reload_turns - gun.reload_turns
	_stat_reload_val.text = "%d (%s%d)" % [reload_turns, "+" if reload_diff > 0 else "", reload_diff]
	_stat_reload_bar.modulate = C_CYAN if reload_diff < 0 else Color.WHITE


## 3) 🎒 공통 가방 인벤토리 그리드 렌더링 헬퍼
func _refresh_backpack_view(grid_container: GridContainer, cap_label: Label, is_equip_mode: bool) -> void:
	if not is_instance_valid(grid_container): return
	
	for child in grid_container.get_children():
		child.queue_free()
		
	var bag_size = run_manager.backpack_items.size()
	cap_label.text = "(%d / %d)" % [bag_size, run_manager.BACKPACK_CAPACITY]
	if bag_size >= run_manager.BACKPACK_CAPACITY:
		cap_label.add_theme_color_override("font_color", C_RED)
	else:
		cap_label.add_theme_color_override("font_color", C_GREEN)
		
	# 8개 그리드 슬롯 고정 렌더링
	for i in range(run_manager.BACKPACK_CAPACITY):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(64, 64) # 슬림 레이아웃 조율
		
		var has_item = i < bag_size
		var is_selected = (not is_equip_mode) and (i == _selected_bag_idx)
		
		var border_color = C_CYAN if is_selected else C_BORDER
		_apply_custom_panel_style(slot, C_SLOT_BG, border_color)
		grid_container.add_child(slot)
		
		var svbox := VBoxContainer.new()
		svbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(svbox)
		
		if has_item:
			var item = run_manager.backpack_items[i]
			var emoji = "📦"
			var name_str = item.display_name.split(" ")[0]
			
			if item is BulletData:
				emoji = "🔴"
			elif item is PartData:
				emoji = _get_part_emoji(item.part_id)
			elif item is ConsumableItem:
				emoji = item.icon_text
				
			svbox.add_child(parent_scene.make_label(emoji, 18, parent_scene.C_TEXT))
			
			var name_lbl = parent_scene.make_label(name_str, 8.5, parent_scene.C_TEXT)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			svbox.add_child(name_lbl)
			
			var idx = i
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					if is_equip_mode:
						# 장비 탭: 클릭 시 즉각 슬롯에 장착/스왑 처리
						_on_equip_part_from_bag(idx)
					else:
						# 상점 탭: 클릭 시 상세 패널 로드 및 액션 버튼 대기
						_on_bag_slot_selected(idx)
			)
		else:
			svbox.add_child(parent_scene.make_label("-", 14, parent_scene.C_DIM))
			var name_lbl = parent_scene.make_label("[ 비어있음 ]", 8, parent_scene.C_DIM)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			svbox.add_child(name_lbl)

	if not is_equip_mode:
		_refresh_bag_detail_panel()


## 가방 상세설명 리프레시 (상점 탭 전용)
func _refresh_bag_detail_panel() -> void:
	if _selected_bag_idx < 0 or _selected_bag_idx >= run_manager.backpack_items.size():
		_shop_bag_detail_title.text = "가방 내 물자를 선택해 주십시오"
		_shop_bag_detail_type.text = "-"
		_shop_bag_detail_desc.text = "인벤토리 슬롯을 클릭하면 해당 물자의 전술 스펙과 액션이 활성화됩니다."
		_shop_bag_action_btn.disabled = true
		_shop_bag_discard_btn.disabled = true
		return
		
	var item = run_manager.backpack_items[_selected_bag_idx]
	_shop_bag_discard_btn.disabled = false
	_shop_bag_action_btn.disabled = false
	
	if item is BulletData:
		_shop_bag_detail_title.text = "🔴 " + item.display_name
		_shop_bag_detail_type.text = "소지 유형: 특수 전술 탄환 상자"
		_shop_bag_detail_desc.text = "DMG: %d  ACC: %d%%  PEN: %d\n효과: %s\n\n[ 즉발 덱 장전 ]\n상자를 뜯어 획득한 특수탄을 1발 전술 덱에 즉시 편입시킵니다." % [
			item.damage, item.accuracy, item.penetration, _get_bullet_effect_desc(item)
		]
		_shop_bag_action_btn.text = "🔴 덱에 탄환 추가 (Add)"
		
	elif item is PartData:
		_shop_bag_detail_title.text = _get_part_emoji(item.part_id) + " " + item.display_name
		_shop_bag_detail_type.text = "소지 유형: 총기 개조 파츠 (Tier %d)" % item.tier
		_shop_bag_detail_desc.text = item.description + "\n\n[ 조작 안내 ]\n본 파츠를 총기에 결합하려면 상단의 '무기 장비 (Equip)' 탭으로 이동하여 가방 슬롯 속 이 파츠를 눌러 조립하십시오."
		_shop_bag_action_btn.text = "🛡️ 장비 탭으로 장착 가이드"
		
	elif item is ConsumableItem:
		_shop_bag_detail_title.text = item.icon_text + " " + item.display_name
		_shop_bag_detail_type.text = "소지 유형: 전술 소모성 즉발 물자"
		_shop_bag_detail_desc.text = item.description + "\n\n[ 즉발 물자 사용 ]\n소모품을 격발하여 즉시 해당 전술 효과를 얻고 가방에서 소진시킵니다."
		_shop_bag_action_btn.text = "✚ 물자 즉발 사용 (Use)"


# ── 버튼 상호작용 콜백 함수들 ──

## 1. 상점 리롤 버튼 클릭 시
func _on_reroll_pressed() -> void:
	var cost = 3 * (_reroll_count + 1)
	if run_manager.spend_credits(cost):
		_reroll_count += 1
		_generate_shop_items()
		_refresh_current_tab_ui()


## 2. 상점 품목 구매 버튼 클릭 시
func _on_buy_item_pressed(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _shop_items.size(): return
	var slot_data = _shop_items[slot_idx]
	var item = slot_data.item
	var price = slot_data.price
	
	if run_manager.backpack_items.size() >= run_manager.BACKPACK_CAPACITY:
		print("❌ 가방 용량 부족! 구매할 수 없습니다.")
		return
		
	if run_manager.spend_credits(price):
		run_manager.add_to_backpack(item)
		_shop_items[slot_idx].sold_out = true
		_refresh_current_tab_ui()


## 3. 파츠 장착 해제 (탈거)
func _on_dequip_part_pressed(part_idx: int) -> void:
	if run_manager.backpack_items.size() >= run_manager.BACKPACK_CAPACITY:
		print("❌ 가방 용량이 꽉 차 파츠를 탈거할 수 없습니다.")
		return
		
	if part_idx >= 0 and part_idx < run_manager.equipped_parts.size():
		var removed_part = run_manager.equipped_parts[part_idx]
		run_manager.equipped_parts.remove_at(part_idx)
		run_manager.add_to_backpack(removed_part)
		_refresh_current_tab_ui()


## 4. 가방 퀵 파츠 장착 (Equip 탭 우측 가방에서 클릭 시 호출)
func _on_equip_part_from_bag(bag_item_idx: int) -> void:
	if bag_item_idx < 0 or bag_item_idx >= run_manager.backpack_items.size(): return
	var item = run_manager.backpack_items[bag_item_idx]
	if not (item is PartData): return
	
	var gun = run_manager.current_gun
	if gun == null: return
	
	if run_manager.equipped_parts.size() < gun.parts_capacity:
		run_manager.equipped_parts.append(item)
		run_manager.remove_from_backpack_at(bag_item_idx)
	else:
		# 교체 가능한 일반 파츠(탈거 불가인 POINT_BLANK, SPREAD_SHOT이 아닌 파츠) 찾기
		var target_idx := -1
		for i in range(run_manager.equipped_parts.size()):
			var p = run_manager.equipped_parts[i]
			if p != null and p.part_id != Enums.PartID.POINT_BLANK and p.part_id != Enums.PartID.SPREAD_SHOT:
				target_idx = i
				break
		
		if target_idx != -1:
			var old_equipped = run_manager.equipped_parts[target_idx]
			run_manager.equipped_parts[target_idx] = item
			run_manager.backpack_items[bag_item_idx] = old_equipped
		else:
			print("⚠ 모든 슬롯에 해제 불가능한 고유 파츠가 장착되어 있어 파츠를 장착할 수 없습니다.")
			return
		
	_refresh_current_tab_ui()


## 5. 가방 슬롯 선택 시 (상점 탭 우측)
func _on_bag_slot_selected(idx: int) -> void:
	_selected_bag_idx = idx
	_refresh_current_tab_ui()


## 6. 가방 사용/장착 버튼 클릭 시 (상점 탭 우측 상세)
func _on_bag_action_pressed() -> void:
	if _selected_bag_idx < 0 or _selected_bag_idx >= run_manager.backpack_items.size(): return
	var item = run_manager.backpack_items[_selected_bag_idx]
	
	if item is BulletData:
		run_manager.add_to_deck(item)
		run_manager.remove_from_backpack_at(_selected_bag_idx)
		_selected_bag_idx = -1
		_refresh_current_tab_ui()
		
	elif item is PartData:
		# 장비 탭으로 장착 가이드 안내 전환
		_switch_tab(1)
			
	elif item is ConsumableItem:
		if item.type == "heal":
			run_manager.hp_buffer = mini(run_manager.hp_buffer + 1, 3)
			print("💊 소모품 즉발 사용: HP 버퍼가 회복되었습니다.")
		elif item.type == "shred":
			print("💊 소모품 즉발 사용: 타겟 파쇄액 투척 효과 발동!")
		
		run_manager.remove_from_backpack_at(_selected_bag_idx)
		_selected_bag_idx = -1
		_refresh_current_tab_ui()


## 7. 가방 버리기 버튼 클릭 시 (상점 탭 우측 상세)
func _on_bag_discard_pressed() -> void:
	if _selected_bag_idx < 0 or _selected_bag_idx >= run_manager.backpack_items.size(): return
	run_manager.remove_from_backpack_at(_selected_bag_idx)
	_selected_bag_idx = -1
	_refresh_current_tab_ui()


## 8. 무기고 이탈 (정비 종료)
func _on_exit_pressed() -> void:
	visible = false
	parent_scene.handle_maintenance_finished()


# ── 무작위 상점 진열 생성 ──
func _generate_shop_items() -> void:
	_shop_items.clear()
	
	var bullet_paths := [
		"res://resources/bullets/shred_rifle.tres",
		"res://resources/bullets/heavy_dmr.tres",
		"res://resources/bullets/slow_pistol.tres",
		"res://resources/bullets/knockback_pistol.tres"
	]
	var bullet_res = load(bullet_paths.pick_random())
	_shop_items.append({ "item": bullet_res, "price": randi_range(20, 25), "sold_out": false })

	var part_paths := [
		"res://resources/parts/rhythm_chamber.tres",
		"res://resources/parts/deep_loader.tres",
		"res://resources/parts/point_blank.tres",
		"res://resources/parts/recoil_push.tres",
		"res://resources/parts/marksman_scope.tres",
		"res://resources/parts/shred_muzzle.tres",
		# ── 신규 편입 파츠 (전투 로직 기구현분 리소스화) ──
		"res://resources/parts/interrupter.tres",
		"res://resources/parts/underflow.tres",
		"res://resources/parts/chaser.tres",
		"res://resources/parts/long_shot.tres",
		"res://resources/parts/executioner.tres",
		"res://resources/parts/high_precision.tres",
		"res://resources/parts/armor_piercing.tres",
		"res://resources/parts/versatile_chamber.tres",
		"res://resources/parts/target_indicator.tres",
		"res://resources/parts/chain_acc.tres",
		"res://resources/parts/inertia_fire.tres",
		"res://resources/parts/blind_fire.tres",
		"res://resources/parts/quick_load.tres"
	]
	var part_res = load(part_paths.pick_random())
	_shop_items.append({ "item": part_res, "price": randi_range(30, 45), "sold_out": false })

	var c1 := ConsumableItem.new()
	c1.display_name = "응급 아머 키트"
	c1.description = "요원의 외골격 아머를 즉시 긴급 정비합니다.\n[즉발 효과] 보유 HP 버퍼가 +1 충전됩니다 (최대 3)."
	c1.price = 20
	c1.type = "heal"
	c1.icon_text = "✚"

	var c2 := ConsumableItem.new()
	c2.display_name = "부식성 전술 파쇄액"
	c2.description = "화학 산화 약제가 들어있는 투척 플라스크입니다.\n[전투 예비] 적 장갑을 일시적으로 부식시켜 교전 돌입 시 적 수비를 감쇄합니다."
	c2.price = 15
	c2.type = "shred"
	c2.icon_text = "◆"
	
	var c_res = c1 if randf() < 0.5 else c2
	_shop_items.append({ "item": c_res, "price": c_res.price, "sold_out": false })


# ── 기타 헬퍼 유틸리티 함수 ──

func _get_bullet_effect_desc(bullet: BulletData) -> String:
	match bullet.effect_type:
		Enums.BulletEffect.ARMOR_SHRED: return "타격 시 적 장갑 영구 파쇄"
		Enums.BulletEffect.COMBO: return "연속 적중 시 콤보 피해"
		Enums.BulletEffect.LAST_SHOT: return "탄창 마지막 탄 위력 극대화"
		Enums.BulletEffect.OPENING_SHOT: return "첫 사격 시 기습 치명상"
	return "없음"

func _apply_tab_style(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.bg_color = C_PANEL_BG if active else Color(0.04, 0.05, 0.08)
	style.border_width_bottom = 2 if active else 1
	style.border_color = C_GOLD if active else C_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	var text_color = Color.WHITE if active else parent_scene.C_DIM
	btn.add_theme_color_override("font_color", text_color)

func _apply_custom_panel_style(panel: PanelContainer, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	panel.add_theme_stylebox_override("panel", style)

func _get_part_emoji(part_id: int) -> String:
	match part_id:
		Enums.PartID.DEEP_LOADER: return "📥"
		Enums.PartID.RHYTHM_CHAMBER: return "🥁"
		Enums.PartID.INTERRUPTER: return "⚡"
		Enums.PartID.UNDERFLOW: return "🔽"
		Enums.PartID.CHASER: return "⛓"
		Enums.PartID.POINT_BLANK: return "💥"
		Enums.PartID.HIGH_PRECISION: return "🎯"
		Enums.PartID.MARKSMAN_SCOPE: return "🔬"
	return "🔧"
