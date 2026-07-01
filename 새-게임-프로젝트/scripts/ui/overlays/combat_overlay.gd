class_name CombatOverlay
extends VBoxContainer

## ═══════════════════════════════════════════════════
## 실제 복도 전투, LIFO 장전 및 결과 알림 통합 오버레이
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager
var combat_manager: CombatManager

# ── 프리로드 리소스 ──
var _bullets_basic: BulletData = preload("res://resources/bullets/basic_bullet.tres")
var _bullets_ap: BulletData = preload("res://resources/bullets/armor_piercing.tres")
var _bullets_kb: BulletData = preload("res://resources/bullets/knockback_slug.tres")
var _bullets_heavy: BulletData = preload("res://resources/bullets/heavy_bullet.tres")
var _bullets_slow: BulletData = preload("res://resources/bullets/slow_bullet.tres")
var _death_burst_scene = preload("res://scenes/effects/death_burst.tscn")
var _bullet_trail_scene = preload("res://scenes/effects/bullet_trail.tscn")

# ── 상태 ──
var _bullet_pool: Dictionary = {}           # BulletData → 남은 수
var _loaded_bullets: Array[BulletData] = []  # 장전 중 총알 (순서대로)
var _current_enemy_data: EnemyData
var _current_gun_data: GunData
var _enemy_sprites: Dictionary = {}
var _global_max_dist: float = 12.0
var _track_overlay: Control
var _is_targeting_mode: bool = false

# ── UI 참조 ──
var _enemy_name_label: Label
var _enemy_hp_label: Label
var _enemy_hp_bar: ProgressBar
var _enemy_stats_label: Label
var _distance_label: Label
var _distance_bar: ProgressBar
var _magazine_label: Label
var _magazine_slots_label: Label
var _log_text: RichTextLabel
var _fire_btn: Button
var _unload_btn: Button
var _reload_btn: Button
var _double_tap_btn: Button
var _eject_btn: Button

# ── 3분할 및 가변 슬라이드 UI 참조 ──
var _ingame_area: Control
var _action_row: HBoxContainer
var _bottom_area: HBoxContainer
var _left_magazine_panel: VBoxContainer
var _mag_tube_container: VBoxContainer
var _btn_load_card: Button
var _btn_unload_card: Button
var _right_bag_panel: PanelContainer
var _bag_scroll: ScrollContainer
var _bag_card_container: GridContainer
var _bag_mini_summary: Label
var _is_bag_expanded: bool = false
var _enemy_sprite: TextureRect
var _agent_sprite: TextureRect
var _last_loaded_count: int = 0
var _confirm_btn: Button
var _hit_info_panel: PanelContainer
var _hit_info_label: RichTextLabel
var _enemy_info_panel: PanelContainer

# ── 서브 오버레이 ──
var _loading_overlay: PanelContainer
var _loading_pool_container: VBoxContainer
var _loading_magazine_label: Label
var _loading_confirm_btn: Button

var _result_overlay: PanelContainer
var _result_title: Label
var _result_message: Label
var _draft_selected: BulletData = null
var _draft_confirm_btn: Button
var _draft_container: VBoxContainer
var _draft_cards_hbox: HBoxContainer

func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	add_theme_constant_override("separation", 0)

	# Main horizontal split

	var main_hbox := HBoxContainer.new()

	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	main_hbox.add_theme_constant_override("separation", 12)

	add_child(main_hbox)

	# 1. Left Column (Magazine + Bag) - ~33% width

	var left_vbox := VBoxContainer.new()

	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	left_vbox.size_flags_stretch_ratio = 0.33

	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	left_vbox.add_theme_constant_override("separation", 10)

	main_hbox.add_child(left_vbox)

	# 2. Right Column (Info panels + Viewport + Buttons) - ~67% width

	var right_vbox := VBoxContainer.new()

	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	right_vbox.size_flags_stretch_ratio = 0.67

	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	right_vbox.add_theme_constant_override("separation", 10)

	main_hbox.add_child(right_vbox)

	# Build Column contents

	_build_left_column(left_vbox)

	_build_right_column(right_vbox)

	# Overlays

	_build_loading_overlay()

	_build_result_overlay()



