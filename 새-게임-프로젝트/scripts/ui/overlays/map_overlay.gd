class_name MapOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 계층 상승 지도 오버레이 (층별 단면도 및 통로 선택)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager

var _map_floor_label: Label
var _route_pressure_label: Label
var _map_scroll: ScrollContainer
var _scroll_content: Control
var _floors_vbox: VBoxContainer
var _lines_drawer: Control
var _node_buttons: Dictionary = {}

var _scan_hint_panel: PanelContainer
var _scan_hint_lbl: Label
var _hp_buffer_label: Label


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	# Force the panel overlay to stretch across the full screen
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	custom_minimum_size = Vector2(960, 540)
	
	# 2차 폴리싱: 네온 블루 보더가 가미된 홀로그램 스타일 패널
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.08, 0.96)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.55, 1.0, 0.8) # 네온 블루 테두리
	style.shadow_color = Color(0.0, 0.55, 1.0, 0.15)
	style.shadow_size = 12
	add_theme_stylebox_override("panel", style)
	
	_build_ui()


func _process(_delta: float) -> void:
	if visible and _lines_drawer:
		_lines_drawer.queue_redraw()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	# 맵 상단 헤더 컨테이너
	var map_header_hbox := HBoxContainer.new()
	main_vbox.add_child(map_header_hbox)

	_map_floor_label = parent_scene.make_label("상승 경로 (1층)", 24, parent_scene.C_ACCENT)
	map_header_hbox.add_child(_map_floor_label)

	_route_pressure_label = parent_scene.make_label("", 12, parent_scene.C_WARNING)
	_route_pressure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_header_hbox.add_child(_route_pressure_label)
	
	# HP 아머 다이아몬드 게이지 컨테이너 (HBox 헤더 우측 및 층수 라벨 사이에 배치)
	var hp_hbox := HBoxContainer.new()
	hp_hbox.alignment = BoxContainer.ALIGNMENT_END
	hp_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_hbox.add_theme_constant_override("separation", 6)
	map_header_hbox.add_child(hp_hbox)
	
	var hp_title_lbl: Label = parent_scene.make_label("HP ARMOR", 11, parent_scene.C_DIM)
	hp_hbox.add_child(hp_title_lbl)
	
	_hp_buffer_label = parent_scene.make_label("◆ ◆ ◇", 16, parent_scene.C_DANGER)
	hp_hbox.add_child(_hp_buffer_label)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	hp_hbox.add_child(spacer)
	
	var btn_exit_run: Button = parent_scene.make_button("❌ 작전 포기", _on_exit_run_pressed, parent_scene.C_DANGER)
	btn_exit_run.custom_minimum_size = Vector2(120, 36)
	btn_exit_run.add_theme_font_size_override("font_size", 13)
	hp_hbox.add_child(btn_exit_run)

	var desc: Label = parent_scene.make_label("다음 진입할 구역(방 노드)을 선택하세요.", 15, parent_scene.C_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(desc)

	# Scroll area for vertical building section
	_map_scroll = ScrollContainer.new()
	DragScroll.attach(_map_scroll)  # 버튼 위에서도 끌어서 스크롤
	_map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(_map_scroll)

	# MarginContainer automatically wraps children and scales scroll window size natively
	_scroll_content = MarginContainer.new()
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_scroll.add_child(_scroll_content)

	# 1. Canvas Line Drawer (added first to be in the background)
	_lines_drawer = MapLinesDrawer.new(self)
	_lines_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_content.add_child(_lines_drawer)

	# 2. VBox for Floor Rows
	_floors_vbox = VBoxContainer.new()
	_floors_vbox.add_theme_constant_override("separation", 45) # spacing for connection lines
	_floors_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_floors_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_content.add_child(_floors_vbox)

	# Request line redraw on resize
	_floors_vbox.resized.connect(func():
		_lines_drawer.queue_redraw()
	)

func show_map_screen() -> void:
	visible = true
	# 계층명 · 런 전체 진행도 · 도시 전체 기준 절대 고도(약 3000층 규모의 한 조각임을 전달)
	var sec_info := MapGenerator.section_info(run_manager.current_section)
	var climbed: int = run_manager.total_floors_climbed()
	var run_len: int = run_manager.total_run_length()
	_map_floor_label.text = "%s · 상승 %d/%d · LV.%04d" % [
		sec_info.name,
		climbed,
		run_len,
		MapGenerator.absolute_level(run_manager.current_section, run_manager.current_floor)
	]
	_route_pressure_label.visible = run_manager.pending_combat_distance_modifier < 0
	_route_pressure_label.text = "  ⚠ 환기 압박: 다음 교전 시작 거리 -2m" if _route_pressure_label.visible else ""
	
	# 2차 폴리싱: HP 아머 다이아몬드 HUD 갱신 (예: ◆ ◆ ◇)
	if _hp_buffer_label:
		var hp_text := ""
		for i in range(3): # 최대 3칸 기준 시각화
			if i < run_manager.hp_buffer:
				hp_text += "◆ "
			else:
				hp_text += "◇ "
		_hp_buffer_label.text = hp_text
	
	# Clear previous rows
	for child in _floors_vbox.get_children():
		child.queue_free()
		
	_node_buttons.clear()
	
	# ⚠️ 지도는 **도시 사다리 35층 전체**를 항상 보여준다. 계층 단위로 끊지 않는다.
	#    연속 런에서 계층은 난이도 사다리가 아니라 한 여정의 구간이므로,
	#    지도가 계층마다 리셋되면 "얼마나 남았는가"를 전혀 알 수 없다.
	#    아직 해금되지 않은 계층도 잠금 상태로 그린다 — 목표를 각인시키기 위해서다.
	var total_floors: int = run_manager.full_ladder_length()
	var here: int = run_manager.total_floors_climbed()
	var active_floor_row: Control = null

	# 위층이 위에 오도록 절대 층 번호 내림차순으로 쌓는다.
	for abs_f in range(total_floors, 0, -1):
		var loc: Dictionary = run_manager.resolve_ladder_floor(abs_f)
		if loc.is_empty():
			continue
		var sec: String = str(loc.section)
		var f: int = int(loc.floor)
		var s_info: Dictionary = MapGenerator.section_info(sec)
		var is_section_top: bool = f == int(s_info.floors)
		var is_here: bool = abs_f == here
		var in_run: bool = run_manager.is_section_in_run(sec)

		# 계층이 바뀌는 경계에 헤더를 넣어 여정의 구간을 구분한다.
		if is_section_top:
			_floors_vbox.add_child(_make_section_header(sec, s_info, abs_f, here, in_run))

		var floor_row := HBoxContainer.new()
		floor_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		floor_row.add_theme_constant_override("separation", 24)
		_floors_vbox.add_child(floor_row)

		if is_here:
			active_floor_row = floor_row

		# Floor Indicator Label Panel
		var floor_panel := PanelContainer.new()
		floor_panel.custom_minimum_size = Vector2(80, 50)
		floor_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fp_style := StyleBoxFlat.new()

		# Highlight current floor
		if is_here:
			fp_style.bg_color = parent_scene.C_ACCENT.darkened(0.6)
			fp_style.border_color = parent_scene.C_ACCENT
			fp_style.border_width_bottom = 2
			fp_style.border_width_top = 2
			fp_style.border_width_left = 2
			fp_style.border_width_right = 2
		else:
			fp_style.bg_color = parent_scene.C_PANEL_DARK

		fp_style.corner_radius_bottom_left = 5
		fp_style.corner_radius_bottom_right = 5
		fp_style.corner_radius_top_left = 5
		fp_style.corner_radius_top_right = 5
		floor_panel.add_theme_stylebox_override("panel", fp_style)
		floor_row.add_child(floor_panel)

		# 큰 숫자는 **사다리 전체 기준 절대 층**이다(1..35). 계층 내 층 번호는 작게 병기한다.
		var fp_label: Label = parent_scene.make_label("%d" % abs_f, 18, parent_scene.C_TEXT)
		if is_here:
			fp_label.text = "%d\n%dF" % [abs_f, f]
			fp_label.add_theme_color_override("font_color", parent_scene.C_ACCENT)
		elif not in_run:
			fp_label.text = "%d\n🔒" % abs_f
			fp_label.add_theme_color_override("font_color", Color(0.35, 0.4, 0.48))
		elif is_section_top:
			fp_label.text = "%d\nBOSS" % abs_f
			fp_label.add_theme_color_override("font_color", parent_scene.C_DANGER)
		else:
			fp_label.text = "%d\n%dF" % [abs_f, f]
			fp_label.add_theme_color_override("font_color", parent_scene.C_DIM)
		fp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		floor_panel.add_child(fp_label)

		# Nodes container for this floor
		var nodes_hbox := HBoxContainer.new()
		nodes_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nodes_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		nodes_hbox.add_theme_constant_override("separation", 20)
		floor_row.add_child(nodes_hbox)
		
		# 아직 관문을 돌파하지 않은 계층은 내용 대신 실루엣만 알린다.
		if not in_run:
			nodes_hbox.add_child(_make_locked_slot(is_section_top))
			continue

		# 지금 서 있는 계층만 상호작용 가능하다. 위 계층은 보이되 아직 고를 수 없다.
		var is_current_section: bool = sec == run_manager.current_section
		var nodes := run_manager.nodes_for(sec, f)
		for node in nodes:
			if node.is_hidden:
				continue # 조건부 개방 전 숨김 노드는 렌더링 패스
			var is_reachable: bool = is_current_section and run_manager.is_node_reachable(node.id)
			var route_to_node: String = run_manager.get_route_to_node(node.id) if is_current_section else "stairs"
				
			# Rich button card representing a room
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(240, 80)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			# Card style box overrides
			var normal_style := StyleBoxFlat.new()
			normal_style.corner_radius_bottom_left = 6
			normal_style.corner_radius_bottom_right = 6
			normal_style.corner_radius_top_left = 6
			normal_style.corner_radius_top_right = 6
			
			if is_here and is_reachable:
				normal_style.bg_color = parent_scene.C_PANEL.darkened(0.3)
				
				# 목적지에 붙은 진입 통로 가격을 네온 테두리로 표시
				var border_col: Color = parent_scene.C_ACCENT
				if CampaignContent.is_major_gate_type(node.type_name):
					border_col = parent_scene.C_DANGER
				elif route_to_node == "air_duct":
					border_col = parent_scene.C_WARNING
				else:
					border_col = parent_scene.C_SUCCESS
					
				normal_style.border_color = border_col
				normal_style.border_width_bottom = 2
				normal_style.border_width_top = 2
				normal_style.border_width_left = 2
				normal_style.border_width_right = 2
				
				# 네온 발광(Glow) 효과 모사
				normal_style.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.25)
				normal_style.shadow_size = 6
				
				btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				btn.pressed.connect(func(): _on_node_selected(node))
			else:
				normal_style.bg_color = parent_scene.C_PANEL_DARK
				# 비활성 노드는 차분하고 얇은 전술 외곽선으로 시각 정돈
				normal_style.border_color = Color(0.12, 0.18, 0.26, 0.4)
				normal_style.border_width_bottom = 1
				normal_style.border_width_top = 1
				normal_style.border_width_left = 1
				normal_style.border_width_right = 1
				
				btn.disabled = true
				if abs_f < here:
					btn.modulate = Color(0.4, 0.4, 0.4, 0.6) # 이미 지나온 층
				elif is_current_section:
					btn.modulate = Color(0.7, 0.7, 0.7, 0.8) # 이 계층의 앞으로 갈 층
				else:
					btn.modulate = Color(0.55, 0.6, 0.7, 0.6) # 아직 도달하지 않은 상위 계층
					
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_stylebox_override("disabled", normal_style)
			
			# Hover highlight for active buttons
			if is_here and is_reachable:
				var hover_style := normal_style.duplicate() as StyleBoxFlat
				hover_style.bg_color = parent_scene.C_PANEL
				hover_style.shadow_size = 10 # 호버 시 발광 증폭
				btn.add_theme_stylebox_override("hover", hover_style)
				btn.add_theme_stylebox_override("pressed", hover_style)
			
			# 미지 노드인 경우 마우스 호버 전술 스캔 힌트 연결 (오직 선택 가능한 활성 노드일 때만)
			if is_here and node.type_name.begins_with("???") and node.scan_hint != "":
				btn.mouse_entered.connect(func(): _show_scan_hint(node.scan_hint, btn))
				btn.mouse_exited.connect(func(): _hide_scan_hint())
				
			nodes_hbox.add_child(btn)
			# ⚠️ 노드 ID는 계층마다 재사용된다(침전 1F도 101, 공역 1F도 101).
			#    런 전체를 한 화면에 그리므로 계층을 포함한 복합 키로 구분해야 한다.
			_node_buttons["%s:%d" % [sec, node.id]] = btn
			
			# Content layout inside the card button
			var content_vbox := VBoxContainer.new()
			content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn.add_child(content_vbox)
			
			# Title
			var title_color: Color = parent_scene.C_TEXT
			if node.type_name.contains("전투"):
				title_color = parent_scene.C_ACCENT
			elif CampaignContent.is_major_gate_type(node.type_name):
				title_color = parent_scene.C_DANGER
			elif node.type_name.contains("정비") or node.type_name.contains("완충") or node.type_name.contains("보급"):
				title_color = parent_scene.C_SUCCESS
			elif node.type_name.contains("이벤트") or node.type_name.contains("우회"):
				title_color = parent_scene.C_WARNING
				
			var title_lbl: Label = parent_scene.make_label(node.type_name, 15, title_color)
			title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content_vbox.add_child(title_lbl)
			
			# Description
			var desc_lbl: Label = parent_scene.make_label(node.description, 11, parent_scene.C_DIM)
			desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content_vbox.add_child(desc_lbl)

			if is_here and is_reachable:
				var route_text := "🚶 비상계단 · 비용 없음"
				var route_color: Color = parent_scene.C_SUCCESS
				if route_to_node == "air_duct":
					route_text = "🕳️ 환기구 · 다음 교전 시작 거리 -2m"
					route_color = parent_scene.C_WARNING
				var route_lbl: Label = parent_scene.make_label(route_text, 10, route_color)
				route_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				content_vbox.add_child(route_lbl)
			
	_lines_drawer.queue_redraw()
	
	# 수직 카메라 스크롤 트윈 적용
	if active_floor_row != null:
		await parent_scene.get_tree().process_frame
		# 타겟 스크롤 계산 (뷰포트 중앙에 활성 행이 정렬되도록 보정)
		var target_y = active_floor_row.position.y - (_map_scroll.size.y / 2.0) + (active_floor_row.size.y / 2.0)
		var max_scroll = _map_scroll.get_v_scroll_bar().max_value - _map_scroll.size.y
		target_y = clamp(target_y, 0, max_scroll)
		
		# 트윈 애니메이션
		var tween = parent_scene.create_tween()
		tween.tween_property(_map_scroll, "scroll_vertical", int(target_y), 0.6)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)



