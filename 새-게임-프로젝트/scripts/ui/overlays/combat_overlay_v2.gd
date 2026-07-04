class_name CombatOverlayV2
extends MarginContainer

## ═══════════════════════════════════════════════════
## 🧠 L.O.B 전투 UI V2 데모 오버레이 (새로운 노드 트리 구조 기반 설계)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager
var combat_manager: CombatManager

# ── 프리로드 리소스 ──
var _bullets_basic: BulletData = preload("res://resources/bullets/basic_bullet.tres")
var _bullets_ap: BulletData = preload("res://resources/bullets/armor_piercing.tres")
var _bullets_kb: BulletData = preload("res://resources/bullets/knockback_slug.tres")
var _bullets_heavy: BulletData = preload("res://resources/bullets/heavy_bullet.tres")

# ── 상태 ──
var _bullet_pool: Dictionary = {}
var _loaded_bullets: Array[BulletData] = []
var _enemy_sprites: Dictionary = {}
var _global_max_dist: float = 12.0
var _is_targeting_mode: bool = false
var _is_bag_expanded: bool = false
var _last_bullet_count: int = -1
var _last_loaded_count: int = 0
var _current_gun_data: GunData

# ── UI 참조 (MainFlow 내부 자식들) ──
# 1. TopBar
var _top_log_toast: Label
var _phase_label: Label

# 2. DistanceLabel (CenterContainer로 래핑됨)
var _distance_label: Label

# 3. Battlefield
# LeftColumn
var _hit_info_panel: PanelContainer
var _hit_info_label: RichTextLabel
var _lookahead_container: VBoxContainer
var _card_next: PanelContainer
var _card_2: PanelContainer
var _card_bundle: PanelContainer
var _agent_sprite: TextureRect

# Track
var _track_control: Control
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
var _drawer_panel: PanelContainer
var _drawer_tab_item: Button
var _drawer_tab_ammo: Button
var _drawer_body_item: VBoxContainer
var _drawer_body_ammo: VBoxContainer

