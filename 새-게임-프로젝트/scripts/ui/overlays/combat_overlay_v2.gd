class_name CombatOverlayV2
extends MarginContainer

## ═══════════════════════════════════════════════════
## 🧠 L.O.B 전투 UI V2 데모 오버레이 (새로운 노드 트리 구조 기반 설계)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager
var combat_manager: CombatManager

# ── 프리로드 리소스 ──
var _bullets_basic: BulletData = preload("res://resources/bullets/basic_pistol.tres")
var _bullets_ap: BulletData = preload("res://resources/bullets/shred_rifle.tres")
var _bullets_kb: BulletData = preload("res://resources/bullets/knockback_pistol.tres")
var _bullets_heavy: BulletData = preload("res://resources/bullets/heavy_dmr.tres")
var _bullets_slow: BulletData = preload("res://resources/bullets/slow_pistol.tres")

# ── 서브 컴포넌트 프리로드 ──
const CylinderView = preload("res://scripts/ui/components/cylinder_view.gd")
const EnemyTrackView = preload("res://scripts/ui/components/enemy_track_view.gd")
const BagInventoryDrawer = preload("res://scripts/ui/components/bag_inventory_drawer.gd")

# ── 상태 ──
var _bullet_pool: Dictionary = {}
var _loaded_bullets: Array[BulletData] = []
var _enemy_sprites: Dictionary:
	get:
		if is_instance_valid(_track_control):
			return _track_control.enemy_sprites
		return {}
var _global_max_dist: float = 12.0
var _is_targeting_mode: bool = false
var _is_bag_expanded: bool = false
var _animate_last_insert: bool = false
var _last_bullet_count: int = -1
var _last_loaded_count: int = 0
var _current_gun_data: GunData
var _current_enemy_data: EnemyData

# ── UI 참조 (MainFlow 내부 자식들) ──
# 1. TopBar
var _top_log_toast: Label
var _phase_label: Label

# 2. DistanceLabel (CenterContainer로 감싸서 관리)
var _distance_container: CenterContainer
var _distance_label: Label

# 3. Battlefield
var _battlefield_container: HBoxContainer
var _loading_container: VBoxContainer
var _loading_stack_vbox: VBoxContainer
var _loading_stack_cap: Label
var _loading_ref_dist: Label
var _loading_bag_ammo: VBoxContainer
var _loading_bag_item: VBoxContainer
var _loading_tab_ammo: Button
var _loading_tab_item: Button
var _loading_confirm_btn: Button
var _loading_undo_btn: Button
var _loading_inventory_grid: HFlowContainer

# LeftColumn
var _hit_info_panel: PanelContainer
var _hit_info_label: RichTextLabel
var _lookahead_container: CylinderView
var _card_next: PanelContainer
var _card_2: PanelContainer
var _card_bundle: PanelContainer
var _agent_sprite: TextureRect

# Track
var _track_control: EnemyTrackView
var _track_line: ColorRect

# 4. ShotLog
var _shot_log_panel: PanelContainer
var _shot_log_label: RichTextLabel  # 색상 태그 표현을 위해 RichTextLabel 사용

# 5. ActionBar
var _action_row: HBoxContainer
var _unload_btn: Button
var _reload_btn: Button
var _double_tap_btn: Button
var _eject_btn: Button
var _fire_btn: Button

# ── MainFlow 외곽 오버레이 ──
var _floating_layer: Control
var _drawer_panel: BagInventoryDrawer
var _drawer_tab_ammo: Button:
	get:
		if is_instance_valid(_drawer_panel):
			return _drawer_panel._drawer_tab_ammo
		return null
var _drawer_tab_discard: Button:
	get:
		if is_instance_valid(_drawer_panel):
			return _drawer_panel._drawer_tab_discard
		return null
var _drawer_tab_exile: Button:
	get:
		if is_instance_valid(_drawer_panel):
			return _drawer_panel._drawer_tab_exile
		return null

# ── 상시 HUD 카운터 컴포넌트 ──
var _hud_lbl_draw: Label
var _hud_lbl_discard: Label
var _hud_lbl_exile: Label

# ── 결과 및 탄환 드래프트 오버레이 변수 이식 ──
var _result_overlay: PanelContainer
var _result_title: Label
var _result_message: Label
var _draft_selected: BulletData = null
var _draft_confirm_btn: Button
var _draft_container: VBoxContainer
var _draft_cards_hbox: HBoxContainer

func _exit_tree() -> void:
	if is_instance_valid(_result_overlay):
		_result_overlay.queue_free()

func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	_build_ui()
	_build_result_overlay()

func _ready() -> void:
	self.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	self.anchor_left = 0.0
	self.anchor_top = 0.0
	self.anchor_right = 1.0
	self.anchor_bottom = 1.0
	self.offset_left = 0
	self.offset_top = 0
	self.offset_right = 0
	self.offset_bottom = 0
	self.resized.connect(_on_resized)
	
	# 디버깅용 레이아웃 출력
	print("[LAYOUT_DEBUG] Viewport Size: ", get_viewport().get_visible_rect().size)
	print("[LAYOUT_DEBUG] CombatUI Anchor: (", anchor_left, ", ", anchor_top, ", ", anchor_right, ", ", anchor_bottom, ")")
	print("[LAYOUT_DEBUG] CombatUI Offset: (", offset_left, ", ", offset_top, ", ", offset_right, ", ", offset_bottom, ")")
	
	# MainFlow 디버깅
	(func():
		var mf = get_node_or_null("MainFlow")
		if mf:
			print("[LAYOUT_DEBUG] MainFlow Anchor: (", mf.anchor_left, ", ", mf.anchor_top, ", ", mf.anchor_right, ", ", mf.anchor_bottom, ")")
			print("[LAYOUT_DEBUG] MainFlow Offset: (", mf.offset_left, ", ", mf.offset_top, ", ", mf.offset_right, ", ", mf.offset_bottom, ")")
			print("[LAYOUT_DEBUG] MainFlow Size: ", mf.size)
	).call_deferred()

