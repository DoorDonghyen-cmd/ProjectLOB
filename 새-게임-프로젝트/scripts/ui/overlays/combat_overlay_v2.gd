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
const RewardDraftPanel = preload("res://scripts/ui/components/reward_draft_panel.gd")

# ── 상태 ──
var _bullet_pool: Dictionary = {}
var _loaded_bullets: Array[BulletData] = []
var _enemy_sprites: Dictionary:
	get:
		if is_instance_valid(_track_control):
			return _track_control.enemy_sprites
		return {}
var _is_bag_expanded: bool = false
var _animate_last_insert: bool = false
var _last_bullet_count: int = -1
var _current_gun_data: GunData
var _current_enemy_data: EnemyData
var _slow_target_enemy: EnemyInstance = null

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
var _agent_sprite: TextureRect

# Track
var _track_control: EnemyTrackView
var _track_line: ColorRect

# 4. ShotLog
var _shot_log_panel: PanelContainer
var _shot_log_label: RichTextLabel  # 색상 태그 표현을 위해 RichTextLabel 사용

# 5. ActionBar
var _action_row: HBoxContainer

## 액션 바 반동 트윈의 기준선(컨테이너가 배치한 원래 y).
##
## ⚠️ 반동은 컨테이너가 관리하는 자식의 position을 직접 건드린다. 그래서
##    "현재 위치"를 원점으로 삼으면 **직전 반동이 끝나기 전에 다음 발이 나갈 때
##    밀린 위치가 새 원점이 되어 8px씩 영구 누적**된다.
##    (연발은 한 프레임에 5발이라 즉시 40px 밀려 버튼이 화면 밖으로 나갔다.)
##    기준선을 따로 보관하고 진행 중인 트윈을 죽여서 누적을 원천 차단한다.
var _action_row_base_y: float = NAN
var _recoil_tween: Tween

## ── 격발 연출 큐 (순차 재생) ──
##
## ⚠️ **시뮬레이션은 즉시 끝나고, 연출만 순차로 재생한다.**
##    연발은 탄창 전체가 1턴에 처리되는데(정본: docs/gdd/21_fire_mode.md §21.3),
##    결과를 한 번에 뭉쳐 보여주면 "펑" 하고 끝나 장전 순서가 전혀 읽히지 않는다.
##    그렇다고 전투 로직을 비동기로 만들면 결정론이 흔들리므로,
##    로직은 그대로 두고 `bullet_fired` 이벤트를 큐에 쌓아 간격을 두고 재생한다.
##    (GDD §21.5: "다탄 발사는 반드시 순차 연출")
const FX_STEP_INTERVAL := 0.18   ## 발 사이 간격(초). "타닥 타닥"이 느껴지는 최소치
## 탄알이 총구에서 표적까지 날아가는 시간.
## ⚠️ 너무 짧으면(≤0.08s = 5프레임 이하) 궤적이 아니라 번쩍임으로 보인다.
const TRACER_TRAVEL := 0.16

var _fire_fx_queue: Array[Dictionary] = []
var _fx_playing: bool = false
## 연출이 재생되는 동안 도착한 전투 결과(승리/패배)를 보류해 둔다.
## 연발은 버스트가 동기로 돌아 적이 죽는 순간 encounter_won이 **즉시** 발생하는데,
## 그 시점엔 총알 연출이 아직 큐에만 있다. 결과 화면을 바로 띄우면
## "발사도 안 보였는데 승리"가 된다. 연출이 끝난 뒤에 처리한다.
var _pending_result: String = ""  ## "" / "won" / "lost"
## 연출 재생 중 탄창에 표시할 잔탄 스냅샷. 비어 있으면 실제 탄창을 그대로 쓴다.
var _mag_display_override: Array[BulletData] = []

## 연출 전용 레이어.
##
## ⚠️ 이 오버레이는 **MarginContainer(컨테이너)**다. 컨테이너는 Control 자식의
##    위치·크기를 강제로 다시 잡으므로, 탄환 궤적 같은 Control을 여기에 직접 붙이면
##    **화면 전체로 늘어나 거대한 플래시가 된다.**
##    컨테이너가 레이아웃을 관리하지 않는 평범한 Control을 하나 두고 그 안에 붙인다.
var _fx_layer: Control
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
var _result_message: RichTextLabel
var _draft_selected: BulletData:
	get:
		if is_instance_valid(_draft_container):
			return _draft_container.get_selected_bullet()
		return null
	set(val):
		if is_instance_valid(_draft_container):
			if val == null:
				_draft_container.clear_selected()
