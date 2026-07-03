class_name CombatOverlayV2
extends VBoxContainer

## ═══════════════════════════════════════════════════
## 🧠 L.O.B 전투 UI V2 데모 오버레이 (목업 기반 설계)
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

# ── UI 참조 (좌측 기둥) ──
var _hit_info_panel: PanelContainer
var _hit_info_label: RichTextLabel
var _left_magazine_panel: VBoxContainer
var _mag_tube_container: VBoxContainer
var _magazine_label: Label
var _magazine_slots_label: Label
var _agent_sprite: TextureRect

# ── UI 참조 (우측 상단 헤더) ──
var _lifeline_panel: PanelContainer
var _distance_label: Label
var _distance_sub_label: Label
var _enemy_info_panel: PanelContainer
var _enemy_name_label: Label
var _enemy_hp_label: Label
var _enemy_hp_bar: ProgressBar
var _enemy_stats_label: Label

# ── UI 참조 (중간 전장 트랙 & 로그) ──
var _ingame_area: Control
var _track_line: ColorRect
var _log_text: RichTextLabel

# ── UI 참조 (하단 버튼 바) ──
var _action_row: HBoxContainer
var _unload_btn: Button
var _reload_btn: Button
var _double_tap_btn: Button
var _eject_btn: Button
var _fire_btn: Button
var _confirm_btn: Button # 대용화되어 사용되진 않으나 호환성 유지