func _on_resized() -> void:
	if is_instance_valid(_drawer_panel):
		if _is_bag_expanded:
			_drawer_panel.position = Vector2(24, size.y - 360 - 64)
		else:
			_drawer_panel.position = Vector2(24, size.y)

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
		
	# ════ 1. MainFlow (VBoxContainer) ════
	# anchors: Full Rect 설정 (self Control의 자식이므로 프리셋 할당 가능)
	var main_flow := VBoxContainer.new()
	main_flow.name = "MainFlow"
	main_flow.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	main_flow.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	main_flow.add_theme_constant_override("separation", 12)
	add_child(main_flow)
	main_flow.anchor_left = 0.0
	main_flow.anchor_top = 0.0
	main_flow.anchor_right = 1.0
	main_flow.anchor_bottom = 1.0
	main_flow.offset_left = 0
	main_flow.offset_top = 0
	main_flow.offset_right = 0
	main_flow.offset_bottom = 0
	main_flow.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_flow.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# (1-A) TopBar 제거됨 (전투 대기 중 라벨은 Battlefield 우상단으로 오버레이 이관, 상황 대기 중 라벨은 거리 표시 밑으로 이관)
	

	
	# (1-C) Battlefield (HBoxContainer)
	_battlefield_container = HBoxContainer.new()
	_battlefield_container.name = "Battlefield"
	_battlefield_container.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	_battlefield_container.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	_battlefield_container.add_theme_constant_override("separation", 12)
	main_flow.add_child(_battlefield_container)
	
	# (1-D) LoadingContainer (VBoxContainer)
	_loading_container = VBoxContainer.new()
	_loading_container.name = "LoadingContainer"
	_loading_container.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	_loading_container.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	_loading_container.visible = false
	main_flow.add_child(_loading_container)
	
	# Topbar (페이즈 표시)
	var topbar = MarginContainer.new()
	topbar.add_theme_constant_override("margin_left", 14)
	topbar.add_theme_constant_override("margin_right", 14)
	topbar.add_theme_constant_override("margin_top", 9)
	topbar.add_theme_constant_override("margin_bottom", 9)
	var topbar_bg = ColorRect.new()
	topbar_bg.color = Color(0.2, 0.88, 0.67, 0.04) # rgba(55,224,172,.04)
	topbar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	topbar.add_child(topbar_bg)
	_loading_container.add_child(topbar)
	
	var topbar_hbox = HBoxContainer.new()
	topbar_hbox.add_theme_constant_override("separation", 12)
	topbar.add_child(topbar_hbox)
	
	var toast_lbl: Label = parent_scene.make_label("웨이브 준비 · 스택을 짜는 시간", 12, parent_scene.C_DIM)
	topbar_hbox.add_child(toast_lbl)
	
	var spacer_top = Control.new()
	spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar_hbox.add_child(spacer_top)
	
	var phase_pill: Label = parent_scene.make_label("● 적재 페이즈", 12, parent_scene.C_SUCCESS)
	topbar_hbox.add_child(phase_pill)
	
	# Refbar (전장 참고)
	var refbar = MarginContainer.new()
	refbar.add_theme_constant_override("margin_left", 16)
	refbar.add_theme_constant_override("margin_right", 16)
	refbar.add_theme_constant_override("margin_top", 8)
	refbar.add_theme_constant_override("margin_bottom", 8)
	var refbar_bg = ColorRect.new()
	refbar_bg.color = Color(0, 0, 0, 0.15)
	refbar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	refbar.add_child(refbar_bg)
	_loading_container.add_child(refbar)
	
	var refbar_hbox = HBoxContainer.new()
	refbar_hbox.add_theme_constant_override("separation", 16)
	refbar.add_child(refbar_hbox)
	
	var ref_lbl: Label = parent_scene.make_label("전장 참고", 10, parent_scene.C_DIM)
	refbar_hbox.add_child(ref_lbl)
	
	var mini_track_margin = MarginContainer.new()
	mini_track_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mini_track_margin.custom_minimum_size = Vector2(0, 20)
	refbar_hbox.add_child(mini_track_margin)
	
	var mini_track_line = ColorRect.new()
	mini_track_line.color = Color(0.13, 0.18, 0.24)
	mini_track_line.custom_minimum_size = Vector2(0, 2)
	mini_track_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mini_track_margin.add_child(mini_track_line)
	
	_loading_ref_dist = parent_scene.make_label("대기 중...", 15, Color.WHITE)
	refbar_hbox.add_child(_loading_ref_dist)
	
	# LoadMain
	var loadmain_margin = MarginContainer.new()
	loadmain_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadmain_margin.add_theme_constant_override("margin_left", 20)
	loadmain_margin.add_theme_constant_override("margin_right", 20)
	loadmain_margin.add_theme_constant_override("margin_top", 16)
	loadmain_margin.add_theme_constant_override("margin_bottom", 16)
	_loading_container.add_child(loadmain_margin)
	
	var loadmain = HBoxContainer.new()
	loadmain.add_theme_constant_override("separation", 20)
	loadmain_margin.add_child(loadmain)
	
	# StackCol (세로 스택)
	var stackcol = VBoxContainer.new()
	stackcol.custom_minimum_size = Vector2(240, 0)
	loadmain.add_child(stackcol)
	
	var stack_h = HBoxContainer.new()
	stackcol.add_child(stack_h)
	
	var stack_t: Label = parent_scene.make_label("▲ 스택 (위 = 다음 발사)", 11, parent_scene.C_DIM)
	stack_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack_h.add_child(stack_t)
	
	_loading_stack_cap = parent_scene.make_label("0/0", 15, parent_scene.C_SUCCESS)
	stack_h.add_child(_loading_stack_cap)
	
	_loading_stack_vbox = VBoxContainer.new()
	_loading_stack_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loading_stack_vbox.add_theme_constant_override("separation", 6)
	stackcol.add_child(_loading_stack_vbox)
	
	# Bag (가방 패널)
	var bag_panel = PanelContainer.new()
	bag_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var bag_style := StyleBoxFlat.new()
	bag_style.bg_color = Color(0.05, 0.07, 0.11)
	bag_style.border_width_left = 1; bag_style.border_width_right = 1
	bag_style.border_width_top = 1; bag_style.border_width_bottom = 1
	bag_style.border_color = Color(0.13, 0.18, 0.24)
	bag_style.corner_radius_top_left = 11; bag_style.corner_radius_top_right = 11
	bag_style.corner_radius_bottom_left = 11; bag_style.corner_radius_bottom_right = 11
	bag_panel.add_theme_stylebox_override("panel", bag_style)
	loadmain.add_child(bag_panel)
	
	var bag_vbox = VBoxContainer.new()
	bag_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_panel.add_child(bag_vbox)
	
	var bag_tabs = HBoxContainer.new()
	bag_tabs.add_theme_constant_override("separation", 0)
	bag_vbox.add_child(bag_tabs)
	
	_loading_tab_ammo = Button.new()
	_loading_tab_ammo.text = "탄환 · 삽탄"
	_loading_tab_ammo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loading_tab_ammo.focus_mode = Control.FOCUS_NONE
	_loading_tab_ammo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_loading_tab_ammo.pressed.connect(func(): _switch_loading_tab(true))
	bag_tabs.add_child(_loading_tab_ammo)
	
	_loading_tab_item = Button.new()
	_loading_tab_item.text = "소모품"
	_loading_tab_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loading_tab_item.focus_mode = Control.FOCUS_NONE
	_loading_tab_item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_loading_tab_item.pressed.connect(func(): _switch_loading_tab(false))
	bag_tabs.add_child(_loading_tab_item)
	
	# 초기 탭 스타일 적용
	_apply_tab_style(_loading_tab_ammo, true)
	_apply_tab_style(_loading_tab_item, false)
	
	var bag_body_margin = MarginContainer.new()
	bag_body_margin.add_theme_constant_override("margin_left", 14)
	bag_body_margin.add_theme_constant_override("margin_right", 14)
	bag_body_margin.add_theme_constant_override("margin_top", 14)
	bag_body_margin.add_theme_constant_override("margin_bottom", 14)
	bag_body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_vbox.add_child(bag_body_margin)
	
	_loading_bag_ammo = VBoxContainer.new()
	_loading_bag_ammo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loading_bag_ammo.add_theme_constant_override("separation", 10)
	bag_body_margin.add_child(_loading_bag_ammo)
	
	var bag_hint_ammo: Label = parent_scene.make_label("✓ 적재 페이즈 — 탄을 눌러 스택 맨 위에 삽탄", 12, parent_scene.C_SUCCESS)
	_loading_bag_ammo.add_child(bag_hint_ammo)
	
	# 세로 스크롤 가능한 스크롤 영역 생성
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_loading_bag_ammo.add_child(scroll)
	
	_loading_inventory_grid = HFlowContainer.new()
	_loading_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loading_inventory_grid.add_theme_constant_override("h_separation", 10)
	_loading_inventory_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_loading_inventory_grid)
	
	var bag_note: Label = parent_scene.make_label("순서를 바꾸려면 납탄으로 위에서부터 빼서 다시 삽탄", 11, parent_scene.C_DIM)
	bag_note.custom_minimum_size = Vector2(0, 20)
	_loading_bag_ammo.add_child(bag_note)
	
	_loading_bag_item = VBoxContainer.new()
	_loading_bag_item.visible = false
	_loading_bag_item.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_body_margin.add_child(_loading_bag_item)
	
	var bag_hint_item: Label = parent_scene.make_label("소모품 — 즉발 사용 (미구현)", 12, parent_scene.C_DIM)
	_loading_bag_item.add_child(bag_hint_item)
	
	# 하단 액션 버튼
	var action_margin = MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 16)
	action_margin.add_theme_constant_override("margin_right", 16)
	action_margin.add_theme_constant_override("margin_top", 12)
	action_margin.add_theme_constant_override("margin_bottom", 12)
	_loading_container.add_child(action_margin)
	
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	action_margin.add_child(actions)
	
	_loading_undo_btn = parent_scene.make_button("납탄 (맨 위 제거)", func(): _on_unload_pressed(), parent_scene.C_WARNING)
	actions.add_child(_loading_undo_btn)
	
	var spacer_act = Control.new()
	spacer_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer_act)
	
	_loading_confirm_btn = parent_scene.make_button("장전 완료 ▸", func(): _on_loading_confirm(), parent_scene.C_SUCCESS)
	actions.add_child(_loading_confirm_btn)
	
	# LeftColumn (VBoxContainer, 고정폭 180으로 슬림화하여 전투 공간 확장)
	var left_col := VBoxContainer.new()
	left_col.name = "LeftColumn"
	left_col.custom_minimum_size = Vector2(180, 0)
	left_col.size_flags_horizontal = Control.SIZE_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	left_col.add_theme_constant_override("separation", 8)
	_battlefield_container.add_child(left_col)
	

	
	# Lookahead 영역을 ScrollContainer로 감싸서 스택이 길어져도 스크롤 대응
	var lookahead_scroll := ScrollContainer.new()
	lookahead_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lookahead_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(lookahead_scroll)
	
	# piles_updated HUD 카운터 컨테이너 추가
	var hud_pile_panel := PanelContainer.new()
	var pile_style := StyleBoxFlat.new()
	pile_style.bg_color = Color(0.06, 0.08, 0.12, 0.8)
	pile_style.corner_radius_top_left = 6; pile_style.corner_radius_top_right = 6
	pile_style.corner_radius_bottom_left = 6; pile_style.corner_radius_bottom_right = 6
	pile_style.content_margin_left = 8; pile_style.content_margin_right = 8
	pile_style.content_margin_top = 4; pile_style.content_margin_bottom = 4
	hud_pile_panel.add_theme_stylebox_override("panel", pile_style)
	left_col.add_child(hud_pile_panel)

	var hud_hbox := HBoxContainer.new()
	hud_hbox.add_theme_constant_override("separation", 4)
	hud_pile_panel.add_child(hud_hbox)

	_hud_lbl_draw = parent_scene.make_label("🎒 0", 11.5, parent_scene.C_SUCCESS)
	_hud_lbl_draw.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_lbl_draw.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hud_lbl_draw.gui_input.connect(func(ev): _on_hud_counter_clicked(ev, 0))
	hud_hbox.add_child(_hud_lbl_draw)

	var hud_spacer1 := Control.new()
	hud_spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_hbox.add_child(hud_spacer1)

	_hud_lbl_discard = parent_scene.make_label("♻ 0", 11.5, parent_scene.C_WARNING)
	_hud_lbl_discard.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_lbl_discard.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hud_lbl_discard.gui_input.connect(func(ev): _on_hud_counter_clicked(ev, 1))
	hud_hbox.add_child(_hud_lbl_discard)

	var hud_spacer2 := Control.new()
	hud_spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_hbox.add_child(hud_spacer2)

	_hud_lbl_exile = parent_scene.make_label("💀 0", 11.5, Color(0.9, 0.3, 0.3))
	_hud_lbl_exile.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_lbl_exile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hud_lbl_exile.gui_input.connect(func(ev): _on_hud_counter_clicked(ev, 2))
	hud_hbox.add_child(_hud_lbl_exile)
	
	_lookahead_container = CylinderView.new()
	_lookahead_container.name = "Lookahead"
	_lookahead_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lookahead_container.add_theme_constant_override("separation", 5)
	lookahead_scroll.add_child(_lookahead_container)
	
	# Track (EnemyTrackView, size_flags: Expand)
	_track_control = EnemyTrackView.new()
	_track_control.name = "Track"
	_track_control.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	_track_control.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	_track_control.custom_minimum_size = Vector2(500, 200)
	_track_control.clip_contents = true
	_battlefield_container.add_child(_track_control)
	
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.04, 0.04, 0.06, 1.0)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track_control.add_child(bg_rect)
	
	# 수평 트랙 중심선
	_track_line = ColorRect.new()
	_track_line.color = Color(0.18, 0.22, 0.28, 0.6)
	_track_line.custom_minimum_size = Vector2(0, 4)
	_track_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track_line.anchor_top = 0.75
	_track_line.anchor_bottom = 0.75
	_track_line.offset_top = -2
	_track_line.offset_bottom = 2
	_track_line.offset_left = 0
	_track_line.offset_right = 0
	_track_control.add_child(_track_line)
	
	# DistanceContainer (CenterContainer) 생성
	_distance_container = CenterContainer.new()
	_distance_container.name = "DistanceContainer"
	_distance_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_distance_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_distance_container.offset_top = 10
	_track_control.add_child(_distance_container)

	# 교전 거리와 상황 대기 중 라벨을 수직으로 모아주는 VBoxContainer
	var dist_vbox := VBoxContainer.new()
	dist_vbox.name = "DistanceVBox"
	dist_vbox.add_theme_constant_override("separation", 2)
	_distance_container.add_child(dist_vbox)

	# 1. 거리 표시 라벨 (CenterContainer -> VBoxContainer 자식으로 탑재)
	_distance_label = parent_scene.make_label("12 m", 22, parent_scene.C_WARNING)
	_distance_label.name = "DistanceLabel"
	_distance_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
	_distance_label.add_theme_constant_override("outline_size", 4)
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dist_vbox.add_child(_distance_label)

	# 2. 상황 로그/경고 메시지 라벨 (교전 거리 바로 아래에 배치)
	_top_log_toast = parent_scene.make_label("준비 완료", 11, parent_scene.C_SUCCESS)
	_top_log_toast.name = "TopLogToast"
	_top_log_toast.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
	_top_log_toast.add_theme_constant_override("outline_size", 3)
	_top_log_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dist_vbox.add_child(_top_log_toast)

	# 3. 전투 대기 중 페이즈 라벨 (전투 영역 내 우상단 오버레이로 배치)
	_phase_label = parent_scene.make_label("전투 대기 페이즈", 12, parent_scene.C_DIM)
	_phase_label.name = "PhaseLabel"
	_phase_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
	_phase_label.add_theme_constant_override("outline_size", 3)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_track_control.add_child(_phase_label)
	
	_phase_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_phase_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_phase_label.offset_right = -12
	_phase_label.offset_top = 12
	
	# HitAnalysis (PanelContainer) — 명중분석 (전투 트랙 좌상단에 반투명 플로팅 오버레이 팝업으로 배치)
	_hit_info_panel = PanelContainer.new()
	_hit_info_panel.name = "HitAnalysis"
	_hit_info_panel.custom_minimum_size = Vector2(180, 95) # 콤팩트 가로 180, 세로 95
	_hit_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE # 마우스 통과 설정
	
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.05, 0.07, 0.11, 0.25) # 25% 반투명 다크 스킨으로 변경 (워터마크화)
	hud_style.border_width_left = 1; hud_style.border_width_right = 1
	hud_style.border_width_top = 1; hud_style.border_width_bottom = 1
	hud_style.border_color = Color(parent_scene.C_ACCENT, 0.2) # 테두리도 20% 투명도로 약화
	hud_style.corner_radius_top_left = 6; hud_style.corner_radius_top_right = 6
	hud_style.corner_radius_bottom_left = 6; hud_style.corner_radius_bottom_right = 6
	_hit_info_panel.add_theme_stylebox_override("panel", hud_style)
	_track_control.add_child(_hit_info_panel)
	
	_hit_info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hit_info_panel.offset_left = 12
	_hit_info_panel.offset_top = 12
	
	var hit_margin := MarginContainer.new()
	hit_margin.add_theme_constant_override("margin_left", 8)
	hit_margin.add_theme_constant_override("margin_right", 8)
	hit_margin.add_theme_constant_override("margin_top", 6)
	hit_margin.add_theme_constant_override("margin_bottom", 6)
	_hit_info_panel.add_child(hit_margin)
	
	var hit_vbox := VBoxContainer.new()
	hit_margin.add_child(hit_vbox)
	
	var hit_title: Label = parent_scene.make_label("◎ 격발 분석", 10.5, parent_scene.C_SUCCESS)
	hit_vbox.add_child(hit_title)
	
	_hit_info_label = RichTextLabel.new()
	_hit_info_label.bbcode_enabled = true
	_hit_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hit_info_label.add_theme_font_size_override("normal_font_size", 11) # 가독성을 위해 폰트 11pt
	_hit_info_label.text = "대기 중..."
	hit_vbox.add_child(_hit_info_label)
	
	# Character (TextureRect) — Track 내부 거리 0 지점에 정박 배치
	_agent_sprite = TextureRect.new()
	_agent_sprite.name = "Character"
	_agent_sprite.layout_mode = 1
	_agent_sprite.custom_minimum_size = Vector2(80, 80)
	_agent_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_agent_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_agent_sprite.texture = load("res://assets/sprites/agent_sheet.png")
	if _agent_sprite.texture:
		var atlas := AtlasTexture.new()
		atlas.atlas = _agent_sprite.texture
		atlas.region = Rect2(0, 0, 278, 278)
		_agent_sprite.texture = atlas
	_track_control.add_child(_agent_sprite)
	
	_agent_sprite.anchor_left = 0.0
	_agent_sprite.anchor_right = 0.0
	_agent_sprite.anchor_top = 0.75
	_agent_sprite.anchor_bottom = 0.75
	# 캐릭터가 트랙 왼쪽 경계 밖으로 나가지 않게 10px 마진을 두며 세로 중앙 정착
	_agent_sprite.offset_left = 10
	_agent_sprite.offset_right = 90
	_agent_sprite.offset_top = -40
	_agent_sprite.offset_bottom = 40
	
	# (1-D) ShotLog (PanelContainer → Label) — 사격 로그 영역 (누적 지원)
	_shot_log_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	_shot_log_panel.name = "ShotLog"
	_shot_log_panel.custom_minimum_size = Vector2(0, 80)
	_shot_log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(_shot_log_panel, Color(0.08, 0.1, 0.15, 0.8))
	main_flow.add_child(_shot_log_panel)
	
	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 12)
	log_margin.add_theme_constant_override("margin_right", 12)
	log_margin.add_theme_constant_override("margin_top", 4)
	log_margin.add_theme_constant_override("margin_bottom", 4)
	_shot_log_panel.add_child(log_margin)
	
	_shot_log_label = RichTextLabel.new()
	_shot_log_label.bbcode_enabled = true
	_shot_log_label.scroll_active = true
	_shot_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shot_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shot_log_label.add_theme_font_size_override("normal_font_size", 12)
	_shot_log_label.text = "[color=#888888]전투 기록 대기 중...[/color]"
	log_margin.add_child(_shot_log_label)
	
	# (1-E) ActionBar (HBoxContainer)
	_action_row = HBoxContainer.new()
	_action_row.name = "ActionBar"
	_action_row.add_theme_constant_override("separation", 8)
	_action_row.custom_minimum_size = Vector2(0, 44)
	_action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_flow.add_child(_action_row)
	
	_unload_btn = parent_scene.make_button("🗑 빼내기", _on_unload_pressed, parent_scene.C_WARNING)
	_unload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unload_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(_unload_btn, parent_scene.C_WARNING)
	_action_row.add_child(_unload_btn)
	
	_reload_btn = parent_scene.make_button("🔄 리로드", _on_reload_pressed, parent_scene.C_ACCENT)
	_reload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reload_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(_reload_btn, parent_scene.C_ACCENT)
	_action_row.add_child(_reload_btn)
	
	var bag_btn: Button = parent_scene.make_button("🎒 가방", _on_bag_clicked, parent_scene.C_WARNING)
	bag_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(bag_btn, parent_scene.C_WARNING)
	_action_row.add_child(bag_btn)
	
	_double_tap_btn = parent_scene.make_button("💥 더블탭 OFF", _on_double_tap_toggled, parent_scene.C_DIM)
	_double_tap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_double_tap_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(_double_tap_btn, parent_scene.C_DIM)
	_action_row.add_child(_double_tap_btn)
	
	_eject_btn = parent_scene.make_button("🎪 이젝트", _on_eject_pressed, parent_scene.C_NEON_GOLD)
	_eject_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eject_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(_eject_btn, parent_scene.C_NEON_GOLD)
	_action_row.add_child(_eject_btn)
	
	_fire_btn = parent_scene.make_button("🔫 발사", _on_fire_pressed, parent_scene.C_DANGER)
	_fire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fire_btn.add_theme_font_size_override("font_size", 13)
	_apply_button_style(_fire_btn, parent_scene.C_DANGER)
	_action_row.add_child(_fire_btn)
	
	# ════ 2. FloatingLayer (Control, Full Rect, mouse_filter: Ignore) ════
	_floating_layer = Control.new()
	_floating_layer.name = "FloatingLayer"
	_floating_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floating_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floating_layer)
	
	# ════ 3. BagDrawer (PanelContainer, anchors: Bottom Wide) ════
	_build_drawer_panel()