var _draft_confirm_btn: Button
var _draft_container: RewardDraftPanel

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
		var overlay_w = size.x if size.x > 100 else get_viewport_rect().size.x
		var overlay_h = size.y if size.y > 100 else get_viewport_rect().size.y
		var target_x = (overlay_w - 700) / 2.0 if overlay_w > 700 else 24.0
		
		if _is_bag_expanded:
			_drawer_panel.position = Vector2(target_x, overlay_h - 390 - 48)
		else:
			_drawer_panel.position = Vector2(target_x, overlay_h)

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
	DragScroll.attach(scroll)  # 버튼 위에서도 끌어서 스크롤
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
	
	# 소모품 사용은 교전 페이즈의 가방 드로어(소모품 탭)에서 수행한다.
	var bag_hint_item: Label = parent_scene.make_label(
		"소모품은 교전 중 가방 서랍의 [소모품] 탭에서 즉발 사용합니다.", 12, parent_scene.C_DIM)
	bag_hint_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	DragScroll.attach(lookahead_scroll)  # 버튼 위에서도 끌어서 스크롤
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

	# 연출 전용 레이어 — 컨테이너 레이아웃 밖에서 자유 좌표를 쓰기 위한 껍데기.
	# 이 오버레이가 MarginContainer라 Control을 직접 붙이면 전부 화면 크기로 늘어난다.
	_fx_layer = Control.new()
	_fx_layer.name = "FXLayer"
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx_layer)

	# 컨테이너가 재배치할 때마다 반동 기준선을 다시 읽는다(창 크기 변경 대응).
	# 트윈이 도는 중에는 트윈이 position을 쥐고 있으므로 갱신하지 않는다.
	main_flow.sort_children.connect(func():
		if _recoil_tween == null or not _recoil_tween.is_valid():
			_action_row_base_y = _action_row.position.y
	)

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
	
	if not expand and combat_manager:
		combat_manager.apply_bullet_insertion_tax()

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
	card.custom_minimum_size = Vector2(120, 72)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.13, 0.18, 0.24)
	style.corner_radius_top_left = 9; style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9; style.corner_radius_bottom_right = 9
	card.add_theme_stylebox_override("panel", style)
	
	# 고대비 오버레이 대형 워터마크 추가 (Absolute Wrapper 노드를 사용해 PanelContainer의 강제 확장을 우회)
	var icon_tex := _get_bullet_icon(bullet)
	if icon_tex:
		var wrapper := Control.new()
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(wrapper)
		
		var bg_icon := TextureRect.new()
		bg_icon.texture = icon_tex
		bg_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_icon.modulate = Color(1, 1, 1, 0.45) # 45%의 선명한 불투명도
		bg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.add_child(bg_icon)
		
		bg_icon.size = Vector2(32, 32)
		bg_icon.position = Vector2(120 - 32 - 6, 72 - 32 - 6) # 마진 및 우측 하단 절대 좌표 지정
		
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
		
	# 5차 폴리싱: 타이틀과 구경/타입 병합 및 행 감축 (세로 4행 -> 3행 정돈)
	var title_hbox := HBoxContainer.new()
	title_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title_hbox)
	
	var title_text := "%s %s" % [caliber_str, type_name]
	var cal_color = parent_scene.C_WARNING if bullet.penetration > 0 else Color.WHITE
	var title_lbl: Label = parent_scene.make_label(title_text, 11.5, cal_color)
	title_lbl.clip_text = true
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_hbox.add_child(title_lbl)
	
	# 수량이 2개 이상일 때만 수량 표기 노출 (1개 이하일 때는 직관성을 위해 완전히 숨김)
	if count > 1:
		var count_lbl: Label = parent_scene.make_label("x%d" % count, 9.5, parent_scene.C_DIM)
		count_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
		count_lbl.add_theme_constant_override("outline_size", 3)
		title_hbox.add_child(count_lbl)
	
	# 1행 HBox (DMG, ACC) - 가독 한계 크기 10.5 확보 및 정식 명칭 사용
	var row1_hbox := HBoxContainer.new()
	row1_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(row1_hbox)
	
	# DMG (대미지)
	var dmg_color = Color.WHITE if bullet.damage > 0 else parent_scene.C_DIM.darkened(0.2)
	var dmg_lbl = parent_scene.make_label("DMG %d" % bullet.damage, 10.5, dmg_color)
	dmg_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	dmg_lbl.add_theme_constant_override("outline_size", 3)
	row1_hbox.add_child(dmg_lbl)
	
	# ACC (명중률)
	var acc_color = Color.WHITE if bullet.accuracy > 0 else parent_scene.C_DIM.darkened(0.2)
	var acc_lbl = parent_scene.make_label("ACC %d" % bullet.accuracy, 10.5, acc_color)
	acc_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	acc_lbl.add_theme_constant_override("outline_size", 3)
	row1_hbox.add_child(acc_lbl)
	
	# 2행 HBox (PEN, KB, SLOW) - 폰트 크기를 10.5로 통일
	var row2_hbox := HBoxContainer.new()
	row2_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(row2_hbox)
	
	# PEN (관통)
	var pen_color = Color(0.3, 0.9, 0.6) if bullet.penetration > 0 else parent_scene.C_DIM.darkened(0.4)
	var pen_lbl = parent_scene.make_label("PEN %d" % bullet.penetration, 10.5, pen_color)
	pen_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	pen_lbl.add_theme_constant_override("outline_size", 3)
	row2_hbox.add_child(pen_lbl)
	
	# KB (넉백)
	var kb_color = Color(1.0, 0.6, 0.2) if bullet.knockback > 0 else parent_scene.C_DIM.darkened(0.4)
	var kb_lbl = parent_scene.make_label("KB %d" % bullet.knockback, 10.5, kb_color)
	kb_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	kb_lbl.add_theme_constant_override("outline_size", 3)
	row2_hbox.add_child(kb_lbl)
	
	# SLOW (슬로우)
	var slow_color = Color(0.2, 0.6, 1.0) if bullet.slow > 0 else parent_scene.C_DIM.darkened(0.4)
	var slow_lbl = parent_scene.make_label("SLOW %d" % bullet.slow, 10.5, slow_color)
	slow_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	slow_lbl.add_theme_constant_override("outline_size", 3)
	row2_hbox.add_child(slow_lbl)
		
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
		
	# 정본은 RunManager.floor_distance_modifier() — 누적 등반 층수 비율 기준이다.
	# (과거 이 자리에 계층 내 층 번호 기반 하드코딩이 있어, 정점 1층에서도 초반 보너스가
	#  붙고 종반 패널티 구간은 도달조차 되지 않았다.)
	var floor_dist_modifier: int = run_manager.floor_distance_modifier() if run_manager else 0

	var route_dist_modifier := run_manager.consume_pending_combat_distance_modifier() if run_manager else 0
	var dist_modifier := floor_dist_modifier + route_dist_modifier
	if floor_dist_modifier > 0:
		add_combat_log("[color=#88ff88]ℹ️ 초반 보너스: 적 소환 거리가 %dm 멀어집니다.[/color]" % floor_dist_modifier)
	elif floor_dist_modifier < 0:
		add_combat_log("[color=#ff8888]ℹ️ 종반 패널티: 적 소환 거리가 %dm 좁혀집니다.[/color]" % abs(floor_dist_modifier))
	if route_dist_modifier < 0:
		add_combat_log("[color=#ffcc44]🕳️ 환기 압박 적용: 이번 교전의 적 시작 거리가 2m 좁혀집니다.[/color]")

	var enemy_data_list: Array[EnemyData] = []
	for ed in enemy_list:
		var temp_ed: EnemyData = ed.duplicate() as EnemyData
		temp_ed.start_distance = maxi(ed.start_distance + dist_modifier, 4)
		enemy_data_list.append(temp_ed)
		
	var initial_deck: Array[BulletData] = []
	var equipped_parts: Array[PartData] = []
	if run_manager:
		initial_deck = run_manager.deck
		equipped_parts = run_manager.equipped_parts
	combat_manager.start_encounter(gun, enemy_data_list, initial_deck, equipped_parts)

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
	_update_penetration_indicators()