# ── 가방 서랍 오버레이 ──
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
	# 부모 뷰포트 가득 채우기 강제
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
		
	add_theme_constant_override("separation", 0)
	
	# 메인 가로 분할
	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 12)
	add_child(main_hbox)
	
	# ════ 1. 좌측 기둥 (Left Column) ════
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(240, 520)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	main_hbox.add_child(left_vbox)
	
	# (1-A) 명중 분석 패널 (이주 완료)
	_hit_info_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	_hit_info_panel.custom_minimum_size = Vector2(0, 120)
	_hit_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(_hit_info_panel, parent_scene.C_ACCENT)
	left_vbox.add_child(_hit_info_panel)
	
	var hit_margin := MarginContainer.new()
	hit_margin.add_theme_constant_override("margin_left", 10)
	hit_margin.add_theme_constant_override("margin_right", 10)
	hit_margin.add_theme_constant_override("margin_top", 8)
	hit_margin.add_theme_constant_override("margin_bottom", 8)
	_hit_info_panel.add_child(hit_margin)
	
	var hit_vbox := VBoxContainer.new()
	hit_margin.add_child(hit_vbox)
	
	var hit_title := parent_scene.make_label("◎ 다음 격발 분석 (최근접)", 11, parent_scene.C_SUCCESS)
	hit_vbox.add_child(hit_title)
	
	_hit_info_label = RichTextLabel.new()
	_hit_info_label.bbcode_enabled = true
	_hit_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hit_info_label.add_theme_font_size_override("normal_font_size", 12)
	_hit_info_label.text = "대기 중..."
	hit_vbox.add_child(_hit_info_label)
	
	# (1-B) 세로 예고창 패널
	_left_magazine_panel = VBoxContainer.new()
	_left_magazine_panel.custom_minimum_size = Vector2(0, 220)
	_left_magazine_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_magazine_panel.add_theme_constant_override("separation", 4)
	left_vbox.add_child(_left_magazine_panel)
	
	var tube_panel := PanelContainer.new()
	tube_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_magazine_panel.add_child(tube_panel)
	
	var tube_margin := MarginContainer.new()
	tube_margin.add_theme_constant_override("margin_left", 6)
	tube_margin.add_theme_constant_override("margin_right", 6)
	tube_margin.add_theme_constant_override("margin_top", 4)
	tube_margin.add_theme_constant_override("margin_bottom", 4)
	tube_panel.add_child(tube_margin)
	
	_mag_tube_container = VBoxContainer.new()
	_mag_tube_container.alignment = BoxContainer.ALIGNMENT_END
	_mag_tube_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mag_tube_container.add_theme_constant_override("separation", 6) # 세로 스택 간격
	tube_margin.add_child(_mag_tube_container)
	
	_magazine_slots_label = parent_scene.make_label("", 11, parent_scene.C_DIM)
	_magazine_slots_label.visible = false
	_mag_tube_container.add_child(_magazine_slots_label)
	
	_magazine_label = parent_scene.make_label("탄창 (0/6)", 13, parent_scene.C_WARNING)
	_magazine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_magazine_panel.add_child(_magazine_label)
	
	# (1-C) 요원 캐릭터 스프라이트
	_agent_sprite = TextureRect.new()
	_agent_sprite.custom_minimum_size = Vector2(0, 110)
	_agent_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_agent_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_agent_sprite.texture = load("res://assets/sprites/agent_sheet.png")
	if _agent_sprite.texture:
		var atlas := AtlasTexture.new()
		atlas.atlas = _agent_sprite.texture
		atlas.region = Rect2(0, 0, 278, 278)
		_agent_sprite.texture = atlas
	left_vbox.add_child(_agent_sprite)
	
	# ════ 2. 우측 전술 판 (Right Column) ════
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	main_hbox.add_child(right_vbox)
	
	# (2-A) 상단 헤더 top_hbox
	var top_hbox := HBoxContainer.new()
	top_hbox.custom_minimum_size = Vector2(0, 110)
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(top_hbox)
	
	# 중앙 생사선 (Lifeline)
	_lifeline_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	_lifeline_panel.custom_minimum_size = Vector2(240, 110)
	_lifeline_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(_lifeline_panel, parent_scene.C_WARNING)
	top_hbox.add_child(_lifeline_panel)
	
	var life_vbox := VBoxContainer.new()
	life_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_lifeline_panel.add_child(life_vbox)
	
	var life_lbl := parent_scene.make_label("최근접 적 거리 (생사선)", 11, parent_scene.C_DIM)
	life_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	life_vbox.add_child(life_lbl)
	
	_distance_label = parent_scene.make_label("12 m", 38, parent_scene.C_WARNING)
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	life_vbox.add_child(_distance_label)
	
	_distance_sub_label = parent_scene.make_label("경계 — 좀비가 다가옵니다", 11, parent_scene.C_DIM)
	_distance_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	life_vbox.add_child(_distance_sub_label)
	
	# 우측 적 정보 분석
	_enemy_info_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	_enemy_info_panel.custom_minimum_size = Vector2(240, 110)
	_enemy_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(_enemy_info_panel, parent_scene.C_DANGER)
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
	
	_enemy_name_label = parent_scene.make_label("?", 16, parent_scene.C_ACCENT)
	enemy_vbox.add_child(_enemy_name_label)
	
	var hp_hbox := HBoxContainer.new()
	hp_hbox.add_theme_constant_override("separation", 8)
	enemy_vbox.add_child(hp_hbox)
	
	var hp_title := parent_scene.make_label("HP", 14, parent_scene.C_DIM)
	hp_hbox.add_child(hp_title)
	
	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.custom_minimum_size = Vector2(0, 14)
	_enemy_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_hp_bar.show_percentage = false
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = parent_scene.C_PANEL_DARK
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = parent_scene.C_HP_BAR
	_enemy_hp_bar.add_theme_stylebox_override("background", hp_style)
	_enemy_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_hbox.add_child(_enemy_hp_bar)
	
	_enemy_hp_label = parent_scene.make_label("0/0", 14, parent_scene.C_TEXT)
	hp_hbox.add_child(_enemy_hp_label)
	
	_enemy_stats_label = parent_scene.make_label("DEF ? | PRES ? | EVA ? | SPD ?", 12, parent_scene.C_DIM)
	enemy_vbox.add_child(_enemy_stats_label)
	
	# (2-B) 전술 수평 트랙 뷰포트 (복도 2D 횡 배치)
	_ingame_area = Control.new()
	_ingame_area.custom_minimum_size = Vector2(0, 220)
	_ingame_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ingame_area.clip_contents = true
	right_vbox.add_child(_ingame_area)
	
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.04, 0.04, 0.06, 1.0)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ingame_area.add_child(bg_rect)
	
	# 수평 트랙 중심선
	_track_line = ColorRect.new()
	_track_line.color = Color(0.18, 0.22, 0.28, 0.6)
	_track_line.custom_minimum_size = Vector2(0, 4)
	_track_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track_line.offset_top = 110
	_track_line.offset_bottom = -106
	_ingame_area.add_child(_track_line)
	
	# (2-C) 사격 로그 텍스트
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 60)
	right_vbox.add_child(log_panel)
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.03, 0.03, 0.04, 0.9)
	log_panel.add_theme_stylebox_override("panel", log_style)
	
	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 12)
	log_margin.add_theme_constant_override("margin_right", 12)
	log_margin.add_theme_constant_override("margin_top", 4)
	log_margin.add_theme_constant_override("margin_bottom", 4)
	log_panel.add_child(log_margin)
	
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.add_theme_font_size_override("normal_font_size", 12)
	_log_text.add_theme_color_override("default_color", parent_scene.C_DIM)
	_log_text.text = "대기 중 — 격발 시 분석 로그가 출력됩니다."
	log_margin.add_child(_log_text)
	
	# (2-D) 하단 버튼 바 _action_row
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 8)
	_action_row.custom_minimum_size = Vector2(0, 56)
	_action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_action_row)
	
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
	
	var bag_btn := parent_scene.make_button("🎒 가방", _on_bag_clicked, parent_scene.C_WARNING)
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
	
	# (3) 🎒 반투명 가방 서랍 오버레이
	_build_drawer_panel()

