class_name MapOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 빌딩 침투 지도 오버레이 (층별 단면도 및 통로 선택)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager

var _map_floor_label: Label
var _map_nodes_container: HBoxContainer
var _map_route_selector: PanelContainer
var _map_route_container: VBoxContainer

var _selected_node: RunManager.RunNode = null


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	add_theme_stylebox_override("panel", style)
	
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 24)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(main_vbox)

	_map_floor_label = parent_scene.make_label("빌딩 침투 지도 (1층)", 32, parent_scene.C_ACCENT)
	_map_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_map_floor_label)

	var desc: Label = parent_scene.make_label("다음 진입할 구역(방 노드)을 선택하세요.", 18, parent_scene.C_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(desc)

	_map_nodes_container = HBoxContainer.new()
	_map_nodes_container.add_theme_constant_override("separation", 16)
	main_vbox.add_child(_map_nodes_container)

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
	
	# 노드 버튼 렌더링
	for child in _map_nodes_container.get_children():
		child.queue_free()
		
	var nodes := run_manager.get_nodes_for_floor(run_manager.current_floor)
	for node in nodes:
		var btn_text := "%s : %s" % [node.type_name, node.description]
		var btn: Button = parent_scene.make_button(btn_text, func(): _on_node_selected(node), parent_scene.C_PANEL)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		_map_nodes_container.add_child(btn)


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
	
	# 부모 씬에 선택된 노드와 경로 정보와 함께 침투 전환 요청
	parent_scene.handle_route_selected(_selected_node, route)