func _update_enemy_position_and_scale(target_enemy = null, animate = false) -> void:
	if is_instance_valid(_track_control):
		_track_control.update_enemy_position_and_scale()

func _update_distance_display(enemy: EnemyInstance) -> void:
	if is_instance_valid(_track_control):
		_track_control.update_distance_display(enemy)

func _update_cylinder_visuals() -> void:
	if is_instance_valid(_lookahead_container):
		# 연출 재생 중에는 실제 탄창이 아니라 재생 진행도를 그린다.
		_lookahead_container.display_override = _mag_display_override
		_lookahead_container.update_cylinder_visuals()
	_update_penetration_indicators()

func _update_penetration_indicators() -> void:
	if not is_instance_valid(_track_control):
		return
		
	var next_bullet: BulletData = null
	if combat_manager and not combat_manager.magazine.is_empty():
		next_bullet = combat_manager.magazine.peek()
		
	_track_control.update_penetration_indicators(next_bullet)

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
	# ⚠️ 리소스 ID로 판정한다. 표시명 매칭은 이름이 바뀌면 조용히 어긋난다.
	var is_tempo := combat_manager.gun_is("smg")
	var is_trickster := combat_manager.gun_is("trickster")
	# 연발 총은 전량 커밋이므로 더블탭·이젝트 같은 "중간 조작"이 성립하지 않는다.
	var is_full_auto := combat_manager.is_full_auto()
	
	_fire_btn.visible = true
	_unload_btn.visible = true
	_reload_btn.visible = true
	_double_tap_btn.visible = is_tempo and not is_full_auto
	_eject_btn.visible = is_trickster and not is_full_auto
	
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
		
	# 연발은 무엇이 일어나는지 버튼에 명시한다 — 되돌릴 수 없는 선택이기 때문이다.
	_fire_btn.text = ("💥 연발 (%d발 전탄)" % combat_manager.magazine.get_remaining()) if is_full_auto else "🔫 발사"
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
			
			# 연발은 탄창 전체가 한 번에 처리되므로, 연출이 한 발씩 재생되는 동안
			# 표시할 잔탄을 미리 스냅샷해 둔다. (실제 탄창은 즉시 비어 버린다)
			if combat_manager.is_full_auto():
				_mag_display_override = combat_manager.magazine.get_loaded_bullets().duplicate()

			var next_bullet := combat_manager.magazine.peek()
			if next_bullet and next_bullet.slow > 0 and is_instance_valid(_slow_target_enemy) and not _slow_target_enemy.is_dead():
				combat_manager.fire_at_target(_slow_target_enemy)
			else:
				combat_manager.fire()
				
			_slow_target_enemy = null
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
				_slow_target_enemy = clicked_enemy
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
	_update_penetration_indicators()

