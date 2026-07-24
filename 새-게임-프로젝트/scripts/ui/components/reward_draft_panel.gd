class_name RewardDraftPanel
extends VBoxContainer

## ═══════════════════════════════════════════════════
## 전투 승리 후 탄환 보상 드래프트 선택 UI 컴포넌트
## ═══════════════════════════════════════════════════

var parent_scene: Control
var run_manager: RunManager
var overlay: Control

var _draft_selected: BulletData = null
var _draft_cards_hbox: HBoxContainer
var _draft_confirm_btn: Button
var is_credit_selected: bool = false
var earned_credits: int = 20

var _btn_add: Button
var _btn_swap: Button
var _btn_skip: Button

var _swap_modal: PanelContainer
var _swap_deck_container: VBoxContainer

# 폴백용 기본 탄환 리소스들
var _bullets_basic: BulletData
var _bullets_ap: BulletData
var _bullets_kb: BulletData
var _bullets_heavy: BulletData
var _bullets_slow: BulletData

func initialize(p_scene: Control, rm: RunManager, overlay_v2: Control) -> void:
	parent_scene = p_scene
	run_manager = rm
	overlay = overlay_v2
	
	add_theme_constant_override("separation", 10)
	
	if get_child_count() == 0:
		var draft_title: Label = parent_scene.make_label("탄환 카드 드래프트: 3개 중 1개의 탄환을 덱에 획득하십시오.", 18, parent_scene.C_WARNING)
		draft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(draft_title)
		
		_draft_cards_hbox = HBoxContainer.new()
		_draft_cards_hbox.add_theme_constant_override("separation", 12)
		_draft_cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(_draft_cards_hbox)
		
		# 하단 제어 버튼들 배치
		var btn_hbox := HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", 20)
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(btn_hbox)
		
		_btn_add = parent_scene.make_button("📥 획득 (Add)", _on_btn_add_pressed, parent_scene.C_SUCCESS)
		_btn_add.custom_minimum_size = Vector2(140, 40)
		_btn_add.add_theme_font_size_override("font_size", 13)
		_btn_add.disabled = true
		btn_hbox.add_child(_btn_add)
		
		_btn_swap = parent_scene.make_button("🔄 교체 (Swap)", _on_btn_swap_pressed, parent_scene.C_WARNING)
		_btn_swap.custom_minimum_size = Vector2(140, 40)
		_btn_swap.add_theme_font_size_override("font_size", 13)
		_btn_swap.disabled = true
		btn_hbox.add_child(_btn_swap)
		
		_btn_skip = parent_scene.make_button("⏭ 건너뛰기 (Skip)", _on_btn_skip_pressed, parent_scene.C_PANEL)
		_btn_skip.custom_minimum_size = Vector2(140, 40)
		_btn_skip.add_theme_font_size_override("font_size", 13)
		btn_hbox.add_child(_btn_skip)
		
		# 덱 교체 모달 생성
		_build_swap_modal()

func setup_choices(b_basic: BulletData, b_ap: BulletData, b_kb: BulletData, b_heavy: BulletData, b_slow: BulletData) -> void:
	_bullets_basic = b_basic
	_bullets_ap = b_ap
	_bullets_kb = b_kb
	_bullets_heavy = b_heavy
	_bullets_slow = b_slow

func show_draft(confirm_btn: Button, efficiency: int = 100, grade: String = "B", credits: int = 20) -> void:
	_draft_confirm_btn = confirm_btn
	if is_instance_valid(_draft_confirm_btn):
		_draft_confirm_btn.visible = false # 기존 단일 선택 완료 버튼 은폐
		
	_draft_selected = null
	is_credit_selected = false
	earned_credits = credits
	visible = true
	
	if is_instance_valid(_btn_add): _btn_add.disabled = true
	if is_instance_valid(_btn_swap): _btn_swap.disabled = true
	
	for child in _draft_cards_hbox.get_children():
		_draft_cards_hbox.remove_child(child)
		child.queue_free()
		
	# 무작위 호환 탄환 2개 생성 (방안 B 구성 적용)
	var bullets = _generate_draft_choices()
	for bullet in bullets:
		_draft_cards_hbox.add_child(_make_draft_card(bullet))
		
	# 3번째 카드: 기업 크레딧 카드 추가
	_draft_cards_hbox.add_child(_make_credit_card(earned_credits))

