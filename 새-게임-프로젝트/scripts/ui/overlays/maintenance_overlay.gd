class_name MaintenanceOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 정비실 오버레이 (무기 캐비닛 및 대피소 통합 뷰 - HTML 이식 버전)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager
var current_node: RunManager.RunNode

# ── 1. 기존 덱 정비 UI 변수 ──
var _deck_maint_layout: HBoxContainer
var _maint_title_label: Label
var _maint_desc_label: Label
var _maint_buttons_container: VBoxContainer
var _maint_deck_list: VBoxContainer
var _maint_confirm_btn: Button
var _deck_select_callback: Callable = func(idx): pass

# ── 2. 신규 파츠 개조 UI 변수 (HTML 프로토타입 이식) ──
var _parts_maint_layout: VBoxContainer
var _weapon_preview_name: Label
var _weapon_preview_cap: Label
var _weapon_icon_rect: TextureRect
var _parts_stack_row: HBoxContainer
var _parts_hold_row: HBoxContainer

# 우측 발견 카드 변수
var _new_part_title: Label
var _new_part_icon: Label
var _new_part_desc: Label
var _new_part_spec: Label
var _new_discovered_part: PartData = null

# 하단 예상 변화 및 경고 변수
var _proj_base_dmg: Label
var _proj_stack_mode: Label
var _proj_warning_msg: Label

# 파츠 버튼들
var _part_btn_equip: Button
var _part_btn_hold: Button
var _part_btn_discard: Button

# ── 색상 상수 ──
const C_BG_COLOR := Color(0.05, 0.05, 0.05, 0.95)
const C_PANEL_BG := Color(0.1, 0.1, 0.1, 1.0)
const C_BORDER := Color(0.2, 0.2, 0.2, 1.0)
const C_GOLD := Color(0.83, 0.69, 0.22, 1.0)
const C_RED := Color(1.0, 0.2, 0.2, 1.0)
const C_GREEN := Color(0.3, 0.69, 0.31, 1.0)
const C_SLOT_BG := Color(0.13, 0.13, 0.13, 1.0)


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	# 풀 화면 960x540 해상도를 꽉 채우기 위한 앵커 및 사이즈 플래그 명시
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(960, 540) # 960x540 강제 최소 크기 고정으로 쏠림 방지
	
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG_COLOR
	add_theme_stylebox_override("panel", style)
	
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	# ── 헤더 (Header) ──
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_lbl = parent_scene.make_label("PARTS MODIFICATION", 16, parent_scene.C_TEXT)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)
	
	var phase_lbl = parent_scene.make_label("[ SAFE ZONE : COMMIT PENDING ]", 11, parent_scene.C_DIM)
	header_hbox.add_child(phase_lbl)
	
	# 구분선
	var separator = ColorRect.new()
	separator.color = C_BORDER
	separator.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(separator)

	# ── 레이아웃 분기 컨테이너들 ──
	# A) 기존 덱 관리 정비 레이아웃
	_deck_maint_layout = HBoxContainer.new()
	_deck_maint_layout.add_theme_constant_override("separation", 28)
	_deck_maint_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_deck_maint_layout)
	_build_deck_maintenance_layout(_deck_maint_layout)

	# B) 신규 파츠 개조 레이아웃 (HTML 이식)
	_parts_maint_layout = VBoxContainer.new()
	_parts_maint_layout.add_theme_constant_override("separation", 16)
	_parts_maint_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parts_maint_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_parts_maint_layout)
	_build_parts_maintenance_layout(_parts_maint_layout)


