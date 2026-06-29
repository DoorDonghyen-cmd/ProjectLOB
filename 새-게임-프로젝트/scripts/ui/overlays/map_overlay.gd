class_name MapOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 빌딩 침투 지도 오버레이 (층별 단면도 및 통로 선택)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager

var _map_floor_label: Label
var _map_scroll: ScrollContainer
var _scroll_content: Control
var _floors_vbox: VBoxContainer
var _lines_drawer: Control
var _map_route_selector: PanelContainer
var _map_route_container: VBoxContainer

var _selected_node: RunManager.RunNode = null
var _node_buttons: Dictionary = {}


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
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	add_theme_stylebox_override("panel", style)
	
	_build_ui()


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

	_map_floor_label = parent_scene.make_label("빌딩 침투 지도 (1층)", 28, parent_scene.C_ACCENT)
	_map_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_map_floor_label)

	var desc: Label = parent_scene.make_label("다음 진입할 구역(방 노드)을 선택하세요.", 15, parent_scene.C_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(desc)

	# Scroll area for vertical building section
	_map_scroll = ScrollContainer.new()
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

	# ── 통로 선택 서브 오버레이 ──
	_map_route_selector = PanelContainer.new()
	_map_route_selector.custom_minimum_size = Vector2(380, 240)
	_map_route_selector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_map_route_selector.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_map_route_selector)

	var sel_margin := MarginContainer.new()
	sel_margin.add_theme_constant_override("margin_left", 16)
	sel_margin.add_theme_constant_override("margin_right", 16)
	sel_margin.add_theme_constant_override("margin_top", 16)
	sel_margin.add_theme_constant_override("margin_bottom", 16)
	_map_route_selector.add_child(sel_margin)

	var sel_vbox := VBoxContainer.new()
	sel_vbox.add_theme_constant_override("separation", 12)
	sel_margin.add_child(sel_vbox)

	sel_vbox.add_child(parent_scene.make_label("🚪 침투 경로 기회비용 선택", 20, parent_scene.C_WARNING))
	
	_map_route_container = VBoxContainer.new()
	_map_route_container.add_theme_constant_override("separation", 8)
	sel_vbox.add_child(_map_route_container)

	var cancel_route_btn: Button = parent_scene.make_button("취소", func(): _map_route_selector.visible = false, parent_scene.C_PANEL)
	sel_vbox.add_child(cancel_route_btn)

	_map_route_selector.visible = false


func show_map_screen() -> void:
	visible = true
	_map_floor_label.text = "빌딩 침투 지도 (%d층)" % run_manager.current_floor
	
	# Clear previous rows
	for child in _floors_vbox.get_children():
		child.queue_free()
		
	_node_buttons.clear()
	
	var start_floor = ((run_manager.current_floor - 1) / 5) * 5 + 1
	var end_floor = start_floor + 4
	
	# Loop from end_floor down to start_floor (top-down visual stacking)
	for f in range(end_floor, start_floor - 1, -1):
		var floor_row := HBoxContainer.new()
		floor_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		floor_row.add_theme_constant_override("separation", 24)
		_floors_vbox.add_child(floor_row)
		
		# Floor Indicator Label Panel
		var floor_panel := PanelContainer.new()
		floor_panel.custom_minimum_size = Vector2(80, 50)
		floor_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fp_style := StyleBoxFlat.new()
		
		# Highlight current floor
		if f == run_manager.current_floor:
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
		
		var fp_label: Label = parent_scene.make_label("%dF" % f, 18, parent_scene.C_TEXT)
		if f == run_manager.current_floor:
			fp_label.add_theme_color_override("font_color", parent_scene.C_ACCENT)
		elif f % 5 == 0:
			fp_label.text = "%dF\nBOSS" % f
			fp_label.add_theme_color_override("font_color", parent_scene.C_DANGER)
		else:
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
		
		var nodes := run_manager.get_nodes_for_floor(f)
		for node in nodes:
			# Rich button card representing a room
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(240, 64)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			# Card style box overrides
			var normal_style := StyleBoxFlat.new()
			normal_style.corner_radius_bottom_left = 6
			normal_style.corner_radius_bottom_right = 6
			normal_style.corner_radius_top_left = 6
			normal_style.corner_radius_top_right = 6
			
			if f == run_manager.current_floor:
				normal_style.bg_color = parent_scene.C_PANEL.darkened(0.2)
				normal_style.border_color = parent_scene.C_WARNING if node.type_name.contains("보스") else parent_scene.C_ACCENT
				normal_style.border_width_bottom = 2
				normal_style.border_width_top = 2
				normal_style.border_width_left = 2
				normal_style.border_width_right = 2
				btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				btn.pressed.connect(func(): _on_node_selected(node))
			else:
				normal_style.bg_color = parent_scene.C_PANEL_DARK
				btn.disabled = true
				if f < run_manager.current_floor:
					btn.modulate = Color(0.4, 0.4, 0.4, 0.6) # Past floors
				else:
					btn.modulate = Color(0.7, 0.7, 0.7, 0.8) # Future floors
					
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_stylebox_override("disabled", normal_style)
			
			# Hover highlight for active buttons
			if f == run_manager.current_floor:
				var hover_style := normal_style.duplicate() as StyleBoxFlat
				hover_style.bg_color = parent_scene.C_PANEL
				btn.add_theme_stylebox_override("hover", hover_style)
				btn.add_theme_stylebox_override("pressed", hover_style)
			
			nodes_hbox.add_child(btn)
			_node_buttons[node.id] = btn
			
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
			elif node.type_name.contains("보스"):
				title_color = parent_scene.C_DANGER
			elif node.type_name.contains("정비") or node.type_name.contains("완충"):
				title_color = parent_scene.C_SUCCESS
			elif node.type_name.contains("이벤트"):
				title_color = parent_scene.C_WARNING
				
			var title_lbl: Label = parent_scene.make_label(node.type_name, 15, title_color)
			title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content_vbox.add_child(title_lbl)
			
			# Description
			var desc_lbl: Label = parent_scene.make_label(node.description, 11, parent_scene.C_DIM)
			desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content_vbox.add_child(desc_lbl)
			
	_lines_drawer.queue_redraw()