func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	_build_ui()

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
		_toggle_drawer(_is_bag_expanded)

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
	
	# (1-A) TopBar (HBoxContainer)
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.custom_minimum_size = Vector2(0, 24)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_flow.add_child(top_bar)
	
	_top_log_toast = parent_scene.make_label("준비 완료", 12, parent_scene.C_SUCCESS)
	_top_log_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_top_log_toast)
	
	_phase_label = parent_scene.make_label("전투 대기 페이즈", 12, parent_scene.C_DIM)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(_phase_label)
	
	# (1-B) DistanceLabel (Label, CenterContainer로 감싸 중앙)
	var dist_center := CenterContainer.new()
	dist_center.name = "DistanceContainer"
	dist_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dist_center.custom_minimum_size = Vector2(0, 36)
	main_flow.add_child(dist_center)
	
	_distance_label = parent_scene.make_label("12 m", 24, parent_scene.C_WARNING)
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dist_center.add_child(_distance_label)
	
	# (1-C) Battlefield (HBoxContainer)
	var battlefield := HBoxContainer.new()
	battlefield.name = "Battlefield"
	battlefield.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	battlefield.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	battlefield.add_theme_constant_override("separation", 12)
	main_flow.add_child(battlefield)
	
	# LeftColumn (VBoxContainer, 고정폭 260)
	var left_col := VBoxContainer.new()
	left_col.name = "LeftColumn"
	left_col.custom_minimum_size = Vector2(260, 0)
	left_col.size_flags_horizontal = Control.SIZE_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	left_col.add_theme_constant_override("separation", 8)
	battlefield.add_child(left_col)
	
	# HitAnalysis (PanelContainer) — 명중분석
	_hit_info_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	_hit_info_panel.name = "HitAnalysis"
	_hit_info_panel.custom_minimum_size = Vector2(0, 70)
	_hit_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(_hit_info_panel, parent_scene.C_ACCENT)
	left_col.add_child(_hit_info_panel)
	
	var hit_margin := MarginContainer.new()
	hit_margin.add_theme_constant_override("margin_left", 10)
	hit_margin.add_theme_constant_override("margin_right", 10)
	hit_margin.add_theme_constant_override("margin_top", 8)
	hit_margin.add_theme_constant_override("margin_bottom", 8)
	_hit_info_panel.add_child(hit_margin)
	
	var hit_vbox := VBoxContainer.new()
	hit_margin.add_child(hit_vbox)
	
	var hit_title: Label = parent_scene.make_label("◎ 격발 분석", 11, parent_scene.C_SUCCESS)
	hit_vbox.add_child(hit_title)
	
	_hit_info_label = RichTextLabel.new()
	_hit_info_label.bbcode_enabled = true
	_hit_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hit_info_label.add_theme_font_size_override("normal_font_size", 12)
	_hit_info_label.text = "대기 중..."
	hit_vbox.add_child(_hit_info_label)
	
	# Lookahead (VBoxContainer) — 예고창 세로
	_lookahead_container = VBoxContainer.new()
	_lookahead_container.name = "Lookahead"
	_lookahead_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lookahead_container.add_theme_constant_override("separation", 4)
	left_col.add_child(_lookahead_container)
	
	_card_next = PanelContainer.new()
	_card_next.name = "Card_Next"
	_card_next.custom_minimum_size = Vector2(0, 38)
	_card_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lookahead_container.add_child(_card_next)
	
	_card_2 = PanelContainer.new()
	_card_2.name = "Card_2"
	_card_2.custom_minimum_size = Vector2(0, 38)
	_card_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lookahead_container.add_child(_card_2)
	
	_card_bundle = PanelContainer.new()
	_card_bundle.name = "Bundle"
	_card_bundle.custom_minimum_size = Vector2(0, 30)
	_card_bundle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lookahead_container.add_child(_card_bundle)
	
	# Track (Control, size_flags: Expand) — 컨테이너가 아님
	_track_control = Control.new()
	_track_control.name = "Track"
	_track_control.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	_track_control.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	_track_control.custom_minimum_size = Vector2(500, 200)
	_track_control.clip_contents = true
	battlefield.add_child(_track_control)
	
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.04, 0.04, 0.06, 1.0)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track_control.add_child(bg_rect)
	
	# 수평 트랙 중심선
	_track_line = ColorRect.new()
	_track_line.color = Color(0.18, 0.22, 0.28, 0.6)
	_track_line.custom_minimum_size = Vector2(0, 4)
	_track_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track_line.anchor_top = 0.5
	_track_line.anchor_bottom = 0.5
	_track_line.offset_top = -2
	_track_line.offset_bottom = 2
	_track_line.offset_left = 0
	_track_line.offset_right = 0
	_track_control.add_child(_track_line)
	
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
	_agent_sprite.anchor_top = 0.5
	_agent_sprite.anchor_bottom = 0.5
	# 캐릭터가 트랙 왼쪽 경계 밖으로 나가지 않게 10px 마진을 두며 세로 중앙 정착
	_agent_sprite.offset_left = 10
	_agent_sprite.offset_right = 90
	_agent_sprite.offset_top = -40
	_agent_sprite.offset_bottom = 40
	
	# (1-D) ShotLog (PanelContainer → Label) — 사격 로그 한 줄
	_shot_log_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	_shot_log_panel.name = "ShotLog"
	_shot_log_panel.custom_minimum_size = Vector2(0, 28)
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
	_shot_log_label.scroll_active = false
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
	_drawer_panel = PanelContainer.new()
	_drawer_panel.name = "BagDrawer"
	_drawer_panel.custom_minimum_size = Vector2(0, 180)
	_drawer_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_drawer_panel)
	
	var drawer_style := StyleBoxFlat.new()
	drawer_style.bg_color = Color(0.05, 0.07, 0.11, 0.96)
	drawer_style.border_width_top = 2
	drawer_style.border_color = parent_scene.C_SUCCESS
	_drawer_panel.add_theme_stylebox_override("panel", drawer_style)
	
	# 초기 위치 설정
	_drawer_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_drawer_panel.position.y = size.y if size.y > 0 else 600
	_drawer_panel.visible = false
	
	var drawer_vbox := VBoxContainer.new()
	_drawer_panel.add_child(drawer_vbox)
	
	var head_hbox := HBoxContainer.new()
	head_hbox.add_theme_constant_override("separation", 10)
	drawer_vbox.add_child(head_hbox)
	
	var tab_hbox := HBoxContainer.new()
	head_hbox.add_child(tab_hbox)
	
	_drawer_tab_item = parent_scene.make_button("소모품 · 즉발", func(): _switch_drawer_tab(true), parent_scene.C_SUCCESS)
	tab_hbox.add_child(_drawer_tab_item)
	
	_drawer_tab_ammo = parent_scene.make_button("탄환 · 열람", func(): _switch_drawer_tab(false), parent_scene.C_DIM)
	tab_hbox.add_child(_drawer_tab_ammo)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_hbox.add_child(spacer)
	
	var close_btn: Button = parent_scene.make_button("✕ 닫기", func(): _toggle_drawer(false), parent_scene.C_DIM)
	head_hbox.add_child(close_btn)
	
	_drawer_body_item = VBoxContainer.new()
	_drawer_body_item.add_theme_constant_override("separation", 6)
	drawer_vbox.add_child(_drawer_body_item)
	
	var item1 := _create_drawer_item("✚ 응급 키트", "체력 회복", true)
	_drawer_body_item.add_child(item1)
	
	var item2 := _create_drawer_item("◆ 장갑 파쇄액", "DEF 차감 디버프", true)
	_drawer_body_item.add_child(item2)
	
	var item3 := _create_drawer_item("≈ 둔화 지뢰", "SPD 둔화 장치", true)
	_drawer_body_item.add_child(item3)
	
	_drawer_body_ammo = VBoxContainer.new()
	_drawer_body_ammo.add_theme_constant_override("separation", 6)
	_drawer_body_ammo.visible = false
	drawer_vbox.add_child(_drawer_body_ammo)
	
	var ammo1 := _create_drawer_item("▮ 9mm 일반탄 x12", "가용 가능", false)
	_drawer_body_ammo.add_child(ammo1)
	var ammo2 := _create_drawer_item("▮ 7.62 관통탄 x4", "가용 가능", false)
	_drawer_body_ammo.add_child(ammo2)
	
	var note_lbl: Label = parent_scene.make_label("🔒 전투 중 탄환 수정 차단 - 삽탄은 준비실/적재 페이즈에서만 가능합니다.", 11, parent_scene.C_DIM)
	_drawer_body_ammo.add_child(note_lbl)