## 기존 탄환 덱 강화/폐기용 레이아웃 생성
func _build_deck_maintenance_layout(parent: HBoxContainer) -> void:
	# 좌측 VBox
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 16)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.5
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(left_vbox)

	_maint_title_label = parent_scene.make_label("구역 이름", 26, parent_scene.C_WARNING)
	_maint_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_maint_title_label)

	_maint_desc_label = parent_scene.make_label("상호작용 설명", 16, parent_scene.C_DIM)
	_maint_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_maint_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(_maint_desc_label)

	_maint_buttons_container = VBoxContainer.new()
	_maint_buttons_container.add_theme_constant_override("separation", 8)
	left_vbox.add_child(_maint_buttons_container)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(spacer)

	_maint_confirm_btn = parent_scene.make_button("작전 구역 계속 탐색", _on_maint_confirm_pressed, parent_scene.C_ACCENT)
	_maint_confirm_btn.custom_minimum_size = Vector2(0, 44)
	left_vbox.add_child(_maint_confirm_btn)

	# 우측 VBox
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.5
	parent.add_child(right_vbox)

	right_vbox.add_child(parent_scene.make_label("🗃 보유 전술 탄환 덱 목록", 18, parent_scene.C_DIM))

	var list_panel: PanelContainer = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_top", 12)
	list_margin.add_theme_constant_override("margin_bottom", 12)
	list_panel.add_child(list_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_margin.add_child(scroll)

	_maint_deck_list = VBoxContainer.new()
	_maint_deck_list.add_theme_constant_override("separation", 4)
	_maint_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_maint_deck_list)