func _on_enemy_stance_changed(enemy_inst: EnemyInstance, new_stance: Enums.EnemyStance) -> void:
	add_combat_log("🔄 태세전환: %s가 새로운 태세로 전환되었습니다." % enemy_inst.data.display_name)
	_update_penetration_indicators()

func _on_magazine_updated(remaining: int = 0, capacity: int = 0) -> void:
	_update_cylinder_visuals()
	var nearest = combat_manager.enemy
	if nearest:
		_update_hit_info(nearest)
	_update_action_buttons()
	_update_penetration_indicators()

## 격발 이벤트 수신 — 연출을 **큐에 쌓고** 순차 재생한다.
##
## 표적 위치는 이 시점에 스냅샷한다. 재생 시점에는 적이 이미 죽었거나
## 전진해 있어(버스트 전체가 1턴이므로) 엉뚱한 곳으로 탄이 날아간다.
func _on_bullet_fired(bullet: BulletData, hit: bool = false, damage: int = 0) -> void:
	var target_pos := Vector2.ZERO
	var target_inst: EnemyInstance = null
	if combat_manager and combat_manager.enemy:
		target_inst = combat_manager.enemy
		var es = _enemy_sprites.get(target_inst)
		if is_instance_valid(es) and es.visible:
			target_pos = es.global_position + es.size / 2.0

	_fire_fx_queue.append({
		"bullet": bullet,
		"hit": hit,
		"damage": damage,
		"target_pos": target_pos,
		"target": target_inst,
	})

	if not _fx_playing:
		_pump_fire_fx()