func _build_left_column(parent: VBoxContainer) -> void:

	# Top: Magazine Panel (45% height)

	_left_magazine_panel = VBoxContainer.new()

	_left_magazine_panel.clip_contents = true

	_left_magazine_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_left_magazine_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_left_magazine_panel.size_flags_stretch_ratio = 0.45

	_left_magazine_panel.add_theme_constant_override("separation", 4)

	parent.add_child(_left_magazine_panel)

	var tube_panel := DragDropTube.new()

	tube_panel.initialize(self)

	tube_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_left_magazine_panel.add_child(tube_panel)

	var tube_margin := MarginContainer.new()

	tube_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	tube_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

	tube_margin.add_theme_constant_override("margin_left", 6)

	tube_margin.add_theme_constant_override("margin_right", 6)

	tube_margin.add_theme_constant_override("margin_top", 4)

	tube_margin.add_theme_constant_override("margin_bottom", 4)

	tube_panel.add_child(tube_margin)

	_mag_tube_container = VBoxContainer.new()

	_mag_tube_container.alignment = BoxContainer.ALIGNMENT_END

	_mag_tube_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_mag_tube_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_mag_tube_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_mag_tube_container.add_theme_constant_override("separation", -12)

	tube_margin.add_child(_mag_tube_container)

	_magazine_slots_label = parent_scene.make_label("", 12, parent_scene.C_DIM)

	_magazine_slots_label.visible = false

	_mag_tube_container.add_child(_magazine_slots_label)

	_magazine_label = parent_scene.make_label("탄창 (0/6)", 14, parent_scene.C_WARNING)

	_magazine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_left_magazine_panel.add_child(_magazine_label)

	var control_hbox := HBoxContainer.new()

	control_hbox.add_theme_constant_override("separation", 2)

	_left_magazine_panel.add_child(control_hbox)

	_btn_load_card = parent_scene.make_button("삽탄", func(): pass, parent_scene.C_SUCCESS)

	_btn_load_card.custom_minimum_size = Vector2(0, 24)

	_btn_load_card.add_theme_font_size_override("font_size", 12)

	control_hbox.add_child(_btn_load_card)

	_btn_unload_card = parent_scene.make_button("납탄", _on_loading_undo, parent_scene.C_DIM)

	_btn_unload_card.custom_minimum_size = Vector2(0, 24)

	_btn_unload_card.add_theme_font_size_override("font_size", 12)

	control_hbox.add_child(_btn_unload_card)

	_right_bag_panel = PanelContainer.new()
	_right_bag_panel.clip_contents = true
	
	var bag_style := StyleBoxFlat.new()
	bag_style.bg_color = Color(0.04, 0.04, 0.06, 0.8) # 아주 어둡고 투명한 차콜 그레이 패널
	bag_style.border_width_left = 1
	bag_style.border_width_right = 1
	bag_style.border_width_top = 1
	bag_style.border_width_bottom = 1
	bag_style.border_color = Color(0.12, 0.14, 0.18, 0.5)
	_right_bag_panel.add_theme_stylebox_override("panel", bag_style)

	_right_bag_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_right_bag_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_right_bag_panel.size_flags_stretch_ratio = 0.55

	parent.add_child(_right_bag_panel)

	_right_bag_panel.gui_input.connect(_on_bag_panel_gui_input)

	var bag_margin := MarginContainer.new()

	bag_margin.name = "BagMargin"

	bag_margin.add_theme_constant_override("margin_left", 8)

	bag_margin.add_theme_constant_override("margin_right", 8)

	bag_margin.add_theme_constant_override("margin_top", 8)

	bag_margin.add_theme_constant_override("margin_bottom", 8)

	_right_bag_panel.add_child(bag_margin)

	var bag_vbox := VBoxContainer.new()

	bag_vbox.name = "BagVBox"

	bag_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	bag_margin.add_child(bag_vbox)

	var bag_header := HBoxContainer.new()

	bag_header.name = "BagHeader"

	bag_header.custom_minimum_size = Vector2(0, 24)

	bag_header.visible = false

	bag_vbox.add_child(bag_header)

	var cancel_btn: Button = parent_scene.make_button("취소", func(): _toggle_bag_panel(false), parent_scene.C_DANGER)

	cancel_btn.custom_minimum_size = Vector2(50, 24)

	cancel_btn.add_theme_font_size_override("font_size", 11)

	_apply_tactical_button_style(cancel_btn, parent_scene.C_DANGER)

	bag_header.add_child(cancel_btn)

	var spacer := Control.new()

	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	bag_header.add_child(spacer)

	_loading_confirm_btn = parent_scene.make_button("장전 완료", _on_loading_confirm, parent_scene.C_SUCCESS)

	_loading_confirm_btn.custom_minimum_size = Vector2(70, 24)

	_loading_confirm_btn.add_theme_font_size_override("font_size", 11)

	_apply_tactical_button_style(_loading_confirm_btn, parent_scene.C_SUCCESS)

	bag_header.add_child(_loading_confirm_btn)

	_bag_mini_summary = parent_scene.make_label("가방 보기 (클릭하여 열기)
	(남은 카드: 10장)", 16, parent_scene.C_DIM)

	_bag_mini_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_bag_mini_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	bag_vbox.add_child(_bag_mini_summary)

	_bag_scroll = ScrollContainer.new()
	_bag_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_bag_scroll.visible = false
	bag_vbox.add_child(_bag_scroll)

	_bag_card_container = GridContainer.new()
	_bag_card_container.columns = 5
	_bag_card_container.add_theme_constant_override("h_separation", 8)
	_bag_card_container.add_theme_constant_override("v_separation", 8)
	_bag_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_card_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_card_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_bag_scroll.add_child(_bag_card_container)


func _build_right_column(parent: VBoxContainer) -> void:

	# 1. Top HBox (Hit Info + Enemy Info)

	var top_hbox := HBoxContainer.new()

	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	top_hbox.custom_minimum_size = Vector2(0, 110)

	top_hbox.add_theme_constant_override("separation", 10)

	parent.add_child(top_hbox)

	# 1a. Left Side: Hit Info Panel

	_hit_info_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)

	_hit_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_apply_tactical_panel_style(_hit_info_panel, parent_scene.C_ACCENT)

	top_hbox.add_child(_hit_info_panel)

	var hit_margin := MarginContainer.new()

	hit_margin.add_theme_constant_override("margin_left", 12)

	hit_margin.add_theme_constant_override("margin_right", 12)

	hit_margin.add_theme_constant_override("margin_top", 8)

	hit_margin.add_theme_constant_override("margin_bottom", 8)

	_hit_info_panel.add_child(hit_margin)

	var hit_vbox := VBoxContainer.new()

	hit_vbox.add_theme_constant_override("separation", 4)

	hit_margin.add_child(hit_vbox)

	var hit_title: Label = parent_scene.make_label("🎯 다음 격발 명중 분석", 16, parent_scene.C_WARNING)

	hit_vbox.add_child(hit_title)

	_hit_info_label = RichTextLabel.new()

	_hit_info_label.bbcode_enabled = true

	_hit_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hit_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_hit_info_label.add_theme_font_size_override("normal_font_size", 13)

	_hit_info_label.text = "대기 중..."

	hit_vbox.add_child(_hit_info_label)

	# 1b. Right Side: Enemy Info Panel

	_enemy_info_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)

	_enemy_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_apply_tactical_panel_style(_enemy_info_panel, parent_scene.C_DANGER)

	top_hbox.add_child(_enemy_info_panel)

	var enemy_margin := MarginContainer.new()

	enemy_margin.add_theme_constant_override("margin_left", 12)

	enemy_margin.add_theme_constant_override("margin_right", 12)

	enemy_margin.add_theme_constant_override("margin_top", 8)

	enemy_margin.add_theme_constant_override("margin_bottom", 8)

	_enemy_info_panel.add_child(enemy_margin)

	var enemy_vbox := VBoxContainer.new()

	enemy_vbox.add_theme_constant_override("separation", 4)

	enemy_margin.add_child(enemy_vbox)

	_enemy_name_label = parent_scene.make_label("?", 20, parent_scene.C_ACCENT)

	enemy_vbox.add_child(_enemy_name_label)

	var hp_hbox := HBoxContainer.new()

	hp_hbox.add_theme_constant_override("separation", 8)

	enemy_vbox.add_child(hp_hbox)

	var hp_title: Label = parent_scene.make_label("HP", 15, parent_scene.C_DIM)

	hp_hbox.add_child(hp_title)

	_enemy_hp_bar = ProgressBar.new()

	_enemy_hp_bar.custom_minimum_size = Vector2(0, 16)

	_enemy_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_enemy_hp_bar.show_percentage = false

	var hp_style := StyleBoxFlat.new()

	hp_style.bg_color = Color(0.2, 0.2, 0.25)

	hp_style.corner_radius_bottom_left = 3

	hp_style.corner_radius_bottom_right = 3

	hp_style.corner_radius_top_left = 3

	hp_style.corner_radius_top_right = 3

	_enemy_hp_bar.add_theme_stylebox_override("background", hp_style)

	var hp_fill := StyleBoxFlat.new()

	hp_fill.bg_color = parent_scene.C_HP_BAR

	hp_fill.corner_radius_bottom_left = 3

	hp_fill.corner_radius_bottom_right = 3

	hp_fill.corner_radius_top_left = 3

	hp_fill.corner_radius_top_right = 3

	_enemy_hp_bar.add_theme_stylebox_override("fill", hp_fill)

	hp_hbox.add_child(_enemy_hp_bar)

	_enemy_hp_label = parent_scene.make_label("0/0", 15, parent_scene.C_TEXT)

	hp_hbox.add_child(_enemy_hp_label)

	_enemy_stats_label = parent_scene.make_label("DEF 0 | PRES 0 | EVA 0 | SPD 0", 13, parent_scene.C_DIM)

	enemy_vbox.add_child(_enemy_stats_label)

	# 2. Middle: Ingame Area (Combat Viewport)

	_ingame_area = Control.new()

	_ingame_area.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_ingame_area.custom_minimum_size = Vector2(0, 180)

	_ingame_area.clip_contents = true # 비율 보정 시 화면 밖으로 탈출하는 배경 텍스처 클리핑

	parent.add_child(_ingame_area)

	var bg := TextureRect.new()

	bg.texture = load("res://assets/sprites/laboratory_corridor_bg.webp") as Texture2D

	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED # 종횡비 왜곡 방지 및 비율 커버 채우기

	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	_ingame_area.add_child(bg)

	# 배경 이미지 위에 눈금선과 마커를 그리기 위해 투명한 그리기 전용 오버레이 추가

	_track_overlay = Control.new()

	_track_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	_track_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_ingame_area.add_child(_track_overlay)

	_distance_label = parent_scene.make_label("거리: 10", 20, parent_scene.C_DIST_SAFE)

	_distance_label.set_anchors_preset(Control.PRESET_TOP_WIDE)

	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_distance_label.position.y = 12

	_ingame_area.add_child(_distance_label)

	_distance_bar = ProgressBar.new()

	_distance_bar.visible = false

	_ingame_area.add_child(_distance_bar)

	_enemy_sprite = TextureRect.new()

	_enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	_enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_enemy_sprite.custom_minimum_size = Vector2(140, 140)

	_enemy_sprite.pivot_offset = Vector2(70, 70)

	_ingame_area.add_child(_enemy_sprite)

	_agent_sprite = TextureRect.new()

	var _agent_atlas := AtlasTexture.new()
	_agent_atlas.atlas = load("res://assets/sprites/agent_sheet.png") as Texture2D
	_agent_atlas.region = Rect2(0, 0, 278, 278)
	_agent_sprite.texture = _agent_atlas

	_agent_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	_agent_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_agent_sprite.custom_minimum_size = Vector2(140, 140)

	_agent_sprite.pivot_offset = Vector2(70, 70)

	_ingame_area.add_child(_agent_sprite)

	_track_overlay.draw.connect(_on_ingame_area_draw)

	_ingame_area.resized.connect(_on_ingame_area_resized)

	# 2.5 Lower-Middle: Combat Log Panel (Added directly as a sibling to parent VBox)

	var log_panel: PanelContainer = parent_scene.make_panel(parent_scene.C_PANEL_DARK)

	log_panel.custom_minimum_size = Vector2(0, 80)

	_apply_tactical_panel_style(log_panel, Color(0.4, 0.45, 0.55))

	parent.add_child(log_panel)

	var log_margin := MarginContainer.new()

	log_margin.add_theme_constant_override("margin_left", 8)

	log_margin.add_theme_constant_override("margin_right", 8)

	log_margin.add_theme_constant_override("margin_top", 4)

	log_margin.add_theme_constant_override("margin_bottom", 4)

	log_panel.add_child(log_margin)

	_log_text = RichTextLabel.new()

	_log_text.bbcode_enabled = true

	_log_text.scroll_following = true

	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_log_text.add_theme_font_size_override("normal_font_size", 14)

	_log_text.add_theme_color_override("default_color", parent_scene.C_DIM)

	log_margin.add_child(_log_text)

	# 3. Bottom: Action Button Row

	_action_row = HBoxContainer.new()

	_action_row.add_theme_constant_override("separation", 8)

	_action_row.custom_minimum_size = Vector2(0, 56)

	parent.add_child(_action_row)

	_unload_btn = parent_scene.make_button("🗑 빼내기", _on_unload_pressed, parent_scene.C_DANGER)

	_unload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_apply_tactical_button_style(_unload_btn, parent_scene.C_WARNING)

	_action_row.add_child(_unload_btn)

	_reload_btn = parent_scene.make_button("🔄 리로드", _on_reload_pressed, parent_scene.C_WARNING)

	_reload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_apply_tactical_button_style(_reload_btn, parent_scene.C_ACCENT)

	_action_row.add_child(_reload_btn)

	_confirm_btn = parent_scene.make_button("✅ 장전완료", _on_loading_confirm, parent_scene.C_SUCCESS)

	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_confirm_btn.visible = false

	_apply_tactical_button_style(_confirm_btn, parent_scene.C_SUCCESS)

	_action_row.add_child(_confirm_btn)

	_double_tap_btn = parent_scene.make_button("💥 더블탭 OFF", _on_double_tap_toggled, parent_scene.C_DIM)

	_double_tap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_double_tap_btn.visible = false

	_apply_tactical_button_style(_double_tap_btn, parent_scene.C_DIM)

	_action_row.add_child(_double_tap_btn)

	_eject_btn = parent_scene.make_button("🎪 이젝트", _on_eject_pressed, parent_scene.C_ACCENT)

	_eject_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_eject_btn.visible = false

	_apply_tactical_button_style(_eject_btn, parent_scene.C_NEON_GOLD)

	_action_row.add_child(_eject_btn)

	_fire_btn = parent_scene.make_button("🔫 발사", _on_fire_pressed, parent_scene.C_ACCENT)

	_fire_btn.icon = load("res://assets/sprites/btn_fire_accent.png") as Texture2D

	_fire_btn.expand_icon = true

	_fire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_apply_tactical_button_style(_fire_btn, parent_scene.C_DANGER)

	_action_row.add_child(_fire_btn)