func _build_drawer_panel() -> void:
	_drawer_panel = BagInventoryDrawer.new()
	_drawer_panel.name = "BagDrawer"
	_floating_layer.add_child(_drawer_panel)

func _toggle_drawer(expand: bool) -> void:
	if is_instance_valid(_drawer_panel):
		_drawer_panel.toggle_drawer(expand)

func _refresh_ammo_drawer() -> void:
	if is_instance_valid(_drawer_panel):
		_drawer_panel.refresh_ammo_drawer()

func _switch_drawer_tab_idx(tab_idx: int) -> void:
	if is_instance_valid(_drawer_panel):
		_drawer_panel._switch_drawer_tab_idx(tab_idx)

func _create_drawer_item(title: String, desc: String, can_use: bool, click_callback: Callable = Callable()) -> HBoxContainer:
	var item_hbox := HBoxContainer.new()
	item_hbox.add_theme_constant_override("separation", 12)
	
	var lbl_title: Label = parent_scene.make_label(title, 13, parent_scene.C_TEXT)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_hbox.add_child(lbl_title)
	
	var lbl_desc: Label = parent_scene.make_label(desc, 12, parent_scene.C_DIM)
	item_hbox.add_child(lbl_desc)
	
	if can_use:
		var btn_lbl := "사용"
		if "탄" in title or "bullet" in title.to_lower():
			btn_lbl = "삽탄"
			
		var use_btn: Button = parent_scene.make_button(btn_lbl, func():
			if click_callback.is_valid():
				click_callback.call()
			else:
				add_combat_log("[color=#37e0ac]💊 소모품 즉발 사용: %s 효과가 격발되었습니다.[/color]" % title)
				_toggle_drawer(false)
		, parent_scene.C_SUCCESS)
		use_btn.custom_minimum_size = Vector2(60, 32)
		use_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item_hbox.add_child(use_btn)
	else:
		var use_btn: Button = parent_scene.make_button("잠금", func(): pass, parent_scene.C_DIM)
		use_btn.disabled = true
		item_hbox.add_child(use_btn)
		
	return item_hbox

