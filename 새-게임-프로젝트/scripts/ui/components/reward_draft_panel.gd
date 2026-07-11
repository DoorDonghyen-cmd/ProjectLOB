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

func setup_choices(b_basic: BulletData, b_ap: BulletData, b_kb: BulletData, b_heavy: BulletData, b_slow: BulletData) -> void:
	_bullets_basic = b_basic
	_bullets_ap = b_ap
	_bullets_kb = b_kb
	_bullets_heavy = b_heavy
	_bullets_slow = b_slow

func show_draft(confirm_btn: Button, efficiency: int = 100, grade: String = "B", credits: int = 20) -> void:
	_draft_confirm_btn = confirm_btn
	_draft_selected = null
	is_credit_selected = false
	earned_credits = credits
	_draft_confirm_btn.disabled = true
	visible = true
	
	for child in _draft_cards_hbox.get_children():
		_draft_cards_hbox.remove_child(child)
		child.queue_free()
		
	# 무작위 호환 탄환 2개 생성
	var bullets = _generate_draft_choices()
	for bullet in bullets:
		_draft_cards_hbox.add_child(_make_draft_card(bullet))
		
	# 3번째 카드: 기업 크레딧 보상 카드
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
		
	var result: Array[BulletData] = []
	pool.shuffle()
	for i in range(min(2, pool.size())):
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
	if is_instance_valid(_draft_confirm_btn):
		_draft_confirm_btn.disabled = false
		
	_highlight_selected_card(selected_card)

func _on_draft_card_selected(bullet: BulletData, selected_card: PanelContainer) -> void:
	_draft_selected = bullet
	is_credit_selected = false
	if is_instance_valid(_draft_confirm_btn):
		_draft_confirm_btn.disabled = false
		
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