## 신규 파츠 개조 UI 레이아웃 생성
func _build_parts_maintenance_layout(parent: VBoxContainer) -> void:
	var split_hbox := HBoxContainer.new()
	split_hbox.add_theme_constant_override("separation", 24)
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(split_hbox)

	# ── 1. 좌측 패널 (Equipped Weapon & Stack) ──
	var left_panel: PanelContainer = parent_scene.make_panel(C_PANEL_BG)
	_apply_custom_panel_style(left_panel, C_PANEL_BG, C_BORDER)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.5
	split_hbox.add_child(left_panel)
	
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 12)
	left_margin.add_theme_constant_override("margin_right", 12)
	left_margin.add_theme_constant_override("margin_top", 10)
	left_margin.add_theme_constant_override("margin_bottom", 10)
	left_panel.add_child(left_margin)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_margin.add_child(left_vbox)

	# 1a) Equipped Weapon 프리뷰 영역
	left_vbox.add_child(parent_scene.make_label("Equipped Weapon", 11, parent_scene.C_DIM))
	
	var weapon_preview_panel = PanelContainer.new()
	weapon_preview_panel.custom_minimum_size = Vector2(0, 52)
	_apply_custom_panel_style(weapon_preview_panel, Color(0.07, 0.07, 0.08), Color(0.25, 0.25, 0.28))
	left_vbox.add_child(weapon_preview_panel)
	
	var wp_margin := MarginContainer.new()
	wp_margin.add_theme_constant_override("margin_left", 10)
	wp_margin.add_theme_constant_override("margin_right", 10)
	wp_margin.add_theme_constant_override("margin_top", 4)
	wp_margin.add_theme_constant_override("margin_bottom", 4)
	weapon_preview_panel.add_child(wp_margin)
	
	var wp_hbox := HBoxContainer.new()
	wp_margin.add_child(wp_hbox)
	
	var wp_info_vbox := VBoxContainer.new()
	wp_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wp_info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wp_hbox.add_child(wp_info_vbox)
	
	_weapon_preview_name = parent_scene.make_label("MK.4 리볼버", 13, C_GOLD)
	wp_info_vbox.add_child(_weapon_preview_name)
	
	_weapon_preview_cap = parent_scene.make_label("CAPACITY: 6", 10, parent_scene.C_DIM)
	wp_info_vbox.add_child(_weapon_preview_cap)
	
	_weapon_icon_rect = TextureRect.new()
	_weapon_icon_rect.custom_minimum_size = Vector2(70, 36)
	_weapon_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wp_hbox.add_child(_weapon_icon_rect)

	# 1b) Current Stack (LIFO) 슬롯 영역
	left_vbox.add_child(parent_scene.make_label("Current Stack (LIFO)", 11, parent_scene.C_DIM))
	
	_parts_stack_row = HBoxContainer.new()
	_parts_stack_row.add_theme_constant_override("separation", 8)
	left_vbox.add_child(_parts_stack_row)

	# 1c) Hold Buffer 영역
	left_vbox.add_child(parent_scene.make_label("Hold Buffer", 11, parent_scene.C_DIM))
	
	_parts_hold_row = HBoxContainer.new()
	_parts_hold_row.add_theme_constant_override("separation", 8)
	left_vbox.add_child(_parts_hold_row)

	# ── 2. 우측 패널 (New Part Discovered) ──
	var right_panel: PanelContainer = parent_scene.make_panel(Color.TRANSPARENT)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.5
	split_hbox.add_child(right_panel)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_vbox)
	
	right_vbox.add_child(parent_scene.make_label("New Part Discovered", 11, parent_scene.C_DIM))

	# 새 파츠 카드 (New Part Card)
	var new_card_panel = PanelContainer.new()
	new_card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_custom_panel_style(new_card_panel, Color(0.08, 0.08, 0.06), C_GOLD)
	right_vbox.add_child(new_card_panel)
	
	var nc_margin := MarginContainer.new()
	nc_margin.add_theme_constant_override("margin_left", 12)
	nc_margin.add_theme_constant_override("margin_right", 12)
	nc_margin.add_theme_constant_override("margin_top", 12)
	nc_margin.add_theme_constant_override("margin_bottom", 12)
	new_card_panel.add_child(nc_margin)
	
	var nc_vbox := VBoxContainer.new()
	nc_vbox.add_theme_constant_override("separation", 8)
	nc_margin.add_child(nc_vbox)
	
	var nc_header := HBoxContainer.new()
	nc_vbox.add_child(nc_header)
	
	_new_part_title = parent_scene.make_label("리듬 챔버", 13, C_GOLD)
	_new_part_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nc_header.add_child(_new_part_title)
	
	_new_part_icon = parent_scene.make_label("🥁", 16, parent_scene.C_TEXT)
	nc_header.add_child(_new_part_icon)
	
	_new_part_desc = parent_scene.make_label("", 10, parent_scene.C_TEXT)
	_new_part_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_new_part_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nc_vbox.add_child(_new_part_desc)
	
	# 스펙 박스 (Stat Box)
	var spec_panel = PanelContainer.new()
	_apply_custom_panel_style(spec_panel, Color(0.05, 0.05, 0.05), C_GOLD)
	nc_vbox.add_child(spec_panel)
	
	var spec_margin := MarginContainer.new()
	spec_margin.add_theme_constant_override("margin_left", 8)
	spec_margin.add_theme_constant_override("margin_right", 8)
	spec_margin.add_theme_constant_override("margin_top", 8)
	spec_margin.add_theme_constant_override("margin_bottom", 8)
	spec_panel.add_child(spec_margin)
	
	_new_part_spec = parent_scene.make_label("", 9, parent_scene.C_TEXT)
	_new_part_spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spec_margin.add_child(_new_part_spec)

	# ── 3. 하단 예상 변화 및 경고 패널 (Projection Panel) ──
	var projection_panel = PanelContainer.new()
	projection_panel.custom_minimum_size = Vector2(0, 30)
	_apply_custom_panel_style(projection_panel, Color.BLACK, C_BORDER)
	parent.add_child(projection_panel)
	
	var proj_margin := MarginContainer.new()
	proj_margin.add_theme_constant_override("margin_left", 14)
	proj_margin.add_theme_constant_override("margin_right", 14)
	proj_margin.add_theme_constant_override("margin_top", 5)
	proj_margin.add_theme_constant_override("margin_bottom", 5)
	projection_panel.add_child(proj_margin)
	
	var proj_hbox := HBoxContainer.new()
	proj_margin.add_child(proj_hbox)
	
	var proj_stats_hbox := HBoxContainer.new()
	proj_stats_hbox.add_theme_constant_override("separation", 16)
	proj_stats_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	proj_hbox.add_child(proj_stats_hbox)
	
	_proj_base_dmg = parent_scene.make_label("Base DMG: 15", 11, parent_scene.C_TEXT)
	proj_stats_hbox.add_child(_proj_base_dmg)
	
	_proj_stack_mode = parent_scene.make_label("Stack Mode: None", 11, C_GOLD)
	proj_stats_hbox.add_child(_proj_stack_mode)
	
	_proj_warning_msg = parent_scene.make_label("", 11, C_RED)
	proj_hbox.add_child(_proj_warning_msg)

	# ── 4. 하단 액션 버튼 그룹 (Actions) ──
	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 10)
	parent.add_child(action_hbox)
	
	_part_btn_equip = parent_scene.make_button("장착 및 교체 (Equip)", _on_parts_equip_pressed, C_GOLD)
	_part_btn_equip.custom_minimum_size = Vector2(0, 32)
	_part_btn_equip.add_theme_font_size_override("font_size", 10)
	_part_btn_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_hbox.add_child(_part_btn_equip)
	
	_part_btn_hold = parent_scene.make_button("임시 보관 (Hold Swap)", _on_parts_hold_pressed, parent_scene.C_TEXT)
	_part_btn_hold.custom_minimum_size = Vector2(0, 32)
	_part_btn_hold.add_theme_font_size_override("font_size", 10)
	_part_btn_hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_hbox.add_child(_part_btn_hold)
	
	_part_btn_discard = parent_scene.make_button("버리기 (Discard)", _on_parts_discard_pressed, C_RED)
	_part_btn_discard.custom_minimum_size = Vector2(0, 32)
	_part_btn_discard.add_theme_font_size_override("font_size", 10)
	_part_btn_discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_hbox.add_child(_part_btn_discard)
	
	# 계속 탐색 (Proceed) 버튼을 네 번째 칼럼으로 이관
	var exit_btn: Button = parent_scene.make_button("계속 탐색 (Proceed)", _on_maint_confirm_pressed, parent_scene.C_ACCENT)
	exit_btn.custom_minimum_size = Vector2(0, 32)
	exit_btn.add_theme_font_size_override("font_size", 10)
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_hbox.add_child(exit_btn)