func _create_drawer_item(title: String, desc: String, can_use: bool) -> HBoxContainer:
	var item_hbox := HBoxContainer.new()
	item_hbox.add_theme_constant_override("separation", 12)
	
	var lbl_title: Label = parent_scene.make_label(title, 13, parent_scene.C_TEXT)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_hbox.add_child(lbl_title)
	
	var lbl_desc: Label = parent_scene.make_label(desc, 12, parent_scene.C_DIM)
	item_hbox.add_child(lbl_desc)
	
	if can_use:
		var use_btn: Button = parent_scene.make_button("사용", func():
			add_combat_log("[color=#37e0ac]💊 소모품 즉발 사용: %s 효과가 격발되었습니다.[/color]" % title)
			_toggle_drawer(false)
		, parent_scene.C_SUCCESS)
		item_hbox.add_child(use_btn)
	else:
		var use_btn: Button = parent_scene.make_button("잠금", func(): pass, parent_scene.C_DIM)
		use_btn.disabled = true
		item_hbox.add_child(use_btn)
		
	return item_hbox

func _switch_drawer_tab(is_item: bool) -> void:
	_drawer_tab_item.modulate = Color.WHITE if is_item else Color(0.6, 0.6, 0.6)
	_drawer_tab_ammo.modulate = Color.WHITE if not is_item else Color(0.6, 0.6, 0.6)
	_drawer_body_item.visible = is_item
	_drawer_body_ammo.visible = not is_item

