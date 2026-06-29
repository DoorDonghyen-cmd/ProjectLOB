class_name MaintenanceOverlay
extends PanelContainer

## ═══════════════════════════════════════════════════
## 정비실 오버레이 (무기 캐비닛, 대피소 등)
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager

var _maint_title_label: Label
var _maint_desc_label: Label
var _maint_buttons_container: VBoxContainer
var _maint_deck_list: VBoxContainer
var _maint_confirm_btn: Button

var _deck_select_callback: Callable = func(idx): pass


func initialize(p_scene: Control, rm: RunManager) -> void:
	parent_scene = p_scene
	run_manager = rm
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	add_theme_stylebox_override("panel", style)
	
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 28)
	margin.add_child(main_hbox)

	# ── 좌측: 액션 및 정보 패널 ──
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 16)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.5
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(left_vbox)

	_maint_title_label = parent_scene.make_label("구역 이름", 32, parent_scene.C_WARNING)
	_maint_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_maint_title_label)

	_maint_desc_label = parent_scene.make_label("상호작용 설명", 18, parent_scene.C_DIM)
	_maint_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_maint_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(_maint_desc_label)

	# 정비 상호작용 버튼 수직 배치 (가로폭이 절반이므로 수직 배치가 어울림!)
	_maint_buttons_container = VBoxContainer.new()
	_maint_buttons_container.add_theme_constant_override("separation", 8)
	left_vbox.add_child(_maint_buttons_container)

	# 여백 확보
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(spacer)

	_maint_confirm_btn = parent_scene.make_button("작전 구역 계속 탐색", _on_maint_confirm_pressed, parent_scene.C_ACCENT)
	_maint_confirm_btn.custom_minimum_size = Vector2(0, 50)
	left_vbox.add_child(_maint_confirm_btn)

	# ── 우측: 덱 리스트 패널 ──
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.5
	main_hbox.add_child(right_vbox)

	right_vbox.add_child(parent_scene.make_label("🗃 보유 전술 탄환 덱 목록", 18, parent_scene.C_DIM))

	var list_panel = parent_scene.make_panel(parent_scene.C_PANEL_DARK)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_top", 12)
	list_margin.add_theme_constant_override("margin_bottom", 12)
	list_panel.add_child(list_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_margin.add_child(scroll)

	_maint_deck_list = VBoxContainer.new()
	_maint_deck_list.add_theme_constant_override("separation", 4)
	_maint_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_maint_deck_list)


func start_maintenance_phase(node: RunManager.RunNode) -> void:
	visible = true
	_maint_title_label.text = node.type_name
	_maint_desc_label.text = node.description
	
	# 3버튼 초기화
	for child in _maint_buttons_container.get_children():
		child.queue_free()
		
	# 덱 리스트 목록 갱신
	_refresh_maintenance_deck_list()
	
	if node.type_name.contains("무기 캐비닛") or node.type_name.contains("보급 캐비닛"):
		# 캐비닛 기능 바인딩
		var btn_up: Button = parent_scene.make_button("장약 보강 (탄환 DMG+1)", func():
			_maint_desc_label.text = "장약 보강할 덱 탄환 카드를 아래 목록에서 클릭하세요."
			_maint_deck_list.visible = true
			_set_deck_list_callback(func(idx):
				run_manager.upgrade_bullet_in_deck(idx, "dmg")
				_maint_desc_label.text = "탄환 장약을 강화했습니다!"
				_refresh_maintenance_deck_list()
			)
		, parent_scene.C_ACCENT)
		_maint_buttons_container.add_child(btn_up)
		
		var btn_pol: Button = parent_scene.make_button("약실 소탕 (리로드면제)", func():
			run_manager.has_chamber_polish = true
			_maint_desc_label.text = "총기 약실 소탕 완료! 다음 전투에서 리로드 1회가 즉시 완료됩니다."
		, parent_scene.C_WARNING)
		_maint_buttons_container.add_child(btn_pol)
		
		var btn_disc: Button = parent_scene.make_button("탄환 폐기 (덱 압축)", func():
			_maint_desc_label.text = "폐기하여 녹여버릴 탄환 카드를 아래 목록에서 선택하세요."
			_maint_deck_list.visible = true
			_set_deck_list_callback(func(idx):
				run_manager.discard_bullet_from_deck(idx)
				_maint_desc_label.text = "탄환 카드를 덱에서 완전히 삭제했습니다."
				_refresh_maintenance_deck_list()
			)
		, parent_scene.C_DANGER)
		_maint_buttons_container.add_child(btn_disc)
		
	elif node.type_name.contains("대피소"):
		# 대피소 기능 바인딩
		var btn_heal: Button = parent_scene.make_button("체력 아머 보급 (HP 버퍼 +1)", func():
			run_manager.hp_buffer = mini(run_manager.hp_buffer + 1, 3)
			_maint_desc_label.text = "의료 키트를 보급하여 HP 버퍼가 회복되었습니다. (현재 버퍼: %d)" % run_manager.hp_buffer
		, parent_scene.C_SUCCESS)
		_maint_buttons_container.add_child(btn_heal)
		
		var btn_rec: Button = parent_scene.make_button("소실 탄환 복구", func():
			var recovered := run_manager.recover_discarded_bullets()
			_maint_desc_label.text = "이전 전투에서 Unload하여 분실했던 탄환 %d발을 무사히 복구했습니다!" % recovered
			_refresh_maintenance_deck_list()
		, parent_scene.C_ACCENT)
		_maint_buttons_container.add_child(btn_rec)
		
	elif node.type_name.contains("보안 통제실"):
		# 이벤트 기능 바인딩
		var btn_hack: Button = parent_scene.make_button("터미널 보안 해킹 개시", func():
			parent_scene.force_goggles_on_title()
			_maint_desc_label.text = "보안 터미널 해킹 완료! [스마트 센서 고글] 렐릭이 강제로 장착되어 적 정보가 투명하게 공개됩니다."
		, parent_scene.C_ACCENT)
		_maint_buttons_container.add_child(btn_hack)


func _refresh_maintenance_deck_list() -> void:
	for child in _maint_deck_list.get_children():
		child.queue_free()
		
	for i in range(run_manager.deck.size()):
		var b := run_manager.deck[i]
		var label_text := "%d. %s  DMG:%d ACC:%d PEN:%d" % [
			i + 1, b.display_name, b.damage, b.accuracy, b.penetration
		]
		if b.knockback > 0: label_text += " KB:%d" % b.knockback
		
		var l: Label = parent_scene.make_label(label_text, 18, parent_scene.C_TEXT)
		_maint_deck_list.add_child(l)


func _set_deck_list_callback(cb: Callable) -> void:
	_deck_select_callback = cb
	# 덱 리스트에 클릭이 가능하도록 버튼으로 다시 렌더링
	for child in _maint_deck_list.get_children():
		child.queue_free()
		
	for i in range(run_manager.deck.size()):
		var b := run_manager.deck[i]
		var btn_text := "%d. %s (선택)" % [i + 1, b.display_name]
		var idx := i # 캡처
		var btn: Button = parent_scene.make_button(btn_text, func(): _deck_select_callback.call(idx), parent_scene.C_PANEL)
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(0, 36)
		_maint_deck_list.add_child(btn)


func _on_maint_confirm_pressed() -> void:
	visible = false
	parent_scene.handle_maintenance_finished()