func _build_drawer_panel() -> void:
	_drawer_panel = PanelContainer.new()
	_drawer_panel.custom_minimum_size = Vector2(0, 240)
	_drawer_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_drawer_panel)
	
	var drawer_style := StyleBoxFlat.new()
	drawer_style.bg_color = Color(0.05, 0.07, 0.11, 0.96) # 반투명 차콜 블루
	drawer_style.border_width_top = 2
	drawer_style.border_color = parent_scene.C_SUCCESS
	_drawer_panel.add_theme_stylebox_override("panel", drawer_style)
	
	# 초기 위치는 화면 밖 하단으로 은폐
	_drawer_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_drawer_panel.position.y = 600
	_drawer_panel.visible = false
	
	var drawer_vbox := VBoxContainer.new()
	_drawer_panel.add_child(drawer_vbox)
	
	# 서랍 헤더 및 탭
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
	
	var close_btn := parent_scene.make_button("✕ 닫기", func(): _toggle_drawer(false), parent_scene.C_DIM)
	head_hbox.add_child(close_btn)
	
	# 서랍 바디 (소모품 리스트)
	_drawer_body_item = VBoxContainer.new()
	_drawer_body_item.add_theme_constant_override("separation", 6)
	drawer_vbox.add_child(_drawer_body_item)
	
	var item1 := _create_drawer_item("✚ 응급 키트", "체력 회복", true)
	_drawer_body_item.add_child(item1)
	
	var item2 := _create_drawer_item("◆ 장갑 파쇄액", "DEF 차감 디버프", true)
	_drawer_body_item.add_child(item2)
	
	var item3 := _create_drawer_item("≈ 둔화 지뢰", "SPD 둔화 장치", true)
	_drawer_body_item.add_child(item3)
	
	# 서랍 바디 (탄환 열람)
	_drawer_body_ammo = VBoxContainer.new()
	_drawer_body_ammo.add_theme_constant_override("separation", 6)
	_drawer_body_ammo.visible = false
	drawer_vbox.add_child(_drawer_body_ammo)
	
	var ammo1 := _create_drawer_item("▮ 9mm 일반탄 x12", "가용 가능", false)
	_drawer_body_ammo.add_child(ammo1)
	var ammo2 := _create_drawer_item("▮ 7.62 관통탄 x4", "가용 가능", false)
	_drawer_body_ammo.add_child(ammo2)
	
	var note_lbl := parent_scene.make_label("🔒 전투 중 탄환 수정 차단 - 삽탄은 준비실/적재 페이즈에서만 가능합니다.", 11, parent_scene.C_DIM)
	_drawer_body_ammo.add_child(note_lbl)

