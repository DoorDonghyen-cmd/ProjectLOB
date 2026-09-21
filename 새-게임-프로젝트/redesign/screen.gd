extends Control
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const BattleView = preload("res://redesign/battle_view.gd")
const MagazineView = preload("res://redesign/magazine_view.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const AmmoCardView = preload("res://redesign/ammo_card_view.gd")
const PartCardView = preload("res://redesign/part_card_view.gd")
const AmmoHandButton = preload("res://redesign/ammo_hand_button.gd")
const FieldCompressorView = preload("res://redesign/field_compressor_view.gd")
const Forecast = preload("res://redesign/forecast.gd")
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
const ACCENT := Color("a9dfbf")
const DANGER := Color("f2a38d")
var model = Model.new()
var campaign = null
var city_ui = CampaignUI.new()
var full_game_enabled := true
var loadout_option: OptionButton
var difficulty_option: SpinBox
var page := "menu"
var save_enabled := true
var debug_session := false
var body: VBoxContainer
var seed_input: LineEdit
var course_toggle: CheckButton
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
var last_presentation: Dictionary = {}
var ammo_inspector: Label
var inspected_ammo := "basic"
var combat_forecast: Dictionary = {}
var preferences = Preferences.new()
var ui_theme: Theme
var main_scroll: ScrollContainer

func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	preferences.load_preferences()
	if is_equal_approx(presentation_speed, 1.0):
		presentation_speed = preferences.motion_scale()
	ui_theme = Theme.new()
	ui_theme.default_font = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
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
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	main_scroll.add_child(margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if busy:
		_skip_animation()
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
	style.set_corner_radius_all(5)
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

func _hint(parent: Node, value: String) -> Label:
	if not bool(preferences.data.get("hints", true)):
		return null
	var hint := _label(parent, value, 17, MUTED)
	hint.name = "ContextHint"
	return hint

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
	_reset_scroll.call_deferred()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if page == "menu":
		_menu()
		return
	if campaign != null and campaign.s.phase != "combat":
		city_ui.render(self)
		return
	var top := _row(body)
	_label(top, "%s / %02d · 35" % [CampaignContent.info(int(campaign.s.region)).name, campaign.absolute_floor()] if campaign != null else "LAST ON BOARD   /   %02d · 07" % (int(model.s.floor) + 1), 26, ACCENT)
	for item in [["정보", "details", _details], ["규칙", "rules", _rules], ["설정", "settings", _settings], ["메뉴", "menu", _to_menu]]:
		var button := _button(top, item[0], item[1], item[2])
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size.x = 84
	var skip := _button(top, "연출 생략", "skip_animation", _skip_animation, true)
	skip.custom_minimum_size.x = 135
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.visible = busy
	var equipment := str(Content.GUNS[model.s.gun].name)
	var active_parts := Content.equipped_parts(model.s)
	if not active_parts.is_empty(): equipment += " · 파츠 %d/%d" % [active_parts.size(), Content.MAX_EQUIPPED_PARTS]
	if model.s.buff.has("dmg"): equipment += " · 증폭 %d발" % model.s.buff.dmg_left
	var status_panel := PanelContainer.new()
	status_panel.name = "CombatStatusBar"
	status_panel.custom_minimum_size.y = 48
	var status_style := _style(Color("17242c"))
	status_style.content_margin_top = 6
	status_style.content_margin_bottom = 6
	status_panel.add_theme_stylebox_override("panel", status_style)
	body.add_child(status_panel)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 14)
	status_panel.add_child(status)
	var identity_label := _label(status, "[%s]  \u00b7  %d\uce78" % [equipment, model.capacity()], 17, ACCENT)
	identity_label.name = "WeaponIdentity"
	identity_label.tooltip_text = str(Content.GUNS[model.s.gun].identity)
	identity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label(status, "%d\ud134" % int(model.s.turns), 16, MUTED).autowrap_mode = TextServer.AUTOWRAP_OFF
	_label(status, "\uc804\uc5f4 %d/4" % model.alive_count(), 16, INK).autowrap_mode = TextServer.AUTOWRAP_OFF
	var reserve_label := _label(status, "\uc99d\uc6d0 %d" % model.reserve_count(), 16, Color("63dce8") if model.reserve_count() > 0 else MUTED)
	reserve_label.name = "ReinforcementCount"
	reserve_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if campaign != null:
		_label(status, "\u25cf %d Cr" % int(campaign.s.credits), 16, ACCENT).autowrap_mode = TextServer.AUTOWRAP_OFF
		_label(status, "\u25c6 %d/%d" % [campaign.s.compressor_charges, campaign.MAX_COMPRESSOR_CHARGES], 16, Color("63dce8")).autowrap_mode = TextServer.AUTOWRAP_OFF
	if not save_error.is_empty():
		_label(body, save_error, 18, DANGER)
	match model.s.phase:
		"plan", "ready": _combat()
		"reward": _reward()
		"won", "lost": _ending()

func _reset_scroll() -> void:
	if is_instance_valid(main_scroll):
		main_scroll.scroll_vertical = 0
		main_scroll.scroll_horizontal = 0

func _menu() -> void:
	_label(body, "LAST ON BOARD", 48, ACCENT)
	_label(body, "빌린 총 하나, 다른 등반 방식. 순서를 만들고 35층을 오르세요.", 20)
	if not bool(preferences.data.get("guide_seen", false)):
		var welcome := _panel(body)
		var welcome_row := _row(welcome)
		_label(welcome_row, "처음 등반한다면 1분 안내에서 장전 순서와 전투 흐름을 먼저 확인하세요.", 18, ACCENT)
		var welcome_button := _button(welcome_row, "처음 안내", "first_guide", _guide)
		welcome_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		welcome_button.custom_minimum_size.x = 150
	var mode_panel := _panel(body)
	var mode_row := _row(mode_panel)
	var mode_label := _label(mode_row, "플레이 모드", 20, ACCENT)
	mode_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mode_label.custom_minimum_size.x = 120
	mode_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	course_toggle = CheckButton.new()
	course_toggle.name = "CourseToggle"
	course_toggle.text = "7교전 기초 훈련"
	course_toggle.button_pressed = false
	course_toggle.custom_minimum_size = Vector2(225, 52)
	course_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mode_row.add_child(course_toggle)
	var mode_summary := _label(mode_row, "도시 등반 · 맵/상점/보급/관문 · 자동 저장", 17, MUTED)
	course_toggle.toggled.connect(func(enabled: bool):
		mode_summary.text = "기초 훈련 · 7교전 · 탄환 효과를 순서대로 학습" if enabled else "도시 등반 · 맵/상점/보급/관문 · 자동 저장"
	)
	var city_probe = Campaign.new()
	var city_saved: bool = city_probe.restore()
	if FileAccess.file_exists(Campaign.SAVE) and not city_saved:
		_label(body, "도시 저장을 읽을 수 없습니다. 새 등반 전까지 원본 파일을 보존합니다.", 17, DANGER)
	var configuration := _row(body)
	var loadout_label := _label(configuration, "시작 보급", 19, MUTED)
	loadout_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	loadout_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	loadout_option = OptionButton.new()
	loadout_option.name = "CityLoadout"
	loadout_option.custom_minimum_size = Vector2(240, 46)
	for id in city_probe.profile.unlocks:
		loadout_option.add_item(CampaignContent.LOADOUTS[id].name)
		loadout_option.set_item_metadata(loadout_option.item_count - 1, id)
	configuration.add_child(loadout_option)
	var difficulty_label := _label(configuration, "난도", 19, MUTED)
	difficulty_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	difficulty_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	difficulty_option = SpinBox.new()
	difficulty_option.name = "CityDifficulty"
	difficulty_option.max_value = int(city_probe.profile.ascension)
	difficulty_option.custom_minimum_size = Vector2(115, 46)
	configuration.add_child(difficulty_option)
	_button(configuration, "기록실", "city_archive", _city_archive)
	var difficulty_summary := _label(body, "난도 0 · 시작 거리 보정 없음 · 완주하면 다음 난도 해금", 17, MUTED)
	difficulty_option.value_changed.connect(func(value: float):
		difficulty_summary.text = "난도%d · 적 시작 거리 −%dm · 배급 보정 −%dCr (최소 8Cr)" % [int(value), mini(4, int(value) / 2), int(value)]
	)
	_label(body, "무기 선택 · 선택한 총기는 이번 등반 끝까지 유지", 18, ACCENT)
	var weapons := GridContainer.new()
	weapons.name = "WeaponSelection"
	weapons.columns = 2
	weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons.add_theme_constant_override("h_separation", 14)
	weapons.add_theme_constant_override("v_separation", 10)
	body.add_child(weapons)
	for id in Content.GUNS:
		var spec: Dictionary = Content.GUNS[id]
		var column := _panel(weapons)
		column.add_theme_constant_override("separation", 4)
		var heading := _row(column)
		var icon := WeaponView.new()
		icon.gun_id = id
		heading.add_child(icon)
		_label(heading, "%s / %s" % [spec.name, spec.role], 24, WeaponView.COLORS[id])
		_label(column, spec.identity, 18)
		_label(column, "%s · %d칸 · 재장전 %d턴   /   %s" % ["전탄 연쇄" if spec.mode == "chain" else "단발 · 매 발 적 접근", spec.capacity, spec.reload, spec.recommendation], 16, MUTED)
		var actions := _row(column)
		_button(actions, "이 총으로 시작", "start_" + id, _request_start.bind(id, false))
		var info := _button(actions, "특징·보급", "weapon_info_" + id, _weapon_details.bind(id))
		info.size_flags_horizontal = Control.SIZE_SHRINK_END
		info.custom_minimum_size.x = 128
	var controls := _row(body)
	var seed_label := _label(controls, "시드", 20, MUTED)
	seed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	seed_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	seed_label.custom_minimum_size.x = 48
	seed_input = LineEdit.new()
	seed_input.name = "Seed"
	seed_input.text = str(int(Time.get_unix_time_from_system()) % 1000000)
	seed_input.custom_minimum_size = Vector2(180, 46)
	controls.add_child(seed_input)
	var probe = Model.new()
	var can_resume: bool = probe.restore_run(SAVE)
	if FileAccess.file_exists(SAVE) and not can_resume:
		_label(body, "자동 저장을 읽을 수 없습니다. 기존 파일은 보존되며, 새 런을 시작하면 교체됩니다.", 17, DANGER)
	var resume_title := "이어 하기"
	if city_saved and not city_probe.s.settled:
		resume_title = "도시 이어하기 · %02d층" % maxi(1, city_probe.absolute_floor())
	elif can_resume:
		resume_title = "훈련 이어하기"
	_button(controls, resume_title, "resume", _resume, not can_resume and not (city_saved and not city_probe.s.settled))
	if city_saved and can_resume:
		_button(controls, "훈련 이어 하기", "resume_training", _resume_training)
	_button(controls, "처음 안내", "guide", _guide)
	_button(controls, "설정", "settings", _settings)
	_button(controls, "규칙", "rules", _rules)
	_button(controls, "개발자 테스트", "dev", _developer)
	_hint(body, "도시 등반은 자동 저장됩니다. 진행 중 새 등반을 고르면 교체 여부를 한 번 더 확인합니다.")

func _request_start(id: String, same_seed: bool) -> void:
	if busy:
		return
	if same_seed or debug_session or (course_toggle != null and course_toggle.button_pressed):
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
	if full_game_enabled and ((same_seed and campaign != null) or (not same_seed and not course_toggle.button_pressed)):
		var run_seed: int = int(campaign.s.seed) if same_seed else int(seed_input.text)
		var difficulty: int = int(campaign.s.difficulty) if same_seed else int(difficulty_option.value)
		var loadout: String = str(campaign.s.loadout) if same_seed else str(loadout_option.get_selected_metadata())
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
	var run_seed: int = int(model.s.seed) if same_seed else int(seed_input.text)
	debug_session = debug_session and same_seed
	var course: bool = model.s.get("course", false) if same_seed else course_toggle.button_pressed
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

func _combat() -> void:
	var previous := combat_forecast
	combat_forecast = Forecast.analyze(model.s)
	battle_view = BattleView.new()
	battle_view.name = "BattleView"
	battle_view.inspection_enabled = not busy
	body.add_child(battle_view)
	battle_view.sync(model.s, combat_forecast)
	if campaign != null: battle_view.caption = str(campaign.node().name)
	if model.s.get("course", false): battle_view.caption = Content.lesson(model.s)
	if not combat_forecast.get("random", false) and not combat_forecast.shots.is_empty(): battle_view.first_shot = combat_forecast.shots[0]
	battle_view.shot_started.connect(_visual_shot)
	battle_view.enemy_inspected.connect(_enemy_details)
	battle_view.reinforcement_inspected.connect(_reinforcement_details)
	_combat_steps()
	var workbench := _row(body)
	var candidates := _panel(workbench)
	candidates.get_parent().size_flags_stretch_ratio = 1.45
	var hand_header := _row(candidates)
	_label(hand_header, "보유 탄환", 22, ACCENT)
	if not model.s.get("course", false) or int(model.s.floor) >= 2:
		if not model.s.get("course", false):
			var field_ids: Array = model.field_compressible_ids()
			var compressor := PanelContainer.new()
			compressor.name = "field_compressor_status"
			compressor.custom_minimum_size = Vector2(82, 52)
			compressor.size_flags_horizontal = Control.SIZE_SHRINK_END
			compressor.tooltip_text = "압축 코어 %d/2 · 같은 탄환을 서로 끌어 임시 압축\n코어는 런 동안 유지되며 상점에서 충전합니다." % int(model.s.field_compression_left)
			var compressor_style := _style(PANEL)
			compressor_style.border_color = Color("63dce8") if not field_ids.is_empty() else Color("38515d")
			compressor_style.set_border_width_all(1)
			compressor.add_theme_stylebox_override("panel", compressor_style)
			hand_header.add_child(compressor)
			var compressor_view := FieldCompressorView.new()
			compressor_view.name = "CompressorGlyph"
			compressor_view.setup(int(model.s.field_compression_left), not field_ids.is_empty())
			compressor.add_child(compressor_view)
		_button(hand_header, "패 교환 · %d회" % model.s.exchange_left, "exchange", _exchange_dialog, model.s.phase != "plan" or model.s.exchange_left <= 0 or (model.s.draw.is_empty() and model.s.discard.is_empty()))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	candidates.add_child(grid)
	var ids: Array = ["basic"]
	for hand_id in model.s.hand:
		if not ids.has(hand_id): ids.append(hand_id)
	var field_ids: Array = model.field_compressible_ids()
	var entries: Array = [{"id": "basic", "count": model.available("basic"), "token": "basic", "copy": 1}]
	for tactical_id in ids.slice(1):
		for copy_index in range(model.available(str(tactical_id))):
			entries.append({"id": str(tactical_id), "count": 1, "token": "%s_%d" % [tactical_id, copy_index], "copy": copy_index + 1})
	for entry in entries:
		var id := str(entry.id)
		var count := int(entry.count)
		var disabled: bool = not model.can_load(id)
		var token := str(entry.token)
		var copy_number := int(entry.copy)
		var key := "load_" + id + ("" if copy_number == 1 else "_%d" % copy_number)
		var can_compress := field_ids.has(id)
		var button := AmmoHandButton.new()
		button.name = key
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 88
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = disabled or busy
		button.setup(id, token, can_compress, model.s)
		button.pressed.connect(_load.bind(id))
		button.pair_dropped.connect(_field_drop)
		grid.add_child(button)
		button.tooltip_text = _ammo_stats(id) + "\n" + Readability.description(id, model.s) + ("\n같은 표시 탄환 위로 끌어 압축" if can_compress else "")
		button.custom_minimum_size.y = 88
		button.mouse_entered.connect(_inspect_ammo.bind(id))
		button.focus_entered.connect(_inspect_ammo.bind(id))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			style.content_margin_left = 6
			style.content_margin_right = 6
			button.add_theme_stylebox_override(state, style)
		var card_view := AmmoCardView.new()
		card_view.name = "CardInfo"
		card_view.setup(id, count, model.s, disabled, can_compress)
		button.add_child(card_view)
	ammo_inspector = _label(candidates, "", 17, INK)
	ammo_inspector.name = "AmmoInspector"
	ammo_inspector.custom_minimum_size.y = 36 if inspect_slots else 0
	ammo_inspector.visible = inspect_slots
	calculation_label = ammo_inspector
	_inspect_ammo(inspected_ammo if ids.has(inspected_ammo) else "basic")
	_reserve_preview(candidates)
	var queue := _panel(workbench)
	_label(queue, "\ubc1c\uc0ac \uc21c\uc11c  \u00b7  %d/%d\uce78" % [Content.slots_used(model.s.plan if model.s.phase == "plan" else model.s.magazine), model.capacity()], 20, ACCENT)
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	magazine_view = MagazineView.new()
	magazine_view.name = "MagazineView"
	magazine_view.stack = stack.duplicate()
	magazine_view.capacity = model.capacity()
	magazine_view.interactive = not busy
	magazine_view.selected_index = selected_slot
	magazine_view.slot_hovered.connect(_inspect_slot)
	for i in range(combat_forecast.shots.size()):
		if i >= previous.get("shots", []).size() or combat_forecast.shots[i].damage != previous.shots[i].damage or combat_forecast.shots[i].target != previous.shots[i].target:
			magazine_view.changed_slots.append(i)
	magazine_view.slot_pressed.connect(_slot_action)
	magazine_view.confirmed = model.s.phase == "ready"
	if not stack.is_empty(): magazine_view.forecast = combat_forecast
	queue.add_child(magazine_view)
	if model.s.phase == "plan":
		var edits := _row(queue)
		var inspect := _button(edits, "계산 보기", "inspect_slots", func():
			inspect_slots = not inspect_slots
			redraw()
		)
		inspect.toggle_mode = true
		inspect.button_pressed = inspect_slots
		inspect.tooltip_text = "켜면 칸 터치로 계산을 확인하고, 끄면 칸 터치로 회수합니다."
		_button(edits, "끝 탄 회수", "undo", _undo, stack.is_empty()).tooltip_text = "마지막 칸을 돌려받습니다. 시간 소모 없음."
	var preview: Dictionary = model.preview()
	preview_label = _label(queue, _preview_text(preview), 18, ACCENT if int(preview.get("damage", 0)) > 0 else MUTED)
	preview_label.tooltip_text = str(preview.get("text", "누른 순서대로 발사합니다. 피해·거리·속성 효과를 함께 설계하세요."))
	if not stack.is_empty():
		preview_label.text = Forecast.compact_summary(combat_forecast)
		preview_label.tooltip_text = "매 탄환은 살아 있는 적 중 무작위 표적을 고릅니다. HP 범위와 처치·접촉 확률은 가능한 모든 표적 순서를 계산한 값입니다." if combat_forecast.get("random", false) else "현재 탄창을 중간 재장전 없이 계속 발사할 때의 예상입니다. 보존은 전투 종료로 미발사, 중단은 접촉 패배로 미발사입니다.\n같은 거리는 A → B → C 순서로 조준합니다."
	if not stack.is_empty(): _inspect_slot(clampi(selected_slot, 0, stack.size() - 1))
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	queue.add_child(actions)
	if model.s.phase == "plan":
		_button(actions, "3 · 장전 확정", "confirm", _confirm, stack.is_empty()).tooltip_text = "시간 소모 없음. 확정 후 순서를 바꾸려면 재장전해야 합니다."
	else:
		var fire_label := "\uc5f0\uc1c4 \uc0ac\uaca9 \u00b7 %d\ubc1c \u00b7 1\ud134" % stack.size() if Content.chains(model.s) else "\ucc98\ud615 \uc5f0\uc1c4 \u00b7 \ucc98\uce58 \uc2dc \uacc4\uc18d \u00b7 1\ud134"
		_button(actions, fire_label, "fire", _fire, stack.is_empty())
		var projected: Array = model.movement_preview(model.reload_cost())
		var lethal := false
		for i in range(projected.size()):
			if model.s.enemies[i].hp > 0 and projected[i] <= 0:
				lethal = true
		_button(actions, "재장전 · %d턴%s" % [model.reload_cost(), " · 접촉 위험" if lethal else ""], "reload", _reload)

func _combat_steps() -> void:
	var strip := PanelContainer.new()
	strip.name = "CombatSteps"
	strip.custom_minimum_size.y = 38
	var style := _style(Color("14252e"))
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	strip.add_theme_stylebox_override("panel", style)
	body.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	strip.add_child(row)
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	var active := 1 if model.s.phase == "plan" and stack.is_empty() else (2 if model.s.phase == "plan" else 3)
	for step in [[1, "\ud0c4 \uc120\ud0dd"], [2, "\uc21c\uc11c \ud655\uc778"], [3, "\ubc1c\uc0ac"]]:
		var number := int(step[0])
		var marker := ">" if number == active else ("v" if number < active else "o")
		var label := _label(row, "%s  %s" % [marker, step[1]], 15, ACCENT if number == active else (INK if number < active else MUTED))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
func _ammo_stats(id: String) -> String:
	return Content.AMMO[id].name + "   " + Readability.stats(id, model.s, true)

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
	var report_label := _label(body, RunInsight.combat_report_line(model.s, int(model.s.floor)), 19, MUTED)
	report_label.name = "EncounterReport"
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
	_label(body, "당신은 아직 인간이다." if won else "계산은 여기서 멈췄다.", 46, ACCENT if won else DANGER)
	_label(body, "정점은 개조를 권한다. 당신은 거부하고, 그 자리에 선다." if won else str(model.s.message), 24)
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

func _reserve_preview(parent: Node) -> void:
	var reserve := _panel(parent)
	reserve.name = "ReserveAmmo"
	reserve.tooltip_text = "다음 두 발은 순서 공개 · 나머지는 대기/사용 구성을 공개하고 순서는 숨깁니다."
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 5)
	reserve.add_child(flow)
	_label(flow, "다음", 14, ACCENT)
	var next_count: int = mini(2, model.s.draw.size())
	if next_count == 0: _label(flow, "셔플", 14, MUTED)
	for i in range(next_count): _reserve_chip(flow, str(model.s.draw[i]), str(i + 1), 1, true, "next")
	_reserve_group(flow, "대기", model.s.draw.slice(next_count), "wait")
	_reserve_group(flow, "사용", model.s.discard, "used")