## 큐를 하나씩 꺼내 간격을 두고 재생한다.
func _pump_fire_fx() -> void:
	if _fx_playing:
		return
	_fx_playing = true

	# ⚠️ 재생 후 **항상 간격을 기다린 뒤** 큐를 다시 본다.
	#    대기 전에 종료를 판정하면, 버스트의 나머지 탄이 아직 도착하지 않은
	#    첫 프레임에 큐가 비어 보여서 매 발이 즉시 재생돼 버린다
	#    (버스트는 동기 루프라 5발이 같은 프레임에 들어온다).
	while not _fire_fx_queue.is_empty():
		var entry: Dictionary = _fire_fx_queue.pop_front()
		_play_fire_fx(entry)

		# 탄창 표시를 한 발씩 줄여 "장전 순서대로 나간다"를 눈에 보이게 한다.
		if not _mag_display_override.is_empty():
			_mag_display_override.pop_back()  # LIFO — 맨 위(마지막에 넣은 탄)부터 나간다
			_update_cylinder_visuals()

		if not is_inside_tree():
			break
		await get_tree().create_timer(FX_STEP_INTERVAL).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return

	_mag_display_override.clear()
	_fx_playing = false
	if is_instance_valid(self) and is_inside_tree():
		_update_cylinder_visuals()

	# 연출이 다 끝났으니 보류해 둔 전투 결과를 이제 띄운다.
	if _pending_result != "":
		var result := _pending_result
		_pending_result = ""
		if result == "won":
			_present_encounter_won()
		elif result == "lost":
			_present_player_died()


func _play_fire_fx(entry: Dictionary) -> void:
	var bullet: BulletData = entry.bullet
	var hit: bool = entry.hit
	var damage: int = entry.damage

	add_combat_log("[color=#ffa500]🔫 격발: %s가 격발되었습니다.[/color]" % bullet.display_name)

	if not _agent_sprite:
		return

	# 1. 아바타 사격 프레임 적용
	var tex = _agent_sprite.texture as AtlasTexture
	if tex:
		tex.region = Rect2(278 * 3, 0, 278, 278) # 사격 프레임 인덱스 3
		
	# 2. Muzzle Flip 및 반동 트윈
	_agent_sprite.pivot_offset = Vector2(40, 40)
	_agent_sprite.offset_left = -14
	_agent_sprite.offset_right = 66
	_agent_sprite.rotation = -0.08
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_agent_sprite, "offset_left", 10.0, 0.18)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_agent_sprite, "offset_right", 90.0, 0.18)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_agent_sprite, "rotation", 0.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): _set_agent_frame(2)) # 조준 복구
	
	# 3. 액션 바 덜컹임 반동 트윈
	# ⚠️ 기준선(_action_row_base_y)에서만 흔든다. "현재 위치"를 원점으로 삼으면
	#    연발처럼 빠르게 연속 격발할 때 밀린 값이 누적돼 버튼이 화면 밖으로 나간다.
	if _action_row:
		if is_nan(_action_row_base_y):
			_action_row_base_y = _action_row.position.y
		if _recoil_tween != null and _recoil_tween.is_valid():
			_recoil_tween.kill()
		_action_row.position.y = _action_row_base_y + 8.0
		_recoil_tween = create_tween()
		_recoil_tween.tween_property(_action_row, "position:y", _action_row_base_y, 0.16)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
			
	# 4. Muzzle Flash 파티클 생성 (총구 부근)
	var muzzle_pos = _agent_sprite.global_position + Vector2(_agent_sprite.size.x * 0.72, _agent_sprite.size.y * 0.42)
	_spawn_muzzle_flash_particles(muzzle_pos)

	# 4-B. 탄환 궤적 — 무엇이 날아갔는지 눈으로 보이게 한다.
	var tgt: Vector2 = entry.target_pos
	if tgt != Vector2.ZERO:
		_spawn_tracer(muzzle_pos, tgt, bullet, hit)

	# 5. 피격 시 Blood Spurt 파티클 및 탄환 반환 플로팅 연출
	# ⚠️ 재생 시점의 `combat_manager.enemy`가 아니라 **격발 당시 스냅샷**을 쓴다.
	#    버스트는 전체가 1턴이라 재생 중에는 이미 다른 적이 최근접이 되어 있다.
	if hit:
		if tgt != Vector2.ZERO:
			_spawn_blood_spurt_particles(tgt)
		var tgt_inst = entry.get("target")
		if damage > 0 and tgt_inst != null and is_instance_valid(tgt_inst):
			_spawn_bullet_refund_floating(tgt_inst, bullet)