## 계층 경계 구분자. 여정의 어느 구간인지와, 이미 지나왔는지를 한 줄로 알린다.
func _make_section_header(sec: String, s_info: Dictionary, top_abs: int, here: int, in_run: bool) -> Control:
	var floors := int(s_info.floors)
	var bottom_abs := top_abs - floors + 1

	var passed: bool = in_run and here > top_abs          # 이 계층을 이미 통과했다
	var current: bool = in_run and here >= bottom_abs and here <= top_abs

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.9) if current else Color(0.04, 0.05, 0.08, 0.7)
	style.border_width_bottom = 2
	style.border_color = parent_scene.C_ACCENT if current else Color(0.15, 0.2, 0.28, 0.8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var col: Color = parent_scene.C_TEXT
	if current:
		col = parent_scene.C_ACCENT
	elif not in_run:
		col = Color(0.35, 0.4, 0.48)
	elif passed:
		col = Color(0.45, 0.5, 0.58)

	hbox.add_child(parent_scene.make_label(str(s_info.icon), 15, col))
	hbox.add_child(parent_scene.make_label(str(s_info.name) if in_run else "미확인 구역", 15, col))
	hbox.add_child(parent_scene.make_label(
		"%d–%d층 · LV.%d~%d" % [
			bottom_abs, top_abs,
			MapGenerator.absolute_level(sec, 1), MapGenerator.absolute_level(sec, floors)
		], 10, parent_scene.C_DIM))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var tag := ""
	if not in_run:
		tag = "🔒 미해금"
	elif passed:
		tag = "돌파함"
	elif current:
		tag = "◀ 현재 구간"
	else:
		tag = "남은 구간"
	hbox.add_child(parent_scene.make_label(tag, 10, col))

	return panel


## 미해금 계층의 노드 자리. 내용은 숨기고 존재만 알린다.
func _make_locked_slot(is_boss_floor: bool) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(240, 60)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.modulate = Color(1, 1, 1, 0.45)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.8)
	style.border_color = Color(0.14, 0.17, 0.22, 0.9)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	slot.add_theme_stylebox_override("panel", style)

	var lbl: Label = parent_scene.make_label(
		"🔒 봉인된 구획" if is_boss_floor else "▨▨▨", 12, Color(0.35, 0.4, 0.48))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(lbl)
	return slot