func get_selected_bullet() -> BulletData:
	return _draft_selected

func clear_selected() -> void:
	_draft_selected = null

func _generate_draft_choices() -> Array[BulletData]:
	var pool: Array[BulletData] = []
	var path: String = "res://resources/bullets/"
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.is_empty() and not file_name.ends_with(".import"):
				if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res") or file_name.ends_with(".res.remap"):
					var clean_name: String = file_name.replace(".remap", "")
					var res = load(path + clean_name)
					if res is BulletData:
						pool.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if pool.is_empty():
		pool = [_bullets_basic, _bullets_ap, _bullets_kb, _bullets_heavy, _bullets_slow]
		
	# 기본 2장 + 크레딧 카드 1장 = 선택지 3개.
	# 승천 "마른 보급"은 탄환 선택지를 줄인다(§4 — 탄환 획득 감소).
	# ⚠️ 최소 1장은 남긴다. 0이면 드래프트가 크레딧 강제 선택이 되어 보상 구조가 사라진다.
	var slots: int = maxi(2 + int(RunManager.ascension_effects().draft_slots_delta), 1)

	var result: Array[BulletData] = []
	pool.shuffle()
	for i in range(min(slots, pool.size())):
		result.append(pool[i].duplicate())
	return result

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
	
	var vbox := vbox_layout_init(card)
	
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
		var eff_lbl: Label = parent_scene.make_label(overlay._bullet_effect_name(bullet.effect_type), 12, parent_scene.C_WARNING)
		eff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eff_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(eff_lbl)
		
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_draft_card_selected(bullet, card)
	)
	return card

func vbox_layout_init(card: PanelContainer) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)
	return vbox

func _make_credit_card(credits_amt: int) -> PanelContainer:
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
	
	var vbox := vbox_layout_init(card)
	
	var title_lbl: Label = parent_scene.make_label("💳 기업 크레딧", 15, parent_scene.C_WARNING)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)
	
	var amount_lbl: Label = parent_scene.make_label("+%d Cr" % credits_amt, 18, Color(0.9, 0.8, 0.2))
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(amount_lbl)
	
	var desc_lbl: Label = parent_scene.make_label("표준 배급 자금\n(무기고 구매용)", 11, parent_scene.C_DIM)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)
	
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_credit_card_selected(card)
	)
	return card

func _on_credit_card_selected(selected_card: PanelContainer) -> void:
	_draft_selected = null
	is_credit_selected = true
	if is_instance_valid(_btn_add): _btn_add.disabled = false
	if is_instance_valid(_btn_swap): _btn_swap.disabled = true
		
	_highlight_selected_card(selected_card)

func _on_draft_card_selected(bullet: BulletData, selected_card: PanelContainer) -> void:
	_draft_selected = bullet
	is_credit_selected = false
	if is_instance_valid(_btn_add): _btn_add.disabled = false
	if is_instance_valid(_btn_swap): _btn_swap.disabled = false
		
	_highlight_selected_card(selected_card)

func _highlight_selected_card(selected_card: PanelContainer) -> void:
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

func _build_swap_modal() -> void:
	_swap_modal = PanelContainer.new()
	_swap_modal.custom_minimum_size = Vector2(400, 320)
	_swap_modal.visible = false
	
	# parent_scene(combat_scene)의 자식으로 등록하여 화면 중앙에 플로팅 팝업
	parent_scene.add_child(_swap_modal)
	
	_swap_modal.anchor_left = 0.5
	_swap_modal.anchor_top = 0.5
	_swap_modal.anchor_right = 0.5
	_swap_modal.anchor_bottom = 0.5
	_swap_modal.offset_left = -200
	_swap_modal.offset_top = -160
	_swap_modal.offset_right = 200
	_swap_modal.offset_bottom = 160
	_swap_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_swap_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.98)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = parent_scene.C_ACCENT
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	_swap_modal.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_swap_modal.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var title = parent_scene.make_label("🔄 교체하여 소실시킬 덱 탄환 선택", 16, parent_scene.C_WARNING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	DragScroll.attach(scroll)  # 버튼 위에서도 끌어서 스크롤
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	_swap_deck_container = VBoxContainer.new()
	_swap_deck_container.add_theme_constant_override("separation", 6)
	_swap_deck_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_swap_deck_container)
	
	var close_btn = parent_scene.make_button("취소", func(): _swap_modal.visible = false, parent_scene.C_PANEL)
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.add_theme_font_size_override("font_size", 12)
	vbox.add_child(close_btn)