## 연출 노드의 부모. 컨테이너 레이아웃 밖이어야 좌표를 자유롭게 쓸 수 있다.
func _fx_parent() -> Node:
	return _fx_layer if is_instance_valid(_fx_layer) else self


## 탄환 궤적 — 총구에서 표적까지 **날아가는 탄알**을 보여준다.
##
## ⚠️ 반드시 `_fx_layer`에 붙인다. 이 오버레이(MarginContainer)에 직접 붙이면
##    컨테이너가 크기를 화면 전체로 늘려 거대한 플래시가 된다.
## 색으로 판정을 전달한다 — 막힘/빗나감이 즉시 읽혀야 "탄 선택이 옳았나"가 전달된다.
func _spawn_tracer(from_pos: Vector2, to_pos: Vector2, bullet: BulletData, hit: bool) -> void:
	if not is_instance_valid(_fx_layer):
		return

	var col := Color(1.0, 0.85, 0.35)   # 기본: 명중
	if not hit:
		col = Color(0.6, 0.63, 0.7)     # 빗나감: 흐린 회색
	elif bullet.penetration >= 3:
		col = Color(0.55, 0.85, 1.0)    # 고관통: 청백
	elif bullet.knockback > 0:
		col = Color(1.0, 0.55, 0.25)    # 충격탄: 주황

	# 탄알 본체 — 작고 선명한 점. 크게 만들면 화면을 덮어 눈이 아프다.
	var slug := ColorRect.new()
	slug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slug.color = col
	slug.size = Vector2(7, 3)
	slug.pivot_offset = slug.size / 2.0
	slug.rotation = (to_pos - from_pos).angle()
	_fx_layer.add_child(slug)

	var start := from_pos - slug.pivot_offset
	var goal := to_pos - slug.pivot_offset
	slug.global_position = start

	# 날아가는 동안은 또렷하게 유지하고, 도착 직전에만 사라진다.
	# (이동 중에 흐려지면 "날아간다"가 아니라 "번쩍인다"로 보인다)
	var t := create_tween()
	t.tween_property(slug, "global_position", goal, TRACER_TRAVEL)\
		.set_trans(Tween.TRANS_LINEAR)
	t.tween_property(slug, "modulate:a", 0.0, 0.05)
	t.tween_callback(slug.queue_free)

## ⚠️ 연발은 한 번의 발사로 이 연출이 5번 연속 재생된다.
##    단발 기준으로 잡은 양을 그대로 두면 겹쳐 쌓여 화면이 번쩍이고 눈이 아프다.
func _spawn_muzzle_flash_particles(pos: Vector2) -> void:
	var parts := CPUParticles2D.new()
	parts.amount = 8
	parts.lifetime = 0.16
	parts.one_shot = true
	parts.explosiveness = 0.98
	parts.spread = 26.0
	parts.gravity = Vector2(0, 0)
	parts.initial_velocity_min = 90.0
	parts.initial_velocity_max = 150.0
	parts.color = Color(1.0, 0.7, 0.25, 0.85)
	parts.direction = Vector2(1, -0.15)
	parts.scale_amount_min = 1.5
	parts.scale_amount_max = 2.8
	parts.global_position = pos
	_fx_parent().add_child(parts)
	parts.emitting = true
	
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_callback(parts.queue_free)

func _spawn_blood_spurt_particles(pos: Vector2) -> void:
	var parts := CPUParticles2D.new()
	parts.amount = 12
	parts.lifetime = 0.26
	parts.one_shot = true
	parts.explosiveness = 0.92
	parts.spread = 50.0
	parts.gravity = Vector2(0, 220)
	parts.initial_velocity_min = 60.0
	parts.initial_velocity_max = 110.0
	parts.color = Color(0.2, 0.62, 0.28, 0.9) # 초록 핏방울
	parts.direction = Vector2(-0.4, -0.9)
	parts.scale_amount_min = 2.0
	parts.scale_amount_max = 3.5
	parts.global_position = pos
	_fx_parent().add_child(parts)
	parts.emitting = true
	
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_callback(parts.queue_free)