func _on_node_selected(node: RunManager.RunNode) -> void:
	var route := run_manager.get_route_to_node(node.id)
	visible = false
	parent_scene.handle_route_selected(node, route)


func _on_exit_run_pressed() -> void:
	visible = false
	parent_scene.handle_debrief_confirmed() # 타이틀 화면으로 복귀


func _draw_lines(drawer: Control) -> void:
	if not run_manager or _node_buttons.is_empty():
		return
		
	# 연결선도 사다리 전체(35층)를 대상으로 돈다. 표시 루프와 같은 근거를 써야 어긋나지 않는다.
	# 미해금 계층은 맵이 없어 nodes_for가 비어 있으므로 자연히 건너뛴다.
	var total_floors: int = run_manager.full_ladder_length()
	var here: int = run_manager.total_floors_climbed()
	var inv := drawer.get_global_transform().affine_inverse()

	# 층 구분선
	for abs_f in range(1, total_floors + 1):
		var loc: Dictionary = run_manager.resolve_ladder_floor(abs_f)
		if loc.is_empty():
			continue
		var sum_y := 0.0
		var count := 0
		for n in run_manager.nodes_for(str(loc.section), int(loc.floor)):
			if n.is_hidden:
				continue
			var key := "%s:%d" % [str(loc.section), n.id]
			if _node_buttons.has(key):
				var btn: Button = _node_buttons[key]
				sum_y += (inv * (btn.global_position + btn.size / 2)).y
				count += 1
		if count > 0:
			var avg_y = sum_y / count
			drawer.draw_line(Vector2(0, avg_y), Vector2(drawer.size.x, avg_y), Color(0.2, 0.2, 0.3, 0.15), 1.5)

	# 노드 간 통로선. 연결 정보는 계층 안에서만 존재하므로 같은 계층끼리만 잇는다.
	for abs_f in range(2, total_floors + 1):
		var loc_c: Dictionary = run_manager.resolve_ladder_floor(abs_f)
		var loc_p: Dictionary = run_manager.resolve_ladder_floor(abs_f - 1)
		if loc_c.is_empty() or loc_p.is_empty():
			continue
		var sec: String = str(loc_c.section)
		if sec != str(loc_p.section):
			continue  # 계층 경계 — 헤더가 구간을 구분하므로 선은 잇지 않는다

		var prev_nodes := run_manager.nodes_for(sec, int(loc_p.floor))
		var curr_nodes := run_manager.nodes_for(sec, int(loc_c.floor))
		if prev_nodes.is_empty() or curr_nodes.is_empty():
			continue

		for prev_node in prev_nodes:
			if prev_node.is_hidden:
				continue
			for curr_node in curr_nodes:
				if curr_node.is_hidden:
					continue
				if not prev_node.connected_node_ids.has(curr_node.id):
					continue

				var k_prev := "%s:%d" % [sec, prev_node.id]
				var k_curr := "%s:%d" % [sec, curr_node.id]
				if not (_node_buttons.has(k_prev) and _node_buttons.has(k_curr)):
					continue

				var btn_prev: Button = _node_buttons[k_prev]
				var btn_curr: Button = _node_buttons[k_curr]
				var local_start = inv * (btn_prev.global_position + btn_prev.size / 2)
				var local_end = inv * (btn_curr.global_position + btn_curr.size / 2)

				var route: String = prev_node.connected_node_routes.get(curr_node.id, "stairs")
				var color: Color = parent_scene.C_ACCENT
				match route:
					"stairs": color = parent_scene.C_SUCCESS
					"air_duct": color = parent_scene.C_WARNING

				# 지금 서 있는 층에서 뻗어 나가는 선(= 지금 고를 수 있는 통로)만 선명하게.
				if abs_f - 1 == here:
					color.a = 1.0
				elif abs_f == here:
					color.a = 0.65
				else:
					color.a = 0.25

				drawer.draw_line(local_start, local_end, color, 3.5, true)