func _reserve_group(parent: Node, title: String, ids: Array, zone: String) -> void:
	if ids.is_empty(): return
	_label(parent, "%s %d" % [title, ids.size()], 14, MUTED)
	var counts := {}
	var order: Array = []
	for value in ids:
		var id := str(value)
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	for id in order: _reserve_chip(parent, str(id), AmmoVisual.SHORT.get(id, Content.AMMO[id].name), int(counts[id]), false, zone)

func _reserve_chip(parent: Node, id: String, title: String, count: int, is_next: bool, zone: String) -> void:
	var chip := PanelContainer.new()
	chip.name = "reserve_%s_%s" % [zone, id]
	chip.custom_minimum_size = Vector2(58 if is_next else 74, 36)
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
	icon.custom_minimum_size = Vector2(24, 30)
	row.add_child(icon)
	var text := title if is_next else title + ("×%d" % count if count > 1 else "")
	_label(row, text, 13, ACCENT if is_next else MUTED)

func _persist() -> void:
	if campaign != null: campaign.sync_combat()
	if save_enabled and not debug_session:
		var error: Error = campaign.save() if campaign != null else model.save_run(SAVE)
		save_error = "자동 저장 실패 (%d) · 게임을 종료하지 말아 주세요." % error if error != OK else ""