func _toggle_drawer(expand: bool) -> void:
	_is_bag_expanded = expand
	if not is_instance_valid(_drawer_panel):
		return
	_drawer_panel.visible = expand
	if expand:
		_drawer_panel.position.y = size.y - 180
	else:
		_drawer_panel.position.y = size.y

func _on_bag_clicked() -> void:
	_toggle_drawer(not _is_bag_expanded)

# ── 전투 로직 바인딩 및 이벤트 핸들링 (호환성) ──

func start_combat(gun: GunData, enemy_list: Array, cm: CombatManager) -> void:
	combat_manager = cm
	_current_gun_data = gun
	
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
	combat_manager.bullet_fired.connect(_on_bullet_fired)
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
		
	combat_manager.start_encounter(gun, enemy_data_list, run_manager.active_relics if run_manager else [])

func _on_encounter_started(enemy_list) -> void:
	_last_bullet_count = -1
	
	# 이전 몬스터 노드 정리
	for key in _enemy_sprites.keys():
		var es = _enemy_sprites[key]
		if is_instance_valid(es):
			es.queue_free()
	_enemy_sprites.clear()
	
	# 수평 트랙 상에 적 리스트 생성 및 정렬
	for enemy in enemy_list:
		var es := TextureRect.new()
		if enemy.data and enemy.data.icon:
			es.texture = enemy.data.icon
		else:
			es.texture = load("res://assets/sprites/zombie_sheet.png")
			if es.texture:
				var atlas := AtlasTexture.new()
				atlas.atlas = es.texture
				atlas.region = Rect2(0, 0, 380, 380)
				es.texture = atlas
				
		es.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		es.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		es.layout_mode = 1
		es.custom_minimum_size = Vector2(80, 80)
		es.pivot_offset = Vector2(40, 40)
		es.mouse_filter = Control.MOUSE_FILTER_STOP
		es.gui_input.connect(func(event): _on_enemy_sprite_gui_input(event, enemy))
		
		# 적 노드를 Track에 탑재
		_track_control.add_child(es)
		_enemy_sprites[enemy] = es
		
		_build_enemy_badge(es, enemy)
		
	_global_max_dist = 20.0
	var max_found := 0
	for e in enemy_list:
		if e.start_distance > max_found:
			max_found = e.start_distance
	if max_found > 0:
		_global_max_dist = maxf(float(max_found) + 6.0, 20.0)
		
	_update_enemy_position_and_scale(null, false)
	
	var nearest = combat_manager.enemy
	if nearest:
		_update_distance_display(nearest)
		_update_hit_info(nearest)
	_update_cylinder_visuals()
	_update_action_buttons()
	_update_phase_state()

func _build_enemy_badge(es: TextureRect, enemy: EnemyInstance) -> void:
	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(24, 24)
	badge_panel.position = Vector2(28, -28)
	es.add_child(badge_panel)
	
	var badge_style := StyleBoxFlat.new()
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_left = 12
	badge_style.corner_radius_bottom_right = 12
	
	var txt := "?"
	var color := Color.GRAY
	match enemy.data.archetype:
		Enums.EnemyArchetype.RUSHER:
			txt = "돌"
			color = parent_scene.C_DANGER
		Enums.EnemyArchetype.TANK:
			txt = "방"
			color = parent_scene.C_ACCENT
		Enums.EnemyArchetype.DODGER:
			txt = "회"
			color = parent_scene.C_SUCCESS
		Enums.EnemyArchetype.SCRAMBLER:
			txt = "스"
			color = parent_scene.C_NEON_GOLD
		_:
			txt = "술"
			color = parent_scene.C_WARNING
			
	badge_style.bg_color = color.darkened(0.3)
	badge_style.border_width_left = 1
	badge_style.border_width_right = 1
	badge_style.border_width_top = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = color
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	
	var lbl: Label = parent_scene.make_label(txt, 11, Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(lbl)
	
	# 타겟 지시기 (최근접 링)
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0,0,0,0)
	ring_style.border_width_left = 2
	ring_style.border_width_right = 2
	ring_style.border_width_top = 2
	ring_style.border_width_bottom = 2
	ring_style.border_color = parent_scene.C_DANGER
	ring_style.corner_radius_top_left = 40
	ring_style.corner_radius_top_right = 40
	ring_style.corner_radius_bottom_left = 40
	ring_style.corner_radius_bottom_right = 40
	
	var ring_panel := PanelContainer.new()
	ring_panel.name = "RingPanel"
	ring_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring_panel.add_theme_stylebox_override("panel", ring_style)
	es.add_child(ring_panel)
	ring_panel.visible = false

