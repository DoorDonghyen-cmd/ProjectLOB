class_name MonsterGalleryOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 몬스터 도감 및 이미지 갤러리 오버레이 (9종 몬스터 리소스 한눈에 보기)
## ═══════════════════════════════════════════════════

var parent_scene: Control

const C_BG_CHARCOAL := Color(0.05, 0.05, 0.07, 0.98)
const C_NEON_GOLD := Color(0.83, 0.69, 0.22, 1.0)
const C_NEON_GOLD_DIM := Color(0.83, 0.69, 0.22, 0.2)
const C_PANEL_BG := Color(0.11, 0.11, 0.15, 1.0)
const C_CARD_BORDER := Color(0.22, 0.22, 0.28, 1.0)

var _grid_container: GridContainer


func initialize(p_scene: Control) -> void:
	parent_scene = p_scene
	
	# 풀스크린 앵커링 설정
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(960, 540)
	
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG_CHARCOAL
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = C_NEON_GOLD
	add_theme_stylebox_override("panel", style)
	
	_build_ui()


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
	main_vbox.add_theme_constant_override("separation", 12)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	# ── 헤더 (Header) ──
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_lbl = parent_scene.make_label("👾 TACTICAL MONSTER ILLUSTRATION GALLERY", 18, parent_scene.C_WARNING)
	header_hbox.add_child(title_lbl)
	
	var scan_line = ColorRect.new()
	scan_line.color = C_NEON_GOLD_DIM
	scan_line.custom_minimum_size = Vector2(0, 2)
	scan_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(scan_line)
	
	# 타이틀로 돌아가는 뒤로가기 버튼
	var btn_back = parent_scene.make_button("❌ 닫기 (Close)", _on_close_pressed, C_NEON_GOLD)
	btn_back.custom_minimum_size = Vector2(130, 36)
	btn_back.add_theme_font_size_override("font_size", 12)
	header_hbox.add_child(btn_back)
	
	# 구분선
	var separator = ColorRect.new()
	separator.color = C_NEON_GOLD
	separator.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(separator)

	# ── 스크롤 카드 그리드 컨테이너 ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll)
	
	var scroll_margin := MarginContainer.new()
	scroll_margin.add_theme_constant_override("margin_left", 8)
	scroll_margin.add_theme_constant_override("margin_right", 8)
	scroll_margin.add_theme_constant_override("margin_top", 8)
	scroll_margin.add_theme_constant_override("margin_bottom", 8)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_margin)
	
	# 4열 그리드로 배치
	_grid_container = GridContainer.new()
	_grid_container.columns = 4
	_grid_container.add_theme_constant_override("h_separation", 20)
	_grid_container.add_theme_constant_override("v_separation", 20)
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_grid_container)


## 갤러리 열기 및 몬스터 리소스 동적 로드
func open_gallery() -> void:
	visible = true
	
	# 기존 자식 요소 청소
	for child in _grid_container.get_children():
		child.queue_free()
		
	var enemy_datas: Array[EnemyData] = []
	var path = "res://resources/enemies/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res") or file_name.ends_with(".res.remap"):
					var clean_name = file_name.replace(".remap", "")
					var res = load(path + clean_name)
					if res is EnemyData:
						enemy_datas.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()
		
	# 이름순 정렬
	enemy_datas.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	# 그리드 내부 카드 렌더링
	for e_data in enemy_datas:
		var cell_panel := PanelContainer.new()
		cell_panel.custom_minimum_size = Vector2(210, 310)
		_apply_panel_style(cell_panel, C_PANEL_BG, C_CARD_BORDER)
		_grid_container.add_child(cell_panel)
		
		var cell_margin := MarginContainer.new()
		cell_margin.add_theme_constant_override("margin_left", 12)
		cell_margin.add_theme_constant_override("margin_right", 12)
		cell_margin.add_theme_constant_override("margin_top", 10)
		cell_margin.add_theme_constant_override("margin_bottom", 10)
		cell_panel.add_child(cell_margin)
		
		var cell_vbox := VBoxContainer.new()
		cell_vbox.add_theme_constant_override("separation", 8)
		cell_margin.add_child(cell_vbox)
		
		# 1) 상단: 100x100 크기의 선명한 도트 스프라이트 렌더링 영역
		var sprite_container := CenterContainer.new()
		sprite_container.custom_minimum_size = Vector2(120, 120)
		cell_vbox.add_child(sprite_container)
		
		var sprite_rect := TextureRect.new()
		sprite_rect.custom_minimum_size = Vector2(100, 100)
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # 픽셀 엣지 보존
		
		if e_data.icon:
			sprite_rect.texture = e_data.icon
		sprite_container.add_child(sprite_rect)
		
		# 2) 정보 영역: 이름, 아키타입
		var info_vbox := VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 2)
		cell_vbox.add_child(info_vbox)
		
		var name_lbl = parent_scene.make_label(e_data.display_name, 14, C_NEON_GOLD)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(name_lbl)
		
		var type_name = ""
		match e_data.archetype:
			Enums.EnemyArchetype.RUSHER: type_name = "돌격형 (RUSHER)"
			Enums.EnemyArchetype.TANK: type_name = "중장갑형 (TANK)"
			Enums.EnemyArchetype.DODGER: type_name = "요격회피형 (DODGER)"
			Enums.EnemyArchetype.CASTER: type_name = "원거리술사형 (CASTER)"
		
		var type_lbl = parent_scene.make_label("[%s]" % type_name, 10, parent_scene.C_ACCENT)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(type_lbl)
		
		# 구분 점선용 라벨
		var div_lbl = parent_scene.make_label("-------------------------", 9, parent_scene.C_DIM)
		div_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_vbox.add_child(div_lbl)
		
		# 3) 스탯 정보 리스트
		var stats_vbox := VBoxContainer.new()
		stats_vbox.add_theme_constant_override("separation", 3)
		cell_vbox.add_child(stats_vbox)
		
		var hp_def_lbl = parent_scene.make_label("체력 (HP): %d  /  방어 (DEF): %d" % [e_data.max_hp, e_data.defense], 9, parent_scene.C_TEXT)
		stats_vbox.add_child(hp_def_lbl)
		
		var eva_spd_lbl = parent_scene.make_label("회피 (EVA): %d  /  속도 (SPD): %d" % [e_data.evasion, e_data.speed], 9, parent_scene.C_TEXT)
		stats_vbox.add_child(eva_spd_lbl)
		
		var kb_res_str = str(e_data.knockback_resistance)
		if e_data.knockback_resistance >= 3:
			kb_res_str += " (넉백 면역)"
		var extra_lbl = parent_scene.make_label("시작거리: %dm  /  넉백저항: %s" % [e_data.start_distance, kb_res_str], 9, parent_scene.C_TEXT)
		stats_vbox.add_child(extra_lbl)
		
		# 4) 설명 라벨
		var desc_lbl = parent_scene.make_label(e_data.description, 9, parent_scene.C_DIM)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(0, 48)
		cell_vbox.add_child(desc_lbl)


func _on_close_pressed() -> void:
	visible = false
	parent_scene.handle_monster_gallery_closed()


func _apply_panel_style(panel: PanelContainer, bg: Color, border: Color) -> void:
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