func _changed() -> void:
	_persist()
	redraw.call_deferred()

func _load(id: String) -> void:
	if busy: return
	var source := find_child("load_" + id, true, false) as Button
	var from: Vector2 = source.get_global_rect().get_center() if source else Vector2(300, 500)
	var insertion_index := Content.insertion_index(model.s.plan, id)
	if model.load_round(id):
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

func _undo() -> void:
	if busy: return
	if model.undo(): _changed()

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
	preview_label.text = ""
	preview_label.tooltip_text = str(result.text)

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
	_label(column, "2. 보행자·쇄도·산개·압쇄는 한 탄창을 1턴에 연쇄 발사합니다. 증강은 한 발마다 1턴입니다. 살아남은 적은 사격 이후 전진합니다.")
	_label(column, "3. 보행자는 전술탄 피해 +2, 회수탄 피해 +1. 쇄도는 같은 적의 주 타격 3회마다 추가 피해 4. 연발의 두 타격은 각각 세며 화상/전이는 세지 않습니다.")
	_label(column, "4. 산개는 탄환마다 살아 있는 적 중 무작위 표적을 선택합니다. 확률과 HP 범위가 예상이며 확정 결과가 아닙니다. 나머지는 가장 가까운 적부터 조준합니다.")
	_label(column, "5. 압쇄는 화상 턴당 피해 2와 전이 피해 3. 증강은 탄환 기본 피해/관통과 증폭/넉백/화상 피해/전이 강도 2배입니다. 연발은 2타, 증폭은 뒤 2발, 화상 기간은 유지합니다.")
	_label(column, "6. 증폭은 다음 2발에 적용하고 연발의 각 타격을 강화합니다. 화상은 전진 직전에 진행합니다. 실제 총기 수치와 효과는 탄환 카드에서 확인하세요.")
	_label(column, "7. 재장전마다 회수탄과 5장 패를 보충하고 교환 1회를 복구합니다. 넉백은 일반 탄창 총 2m, 증강은 4m까지입니다. 관문 용량 +2는 파츠와 독립적입니다.")
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
		_label(column, "기본 피해/관통 2배 · 증폭 +4 · 충격 4m · 화상 턴당 2 · 전이 4. 연발의 타격 수와 지속 기간은 유지해 중복 4배를 방지합니다. 매 발사 후 생존 적이 전진합니다.", 18)
	var loadout := "balanced" if loadout_option == null else str(loadout_option.get_selected_metadata())
	var deck: Array = Content.start_deck(id) if loadout == "balanced" else CampaignContent.LOADOUTS[loadout].deck
	_label(column, "도시 시작 보급 / " + CampaignContent.LOADOUTS[loadout].name, 20, ACCENT)
	_label(column, RunInsight.deck_summary(deck), 18)
	_label(column, "기초 훈련에서는 무기와 관계없이 같은 순서로 탄환을 배웁니다.", 16, MUTED)

func _inspect_slot(index: int) -> void:
	if busy or not is_instance_valid(calculation_label): return
	selected_slot = index
	magazine_view.selected_index = index
	magazine_view.queue_redraw()
	if combat_forecast.shots.is_empty():
		calculation_label.text = Readability.explain({}) if model.s.phase == "plan" else "다음 탄창을 장전하세요."
	elif index >= combat_forecast.shots.size():
		calculation_label.text = "%d번 · 전투가 먼저 끝나 이 탄은 발사되지 않습니다." % (index + 1)
	else:
		var shot: Dictionary = combat_forecast.shots[index]
		calculation_label.add_theme_color_override("font_color", INK)
		calculation_label.text = "%d번 %s → " % [index + 1, Content.AMMO[shot.id].name] + Readability.explain(shot)
		var sequence_note := Forecast.note(combat_forecast, index)
		if not sequence_note.is_empty(): calculation_label.text += "\n순서 효과 · " + sequence_note

func _slot_action(index: int) -> void:
	if busy: return
	if inspect_slots or model.s.phase != "plan": _inspect_slot(index)
	else: _remove_slot(index)

func _remove_slot(index: int) -> void:
	if not busy and model.remove_planned(index): _changed()

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
		page = "menu"
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
