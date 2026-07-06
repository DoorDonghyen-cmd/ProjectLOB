class_name BagInventoryDrawer
extends PanelContainer

## ═══════════════════════════════════════════════════
## 인벤토리 드로어 UI 컴포넌트 (가방/버림/소멸/소모품 탭 렌더링)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager
var combat_manager: CombatManager
var overlay: Control # 최상위 CombatOverlayV2 참조

var _drawer_tab_item: Button
var _drawer_tab_ammo: Button
var _drawer_tab_discard: Button
var _drawer_tab_exile: Button
var _active_drawer_tab: int = 0 # 0:가방, 1:버림, 2:소멸, 3:소모품
var _drawer_body_item: Control
var _drawer_body_ammo: Control
var _drawer_inventory_grid: HFlowContainer
var _drawer_item_grid: HFlowContainer
var _drawer_stack_vbox: VBoxContainer
var _drawer_stack_cap: Label
var _drawer_undo_btn: Button
var _drawer_confirm_btn: Button

func initialize(p_scene: Control, rm: RunManager, cm: CombatManager, overlay_v2: Control) -> void:
	parent_scene = p_scene
	run_manager = rm
	combat_manager = cm
	overlay = overlay_v2
	
	var drawer_style := StyleBoxFlat.new()
	drawer_style.bg_color = Color(0.05, 0.07, 0.11, 0.96)
	drawer_style.border_width_top = 2
	drawer_style.border_width_left = 2
	drawer_style.border_width_right = 2
	drawer_style.border_color = parent_scene.C_SUCCESS
	add_theme_stylebox_override("panel", drawer_style)
	
	if get_child_count() == 0:
		_build_ui()
	toggle_drawer(false)