func _create_inventory_card(bullet: BulletData, count: int, click_callback: Callable = Callable()) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(82, 70)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.13, 0.18, 0.24)
	style.corner_radius_top_left = 9; style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9; style.corner_radius_bottom_right = 9
	card.add_theme_stylebox_override("panel", style)
	
	# 고대비 오버레이 대형 워터마크 추가 (가장 뒤에 그려지도록 먼저 add_child)
	var icon_tex := _get_bullet_icon(bullet)
	if icon_tex:
		var bg_icon := TextureRect.new()
		bg_icon.texture = icon_tex
		bg_icon.custom_minimum_size = Vector2(32, 32) # 32px로 축소
		bg_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_icon.modulate = Color(1, 1, 1, 0.45) # 45%의 선명한 불투명도
		bg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg_icon)
		
		bg_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		bg_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		bg_icon.grow_vertical = Control.GROW_DIRECTION_BEGIN
		bg_icon.position = Vector2(82 - 32 - 6, 70 - 32 - 6) # 마진 및 우측 하단 오프셋 조정
		
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	
	var caliber_str := ""
	var type_name := "탄환"
	var parts := bullet.display_name.split(" ")
	if parts.size() >= 2:
		caliber_str = parts[0]
		type_name = parts[1]
	else:
		caliber_str = bullet.display_name
		
	# 5가지 스탯을 2개 행으로 나누어 모두 조립 (DMG/ACC 주요 스탯, PEN/KB/SL 유틸리티 스탯)
	var st_str1 := "DMG %d  ACC %d" % [bullet.damage, bullet.accuracy]
	var st_str2 := "PEN %d  KB %d  SL %d" % [bullet.penetration, bullet.knockback, bullet.slow]
	
	var cal_color = parent_scene.C_WARNING if bullet.penetration > 0 else Color.WHITE
	var cal_lbl: Label = parent_scene.make_label(caliber_str, 12, cal_color) # 12.5 -> 12
	vbox.add_child(cal_lbl)
	
	# 1행 (DMG, ACC) - 밝은 흰색
	var st_lbl1: Label = parent_scene.make_label(st_str1, 9.5, Color.WHITE)
	st_lbl1.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	st_lbl1.add_theme_constant_override("outline_size", 3)
	vbox.add_child(st_lbl1)
	
	# 2행 (PEN, KB, SL) - 차분한 딤드 회색
	var st_lbl2: Label = parent_scene.make_label(st_str2, 8.5, parent_scene.C_DIM)
	st_lbl2.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	st_lbl2.add_theme_constant_override("outline_size", 3)
	vbox.add_child(st_lbl2)
	
	var count_lbl: Label = parent_scene.make_label("%s ×%d" % [type_name, count], 9.5, parent_scene.C_DIM) # 10 -> 9.5
	count_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	count_lbl.add_theme_constant_override("outline_size", 3)
	vbox.add_child(count_lbl)
		
	if click_callback.is_valid():
		var btn := Button.new()
		var empty_style := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)
		btn.add_theme_stylebox_override("disabled", empty_style)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var tw := create_tween()
				tw.tween_property(card, "scale", Vector2(0.9, 0.9), 0.05)
				tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1)
				click_callback.call()
		)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(btn)
		
		btn.mouse_entered.connect(func():
			style.border_color = parent_scene.C_SUCCESS
			style.bg_color = Color(0.12, 0.16, 0.23)
		)
		btn.mouse_exited.connect(func():
			style.border_color = Color(0.13, 0.18, 0.24)
			style.bg_color = Color(0.08, 0.11, 0.16)
		)
		
	card.pivot_offset = card.custom_minimum_size / 2.0
	return card

func _get_bullet_icon(bullet: BulletData) -> Texture2D:
	if not bullet: return null
	if bullet.icon: return bullet.icon
	
	var r_path = bullet.resource_path.get_file().get_basename().to_lower()
	var img_path := "res://assets/textures/bullets/basic_bullet_icon.png"
	
	if "ap" in r_path or "piercing" in r_path:
		img_path = "res://assets/textures/bullets/armor_piercing_icon.png"
	elif "slug" in r_path or "heavy" in r_path:
		img_path = "res://assets/textures/bullets/knockback_slug_icon.png"
	elif "tactical" in r_path or "shot" in r_path or "strike" in r_path or "critical" in r_path or "rhythm" in r_path:
		img_path = "res://assets/textures/bullets/tactical_bullet_icon.png"
		
	if ResourceLoader.exists(img_path):
		return load(img_path) as Texture2D
	return null

func _create_consumable_card(title: String, desc: String, click_callback: Callable = Callable()) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(126, 80)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.13, 0.18, 0.24)
	style.corner_radius_top_left = 9; style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9; style.corner_radius_bottom_right = 9
	card.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 11)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	
	var name_lbl: Label = parent_scene.make_label(title, 13, Color.WHITE)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)
	
	var desc_lbl: Label = parent_scene.make_label(desc, 10.5, parent_scene.C_DIM)
	desc_lbl.custom_minimum_size = Vector2(0, 20)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)
	
	if click_callback.is_valid():
		var btn := Button.new()
		var empty_style := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)
		btn.add_theme_stylebox_override("disabled", empty_style)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var tw := create_tween()
				tw.tween_property(card, "scale", Vector2(0.9, 0.9), 0.05)
				tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1)
				click_callback.call()
		)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(btn)
		
		btn.mouse_entered.connect(func():
			style.border_color = parent_scene.C_SUCCESS
			style.bg_color = Color(0.12, 0.16, 0.23)
		)
		btn.mouse_exited.connect(func():
			style.border_color = Color(0.13, 0.18, 0.24)
			style.bg_color = Color(0.08, 0.11, 0.16)
		)
		
	card.pivot_offset = card.custom_minimum_size / 2.0
	return card

func _refresh_loading_inventory() -> void:
	if not is_instance_valid(_loading_inventory_grid): return
	for child in _loading_inventory_grid.get_children():
		child.queue_free()
		
	for bullet: BulletData in _bullet_pool:
		var count: int = _bullet_pool[bullet]
		if count <= 0: continue
		
		var card := _create_inventory_card(bullet, count, func():
			request_insert_bullet(bullet)
		)
		_loading_inventory_grid.add_child(card)
		
	if _loading_inventory_grid.get_child_count() == 0:
		var empty_lbl = parent_scene.make_label("가방이 비어있습니다.", 16, parent_scene.C_DIM)
		_loading_inventory_grid.add_child(empty_lbl)

func _switch_loading_tab(is_ammo: bool) -> void:
	_apply_tab_style(_loading_tab_ammo, is_ammo)
	_apply_tab_style(_loading_tab_item, not is_ammo)
	if is_instance_valid(_loading_bag_ammo):
		_loading_bag_ammo.visible = is_ammo
	if is_instance_valid(_loading_bag_item):
		_loading_bag_item.visible = not is_ammo