func _build_loading_overlay() -> void:

	_loading_overlay = parent_scene.make_fullscreen_overlay()

	parent_scene.add_child(_loading_overlay)

	_loading_overlay.visible = false


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

	_apply_tactical_button_style(_draft_confirm_btn, parent_scene.C_SUCCESS)

	btn_hbox.add_child(_draft_confirm_btn)

	_result_overlay.visible = false


func start_combat(gun_data: GunData, enemy_datas: Array[EnemyData], cm: CombatManager) -> void:
	visible = true
	combat_manager = cm
	_current_gun_data = gun_data
	_current_enemy_data = enemy_datas[0] if enemy_datas.size() > 0 else null
	
	# 시그널 연동
	_connect_signals()
	
	# 전투 로그 초기화 및 안내
	add_combat_log("[color=#5588aa]전투 및 시뮬레이션 페이즈 진입[/color]")
	
	# 각 인스턴스 정보 초기 셋팅 (원본 데이터 유지)
	_bullet_pool.clear()
	for b_data in run_manager.deck:
		_bullet_pool[b_data] = _bullet_pool.get(b_data, 0) + 1
		
	_loaded_bullets.clear()
	
	# 시뮬레이터 시작
	var enemy_data_list: Array[EnemyData] = []
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

	for ed in enemy_datas:
		var temp_ed := ed.duplicate()
		temp_ed.start_distance = maxi(ed.start_distance + dist_modifier, 4)
		enemy_data_list.append(temp_ed)
	combat_manager.start_encounter(gun_data, enemy_data_list, run_manager.active_relics)

func _connect_signals() -> void:
	combat_manager.encounter_started.connect(_on_encounter_started)
	if combat_manager.has_signal("enemy_killed"):
		combat_manager.enemy_killed.connect(_on_enemy_killed)
	if combat_manager.has_signal("all_enemies_moved"):
		combat_manager.all_enemies_moved.connect(_on_all_enemies_moved)
	combat_manager.loading_phase_started.connect(_on_loading_phase_started)
	combat_manager.combat_log.connect(_on_combat_log)
	combat_manager.enemy_damaged.connect(_on_enemy_damaged)
	combat_manager.enemy_moved.connect(_on_enemy_moved)
	combat_manager.enemy_knocked_back.connect(_on_enemy_kb)
	combat_manager.armor_shredded.connect(_on_armor_shredded)
	combat_manager.enemy_stance_changed.connect(_on_enemy_stance_changed)
	combat_manager.magazine_updated.connect(_on_magazine_updated)
	combat_manager.encounter_won.connect(_on_encounter_won)
	combat_manager.player_died.connect(_on_player_died)
	combat_manager.bullet_unloaded.connect(func(b): run_manager.unload_bullet_to_discard(b))
	combat_manager.bullet_fired.connect(_on_bullet_fired)