func _build_ui() -> void:
	custom_minimum_size = Vector2(700, 390)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	var drawer_vbox := VBoxContainer.new()
	drawer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(drawer_vbox)
	
	# 탭 바
	var tab_hbox := HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 0)
	drawer_vbox.add_child(tab_hbox)
	
	_drawer_tab_ammo = Button.new()
	_drawer_tab_ammo.text = "가방"
	_drawer_tab_ammo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_tab_ammo.focus_mode = Control.FOCUS_NONE
	_drawer_tab_ammo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drawer_tab_ammo.pressed.connect(func(): _switch_drawer_tab_idx(0))
	tab_hbox.add_child(_drawer_tab_ammo)

	_drawer_tab_discard = Button.new()
	_drawer_tab_discard.text = "버림"
	_drawer_tab_discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_tab_discard.focus_mode = Control.FOCUS_NONE
	_drawer_tab_discard.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drawer_tab_discard.pressed.connect(func(): _switch_drawer_tab_idx(1))
	tab_hbox.add_child(_drawer_tab_discard)

	_drawer_tab_exile = Button.new()
	_drawer_tab_exile.text = "소멸"
	_drawer_tab_exile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_tab_exile.focus_mode = Control.FOCUS_NONE
	_drawer_tab_exile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drawer_tab_exile.pressed.connect(func(): _switch_drawer_tab_idx(2))
	tab_hbox.add_child(_drawer_tab_exile)
	
	_drawer_tab_item = Button.new()
	_drawer_tab_item.text = "소모품"
	_drawer_tab_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_tab_item.focus_mode = Control.FOCUS_NONE
	_drawer_tab_item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drawer_tab_item.pressed.connect(func(): _switch_drawer_tab_idx(3))
	tab_hbox.add_child(_drawer_tab_item)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(func(): toggle_drawer(false))
	
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color.TRANSPARENT
	close_style.border_width_bottom = 1
	close_style.border_color = Color(0.13, 0.18, 0.24)
	close_style.content_margin_left = 16
	close_style.content_margin_right = 16
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_stylebox_override("hover", close_style)
	close_btn.add_theme_stylebox_override("pressed", close_style)
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.add_theme_color_override("font_color", parent_scene.C_DIM)
	tab_hbox.add_child(close_btn)
	
	# 초기 탭 스타일 적용
	_apply_tab_style(_drawer_tab_ammo, true)
	_apply_tab_style(_drawer_tab_discard, false)
	_apply_tab_style(_drawer_tab_exile, false)
	_apply_tab_style(_drawer_tab_item, false)
	
	# 본문 마진
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 16)
	body_margin.add_theme_constant_override("margin_right", 16)
	body_margin.add_theme_constant_override("margin_top", 8)
	body_margin.add_theme_constant_override("margin_bottom", 8)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_vbox.add_child(body_margin)
	
	var drawer_main_hbox := HBoxContainer.new()
	drawer_main_hbox.add_theme_constant_override("separation", 16)
	drawer_main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_child(drawer_main_hbox)
	
	# 좌측 세로 스택
	var drawer_stackcol := VBoxContainer.new()
	drawer_stackcol.custom_minimum_size = Vector2(200, 0)
	drawer_stackcol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_main_hbox.add_child(drawer_stackcol)
	
	var d_stack_h := HBoxContainer.new()
	drawer_stackcol.add_child(d_stack_h)
	
	var d_stack_t: Label = parent_scene.make_label("▲ 탄창 상태", 11, parent_scene.C_DIM)
	d_stack_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_stack_h.add_child(d_stack_t)
	
	_drawer_stack_cap = parent_scene.make_label("0/0", 12, parent_scene.C_SUCCESS)
	d_stack_h.add_child(_drawer_stack_cap)
	
	_drawer_stack_vbox = VBoxContainer.new()
	_drawer_stack_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer_stack_vbox.add_theme_constant_override("separation", 4)
	drawer_stackcol.add_child(_drawer_stack_vbox)
	
	# 우측 본문 VBox
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_main_hbox.add_child(right_vbox)
	
	# 소모품 스크롤
	var item_scroll := ScrollContainer.new()
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(item_scroll)
	_drawer_body_item = item_scroll
	
	_drawer_item_grid = HFlowContainer.new()
	_drawer_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_item_grid.add_theme_constant_override("h_separation", 8)
	_drawer_item_grid.add_theme_constant_override("v_separation", 8)
	item_scroll.add_child(_drawer_item_grid)
	
	var c_item1 := _create_consumable_card("✚ 응급 키트", "HP 회복", func():
		overlay.add_combat_log("[color=#37e0ac]💊 소모품 즉발 사용: 응급 키트 효과가 격발되었습니다.[/color]")
		toggle_drawer(false)
	)
	_drawer_item_grid.add_child(c_item1)
	
	var c_item2 := _create_consumable_card("◆ 파쇄액", "타겟 DEF −", func():
		overlay.add_combat_log("[color=#37e0ac]💊 소모품 즉발 사용: 파쇄액 효과가 격발되었습니다.[/color]")
		toggle_drawer(false)
	)
	_drawer_item_grid.add_child(c_item2)
	
	var c_item3 := _create_consumable_card("≈ 둔화 지뢰", "HP 둔화 장치", func():
		overlay.add_combat_log("[color=#37e0ac]💊 소모품 즉발 사용: 둔화 지뢰 효과가 격발되었습니다.[/color]")
		toggle_drawer(false)
	)
	_drawer_item_grid.add_child(c_item3)
	
	# 탄환 그리드 스크롤
	var drawer_scroll := ScrollContainer.new()
	drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer_scroll.visible = false
	right_vbox.add_child(drawer_scroll)
	_drawer_body_ammo = drawer_scroll
	
	_drawer_inventory_grid = HFlowContainer.new()
	_drawer_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_inventory_grid.add_theme_constant_override("h_separation", 8)
	_drawer_inventory_grid.add_theme_constant_override("v_separation", 8)
	drawer_scroll.add_child(_drawer_inventory_grid)
	
	# 하단 버튼
	var drawer_actions := HBoxContainer.new()
	drawer_actions.add_theme_constant_override("separation", 10)
	right_vbox.add_child(drawer_actions)
	
	_drawer_undo_btn = parent_scene.make_button("납탄 (맨 위 제거)", func(): _on_drawer_undo_pressed(), parent_scene.C_WARNING)
	_drawer_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_actions.add_child(_drawer_undo_btn)
	
	_drawer_confirm_btn = parent_scene.make_button("장전 완료 ▸", func(): _on_drawer_confirm_pressed(), parent_scene.C_SUCCESS)
	_drawer_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_actions.add_child(_drawer_confirm_btn)
	
	_switch_drawer_tab_idx(0)