func _apply_tab_style(btn: Button, is_active: bool) -> void:
	if not is_instance_valid(btn): return
	
	var style := StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.09, 0.13, 0.18) # #18222f
		style.border_width_bottom = 2
		style.border_color = parent_scene.C_SUCCESS
	else:
		style.bg_color = Color.TRANSPARENT
		style.border_width_bottom = 1
		style.border_color = Color(0.13, 0.18, 0.24)
		
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", parent_scene.C_TEXT if is_active else parent_scene.C_DIM)
	btn.add_theme_font_size_override("font_size", 12)


func _on_drawer_undo_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.LOADING:
		_on_unload_pressed()
	else:
		add_combat_log("[color=#ff4242]⚠️ 전투 중 임의 배출은 지원되지 않습니다.[/color]")

func _on_drawer_confirm_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.LOADING:
		_on_loading_confirm()
	else:
		_toggle_drawer(false)

func _on_bag_clicked() -> void:
	_toggle_drawer(not _is_bag_expanded)

# ── 전투 로직 바인딩 및 이벤트 핸들링 (호환성) ──

func start_combat(gun: GunData, enemy_list: Array, cm: CombatManager) -> void:
	combat_manager = cm
	_current_gun_data = gun
	_current_enemy_data = enemy_list[0] if enemy_list.size() > 0 else null
	
	if is_instance_valid(_lookahead_container):
		_lookahead_container.initialize(parent_scene, cm)
	if is_instance_valid(_track_control):
		_track_control.initialize(parent_scene, cm, _distance_label, _top_log_toast)
	if is_instance_valid(_drawer_panel):
		_drawer_panel.initialize(parent_scene, run_manager, cm, self)
	
	# 각 인스턴스 정보 초기 셋팅 (인벤토리 덱 정보 동기화)
	_bullet_pool.clear()
	if run_manager and run_manager.deck:
		for b_data in run_manager.deck:
			_bullet_pool[b_data] = _bullet_pool.get(b_data, 0) + 1
	_loaded_bullets.clear()
	
	combat_manager.encounter_started.connect(_on_encounter_started)
	combat_manager.enemy_damaged.connect(_on_enemy_damaged)
	combat_manager.enemy_moved.connect(_on_enemy_moved)
	combat_manager.enemy_knocked_back.connect(_on_enemy_kb)
	combat_manager.armor_shredded.connect(_on_armor_shredded)
	combat_manager.enemy_stance_changed.connect(_on_enemy_stance_changed)
	combat_manager.magazine_updated.connect(_on_magazine_updated)
	combat_manager.encounter_won.connect(_on_encounter_won)
	combat_manager.player_died.connect(_on_player_died)
	combat_manager.bullet_unloaded.connect(func(b): run_manager.unload_bullet_to_discard(b))
	combat_manager.bullet_exiled.connect(func(b): run_manager.exile_bullet_from_deck(b))
	combat_manager.buttstroke_triggered.connect(_on_buttstroke_triggered)
	if combat_manager.has_signal("draw_pile_updated"):
		combat_manager.draw_pile_updated.connect(_on_draw_pile_updated)
	if combat_manager.has_signal("piles_updated"):
		combat_manager.piles_updated.connect(_on_piles_updated)
	combat_manager.bullet_fired.connect(_on_bullet_fired)
	if combat_manager.has_signal("all_enemies_moved"):
		combat_manager.all_enemies_moved.connect(_on_all_enemies_moved)
	if combat_manager.has_signal("loading_phase_started"):
		combat_manager.loading_phase_started.connect(_on_loading_phase_started)
	if combat_manager.has_signal("combat_log"):
		combat_manager.combat_log.connect(_on_combat_log)
	if combat_manager.has_signal("enemy_killed"):
		combat_manager.enemy_killed.connect(_on_enemy_killed)
		
	var floor_num := run_manager.current_floor if run_manager else 1
	var dist_modifier := 0
	if floor_num <= 3:
		dist_modifier = 6
	elif floor_num <= 7:
		dist_modifier = 4
	elif floor_num <= 10:
		dist_modifier = 2
	elif floor_num >= 15:
		dist_modifier = -2

	if dist_modifier > 0:
		add_combat_log("[color=#88ff88]ℹ️ 초반 보너스: 적 소환 거리가 %dm 멀어집니다.[/color]" % dist_modifier)
	elif dist_modifier < 0:
		add_combat_log("[color=#ff8888]ℹ️ 종반 패널티: 적 소환 거리가 %dm 좁혀집니다.[/color]" % abs(dist_modifier))

	var enemy_data_list: Array[EnemyData] = []
	for ed in enemy_list:
		var temp_ed: EnemyData = ed.duplicate() as EnemyData
		temp_ed.start_distance = maxi(ed.start_distance + dist_modifier, 4)
		enemy_data_list.append(temp_ed)
		
	var initial_deck: Array[BulletData] = []
	var relics: Array[String] = []
	if run_manager:
		initial_deck = run_manager.deck
		relics = run_manager.active_relics
	combat_manager.start_encounter(gun, enemy_data_list, initial_deck, relics)

func _on_encounter_started(enemy_list) -> void:
	_last_bullet_count = -1
	
	if is_instance_valid(_track_control):
		_track_control.setup_encounter(enemy_list)
		_track_control.connect_enemy_gui_input(_on_enemy_sprite_gui_input)
		
	var nearest = combat_manager.enemy
	if nearest:
		_update_hit_info(nearest)
	_update_cylinder_visuals()
	_update_action_buttons()
	_update_phase_state()

func _update_enemy_position_and_scale(target_enemy = null, animate = false) -> void:
	if is_instance_valid(_track_control):
		_track_control.update_enemy_position_and_scale()

func _update_distance_display(enemy: EnemyInstance) -> void:
	if is_instance_valid(_track_control):
		_track_control.update_distance_display(enemy)

func _update_cylinder_visuals() -> void:
	if is_instance_valid(_lookahead_container):
		_lookahead_container.update_cylinder_visuals()

func _update_hit_info(enemy: EnemyInstance) -> void:
	if not enemy or enemy.is_dead():
		_hit_info_label.text = "[color=#66788c]타겟 부재 - 사격 대기 중[/color]"
		return
		
	var next_bullet: BulletData = null
	if combat_manager and not combat_manager.magazine.is_empty():
		next_bullet = combat_manager.magazine.peek()
		
	if not next_bullet:
		_hit_info_label.text = "[color=#ff4242]약실 비어있음 - 리로드 필요[/color]"
		return
		
	var total_pen: int = next_bullet.penetration
	var b_csv: Dictionary = DataLoader.get_bullet(next_bullet.resource_path.get_file().get_basename())
	if not b_csv.is_empty():
		total_pen = b_csv.penetration
		
	if _current_gun_data:
		var g_csv: Dictionary = DataLoader.get_gun(_current_gun_data.resource_path.get_file().get_basename())
		var pen_bonus: int = _current_gun_data.passive_pen_bonus
		if not g_csv.is_empty():
			pen_bonus = g_csv.passive_pen_bonus
		total_pen += pen_bonus

	var can_pierce: bool = total_pen >= enemy.current_def
	var hit_status := "[color=#37e0ac]관통 성공 ✓[/color]" if can_pierce else "[color=#ff4242]도탄 경고 ✗ (DEF>=PEN)[/color]"
	
	_hit_info_label.text = "사격탄: %s\n예상명중: %s\n대상타겟: %s" % [
		next_bullet.display_name,
		hit_status,
		enemy.data.display_name
	]

func _update_action_buttons() -> void:
	if not combat_manager: return
	var is_tempo := combat_manager.gun and (combat_manager.gun.display_name.contains("Tempo") or combat_manager.gun.display_name.contains("속사형"))
	var is_trickster := combat_manager.gun and (combat_manager.gun.display_name.contains("Trickster") or combat_manager.gun.display_name.contains("곡예형"))
	
	_fire_btn.visible = true
	_unload_btn.visible = true
	_reload_btn.visible = true
	_double_tap_btn.visible = is_tempo
	_eject_btn.visible = is_trickster
	
	if combat_manager.state == CombatManager.State.LOADING:
		_loading_confirm_btn.disabled = _loaded_bullets.is_empty()
		_loading_undo_btn.disabled = _loaded_bullets.is_empty()
		
		# (Old Action Row items - hidden anyway, but keep logic safe)
		_fire_btn.disabled = _loaded_bullets.is_empty()
		_unload_btn.disabled = _loaded_bullets.is_empty()
		_reload_btn.disabled = true
		if _double_tap_btn.visible: _double_tap_btn.disabled = true
		if _eject_btn.visible: _eject_btn.disabled = true
		return
		
	_fire_btn.text = "🔫 발사"
	_unload_btn.text = "🗑 빼내기"
	
	if combat_manager.state != CombatManager.State.PLAYER_TURN:
		_fire_btn.disabled = true
		_unload_btn.disabled = true
		_reload_btn.disabled = true
		if _double_tap_btn.visible: _double_tap_btn.disabled = true
		if _eject_btn.visible: _eject_btn.disabled = true
		return
		
	var has_ammo := not combat_manager.magazine.is_empty()
	_fire_btn.disabled = not has_ammo
	_unload_btn.disabled = not has_ammo
	_reload_btn.disabled = false
	if _eject_btn.visible:
		var eject_used = combat_manager.get("eject_used_this_turn") if "eject_used_this_turn" in combat_manager else false
		_eject_btn.disabled = not has_ammo or eject_used
	if _double_tap_btn.visible:
		var dt_used = combat_manager.get("double_tap_used_this_turn") if "double_tap_used_this_turn" in combat_manager else false
		var dt_active = combat_manager.get("double_tap_active") if "double_tap_active" in combat_manager else false
		_double_tap_btn.disabled = not has_ammo or dt_used
		_double_tap_btn.text = "💥 더블탭 ON" if dt_active else "💥 더블탭 OFF"