func _on_encounter_started(enemy_list) -> void:
	if _agent_sprite:
		_agent_sprite.visible = true # 요원 표시
		
	# Clear previous sprites
	for key in _enemy_sprites.keys():
		var es = _enemy_sprites[key]
		if is_instance_valid(es):
			es.queue_free()
	_enemy_sprites.clear()
	
	for enemy in enemy_list:
		var es := TextureRect.new()
		
		# 스프라이트 할당 시트 로직 
		if enemy.data and enemy.data.sprite_sheet:
			es.texture = enemy.data.sprite_sheet
		else:
			es.texture = load("res://assets/sprites/zombie_sheet.png")
			
		var z_tex := AtlasTexture.new()
		z_tex.atlas = es.texture
		
		# 좀비 프레임 1024x1024, 폭동 진압병 프레임 380x380 (대충 분기)
		if es.texture.resource_path.get_file() == "zombie_sheet.png":
			z_tex.region = Rect2(0, 0, 1024, 1024)
		else:
			z_tex.region = Rect2(0, 0, 380, 380) # 폭동 진압병 프레임
		es.texture = z_tex
		
		es.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		es.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		es.custom_minimum_size = Vector2(140, 140)
		es.pivot_offset = Vector2(70, 70)
		
		# 조준 선택 클릭을 위해 마우스 필터 켜고 신호 연결
		es.mouse_filter = Control.MOUSE_FILTER_STOP
		es.gui_input.connect(func(event): _on_enemy_sprite_gui_input(event, enemy))
		
		_ingame_area.add_child(es)
		_enemy_sprites[enemy] = es
		
	# 공유 트랙의 최대 거리를 소환된 적들 중 가장 먼 거리로 설정
	_global_max_dist = 12.0
	var max_found := 0
	for e in enemy_list:
		if e.start_distance > max_found:
			max_found = e.start_distance
	if max_found > 0:
		_global_max_dist = float(max_found)

	var nearest = combat_manager.enemy
	if nearest:
		_update_enemy_display(nearest)
		_update_distance_display(nearest)
		_update_hit_info(nearest)
	else:
		_update_enemy_position_and_scale(null, false)
	_update_cylinder_visuals()


func _on_loading_phase_started() -> void:
	var tex = _agent_sprite.texture as AtlasTexture
	if tex:
		# 장전 페이즈 진입 시 대기(Idle) 모션 (프레임 0)
		tex.region = Rect2(0, 0, 278, 278)
		
	_is_bag_expanded = false
	_start_loading_phase()


func _start_loading_phase() -> void:
	_result_overlay.visible = false
	_toggle_bag_panel(true)

	_bullet_pool.clear()
	for b_data in run_manager.deck:
		_bullet_pool[b_data] = _bullet_pool.get(b_data, 0) + 1
		
	_loaded_bullets.clear()
	_refresh_loading_ui()


func _refresh_loading_ui() -> void:
	# 1. 가방 카드 목록 갱신 (개별 탄환 슬롯 형태로 펼쳐서 나열)
	for child in _bag_card_container.get_children():
		child.queue_free()

	for bullet: BulletData in _bullet_pool:
		var count: int = _bullet_pool[bullet]
		for c in range(count):
			var card := DragCard.new()
			card.initialize(bullet, self, 1)
			_bag_card_container.add_child(card)

	# 2. 실시간 탄창 LIFO 튜브 노드 갱신 (애니메이션 지원 통합 버전)
	_update_cylinder_visuals()

	var cap := _current_gun_data.magazine_capacity
	var has_ch := _current_gun_data.has_chamber
	var max_cap := cap + (1 if has_ch else 0)

	_magazine_label.text = "탄창 (%d/%d)" % [_last_loaded_count, max_cap]
	_bag_mini_summary.text = "가방 보기 (클릭하여 열기)\n(남은 카드: %d장)" % run_manager.deck.size()
	
	if _loading_confirm_btn:
		_loading_confirm_btn.disabled = _loaded_bullets.is_empty()


func _on_loading_add_bullet(bullet: BulletData) -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		if combat_manager.double_tap_active:
			combat_manager.combat_log.emit("⚠ 더블탭이 선언된 턴에는 납탄할 수 없습니다.")
			return
		var cap := _current_gun_data.magazine_capacity
		var has_ch := _current_gun_data.has_chamber
		var max_cap := cap + (1 if has_ch else 0)
		if combat_manager.magazine.get_remaining() >= max_cap:
			combat_manager.combat_log.emit("⚠ 탄창이 가득 찼습니다.")
			return
		if _bullet_pool.get(bullet, 0) <= 0:
			combat_manager.combat_log.emit("⚠ 가방에 남은 탄환이 없습니다.")
			return
		
		_bullet_pool[bullet] -= 1
		combat_manager.request_insert_bullet(bullet)
		_toggle_bag_panel(false)
		_refresh_loading_ui()
		return

	var cap := _current_gun_data.magazine_capacity
	var has_ch := _current_gun_data.has_chamber
	var max_cap := cap + (1 if has_ch else 0)
	if _loaded_bullets.size() >= max_cap:
		return
	if _bullet_pool.get(bullet, 0) <= 0:
		return

	_loaded_bullets.append(bullet)
	_bullet_pool[bullet] -= 1
	_refresh_loading_ui()


func _on_loading_undo() -> void:
	if _loaded_bullets.is_empty():
		return
	var removed: BulletData = _loaded_bullets.pop_back()
	_bullet_pool[removed] = _bullet_pool.get(removed, 0) + 1
	_refresh_loading_ui()


func _on_loading_confirm() -> void:
	if _loaded_bullets.is_empty():
		return
		
	var tex = _agent_sprite.texture as AtlasTexture
	if tex:
		# 장전 완료 시 조준(Aiming) 모션 (프레임 2)
		tex.region = Rect2(278 * 2, 0, 278, 278)
		
	_toggle_bag_panel(false) # 장전 완료 후 가방 닫기
	combat_manager.confirm_loading(_loaded_bullets.duplicate())
	_update_action_buttons()


func clear_combat_log() -> void:
	if _log_text:
		_log_text.clear()


func add_combat_log(msg: String) -> void:
	if _log_text:
		_log_text.append_text(msg + "\n")


func _on_combat_log(msg: String) -> void:
	add_combat_log(msg)


# 대미지/도탄/빗나감 플로팅 텍스트 소환
func _spawn_damage_floating_text(es: Control, damage_or_miss: int) -> void:
	if not es or not is_instance_valid(es):
		return
		
	var label := Label.new()
	if damage_or_miss == -1:
		label.text = "빗나감!"
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	elif damage_or_miss == 0:
		label.text = "도탄!"
		label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	else:
		label.text = "-%d" % damage_or_miss
		label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		
	label.add_theme_font_size_override("font_size", 24 if damage_or_miss >= 0 else 22)
	
	# 아웃라인으로 가독성 확보
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# 적 스프라이트 상단 중앙 쯤에 소환
	var spawn_pos := es.position + Vector2(es.size.x / 2.0 - 30.0, -40.0)
	label.position = spawn_pos
	
	_ingame_area.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", spawn_pos.y - 60.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
		
	tween.chain().tween_callback(label.queue_free)


func _on_enemy_damaged(enemy_inst: EnemyInstance, damage: int, remaining_hp: int) -> void:
	_enemy_hp_bar.value = remaining_hp
	_enemy_hp_label.text = "%d/%d" % [remaining_hp, enemy_inst.data.max_hp]

	# Juice: 피격된 적 스프라이트를 식별하여 개별 피격 셰이크 및 붉은색 플래시 연출 적용
	var es = _enemy_sprites.get(enemy_inst)
	if es and is_instance_valid(es):
		_spawn_damage_floating_text(es, damage)
		_spawn_hit_particles(es)
		var orig_pos: Vector2 = es.position
		es.position.x += 15.0  # 뒤로 밀림
		es.rotation = 0.12
		es.modulate = Color(2.5, 0.4, 0.4, 1.0) # 오버브라이트 레드 플래시

		var shake_tween: Tween = create_tween()
		shake_tween.set_parallel(true)
		shake_tween.tween_property(es, "position", orig_pos, 0.25)\
			.set_trans(Tween.TRANS_ELASTIC)\
			.set_ease(Tween.EASE_OUT)
		shake_tween.tween_property(es, "rotation", 0.0, 0.2)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
			
		var target_color := Color.WHITE if enemy_inst == combat_manager.enemy else Color(0.6, 0.6, 0.7, 0.85)
		shake_tween.tween_property(es, "modulate", target_color, 0.25)