## 정비실 페이즈 개시
func start_maintenance_phase(node: RunManager.RunNode) -> void:
	visible = true
	current_node = node
	
	# 노드 타입에 따라 레이아웃 토글
	if node.type_name.contains("무기 캐비닛"):
		_deck_maint_layout.visible = false
		_parts_maint_layout.visible = true
		
		# 데모용: 상자에서 발견된 파츠 랜덤 지정 (리듬 챔버 고정 / 샷건일 땐 포인트블랭크)
		if run_manager.current_gun and run_manager.current_gun.display_name.contains("샷건"):
			_new_discovered_part = load("res://resources/parts/point_blank.tres")
		else:
			_new_discovered_part = load("res://resources/parts/rhythm_chamber.tres")
			
		_refresh_parts_modification_ui()
	else:
		_deck_maint_layout.visible = true
		_parts_maint_layout.visible = false
		
		_maint_title_label.text = node.type_name
		_maint_desc_label.text = node.description
		
		# 3버튼 초기화 및 재생성
		for child in _maint_buttons_container.get_children():
			child.queue_free()
			
		_refresh_maintenance_deck_list()
		_build_deck_maintenance_buttons(node)


## 기존 덱 관련 정비 버튼 빌드
func _build_deck_maintenance_buttons(node: RunManager.RunNode) -> void:
	if node.type_name.contains("보급 캐비닛"):
		var btn_up: Button = parent_scene.make_button("장약 보강 (탄환 DMG+1)", func():
			_maint_desc_label.text = "장약 보강할 덱 탄환 카드를 아래 목록에서 클릭하세요."
			_maint_deck_list.visible = true
			_set_deck_list_callback(func(idx):
				run_manager.upgrade_bullet_in_deck(idx, "dmg")
				_maint_desc_label.text = "탄환 장약을 강화했습니다!"
				_refresh_maintenance_deck_list()
			)
		, parent_scene.C_ACCENT)
		_maint_buttons_container.add_child(btn_up)
		
		var btn_pol: Button = parent_scene.make_button("약실 소탕 (리로드면제)", func():
			run_manager.has_chamber_polish = true
			_maint_desc_label.text = "총기 약실 소탕 완료! 다음 전투에서 리로드 1회가 즉시 완료됩니다."
		, parent_scene.C_WARNING)
		_maint_buttons_container.add_child(btn_pol)
		
		var btn_disc: Button = parent_scene.make_button("탄환 폐기 (덱 압축)", func():
			_maint_desc_label.text = "폐기하여 녹여버릴 탄환 카드를 아래 목록에서 선택하세요."
			_maint_deck_list.visible = true
			_set_deck_list_callback(func(idx):
				run_manager.discard_bullet_from_deck(idx)
				_maint_desc_label.text = "탄환 카드를 덱에서 완전히 삭제했습니다."
				_refresh_maintenance_deck_list()
			)
		, parent_scene.C_DANGER)
		_maint_buttons_container.add_child(btn_disc)
		
	elif node.type_name.contains("대피소"):
		var btn_heal: Button = parent_scene.make_button("체력 아머 보급 (HP 버퍼 +1)", func():
			run_manager.hp_buffer = mini(run_manager.hp_buffer + 1, 3)
			_maint_desc_label.text = "의료 키트를 보급하여 HP 버퍼가 회복되었습니다. (현재 버퍼: %d)" % run_manager.hp_buffer
		, parent_scene.C_SUCCESS)
		_maint_buttons_container.add_child(btn_heal)
		
		var btn_rec: Button = parent_scene.make_button("소실 탄환 복구", func():
			var recovered := run_manager.recover_discarded_bullets()
			_maint_desc_label.text = "이전 전투에서 Unload하여 분실했던 탄환 %d발을 무사히 복구했습니다!" % recovered
			_refresh_maintenance_deck_list()
		, parent_scene.C_ACCENT)
		_maint_buttons_container.add_child(btn_rec)
		
	elif node.type_name.contains("보안 통제실"):
		var btn_hack: Button = parent_scene.make_button("터미널 보안 해킹 개시", func():
			parent_scene.force_goggles_on_title()
			_maint_desc_label.text = "보안 터미널 해킹 완료! [스마트 센서 고글] 렐릭이 강제로 장착되어 적 정보가 투명하게 공개됩니다."
		, parent_scene.C_ACCENT)
		_maint_buttons_container.add_child(btn_hack)