func _update_phase_state() -> void:
	if not combat_manager: return
	
	_battlefield_container.visible = true
	_action_row.visible = true
	_loading_container.visible = false
	
	match combat_manager.state:
		CombatManager.State.LOADING:
			_phase_label.text = "탄창 적재 페이즈"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
			_refresh_loading_stack()
			_refresh_loading_inventory()
			_set_agent_frame(0) # 대기/장전 모션 (1번째 프레임)
		CombatManager.State.PLAYER_TURN:
			_phase_label.text = "아군 작전 페이즈"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_ACCENT)
			_set_agent_frame(2) # 조준/전투 모션 (3번째 프레임 인덱스 2로 보정)
		CombatManager.State.RELOADING:
			_phase_label.text = "탄창 리로드 중"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_WARNING)
			_set_agent_frame(0)
		CombatManager.State.WON:
			_phase_label.text = "교전 승리"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
			_set_agent_frame(0)
		CombatManager.State.LOST:
			_phase_label.text = "작전 실패"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_DANGER)
			_set_agent_frame(0)
		_:
			_phase_label.text = "전투 대기 중"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_DIM)
			_set_agent_frame(0)

func _set_agent_frame(frame_idx: int) -> void:
	if is_instance_valid(_agent_sprite) and _agent_sprite.texture is AtlasTexture:
		var atlas := _agent_sprite.texture as AtlasTexture
		atlas.region = Rect2(278 * frame_idx, 0, 278, 278)

# ── 버튼 핸들러 연동 ──

func _on_fire_pressed() -> void:
	if combat_manager:
		if combat_manager.state == CombatManager.State.LOADING:
			_on_loading_confirm()
			return
		if combat_manager.state == CombatManager.State.PLAYER_TURN:
			clear_combat_log()
			combat_manager.fire()
			_update_action_buttons()

func _on_unload_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.LOADING:
		# LOADING 페이즈 중에는 _loaded_bullets에서 마지막 탄을 뺍니다.
		if _loaded_bullets.size() > 0:
			var popped: BulletData = _loaded_bullets.pop_back()
			_bullet_pool[popped] = _bullet_pool.get(popped, 0) + 1
			
			add_combat_log("[color=#ffa500]↩️ 약실 배출: %s를 가방으로 되돌렸습니다.[/color]" % popped.display_name)
			
			_refresh_loading_stack()
			
			_update_cylinder_visuals()
			_update_action_buttons()
			
			# 서랍장이 열려있다면 즉시 가방 내용물 갱신
			if _is_bag_expanded:
				_refresh_ammo_drawer()
		else:
			add_combat_log("[color=#ff4242]⚠️ 약실이 비어 있어 빼낼 탄환이 없습니다.[/color]")
		return
		
	# PLAYER_TURN 중 빼내기 로직 활성화
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		if combat_manager.has_method("request_unload"):
			combat_manager.request_unload()
		else:
			add_combat_log("[color=#ff4242]⚠️ 전투 중 임의 배출은 지원되지 않습니다.[/color]")
		_update_action_buttons()

func _on_reload_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		combat_manager.request_reload()
		_update_action_buttons()
		_update_phase_state()

func _on_double_tap_toggled() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		if combat_manager.has_method("toggle_double_tap"):
			combat_manager.toggle_double_tap()
		_update_action_buttons()

func _on_eject_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		if combat_manager.has_method("request_eject"):
			combat_manager.request_eject()
		_update_action_buttons()

func _on_loading_confirm() -> void:
	if combat_manager:
		combat_manager.confirm_loading(_loaded_bullets)
		_loaded_bullets.clear()
		
		# Clear visual magazine slots
		if is_instance_valid(_loading_stack_vbox):
			for child in _loading_stack_vbox.get_children():
				child.queue_free()
				
		_update_cylinder_visuals()
		_update_action_buttons()
		_update_phase_state()
		
		# 장전 완료 후 가방 서랍 닫기
		_toggle_drawer(false)
		_set_agent_frame(2) # 강제로 즉각 조준 자세 전환 (상태 전이 딜레이 대응)

func _on_enemy_sprite_gui_input(event: InputEvent, clicked_enemy: EnemyInstance) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
			var next_bullet := combat_manager.magazine.peek()
			if next_bullet and next_bullet.slow > 0:
				combat_manager.slow_target_enemy = clicked_enemy
				add_combat_log("[color=#37e0ac]🎯 조준 완료: %s를 조준 지목했습니다.[/color]" % clicked_enemy.data.display_name)
				_update_hit_info(clicked_enemy)

# ── 상태 전이 헨들러 바인딩 ──

func _on_enemy_damaged(enemy_inst: EnemyInstance, damage: int, remaining_hp: int) -> void:
	add_combat_log("[color=#ff4242]💥 피격: %s가 %d의 피해를 입었습니다. (남은 HP: %d)[/color]" % [
		enemy_inst.data.display_name, damage, remaining_hp
	])
	_spawn_damage_text(enemy_inst, "-%d" % damage)
	var nearest = combat_manager.enemy
	_update_hit_info(nearest)
	_update_distance_display(nearest)

func _on_enemy_moved(enemy_inst: EnemyInstance, new_distance: int, speed_used: int) -> void:
	add_combat_log("[color=#ffa500]👣 전진: %s가 %d만큼 다가왔습니다. (현재 거리: %d)[/color]" % [
		enemy_inst.data.display_name, speed_used, new_distance
	])
	_update_enemy_position_and_scale(null, true)
	_update_distance_display(combat_manager.enemy)
	_update_phase_state()

func _on_enemy_kb(enemy_inst: EnemyInstance, new_distance: int, amount: int) -> void:
	add_combat_log("[color=#37e0ac]🛡️ 넉백: %s가 %d만큼 밀려났습니다. (현재 거리: %d)[/color]" % [
		enemy_inst.data.display_name, amount, new_distance
	])
	_update_enemy_position_and_scale(null, true)
	_update_distance_display(combat_manager.enemy)

func _on_buttstroke_triggered(enemy_inst: EnemyInstance, new_distance: int) -> void:
	add_combat_log("[color=#3df5a6]🛡️ 격퇴: 적 %s를 개머리판으로 후려쳐 2m 넉백시켰습니다! (기절 부여)[/color]" % enemy_inst.data.display_name)
	_update_enemy_position_and_scale(null, true)
	_update_distance_display(combat_manager.enemy)
	# 카메라 셰이크가 구현되어 있을 경우 호출
	if parent_scene and parent_scene.has_method("shake_camera"):
		parent_scene.shake_camera()

func _on_draw_pile_updated(draw_pile: Array[BulletData]) -> void:
	_bullet_pool.clear()
	for b_data in draw_pile:
		_bullet_pool[b_data] = _bullet_pool.get(b_data, 0) + 1
	_refresh_ammo_drawer()

func _on_piles_updated(draw_pile: Array[BulletData], discard_pile: Array[BulletData], exile_pile: Array[BulletData]) -> void:
	if is_instance_valid(_hud_lbl_draw):
		_hud_lbl_draw.text = "🎒 %d" % draw_pile.size()
	if is_instance_valid(_hud_lbl_discard):
		_hud_lbl_discard.text = "♻ %d" % discard_pile.size()
	if is_instance_valid(_hud_lbl_exile):
		_hud_lbl_exile.text = "💀 %d" % exile_pile.size()
		
	if is_instance_valid(_drawer_tab_ammo):
		_drawer_tab_ammo.text = "가방 (%d)" % draw_pile.size()
	if is_instance_valid(_drawer_tab_discard):
		_drawer_tab_discard.text = "버림 (%d)" % discard_pile.size()
	if is_instance_valid(_drawer_tab_exile):
		_drawer_tab_exile.text = "소멸 (%d)" % exile_pile.size()
		
	_bullet_pool.clear()
	for b_data in draw_pile:
		_bullet_pool[b_data] = _bullet_pool.get(b_data, 0) + 1
		
	if _is_bag_expanded:
		_refresh_ammo_drawer()

func _on_hud_counter_clicked(event: InputEvent, tab_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_drawer(true)
		_switch_drawer_tab_idx(tab_idx)

func _on_armor_shredded(enemy_inst: EnemyInstance, new_def: int, amount: int) -> void:
	add_combat_log("[color=#a878e8] 파쇄: %s의 DEF가 %d 차감되었습니다.[/color]" % [
		enemy_inst.data.display_name, amount
	])

func _on_enemy_stance_changed(enemy_inst: EnemyInstance, new_stance: Enums.EnemyStance) -> void:
	add_combat_log("🔄 태세전환: %s가 새로운 태세로 전환되었습니다." % enemy_inst.data.display_name)

func _on_magazine_updated(remaining: int = 0, capacity: int = 0) -> void:
	_update_cylinder_visuals()
	var nearest = combat_manager.enemy
	if nearest:
		_update_hit_info(nearest)
	_update_action_buttons()

func _on_bullet_fired(bullet: BulletData, hit: bool = false, damage: int = 0) -> void:
	add_combat_log("[color=#ffa500]🔫 격발: %s가 격발되었습니다.[/color]" % bullet.display_name)
	
	if not _agent_sprite:
		return
		
	var tex = _agent_sprite.texture as AtlasTexture
	if tex:
		# 사격 프레임 (4번째 프레임 인덱스 3) 할당: 278 * 3
		tex.region = Rect2(278 * 3, 0, 278, 278)
		
	# Muzzle Flip을 위한 피벗 오프셋 설정
	_agent_sprite.pivot_offset = Vector2(40, 40)
	
	# 반동으로 임시 마진 이동 및 회전
	_agent_sprite.offset_left = -10
	_agent_sprite.offset_right = 70
	_agent_sprite.rotation = -0.06
	
	# 트윈으로 원래 상태 복원
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_agent_sprite, "offset_left", 10.0, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_agent_sprite, "offset_right", 90.0, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_agent_sprite, "rotation", 0.0, 0.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): _set_agent_frame(2)) # 사격 반동 후 조준 자세 복구