func _on_enemy_moved(enemy_inst: EnemyInstance, new_distance: int, speed_used: int) -> void:
	var nearest = combat_manager.enemy
	if nearest:
		_update_distance_display(nearest)
		_update_enemy_stats_display(nearest)


func _on_enemy_kb(enemy_inst: EnemyInstance, new_distance: int, amount: int) -> void:
	var nearest = combat_manager.enemy
	if nearest:
		_update_distance_display(nearest)


func _on_armor_shredded(enemy_inst: EnemyInstance, new_def: int, amount: int) -> void:
	var nearest = combat_manager.enemy
	if nearest:
		_update_enemy_stats_display(nearest)


func _on_magazine_updated(remaining: int, capacity: int) -> void:
	_magazine_label.text = "탄창 (%d/%d)" % [remaining, capacity]
	if remaining == 0:
		_magazine_slots_label.text = "[ 비어있음 ]"
	else:
		var bullets := combat_manager.magazine.get_loaded_bullets()
		var names: PackedStringArray = []
		for b in bullets:
			names.append(b.display_name)
		_magazine_slots_label.text = " → ".join(names)

	_update_cylinder_visuals()
	if combat_manager and combat_manager.enemy:
		_update_hit_info(combat_manager.enemy)
	_update_action_buttons()


func _on_encounter_won() -> void:
	_result_title.text = "전투 승리!"
	_result_title.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
	var enemy_name := "적"
	if combat_manager.enemy and combat_manager.enemy.data:
		enemy_name = combat_manager.enemy.data.display_name
	elif _current_enemy_data:
		enemy_name = _current_enemy_data.display_name
	_result_message.text = "%s 처치 완료!\n탄환 1개를 드래프트합니다." % enemy_name

	_draft_selected = null
	_draft_confirm_btn.disabled = true
	_draft_container.visible = true
	for child in _draft_cards_hbox.get_children():
		child.queue_free()
	for bullet in _generate_draft_choices():
		_draft_cards_hbox.add_child(_make_draft_card(bullet))

	_result_overlay.visible = true
	_fire_btn.disabled = true
	_unload_btn.disabled = true
	_reload_btn.disabled = true


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
		_result_message.text = "HP 버퍼 0. 사망했습니다."


func _on_enemy_sprite_gui_input(event: InputEvent, clicked_enemy: EnemyInstance) -> void:
	if not _is_targeting_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_targeting_mode = false
		_update_action_buttons()
		combat_manager.fire_at_target(clicked_enemy)


func _on_confirm_pressed() -> void:
	combat_manager.player_end_turn()

func _on_fire_pressed() -> void:
	if not combat_manager or combat_manager.state != CombatManager.State.PLAYER_TURN:
		return
		
	var next_bullet := combat_manager.magazine.peek()
	if next_bullet and next_bullet.slow > 0:
		# 슬로우 탄일 경우 자유 타겟 조준 모드로 전환
		if not _is_targeting_mode:
			_is_targeting_mode = true
			_update_action_buttons()
			add_combat_log("[color=#ffa500]🎯 조준 개시: 슬로우 탄 발사 표적을 지상 좀비 대열에서 직접 탭하여 지목하세요.[/color]")
			return
		else:
			# 다시 누르면 조준 해제 (일반 최근접 발사로 복귀)
			_is_targeting_mode = false
			_update_action_buttons()
			add_combat_log("[color=#5588aa]조준 해제: 최근접 적 자동 타겟팅으로 복귀합니다.[/color]")
			return
			
	# 일반 탄 격발
	parent_scene.trigger_camera_shake(12.0)
	combat_manager.fire()
	_update_action_buttons()

func _on_unload_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		combat_manager.request_unload()
		_update_action_buttons()


func _on_eject_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		combat_manager.request_eject()
		_update_action_buttons()


func _on_double_tap_toggled() -> void:
	if not combat_manager or combat_manager.state != CombatManager.State.PLAYER_TURN:
		return
		
	# Check if we have enough bullets
	if combat_manager.magazine.get_remaining() < 2:
		combat_manager.combat_log.emit("⚠ 탄창에 탄환이 2발 이상 있어야 더블탭을 선언할 수 없습니다.")
		return
		
	# Check if lead bullet was inserted this turn (tempo tax)
	if combat_manager._insert_seal_active:
		combat_manager.combat_log.emit("⚠ 이번 턴에 이미 납탄(삽탄)을 수행하여 더블탭을 선언할 수 없습니다.")
		return
		
	combat_manager.double_tap_active = not combat_manager.double_tap_active
	if combat_manager.double_tap_active:
		add_combat_log("[color=#ff8822]💥 더블탭 시그니처 선언! 이번 격발은 연속 2발 사격하며, 납탄(중간 장전)이 금지됩니다.[/color]")
	else:
		add_combat_log("[color=#888888]더블탭 선언 해제. 단발 사격 모드로 전환합니다.[/color]")
		
	_update_action_buttons()


func _on_reload_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		combat_manager.request_reload()


func _on_result_confirmed() -> void:
	if _draft_selected:
		run_manager.add_to_deck(_draft_selected)
	_draft_selected = null
	_result_overlay.visible = false
	visible = false
	var is_dead := (combat_manager.state == CombatManager.State.LOST and run_manager.hp_buffer == 0)
	parent_scene.handle_combat_finished(is_dead)


func _generate_draft_choices() -> Array[BulletData]:
	var pool: Array[BulletData] = []
	var path: String = "res://resources/bullets/"
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res") or file_name.ends_with(".res.remap"):
					var clean_name: String = file_name.replace(".remap", "")
					var res: BulletData = load(path + clean_name) as BulletData
					if res:
						pool.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()
		
	if pool.is_empty():
		# 폴백 안전 처리
		pool = [_bullets_basic, _bullets_ap, _bullets_kb, _bullets_heavy, _bullets_slow]
		
	pool.shuffle()
	var choices: Array[BulletData] = []
	var count: int = mini(3, pool.size())
	for i in range(count):
		choices.append(pool[i].duplicate())
	return choices

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


func _bullet_effect_name(effect: Enums.BulletEffect) -> String:
	match effect:
		Enums.BulletEffect.ARMOR_SHRED: return "[장갑 파쇄]"
		Enums.BulletEffect.COMBO: return "[콤보 사격]"
		Enums.BulletEffect.LAST_SHOT: return "[막탄 강화]"
		Enums.BulletEffect.OPENING_SHOT: return "[선제 사격]"
	return ""


