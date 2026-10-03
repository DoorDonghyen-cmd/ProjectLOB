extends Control
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const BattleView = preload("res://redesign/battle_view.gd")
const MagazineView = preload("res://redesign/magazine_view.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const AmmoCardView = preload("res://redesign/ammo_card_view.gd")
const PartCardView = preload("res://redesign/part_card_view.gd")
const CombatPartView = preload("res://redesign/combat_part_view.gd")
const PartFeedback = preload("res://redesign/part_feedback.gd")
const AmmoHandButton = preload("res://redesign/ammo_hand_button.gd")
const FieldCompressorView = preload("res://redesign/field_compressor_view.gd")
const Forecast = preload("res://redesign/forecast.gd")
const CombatWorkbench = preload("res://redesign/combat_workbench.tscn")
const CompressionPairButton = preload("res://redesign/compression_pair_button.gd")
const Readability = preload("res://redesign/readability.gd")
const RunInsight = preload("res://redesign/run_insight.gd")
const Campaign = preload("res://redesign/campaign.gd")
const CampaignUI = preload("res://redesign/campaign_ui.gd")
const CampaignContent = preload("res://redesign/campaign_content.gd")
const WeaponView = preload("res://redesign/weapon_view.gd")
const Preferences = preload("res://redesign/preferences.gd")
const SAVE := "user://chain_run_v2.json"
const BG := Color("101920")
const PANEL := Color("1b2a34")
const INK := Color("e7e4d9")
const MUTED := Color("a4b4ba")
const ACCENT := Color("e4bd72")
const DANGER := Color("f2a38d")
var model = Model.new()
var campaign = null
var city_ui = CampaignUI.new()
var full_game_enabled := true
var difficulty_option: SpinBox
var page := "menu"
var save_enabled := true
var debug_session := false
var body: VBoxContainer
var seed_input: LineEdit
var calculation_label: Label
var selected_slot := 0
var inspect_slots := false
var previous_forecast: Dictionary = {}
var save_error := ""
var busy := false
var presentation_speed := 1.0
var battle_view: Control
var magazine_view: Control
var preview_label: Label
var combat_parts: Dictionary = {}
var last_presentation: Dictionary = {}
var ammo_inspector: Label
var inspected_ammo := "basic"
var combat_forecast: Dictionary = {}
var full_forecast: Dictionary = {}
var next_forecast: Dictionary = {}
var show_full_forecast := false
var hand_layout: Array = []
var hand_layout_key := ""
var used_hand_tokens: Array = []
var preparation_options_open := false
var preferences = Preferences.new()
var ui_theme: Theme
var main_scroll: ScrollContainer
var content_margin: MarginContainer
var workspace_overlay: Control
var selected_weapon_id := "single"
var selected_loadout_id := "balanced"
var selected_difficulty := 0
var preparation_training := false
var preparation_seed := ""

func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	preferences.load_preferences()
	if is_equal_approx(presentation_speed, 1.0):
		presentation_speed = preferences.motion_scale()
	ui_theme = Theme.new()
	ui_theme.default_font = preload("res://redesign/ui_font.tres")
	ui_theme.default_font_size = _scaled(20)
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_color("font_disabled_color", "Button", Color("a0b1ba"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := _style(PANEL if state == "normal" else Color("28404b"))
		box.border_color = ACCENT if state in ["hover", "focus"] else Color("38515d")
		box.set_border_width_all(1)
		ui_theme.set_stylebox(state, "Button", box)
	theme = ui_theme
	main_scroll = ScrollContainer.new()
	main_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_scroll)
	content_margin = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		content_margin.add_theme_constant_override("margin_" + side, 20)
	main_scroll.add_child(content_margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	content_margin.add_child(body)
	get_viewport().size_changed.connect(_viewport_resized)
	redraw()

func _viewport_resized() -> void:
	if is_inside_tree() and not busy:
		redraw.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if busy:
		_skip_animation()
		return
	if is_instance_valid(workspace_overlay):
		_close_workspace()
		return
	for i in range(get_child_count() - 1, -1, -1):
		var child := get_child(i)
		if child is AcceptDialog and child.visible:
			child.hide()
			child.queue_free()
			return
	if page != "menu":
		_to_menu()

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _scaled(value: int) -> int:
	return maxi(12, roundi(float(value) * float(preferences.data.get("text_scale", 1.0))))

func _label(parent: Node, value: String, font_size: int = 20, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", _scaled(font_size))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	return row

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return column

func _button(parent: Node, title: String, key: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.name = key
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", _scaled(20))
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled or busy
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _primary_button(button: Button, color: Color = ACCENT) -> Button:
	button.add_theme_color_override("font_color", Color("101920"))
	button.add_theme_color_override("font_hover_color", Color("101920"))
	button.add_theme_color_override("font_pressed_color", Color("101920"))
	button.add_theme_color_override("font_focus_color", Color("101920"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := _style(color.lightened(0.08) if state in ["hover", "focus"] else (color.darkened(0.12) if state == "pressed" else color))
		box.border_color = color.lightened(0.22)
		box.set_border_width_all(2 if state in ["hover", "focus"] else 1)
		button.add_theme_stylebox_override(state, box)
	return button

func _hint(parent: Node, value: String) -> Label:
	if not bool(preferences.data.get("hints", true)):
		return null
	var hint := _label(parent, value, 17, MUTED)
	hint.name = "ContextHint"
	return hint

func _focus_control(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()

func _stat(parent: Node, icon: String, title: String, value: String, color: Color = INK) -> VBoxContainer:
	var column := _panel(parent)
	column.get_parent().custom_minimum_size.y = 54
	column.add_theme_constant_override("separation", 0)
	var heading := _label(column, "%s  %s" % [icon, title], 13, MUTED)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	var amount := _label(column, value, 18, color)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	return column

func _screen_intro(title: String, question: String = "") -> void:
	_label(body, title, 34, ACCENT)
	if not question.is_empty():
		_label(body, question, 20, INK)

func redraw() -> void:
	combat_parts.clear()
	_close_workspace()
	_reset_scroll.call_deferred()
	var combat_screen: bool = page == "run" and str(model.s.phase) in ["plan", "ready"]
	var compact_combat: bool = combat_screen and size.y < 960
	var edge_margin := 10 if compact_combat else 20
	content_margin.custom_minimum_size.y = 0
	for side in ["left", "right", "top", "bottom"]:
		content_margin.add_theme_constant_override("margin_" + side, edge_margin)
	body.add_theme_constant_override("separation", 6 if compact_combat else 10)
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if page == "menu":
		hand_layout_key = ""
		_menu()
		return
	if page == "loadout":
		_loadout_screen()
		return
	if campaign != null and campaign.s.phase != "combat":
		city_ui.render(self)
		return
	_combat_header(compact_combat)
	if not save_error.is_empty():
		_label(body, save_error, 18, DANGER)
	match model.s.phase:
		"plan", "ready": _combat()
		"reward": _reward()
		"won", "lost": _ending()

func _combat_header(compact: bool) -> void:
	var spec: Dictionary = Content.GUNS[model.s.gun]
	var active_parts := Content.equipped_parts(model.s)
	var status_panel := PanelContainer.new()
	status_panel.name = "CombatStatusBar"
	status_panel.custom_minimum_size.y = 56 if compact else 64
	var status_style := _style(Color("15252e"))
	status_style.content_margin_left = 12
	status_style.content_margin_right = 10
	status_style.content_margin_top = 6
	status_style.content_margin_bottom = 6
	status_style.border_color = WeaponView.COLORS[model.s.gun]
	status_style.border_width_left = 5
	status_panel.add_theme_stylebox_override("panel", status_style)
	body.add_child(status_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if compact else 12)
	status_panel.add_child(row)

	var location_text := "%s  %02d/35" % [CampaignContent.info(int(campaign.s.region)).name, campaign.absolute_floor()] if campaign != null else "훈련  %02d/07" % (int(model.s.floor) + 1)
	var location := _label(row, location_text, 18 if compact else 20, Color("63dce8"))
	location.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	location.custom_minimum_size.x = 156 if compact else 210
	location.autowrap_mode = TextServer.AUTOWRAP_OFF

	var identity_text := "%s · %s" % [spec.name, "연쇄" if spec.mode == "chain" else "단발"]
	var identity_label := _label(row, identity_text, 17 if compact else 18, WeaponView.COLORS[model.s.gun])
	identity_label.name = "WeaponIdentity"
	identity_label.tooltip_text = "%s\n파츠 %d/%d · 탄창 %d칸" % [spec.identity, active_parts.size(), Content.MAX_EQUIPPED_PARTS, model.capacity()]
	identity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if compact:
		identity_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		identity_label.custom_minimum_size.x = 118

	var metrics_text := "T%d · 적%d · +%d" % [int(model.s.turns), model.alive_count(), model.reserve_count()] if compact else "%d턴  │  전열 %d  │  증원 %d" % [int(model.s.turns), model.alive_count(), model.reserve_count()]
	var metrics := _label(row, metrics_text, 14 if compact else 16, INK)
	metrics.name = "CombatMetrics"
	metrics.size_flags_horizontal = Control.SIZE_SHRINK_END
	metrics.autowrap_mode = TextServer.AUTOWRAP_OFF
	var reserve_marker := Label.new()
	reserve_marker.name = "ReinforcementCount"
	reserve_marker.visible = false
	row.add_child(reserve_marker)
	if campaign != null:
		var resources := _label(row, "Cr%d ◆%d" % [int(campaign.s.credits), int(campaign.s.compressor_charges)] if compact else "%dCr  ◆%d" % [int(campaign.s.credits), int(campaign.s.compressor_charges)], 14 if compact else 16, ACCENT)
		resources.size_flags_horizontal = Control.SIZE_SHRINK_END
		resources.autowrap_mode = TextServer.AUTOWRAP_OFF
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(header_spacer)
	if model.s.phase in ["plan", "ready"] and not active_parts.is_empty():
		var parts_row := HBoxContainer.new()
		parts_row.name = "CombatParts"
		parts_row.add_theme_constant_override("separation", 3)
		row.add_child(parts_row)
		for id in active_parts:
			var button := _button(parts_row, "", "combat_part_" + str(id), _combat_part_details.bind(str(id)))
			button.custom_minimum_size = Vector2(48, 44)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			for button_state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var style := _style(Color("263e49") if button_state in ["hover", "pressed", "focus"] else Color("182b35"))
				style.set_content_margin_all(0)
				style.set_border_width_all(1)
				style.border_color = ACCENT if button_state == "focus" else Color("405661")
				button.add_theme_stylebox_override(button_state, style)
			var view := CombatPartView.new()
			view.setup(str(id), model.s, true)
			button.add_child(view)
			combat_parts[id] = view

	for item in [["빌드", "details", _details, "전투·적·빌드 정보"], ["도움", "rules", _rules, "탄환과 전투 규칙"], ["설정", "settings", _settings, "접근성 및 연출 설정"], ["메뉴", "menu", _to_menu, "타이틀로 돌아가기"]]:
		var button := _button(row, item[0], item[1], item[2])
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size = Vector2(58 if compact else 64, 40)
		button.add_theme_font_size_override("font_size", _scaled(18 if compact else 19))
		button.tooltip_text = item[3]
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		if compact:
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var button_style := _style(Color("1b2a34") if state == "normal" else Color("28404b"))
				button_style.content_margin_left = 4
				button_style.content_margin_right = 4
				button_style.content_margin_top = 3
				button_style.content_margin_bottom = 3
				button_style.border_color = ACCENT if state in ["hover", "focus"] else Color("38515d")
				button_style.set_border_width_all(1)
				button.add_theme_stylebox_override(state, button_style)
	var skip_host := Control.new()
	skip_host.custom_minimum_size = Vector2(76, 40)
	row.add_child(skip_host)
	var skip := _button(skip_host, "건너뜀", "skip_animation", _skip_animation, true)
	skip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip.custom_minimum_size = Vector2(76, 36)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.add_theme_font_size_override("font_size", _scaled(14))
	skip.visible = busy

func _reset_scroll() -> void:
	if is_instance_valid(main_scroll):
		main_scroll.scroll_vertical = 0
		main_scroll.scroll_horizontal = 0

func _menu() -> void:
	var city_probe = Campaign.new()
	var city_saved: bool = city_probe.restore()
	var training_probe = Model.new()
	var training_saved: bool = training_probe.restore_run(SAVE)
	var home := _row(body)
	home.name = "TitleLayout"
	home.custom_minimum_size.y = 535
	var hero := _panel(home)
	hero.get_parent().name = "TitleHero"
	hero.get_parent().size_flags_stretch_ratio = 1.45
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 16)
	_label(hero, "LAST ON", 58, INK)
	_label(hero, "BOARD", 86, ACCENT)
	_label(hero, "탄환의 순서가 전투를 바꾼다", 27, INK)
	var preview = Model.new()
	preview.start("single", 1)
	var sequence := _row(hero)
	for id in ["charge", "precise", "pierce"]:
		var card := AmmoCardView.new()
		card.custom_minimum_size = Vector2(0, 154)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.setup(id, 0, preview.s)
		sequence.add_child(card)
	_label(hero, "탄환 조합  →  연쇄 사격  →  나만의 빌드", 18, MUTED)
	var actions := _panel(home)
	actions.get_parent().name = "TitleActions"
	actions.get_parent().custom_minimum_size.x = 390
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	_label(actions, "출격", 17, Color("63dce8"))
	if city_saved and not city_probe.s.settled:
		var saved := VBoxContainer.new()
		saved.name = "ContinueRunCard"
		actions.add_child(saved)
		_label(saved, "%02d / 35층 · %s" % [maxi(1, city_probe.absolute_floor()), Content.GUNS[city_probe.s.gun].name], 26, ACCENT)
		_label(saved, "%s · %d Cr" % [CampaignContent.info(int(city_probe.s.region)).name, int(city_probe.s.credits)], 17, MUTED)
		_primary_button(_button(actions, "등반 계속  ›", "resume", _resume)).custom_minimum_size.y = 72
	else:
		_label(actions, "다섯 무기, 하나의 등반", 28, INK)
		_label(actions, "총기를 고르고 탄환과 파츠로\n35층을 돌파할 빌드를 만드세요.", 19, MUTED)
	var start := _button(actions, "새 등반 준비  ›", "new_run_setup", _open_preparation.bind(false))
	start.custom_minimum_size.y = 72
	if not city_saved or city_probe.s.settled: _primary_button(start)
	_button(actions, "기초 훈련 · 7교전", "training_setup", _open_preparation.bind(true))
	if training_saved: _button(actions, "훈련 이어하기", "resume_training", _resume_training)
	if not bool(preferences.data.get("guide_seen", false)):
		_button(actions, "처음이라면 · 1분 안내", "first_guide", _guide).add_theme_font_size_override("font_size", _scaled(17))
	if FileAccess.file_exists(Campaign.SAVE) and not city_saved:
		_label(actions, "도시 저장을 읽을 수 없습니다. 새 등반 전까지 원본을 보존합니다.", 16, DANGER)
	if FileAccess.file_exists(SAVE) and not training_saved:
		_label(actions, "훈련 저장을 읽을 수 없습니다. 기존 파일은 보존됩니다.", 16, DANGER)
	var utilities := _row(body)
	for item in [["기록실", "city_archive", _city_archive], ["조작 안내", "guide", _guide], ["게임 규칙", "rules", _rules], ["설정", "settings", _settings]]:
		var utility := _button(utilities, item[0], item[1], item[2])
		utility.add_theme_font_size_override("font_size", _scaled(17))
	var dev := _button(utilities, "개발", "dev", _developer)
	dev.size_flags_horizontal = Control.SIZE_SHRINK_END
	dev.custom_minimum_size.x = 86
	_hint(body, "진행은 자동 저장됩니다.")
	var default_focus := body.find_child("resume", true, false) as Button
	if default_focus == null: default_focus = body.find_child("new_run_setup", true, false) as Button
	_focus_control.call_deferred(default_focus)

func _open_preparation(training: bool = false) -> void:
	if busy:
		return
	preparation_training = training
	if preparation_seed.is_empty():
		preparation_seed = str(int(Time.get_unix_time_from_system()) % 1000000)
	page = "loadout"
	redraw()

func _remember_preparation_seed() -> void:
	if is_instance_valid(seed_input) and not seed_input.text.is_empty():
		preparation_seed = seed_input.text

func _select_weapon(id: String) -> void:
	_remember_preparation_seed()
	selected_weapon_id = id
	redraw()

func _select_loadout(id: String) -> void:
	_remember_preparation_seed()
	selected_loadout_id = id
	redraw()

func _loadout_screen() -> void:
	var probe = Campaign.new()
	probe.restore()
	var unlocks: Array = probe.profile.unlocks
	if not unlocks.has(selected_loadout_id): selected_loadout_id = "balanced"
	if preparation_seed.is_empty(): preparation_seed = str(int(Time.get_unix_time_from_system()) % 1000000)
	var top := _row(body)
	var back := _button(top, "‹ 돌아가기", "loadout_back", _to_menu)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 150
	_label(top, "훈련 준비" if preparation_training else "출격 준비", 30, INK)
	var badge := _label(top, "7교전" if preparation_training else "35층 등반", 18, ACCENT)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label(body, "01   전투 방식을 선택하세요", 18, MUTED)
	var weapons := GridContainer.new()
	weapons.name = "WeaponSelection"
	weapons.columns = 5
	weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons.add_theme_constant_override("h_separation", 10)
	body.add_child(weapons)
	for id in Content.GUNS:
		var spec: Dictionary = Content.GUNS[id]
		var chosen: bool = id == selected_weapon_id
		var button := _button(weapons, "", "weapon_select_" + id, _select_weapon.bind(id))
		button.custom_minimum_size.y = 160
		button.tooltip_text = str(spec.text)
		var style := _style(Color("263c44") if chosen else Color("17242c"))
		style.border_color = WeaponView.COLORS[id] if chosen else Color("3a4e58")
		style.set_border_width_all(3 if chosen else 1)
		button.add_theme_stylebox_override("normal", style)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(copy)
		var icon := WeaponView.new()
		icon.gun_id = id
		icon.display_scale = 1.6
		copy.add_child(icon)
		var name_label := _label(copy, ("✓ " if chosen else "") + str(spec.name), 22, WeaponView.COLORS[id])
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var role := _label(copy, str(spec.role), 16, MUTED)
		role.mouse_filter = Control.MOUSE_FILTER_IGNORE
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spec: Dictionary = Content.GUNS[selected_weapon_id]
	var showcase := _panel(body)
	showcase.get_parent().name = "SelectedWeaponPanel"
	var heading := _row(showcase)
	_label(heading, str(spec.name) + "  ·  " + str(spec.identity), 24, WeaponView.COLORS[selected_weapon_id])
	var details := _button(heading, "규칙 상세", "weapon_info_" + selected_weapon_id, _weapon_details.bind(selected_weapon_id))
	details.custom_minimum_size = Vector2(130, 46)
	details.size_flags_horizontal = Control.SIZE_SHRINK_END
	details.add_theme_font_size_override("font_size", _scaled(16))
	var metrics := _row(showcase)
	_label(metrics, "%s   /   탄창 %d칸   /   재장전 %d턴" % ["전탄 연쇄" if spec.mode == "chain" else "한 발씩 발사", spec.capacity, spec.reload], 19, INK)
	_label(metrics, str(spec.recommendation), 17, MUTED)
	_label(body, "02   시작 보급 · 탄환을 누르면 효과 확인", 18, MUTED)
	var supply := _panel(body)
	var supply_row := _row(supply)
	if preparation_training:
		_label(supply_row, "훈련 보급 · 교전마다 새 탄환을 익힙니다", 20, INK)
	else:
		var choices := _row(supply_row)
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.name = "LoadoutSelection"
		for id in unlocks:
			var button := _button(choices, str(CampaignContent.LOADOUTS[id].name), "loadout_select_" + id, _select_loadout.bind(id))
			button.custom_minimum_size.y = 46
			button.add_theme_font_size_override("font_size", _scaled(17))
			if id == selected_loadout_id:
				var selected_style := _style(Color("243942"))
				selected_style.border_color = WeaponView.COLORS[selected_weapon_id]
				selected_style.border_width_bottom = 3
				button.add_theme_stylebox_override("normal", selected_style)
	var start_deck: Array = Content.COURSE_GRANTS[0] if preparation_training else (Content.start_deck(selected_weapon_id) if selected_loadout_id == "balanced" else CampaignContent.LOADOUTS[selected_loadout_id].deck)
	var rounds := _row(supply)
	rounds.name = "StartingDeckPreview"
	var seen: Array = []
	for id in start_deck:
		if seen.has(id): continue
		seen.append(id)
		var detail := _button(rounds, "", "starting_detail_" + str(id), _starting_round_details.bind(str(id)))
		detail.custom_minimum_size.y = 90
		var item := VBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_child(item)
		item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		item.offset_top = 8
		item.offset_bottom = -8
		var bullet := Control.new()
		bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bullet.custom_minimum_size.y = 38
		bullet.draw.connect(func(): AmmoVisual.round_icon(bullet, Vector2(bullet.size.x * 0.5, 19), str(id), 0.42))
		item.add_child(bullet)
		var caption := _label(item, "%s ×%d" % [Content.AMMO[id].name, start_deck.count(id)], 16, MUTED)
		caption.name = "StartingRound_" + str(id)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.tooltip_text = str(Content.AMMO[id].text)
	var footer := _row(body)
	var options := _row(body)
	options.name = "PreparationOptions"
	options.visible = preparation_options_open
	var settings := _button(footer, "등반 설정  ▾", "preparation_options", func():
		preparation_options_open = not preparation_options_open
		options.visible = preparation_options_open
	)
	settings.custom_minimum_size.x = 180
	settings.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var difficulty_status := _label(footer, "기본 난도" if selected_difficulty == 0 else "난도 %d" % selected_difficulty, 17, MUTED)
	if not preparation_training:
		var difficulty_caption := _label(options, "난도", 17, MUTED)
		difficulty_caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		difficulty_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		difficulty_option = SpinBox.new()
		difficulty_option.name = "CityDifficulty"
		difficulty_option.custom_minimum_size = Vector2(100, 48)
		difficulty_option.max_value = int(probe.profile.ascension)
		difficulty_option.value = clampi(selected_difficulty, 0, int(probe.profile.ascension))
		selected_difficulty = int(difficulty_option.value)
		difficulty_option.editable = int(probe.profile.ascension) > 0
		difficulty_option.tooltip_text = "등반 성공 시 다음 난도가 해금됩니다."
		difficulty_status.text = "기본 난도" if selected_difficulty == 0 else "난도 %d" % selected_difficulty
		difficulty_option.value_changed.connect(func(value: float):
			selected_difficulty = int(value)
			difficulty_status.text = "기본 난도" if selected_difficulty == 0 else "난도 %d" % selected_difficulty
		)
		options.add_child(difficulty_option)
	var seed_caption := _label(options, "시드", 17, MUTED)
	seed_caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	seed_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	seed_input = LineEdit.new()
	seed_input.name = "Seed"
	seed_input.text = preparation_seed
	seed_input.custom_minimum_size = Vector2(150, 48)
	seed_input.text_changed.connect(func(value: String): preparation_seed = value)
	options.add_child(seed_input)
	var randomize := _button(options, "새 시드", "randomize_seed", func():
		preparation_seed = str(int(Time.get_ticks_usec()) % 1000000)
		seed_input.text = preparation_seed
	)
	randomize.custom_minimum_size.x = 112
	randomize.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	var launch := _primary_button(_button(footer, "훈련 시작  ›" if preparation_training else "이 구성으로 출격  ›", "start_" + selected_weapon_id, _request_start.bind(selected_weapon_id, false)), WeaponView.COLORS[selected_weapon_id])
	launch.custom_minimum_size = Vector2(290, 64)
	launch.size_flags_horizontal = Control.SIZE_SHRINK_END
	_focus_control.call_deferred(body.find_child("weapon_select_" + selected_weapon_id, true, false))

func _starting_round_details(id: String) -> void:
	var column := _dialog(str(Content.AMMO[id].name), true)
	column.name = "StartingRoundDetails"
	_label(column, str(Content.AMMO[id].text), 21)
	_label(column, "선택 무기 · " + str(Content.GUNS[selected_weapon_id].text), 18, MUTED)

func _request_start(id: String, same_seed: bool) -> void:
	if busy:
		return
	if same_seed or preparation_training:
		_start(id, same_seed)
		return
	var active := Campaign.new()
	if not active.restore() or bool(active.s.get("settled", false)):
		_start(id, same_seed)
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "NewRunConfirmation"
	dialog.title = "진행 중인 등반 교체"
	dialog.dialog_text = "%02d / 35층 · %s 진행이 저장되어 있습니다.\n새 %s 등반으로 교체할까요?" % [active.absolute_floor(), Content.GUNS[active.s.gun].name, Content.GUNS[id].name]
	dialog.ok_button_text = "새 등반 시작"
	dialog.cancel_button_text = "계속 보관"
	dialog.confirmed.connect(func():
		dialog.queue_free()
		_start(id, same_seed)
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 260))

func _start(id: String, same_seed: bool) -> void:
	if busy: return
	hand_layout_key = ""
	show_full_forecast = false
	_remember_preparation_seed()
	if full_game_enabled and ((same_seed and campaign != null) or (not same_seed and not preparation_training)):
		var run_seed: int = int(campaign.s.seed) if same_seed else int(preparation_seed)
		var difficulty: int = int(campaign.s.difficulty) if same_seed else selected_difficulty
		var loadout: String = str(campaign.s.loadout) if same_seed else selected_loadout_id
		var progress = Campaign.new()
		progress.restore()
		if same_seed and debug_session: progress.profile = campaign.profile.duplicate(true)
		campaign = progress
		campaign.start(id, run_seed, difficulty, loadout)
		model = campaign.model
		debug_session = debug_session and same_seed
		page = "run"
		_changed()
		return
	campaign = null
	var run_seed: int = int(model.s.seed) if same_seed else int(preparation_seed)
	debug_session = debug_session and same_seed
	var course: bool = model.s.get("course", false) if same_seed else preparation_training
	model.start(id, run_seed, course)
	selected_slot = 0
	inspect_slots = false
	previous_forecast = {}
	page = "run"
	_changed()

func _resume() -> void:
	if busy: return
	var probe = Campaign.new()
	if full_game_enabled and probe.restore() and not probe.s.settled:
		campaign = probe
		model = campaign.model
		debug_session = false
		page = "run"
		redraw()
		return
	_resume_training()

func _resume_training() -> void:
	if busy: return
	if model.restore_run(SAVE):
		campaign = null
		debug_session = false
		page = "run"
		redraw()

func _to_menu() -> void:
	if busy: return
	page = "menu"
	redraw()

func _new_battle_view() -> Control:
	return BattleView.new()

func _combat() -> void:
	var compact := size.y < 960
	var previous := combat_forecast
	full_forecast = Forecast.analyze(model.s)
	next_forecast = Forecast.analyze(model.s, true)
	if int(full_forecast.get("turns", 0)) <= 1: show_full_forecast = false
	combat_forecast = full_forecast if show_full_forecast else next_forecast
	var layout := CombatWorkbench.instantiate()
	layout.name = "CombatWorkbench"
	layout.add_theme_constant_override("separation", 5 if compact else 10)
	layout.size_flags_vertical = Control.SIZE_FILL
	body.add_child(layout)

	var tactical_grid := layout.get_node("%TacticalGrid") as GridContainer
	tactical_grid.columns = 1
	tactical_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	tactical_grid.add_theme_constant_override("h_separation", 8 if compact else 14)
	tactical_grid.add_theme_constant_override("v_separation", 6 if compact else 10)
	if compact:
		(layout.get_node("TacticalGrid/CandidatesPanel/CandidatesColumn") as VBoxContainer).add_theme_constant_override("separation", 4)
		(layout.get_node("TacticalGrid/QueuePanel/QueueColumn") as VBoxContainer).add_theme_constant_override("separation", 4)
	var current_stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	var candidate_active: bool = model.s.phase == "plan" and current_stack.is_empty()
	for panel_path in ["%CandidatesPanel", "%QueuePanel"]:
		var panel := layout.get_node(panel_path) as PanelContainer
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
		var panel_active: bool = candidate_active if panel_path == "%CandidatesPanel" else not candidate_active
		var panel_style := _style(Color("172a34") if panel_active else PANEL)
		panel_style.border_color = ACCENT if panel_active else Color("304852")
		panel_style.set_border_width_all(2 if panel_active else 1)
		if compact:
			panel_style.content_margin_left = 8
			panel_style.content_margin_right = 8
			panel_style.content_margin_top = 6
			panel_style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", panel_style)
	var hand_heading := layout.get_node("TacticalGrid/CandidatesPanel/CandidatesColumn/HandHeader/HandHeading") as Label
	hand_heading.text = "탄환 선택"
	hand_heading.add_theme_font_size_override("font_size", _scaled(18 if compact else 22))
	var queue_heading := layout.get_node("%QueueHeading") as Label
	queue_heading.add_theme_font_size_override("font_size", _scaled(17 if compact else 20))
	var hand_controls := layout.get_node("%HandControls") as HBoxContainer
	if campaign != null and bool(preferences.data.hints):
		var lesson := CampaignContent.lesson(campaign.node(), model.s)
		if not lesson.is_empty():
			hand_heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			var lesson_label := _label(hand_heading.get_parent(), lesson, 17, MUTED)
			lesson_label.name = "EncounterLesson"
			lesson_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			lesson_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			lesson_label.tooltip_text = lesson
			hand_heading.get_parent().move_child(lesson_label, 1)
	var steps := layout.get_node("%CombatSteps") as PanelContainer
	steps.visible = not compact
	var battle_preview := layout.get_node("%BattlePreview")
	battle_preview.get_parent().remove_child(battle_preview)
	battle_preview.queue_free()
	battle_view = _new_battle_view()
	battle_view.name = "BattleView"
	battle_view.compact_ui = compact
	battle_view.region = int(campaign.s.region) if campaign != null else 0
	battle_view.inspection_enabled = not busy
	layout.get_node("%BattleHost").add_child(battle_view)
	if compact: battle_view.custom_minimum_size.y = 248
	battle_view.sync(model.s, combat_forecast)
	if campaign != null: battle_view.caption = str(campaign.node().name)
	if model.s.get("course", false): battle_view.caption = Content.lesson(model.s)
	if not combat_forecast.get("random", false) and not combat_forecast.shots.is_empty(): battle_view.first_shot = combat_forecast.shots[0]
	battle_view.shot_started.connect(_visual_shot)
	battle_view.shot_impacted.connect(_visual_impact)
	_update_combat_parts()
	battle_view.enemy_inspected.connect(_enemy_details)
	battle_view.reinforcement_inspected.connect(_reinforcement_details)
	_combat_steps(layout)

	var decision_prompt := layout.get_node("%DecisionPrompt") as Label
	decision_prompt.add_theme_font_size_override("font_size", _scaled(14 if compact else 17))
	decision_prompt.text = "탄을 선택하면 발사 순서에 추가됩니다" if model.s.plan.is_empty() else "왼쪽부터 발사 · 전장에서 처치와 충돌 위험 확인"
	var prompt_style := _style(Color("17313a"))
	prompt_style.border_color = Color("63dce8") if model.s.plan.is_empty() else ACCENT
	prompt_style.border_width_left = 4
	prompt_style.content_margin_left = 8 if compact else 16
	prompt_style.content_margin_right = 8 if compact else 16
	prompt_style.content_margin_top = 5 if compact else 8
	prompt_style.content_margin_bottom = 5 if compact else 8
	decision_prompt.add_theme_stylebox_override("normal", prompt_style)
	if not model.s.get("course", false) or int(model.s.floor) >= 2:
		if not model.s.get("course", false):
			var field_ids: Array = model.field_compressible_ids()
			var compressor := PanelContainer.new()
			compressor.name = "field_compressor_status"
			compressor.custom_minimum_size = Vector2(50 if compact else 58, 36 if compact else 44)
			compressor.size_flags_horizontal = Control.SIZE_SHRINK_END
			compressor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			compressor.tooltip_text = "압축 코어 %d/2 · 같은 탄환을 서로 끌어 임시 압축\n코어는 런 동안 유지되며 상점에서 충전합니다." % int(model.s.field_compression_left)
			var compressor_style := _style(PANEL)
			compressor_style.border_color = Color("63dce8") if not field_ids.is_empty() else Color("38515d")
			compressor_style.set_border_width_all(1)
			compressor.add_theme_stylebox_override("panel", compressor_style)
			hand_controls.add_child(compressor)
			var compressor_view := FieldCompressorView.new()
			compressor_view.name = "CompressorGlyph"
			compressor_view.setup(int(model.s.field_compression_left), not field_ids.is_empty())
			compressor.add_child(compressor_view)
		var exchange_button := _button(hand_controls, "패 교환  %d" % model.s.exchange_left, "exchange", _exchange_dialog, model.s.phase != "plan" or model.s.exchange_left <= 0 or (model.s.draw.is_empty() and model.s.discard.is_empty()))
		exchange_button.custom_minimum_size = Vector2(106 if compact else 132, 36 if compact else 44)
		exchange_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		exchange_button.add_theme_font_size_override("font_size", _scaled(14 if compact else 16))

	var field_ids: Array = model.field_compressible_ids()
	var compression_actions := layout.get_node("%CompressionActions") as HBoxContainer
	for compress_id_value in field_ids:
		var compress_id := str(compress_id_value)
		var compress_button := CompressionPairButton.new()
		compress_button.name = "compress_pair_" + compress_id
		compress_button.setup(compress_id)
		compress_button.pressed.connect(_field_compress_click.bind(compress_id))
		compression_actions.add_child(compress_button)
		compress_button.tooltip_text = "압축 코어 1개를 사용합니다. 드래그하지 않아도 같은 결과가 적용됩니다."
	var grid := layout.get_node("%AmmoGrid") as GridContainer
	grid.columns = 6 if get_tree().root.size.x >= 900 else 3
	var ids: Array = ["basic"]
	for hand_id in model.s.hand:
		if not ids.has(hand_id): ids.append(hand_id)
	var entries: Array = _hand_entries()
	for entry in entries:
		var id := str(entry.id)
		var count := int(entry.count)
		var held: bool = bool(entry.get("held", false))
		var disabled: bool = held or not model.can_load(id)
		var token := str(entry.token)
		var copy_number := int(entry.copy)
		var key := "load_" + id + ("" if copy_number == 1 else "_%d" % copy_number)
		var can_compress := not held and field_ids.has(id)
		var button := AmmoHandButton.new()
		button.name = key
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 154
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = disabled or busy
		button.setup(id, token, can_compress, model.s)
		button.pressed.connect(_load.bind(id, key))
		button.pair_dropped.connect(_field_drop)
		grid.add_child(button)
		button.tooltip_text = _ammo_stats(id) + "\n" + Readability.description(id, model.s) + ("\n같은 표시 탄환 위로 끌어 압축" if can_compress else "")
		button.custom_minimum_size.y = 154
		button.mouse_entered.connect(_inspect_ammo.bind(id))
		button.focus_entered.connect(_inspect_ammo.bind(id))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var base_color := Color("15262f").lerp(AmmoVisual.COLORS[id], 0.08)
			if state in ["hover", "focus"]: base_color = base_color.lightened(0.08)
			elif state == "pressed": base_color = base_color.darkened(0.08)
			elif state == "disabled": base_color = Color("101b22")
			var style := _style(base_color)
			style.border_color = Color("63dce8") if can_compress else AmmoVisual.COLORS[id].darkened(0.18)
			style.set_border_width_all(2 if can_compress or state in ["hover", "focus"] else 1)
			style.content_margin_left = 6
			style.content_margin_right = 6
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			button.add_theme_stylebox_override(state, style)
		var card_view := AmmoCardView.new()
		card_view.name = "CardInfo"
		card_view.compact_ui = false
		card_view.setup(id, count, model.s, disabled, can_compress, "장전한 탄" if held else "")
		button.add_child(card_view)

	ammo_inspector = layout.get_node("%AmmoInspector") as Label
	ammo_inspector.add_theme_font_size_override("font_size", _scaled(17))
	ammo_inspector.add_theme_color_override("font_color", INK)
	ammo_inspector.custom_minimum_size.y = 0
	ammo_inspector.hide()
	calculation_label = ammo_inspector
	_inspect_ammo(inspected_ammo if ids.has(inspected_ammo) else "basic")
	_reserve_preview(layout.get_node("%ReserveHost"), compact)

	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	queue_heading.text = "발사 순서  ·  %d/%d칸" % [Content.slots_used(stack), model.capacity()]
	if str(model.s.gun) == "amplifier": queue_heading.text += " · 처치 시 연속"
	var magazine_preview := layout.get_node("%MagazinePreview")
	magazine_preview.get_parent().remove_child(magazine_preview)
	magazine_preview.queue_free()
	magazine_view = MagazineView.new()
	magazine_view.name = "MagazineView"
	magazine_view.compact_ui = false
	magazine_view.stack = stack.duplicate()
	magazine_view.capacity = model.capacity()
	magazine_view.interactive = not busy
	magazine_view.selected_index = selected_slot
	magazine_view.slot_moved.connect(_move_slot)
	magazine_view.next_shot_count = next_forecast.shots.size() if int(full_forecast.get("turns", 0)) > 1 else -1
	for i in range(combat_forecast.shots.size()):
		if i >= previous.get("shots", []).size() or combat_forecast.shots[i].damage != previous.shots[i].damage or combat_forecast.shots[i].target != previous.shots[i].target:
			magazine_view.changed_slots.append(i)
	magazine_view.slot_pressed.connect(_slot_action)
	magazine_view.confirmed = model.s.phase == "ready"
	if not stack.is_empty(): magazine_view.forecast = full_forecast
	layout.get_node("%MagazineHost").add_child(magazine_view)

	var edits := layout.get_node("%EditActions") as HBoxContainer
	_button(edits, "← 앞으로", "slot_previous", func(): _move_slot(selected_slot, selected_slot - 1))
	_button(edits, "뒤로 →", "slot_next", func(): _move_slot(selected_slot, selected_slot + 1))
	_button(edits, "선택 회수", "remove_selected", func(): _remove_slot(selected_slot))
	_button(edits, "탄 상세", "inspect_slots", _slot_details, stack.is_empty())
	_button(edits, "끝 탄 회수", "undo", _undo, model.s.phase != "plan" or stack.is_empty())
	for edit in edits.get_children():
		edit.custom_minimum_size = Vector2(100, 40)
		edit.add_theme_font_size_override("font_size", _scaled(15))
		_compact_control(edit, 40)
	_update_slot_actions()

	var preview: Dictionary = model.preview()
	preview_label = layout.get_node("%ForecastLabel") as Label
	preview_label.add_theme_font_size_override("font_size", _scaled(15 if compact else 18))
	preview_label.add_theme_color_override("font_color", ACCENT if int(preview.get("damage", 0)) > 0 else MUTED)
	preview_label.custom_minimum_size.y = 26 if compact else 36
	var result_style := _style(Color("183039") if not stack.is_empty() else Color("14252e"))
	result_style.border_color = ACCENT if not stack.is_empty() else Color("38515d")
	result_style.border_width_left = 4 if not stack.is_empty() else 1
	result_style.content_margin_left = 8 if compact else 16
	result_style.content_margin_right = 8 if compact else 16
	result_style.content_margin_top = 5 if compact else 9
	result_style.content_margin_bottom = 5 if compact else 9
	preview_label.add_theme_stylebox_override("normal", result_style)
	preview_label.text = "선택 결과 · " + _preview_text(preview)
	preview_label.tooltip_text = str(preview.get("text", "누른 순서대로 발사합니다. 피해·거리·속성 효과를 함께 설계하세요."))
	if not stack.is_empty():
		preview_label.text = ("계속 발사 · %d턴 · " % int(full_forecast.turns) if show_full_forecast else "이번 발사 · 1턴 · ") + Forecast.compact_summary(combat_forecast)
		preview_label.tooltip_text = "무작위 표적의 HP 범위와 처치·접촉 확률입니다." if combat_forecast.get("random", false) else "전장의 HP 화살표도 이 범위의 결과입니다. 전체 탄창 예측은 중간 재장전 없이 계속 발사하는 조건입니다."
	if not stack.is_empty(): _inspect_slot(clampi(selected_slot, 0, stack.size() - 1))

	var actions := layout.get_node("%CombatActions") as VBoxContainer
	if model.s.phase == "plan":
		var confirm_button := _button(actions, "장전 확정", "confirm", _confirm, stack.is_empty())
		confirm_button.custom_minimum_size.y = 44 if compact else 52
		confirm_button.add_theme_font_size_override("font_size", _scaled(17 if compact else 20))
		_primary_button(confirm_button)
		confirm_button.tooltip_text = "시간 소모 없음. 확정 후 순서를 바꾸려면 재장전해야 합니다."
		_label(actions, "확정 후 변경: 재장전 %d턴" % model.reload_cost(), 16, MUTED).name = "ConfirmCost"
	else:
		var fire_label := "연쇄 사격 · %d발 · 1턴" % stack.size() if Content.chains(model.s) else "처형 연쇄 · 처치 시 계속 · 1턴"
		var fire_count: int = next_forecast.shots.size()
		var fire_button := _primary_button(_button(actions, "발사  ·  %d발" % fire_count, "fire", _fire, stack.is_empty()))
		fire_button.tooltip_text = fire_label
		fire_button.custom_minimum_size.y = 44
		fire_button.add_theme_font_size_override("font_size", _scaled(17 if compact else 20))
		var projected: Array = model.movement_preview(model.reload_cost())
		var lethal := false
		for i in range(projected.size()):
			if model.s.enemies[i].hp > 0 and projected[i] <= 0:
				lethal = true
		var reload_button := _button(actions, "재장전 · %d턴%s" % [model.reload_cost(), " · 접촉 위험" if lethal else ""], "reload", _reload)
		reload_button.custom_minimum_size.y = 36 if compact else 44
		reload_button.add_theme_font_size_override("font_size", _scaled(16 if compact else 20))
	for action in actions.get_children():
		if action is Button: _compact_control(action)

	layout.arrange_combat()
	var result_row := HBoxContainer.new()
	result_row.name = "ForecastRow"
	result_row.custom_minimum_size.y = 40
	var result_parent := preview_label.get_parent()
	var result_index := preview_label.get_index()
	result_parent.add_child(result_row)
	result_parent.move_child(result_row, result_index)
	preview_label.reparent(result_row)
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if int(full_forecast.get("turns", 0)) > 1:
		var scope := _button(result_row, "이번 발사 보기" if show_full_forecast else "전체 %d턴 보기" % int(full_forecast.turns), "forecast_scope", func():
			show_full_forecast = not show_full_forecast
			redraw()
		)
		scope.custom_minimum_size = Vector2(150, 40)
		scope.size_flags_horizontal = Control.SIZE_SHRINK_END
		scope.add_theme_font_size_override("font_size", _scaled(15))
		_compact_control(scope, 40)

func _compact_control(button: Button, height: int = 44) -> void:
	button.custom_minimum_size.y = height
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)

func _hand_entries() -> Array:
	var key := JSON.stringify([model.s.seed, model.s.gun, model.s.floor, model.s.reloads, model.s.exchange_left, model.s.get("course", false)])
	if hand_layout_key != key:
		hand_layout_key = key
		used_hand_tokens.clear()
		hand_layout = [{"id": "basic", "count": 0, "token": "basic", "copy": 1}]
		var pool: Array = model.s.hand.duplicate()
		if model.s.phase == "ready":
			for id in model.s.magazine:
				if id != "basic" and not Content.is_temporary(str(id)): pool.append(id)
		var field: Dictionary = model.s.get("field_compression", {})
		if not field.is_empty():
			pool.append(field.source)
			pool.append(field.source)
		var seen: Array = []
		for id in pool:
			if seen.has(id): continue
			seen.append(id)
			for i in range(pool.count(id)):
				hand_layout.append({"id": id, "count": 1, "token": "load_" + str(id) + ("" if i == 0 else "_%d" % (i + 1)), "copy": i + 1})
	var entries := hand_layout.duplicate(true)
	entries[0].count = model.available("basic")
	var held_tokens: Array = []
	var ids: Array = []
	for entry in entries.slice(1):
		if ids.has(entry.id): continue
		ids.append(entry.id)
		var copies: Array = entries.filter(func(e): return e.id == entry.id)
		var spent: int = maxi(0, copies.size() - model.available(str(entry.id)))
		for token in used_hand_tokens:
			if spent <= 0: break
			if copies.any(func(e): return e.token == token):
				held_tokens.append(token)
				spent -= 1
		for copy_entry in copies:
			if spent <= 0: break
			if not held_tokens.has(copy_entry.token):
				held_tokens.append(copy_entry.token)
				spent -= 1
	for entry in entries: entry.held = held_tokens.has(entry.token)
	return entries

func _combat_steps(layout: Control) -> void:
	var strip := layout.get_node("%CombatSteps") as PanelContainer
	var style := _style(Color("14252e"))
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	strip.add_theme_stylebox_override("panel", style)
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	var active := 1 if model.s.phase == "plan" and stack.is_empty() else (2 if model.s.phase == "plan" else 3)
	for step in [[1, "탄 선택", "%CombatStep1"], [2, "순서 확인", "%CombatStep2"], [3, "발사", "%CombatStep3"]]:
		var number := int(step[0])
		var marker := "●" if number == active else ("✓" if number < active else "○")
		var label := layout.get_node(str(step[2])) as Label
		label.text = "%s  %s" % [marker, step[1]]
		label.add_theme_font_size_override("font_size", _scaled(15))
		var step_style := _style(ACCENT if number == active else (Color("213842") if number < active else Color("101c24")))
		step_style.border_color = ACCENT if number <= active else Color("304852")
		step_style.set_border_width_all(1)
		step_style.content_margin_top = 6
		step_style.content_margin_bottom = 6
		label.add_theme_stylebox_override("normal", step_style)
		label.add_theme_color_override("font_color", Color("101920") if number == active else (INK if number < active else MUTED))
		label.custom_minimum_size.y = 32
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
func _ammo_stats(id: String) -> String:
	return Content.AMMO[id].name + "   " + Readability.stats(id, model.s, true)

func _candidate_outcome(id: String) -> Dictionary:
	if not model.can_load(id):
		return {"text": "보유 없음" if model.available(id) <= 0 else "공간 부족", "positive": false}
	var insert_at := Content.insertion_index(model.s.plan, id)
	var copy := Model.new()
	copy.s = model.s.duplicate(true)
	if not copy.load_round(id): return {"text": "지금 장전할 수 없음", "positive": false}
	var projected := Forecast.analyze(copy.s)
	var current_kills := _forecast_kills(combat_forecast)
	var projected_kills := _forecast_kills(projected)
	if projected_kills > current_kills:
		return {"text": "처치 +%d" % (projected_kills - current_kills), "positive": true}
	if str(combat_forecast.get("phase", "")) == "lost" and str(projected.get("phase", "")) != "lost":
		return {"text": "충돌 위험 해제", "positive": true}
	var shots: Array = projected.get("shots", [])
	if insert_at >= 0 and insert_at < shots.size():
		var shot: Dictionary = shots[insert_at]
		if shot.get("random", false):
			return {"text": "무작위 %d~%d 피해" % [shot.damage_min, shot.damage_max], "positive": int(shot.damage_max) > 0}
		var result := "%s %s" % [Forecast.tag(int(shot.target)), Forecast.outcome(shot)]
		return {"text": result, "positive": int(shot.get("damage", 0)) > 0 or int(shot.get("blocked_hits", 0)) > 0}
	return {"text": "결과 확인", "positive": false}

func _forecast_kills(forecast: Dictionary) -> int:
	var result := 0
	for enemy in forecast.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: result += 1
	return result

func _inspect_ammo(id: String) -> void:
	inspected_ammo = id
	if is_instance_valid(ammo_inspector):
		var axes := Content.axes(model.s)
		var legend := "피해 → HP"
		if axes.armor: legend += "   관통 → 장갑"
		ammo_inspector.text = legend + "\n" + Readability.description(id, model.s)
		ammo_inspector.add_theme_color_override("font_color", AmmoVisual.COLORS[id])

func _preview_text(preview: Dictionary) -> String:
	if preview.is_empty():
		return "탄환을 눌러 장전하세요" if model.s.phase == "plan" else "탄창이 비었습니다"
	var result := "빗나감" if not preview.hit else ("도탄" if int(preview.damage) == 0 else "피해 %d" % preview.damage)
	if int(preview.hp) <= 0: result += " · 처치"
	var spec: Dictionary = Content.AMMO[preview.id]
	if str(spec.effect) in ["boost", "burn", "arc"]:
		result += "\n" + str(AmmoVisual.HINT[preview.id])
	return "첫 발  ·  " + result

func _reward() -> void:
	_label(body, "통과했습니다. 무엇을 가져갈까요?", 34, ACCENT)
	_encounter_debrief(body, model.s)
	var next_index := int(model.s.floor) + 1
	var next: Dictionary = Content.ENCOUNTERS[next_index]
	var next_enemies := Content.enemies_for(next_index, int(model.s.seed), model.s.get("course", false), str(model.s.gun))
	var peek := _panel(body)
	_label(peek, "다음 교전  /  " + str(next.name), 24)
	var threat_label := _label(peek, RunInsight.threat_line(next_enemies), 19, ACCENT)
	threat_label.name = "ThreatSummary"
	var enemy_row := _row(peek)
	for enemy_index in range(next_enemies.size()):
		var e: Dictionary = next_enemies[enemy_index]
		var enemy_card := _panel(enemy_row)
		_label(enemy_card, "%s  %s" % [Forecast.tag(enemy_index), e.name], 18)
		_label(enemy_card, "HP %d · 장갑 %d" % [e.hp, e.def], 17, MUTED)
		_label(enemy_card, "%dm  /  턴당 −%dm" % [e.distance, e.speed], 17, MUTED)
	if model.s.get("course", false):
		var grants: Array = Content.COURSE_GRANTS[next_index]
		if not grants.is_empty(): _label(peek, "다음 교전 보급: " + _ammo_names(grants), 18, ACCENT)
	_label(body, "덱 %d장 · 파츠 %d/%d" % [model.s.deck.size(), Content.equipped_parts(model.s).size(), Content.MAX_EQUIPPED_PARTS], 18, MUTED)
	var row := _row(body)
	for id in model.reward_options():
		var is_ammo: bool = Content.AMMO.has(id)
		var spec: Dictionary = Content.AMMO[id] if is_ammo else Content.PARTS[id]
		var card := _panel(row)
		if is_ammo:
			var card_view := AmmoCardView.new()
			card_view.name = "RewardCardInfo"
			card_view.custom_minimum_size = Vector2(280, 104)
			card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_view.setup(id, 1, model.s)
			card.add_child(card_view)
		else:
			var part_view := PartCardView.new()
			part_view.name = "RewardPartInfo"
			part_view.custom_minimum_size = Vector2(280, 128)
			part_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			part_view.setup(id, model.s, false, false)
			card.add_child(part_view)
		if is_ammo: _label(card, Readability.description(id, model.s), 17, MUTED)
		var impact := _label(card, "영향 · " + RunInsight.reward_impact(id, model.s, next_enemies), 17, ACCENT)
		impact.name = "RewardImpact_" + id
		_button(card, "덱에 1장 추가" if is_ammo else "파츠 추가 장착", "reward_" + id, _choose.bind(id, ""), (is_ammo and model.s.deck.size() >= model.deck_limit()) or (not is_ammo and Content.equipped_parts(model.s).size() >= Content.MAX_EQUIPPED_PARTS))
	var refine := _panel(body)
	_label(refine, "덱을 늘리지 않는 선택", 23)
	_button(refine, "지금 구성을 유지하고 계속", "reward_skip", _choose.bind("skip", ""))

func _ending() -> void:
	var won: bool = model.s.phase == "won"
	if won and model.s.get("course", false) and save_enabled and not debug_session:
		var flag := FileAccess.open("user://course_completed.flag", FileAccess.WRITE)
		if flag: flag.store_string("completed")
	_label(body, "훈련 완료" if won else "계산은 여기서 멈췄다.", 46, ACCENT if won else DANGER)
	_label(body, "이제 나만의 무기로 도시를 오를 준비가 됐습니다." if won else str(model.s.message), 24)
	_label(body, "%d / 7 교전 통과 · %d턴 · %d발 · 재장전 %d회" % [7 if won else int(model.s.floor), model.s.turns, model.s.shots, model.s.reloads], 22, MUTED)
	var run_report := _label(body, RunInsight.combat_report_line(model.s), 19, ACCENT)
	run_report.name = "RunReport"
	if not won:
		var advice := _panel(body)
		_label(advice, "다음 설계", 20, ACCENT)
		_label(advice, RunInsight.loss_advice(model.s), 18)
	var final_deck := _label(body, "최종 덱: " + RunInsight.deck_summary(model.s.deck), 20)
	final_deck.name = "FinalDeckSummary"
	var row := _row(body)
	_button(row, "같은 시드로 다시 설계", "retry", _start.bind(str(model.s.gun), true))
	_button(row, "총기 / 새 시드 선택", "new_run", _to_menu)

func _ammo_names(ids: Array) -> String:
	var names: PackedStringArray = []
	for id in ids:
		names.append(Content.AMMO[id].name + (" ◆" if Content.is_compressed(str(id)) else ""))
	return " · ".join(names) if not names.is_empty() else "없음"

func _reserve_preview(parent: Node, compact: bool = false) -> void:
	var reserve := _panel(parent)
	reserve.name = "ReserveAmmo"
	reserve.tooltip_text = "다음 두 발은 순서 공개 · 나머지는 대기/사용 구성을 공개하고 순서는 숨깁니다."
	if compact:
		var reserve_style := _style(Color("14242c"))
		reserve_style.content_margin_left = 6
		reserve_style.content_margin_right = 6
		reserve_style.content_margin_top = 3
		reserve_style.content_margin_bottom = 3
		reserve.get_parent().add_theme_stylebox_override("panel", reserve_style)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4 if compact else 6)
	flow.add_theme_constant_override("v_separation", 3 if compact else 5)
	reserve.add_child(flow)
	_label(flow, "다음", 12 if compact else 14, ACCENT)
	var next_count: int = mini(2, model.s.draw.size())
	if next_count == 0: _label(flow, "셔플", 14, MUTED)
	for i in range(next_count): _reserve_chip(flow, str(model.s.draw[i]), str(i + 1), 1, true, "next", compact)
	_reserve_group(flow, "대기", model.s.draw.slice(next_count), "wait", compact)
	_reserve_group(flow, "사용", model.s.discard, "used", compact)

func _reserve_group(parent: Node, title: String, ids: Array, zone: String, compact: bool = false) -> void:
	if ids.is_empty(): return
	_label(parent, "%s %d" % [title, ids.size()], 12 if compact else 14, MUTED)
	var counts := {}
	var order: Array = []
	for value in ids:
		var id := str(value)
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	for id in order: _reserve_chip(parent, str(id), AmmoVisual.SHORT.get(id, Content.AMMO[id].name), int(counts[id]), false, zone, compact)

func _reserve_chip(parent: Node, id: String, title: String, count: int, is_next: bool, zone: String, compact: bool = false) -> void:
	var chip := PanelContainer.new()
	chip.name = "reserve_%s_%s" % [zone, id]
	chip.custom_minimum_size = Vector2(50 if is_next and compact else (64 if compact else (58 if is_next else 74)), 30 if compact else 36)
	chip.tooltip_text = ("다음 %s번째 · " % title if is_next else ("사용 구성 · " if zone == "used" else "대기 구성 · ")) + Content.AMMO[id].name
	var style := _style(Color("17242c"))
	style.border_color = ACCENT if is_next else Color("38515d")
	style.set_border_width_all(1)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	chip.add_child(row)
	var icon := AmmoVisual.new()
	icon.ammo_id = id
	icon.custom_minimum_size = Vector2(20 if compact else 24, 24 if compact else 30)
	row.add_child(icon)
	var text := title if is_next else title + ("×%d" % count if count > 1 else "")
	_label(row, text, 12 if compact else 13, ACCENT if is_next else MUTED)

func _persist() -> void:
	if campaign != null: campaign.sync_combat()
	if save_enabled and not debug_session:
		var error: Error = campaign.save() if campaign != null else model.save_run(SAVE)
		save_error = "자동 저장 실패 (%d) · 게임을 종료하지 말아 주세요." % error if error != OK else ""

func _changed() -> void:
	_persist()
	redraw.call_deferred()

func _load(id: String, source_key: String = "") -> void:
	if busy: return
	var source := find_child(source_key if not source_key.is_empty() else "load_" + id, true, false) as Button
	var from: Vector2 = source.get_global_rect().get_center() if source else Vector2(300, 500)
	var insertion_index := Content.insertion_index(model.s.plan, id)
	if model.load_round(id):
		if id != "basic": used_hand_tokens.append(str(source.name) if source else "load_" + id)
		inspected_ammo = id
		selected_slot = insertion_index
		busy = true
		_persist()
		redraw()
		await get_tree().process_frame
		await magazine_view.arrive(id, from, 0.23 * presentation_speed, insertion_index)
		busy = false
		redraw()

func _field_drop(id: String, source_center: Vector2, target_center: Vector2) -> void:
	if busy or not model.can_field_compress(id): return
	var from := source_center.lerp(target_center, 0.5)
	var temporary_id := Content.field_id(id)
	var insertion_index := Content.insertion_index(model.s.plan, temporary_id)
	if model.field_compress(id):
		inspected_ammo = temporary_id
		selected_slot = insertion_index
		busy = true
		_persist()
		redraw()
		await get_tree().process_frame
		await magazine_view.arrive(temporary_id, from, 0.28 * presentation_speed, insertion_index)
		busy = false
		redraw()

func _field_compress_click(id: String) -> void:
	if busy or not model.can_field_compress(id): return
	var first := find_child("load_" + id, true, false) as Control
	var second := find_child("load_" + id + "_2", true, false) as Control
	var from := first.get_global_rect().get_center() if first else Vector2(280, 500)
	var to := second.get_global_rect().get_center() if second else from + Vector2(120, 0)
	_field_drop(id, from, to)

func _undo() -> void:
	if busy: return
	_remove_slot(model.s.plan.size() - 1)

func _confirm() -> void:
	if busy: return
	if model.confirm(): _changed()

func _fire() -> void:
	if busy: return
	var before: Dictionary = model.s.duplicate(true)
	if model.fire():
		var detail: Dictionary = model.s.history.back().detail
		await _present(before, detail.results, detail.get("advance_events", []), false, detail.get("deployments", []))

func _reload() -> void:
	if busy: return
	var before: Dictionary = model.s.duplicate(true)
	if model.reload_magazine():
		var detail: Dictionary = model.s.history.back().detail
		await _present(before, [], detail.get("advance_events", []), true, detail.get("deployments", []))

func _choose(id: String, remove_id: String) -> void:
	if busy: return
	if model.choose_reward(id, remove_id): _changed()

func _present(before: Dictionary, results: Array, advance_events: Array, reloading: bool, deployments: Array = []) -> void:
	busy = true
	_persist()
	find_child("skip_animation", true, false).show()
	magazine_view.forecast = {}
	magazine_view.queue_redraw()
	for button in find_children("*", "Button", true, false):
		button.disabled = button.name != "skip_animation"
	battle_view.speed_scale = presentation_speed
	await battle_view.play_action(before, model.s, results, advance_events, reloading, deployments)
	last_presentation = {"before": before, "after": model.s.duplicate(true), "shown_enemies": battle_view.enemies.duplicate(true), "events": battle_view.visual_events.duplicate(true)}
	busy = false
	redraw()

func _visual_shot(result: Dictionary) -> void:
	magazine_view.consume()
	for view in combat_parts.values():
		view.activated = false
		view.queue_redraw()
	preview_label.text = "%s  →  %s" % [AmmoVisual.SHORT[str(result.id)], Forecast.tag(int(result.target))]
	preview_label.tooltip_text = str(result.text)

func _visual_impact(result: Dictionary) -> void:
	var effects: Array = result.get("part_effects", [])
	for effect in effects:
		if combat_parts.has(str(effect.id)):
			combat_parts[str(effect.id)].activated = true
			combat_parts[str(effect.id)].queue_redraw()
	magazine_view.impact_active = not effects.is_empty() or int(result.get("focus_damage", 0)) > 0 or int(result.get("math", {}).get("boost", 0)) > 0
	magazine_view.queue_redraw()
	preview_label.text = "%s → %s  −%d" % [AmmoVisual.SHORT[str(result.id)], Forecast.tag(int(result.target)), int(result.damage)]
	if not effects.is_empty():
		preview_label.text += " · %s %s" % [Content.PARTS[str(effects[0].id)].name, effects[0].label]
	if int(result.get("focus_damage", 0)) > 0:
		preview_label.text += " · 집중 +%d" % int(result.focus_damage)
	elif int(result.get("math", {}).get("boost", 0)) > 0:
		preview_label.text += " · 증폭 +%d" % int(result.math.boost)

func _update_combat_parts() -> void:
	for id in combat_parts:
		var view = combat_parts[id]
		view.ready_slots = PartFeedback.slots(next_forecast, str(id))
		view.shot_count = 0 if next_forecast.get("random", false) or PartFeedback.PASSIVE.has(id) else next_forecast.get("shots", []).size()
		view.get_parent().tooltip_text = str(Content.PARTS[id].name) + "\n" + PartFeedback.readiness(next_forecast, str(id)) + "\n누르면 조건과 대가 보기"
		view.queue_redraw()

func _combat_part_details(id: String) -> void:
	if busy: return
	var column := _dialog(str(Content.PARTS[id].name), true)
	column.name = "CombatPartDetails"
	_label(column, str(Content.PARTS[id].name), 26, PartCardView.COLORS[id])
	_label(column, PartFeedback.readiness(next_forecast, id), 20, ACCENT)
	_label(column, str(Content.PARTS[id].text), 19)
	var downside := str(Content.PARTS[id].get("downside", ""))
	if not downside.is_empty(): _label(column, "대가 · " + downside, 19, DANGER)
	_label(column, "아이콘 아래 칸은 이번 발사의 탄환 순서입니다. 밝은 칸에서 발동을 예상하며, 실제 발동 시 아이콘과 해당 탄이 함께 빛납니다.", 17, MUTED)

func _encounter_debrief(parent: Node, state: Dictionary) -> void:
	var current := PartFeedback.encounter_state(state)
	var report := RunInsight.combat_report(current)
	var row := _row(parent)
	row.name = "EncounterDebrief"
	var summary := _label(row, "교전 기록 · %d발 / %d기 처치" % [report.shots, report.kills], 18, MUTED)
	summary.name = "EncounterReport"
	for item in PartFeedback.highlights(current):
		var text := _label(row, str(item.text), 18, ACCENT)
		text.name = "BuildHighlight_" + str(item.id)
		text.tooltip_text = "한 탄환에 여러 타격이 있어도 발동은 1발로 기록합니다. 발동 횟수를 추가 HP 피해로 합산하지 않습니다."
	var details := _button(row, "기록", "encounter_record", _encounter_record.bind(current))
	details.autowrap_mode = TextServer.AUTOWRAP_OFF
	details.size_flags_horizontal = Control.SIZE_SHRINK_END
	details.custom_minimum_size = Vector2(64, 40)

func _encounter_record(state: Dictionary) -> void:
	var column := _dialog("이번 교전 기록")
	_label(column, RunInsight.combat_report_line(state), 20, ACCENT)
	for event in state.get("history", []):
		if str(event.get("action", "")) != "fire": continue
		for shot in event.get("detail", {}).get("results", []):
			_label(column, str(shot.get("text", "")), 18)

func _skip_animation() -> void:
	if busy and is_instance_valid(battle_view): battle_view.fast_forward = true

func _dialog(title: String, compact: bool = false) -> VBoxContainer:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.min_size = Vector2i(520, 240) if compact else Vector2i(720, 480)
	dialog.dialog_hide_on_ok = true
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(530, 190) if compact else Vector2(780, 500)
	dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	column.set_meta("dialog", dialog)
	scroll.add_child(column)
	dialog.popup_centered.call_deferred(Vector2i(580, 330) if compact else Vector2i(820, 640))
	return column

var workspace_return_focus: WeakRef

func _workspace(title: String, subtitle: String = "") -> VBoxContainer:
	_close_workspace()
	var prior := get_viewport().gui_get_focus_owner()
	if prior != null: workspace_return_focus = weakref(prior)
	var overlay := PanelContainer.new()
	overlay.name = "WorkspaceOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := _style(Color("101920"))
	backdrop.set_corner_radius_all(0)
	backdrop.set_border_width_all(0)
	overlay.add_theme_stylebox_override("panel", backdrop)
	add_child(overlay)
	workspace_overlay = overlay
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	overlay.add_child(margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 12)
	margin.add_child(frame)
	var header_panel := PanelContainer.new()
	header_panel.name = "WorkspaceHeader"
	header_panel.add_theme_stylebox_override("panel", _style(Color("17242c")))
	frame.add_child(header_panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header_panel.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	_label(titles, title, 30, ACCENT)
	if not subtitle.is_empty():
		_label(titles, subtitle, 16, MUTED)
	var close := _button(header, "닫기", "workspace_close", _close_workspace)
	close.custom_minimum_size = Vector2(112, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	var scroll := ScrollContainer.new()
	scroll.name = "WorkspaceScroll"
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	column.set_meta("dialog", overlay)
	scroll.add_child(column)
	_focus_control.call_deferred(close)
	_workspace_focus_chain.call_deferred()
	return column

func _workspace_focus_chain() -> void:
	if not is_instance_valid(workspace_overlay): return
	var controls: Array[Control] = []
	for item in workspace_overlay.find_children("*", "Control", true, false):
		if not item.is_visible_in_tree() or item.focus_mode != Control.FOCUS_ALL: continue
		if item is BaseButton and item.disabled: continue
		controls.append(item)
	for i in range(controls.size()):
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[(i + controls.size() - 1) % controls.size()])

func _close_workspace() -> void:
	if is_instance_valid(workspace_overlay):
		workspace_overlay.hide()
		workspace_overlay.queue_free()
	workspace_overlay = null
	if workspace_return_focus != null:
		var prior = workspace_return_focus.get_ref()
		if is_instance_valid(prior) and prior.is_visible_in_tree(): prior.grab_focus()
	workspace_return_focus = null

func _apply_preferences() -> void:
	presentation_speed = preferences.motion_scale()
	if ui_theme != null:
		ui_theme.default_font_size = _scaled(20)
	redraw.call_deferred()

func _guide() -> void:
	if busy:
		return
	preferences.set_value("guide_seen", true)
	var column := _dialog("처음 등반 · 세 번의 판단")
	column.name = "FirstGuide"
	var steps := [
		["1", "탄환을 고른다", "아이콘의 큰 수치는 피해, 방패 수치는 관통입니다. 같은 탄환 두 장은 빛나는 결합 표시가 있을 때 서로 끌어 압축할 수 있습니다."],
		["2", "순서를 읽는다", "탄창은 왼쪽부터 발사합니다. 증폭은 뒤 2발, 화상은 전진 직전, 전이는 다른 생존 적에게 적용됩니다."],
		["3", "확정하고 쏜다", "예상 처치와 안전 거리를 확인한 뒤 확정합니다. 발사와 재장전 뒤에는 적이 접근하므로 턴 수까지 계산하세요."],
	]
	for entry in steps:
		var panel := _panel(column)
		var row := _row(panel)
		var badge := _label(row, str(entry[0]), 34, ACCENT)
		badge.custom_minimum_size.x = 48
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		_label(copy, str(entry[1]), 24, INK)
		_label(copy, str(entry[2]), 17, MUTED)
	var flow := _panel(column)
	_label(flow, "도시 흐름", 22, ACCENT)
	_label(flow, "경로 선택  →  전투/보급/무기고  →  계층 관문  →  35층 정점", 19)
	_label(flow, "처음에는 7교전 기초 훈련으로 탄환 효과만 익힐 수 있습니다.", 17, MUTED)

func _settings() -> void:
	if busy:
		return
	var column := _dialog("설정 · 읽기와 진행", true)
	column.name = "SettingsDialog"
	var text_row := _row(column)
	_label(text_row, "글자 크기", 20).custom_minimum_size.x = 170
	var scale_option := OptionButton.new()
	scale_option.name = "TextScaleSetting"
	scale_option.custom_minimum_size = Vector2(260, 48)
	for entry in [["작게 · 90%", 0.9], ["기본 · 100%", 1.0], ["크게 · 110%", 1.1]]:
		scale_option.add_item(entry[0])
		scale_option.set_item_metadata(scale_option.item_count - 1, entry[1])
		if is_equal_approx(float(entry[1]), float(preferences.data.text_scale)):
			scale_option.select(scale_option.item_count - 1)
	text_row.add_child(scale_option)
	scale_option.item_selected.connect(func(index: int):
		preferences.set_value("text_scale", float(scale_option.get_item_metadata(index)))
		_apply_preferences()
	)
	var motion_row := _row(column)
	_label(motion_row, "전투 연출", 20).custom_minimum_size.x = 170
	var motion_option := OptionButton.new()
	motion_option.name = "MotionSetting"
	motion_option.custom_minimum_size = Vector2(260, 48)
	for entry in [["기본", "normal"], ["빠르게", "fast"], ["즉시", "instant"]]:
		motion_option.add_item(entry[0])
		motion_option.set_item_metadata(motion_option.item_count - 1, entry[1])
		if str(entry[1]) == str(preferences.data.motion):
			motion_option.select(motion_option.item_count - 1)
	motion_row.add_child(motion_option)
	motion_option.item_selected.connect(func(index: int):
		preferences.set_value("motion", str(motion_option.get_item_metadata(index)))
		_apply_preferences()
	)
	var hint_toggle := CheckButton.new()
	hint_toggle.name = "ContextHintsSetting"
	hint_toggle.text = "상황 도움말 표시"
	hint_toggle.button_pressed = bool(preferences.data.hints)
	hint_toggle.custom_minimum_size.y = 48
	hint_toggle.toggled.connect(func(enabled: bool):
		preferences.set_value("hints", enabled)
		_apply_preferences()
	)
	column.add_child(hint_toggle)
	_label(column, "탄환 수치, 예상 결과, 비용과 위험 표시는 도움말을 꺼도 유지됩니다.", 16, MUTED)
	_button(column, "기본 설정으로 복원", "settings_reset", func():
		preferences.reset()
		column.get_meta("dialog").queue_free()
		_apply_preferences()
	)

func _part_gallery() -> void:
	if busy:
		return
	var column := _dialog("파츠 아이콘 · 20종 미리보기")
	column.name = "PartGallery"
	_label(column, "형태와 색으로 먼저 구분하고, 수치와 설명은 필요할 때만 읽습니다.", 18, MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for id in Content.PARTS:
		if id == "none": continue
		var panel := _panel(grid)
		panel.get_parent().custom_minimum_size = Vector2(370, 144)
		var view := PartCardView.new()
		view.name = "PartGallery_" + id
		view.custom_minimum_size = Vector2(350, 128)
		view.setup(id, model.s, Content.has_part(model.s, id), false)
		panel.add_child(view)

func _rules() -> void:
	if busy: return
	var column := _dialog("순서를 설계하는 법")
	_label(column, "누른 순서대로 · 피해와 관통", 30, ACCENT)
	_label(column, "1. 피해는 타격당 기본 화력, 관통은 무시하는 장갑입니다. 장전한 순서대로 발사하며 확정 전에는 칸을 눌러 회수할 수 있습니다.")
	_label(column, "2. 보행자·쇄도·산개·압쇄는 한 탄창을 1턴에 연쇄 발사합니다. 증강은 1발을 쏘고, 주 표적을 처치하면 다음 탄도 이어 쏩니다. 한 번의 발사가 끝나면 1턴이 지나고 살아남은 적이 전진합니다.")
	_label(column, "3. 보행자는 전술탄 피해 +2, 회수탄 피해 +1. 쇄도는 같은 적의 주 타격 3회마다 추가 피해 4. 연발의 두 타격은 각각 세며 화상/전이는 세지 않습니다.")
	_label(column, "4. 산개는 탄환마다 살아 있는 적 중 무작위 표적을 선택합니다. 확률과 HP 범위가 예상이며 확정 결과가 아닙니다. 나머지는 가장 가까운 적부터 조준합니다.")
	_label(column, "5. 압쇄는 화상 턴당 피해 2와 전이 피해 3. 증강은 탄환 기본 피해/관통과 증폭/넉백/화상 피해/전이 강도 2배입니다. 연발은 2타, 증폭은 뒤 2발, 화상 기간은 유지합니다.")
	_label(column, "6. 증폭은 다음 2발에 적용하고 연발의 각 타격을 강화합니다. 화상은 전진 직전에 진행합니다. 실제 총기 수치와 효과는 탄환 카드에서 확인하세요.")
	_label(column, "7. 재장전마다 회수탄과 5장 패를 보충하고 교환 1회를 복구합니다. 예비 급탄기는 교환을 2회로 늘립니다. 넉백은 일반 탄창 총 2m, 증강은 4m까지입니다. 관문 용량 +2는 파츠와 독립적입니다.")
	_label(column, "8. 관문에서는 같은 일반탄 2장을 한 발로 압축할 수 있습니다. 이어진 두 칸, 앞쪽 결합부, 뒤쪽 마개가 각각 공간과 자동 발사 위치를 보여 줍니다.")
	_label(column, "9. 같은 일반탄 두 발을 전투 중 임시 압축하면 압축 코어 1개를 씁니다. 확정 전에 회수하면 두 발과 코어가 돌아오며, 코어는 상점에서 최대 2개까지 충전합니다.")
	_label(column, "10. 상층 부유체는 3턴마다 다른 적을 2m 당기고, 흡수 구체는 직접 타격으로 배리어를 먼저 소모하며, 태세 드론은 전진 뒤 장갑 4와 0을 교대합니다.")
	_label(column, "11. 도시 등반은 5계층 35층. 파츠는 최대 5개를 함께 장착하고 금색 코어는 하나만 사용합니다. 청록 ▲는 이점, 적색 ▼는 패널티입니다.")

func _weapon_details(id: String) -> void:
	if busy: return
	var spec: Dictionary = Content.GUNS[id]
	var column := _dialog(spec.name + " · " + spec.role, true)
	column.name = "WeaponDetails"
	_label(column, spec.identity, 24, WeaponView.COLORS[id])
	_label(column, spec.text, 19)
	_label(column, "%d칸 → 최대 %d칸 · 선택한 무기는 이번 등반 끝까지 유지" % [spec.capacity, int(spec.capacity) + 2], 18, MUTED)
	_label(column, spec.recommendation, 19, ACCENT)
	if id == "scatter":
		_label(column, "탄환마다 생존 표적을 다시 무작위 선택합니다. 연발의 두 타격은 같은 표적입니다. 피해가 흩어지는 비용을 큰 탄창으로 보상하며, 예측은 HP 범위와 처치 확률을 보여 줍니다.", 18)
	elif id == "heavy":
		_label(column, "소이의 화상은 기간을 유지하며 턴당 2피해, 전격은 다른 생존 적에게 3피해를 전달합니다. 물리탄에는 별도 관통 보정이 없습니다.", 18)
	elif id == "burst":
		_label(column, "적별 주 타격을 셉니다. 3번째 타격 후 추가 피해 4, 다시 0부터 누적합니다. 재장전 후에도 진도 유지, 표적 처치 시 진도 종료. 전이와 화상은 집계하지 않습니다.", 18)
	elif id == "amplifier":
		_label(column, "기본 피해/관통 2배 · 증폭 +4 · 충격 4m · 화상 턴당 2 · 전이 4. 타격 수와 지속 기간은 유지합니다. 주 표적 처치 시 다음 탄도 이어 쏘며, 생존 표적에서 멈춘 뒤 적이 전진합니다.", 18)
	var loadout := selected_loadout_id if page == "loadout" else (str(campaign.s.loadout) if campaign != null else "balanced")
	var deck: Array = Content.start_deck(id) if loadout == "balanced" else CampaignContent.LOADOUTS[loadout].deck
	_label(column, "도시 시작 보급 / " + CampaignContent.LOADOUTS[loadout].name, 20, ACCENT)
	_label(column, RunInsight.deck_summary(deck), 18)
	_label(column, "기초 훈련에서는 무기와 관계없이 같은 순서로 탄환을 배웁니다.", 16, MUTED)

func _inspect_slot(index: int) -> void:
	if busy or not is_instance_valid(calculation_label): return
	selected_slot = index
	magazine_view.selected_index = index
	magazine_view.queue_redraw()
	_update_slot_actions()
	if full_forecast.shots.is_empty():
		calculation_label.text = Readability.explain({}) if model.s.phase == "plan" else "다음 탄창을 장전하세요."
	elif index >= full_forecast.shots.size():
		calculation_label.text = "%d번 · 전투가 먼저 끝나 이 탄은 발사되지 않습니다." % (index + 1)
	else:
		var shot: Dictionary = full_forecast.shots[index]
		calculation_label.add_theme_color_override("font_color", INK)
		calculation_label.text = "%d번 %s → " % [index + 1, Content.AMMO[shot.id].name] + Readability.explain(shot)
		calculation_label.text = ("이번 발사\n" if int(shot.get("action", 0)) == 0 else "%d번째 발사 시 · 중간 재장전 없음\n" % (int(shot.action) + 1)) + calculation_label.text
		var sequence_note := Forecast.note(full_forecast, index)
		if not sequence_note.is_empty(): calculation_label.text += "\n순서 효과 · " + sequence_note

func _slot_action(index: int) -> void:
	if busy: return
	_inspect_slot(index)

func _slot_details() -> void:
	if busy: return
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	if stack.is_empty(): return
	_inspect_slot(clampi(selected_slot, 0, stack.size() - 1))
	var column := _dialog("탄환 계산 · %d번" % (selected_slot + 1), true)
	column.name = "SlotDetails"
	_label(column, calculation_label.text, 19)
	_label(column, str(Content.AMMO[stack[selected_slot]].text), 17, MUTED)

func _update_slot_actions() -> void:
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	selected_slot = clampi(selected_slot, 0, maxi(0, stack.size() - 1))
	for item in [["slot_previous", not model.can_move_planned(selected_slot, selected_slot - 1)], ["slot_next", not model.can_move_planned(selected_slot, selected_slot + 1)], ["remove_selected", model.s.phase != "plan" or stack.is_empty()]]:
		var button := find_child(str(item[0]), true, false) as Button
		if button != null: button.disabled = busy or bool(item[1])

func _move_slot(from: int, to: int) -> void:
	if busy: return
	if model.move_planned(from, to):
		selected_slot = to
		_changed()

func _remove_slot(index: int) -> void:
	if busy or index < 0 or index >= model.s.plan.size(): return
	var id := str(model.s.plan[index])
	if model.remove_planned(index):
		_forget_hand_token(id)
		_changed()

func _forget_hand_token(id: String) -> void:
	for i in range(used_hand_tokens.size() - 1, -1, -1):
		var token := str(used_hand_tokens[i])
		if token == "load_" + id or token.begins_with("load_" + id + "_"):
			used_hand_tokens.remove_at(i)
			break

func _exchange_dialog() -> void:
	if busy or model.s.phase != "plan" or model.s.exchange_left <= 0: return
	var column := _dialog("전술탄 1장 교환", true)
	column.name = "ExchangeDialog"
	_label(column, "다음 탄: " + _ammo_names(model.s.draw.slice(0, 1)), 20, ACCENT)
	var ids: Array = []
	for id in model.s.hand:
		if ids.has(id): continue
		ids.append(id)
		_button(column, Content.AMMO[id].name + " 교환", "exchange_" + id, func():
			if not busy and model.exchange(id):
				column.get_meta("dialog").queue_free()
				_changed()
		, model.available(id) <= 0)

func _details() -> void:
	if busy: return
	var column := _dialog("전투 정보")
	column.name = "CombatDetails"
	var encounter: Dictionary = Content.ENCOUNTERS[int(model.s.floor)]
	if campaign != null: encounter = {"name": campaign.node().name, "text": CampaignContent.hint(campaign.node())}
	_label(column, encounter.name, 26, ACCENT)
	_label(column, encounter.text, 18, MUTED)
	var part_names := PackedStringArray()
	for id in Content.equipped_parts(model.s): part_names.append(str(Content.PARTS[id].name))
	_label(column, "시드 %s · %s\n파츠 %d/%d · %s" % [str(model.s.seed), Content.GUNS[model.s.gun].text, part_names.size(), Content.MAX_EQUIPPED_PARTS, " · ".join(part_names) if not part_names.is_empty() else "없음"], 18)
	_label(column, "적 정보", 22, ACCENT)
	for e in model.s.enemies:
		_label(column, "%s · HP %d/%d · 장갑 %d · 화상 %d\n거리 %dm · 접근 %dm\n%s" % [e.name, e.hp, e.max_hp, e.def, e.burn, e.distance, e.speed, Content.enemy_rule(e)], 18)
	_label(column, "탄환 · 현재 총기/파츠 반영", 22, ACCENT)
	var ids: Array = ["basic"]
	for id in model.s.deck:
		if not ids.has(id): ids.append(id)
	for id in ids:
		_label(column, _ammo_stats(id), 19, AmmoVisual.COLORS[id])
		_label(column, "재장전 시 %d발 공급" % model.supply_capacity() if id == "basic" else Readability.description(id, model.s), 17, MUTED)
	_label(column, "덱 %d장 · 남은 덱 %d · 사용탄 %d\n%s" % [model.s.deck.size(), model.s.draw.size(), model.s.discard.size(), _ammo_names(model.s.deck)], 18)
	_label(column, "최근 결과\n" + str(model.s.message), 18, MUTED)

func _enemy_details(index: int) -> void:
	if busy or index < 0 or index >= model.s.enemies.size(): return
	var e: Dictionary = model.s.enemies[index]
	var column := _dialog("적 정보 · 자동 조준 유지", true)
	column.name = "EnemyDetails"
	column.set_meta("enemy_index", index)
	_label(column, "%s · %s" % [Forecast.tag(index), e.name], 26, ACCENT)
	_label(column, "HP %d/%d   장갑 %d   화상 %d" % [e.hp, e.max_hp, e.def, e.burn], 21)
	_label(column, "거리 %dm · 다음 접근 %dm" % [e.distance, e.speed], 19, MUTED)
	if model.s.gun == "burst":
		_label(column, "집중 %d/3 · 같은 적 3회 적중마다 추가 피해 4\n재장전 후에도 유지 · 보호에 막힌 타격은 누적되지만 추가 피해는 막힙니다." % int(e.get("focus_hits", 0)), 18, ACCENT)
	var rule := Content.enemy_rule(e)
	if not rule.is_empty():
		var rule_panel := _panel(column)
		_label(rule_panel, "행동 규칙", 17, ACCENT)
		_label(rule_panel, rule, 18)
	if combat_forecast.get("random", false):
		var predicted: Dictionary = combat_forecast.enemies[index]
		_label(column, "무작위 예상 HP %d~%d · 처치 %d%%" % [predicted.hp_min, predicted.hp_max, floori(minf(1.0, float(predicted.kill_probability) + 0.0000001) * 100)], 18, ACCENT)
		_label(column, "탄환마다 그 시점에 살아 있는 적 중 같은 확률로 선택합니다.", 18, MUTED)
		return
	var hits: PackedStringArray = []
	for i in range(combat_forecast.get("shots", []).size()):
		var shot: Dictionary = combat_forecast.shots[i]
		if shot.target == index: hits.append("%d발 %s" % [i + 1, Forecast.outcome(shot)])
		for other in shot.get("secondary", []):
			if int(other.target) == index: hits.append("%d발 %s −%d" % [i + 1, "확산" if other.get("kind", "arc") == "spread" else "전이", other.damage])
	_label(column, "연속 사격 예상: " + (" · ".join(hits) if not hits.is_empty() else "피격 없음"), 18, ACCENT)

func _reinforcement_details(index: int) -> void:
	if busy or index < 0 or index >= model.s.get("reinforcements", []).size(): return
	var enemy: Dictionary = model.s.reinforcements[index]
	var column := _dialog("증원 정보", true)
	column.name = "ReinforcementDetails"
	_label(column, "대기 %d · %s" % [index + 1, enemy.name], 26, Color("63dce8"))
	_label(column, "HP %d   장갑 %d   진입 %dm" % [enemy.hp, enemy.def, enemy.distance], 20)
	_label(column, "전열이 2기 이하가 되면 빈 자리에 투입됩니다.", 18, ACCENT)
	var rule := Content.enemy_rule(enemy)
	if not rule.is_empty(): _label(column, rule, 18, MUTED)

func _developer() -> void:
	campaign = null
	var column := _dialog("개발자 테스트 · 기존 저장 보존")
	_label(column, "화면과 규칙을 즉시 확인하는 연습", 26)
	var ux_row := _row(column)
	_button(ux_row, "처음 안내", "debug_first_guide", func():
		column.get_meta("dialog").hide()
		column.get_meta("dialog").queue_free()
		_guide()
	)
	_button(ux_row, "설정·접근성", "debug_settings", func():
		column.get_meta("dialog").hide()
		column.get_meta("dialog").queue_free()
		_settings()
	)
	_button(ux_row, "파츠 아이콘", "debug_part_cards", func():
		column.get_meta("dialog").hide()
		column.get_meta("dialog").queue_free()
		_part_gallery()
	)
	var weapon_row := GridContainer.new()
	weapon_row.columns = 2
	column.add_child(weapon_row)
	for id in Content.GUNS:
		_button(weapon_row, Content.GUNS[id].name + " · 같은 대열 조합 비교", "debug_weapon_" + id, func():
			_debug_weapon(id)
			column.get_meta("dialog").queue_free()
		)
	_button(column, "무기 5종 선택 화면", "debug_weapon_selection", func():
		column.get_meta("dialog").queue_free()
		preparation_training = false
		page = "loadout"
		redraw()
	)
	var city_row := GridContainer.new()
	city_row.columns = 3
	column.add_child(city_row)
	for entry in [["도시 분기 맵", "map"], ["크레딧 무기고", "shop"], ["탄환 보급", "supply"], ["선택 이벤트", "event"], ["관문 압축 선택", "gate"], ["도시 승리 정산", "ending"], ["도시 패배 정산", "loss"], ["도시 전투 보상", "reward"], ["덱·장비", "deck"], ["기록실", "archive"]]:
		_button(city_row, entry[0], "debug_city_" + entry[1], func():
			column.get_meta("dialog").hide()
			_debug_city(entry[1])
			column.get_meta("dialog").queue_free()
		)
	_button(column, "압축탄 장전 UI", "debug_compressed_ammo", func():
		model.start("burst", 731042)
		model.s.floor = 6
		model.begin_encounter()
		model.s.deck = ["precise_c", "pierce_c", "charge_c", "push_c", "arc_c", "bore_c", "pierce", "charge"]
		model.s.hand = ["precise_c", "pierce_c", "charge_c", "push_c", "arc_c"]
		model.s.draw = ["bore_c", "pierce", "charge"]
		model.s.discard = []
		model.s.plan = []
		model.s.plan_load_order = []
		model.load_round("push_c")
		model.load_round("precise_c")
		# Show all three physical constraints in one real magazine: first fitting,
		# a two-cell body, and the last fitting.
		model.load_round("pierce_c")
		debug_session = true
		selected_slot = 0
		inspect_slots = false
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	_button(column, "전투 중 임시 압축 UI", "debug_field_compression", func():
		model.start("single", 731042)
		model.s.floor = 4
		model.begin_encounter()
		model.s.deck = ["charge", "charge", "precise", "precise", "arc", "bore", "push", "pierce"]
		model.s.hand = ["charge", "charge", "precise", "precise", "arc"]
		model.s.draw = ["bore", "push", "pierce"]
		model.s.discard = []
		model.s.plan = []
		model.s.plan_load_order = []
		debug_session = true
		selected_slot = 0
		inspect_slots = false
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)

	_button(column, "3속성 탄환 전체", "debug_icon_cards", func():
		model.start("single", 731042)
		model.s.floor = 6
		model.begin_encounter()
		model.s.deck = ["bore", "pierce", "precise", "charge", "push", "arc"]
		model.s.hand = model.s.deck.duplicate()
		model.s.draw = []
		model.s.discard = []
		debug_session = true
		selected_slot = 0
		inspect_slots = false
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	_button(column, "상층 적 3규칙", "debug_enemy_locks", func():
		model.start("single", 731042)
		model.s.floor = 5
		model.begin_encounter()
		model.s.enemies = [
			{"kind": "caster", "name": Content.ENEMY_NAMES.caster, "hp": 10, "max_hp": 10, "def": 1, "speed": 1, "distance": 14, "burn": 0, "charge": 2, "charge_max": 3, "charge_pull": 2},
			{"kind": "absorber", "name": Content.ENEMY_NAMES.absorber, "hp": 13, "max_hp": 13, "def": 1, "speed": 1, "distance": 21, "burn": 0, "barrier": 2, "barrier_max": 2},
			{"kind": "stance", "name": Content.ENEMY_NAMES.stance, "hp": 16, "max_hp": 16, "def": 4, "speed": 2, "distance": 27, "burn": 0, "stance": true, "stance_def": 4, "stance_closed": true},
		]
		model.s.deck = ["precise_c", "pierce", "bore", "charge", "precise", "arc", "push", "pierce"]
		model.s.hand = ["precise_c", "pierce", "bore", "charge", "arc"]
		model.s.draw = ["push", "precise", "pierce"]
		model.s.discard = []
		debug_session = true
		selected_slot = 0
		inspect_slots = false
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	_button(column, "다수전 · 증원 UI", "debug_horde_reinforcement", func():
		model.start("single", 731042)
		model.s.floor = 4
		model.begin_encounter()
		model.s.enemies = [
			{"kind": "runner", "name": Content.ENEMY_NAMES.runner, "hp": 4, "max_hp": 4, "def": 0, "speed": 2, "distance": 14, "burn": 0},
			{"kind": "evader", "name": Content.ENEMY_NAMES.evader, "hp": 4, "max_hp": 4, "def": 0, "speed": 2, "distance": 18, "burn": 0, "weakness": "electric"},
			{"kind": "caster", "name": Content.ENEMY_NAMES.caster, "hp": 5, "max_hp": 5, "def": 0, "speed": 1, "distance": 22, "burn": 0, "charge": 1, "charge_max": 3, "charge_pull": 2},
			{"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": 7, "max_hp": 7, "def": 2, "speed": 1, "distance": 26, "burn": 0},
		]
		model.s.reinforcements = [
			{"kind": "runner", "name": Content.ENEMY_NAMES.runner, "hp": 4, "max_hp": 4, "def": 0, "speed": 2, "distance": 25, "burn": 0},
			{"kind": "absorber", "name": Content.ENEMY_NAMES.absorber, "hp": 6, "max_hp": 6, "def": 1, "speed": 1, "distance": 28, "burn": 0, "barrier": 2, "barrier_max": 2},
			{"kind": "evader", "name": Content.ENEMY_NAMES.evader, "hp": 4, "max_hp": 4, "def": 0, "speed": 2, "distance": 30, "burn": 0, "weakness": "electric"},
			{"kind": "stance", "name": Content.ENEMY_NAMES.stance, "hp": 7, "max_hp": 7, "def": 4, "speed": 2, "distance": 32, "burn": 0, "stance": true, "stance_def": 4, "stance_closed": true},
		]
		model.s.encounter_total = 8
		model.s.deployed = 4
		model.s.wave = 1
		model.assign_opening_lanes()
		model.s.deck = ["charge", "precise", "arc", "pierce", "bore", "push", "charge", "precise"]
		model.s.hand = ["charge", "precise", "arc", "pierce", "bore"]
		model.s.draw = ["push", "charge", "precise"]
		model.s.discard = []
		for id in ["charge", "precise", "arc", "pierce"]: model.load_round(id)
		debug_session = true
		selected_slot = 0
		inspect_slots = false
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	var lessons := _row(column)
	for entry in [["피해·증폭 연습", 0], ["장갑·관통 연습", 1], ["화상 연습", 2]]:
		_button(lessons, entry[0], "debug_lesson_" + str(entry[1]), func():
			model.start("single", 731042, true)
			for floor_index in range(1, int(entry[1]) + 1):
				model.s.deck.append_array(Content.COURSE_GRANTS[floor_index])
			model.s.floor = entry[1]
			model.begin_encounter()
			debug_session = true
			selected_slot = 0
			inspect_slots = false
			page = "run"
			column.get_meta("dialog").queue_free()
			redraw()
		)
	_button(column, "화상 전진 정산", "debug_burn_tick", func():
		model.start("single", 731042)
		model.s.floor = 2
		model.begin_encounter()
		model.s.enemies = [{"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": 8, "max_hp": 8, "def": 1, "speed": 2, "distance": 6, "burn": 0}]
		model.s.deck = ["bore", "charge", "precise", "pierce", "push", "arc"]
		model.s.hand = model.s.deck.slice(0, 5)
		model.s.draw = ["arc"]
		model.s.discard = []
		model.load_round("bore")
		model.confirm()
		debug_session = true
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	_button(column, "조합 결과 연습", "debug_combo_forecast", func():
		model.start("single", 731042)
		model.s.floor = 6
		model.s.equipped_parts = ["supply", "opening", "sequencer"]
		model.s.part = "none"
		model.begin_encounter()
		model.s.enemies = [
			{"kind": "runner", "name": Content.ENEMY_NAMES.runner, "hp": 30, "max_hp": 30, "def": 1, "speed": 2, "distance": 18, "burn": 0},
			{"kind": "evader", "name": Content.ENEMY_NAMES.evader, "hp": 6, "max_hp": 6, "def": 0, "speed": 2, "distance": 21, "burn": 0},
		]
		model.s.deck = ["bore", "push", "charge", "precise", "arc"]
		model.s.hand = model.s.deck.duplicate()
		model.s.draw = []
		model.s.discard = []
		for id in ["bore", "push", "charge", "precise", "arc"]: model.load_round(id)
		debug_session = true
		selected_slot = 3
		inspect_slots = true
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	_button(column, "보상·빌드 판단", "debug_reward_build", func():
		model.start("single", 731042)
		model.s.floor = 4
		model.begin_encounter()
		model.s.enemies = [{"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": 9, "max_hp": 9, "def": 1, "speed": 1, "distance": 20, "burn": 0}]
		model.s.deck = ["charge", "precise", "bore", "bore", "pierce", "push", "arc"]
		model.s.hand = model.s.deck.slice(0, 5)
		model.s.draw = ["push", "arc"]
		model.s.discard = []
		model.load_round("charge")
		model.load_round("precise")
		model.confirm()
		model.fire()
		model.fire()
		debug_session = true
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	_button(column, "다수전 표적 전환 연습", "debug_multi_target", func():
		model.start("burst", 731042)
		model.s.floor = 3
		model.begin_encounter()
		model.s.enemies[0].distance = 16
		model.s.enemies[0].hp = 20
		model.s.enemies[0].max_hp = 20
		model.s.enemies[1].distance = 17
		model.s.enemies[1].hp = 4
		model.s.enemies[1].max_hp = 4
		model.s.enemies[1].def = 0
		model.s.hand = ["push", "charge", "precise", "bore", "arc"]
		for id in ["bore", "push", "precise", "charge"]: model.load_round(id)
		debug_session = true
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	for entry in [["통합 장전 화면", 0, "plan"], ["보상 선택 화면", 0, "reward"], ["최종 복합 교전", 6, "plan"]]:
		_button(column, entry[0], "debug_" + str(entry[1]) + entry[2], func():
			model.start("single", 731042)
			model.s.floor = entry[1]
			model.begin_encounter()
			model.s.phase = entry[2]
			debug_session = true
			page = "run"
			column.get_meta("dialog").queue_free()
			redraw()
		)

func _campaign_action(command: String, value: Variant = "", extra: String = "") -> void:
	if busy or campaign == null: return
	var accepted := false
	match command:
		"enter": accepted = campaign.enter(int(value))
		"reward": accepted = campaign.reward(str(value), extra)
		"gate": accepted = campaign.gate(str(value), extra)
		"buy": accepted = campaign.buy(int(value))
		"buy_compressor": accepted = campaign.buy_compressor_charge()
		"reroll": accepted = campaign.reroll()
		"shop_refine": accepted = campaign.shop_refine(str(value))
		"equip": accepted = campaign.equip(str(value))
		"replace_part": accepted = campaign.replace_part(str(value), extra)
		"dismantle": accepted = campaign.dismantle(str(value))
		"resolve": accepted = campaign.resolve(str(value), extra)
		"leave": accepted = campaign.leave()
	if accepted:
		model = campaign.model
		selected_slot = 0
		inspect_slots = false
		previous_forecast = {}
		_changed()

func _city_archive() -> void:
	var progress = Campaign.new()
	progress.restore()
	campaign = progress
	city_ui.ui = self
	city_ui.campaign = campaign
	city_ui.archive()

func _debug_weapon(id: String) -> void:
	hand_layout_key = ""
	show_full_forecast = false
	campaign = null
	model.start(id, 731042)
	model.s.floor = 6
	model.s.deck = ["charge", "precise", "pierce", "arc", "push", "bore", "charge", "precise", "pierce", "arc"]
	model.s.hand = model.s.deck.slice(0, 5)
	model.s.draw = model.s.deck.slice(5)
	model.s.discard = []
	model.s.enemies = [
		{"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": 30, "max_hp": 30, "def": 3, "speed": 1, "distance": 18, "burn": 0},
		{"kind": "runner", "name": Content.ENEMY_NAMES.runner, "hp": 12, "max_hp": 12, "def": 0, "speed": 2, "distance": 20, "burn": 0},
		{"kind": "evader", "name": Content.ENEMY_NAMES.evader, "hp": 8, "max_hp": 8, "def": 1, "speed": 2, "distance": 22, "burn": 0},
	]
	for round_id in ["charge", "precise", "arc"]: model.load_round(round_id)
	debug_session = true
	selected_slot = 0
	inspect_slots = false
	previous_forecast = {}
	page = "run"
	redraw()

func _debug_city(kind: String) -> void:
	hand_layout_key = ""
	show_full_forecast = false
	debug_session = true
	campaign = Campaign.new()
	campaign.start("burst", 731042)
	campaign.s.credits = 75
	if kind == "shop":
		campaign.s.floor = 3
		campaign.s.node = 301
		campaign.enter(401)
	elif kind == "supply":
		campaign.s.floor = 2
		campaign.s.node = 201
		campaign.enter(301)
	elif kind == "event":
		campaign.s.floor = 1
		campaign.s.node = 101
		campaign.enter(202)
	elif kind == "reward":
		campaign.enter(101)
		for enemy in campaign.model.s.enemies: enemy.hp = 0
		campaign.model.s.phase = "reward"
		campaign.sync_combat()
	elif kind in ["gate", "ending"]:
		if kind == "ending": campaign.s.region = 4
		var floors := int(CampaignContent.info(int(campaign.s.region)).floors)
		campaign.s.floor = floors - 1
		campaign.s.node = int(campaign.s.region) * 10000 + (floors - 1) * 100 + 1
		campaign.enter(int(campaign.s.region) * 10000 + floors * 100 + 1)
		for enemy in campaign.model.s.enemies: enemy.hp = 0
		campaign.model.s.phase = "reward"
		campaign.sync_combat()
		campaign.reward("skip")
	elif kind == "loss":
		campaign.s.floor = 4
		campaign.s.clears = 3
		campaign.model.s.enemies[0].distance = 0
		campaign.model.s.phase = "lost"
		campaign.s.phase = "lost"
		campaign.settle(false)
	elif kind == "deck":
		campaign.s.parts = ["capacitor", "rammer", "sequencer", "opening", "field_press", "overbore"]
		campaign.s.equipped_parts = ["capacitor", "rammer", "sequencer", "opening", "field_press"]
		campaign.model.s.equipped_parts = campaign.s.equipped_parts.duplicate()
		campaign.model.s.part = "none"
	model = campaign.model
	page = "run"
	redraw()
	if kind == "deck": city_ui.deck.call_deferred()
	elif kind == "archive": city_ui.archive.call_deferred()