func _create_drawer_item(title: String, desc: String, can_use: bool) -> HBoxContainer:
	var item_hbox := HBoxContainer.new()
	item_hbox.add_theme_constant_override("separation", 12)
	
	var lbl_title := parent_scene.make_label(title, 13, parent_scene.C_TEXT)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_hbox.add_child(lbl_title)
	
	var lbl_desc := parent_scene.make_label(desc, 12, parent_scene.C_DIM)
	item_hbox.add_child(lbl_desc)
	
	if can_use:
		var use_btn := parent_scene.make_button("사용", func():
			add_combat_log("[color=#37e0ac]💊 소모품 즉발 사용: %s 효과가 격발되었습니다.[/color]" % title)
			_toggle_drawer(false)
		, parent_scene.C_SUCCESS)
		item_hbox.add_child(use_btn)
	else:
		var use_btn := parent_scene.make_button("잠금", func(): pass, parent_scene.C_DIM)
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
	_drawer_panel.visible = expand
	if expand:
		_drawer_panel.position.y = size.y - 240
	else:
		_drawer_panel.position.y = size.y

func _on_bag_clicked() -> void:
	_toggle_drawer(not _is_bag_expanded)

# ── 전투 로직 바인딩 및 이벤트 핸들링 (호환성) ──

func start_combat(gun: GunData, enemy_list: Array, cm: CombatManager) -> void:
	combat_manager = cm
	_current_gun_data = gun
	
	# 기존 오프닝 탄환 데이터 및 동기화 바인딩
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
	
	_on_encounter_started(enemy_list)

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
		es.custom_minimum_size = Vector2(80, 80)
		es.pivot_offset = Vector2(40, 40)
		es.mouse_filter = Control.MOUSE_FILTER_STOP
		es.gui_input.connect(func(event): _on_enemy_sprite_gui_input(event, enemy))
		
		# 머리 위 자물쇠 픽토그램 배지 및 타겟 링 바인딩
		_ingame_area.add_child(es)
		_enemy_sprites[enemy] = es
		
		_build_enemy_badge(es, enemy)
		
	_global_max_dist = 12.0
	var max_found := 0
	for e in enemy_list:
		if e.start_distance > max_found:
			max_found = e.start_distance
	if max_found > 0:
		_global_max_dist = float(max_found)
		
	_update_enemy_position_and_scale(null, false)
	
	var nearest = combat_manager.enemy
	if nearest:
		_update_enemy_display(nearest)
		_update_distance_display(nearest)
		_update_hit_info(nearest)
	_update_cylinder_visuals()
	_update_action_buttons()