func _on_enemy_killed(enemy_inst: EnemyInstance) -> void:
	add_combat_log("[color=#37e0ac]💀 처치: %s를 무력화시켰습니다![/color]" % enemy_inst.data.display_name)
	_spawn_damage_text(enemy_inst, "처치!")
	var nearest = combat_manager.enemy
	_update_hit_info(nearest)
	_update_distance_display(nearest)

func _on_encounter_won() -> void:
	_result_title.text = "전투 승리!"
	_result_title.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
	var enemy_name := "적"
	if combat_manager.enemy and combat_manager.enemy.data:
		enemy_name = combat_manager.enemy.data.display_name
	elif _current_enemy_data:
		enemy_name = _current_enemy_data.display_name
	_result_message.text = "%s 처치 완료!\n탄환 1개를 드래프트합니다." % enemy_name

	# 거리 피드백 연출 발동 (라스트 스탠드 및 퍼펙트 킬)
	if combat_manager:
		var dist = combat_manager.final_kill_distance
		if dist == 1:
			parent_scene.trigger_camera_shake(20.0, 1.2)
			_trigger_last_stand_slowmotion()
			add_combat_log("[color=#ff3333][b]🚨 LAST STAND! 🚨[/b] 죽음의 문턱에서 간신히 거리를 지켜내 생존했습니다![/color]")
		elif dist >= 4 and dist != 99:
			_trigger_perfect_kill_decal()
			add_combat_log("[color=#33ff55][b]🛡️ SECURE DISTANCE - PERFECT! 🛡️[/b] 완벽하게 통제된 거리에서 위협을 차단했습니다.[/color]")
			add_combat_log("[color=#66ffcc]🔊 *깡!- 차가운 전술 차단 금속음*[/color]")

	_draft_selected = null
	_draft_confirm_btn.disabled = true
	_draft_container.visible = true
	for child in _draft_cards_hbox.get_children():
		child.queue_free()
	for bullet in _generate_draft_choices():
		_draft_cards_hbox.add_child(_make_draft_card(bullet))

	_result_overlay.visible = true

func _on_player_died() -> void:
	_fire_btn.disabled = true
	_unload_btn.disabled = true
	_reload_btn.disabled = true

	_draft_container.visible = false
	_draft_confirm_btn.disabled = false

	_result_overlay.visible = true

	if run_manager.hp_buffer > 0:
		run_manager.hp_buffer -= 1
		_result_title.text = "비상 철수"
		_result_title.add_theme_color_override("font_color", parent_scene.C_WARNING)
		_result_message.text = "비상 장치 가동!\nHP 버퍼 1 감소 (남은 버퍼: %d)\n이전 구역으로 철수합니다." % run_manager.hp_buffer
	else:
		_result_title.text = "작전 실패"
		_result_title.add_theme_color_override("font_color", parent_scene.C_DANGER)
		_result_message.text = "에이전트가 무력화되었습니다.\n생사선을 확보하지 못해 작전이 종료됩니다."

# ── 헬퍼 메서드 ──

func add_combat_log(text: String) -> void:
	if _shot_log_label:
		if _shot_log_label.text == "[color=#888888]전투 기록 대기 중...[/color]" or _shot_log_label.text == "":
			_shot_log_label.text = text
		else:
			_shot_log_label.text += "\n" + text
		
		# 최신 로그가 바로 보여지도록 최하단 스크롤 강제 (지연 갱신 적용)
		var callable := func():
			var scroll = _shot_log_label.get_v_scroll_bar()
			if scroll:
				scroll.value = scroll.max_value
		callable.call_deferred()

func clear_combat_log() -> void:
	if _shot_log_label:
		_shot_log_label.text = ""

func _spawn_damage_text(es_inst: EnemyInstance, text: String) -> void:
	var es = _enemy_sprites.get(es_inst)
	if not is_instance_valid(es): return
	
	# FloatingLayer를 사격결과 플로팅 영역으로 사용
	var lbl: Label = parent_scene.make_label(text, 20, parent_scene.C_DANGER)
	_floating_layer.add_child(lbl)
	
	# es의 전역 포지션을 _floating_layer 로컬 포지션으로 변환하여 위치 지정
	var global_pos = es.global_position
	var local_pos = global_pos - _floating_layer.global_position
	lbl.position = local_pos + Vector2(20, -30)
	
	var tween := create_tween()
	tween.tween_property(lbl, "position", local_pos + Vector2(20, -80), 1.0)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(lbl.queue_free)