func _update_enemy_position_and_scale(target_enemy: EnemyInstance, animate: bool) -> void:
	if not combat_manager:
		return
		
	var nearest = combat_manager.enemy
	
	for e in _enemy_sprites.keys():
		var es = _enemy_sprites[e]
		if not is_instance_valid(es) or e.is_dead():
			if is_instance_valid(es):
				es.visible = false
			continue
			
		es.visible = true
		var dist: int = e.current_distance
		var ratio: float = float(dist) / _global_max_dist if _global_max_dist > 0.0 else 0.0
		
		# [절대 규칙] anchor_left = 거리 / 최대거리로 수평 자유 배치
		# 우측 끝 잘림 방지 패딩 보정 (가용 최대 앵커 비율을 0.88로 조율)
		var anchor_ratio := ratio * 0.88
		es.anchor_left = anchor_ratio
		es.anchor_right = anchor_ratio
		es.anchor_top = 0.5
		es.anchor_bottom = 0.5
		
		# 중심점이 앵커에 오도록 마진 오프셋 계산 (80px 크기)
		es.offset_left = -40
		es.offset_right = 40
		es.offset_top = -40
		es.offset_bottom = 40
		es.scale = Vector2(0.8, 0.8)
		
		# 타겟 링 표시 갱신
		var ring = es.get_node_or_null("RingPanel")
		if ring:
			ring.visible = (e == nearest)

func _update_distance_display(enemy: EnemyInstance) -> void:
	if not enemy or enemy.is_dead():
		_distance_label.text = "- m"
		return
		
	var dist := enemy.current_distance
	_distance_label.text = "%d m" % dist
	
	# 생사선 위험 연출 분기
	if dist <= 3:
		_distance_label.add_theme_color_override("font_color", parent_scene.C_DANGER)
		_top_log_toast.text = "⚠ 즉사 위험! 다음 턴 진입 시 사망합니다!"
		_top_log_toast.add_theme_color_override("font_color", parent_scene.C_DANGER)
	elif dist <= 6:
		_distance_label.add_theme_color_override("font_color", parent_scene.C_WARNING)
		_top_log_toast.text = "경고 — 적이 접근 중입니다."
		_top_log_toast.add_theme_color_override("font_color", parent_scene.C_WARNING)
	else:
		_distance_label.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
		_top_log_toast.text = "상황 대기 중"
		_top_log_toast.add_theme_color_override("font_color", parent_scene.C_SUCCESS)

func _update_cylinder_visuals() -> void:
	var bullets: Array[BulletData] = []
	if combat_manager:
		bullets = combat_manager.magazine.get_loaded_bullets()
		
	# 1. Card_Next (1번째 발사 예정 탄환)
	if bullets.size() > 0:
		_card_next.visible = true
		_update_card_visual(_card_next, bullets[0], "다음 격발", true)
	else:
		_card_next.visible = true
		_update_card_empty_visual(_card_next, "약실 비어있음")
		
	# 2. Card_2 (2번째 탄환)
	if bullets.size() > 1:
		_card_2.visible = true
		_update_card_visual(_card_2, bullets[1], "그다음", false)
	else:
		_card_2.visible = false
		
	# 3. Bundle (나머지 탄환 더미)
	if bullets.size() > 2:
		_card_bundle.visible = true
		_update_bundle_visual(_card_bundle, bullets.size() - 2)
	else:
		_card_bundle.visible = false