func _build_enemy_badge(es: TextureRect, enemy: EnemyInstance) -> void:
	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(24, 24)
	badge_panel.position = Vector2(28, -28) # 적 머리 위 중앙 배치
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
	
	var lbl := parent_scene.make_label(txt, 11, Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(lbl)
	
	# 타겟 지시기 (최근접 링)
	var ring := ColorRect.new()
	ring.name = "TargetRing"
	ring.color = Color(0, 0, 0, 0)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		
	var size := _ingame_area.size
	if size.x == 0:
		size = Vector2(500, 220)
		
	var nearest = combat_manager.enemy
	
	for e in _enemy_sprites.keys():
		var es = _enemy_sprites[e]
		if not is_instance_valid(es) or e.is_dead():
			if is_instance_valid(es):
				es.visible = false
			continue
			
		var dist := e.current_distance
		var ratio := float(dist) / _global_max_dist if _global_max_dist > 0 else 0.0
		
		# 수평 트랙 횡 배치 (요원 60px에서 몹 최대거리까지 가로 나열)
		var target_x := lerp(120.0, size.x - 60.0, ratio)
		var target_y := 110.0 - 40.0 # 중앙선에 맞춘 스케일 센터
		
		var target_pos := Vector2(target_x, target_y)
		es.position = target_pos
		es.scale = Vector2(0.8, 0.8)
		
		# 타겟 링 가시성 갱신
		var ring = es.get_node_or_null("RingPanel")
		if ring:
			ring.visible = (e == nearest)

func _update_enemy_display(enemy: EnemyInstance) -> void:
	if not enemy or enemy.is_dead():
		_enemy_name_label.text = "처치 완료 — 대기 중"
		_enemy_hp_bar.value = 0
		_enemy_hp_label.text = "0/0"
		return
		
	_enemy_name_label.text = "%s (%s)" % [enemy.data.display_name, _archetype_name(enemy.data.archetype)]
	_enemy_hp_bar.max_value = enemy.data.max_hp
	_enemy_hp_bar.value = enemy.current_hp
	_enemy_hp_label.text = "%d/%d" % [enemy.current_hp, enemy.data.max_hp]
	
	_update_enemy_stats_display(enemy)
	_update_distance_display(enemy)
	_update_enemy_position_and_scale(enemy, true)

func _update_enemy_stats_display(enemy: EnemyInstance) -> void:
	if parent_scene.is_goggles_enabled():
		_enemy_stats_label.text = "DEF %d | PRES %d | EVA %d | SPD %d" % [
			enemy.current_def, enemy.knockback_resistance,
			enemy.current_evasion, enemy.current_speed,
		]
	else:
		_enemy_stats_label.text = "DEF ? | PRES ? | EVA ? | SPD ?"

func _update_distance_display(enemy: EnemyInstance) -> void:
	if not enemy or enemy.is_dead():
		_distance_label.text = "- m"
		return
		
	var dist := enemy.current_distance
	_distance_label.text = "%d m" % dist
	
	# 생사선 위기/경고/안전 연출 분기
	if dist <= 3:
		_distance_label.add_theme_color_override("font_color", parent_scene.C_DANGER)
		_distance_sub_label.text = "⚠ 즉사 위험! 다음 턴 진입 시 사망합니다!"
		_distance_sub_label.add_theme_color_override("font_color", parent_scene.C_DANGER)
	elif dist <= 6:
		_distance_label.add_theme_color_override("font_color", parent_scene.C_WARNING)
		_distance_sub_label.text = "경고 — 적이 사정거리 안에 들어왔습니다."
		_distance_sub_label.add_theme_color_override("font_color", parent_scene.C_WARNING)
	else:
		_distance_label.add_theme_color_override("font_color", parent_scene.C_SUCCESS)
		_distance_sub_label.text = "경계 — 요원 복도 상황 대기 중"
		_distance_sub_label.add_theme_color_override("font_color", parent_scene.C_DIM)

func _update_cylinder_visuals() -> void:
	for child in _mag_tube_container.get_children():
		if child != _magazine_slots_label:
			_mag_tube_container.remove_child(child)
			child.queue_free()
			
	var bullets: Array[BulletData] = []
	if combat_manager:
		bullets = combat_manager.magazine.get_loaded_bullets()
		
	_magazine_label.text = "탄창 (%d/%d)" % [bullets.size(), 6]
	
	# 예고창 가이드라인: 앞 2발은 선명히, 나머지는 N칸 더 묶어서 덩어리로 표시!
	var size_to_draw := min(bullets.size(), 2)
	for i in range(size_to_draw):
		var bullet := bullets[i]
		var card := parent_scene.make_panel(parent_scene.C_PANEL_DARK)
		card.custom_minimum_size = Vector2(0, 48)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_panel_style(card, _get_bullet_color(bullet))
		
		var card_vbox := VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(card_vbox)
		
		var idx_lbl := parent_scene.make_label("다음 격발" if i == 0 else "그다음", 10, parent_scene.C_SUCCESS if i == 0 else parent_scene.C_DIM)
		idx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(idx_lbl)
		
		var name_lbl := parent_scene.make_label(bullet.display_name, 12, Color.WHITE)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(name_lbl)
		
		_mag_tube_container.add_child(card)
		
	if bullets.size() > 2:
		var bundle := PanelContainer.new()
		bundle.custom_minimum_size = Vector2(0, 40)
		var bundle_style := StyleBoxFlat.new()
		bundle_style.bg_color = Color(0.06, 0.08, 0.12, 0.6)
		bundle_style.border_width_left = 1
		bundle_style.border_width_right = 1
		bundle_style.border_width_top = 1
		bundle_style.border_width_bottom = 1
		bundle_style.border_color = parent_scene.C_DIM
		bundle.add_theme_stylebox_override("panel", bundle_style)
		
		var bundle_lbl := parent_scene.make_label("+ %d칸 더 적재됨" % [bullets.size() - 2], 11, parent_scene.C_DIM)
		bundle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bundle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bundle.add_child(bundle_lbl)
		
		_mag_tube_container.add_child(bundle)

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
		
	var can_pierce := DamageCalculator.can_pierce(next_bullet, enemy)
	var hit_status := "[color=#37e0ac]관통 성공 ✓[/color]" if can_pierce else "[color=#ff4242]도탄 경고 ✗ (DEF>=PEN)[/color]"
	
	_hit_info_label.text = "사격탄: %s\n예상명중: %s\n대상타겟: %s" % [
		next_bullet.display_name,
		hit_status,
		enemy.data.display_name
	]

func _update_action_buttons() -> void:
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

func _on_enemy_sprite_gui_input(event: InputEvent, clicked_enemy: EnemyInstance) -> void:
	# 조준 선택 연동
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
	_update_enemy_display(combat_manager.enemy)
	_update_hit_info(combat_manager.enemy)

func _on_enemy_moved(enemy_inst: EnemyInstance, new_distance: int, speed_used: int) -> void:
	add_combat_log("[color=#ffa500]👣 전진: %s가 %d만큼 다가왔습니다. (현재 거리: %d)[/color]" % [
		enemy_inst.data.display_name, speed_used, new_distance
	])
	_update_enemy_position_and_scale(null, true)
	_update_distance_display(combat_manager.enemy)

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
	_update_enemy_display(combat_manager.enemy)

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
	_update_enemy_display(combat_manager.enemy)
	_update_hit_info(combat_manager.enemy)

func _on_encounter_won() -> void:
	add_combat_log("[color=#37e0ac]🏆 승리: 복도의 모든 위협이 소멸되었습니다![/color]")
	parent_scene.handle_combat_finished(true)

func _on_player_died() -> void:
	add_combat_log("[color=#ff4242]🚨 사망: 생사선이 뚫려 플레이어가 무력화되었습니다.[/color]")
	parent_scene.handle_combat_finished(false)

# ── 헬퍼 메서드 ──

func add_combat_log(text: String) -> void:
	if _log_text:
		_log_text.append_text("\n" + text)

func clear_combat_log() -> void:
	if _log_text:
		_log_text.text = ""

func _spawn_damage_text(es_inst: EnemyInstance, text: String) -> void:
	var es = _enemy_sprites.get(es_inst)
	if not is_instance_valid(es): return
	
	var lbl := parent_scene.make_label(text, 20, parent_scene.C_DANGER)
	lbl.position = Vector2(20, -50)
	es.add_child(lbl)
	
	var tween := create_tween()
	tween.tween_property(lbl, "position", Vector2(20, -100), 1.0)
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

func _archetype_name(arch: int) -> String:
	match arch:
		Enums.EnemyArchetype.RUSHER: return "돌격병"
		Enums.EnemyArchetype.TANK: return "방패병"
		Enums.EnemyArchetype.DODGER: return "회피병"
		Enums.EnemyArchetype.SCRAMBLER: return "스펀지"
		_: return "술사"

# 미인용 오버레이 로딩 호환 메서드 상속
func _build_loading_overlay() -> void: pass
func _build_result_overlay() -> void: pass
func request_insert_bullet(bullet: BulletData) -> void:
	# 적재 모드 시 탄환 드래그/삽탄 연동 처리
	if _loaded_bullets.size() < 6:
		_loaded_bullets.append(bullet)
		_update_cylinder_visuals()
		_update_action_buttons()