func _on_enemy_killed(enemy_inst: EnemyInstance) -> void:
	add_combat_log("[color=#37e0ac]💀 처치: %s를 무력화시켰습니다![/color]" % enemy_inst.data.display_name)
	_spawn_damage_text(enemy_inst, "처치!")
	var nearest = combat_manager.enemy
	_update_hit_info(nearest)
	_update_distance_display(nearest)

## 승리 신호 수신 — 연출이 재생 중이면 끝날 때까지 결과 화면을 미룬다.
func _on_encounter_won() -> void:
	if _fx_playing or not _fire_fx_queue.is_empty():
		_pending_result = "won"
		return
	_present_encounter_won()


func _present_encounter_won() -> void:
	_result_title.text = "전투 승리!"
	_result_title.add_theme_color_override("font_color", parent_scene.C_SUCCESS)

	# 탄약 효율성 평가 등급 산출
	var total_kills = combat_manager.battle_stats.total_kills
	var shots_fired = combat_manager.battle_stats.lead_bullets_fired
	var efficiency = 100
	if shots_fired > 0:
		efficiency = clampi(int(round((float(total_kills) / float(shots_fired)) * 100.0)), 0, 100)
		
	var grade = "B"
	var earned_credits = 20
	var grade_desc = "표준 전투 범주 내 소비율 확인."
	
	if efficiency >= 95:
		grade = "S"
		earned_credits = 50
		grade_desc = "합리적 자원 통제 확인. 기업 크레딧 배급 한도 증액 승인. 요원의 생존 가능성을 극도로 높게 평가합니다."
	elif efficiency >= 80:
		grade = "A"
		earned_credits = 35
		grade_desc = "자원 통제 수준 우수. 배급 한도가 임시 증액되었습니다. 귀하의 생존 효율은 자산 가치에 부합합니다."
	elif efficiency >= 60:
		grade = "B"
		earned_credits = 20
		grade_desc = "표준 전투 범주 내 소비율 확인. 기본 배급 절차를 실행합니다."
	elif efficiency >= 40:
		grade = "C"
		earned_credits = 10
		grade_desc = "탄약 사용 편차 누적 감지. 표준 배급량이 삭감 적용됩니다."
	else:
		grade = "D"
		earned_credits = 5
		grade_desc = "주의: 극심한 탄약 남용이 감지되었습니다. 시설 보급 한계치 임박. 탄약 절약이 강제 권고됩니다."

	var enemy_name := "적"
	if combat_manager.enemy and combat_manager.enemy.data:
		enemy_name = combat_manager.enemy.data.display_name
	elif _current_enemy_data:
		enemy_name = _current_enemy_data.display_name

	if _result_message:
		_result_message.text = "[center]%s 처치 완료!\n[color=#ffff44]탄약 효율: %d%% [%s등급][/color]\n%s[/center]" % [enemy_name, efficiency, grade, grade_desc]

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

	if is_instance_valid(_draft_container):
		_draft_container.show_draft(_draft_confirm_btn, efficiency, grade, earned_credits)

	_result_overlay.visible = true

## 패배 신호 수신 — 승리와 같은 이유로 연출이 끝난 뒤에 처리한다.
func _on_player_died() -> void:
	if _fx_playing or not _fire_fx_queue.is_empty():
		_pending_result = "lost"
		return
	_present_player_died()


func _present_player_died() -> void:
	_fire_btn.disabled = true
	_unload_btn.disabled = true
	_reload_btn.disabled = true

	_draft_container.visible = false
	_draft_confirm_btn.disabled = false
	_draft_confirm_btn.visible = true

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