func _update_action_buttons() -> void:
	if not combat_manager:
		return
		
	var is_tempo := combat_manager.gun and (combat_manager.gun.display_name.contains("Tempo") or combat_manager.gun.display_name.contains("속사형"))
	var is_trickster := combat_manager.gun and (combat_manager.gun.display_name.contains("Trickster") or combat_manager.gun.display_name.contains("곡예형"))
		
	if combat_manager.state == CombatManager.State.LOADING:
		_confirm_btn.visible = true
		_confirm_btn.disabled = _loaded_bullets.is_empty()
		
		_fire_btn.visible = false
		_unload_btn.visible = false
		_reload_btn.visible = false
		_double_tap_btn.visible = false
		_eject_btn.visible = false
		return
		
	_confirm_btn.visible = false
	_fire_btn.visible = true
	_unload_btn.visible = true
	_reload_btn.visible = true
	_double_tap_btn.visible = is_tempo
	_eject_btn.visible = is_trickster
	
	if combat_manager.state != CombatManager.State.PLAYER_TURN:
		_fire_btn.disabled = true
		_unload_btn.disabled = true
		_reload_btn.disabled = true
		if _double_tap_btn.visible:
			_double_tap_btn.disabled = true
		if _eject_btn.visible:
			_eject_btn.disabled = true
		return
		
	var has_ammo: bool = not combat_manager.magazine.is_empty()
	_fire_btn.disabled = not has_ammo
	_unload_btn.disabled = not has_ammo
	_reload_btn.disabled = false
	if _eject_btn.visible:
		_eject_btn.disabled = not has_ammo or combat_manager.eject_used_this_turn
	
	# 더블탭 버튼 제어
	if _double_tap_btn.visible:
		var ammo_count := combat_manager.magazine.get_remaining()
		if ammo_count < 2:
			if combat_manager.double_tap_active:
				combat_manager.double_tap_active = false
				add_combat_log("[color=#ff3333]⚠ 탄환이 부족하여 더블탭 선언이 해제되었습니다.[/color]")
			_double_tap_btn.disabled = true
		else:
			_double_tap_btn.disabled = false
			
		if combat_manager.double_tap_active:
			_double_tap_btn.text = "🔥 더블탭 ON"
			_apply_tactical_button_style(_double_tap_btn, parent_scene.C_WARNING)
		else:
			_double_tap_btn.text = "💥 더블탭 OFF"
			_apply_tactical_button_style(_double_tap_btn, parent_scene.C_DIM)
	
	if _is_targeting_mode:
		_fire_btn.text = "조준 중 (대상을 탭하세요)"
	elif has_ammo and combat_manager.enemy:
		var next_bullet := combat_manager.magazine.peek()
		var target := combat_manager.enemy
		
		var is_hit := DamageCalculator.check_hit(next_bullet, target.current_evasion, _current_gun_data)
		var next_pen := next_bullet.penetration
		if _current_gun_data:
			next_pen += _current_gun_data.passive_pen_bonus
			
		if not is_hit:
			_fire_btn.text = "⚠️ 빗나감! (격발)"
		elif next_pen < target.current_def:
			_fire_btn.text = "🛡️ 도탄! (격발)"
		else:
			_fire_btn.text = "🔫 격발"
	else:
		_fire_btn.text = "격발" 


func _update_enemy_display(enemy: EnemyInstance) -> void:
	var stance_suffix := ""
	var is_stance_hunter := combat_manager.gun and (combat_manager.gun.display_name.contains("Stance") or combat_manager.gun.display_name.contains("태세"))
	
	match enemy.current_stance:
		Enums.EnemyStance.IRON_SHIELD:
			var rem := 3 - enemy.shot_counter
			if is_stance_hunter:
				stance_suffix = " [물리 장갑 (전환까지 %d발) ➡️ 회피 돌격 예고]" % rem
			else:
				stance_suffix = " [물리 장갑 (전환까지 %d발)]" % rem
		Enums.EnemyStance.ACTIVE_DODGER:
			var rem := 3 - enemy.shot_counter
			if is_stance_hunter:
				stance_suffix = " [회피 돌격 (전환까지 %d발) ➡️ 물리 장갑 예고]" % rem
			else:
				stance_suffix = " [회피 돌격 (전환까지 %d발)]" % rem

	_enemy_name_label.text = "%s (%s)%s" % [
		enemy.data.display_name,
		_archetype_name(enemy.data.archetype),
		stance_suffix
	]
	_enemy_hp_bar.max_value = enemy.data.max_hp
	_enemy_hp_bar.value = enemy.current_hp
	_enemy_hp_label.text = "%d/%d" % [enemy.current_hp, enemy.data.max_hp]
	
	# 타겟인 최근접 좀비는 밝게 노출, 대기 좀비들은 약간 어둡고 푸른 톤으로 블렌딩하여 UI 계층 유도
	for e in _enemy_sprites.keys():
		var es = _enemy_sprites[e]
		if is_instance_valid(es):
			if e == enemy:
				es.modulate = Color.WHITE
				es.z_index = 10
			else:
				es.modulate = Color(0.6, 0.6, 0.7, 0.85)
				es.z_index = 5
		
	_update_enemy_stats_display(enemy)
	_update_distance_display(enemy)

func _update_enemy_stats_display(enemy: EnemyInstance) -> void:
	if parent_scene.is_goggles_enabled():
		_enemy_stats_label.text = "DEF %d | PRES %d | EVA %d | SPD %d" % [
			enemy.current_def, enemy.knockback_resistance,
			enemy.current_evasion, enemy.current_speed,
		]
	else:
		_enemy_stats_label.text = "DEF ? | PRES ? | EVA ? | SPD ?"


func _on_enemy_stance_changed(enemy_inst: EnemyInstance, new_stance: Enums.EnemyStance) -> void:
	var nearest = combat_manager.enemy
	if nearest:
		_update_enemy_display(nearest)


func _update_distance_display(enemy: EnemyInstance) -> void:
	var dist := enemy.current_distance

	_distance_label.text = "거리: %d" % dist
	_distance_bar.max_value = _global_max_dist
	_distance_bar.value = dist

	var ratio := float(dist) / _global_max_dist if _global_max_dist > 0 else 0.0
	var color: Color
	if ratio > 0.6:
		color = parent_scene.C_DIST_SAFE
	elif ratio > 0.3:
		color = parent_scene.C_DIST_WARN
	else:
		color = parent_scene.C_DIST_DANGER

	_distance_label.add_theme_color_override("font_color", color)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_bottom_left = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	_distance_bar.add_theme_stylebox_override("fill", fill_style)
	
	# 원근 Y/Scale 위치 보간 트리거
	_update_enemy_position_and_scale(enemy, true)


func _archetype_name(arch: Enums.EnemyArchetype) -> String:
	match arch:
		Enums.EnemyArchetype.RUSHER: return "돌격 요원"
		Enums.EnemyArchetype.TANK: return "방패 요원"
		Enums.EnemyArchetype.DODGER: return "침투 요원"
	return "?"


func _on_ingame_area_resized() -> void:
	if combat_manager and combat_manager.enemy:
		_update_enemy_position_and_scale(combat_manager.enemy, false)
	else:
		var size := _ingame_area.size
		if size.x == 0 or size.y == 0:
			return
		var floor_y: float = size.y - 25.0
		if _agent_sprite:
			_agent_sprite.position = Vector2(80.0 - 70.0, floor_y - 140.0)
			_agent_sprite.scale = Vector2(1.0, 1.0)


func _on_ingame_area_draw() -> void:
	var size := _track_overlay.size
	var floor_y := size.y - 25.0
	
	# 1. 2D 사이드뷰 평면 눈금선 그리기
	var track_color := Color(0.1, 0.7, 0.9, 0.25)
	_track_overlay.draw_line(Vector2(180.0, floor_y), Vector2(size.x - 150.0, floor_y), track_color, 2.0)
	
	# 2. 10m 거리 표시 눈금 그리기
	var tick_color := Color(0.1, 0.7, 0.9, 0.4)
	for i in range(1, 11):
		var ratio: float = float(i) / 10.0
		var x: float = lerp(180.0, size.x - 150.0, ratio)
		_track_overlay.draw_line(Vector2(x, floor_y - 4.0), Vector2(x, floor_y + 4.0), tick_color, 1.5)
		
	# 3. 생존해 있는 모든 적들의 눈금 마커 표시
	if combat_manager:
		var enemies_list: Array[EnemyInstance] = combat_manager.get_alive_enemies()
		var nearest: EnemyInstance = combat_manager.enemy
		for e: EnemyInstance in enemies_list:
			var dist_ratio: float = float(e.current_distance) / _global_max_dist if _global_max_dist > 0 else 0.0
			var x: float = lerp(180.0, size.x - 150.0, dist_ratio)
			
			if e == nearest:
				# 강제 타겟팅 대상 (최근접): 펄싱하는 네온 붉은색 마커
				_track_overlay.draw_circle(Vector2(x, floor_y), 6.0, Color(1.0, 0.1, 0.2, 0.4))
				_track_overlay.draw_circle(Vector2(x, floor_y), 4.0, Color(1.0, 0.1, 0.2, 0.9))
			else:
				# 후순위 대기 적: 든든한 경고 황색 마커
				_track_overlay.draw_circle(Vector2(x, floor_y), 4.0, Color(0.9, 0.6, 0.1, 0.8))
				
			# 술사(CASTER) 머리 위에 차징 미터 그리기
			if e.data.archetype == Enums.EnemyArchetype.CASTER:
				var head_y := floor_y - 150.0
				# 차징 게이지 배경 (검은색)
				_track_overlay.draw_rect(Rect2(x - 20, head_y, 40, 5), Color(0.08, 0.08, 0.1, 0.8))
				# 차징 충전량 (노란색/금색)
				var fill_w: float = 40.0 * (float(e.charge_turns_current) / float(e.charge_turns_max))
				_track_overlay.draw_rect(Rect2(x - 20, head_y, fill_w, 5), Color(1.0, 0.85, 0.15, 0.95))

