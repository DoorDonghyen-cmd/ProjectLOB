class_name BulletGalleryOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 탄환 이미지 갤러리 오버레이 (15종 총알 리소스 한눈에 보기)
## ═══════════════════════════════════════════════════

var parent_scene: Control

const C_BG_CHARCOAL := Color(0.06, 0.06, 0.08, 0.98)
const C_NEON_GOLD := Color(0.83, 0.69, 0.22, 1.0)
const C_NEON_GOLD_DIM := Color(0.83, 0.69, 0.22, 0.2)
const C_PANEL_BG := Color(0.12, 0.12, 0.16, 1.0)

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
	
	var title_lbl = parent_scene.make_label("🔴 TACTICAL BULLET GALLERY", 18, parent_scene.C_DANGER)
	header_hbox.add_child(title_lbl)
	
	var scan_line = ColorRect.new()
	scan_line.color = C_NEON_GOLD_DIM
	scan_line.custom_minimum_size = Vector2(0, 2)
	scan_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(scan_line)
	
	# 로비로 돌아가는 뒤로가기 버튼
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
	
	# 5열 그리드로 카드들을 배치
	_grid_container = GridContainer.new()
	_grid_container.columns = 5
	_grid_container.add_theme_constant_override("h_separation", 16)
	_grid_container.add_theme_constant_override("v_separation", 16)
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_grid_container)


## 갤러리 열기 및 총알 카드 리로드
func open_gallery() -> void:
	visible = true
	
	# 기존 차일드 클리어
	for child in _grid_container.get_children():
		child.queue_free()
		
	# resources/bullets/ 에서 모든 .tres 파일 로드
	var bullet_datas: Array[BulletData] = []
	var path = "res://resources/bullets/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(path + file_name)
				if res is BulletData:
					bullet_datas.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()
		
	# 이름순 정렬
	bullet_datas.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	# 그리드 내부 카드 렌더링
	for b_data in bullet_datas:
		var cell_panel := PanelContainer.new()
		cell_panel.custom_minimum_size = Vector2(170, 100)
		_apply_panel_style(cell_panel, C_PANEL_BG, Color(0.25, 0.25, 0.3))
		_grid_container.add_child(cell_panel)
		
		var cell_margin := MarginContainer.new()
		cell_margin.add_theme_constant_override("margin_left", 8)
		cell_margin.add_theme_constant_override("margin_right", 8)
		cell_margin.add_theme_constant_override("margin_top", 6)
		cell_margin.add_theme_constant_override("margin_bottom", 6)
		cell_panel.add_child(cell_margin)
		
		var cell_hbox := HBoxContainer.new()
		cell_hbox.add_theme_constant_override("separation", 10)
		cell_margin.add_child(cell_hbox)
		
		# 1) 좌측: 48x64 규격 드래그 카드 인스턴스 (비주얼 검증용)
		var drag_card = DragCard.new()
		drag_card.initialize(b_data, null, 1)
		drag_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell_hbox.add_child(drag_card)
		
		# 2) 우측: 세부 정보 텍스트 (이름, 스탯, 전술 효과)
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cell_hbox.add_child(info_vbox)
		
		var name_lbl = parent_scene.make_label(b_data.display_name, 11, C_NEON_GOLD)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(name_lbl)
		
		var stat_lbl = parent_scene.make_label("DMG:%d ACC:%d PEN:%d" % [b_data.damage, b_data.accuracy, b_data.penetration], 8, parent_scene.C_TEXT)
		info_vbox.add_child(stat_lbl)
		
		# 구경 규격 문자열
		var cal_name = ""
		match b_data.caliber:
			Enums.Caliber.CAL_9MM: cal_name = "9mm"
			Enums.Caliber.CAL_556: cal_name = "5.56"
			Enums.Caliber.CAL_762: cal_name = "7.62"
		var caliber_lbl = parent_scene.make_label("구경: %s / KB:%d / S:%d" % [cal_name, b_data.knockback, b_data.slow], 8, parent_scene.C_DIM)
		info_vbox.add_child(caliber_lbl)
		
		if b_data.effect_type != Enums.BulletEffect.NONE:
			var eff_name = ""
			match b_data.effect_type:
				Enums.BulletEffect.ARMOR_SHRED: eff_name = "장갑 파쇄"
				Enums.BulletEffect.COMBO: eff_name = "콤보 사격"
				Enums.BulletEffect.LAST_SHOT: eff_name = "막탄 강화"
				Enums.BulletEffect.OPENING_SHOT: eff_name = "선제 사격"
				Enums.BulletEffect.CALIBER_DIFF: eff_name = "구경 교차"
				Enums.BulletEffect.PIERCE: eff_name = "관통 다중"
			var eff_lbl = parent_scene.make_label("★ %s (%d)" % [eff_name, b_data.effect_value], 8, Color(0.3, 0.9, 0.5))
			info_vbox.add_child(eff_lbl)


func _on_close_pressed() -> void:
	visible = false
	parent_scene.handle_gallery_closed()


func _apply_panel_style(panel: PanelContainer, bg: Color, border: Color) -> void:
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