# ── 파츠 개조 전용 UI 갱신 로직 ──
func _refresh_parts_modification_ui() -> void:
	if run_manager == null or run_manager.current_gun == null:
		return
		
	var gun := run_manager.current_gun
	_weapon_preview_name.text = gun.display_name
	_weapon_preview_cap.text = "CAPACITY: %d" % gun.parts_capacity
	_weapon_icon_rect.texture = gun.icon
	
	# 1. 장착 LIFO 스택 슬롯 빌드
	for child in _parts_stack_row.get_children():
		child.queue_free()
		
	# 안티시너지 충돌 상태 판별 (리듬챔버 + 인터럽터 공존 검증)
	var has_rhythm := false
	var has_interrupter := false
	
	# 발견된 파츠 포함 공존 여부
	var temp_all_parts := run_manager.equipped_parts.duplicate()
	for p in temp_all_parts:
		if p.part_id == 2: has_rhythm = true
		if p.part_id == 3: has_interrupter = true
		
	var is_conflict := has_rhythm and has_interrupter
	
	for i in range(gun.parts_capacity):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(64, 76)
		
		# 장착 여부 확인
		var is_equipped := i < run_manager.equipped_parts.size()
		var slot_color := C_SLOT_BG
		var border_color := C_BORDER
		
		# 충돌 시 붉은색 테두리
		if is_equipped:
			var part = run_manager.equipped_parts[i]
			var is_part_conflict = is_conflict and (part.part_id == 2 or part.part_id == 3)
			border_color = C_RED if is_part_conflict else Color(0.35, 0.35, 0.35)
		
		_apply_custom_panel_style(slot_panel, slot_color, border_color)
		_parts_stack_row.add_child(slot_panel)
		
		# 슬롯 넘버링 라벨
		var num_margin := MarginContainer.new()
		num_margin.add_theme_constant_override("margin_left", 3)
		num_margin.add_theme_constant_override("margin_top", 3)
		slot_panel.add_child(num_margin)
		
		var num_lbl = parent_scene.make_label(str(i + 1), 8, parent_scene.C_DIM)
		num_margin.add_child(num_lbl)
		
		# 슬롯 내부 vbox
		var svbox := VBoxContainer.new()
		svbox.add_theme_constant_override("separation", 2)
		svbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_panel.add_child(svbox)
		
		if is_equipped:
			var part = run_manager.equipped_parts[i]
			var icon_emoji := _get_part_emoji(part.part_id)
			svbox.add_child(parent_scene.make_label(icon_emoji, 18, parent_scene.C_TEXT))
			
			var name_lbl = parent_scene.make_label(part.display_name.split(" ")[0], 8, parent_scene.C_TEXT)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			svbox.add_child(name_lbl)
		else:
			svbox.add_child(parent_scene.make_label("", 18, parent_scene.C_DIM))
			var name_lbl = parent_scene.make_label("[ EMPTY ]", 8, parent_scene.C_DIM)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			svbox.add_child(name_lbl)
			
	# 2. Hold 슬롯 빌드
	for child in _parts_hold_row.get_children():
		child.queue_free()
		
	var hold_panel = PanelContainer.new()
	hold_panel.custom_minimum_size = Vector2(64, 76)
	
	var hold_border = C_GOLD if run_manager.hold_part else Color(0.2, 0.2, 0.2, 0.5)
	_apply_custom_panel_style(hold_panel, C_SLOT_BG, hold_border)
	_parts_hold_row.add_child(hold_panel)
	
	# H 라벨
	var hold_num_margin := MarginContainer.new()
	hold_num_margin.add_theme_constant_override("margin_left", 3)
	hold_num_margin.add_theme_constant_override("margin_top", 3)
	hold_panel.add_child(hold_num_margin)
	hold_num_margin.add_child(parent_scene.make_label("H", 8, parent_scene.C_DIM))
	
	var hold_vbox := VBoxContainer.new()
	hold_vbox.add_theme_constant_override("separation", 2)
	hold_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hold_panel.add_child(hold_vbox)
	
	if run_manager.hold_part:
		var part = run_manager.hold_part
		hold_vbox.add_child(parent_scene.make_label(_get_part_emoji(part.part_id), 18, parent_scene.C_TEXT))
		var name_lbl = parent_scene.make_label(part.display_name.split(" ")[0], 8, parent_scene.C_TEXT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hold_vbox.add_child(name_lbl)
	else:
		hold_vbox.add_child(parent_scene.make_label("🔒", 18, parent_scene.C_DIM))
		var name_lbl = parent_scene.make_label("비활성화 됨", 8, parent_scene.C_DIM)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hold_vbox.add_child(name_lbl)

	# 3. 우측 발견 카드 내용 업데이트
	if _new_discovered_part:
		_new_part_title.text = _new_discovered_part.display_name
		_new_part_icon.text = _get_part_emoji(_new_discovered_part.part_id)
		_new_part_desc.text = _new_discovered_part.description
		
		# 스펙 명세 파싱
		if _new_discovered_part.part_id == 2: # 리듬챔버
			_new_part_spec.text = "• 조건: 직전 탄환과 동일 구경\n• 효과: 격발당 DMG +3 누적 증가\n• 슬롯: 층위 1 (스택 레이어)"
		elif _new_discovered_part.part_id == 6: # 포인트블랭크
			_new_part_spec.text = "• 조건: 타겟과의 거리 DIST 1~2\n• 효과: 근접 타격 시 DMG +4 가산\n• 슬롯: 층위 2 (거리 레이어)"
		else:
			_new_part_spec.text = "• 조건: 기본 장착\n• 효과: 고유 시그니처 혜택 부여\n• 슬롯: 전용 내장 슬롯"
	else:
		_new_part_title.text = "발견된 파츠 없음"
		_new_part_icon.text = "📦"
		_new_part_desc.text = "캐비닛이 텅 비어 있습니다."
		_new_part_spec.text = "-"

	# 4. 예상 변화 및 안티시너지 경고 업데이트
	_proj_base_dmg.text = "Base DMG: %d" % (10 + (run_manager.equipped_parts.size() * 2))
	
	if has_rhythm:
		_proj_stack_mode.text = "Stack Mode: Combo"
	elif has_interrupter:
		_proj_stack_mode.text = "Stack Mode: Alternate"
	else:
		_proj_stack_mode.text = "Stack Mode: Normal"
		
	if is_conflict:
		_proj_warning_msg.text = "안티시너지 경고: '인터럽터(교차 교대)'와 상극입니다!"
		_proj_warning_msg.visible = true
	else:
		_proj_warning_msg.visible = false

	# 버튼 상태 최적화
	_part_btn_equip.disabled = _new_discovered_part == null
	_part_btn_hold.disabled = _new_discovered_part == null
	_part_btn_discard.disabled = _new_discovered_part == null


# ── 파츠 전용 상호작용 액션 버튼 함수들 ──

## 1. 장착 및 교체 (Equip)
func _on_parts_equip_pressed() -> void:
	if _new_discovered_part == null:
		return
		
	var gun = run_manager.current_gun
	if run_manager.equipped_parts.size() < gun.parts_capacity:
		# 빈 슬롯이 있으면 즉시 장착
		run_manager.equip_part_to_slot(_new_discovered_part)
		_new_discovered_part = null
	else:
		# 슬롯이 가득 찼으면 첫 번째 파츠를 덮어쓰며 파괴
		run_manager.replace_equipped_part(0, _new_discovered_part)
		_new_discovered_part = null
		
	_refresh_parts_modification_ui()


## 2. 임시 보관 (Hold Swap)
func _on_parts_hold_pressed() -> void:
	if _new_discovered_part == null:
		return
		
	# Hold 슬롯에 이미 파츠가 들어 있다면 맞바꿈(스왑)
	var old_hold = run_manager.store_in_hold(_new_discovered_part)
	_new_discovered_part = old_hold # 밀려난 파츠를 우측 발견 카드로 돌림
	_refresh_parts_modification_ui()


## 3. 버리기 (Discard)
func _on_parts_discard_pressed() -> void:
	# 프로토타입: 발견된 새 파츠를 영구 파괴
	_new_discovered_part = null
	_refresh_parts_modification_ui()


# ── 보조 및 기존 공통 메서드들 ──

func _refresh_maintenance_deck_list() -> void:
	for child in _maint_deck_list.get_children():
		child.queue_free()
		
	for i in range(run_manager.deck.size()):
		var b := run_manager.deck[i]
		var label_text := "%d. %s  DMG:%d ACC:%d PEN:%d" % [
			i + 1, b.display_name, b.damage, b.accuracy, b.penetration
		]
		if b.knockback > 0: label_text += " KB:%d" % b.knockback
		
		var l: Label = parent_scene.make_label(label_text, 18, parent_scene.C_TEXT)
		_maint_deck_list.add_child(l)


func _set_deck_list_callback(cb: Callable) -> void:
	_deck_select_callback = cb
	for child in _maint_deck_list.get_children():
		child.queue_free()
		
	for i in range(run_manager.deck.size()):
		var b := run_manager.deck[i]
		var btn_text := "%d. %s (선택)" % [i + 1, b.display_name]
		var idx := i
		var btn: Button = parent_scene.make_button(btn_text, func(): _deck_select_callback.call(idx), parent_scene.C_PANEL)
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(0, 36)
		_maint_deck_list.add_child(btn)


func _on_maint_confirm_pressed() -> void:
	visible = false
	parent_scene.handle_maintenance_finished()


## 테마 스타일 지정 헬퍼
func _apply_custom_panel_style(panel: PanelContainer, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	panel.add_theme_stylebox_override("panel", style)


## 파츠 ID에 대응하는 이모지 헬퍼
func _get_part_emoji(part_id: int) -> String:
	match part_id:
		1: return "📥" # 딥로더
		2: return "🥁" # 리듬챔버
		3: return "⚡" # 인터럽터
		4: return "🔽" # 언더플로우
		5: return "⛓" # 체이서
		6: return "💥" # 포인트블랭크
		7: return "🎯" # 고정밀총열
		23: return "🔒" # 저격경
	return "🔧"