func _update_card_visual(card: PanelContainer, bullet: BulletData, label_text: String, is_next: bool) -> void:
	_apply_panel_style(card, _get_bullet_color(bullet))
	
	if card.get_child_count() == 0:
		var card_vbox := VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(card_vbox)
		
		var idx_lbl: Label = parent_scene.make_label(label_text, 10, parent_scene.C_SUCCESS if is_next else parent_scene.C_DIM)
		idx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		idx_lbl.name = "IndexLabel"
		card_vbox.add_child(idx_lbl)
		
		var name_lbl: Label = parent_scene.make_label(bullet.display_name, 12, Color.WHITE)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.name = "NameLabel"
		card_vbox.add_child(name_lbl)
	else:
		var card_vbox = card.get_child(0)
		var idx_lbl = card_vbox.get_node("IndexLabel") as Label
		var name_lbl = card_vbox.get_node("NameLabel") as Label
		idx_lbl.text = label_text
		idx_lbl.add_theme_color_override("font_color", parent_scene.C_SUCCESS if is_next else parent_scene.C_DIM)
		name_lbl.text = bullet.display_name

func _update_card_empty_visual(card: PanelContainer, text: String) -> void:
	_apply_panel_style(card, parent_scene.C_DIM)
	
	if card.get_child_count() == 0:
		var card_vbox := VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(card_vbox)
		
		var idx_lbl: Label = parent_scene.make_label("약실", 10, parent_scene.C_DIM)
		idx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		idx_lbl.name = "IndexLabel"
		card_vbox.add_child(idx_lbl)
		
		var name_lbl: Label = parent_scene.make_label(text, 12, parent_scene.C_DIM)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.name = "NameLabel"
		card_vbox.add_child(name_lbl)
	else:
		var card_vbox = card.get_child(0)
		var idx_lbl = card_vbox.get_node("IndexLabel") as Label
		var name_lbl = card_vbox.get_node("NameLabel") as Label
		idx_lbl.text = "약실"
		idx_lbl.add_theme_color_override("font_color", parent_scene.C_DIM)
		name_lbl.text = text

func _update_bundle_visual(card: PanelContainer, count: int) -> void:
	var bundle_style := StyleBoxFlat.new()
	bundle_style.bg_color = Color(0.06, 0.08, 0.12, 0.6)
	bundle_style.border_width_left = 1
	bundle_style.border_width_right = 1
	bundle_style.border_width_top = 1
	bundle_style.border_width_bottom = 1
	bundle_style.border_color = parent_scene.C_DIM
	bundle_style.corner_radius_top_left = 4
	bundle_style.corner_radius_top_right = 4
	bundle_style.corner_radius_bottom_left = 4
	bundle_style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", bundle_style)
	
	if card.get_child_count() == 0:
		var bundle_lbl: Label = parent_scene.make_label("+ %d칸 더 적재됨" % count, 11, parent_scene.C_DIM)
		bundle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bundle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bundle_lbl.name = "BundleLabel"
		card.add_child(bundle_lbl)
	else:
		var bundle_lbl = card.get_child(0) as Label
		bundle_lbl.text = "+ %d칸 더 적재됨" % count

func _get_bullet_color(bullet: BulletData) -> Color:
	if "AP" in bullet.display_name or "관통" in bullet.display_name:
		return parent_scene.C_SUCCESS
	elif "KB" in bullet.display_name or "넉백" in bullet.display_name:
		return parent_scene.C_WARNING
	elif "HEAVY" in bullet.display_name or "중장" in bullet.display_name:
		return parent_scene.C_NEON_GOLD
	return parent_scene.C_DIM

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
		_fire_btn.text = "✅ 장전완료"
		_fire_btn.disabled = _loaded_bullets.is_empty()
		_unload_btn.disabled = true
		_reload_btn.disabled = true
		if _double_tap_btn.visible: _double_tap_btn.disabled = true
		if _eject_btn.visible: _eject_btn.disabled = true
		return
		
	_fire_btn.text = "🔫 발사"
	
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
		_eject_btn.disabled = not has_ammo or combat_manager.eject_used_this_turn
	if _double_tap_btn.visible:
		_double_tap_btn.disabled = not has_ammo or combat_manager.double_tap_used_this_turn
		_double_tap_btn.text = "💥 더블탭 ON" if combat_manager.double_tap_active else "💥 더블탭 OFF"