func _open_deck_swap_popup() -> void:
	if not run_manager or not _swap_deck_container:
		return
		
	for child in _swap_deck_container.get_children():
		child.queue_free()
		
	_swap_modal.visible = true
	
	for i in range(run_manager.deck.size()):
		var bullet = run_manager.deck[i]
		var idx = i
		
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 40)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var style := StyleBoxFlat.new()
		style.bg_color = parent_scene.C_PANEL_DARK
		style.border_width_left = 1; style.border_width_right = 1
		style.border_width_top = 1; style.border_width_bottom = 1
		style.border_color = Color(0.2, 0.2, 0.25)
		style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4; style.corner_radius_bottom_right = 4
		card.add_theme_stylebox_override("panel", style)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		card.add_child(margin)
		
		var hbox := HBoxContainer.new()
		margin.add_child(hbox)
		
		var name_lbl: Label = parent_scene.make_label(bullet.display_name, 12, parent_scene.C_TEXT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var stats_lbl: Label = parent_scene.make_label("DMG %d PEN %d" % [bullet.damage, bullet.penetration], 10, parent_scene.C_DIM)
		hbox.add_child(stats_lbl)
		
		var btn := Button.new()
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		btn.pressed.connect(func():
			_execute_swap_action(idx)
		)
		btn.mouse_entered.connect(func():
			style.bg_color = parent_scene.C_PANEL
			style.border_color = parent_scene.C_ACCENT
		)
		btn.mouse_exited.connect(func():
			style.bg_color = parent_scene.C_PANEL_DARK
			style.border_color = Color(0.2, 0.2, 0.25)
		)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(btn)
		
		_swap_deck_container.add_child(card)

func _on_btn_add_pressed() -> void:
	if is_credit_selected:
		run_manager.credits += earned_credits
		overlay.add_combat_log("[color=#37e0ac]💳 기업 크레딧 보상 획득: +%d Cr (보유 크레딧: %d)[/color]" % [earned_credits, run_manager.credits])
		_finish_draft_flow()
	elif _draft_selected:
		run_manager.add_to_deck(_draft_selected)
		overlay.add_combat_log("[color=#3df5a6]📥 탄환 드래프트 획득: %s[/color]" % _draft_selected.display_name)
		_finish_draft_flow()

func _on_btn_swap_pressed() -> void:
	if _draft_selected:
		_open_deck_swap_popup()

func _on_btn_skip_pressed() -> void:
	run_manager.credits += 10
	overlay.add_combat_log("[color=#37e0ac]💳 건너뛰기 선택: 위로 보조금 +10 Cr 획득 (보유 크레딧: %d)[/color]" % run_manager.credits)
	_finish_draft_flow()

func _execute_swap_action(deck_idx: int) -> void:
	if deck_idx >= 0 and deck_idx < run_manager.deck.size() and _draft_selected:
		var removed = run_manager.deck[deck_idx]
		run_manager.deck.remove_at(deck_idx)
		run_manager.deck.insert(deck_idx, _draft_selected.duplicate())
		overlay.add_combat_log("[color=#ffa500]🔄 탄환 교체 완료: %s ➡️ %s[/color]" % [removed.display_name, _draft_selected.display_name])
		
		_swap_modal.visible = false
		_finish_draft_flow()

func _finish_draft_flow() -> void:
	# 전투 효율 등급에 따른 기본 크레딧을 최종 누적 지급 처리합니다.
	run_manager.credits += earned_credits
	overlay.add_combat_log("[color=#37e0ac]💳 전투 정산 기본 크레딧 지급: +%d Cr (현재 크레딧: %d)[/color]" % [earned_credits, run_manager.credits])

	_draft_selected = null
	clear_selected()
	visible = false
	
	overlay._draft_selected = null
	overlay._loaded_bullets.clear()
	overlay._bullet_pool.clear()
	overlay._result_overlay.visible = false
	overlay.visible = false
	
	var is_dead: bool = (overlay.combat_manager.state == CombatManager.State.LOST and run_manager.hp_buffer == 0)
	parent_scene.handle_combat_finished(is_dead)