func _update_enemy_position_and_scale(enemy: EnemyInstance, animate: bool) -> void:
	if not combat_manager:
		return
	var size: Vector2 = _ingame_area.size
	if size.x == 0 or size.y == 0:
		return
	
	var floor_y: float = size.y - 25.0
	
	# 아군은 항상 좌측 전경 바닥에 단단히 정박
	if _agent_sprite:
		var agent_scale: float = 0.5
		_agent_sprite.position = Vector2(80.0 - 70.0, floor_y - 70.0 - 70.0 * agent_scale)
		_agent_sprite.scale = Vector2(agent_scale, agent_scale)
		
	# 모든 생존해 있는 적들의 수평 위치 및 렌더링 스케일링 동기화
	for e in _enemy_sprites.keys():
		var es = _enemy_sprites[e]
		if not is_instance_valid(es) or e.is_dead():
			continue
			
		var dist: int = e.current_distance
		var ratio: float = float(dist) / _global_max_dist if _global_max_dist > 0 else 0.0
		
		# 2D 사이드뷰 수평 이동
		var target_x: float = lerp(180.0, size.x - 150.0, ratio)
		var target_scale: float = 0.75 # 몬스터는 0.75 스케일 (에이전트 0.5의 1.5배)
		var target_pos := Vector2(target_x - 70.0, floor_y - 70.0 - 70.0 * target_scale)
		
		if animate:
			var is_knockback: bool = target_pos.x > es.position.x
			var tilt_angle: float = 0.08 if is_knockback else -0.08
			
			var tween: Tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(es, "position", target_pos, 0.35)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_OUT)
			
			var scale_tween: Tween = create_tween()
			scale_tween.tween_property(es, "scale", Vector2(target_scale * 1.05, target_scale * 0.85), 0.15)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_OUT)
			scale_tween.tween_property(es, "scale", Vector2(target_scale, target_scale), 0.2)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_IN_OUT)
			
			var rot_tween: Tween = create_tween()
			rot_tween.tween_property(es, "rotation", tilt_angle, 0.15)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_OUT)
			rot_tween.tween_property(es, "rotation", 0.0, 0.2)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_IN_OUT)
		else:
			es.position = target_pos
			es.scale = Vector2(target_scale, target_scale)
			es.rotation = 0.0
			
	_track_overlay.queue_redraw()


func _spawn_hit_particles(es: TextureRect) -> void:
	if not es or not es.texture:
		return
		
	# 적 스프라이트의 중앙 위치 기준
	var sprite_w := 140.0 * es.scale.x
	var sprite_h := 140.0 * es.scale.y
	var pos := es.position + Vector2(sprite_w / 2.0, sprite_h / 2.0)
	
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 16
	particles.lifetime = 0.4
	particles.direction = Vector2(0, -1)
	particles.spread = 80.0
	particles.gravity = Vector2(0, 350)
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 160.0
	particles.color = Color(1.0, 0.75, 0.25, 0.95) # 픽셀 파편 스파크
	particles.speed_scale = 1.3
	particles.position = pos
	
	_ingame_area.add_child(particles)
	
	# 수명이 다하면 노드 파괴
	var timer := get_tree().create_timer(particles.lifetime + 0.1)
	timer.timeout.connect(func(): particles.queue_free())


func _get_bullet_icon(bullet_name: String) -> Texture2D:
	if bullet_name.contains("철갑탄") or bullet_name.contains("Armor") or bullet_name.contains("AP"):
		return load("res://assets/textures/bullets/armor_piercing_icon.png") as Texture2D
	elif bullet_name.contains("스턴탄") or bullet_name.contains("Slug") or bullet_name.contains("KB"):
		return load("res://assets/textures/bullets/knockback_slug_icon.png") as Texture2D
	return load("res://assets/textures/bullets/basic_bullet_icon.png") as Texture2D


# ═══════════════════════════════════════════════════
# ── 이너 클래스: 드래그 앤 드롭이 가능한 탄환 카드 노드 ──
# ═══════════════════════════════════════════════════
func _on_bag_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if combat_manager and (combat_manager.state == CombatManager.State.PLAYER_TURN or combat_manager.state == CombatManager.State.LOADING):
			_toggle_bag_panel(not _is_bag_expanded)


func _on_bullet_fired(bullet: BulletData, hit: bool, damage: int) -> void:
	if not _agent_sprite:
		return
	var size = _ingame_area.size
	var floor_y: float = size.y - 30.0
	var agent_scale: float = 0.5
	var base_pos: Vector2 = Vector2(80.0 - 70.0, floor_y - 70.0 - 70.0 * agent_scale)
	
	var tex = _agent_sprite.texture as AtlasTexture
	if tex:
		# 사격 프레임 (4번째 프레임 인덱스 3) 할당: 278 * 3
		tex.region = Rect2(278 * 3, 0, 278, 278)
	
	# 1. Firing Recoil Tween
	_agent_sprite.position = base_pos - Vector2(15.0, 0.0)  # Push back horizontally by 15px
	var tween: Tween = create_tween()
	tween.tween_property(_agent_sprite, "position", base_pos, 0.15)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	if tex:
		# 사격 반동 후 다시 조준(Aiming) 모션으로 복귀
		tween.tween_callback(func(): tex.region = Rect2(278 * 2, 0, 278, 278))
	
	# 2. Muzzle Flash HDR Effect
	_agent_sprite.modulate = Color(2.0, 1.5, 1.2, 1.0)  # Overbright glow
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(_agent_sprite, "modulate", Color.WHITE, 0.1)
	
	# 3. Bullet Trail Effect
	var trail: Line2D = _bullet_trail_scene.instantiate() as Line2D
	trail.add_point(base_pos + Vector2(100.0, -90.0)) # 총구 대략적 위치 (가방/요원 좌표 기준)
	
	var target_x: float = size.x # 기본: 화면 끝
	var target_y: float = floor_y - 100.0
	var first_enemy_sprite = _enemy_sprites.values().front() if not _enemy_sprites.is_empty() else null
	if first_enemy_sprite and is_instance_valid(first_enemy_sprite):
		target_x = first_enemy_sprite.position.x + 70.0 # 몬스터 중앙
		target_y = first_enemy_sprite.position.y + 70.0
		if not hit:
			target_x += 250.0 # 빗나가면 뒤로 뚫고 지나감
			target_y += randf_range(-60.0, 60.0) # 살짝 빗나감
			_spawn_damage_floating_text(first_enemy_sprite, -1)
			
	trail.add_point(Vector2(target_x, target_y))
	_ingame_area.add_child(trail)