func _update_phase_state() -> void:
	if not combat_manager: return
	match combat_manager.state:
		CombatManager.State.LOADING:
			_phase_label.text = "탄창 적재 페이즈"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
		CombatManager.State.PLAYER_TURN:
			_phase_label.text = "아군 작전 페이즈"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_ACCENT)
		CombatManager.State.RELOADING:
			_phase_label.text = "탄창 리로드 중"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_WARNING)
		CombatManager.State.WON:
			_phase_label.text = "작전 성공 (WON)"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
		CombatManager.State.LOST:
			_phase_label.text = "작전 실패 (LOST)"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_DANGER)
		_:
			_phase_label.text = "전투 대기 중"
			_phase_label.add_theme_color_override("font_color", parent_scene.C_DIM)

# ── 버튼 핸들러 연동 ──

func _on_fire_pressed() -> void:
	if not combat_manager: return
	if combat_manager.state == CombatManager.State.LOADING:
		_on_loading_confirm()
		return
	if combat_manager.state != CombatManager.State.PLAYER_TURN: return
	
	parent_scene.trigger_camera_shake(10.0)
	combat_manager.fire()
	_update_action_buttons()
	_update_phase_state()

func _on_unload_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		combat_manager.request_unload()
		_update_action_buttons()

func _on_reload_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		combat_manager.request_reload()
		_update_action_buttons()

func _on_double_tap_toggled() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		combat_manager.toggle_double_tap()
		_update_action_buttons()

func _on_eject_pressed() -> void:
	if combat_manager and combat_manager.state == CombatManager.State.PLAYER_TURN:
		combat_manager.request_eject()
		_update_action_buttons()

func _on_loading_confirm() -> void:
	if combat_manager:
		combat_manager.confirm_loading(_loaded_bullets)
		_loaded_bullets.clear()
		_update_cylinder_visuals()
		_update_action_buttons()
		_update_phase_state()

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

func _on_armor_shredded(enemy_inst: EnemyInstance, new_def: int, amount: int) -> void:
	add_combat_log("[color=#a878e8] 파쇄: %s의 DEF가 %d 차감되었습니다.[/color]" % [
		enemy_inst.data.display_name, amount
	])

func _on_enemy_stance_changed(enemy_inst: EnemyInstance, new_stance: Enums.EnemyStance) -> void:
	add_combat_log("🔄 태세전환: %s가 새로운 태세로 전환되었습니다." % enemy_inst.data.display_name)

func _on_magazine_updated() -> void:
	_update_cylinder_visuals()
	var nearest = combat_manager.enemy
	if nearest:
		_update_hit_info(nearest)
	_update_action_buttons()

func _on_bullet_fired(bullet: BulletData) -> void:
	add_combat_log("[color=#ffa500]🔫 격발: %s가 격발되었습니다.[/color]" % bullet.display_name)

func _on_enemy_killed(enemy_inst: EnemyInstance) -> void:
	add_combat_log("[color=#37e0ac]💀 처치: %s를 무력화시켰습니다![/color]" % enemy_inst.data.display_name)
	_spawn_damage_text(enemy_inst, "처치!")
	var nearest = combat_manager.enemy
	_update_hit_info(nearest)
	_update_distance_display(nearest)

func _on_encounter_won() -> void:
	add_combat_log("[color=#37e0ac]🏆 승리: 복도의 모든 위협이 소멸되었습니다![/color]")
	parent_scene.handle_combat_finished(true)

func _on_player_died() -> void:
	add_combat_log("[color=#ff4242]🚨 사망: 생사선이 뚫려 플레이어가 무력화되었습니다.[/color]")
	parent_scene.handle_combat_finished(false)

# ── 헬퍼 메서드 ──

func add_combat_log(text: String) -> void:
	if _shot_log_label:
		_shot_log_label.text = text

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
	var local_pos = _floating_layer.to_local(global_pos)
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
func _build_result_overlay() -> void: pass
func request_insert_bullet(bullet: BulletData) -> void:
	if _loaded_bullets.size() < 6:
		_loaded_bullets.append(bullet)
		_update_cylinder_visuals()
		_update_action_buttons()