func _spawn_bullet_refund_floating(es_inst: EnemyInstance, bullet: BulletData) -> void:
	var es = _enemy_sprites.get(es_inst)
	if not is_instance_valid(es): return
	
	var container := HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	_floating_layer.add_child(container)
	
	# 1. 탄환 아이콘 추가
	if bullet and bullet.icon:
		var tex_rect := TextureRect.new()
		tex_rect.texture = bullet.icon
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(24, 24)
		container.add_child(tex_rect)
		
	# 2. 반환 텍스트 레이블 (밝은 초록색)
	var text_color = parent_scene.C_SUCCESS if parent_scene else Color(0.3, 1.0, 0.5)
	var lbl = parent_scene.make_label("♻ 반환", 16, text_color) if parent_scene else Label.new()
	if not parent_scene:
		lbl.text = "♻ 반환"
		lbl.add_theme_color_override("font_color", text_color)
	container.add_child(lbl)
	
	# 3. 위치 지정
	var global_pos = es.global_position
	var local_pos = global_pos - _floating_layer.global_position
	container.position = local_pos + Vector2(es.size.x + 10, es.size.y * 0.3)
	
	# 4. 애니메이션 연출 (우상단 사선 이동 + Fade Out)
	var tween := create_tween()
	var target_pos = container.position + Vector2(30, -50)
	tween.tween_property(container, "position", target_pos, 0.8)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 0.8)
	tween.tween_callback(container.queue_free)

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
		
	# [Phase 4] 은폐성 규칙 판정: LOADING 페이즈가 아니고, 깊이가 3번째 이상(pos >= 2)이면 정보 은폐
	var is_hidden := false
	if combat_manager and combat_manager.state != CombatManager.State.LOADING:
		is_hidden = (pos >= 2)
		
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
	
	# 좌측: 32x32 대형 컬러 총알 아이콘 (은폐 시에는 렌더링 생략)
	if not is_hidden:
		var icon_tex := _get_bullet_icon(bullet)
		if icon_tex:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slot_hbox.add_child(icon_rect)
	else:
		# 은폐 시 레이아웃 정렬 유지를 위해 32x32 빈 공간 배치
		var empty_spacer := Control.new()
		empty_spacer.custom_minimum_size = Vector2(32, 32)
		slot_hbox.add_child(empty_spacer)
		
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
	elif pos == _loaded_bullets.size() - 1 and not is_hidden: role_str = "바닥"
	
	var role_lbl: Label = parent_scene.make_label(role_str, 9, parent_scene.C_SUCCESS if pos == 0 else parent_scene.C_DIM)
	top_hbox.add_child(role_lbl)
	
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(top_spacer)
	
	var spec_str := ""
	var spec_color := Color(0.3, 0.9, 0.6) # 밝은 전술 연두색
	if not is_hidden:
		var parts_list: Array[String] = []
		parts_list.append("D:%d" % bullet.damage)
		if bullet.penetration > 0:
			parts_list.append("🎯P:%d" % bullet.penetration)
		if bullet.knockback > 0:
			parts_list.append("💥K:%d" % bullet.knockback)
		if bullet.slow > 0:
			parts_list.append("❄️S:%d" % bullet.slow)
		spec_str = " ".join(parts_list)
	else:
		spec_str = "???"
		spec_color = parent_scene.C_DIM
		
	var st_lbl: Label = parent_scene.make_label(spec_str, 11.0, spec_color)
	top_hbox.add_child(st_lbl)
	
	# 하단 행 (탄환 이름)
	var display_name := bullet.display_name
	var name_color := Color.WHITE
	if is_hidden:
		display_name = "??? [정보 은폐]"
		name_color = parent_scene.C_DIM
		
	var name_lbl: Label = parent_scene.make_label(display_name, 12.5, name_color)
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

	_result_message = RichTextLabel.new()
	_result_message.bbcode_enabled = true
	_result_message.fit_content = true
	_result_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_message.add_theme_font_size_override("normal_font_size", 16)
	_result_message.add_theme_color_override("default_color", parent_scene.C_DIM)
	vbox.add_child(_result_message)

	_draft_container = RewardDraftPanel.new()
	_draft_container.name = "RewardDraftPanel"
	_draft_container.visible = false
	vbox.add_child(_draft_container)
	_draft_container.initialize(parent_scene, run_manager, self)
	_draft_container.setup_choices(_bullets_basic, _bullets_ap, _bullets_kb, _bullets_heavy, _bullets_slow)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	_draft_confirm_btn = parent_scene.make_button("선택 완료", _on_result_confirmed, parent_scene.C_SUCCESS)
	_draft_confirm_btn.custom_minimum_size = Vector2(120, 40)
	_apply_button_style(_draft_confirm_btn, parent_scene.C_SUCCESS)
	btn_hbox.add_child(_draft_confirm_btn)

	_result_overlay.visible = false



func _on_result_confirmed() -> void:
	# 드래프트 선택 처리는 reward_draft_panel 내부의 버튼들에서 처리 완료했으므로,
	# 여기서는 일반 확인(예: 사망 시 상승 종료) 처리만 수행하도록 설정합니다.
	_draft_selected = null
	if _draft_container:
		_draft_container.clear_selected()
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