func _on_node_selected(node: RunManager.RunNode) -> void:
	_selected_node = node
	_map_route_selector.visible = true
	
	# 통로 버튼들
	for child in _map_route_container.get_children():
		child.queue_free()
		
	for route in node.connected_routes:
		var r_name := ""
		var color: Color = parent_scene.C_ACCENT
		match route:
			"stairs":
				r_name = "비상계단 (Stairs) - 무난함"
				color = parent_scene.C_SUCCESS
			"air_duct":
				r_name = "환기구 (Air Duct) - [패널티] 시작 거리 -2"
				color = parent_scene.C_WARNING
			"shaft":
				r_name = "엘리베이터 샤프트 (Shaft) - [위험] 버퍼 소실 or 초근접"
				color = parent_scene.C_DANGER
				
		var b := route
		var btn: Button = parent_scene.make_button(r_name, func(): _on_route_selected(b), color)
		btn.add_theme_font_size_override("font_size", 16)
		_map_route_container.add_child(btn)


func _on_route_selected(route: String) -> void:
	_map_route_selector.visible = false
	visible = false
	parent_scene.handle_route_selected(_selected_node, route)


func _draw_lines(drawer: Control) -> void:
	if not run_manager or _node_buttons.is_empty():
		return
		
	var start_floor = ((run_manager.current_floor - 1) / 5) * 5 + 1
	var end_floor = start_floor + 4
	
	# Loop from start_floor + 1 to end_floor to draw lines from f-1 to f
	for f in range(start_floor + 1, end_floor + 1):
		var prev_nodes = run_manager.get_nodes_for_floor(f - 1)
		var curr_nodes = run_manager.get_nodes_for_floor(f)
		
		if prev_nodes.is_empty() or curr_nodes.is_empty():
			continue
			
		for curr_node in curr_nodes:
			for route in curr_node.connected_routes:
				# Resolve source node on prev floor
				var prev_node: RunManager.RunNode = null
				if prev_nodes.size() == 1:
					prev_node = prev_nodes[0]
				else:
					if route == "stairs":
						prev_node = prev_nodes[0]
					elif route == "air_duct":
						prev_node = prev_nodes[0]
					elif route == "shaft":
						prev_node = prev_nodes[-1]
						
				if not prev_node:
					prev_node = prev_nodes[0]
					
				# Calculate positions
				if _node_buttons.has(prev_node.id) and _node_buttons.has(curr_node.id):
					var btn_prev: Button = _node_buttons[prev_node.id]
					var btn_curr: Button = _node_buttons[curr_node.id]
					
					var start_pos = btn_prev.global_position + btn_prev.size / 2
					var end_pos = btn_curr.global_position + btn_curr.size / 2
					
					var local_start = drawer.get_global_transform().affine_inverse() * start_pos
					var local_end = drawer.get_global_transform().affine_inverse() * end_pos
					
					var color: Color = parent_scene.C_ACCENT
					match route:
						"stairs": color = parent_scene.C_SUCCESS
						"air_duct": color = parent_scene.C_WARNING
						"shaft": color = parent_scene.C_DANGER
						
					# Add transparency depending on floor state
					if f - 1 != run_manager.current_floor and f != run_manager.current_floor:
						color.a = 0.3
					else:
						if f == run_manager.current_floor:
							if route == run_manager.current_route_type:
								color.a = 1.0
							else:
								color.a = 0.15
						else:
							color.a = 0.7
							
					drawer.draw_line(local_start, local_end, color, 3.5, true)



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