func toggle_drawer(expand: bool) -> void:
	overlay._is_bag_expanded = expand
	visible = expand
	
	var overlay_w = overlay.size.x if overlay.size.x > 100 else get_viewport_rect().size.x
	var overlay_h = overlay.size.y if overlay.size.y > 100 else get_viewport_rect().size.y
	
	var target_x = (overlay_w - 700) / 2.0 if overlay_w > 700 else 24.0
	if expand:
		size = Vector2(700, 390)
		position = Vector2(target_x, overlay_h - 390 - 48)
		refresh_ammo_drawer()
	else:
		position = Vector2(target_x, overlay_h)

func _switch_drawer_tab_idx(tab_idx: int) -> void:
	_active_drawer_tab = tab_idx
	_apply_tab_style(_drawer_tab_ammo, tab_idx == 0)
	_apply_tab_style(_drawer_tab_discard, tab_idx == 1)
	_apply_tab_style(_drawer_tab_exile, tab_idx == 2)
	_apply_tab_style(_drawer_tab_item, tab_idx == 3)
	
	_drawer_body_item.visible = (tab_idx == 3)
	_drawer_body_ammo.visible = (tab_idx != 3)
	
	refresh_ammo_drawer()

func refresh_ammo_drawer() -> void:
	_refresh_drawer_stack()
	if not is_instance_valid(_drawer_inventory_grid):
		return
		
	for child in _drawer_inventory_grid.get_children():
		child.queue_free()
		
	var can_insert := false
	if combat_manager:
		can_insert = (combat_manager.state == CombatManager.State.LOADING 
			or combat_manager.state == CombatManager.State.PLAYER_TURN)
	else:
		can_insert = true
		
	var render_source: Dictionary = {}
	var is_interactive := false
	var empty_text := "🎒 가방에 남은 탄환이 없습니다."
	
	if _active_drawer_tab == 0:
		render_source = overlay._bullet_pool
		is_interactive = can_insert
		empty_text = "🎒 가방에 남은 탄환이 없습니다."
	elif _active_drawer_tab == 1:
		var list = combat_manager.discard_pile if combat_manager else []
		for b in list:
			render_source[b] = render_source.get(b, 0) + 1
		empty_text = "♻ 버린 더미에 탄환이 없습니다."
	elif _active_drawer_tab == 2:
		var list = combat_manager.exile_pile if combat_manager else []
		for b in list:
			render_source[b] = render_source.get(b, 0) + 1
		empty_text = "💀 소멸된 탄환이 없습니다."
		
	var has_any_bullet := false
	for bullet: BulletData in render_source:
		var count: int = render_source[bullet]
		if count <= 0:
			continue
		has_any_bullet = true
		
		var card: Control
		if is_interactive:
			card = _create_inventory_card(bullet, count, func():
				overlay.request_insert_bullet(bullet)
			)
		else:
			card = _create_inventory_card(bullet, count, Callable())
			card.modulate = Color(1.0, 1.0, 1.0, 0.45)
			
		_drawer_inventory_grid.add_child(card)
		
	if not has_any_bullet:
		var empty_lbl: Label = parent_scene.make_label(empty_text, 12, parent_scene.C_DIM)
		_drawer_inventory_grid.add_child(empty_lbl)
		
	if is_instance_valid(_drawer_undo_btn):
		if combat_manager and combat_manager.state == CombatManager.State.LOADING:
			_drawer_undo_btn.disabled = overlay._loaded_bullets.is_empty()
		else:
			_drawer_undo_btn.disabled = true
			
	if is_instance_valid(_drawer_confirm_btn):
		if combat_manager and combat_manager.state == CombatManager.State.LOADING:
			_drawer_confirm_btn.text = "장전 완료 ▸"
			_drawer_confirm_btn.disabled = overlay._loaded_bullets.is_empty()
		else:
			_drawer_confirm_btn.text = "가방 닫기 ✕"
			_drawer_confirm_btn.disabled = false