func _toggle_bag_panel(expand: bool) -> void:
	_is_bag_expanded = expand
	_bag_mini_summary.visible = not expand
	_bag_scroll.visible = expand
	
	var header := _right_bag_panel.get_node("BagMargin/BagVBox/BagHeader") as Control
	if header:
		header.visible = expand
		
	_btn_load_card.visible = expand
	_btn_unload_card.visible = expand
	_magazine_label.visible = expand


func _update_cylinder_visuals() -> void:
	if not _mag_tube_container:
		return
		
	for child in _mag_tube_container.get_children():
		if child != _magazine_slots_label:
			_mag_tube_container.remove_child(child)
			child.queue_free()
			
	var bullets: Array[BulletData] = []
	var is_loading_phase := false
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		bullets = combat_manager.magazine.get_loaded_bullets()
	else:
		bullets = _loaded_bullets
		is_loading_phase = true
		
	var animate_last := false
	if is_loading_phase:
		animate_last = bullets.size() > _last_loaded_count
		_last_loaded_count = bullets.size()
		
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(32, 20)
		
		# 장전 페이즈 중일 때 튜브 내 탄환을 클릭하면 다시 가방으로 회수
		if is_loading_phase:
			wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
			var remove_idx := i
			var remove_bullet := b
			wrapper.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if remove_idx < _loaded_bullets.size() and _loaded_bullets[remove_idx] == remove_bullet:
						_loaded_bullets.remove_at(remove_idx)
						_bullet_pool[remove_bullet] = _bullet_pool.get(remove_bullet, 0) + 1
						_refresh_loading_ui()
			)
		else:
			wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
		_mag_tube_container.add_child(wrapper)
		
		var bullet_tr := TextureRect.new()
		
		# 예고창 가시성 처리
		var depth_index := (bullets.size() - 1) - i
		var is_hidden := not is_loading_phase and depth_index >= run_manager.visible_magazine_slots
		
		if is_hidden:
			# 가려진 칸은 아이콘 대신 회색조/반투명 처리 (잔량만 표시)
			bullet_tr.texture = _get_bullet_icon("기본 탄환") # 임시 텍스처, 모듈레이트로 가림
			bullet_tr.modulate = Color(0.3, 0.3, 0.3, 0.3)
		else:
			bullet_tr.texture = _get_bullet_icon(b.display_name)
			
		bullet_tr.custom_minimum_size = Vector2(32, 32)
		bullet_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bullet_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bullet_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		bullet_tr.pivot_offset = Vector2(16, 16)
		bullet_tr.rotation_degrees = 90.0
		bullet_tr.position.x = 0
		
		wrapper.add_child(bullet_tr)
		
		if animate_last and i == bullets.size() - 1:
			bullet_tr.position.y = -100.0
			var tween: Tween = create_tween()
			tween.tween_property(bullet_tr, "position:y", 0.0, 0.35)\
				.set_trans(Tween.TRANS_BOUNCE)\
				.set_ease(Tween.EASE_OUT)

func _update_hit_info(enemy: EnemyInstance) -> void:
	if not _hit_info_label:
		return
	if not enemy or not enemy.data:
		_hit_info_label.text = "대기 중..."
		return
		
	if not combat_manager or not combat_manager.magazine:
		_hit_info_label.text = "탄창 정보가 없습니다."
		return
		
	var bullets: Array[BulletData] = []
	if combat_manager.state == CombatManager.State.LOADING:
		bullets = _loaded_bullets
	else:
		bullets = combat_manager.magazine.get_loaded_bullets()
		
	if bullets.is_empty():
		_hit_info_label.text = "[color=#aa8888]탄창이 비어 있습니다.[/color]\n사격하려면 탄환을 삽탄하십시오."
		return
		
	var next_bullet: BulletData = bullets.back() # top of stack is the last element
	var acc: int = next_bullet.accuracy
	var eva: int = enemy.current_evasion
	var is_hit: bool = acc >= eva
	
	var hit_text := ""
	if is_hit:
		hit_text = "[color=#55aa55][b]명중 확정[/b][/color] (100%)\n"
	else:
		hit_text = "[color=#ff5555][b]빗나감 예고[/b][/color] (0%)\n"
		
	hit_text += "사격 예정: [color=#eeaa44]%s[/color]\n명중률(ACC): %d vs 회피값(EVA): %d" % [
		next_bullet.display_name,
		acc,
		eva
	]
	_hit_info_label.text = hit_text


func _apply_tactical_button_style(btn: Button, color: Color) -> void:
	# Normal stylebox
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.75)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.8)
	normal.corner_radius_bottom_left = 2
	normal.corner_radius_bottom_right = 2
	normal.corner_radius_top_left = 2
	normal.corner_radius_top_right = 2
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", normal)

	# Hover stylebox (thicker border, brighter background)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.85)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(color.r, color.g, color.b, 1.0)
	hover.corner_radius_bottom_left = 2
	hover.corner_radius_bottom_right = 2
	hover.corner_radius_top_left = 2
	hover.corner_radius_top_right = 2
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed stylebox
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(color.r * 0.08, color.g * 0.08, color.b * 0.08, 0.95)
	pressed.border_width_left = 1
	pressed.border_width_right = 1
	pressed.border_width_top = 1
	pressed.border_width_bottom = 1
	pressed.border_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.9)
	pressed.corner_radius_bottom_left = 2
	pressed.corner_radius_bottom_right = 2
	pressed.corner_radius_top_left = 2
	pressed.corner_radius_top_right = 2
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	btn.add_theme_stylebox_override("pressed", pressed)

	# Disabled stylebox
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.08, 0.1, 0.4)
	disabled.border_width_left = 1
	disabled.border_width_right = 1
	disabled.border_width_top = 1
	disabled.border_width_bottom = 1
	disabled.border_color = Color(0.2, 0.22, 0.25, 0.3)
	disabled.corner_radius_bottom_left = 2
	disabled.corner_radius_bottom_right = 2
	disabled.corner_radius_top_left = 2
	disabled.corner_radius_top_right = 2
	disabled.content_margin_left = 12
	disabled.content_margin_right = 12
	btn.add_theme_stylebox_override("disabled", disabled)

	# Glow font colors
	btn.add_theme_color_override("font_color", Color(color.r * 0.9, color.g * 0.9, color.b * 0.9))
	btn.add_theme_color_override("font_hover_color", Color(color.r, color.g, color.b))
	btn.add_theme_color_override("font_pressed_color", Color(color.r * 0.7, color.g * 0.7, color.b * 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.45))


func _apply_tactical_panel_style(panel: PanelContainer, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.06, color.g * 0.06, color.b * 0.08, 0.85)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(color.r, color.g, color.b, 0.7)
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	panel.add_theme_stylebox_override("panel", style)


func _on_enemy_killed(enemy_inst: EnemyInstance) -> void:
	var es = _enemy_sprites.get(enemy_inst)
	if es and is_instance_valid(es):
		var fade_tween := create_tween()
		# Flash white (HDR glow) then fade out red
		fade_tween.tween_property(es, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.15)
		fade_tween.tween_property(es, "modulate", Color(1.0, 0.2, 0.2, 0.0), 0.35)
		fade_tween.tween_callback(func():
			if is_instance_valid(es):
				es.queue_free()
			_enemy_sprites.erase(enemy_inst)
			
			var nearest = combat_manager.enemy
			if nearest:
				_update_enemy_display(nearest)
				_update_distance_display(nearest)
				_update_hit_info(nearest)
		)

func _on_all_enemies_moved() -> void:
	var nearest = combat_manager.enemy
	if nearest:
		_update_enemy_position_and_scale(nearest, true)
	_track_overlay.queue_redraw()