func _build_scan_hint_panel() -> void:
	_scan_hint_panel = PanelContainer.new()
	_scan_hint_panel.custom_minimum_size = Vector2(280, 45)
	_scan_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.05, 0.0, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.9, 0.4)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	_scan_hint_panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scan_hint_panel.add_child(margin)
	
	_scan_hint_lbl = parent_scene.make_label("", 11, Color(0.2, 0.9, 0.4))
	_scan_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scan_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scan_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_scan_hint_lbl)
	
	add_child(_scan_hint_panel)
	_scan_hint_panel.visible = false


func _show_scan_hint(hint: String, target_btn: Button) -> void:
	if not _scan_hint_panel:
		_build_scan_hint_panel()
	_scan_hint_lbl.text = hint
	_scan_hint_panel.visible = true
	_scan_hint_panel.size = _scan_hint_panel.custom_minimum_size
	
	var local_pos = target_btn.global_position - global_position
	_scan_hint_panel.position = Vector2(local_pos.x + (target_btn.size.x - _scan_hint_panel.size.x) / 2.0, local_pos.y - 50)


func _hide_scan_hint() -> void:
	if _scan_hint_panel:
		_scan_hint_panel.visible = false



# ── Canvas overlay sub-node definition ──
class MapLinesDrawer:
	extends Control
	
	var map_overlay: MapOverlay
	
	func _init(overlay: MapOverlay) -> void:
		map_overlay = overlay
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		
	func _draw() -> void:
		if map_overlay:
			map_overlay._draw_lines(self)