func _apply_panel_style(panel: PanelContainer, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

func _apply_button_style(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.darkened(0.3)
	btn.add_theme_stylebox_override("hover", hover)
	
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.15, 0.15, 0.18)
	disabled.border_color = Color(0.25, 0.25, 0.28)
	btn.add_theme_stylebox_override("disabled", disabled)

# 미사용 오버레이 로딩 호환 메서드 상속
func _build_loading_overlay() -> void: pass
func request_insert_bullet(bullet: BulletData) -> void:
	if not combat_manager or not _current_gun_data:
		return

	var cap := _current_gun_data.magazine_capacity
	var has_ch := _current_gun_data.has_chamber
	var max_cap := cap + (1 if has_ch else 0)

	# 1. PLAYER_TURN (인게임 플레이어 턴 도중 삽탄)
	if combat_manager.state == CombatManager.State.PLAYER_TURN:
		if combat_manager.double_tap_active:
			add_combat_log("[color=#ff6666]⚠ 더블탭이 선언된 턴에는 납탄할 수 없습니다.[/color]")
			combat_manager.combat_log.emit("⚠ 더블탭이 선언된 턴에는 납탄할 수 없습니다.")
			return
		
		# 현재 남은 탄수가 최대 용량 이상인지 확인
		if combat_manager.magazine.get_remaining() >= max_cap:
			add_combat_log("[color=#ff6666]⚠ 탄창이 가득 찼습니다.[/color]")
			combat_manager.combat_log.emit("⚠ 탄창이 가득 찼습니다.")
			return
			
		# 가방에 남은 탄환 확인
		if _bullet_pool.get(bullet, 0) <= 0:
			add_combat_log("[color=#ff6666]⚠ 가방에 남은 탄환이 없습니다.[/color]")
			combat_manager.combat_log.emit("⚠ 가방에 남은 탄환이 없습니다.")
			return
			
		_bullet_pool[bullet] -= 1
		combat_manager.request_insert_bullet(bullet)
		_animate_last_insert = true
		_refresh_ammo_drawer()
		_update_cylinder_visuals()
		_update_action_buttons()
		return

	# 2. LOADING 또는 RELOADING 페이즈 (적재 상태)
	if _loaded_bullets.size() >= max_cap:
		add_combat_log("[color=#ff6666]⚠ 탄창 용량 한계에 도달했습니다.[/color]")
		return
	if _bullet_pool.get(bullet, 0) <= 0:
		add_combat_log("[color=#ff6666]⚠ 가방에 남은 탄환이 없습니다.[/color]")
		return

	_loaded_bullets.append(bullet)
	_bullet_pool[bullet] -= 1
	_animate_last_insert = true
	_refresh_loading_stack()
	_refresh_ammo_drawer()
	_update_cylinder_visuals()
	_update_action_buttons()

func _refresh_loading_stack() -> void:
	if not is_instance_valid(_loading_stack_vbox): return
	for child in _loading_stack_vbox.get_children():
		child.queue_free()
		
	var gun = combat_manager.gun if combat_manager else null
	var max_cap: int = (gun.magazine_capacity + (1 if gun.has_chamber else 0)) if gun else 5
	var loaded: int = _loaded_bullets.size()
	
	# 탄창 크기에 맞춰 VBox의 최소 높이를 사전에 고정하여, 삽탄 애니메이션 시 UI 높이 들썩임 방지
	_loading_stack_vbox.custom_minimum_size.y = max_cap * 52 + (max_cap - 1) * 6
	
	if is_instance_valid(_loading_stack_cap):
		_loading_stack_cap.text = "%d/%d" % [loaded, max_cap]
		
	# LIFO Stack: 1. 위쪽(비어 있는) 슬롯 먼저 (메인 스택 너비: 240px 고정)
	for i in range(max_cap - loaded):
		var slot := _create_stack_slot(null, -1, 240.0)
		_loading_stack_vbox.add_child(slot)
		
	# 2. 채워진 슬롯 (loaded - 1 부터 0 까지 내려가며 생성, 맨 위가 다음 발사) (메인 스택 너비: 240px 고정)
	for i in range(loaded - 1, -1, -1):
		var pos: int = (loaded - 1) - i
		var slot := _create_stack_slot(_loaded_bullets[i], pos, 240.0)
		_loading_stack_vbox.add_child(slot)
		
		# 방금 삽탄한 경우 최상단 슬롯(pos == 0) 높이 확장 및 페이드인 애니메이션
		if _animate_last_insert and pos == 0:
			slot.custom_minimum_size.y = 0
			slot.modulate.a = 0.0
			slot.clip_contents = true
			var tween := create_tween()
			tween.tween_property(slot, "custom_minimum_size:y", 52.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(slot, "modulate:a", 1.0, 0.25)
			
	_animate_last_insert = false

func _create_stack_slot(bullet: BulletData, pos: int, width: float = 180.0) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(width, 52)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.corner_radius_top_left = 9; style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9; style.corner_radius_bottom_right = 9
	
	if bullet == null:
		style.bg_color = Color.TRANSPARENT
		style.border_color = parent_scene.C_DIM
		slot.add_theme_stylebox_override("panel", style)
		
		var lbl: Label = parent_scene.make_label("비어 있음 — 삽탄 가능", 11, parent_scene.C_DIM)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(lbl)
		return slot
		
	if pos == 0:
		style.border_color = parent_scene.C_SUCCESS
		style.shadow_color = Color(parent_scene.C_SUCCESS.r, parent_scene.C_SUCCESS.g, parent_scene.C_SUCCESS.b, 0.25)
		style.shadow_size = 3
	else:
		style.border_color = Color(0.13, 0.18, 0.24)
		
	slot.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	slot.add_child(margin)
	
	# 좌우 배치 HBox
	var slot_hbox := HBoxContainer.new()
	slot_hbox.add_theme_constant_override("separation", 10)
	margin.add_child(slot_hbox)
	
	# 좌측: 32x32 대형 컬러 총알 아이콘
	var icon_tex := _get_bullet_icon(bullet)
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot_hbox.add_child(icon_rect)
		
	# 우측: 정보 텍스트 vbox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot_hbox.add_child(vbox)
	
	# 상단 행 (메타 정보)
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(top_hbox)
	
	if pos == 0:
		var arrow: Label = parent_scene.make_label("▶", 11, parent_scene.C_SUCCESS)
		top_hbox.add_child(arrow)
		
	var role_str = ""
	if pos == 0: role_str = "다음 발사"
	elif pos == 1: role_str = "그다음"
	elif pos == _loaded_bullets.size() - 1: role_str = "바닥"
	
	var role_lbl: Label = parent_scene.make_label(role_str, 9, parent_scene.C_SUCCESS if pos == 0 else parent_scene.C_DIM)
	top_hbox.add_child(role_lbl)
	
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(top_spacer)
	
	var spec_str := ""
	if bullet.penetration > 0:
		spec_str = "PEN %d" % bullet.penetration
	elif bullet.knockback > 0:
		spec_str = "KB %d" % bullet.knockback
	elif bullet.slow > 0:
		spec_str = "SL %d" % bullet.slow
	else:
		spec_str = "DMG %d" % bullet.damage
		
	var st_lbl: Label = parent_scene.make_label(spec_str, 9.5, parent_scene.C_DIM)
	top_hbox.add_child(st_lbl)
	
	# 하단 행 (탄환 이름)
	var name_lbl: Label = parent_scene.make_label(bullet.display_name, 12.5, Color.WHITE)
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(name_lbl)
	
	return slot

# ── 결과 및 탄환 드래프트 오버레이 이식 ──

func _build_result_overlay() -> void:
	_result_overlay = parent_scene.make_fullscreen_overlay()
	parent_scene.add_child(_result_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	_result_overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	_result_title = parent_scene.make_label("", 42, parent_scene.C_SUCCESS)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_result_title)

	_result_message = parent_scene.make_label("", 20, parent_scene.C_DIM)
	_result_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_result_message)

	_draft_container = VBoxContainer.new()
	_draft_container.add_theme_constant_override("separation", 10)
	_draft_container.visible = false
	vbox.add_child(_draft_container)

	var draft_title: Label = parent_scene.make_label("탄환 카드 드래프트: 3개 중 1개의 탄환을 덱에 획득하십시오.", 18, parent_scene.C_WARNING)
	draft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_draft_container.add_child(draft_title)

	_draft_cards_hbox = HBoxContainer.new()
	_draft_cards_hbox.add_theme_constant_override("separation", 12)
	_draft_cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_draft_container.add_child(_draft_cards_hbox)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	_draft_confirm_btn = parent_scene.make_button("선택 완료", _on_result_confirmed, parent_scene.C_SUCCESS)
	_draft_confirm_btn.custom_minimum_size = Vector2(120, 40)
	_apply_button_style(_draft_confirm_btn, parent_scene.C_SUCCESS)
	btn_hbox.add_child(_draft_confirm_btn)

	_result_overlay.visible = false

func _generate_draft_choices() -> Array[BulletData]:
	var pool: Array[BulletData] = []
	var path: String = "res://resources/bullets/"
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.is_empty() and not file_name.ends_with(".import"):
				if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res") or file_name.ends_with(".res.remap"):
					var clean_name: String = file_name.replace(".remap", "")
					var res = load(path + clean_name)
					if res is BulletData:
						pool.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if pool.is_empty():
		# 폴백 안전 처리
		pool = [_bullets_basic, _bullets_ap, _bullets_kb, _bullets_heavy, _bullets_slow]
	
	var result: Array[BulletData] = []
	pool.shuffle()
	for i in range(min(3, pool.size())):
		result.append(pool[i].duplicate())
	return result

func _make_draft_card(bullet: BulletData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(130, 130)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = parent_scene.C_PANEL
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var name_lbl: Label = parent_scene.make_label(bullet.display_name, 15, parent_scene.C_TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var stats_lbl: Label = parent_scene.make_label(
		"DMG %d  ACC %d  PEN %d" % [bullet.damage, bullet.accuracy, bullet.penetration],
		13, parent_scene.C_DIM)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

	if bullet.knockback > 0 or bullet.slow > 0:
		var util_lbl: Label = parent_scene.make_label(
			"KB %d  Slow %d" % [bullet.knockback, bullet.slow], 13, parent_scene.C_DIST_SAFE)
		util_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		util_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(util_lbl)

	if bullet.effect_type != Enums.BulletEffect.NONE:
		var eff_lbl: Label = parent_scene.make_label(_bullet_effect_name(bullet.effect_type), 12, parent_scene.C_WARNING)
		eff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eff_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(eff_lbl)

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_draft_card_selected(bullet, card)
	)
	return card

func _on_draft_card_selected(bullet: BulletData, selected_card: PanelContainer) -> void:
	_draft_selected = bullet
	_draft_confirm_btn.disabled = false
	for card in _draft_cards_hbox.get_children():
		var s := StyleBoxFlat.new()
		s.corner_radius_bottom_left = 10
		s.corner_radius_bottom_right = 10
		s.corner_radius_top_left = 10
		s.corner_radius_top_right = 10
		if card == selected_card:
			s.bg_color = parent_scene.C_ACCENT.darkened(0.25)
			s.border_color = parent_scene.C_ACCENT
			s.border_width_bottom = 2
			s.border_width_top = 2
			s.border_width_left = 2
			s.border_width_right = 2
		else:
			s.bg_color = parent_scene.C_PANEL_DARK
		card.add_theme_stylebox_override("panel", s)

func _on_result_confirmed() -> void:
	if _draft_selected:
		run_manager.add_to_deck(_draft_selected)
	_draft_selected = null
	_loaded_bullets.clear()
	_bullet_pool.clear()
	_result_overlay.visible = false
	visible = false
	var is_dead := (combat_manager.state == CombatManager.State.LOST and run_manager.hp_buffer == 0)
	parent_scene.handle_combat_finished(is_dead)

func _bullet_effect_name(effect: Enums.BulletEffect) -> String:
	match effect:
		Enums.BulletEffect.ARMOR_SHRED: return "[장갑 파쇄]"
		Enums.BulletEffect.COMBO: return "[콤보 사격]"
		Enums.BulletEffect.LAST_SHOT: return "[막탄 강화]"
		Enums.BulletEffect.OPENING_SHOT: return "[선제 사격]"
	return ""

func _trigger_perfect_kill_decal() -> void:
	var decal_panel := PanelContainer.new()
	decal_panel.custom_minimum_size = Vector2(280, 45)
	decal_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	decal_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.05, 0.0, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.9, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	decal_panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	decal_panel.add_child(margin)
	
	var label = parent_scene.make_label("DIST_STAT: SECURED (PERFECT)", 11, Color(0.2, 0.9, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	
	add_child(decal_panel)
	decal_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	decal_panel.position = Vector2((size.x - 280) / 2.0, 80)
	
	var tween := create_tween()
	decal_panel.modulate.a = 0.0
	tween.tween_property(decal_panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.8)
	tween.tween_property(decal_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(decal_panel.queue_free)

func _trigger_last_stand_slowmotion() -> void:
	Engine.time_scale = 0.15
	var tween := create_tween()
	tween.tween_property(Engine, "time_scale", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_all_enemies_moved() -> void:
	_update_enemy_position_and_scale(null, true)

func _on_loading_phase_started() -> void:
	var tex = _agent_sprite.texture as AtlasTexture
	if tex:
		# 장전 페이즈 진입 시 대기(Idle) 모션 (프레임 0)
		tex.region = Rect2(0, 0, 278, 278)
	_is_bag_expanded = false
	_update_phase_state()

func _on_combat_log(msg: String) -> void:
	add_combat_log(msg)