func _refresh_drawer_stack() -> void:
	if not is_instance_valid(_drawer_stack_vbox): return
	for child in _drawer_stack_vbox.get_children():
		_drawer_stack_vbox.remove_child(child)
		child.queue_free()
		
	var bullets: Array[BulletData] = []
	var max_cap: int = 5
	
	if combat_manager and combat_manager.gun:
		max_cap = combat_manager.gun.magazine_capacity + (1 if combat_manager.gun.has_chamber else 0)
		if combat_manager.state == CombatManager.State.LOADING:
			bullets = overlay._loaded_bullets
		else:
			bullets = combat_manager.magazine.get_loaded_bullets()
			
	var loaded := bullets.size()
	_drawer_stack_vbox.custom_minimum_size.y = max_cap * 52 + (max_cap - 1) * 4
	if is_instance_valid(_drawer_stack_cap):
		_drawer_stack_cap.text = "%d/%d" % [loaded, max_cap]
		
	for i in range(max_cap - loaded):
		var slot := _create_stack_slot(null, -1, 200.0)
		_drawer_stack_vbox.add_child(slot)
		
	for i in range(loaded - 1, -1, -1):
		var pos: int = (loaded - 1) - i
		var slot := _create_stack_slot(bullets[i], pos, 200.0)
		_drawer_stack_vbox.add_child(slot)
		
		if overlay._animate_last_insert and pos == 0:
			slot.custom_minimum_size.y = 0
			var tw := create_tween()
			tw.tween_property(slot, "custom_minimum_size:y", 52.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			slot.modulate.a = 0.0
			var tw_fade := create_tween()
			tw_fade.tween_property(slot, "modulate:a", 1.0, 0.15)
			
	overlay._animate_last_insert = false

func _create_stack_slot(bullet: BulletData, pos: int, width: float = 180.0) -> Control:
	return overlay._create_stack_slot(bullet, pos, width)

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
	
	var icon_tex = overlay._get_bullet_icon(bullet)
	if icon_tex:
		var bg_icon := TextureRect.new()
		bg_icon.texture = icon_tex
		bg_icon.custom_minimum_size = Vector2(32, 32)
		bg_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_icon.modulate = Color(1, 1, 1, 0.45)
		bg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg_icon)
		
		bg_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		bg_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		bg_icon.grow_vertical = Control.GROW_DIRECTION_BEGIN
		bg_icon.position = Vector2(82 - 32 - 6, 70 - 32 - 6)
		
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
		
	var st_str1 := "DMG %d  ACC %d" % [bullet.damage, bullet.accuracy]
	var st_str2 := "PEN %d  KB %d  SL %d" % [bullet.penetration, bullet.knockback, bullet.slow]
	
	var cal_color = parent_scene.C_WARNING if bullet.penetration > 0 else Color.WHITE
	var cal_lbl: Label = parent_scene.make_label(caliber_str, 12, cal_color)
	vbox.add_child(cal_lbl)
	
	var st_lbl1: Label = parent_scene.make_label(st_str1, 9.5, Color.WHITE)
	st_lbl1.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	st_lbl1.add_theme_constant_override("outline_size", 3)
	vbox.add_child(st_lbl1)
	
	var st_lbl2: Label = parent_scene.make_label(st_str2, 8.5, parent_scene.C_DIM)
	st_lbl2.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.11))
	st_lbl2.add_theme_constant_override("outline_size", 3)
	vbox.add_child(st_lbl2)
	
	var count_lbl: Label = parent_scene.make_label("%s ×%d" % [type_name, count], 9.5, parent_scene.C_DIM)
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

func _apply_tab_style(btn: Button, is_active: bool) -> void:
	if not is_instance_valid(btn): return
	
	var style := StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.09, 0.13, 0.18)
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
	overlay._on_drawer_undo_pressed()

func _on_drawer_confirm_pressed() -> void:
	overlay._on_drawer_confirm_pressed()
