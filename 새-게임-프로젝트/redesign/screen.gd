extends Control
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const BattleView = preload("res://redesign/battle_view.gd")
const MagazineView = preload("res://redesign/magazine_view.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const AmmoSynergy = preload("res://redesign/ammo_synergy.gd")
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
var forecast_pending := false
var forecast_refresh_waiting := false
var forecast_worker: Node
var show_full_forecast := false
var hand_layout: Array = []
var hand_layout_key := ""
var hand_page := 0
var used_hand_tokens: Array = []
var preferences = Preferences.new()
var ui_theme: Theme
var main_scroll: ScrollContainer
var content_margin: MarginContainer
var workspace_overlay: Control
var selected_weapon_id := "single"
var selected_loadout_id := "balanced"
var selected_outfit_id := "carrier"
var selected_difficulty := 0
var preparation_training := false
var preparation_seed := ""
var feedback = preload("res://redesign/presentation_feedback.gd").new()

func _ready() -> void:
	# Keep the formal entry scene visible in the editor; runtime binds this same scene.
	var title_preview := get_node_or_null("TitlePreview")
	if title_preview != null:
		remove_child(title_preview)
		title_preview.free()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	forecast_worker = preload("res://redesign/forecast_worker.gd").new()
	add_child(forecast_worker)
	forecast_worker.completed.connect(_forecast_completed)
	RenderingServer.set_default_clear_color(BG)
	preferences.load_preferences()
	add_child(feedback)
	feedback.configure(preferences.data)
	add_child(preload("res://redesign/touch_scroll_policy.gd").new())
	if is_equal_approx(presentation_speed, 1.0):
		presentation_speed = preferences.motion_scale()
	ui_theme = Theme.new()
	ui_theme.default_font = preload("res://redesign/ui_font.tres")
	ui_theme.default_font_size = _scaled(20)
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_color("font_disabled_color", "Button", Color("a0b1ba"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := _console_style("button", state)
		ui_theme.set_stylebox(state, "Button", box)
	preload("res://redesign/console_widgets.gd").apply_to(ui_theme)
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
		if child.has_meta("lob_modal") and child.visible:
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

func _console_style(kind: String, state: String = "normal") -> StyleBoxTexture:
	var style := preload("res://redesign/combat_pixel_skin.gd").box(kind, state)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14 if state == "pressed" else 12
	style.content_margin_bottom = 10 if state == "pressed" else 12
	return style

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
	panel.add_theme_stylebox_override("panel", _console_style("panel"))
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
	if key not in ["confirm", "fire", "reload", "skip_animation"]:
		button.pressed.connect(func(): feedback.play("click"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _primary_button(button: Button, _color: Color = ACCENT) -> Button:
	button.add_theme_color_override("font_color", Color("101920"))
	button.add_theme_color_override("font_hover_color", Color("101920"))
	button.add_theme_color_override("font_pressed_color", Color("101920"))
	button.add_theme_color_override("font_focus_color", Color("101920"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := _console_style("primary", state)
		button.add_theme_stylebox_override(state, box)
	return button

func _hint(parent: Node, value: String) -> Label:
	if not bool(preferences.data.get("hints", true)):
		return null
	var hint := _label(parent, value, 17, MUTED)
	hint.name = "ContextHint"
	return hint

func _focus_control(control: Variant) -> void:
	# Deferred focus may outlive its page during quick navigation.
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

func _forecast_completed() -> void:
	if is_instance_valid(workspace_overlay):
		forecast_refresh_waiting = true
		return
	if not busy and page == "run" and model.s.phase in ["plan", "ready"] and (campaign == null or campaign.s.phase == "combat"):
		redraw()

func redraw() -> void:
	# Acquisition feedback belongs to the resulting screen, not later navigation.
	var previous_notice := get_node_or_null("AmmoAcquiredNotice")
	if previous_notice != null:
		remove_child(previous_notice)
		previous_notice.queue_free()
	# Plan/ready and hand edits share a screen; only navigation changes fade in.
	var stage := page
	if page == "run":
		stage = str(campaign.s.phase) if campaign != null else str(model.s.phase)
		if stage in ["plan", "ready"]: stage = "combat"
	var flow := page + ":" + stage
	if page == "run" and campaign != null: flow += ":" + str(campaign.s.node)
	feedback.enter(flow, body, stage == "reward")
	forecast_pending = false
	if page != "run" or model.s.get("phase", "") not in ["plan", "ready"] or (campaign != null and campaign.s.phase != "combat"):
		forecast_worker.cancel_request()
		forecast_refresh_waiting = false
	combat_parts.clear()
	_close_workspace()
	_reset_scroll.call_deferred()
	var combat_screen: bool = page == "run" and str(model.s.phase) in ["plan", "ready"]
	var compact_combat: bool = combat_screen and size.y < 960
	var edge_margin := 0 if page in ["menu", "loadout"] else (10 if compact_combat else 20)
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
	var status_style := _style(Color("101d22"))
	status_style.content_margin_left = 12
	status_style.content_margin_right = 10
	status_style.content_margin_top = 6
	status_style.content_margin_bottom = 6
	status_style.border_color = WeaponView.COLORS[model.s.gun]
	status_style.border_width_left = 0
	status_panel.add_theme_stylebox_override("panel", status_style)
	body.add_child(status_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if compact else 12)
	status_panel.add_child(row)

	var location_text := str(campaign.region_info().name) if campaign != null else "훈련  %02d/07" % (int(model.s.floor) + 1)
	var location := _label(row, location_text, 18 if compact else 20, Color("d3c9aa"))
	location.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	location.custom_minimum_size.x = 156 if compact else 210
	location.autowrap_mode = TextServer.AUTOWRAP_OFF

	var identity_button := _button(row, str(spec.name), "weapon_identity", _weapon_details.bind(str(model.s.gun)))
	identity_button.custom_minimum_size = Vector2(96, 40)
	identity_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	identity_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	identity_button.add_theme_font_size_override("font_size", _scaled(18))
	identity_button.tooltip_text = spec.identity
	if model.reserve_count() > 0:
		var reserve_marker := _label(row, "증원 %d" % model.reserve_count(), 16, MUTED)
		reserve_marker.name = "ReinforcementCount"
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
	skip.add_theme_font_size_override("font_size", _scaled(16))
	skip.add_theme_font_override("font", preload("res://redesign/combat_pixel_font.tres"))
	skip.autowrap_mode = TextServer.AUTOWRAP_OFF
	preload("res://redesign/combat_treatment.gd").finish_button(skip)
	skip.visible = busy
	for button in row.get_children():
		if button is Label: button.add_theme_font_override("font", preload("res://redesign/combat_pixel_font.tres"))
		if button is Button: preload("res://redesign/combat_surface.gd").finish_button(button)

func _reset_scroll() -> void:
	if is_instance_valid(main_scroll):
		main_scroll.scroll_vertical = 0
		main_scroll.scroll_horizontal = 0

func _menu() -> void:
	var city_probe = Campaign.new()
	var city_saved: bool = city_probe.restore()
	var training_probe = Model.new()
	var training_saved: bool = training_probe.restore_run(SAVE)
	var title = preload("res://redesign/title_screen.tscn").instantiate()
	title.custom_minimum_size = size
	body.add_child(title)
	title.bind_screen(self, city_probe, city_saved, training_saved)

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

func _loadout_screen() -> void:
	var probe = Campaign.new()
	probe.restore()
	if not probe.profile.unlocks.has(selected_loadout_id): selected_loadout_id = "balanced"
	selected_difficulty = clampi(selected_difficulty, 0, int(probe.profile.ascension))
	if preparation_seed.is_empty(): preparation_seed = str(int(Time.get_unix_time_from_system()) % 1000000)
	var equipment = preload("res://redesign/equipment_screen.tscn").instantiate()
	equipment.custom_minimum_size = Vector2(size.x, maxf(size.y, 620.0))
	body.add_child(equipment)
	equipment.bind_screen(self, probe.profile)

func _request_start(id: String, same_seed: bool) -> void:
	if busy:
		return
	if same_seed or preparation_training:
		_start(id, same_seed)
		return
	var active := Campaign.new()
	if not active.restore() or (bool(active.s.get("settled", false)) and not active.restoration_pending()):
		_start(id, same_seed)
		return
	_confirmation("진행 중인 등반 교체", "%s · %s 진행이 저장되어 있습니다.\n새 %s 등반으로 교체할까요?" % [active.region_info().name, Content.GUNS[active.s.gun].name, Content.GUNS[id].name], "NewRunConfirmation", "새 등반 시작", "계속 보관", _start.bind(id, same_seed))

func _start(id: String, same_seed: bool) -> void:
	if busy: return
	hand_layout_key = ""
	show_full_forecast = false
	_remember_preparation_seed()
	if full_game_enabled and ((same_seed and campaign != null) or (not same_seed and not preparation_training)):
		var run_seed: int = int(campaign.s.seed) if same_seed else int(preparation_seed)
		var difficulty: int = int(campaign.s.difficulty) if same_seed else selected_difficulty
		var loadout: String = str(campaign.s.loadout) if same_seed else selected_loadout_id
		var map_version: int = int(campaign.s.get("map_version", 1)) if same_seed else CampaignContent.RouteMap.VERSION
		var outfit: String = str(campaign.s.get("outfit", "work")) if same_seed else selected_outfit_id
		var progress = Campaign.new()
		progress.restore()
		if same_seed and debug_session: progress.profile = campaign.profile.duplicate(true)
		campaign = progress
		campaign.start(id, run_seed, difficulty, loadout, map_version, outfit)
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
	if full_game_enabled and probe.restore() and (not probe.s.settled or probe.restoration_pending()):
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
	var view: Control = preload("res://redesign/samples/ranged_battle_view.tscn").instantiate()
	if debug_session and campaign != null and campaign.get_meta("eavesback_preview", false):
		view.free()
		if campaign.get_meta("creature_family_preview", false):
			view = preload("res://redesign/samples/residential_creatures_view.tscn").instantiate()
		else:
			view = preload("res://redesign/samples/eavesback_view.tscn").instantiate()
	elif campaign != null and int(campaign.s.get("region", -1)) == 0 and int(campaign.s.get("roster_version", 1)) >= 2:
		view.free()
		view = preload("res://redesign/residential_battle_view.tscn").instantiate()
	view.reduced_feedback = str(preferences.data.motion) == "instant"
	view.projectile_inspected.connect(_combat_projectile_details)
	return view

func _combat_projectile_details(target_id: int) -> void:
	if busy: return
	var projectile: Dictionary = model.target_entity(target_id)
	if projectile.is_empty(): return
	var column := _dialog("압력탄", true)
	column.name = "ProjectileDetails"
	_label(column, "%dm · 도달 %d턴 · HP 1" % [projectile.distance, preload("res://redesign/ranged.gd").arrival(projectile)], 24)
	_label(column, "가장 가까워지면 다음 탄으로 자동 요격합니다. 산개도 확정 요격합니다.\n본체를 처치해도 이미 발사된 탄은 남습니다. 0m 도달 시 패배합니다.\n과열로 강제 재장전하는 동안에도 압력탄은 매 턴 6m씩 이동합니다.", 19)

func _reload_forecast_text(prediction: Dictionary) -> String:
	if model.s.phase == "plan" and model.s.plan.is_empty():
		return "재장전 %d턴 · 냉각 %d" % [model.base_reload_cost(), Content.reload_cooling(model.s)]
	var thermal: Dictionary = prediction.get("heat", {})
	if float(thermal.get("forced_probability", 0)) > 0:
		var low := int(thermal.forced_cost_min)
		var high := int(thermal.forced_cost_max)
		var value := str(high) if low == high else "%d~%d" % [low, high]
		return "강제 재장전 %s턴%s" % [value, " · 위험" if prediction.get("phase", "") == "lost" or float(prediction.get("lost_probability", 0)) > 0 else ""]
	var reload: Dictionary = prediction.get("reload", {})
	if reload.get("random", false):
		if float(reload.get("required_probability", 0)) <= 0: return "사격 후 충돌 위험" if float(reload.get("lost_probability", 0)) > 0 else "다음 재장전 없음"
		var low := int(reload.get("cost_min", 0))
		var high := int(reload.get("cost_max", 0))
		var value := str(low) if low == high else "%d~%d" % [low, high]
		return "재장전 %s턴 · 열 %s%s" % [value, str(reload.temperature_min) if reload.temperature_min == reload.temperature_max else "%d~%d" % [reload.temperature_min, reload.temperature_max], " · 위험" if float(reload.get("lost_probability", 0)) > 0 else ""]
	if not bool(reload.get("required", false)):
		if str(reload.get("phase", "")) == "lost": return "사격 후 충돌"
		return "교전 돌파 · 재장전 없음" if str(reload.get("phase", "")) in ["won", "reward"] else "재장전 %d턴" % model.reload_cost()
	return "재장전 %d턴 · 열 %d%s" % [reload.cost, reload.temperature_after, " · 위험" if reload.phase == "lost" else ""]


func _heat_consequence(prediction: Dictionary) -> String:
	var heat: Dictionary = prediction.get("heat", {})
	var chance := float(heat.get("overheat_probability", 0))
	if chance <= 0: return ""
	var forced := float(heat.get("forced_probability", 0))
	var heading := "과열 · 사격 중단" if chance >= 0.999999 else "과열 가능 %d%%" % roundi(chance * 100)
	if forced > 0:
		# Include the legacy surcharge when viewing an older saved run.
		return heading + "\n강제 재장전 %d턴%s · 열 0" % [model.base_reload_cost() + 1 + int(model.s.get("legacy_reload_penalty", 0)), " 가능" if forced < 0.999999 else ""]
	return heading + ("\n교전 종료 · 재장전 없음" if str(prediction.get("phase", "")) in ["won", "reward"] else "\n접촉 위험" if str(prediction.get("phase", "")) == "lost" else "")

func _combat() -> void:
	var compact := size.y < 960
	var previous := combat_forecast
	var queued: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	if model.s.gun == "scatter" and queued.size() >= 5:
		full_forecast = forecast_worker.request(model.s)
		forecast_pending = full_forecast.is_empty()
		if forecast_pending:
			full_forecast = {"pending": true, "shots": [], "turns": 0, "phase": model.s.phase, "enemies": model.s.enemies, "projectiles": model.s.get("projectiles", []), "reserve": model.s.get("reinforcements", []), "remaining": queued, "heat": {}}
		next_forecast = full_forecast
	else:
		forecast_worker.cancel_request()
		full_forecast = Forecast.analyze(model.s, false, true)
		next_forecast = Forecast.analyze(model.s, true, true)
	if int(full_forecast.get("turns", 0)) <= int(next_forecast.get("turns", 0)): show_full_forecast = false
	combat_forecast = full_forecast if show_full_forecast else next_forecast
	var layout := CombatWorkbench.instantiate()
	layout.name = "CombatWorkbench"
	var combat_theme := ui_theme.duplicate() as Theme
	combat_theme.default_font = preload("res://redesign/combat_pixel_font.tres")
	layout.theme = combat_theme
	layout.add_theme_constant_override("separation", 2)
	layout.size_flags_vertical = Control.SIZE_FILL
	body.add_child(layout)

	var tactical_grid := layout.get_node("%TacticalGrid") as GridContainer
	tactical_grid.columns = 1
	tactical_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	tactical_grid.add_theme_constant_override("h_separation", 8 if compact else 14)
	tactical_grid.add_theme_constant_override("v_separation", 0)
	if compact:
		(layout.get_node("TacticalGrid/CandidatesPanel/CandidatesColumn") as VBoxContainer).add_theme_constant_override("separation", 2)
		(layout.get_node("TacticalGrid/QueuePanel/QueueColumn") as VBoxContainer).add_theme_constant_override("separation", 4)
	for panel_path in ["%CandidatesPanel", "%QueuePanel"]:
		var panel := layout.get_node(panel_path) as PanelContainer
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
		# Both sections share the workbench backing; margins are counted once.
		var panel_style := StyleBoxEmpty.new()
		panel_style.content_margin_left = 12
		panel_style.content_margin_right = 12
		panel_style.content_margin_top = 6 if panel_path == "%QueuePanel" else 4
		panel_style.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", panel_style)
		# The new hand uses quiet surfaces; avoid repeating the old mechanical frame.
	var hand_heading := layout.get_node("TacticalGrid/CandidatesPanel/CandidatesColumn/HandHeader/HandHeading") as Label
	hand_heading.get_parent().add_theme_constant_override("separation", 10)
	hand_heading.text = "탄환 선택 · %d/%d장" % [model.s.hand.size(), Content.hand_capacity(model.s)]
	hand_heading.tooltip_text = "%s · 가방 %d장 · 교환 %d회\n남은 패는 재장전 시 사용 더미로 보내고 새 패를 뽑습니다." % [Content.outfit_name(model.s), Content.hand_capacity(model.s), Content.exchange_capacity(model.s)]
	hand_heading.add_theme_font_size_override("font_size", _scaled(20 if compact else 22))
	hand_heading.add_theme_color_override("font_color", Color("aec4c3"))
	var queue_heading := layout.get_node("%QueueHeading") as Label
	queue_heading.add_theme_font_size_override("font_size", _scaled(20 if compact else 22))
	queue_heading.add_theme_color_override("font_color", Color("aec4c3"))
	var hand_controls := layout.get_node("%HandControls") as HBoxContainer
	if not model.s.get("prepared", []).is_empty():
		var prepared_names: PackedStringArray = []
		for id in model.s.prepared: prepared_names.append(Content.AMMO[id].name)
		var reservation := _label(hand_heading.get_parent(), "다음 패 예약 · " + " / ".join(prepared_names), 17, Color("c4c392"))
		reservation.name = "ReservationStatus"
		reservation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reservation.autowrap_mode = TextServer.AUTOWRAP_OFF
		reservation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		reservation.tooltip_text = reservation.text + "\n재장전하면 소유 탄환을 다음 패로 가져옵니다. 탄환을 복제하지 않습니다."
		hand_heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hand_heading.get_parent().move_child(reservation, 1)
	var steps := layout.get_node("%CombatSteps") as PanelContainer
	steps.visible = not compact
	var battle_preview := layout.get_node("%BattlePreview")
	battle_preview.get_parent().remove_child(battle_preview)
	battle_preview.queue_free()
	battle_view = _new_battle_view()
	battle_view.name = "BattleView"
	battle_view.compact_ui = compact
	battle_view.region = int(campaign.s.region) if campaign != null else 0
	if campaign != null:
		# Campaign depth includes shops/events and comes from the selected node,
		# unlike the combat model's encounter index or the number of visited rooms.
		battle_view.set_route_background(int(campaign.s.region), int(campaign.s.floor), int(campaign.region_info().floors))
	battle_view.inspection_enabled = not busy
	layout.get_node("%BattleHost").add_child(battle_view)
	# Give the stage the recovered hand space and part of the spare tall-screen
	# height. Actor scale uses the previous stage height, not this layout budget.
	battle_view.character_reference_height = 240.0 if compact else 350.0
	battle_view.custom_minimum_size.y = 280.0 + clampf(size.y - 800.0, 0.0, 140.0) * 0.65 if compact else 390.0
	layout.preferred_battle_height = battle_view.custom_minimum_size.y
	layout.bottom_margin = 10.0 if compact else 20.0
	battle_view.sync(model.s, {} if forecast_pending else combat_forecast)
	if debug_session and campaign != null and campaign.has_meta("background_preview"):
		battle_view.show_caption = true
		battle_view.caption = ["초반 · 생활 통로", "중반 · 폐쇄 주거지", "상층 · 승강 설비"][int(campaign.get_meta("background_preview"))] + " · 배경 미리보기"
	if model.s.get("course", false):
		battle_view.show_caption = true
		battle_view.caption = Content.lesson(model.s)
	if not combat_forecast.get("random", false) and not combat_forecast.shots.is_empty(): battle_view.first_shot = combat_forecast.shots[0]
	battle_view.shot_started.connect(_visual_shot)
	battle_view.shot_impacted.connect(_visual_impact)
	_update_combat_parts()
	battle_view.enemy_inspected.connect(_enemy_details)
	battle_view.reinforcement_inspected.connect(_reinforcement_details)
	_combat_steps(layout)

	var decision_prompt := layout.get_node("%DecisionPrompt") as Label
	decision_prompt.add_theme_font_size_override("font_size", _scaled(14 if compact else 17))
	decision_prompt.text = "마지막에 넣은 탄부터 발사 · 새 탄은 맨 앞에" if model.s.phase == "plan" else "장전 확정 · 왼쪽부터 발사"
	if model.s.phase == "plan" and not model.s.plan.is_empty() and Content.anchor(str(model.s.plan[0])) == "first":
		decision_prompt.text = "첫 발 고정 · 더 넣으려면 맨 앞 탄을 회수하세요"
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
			compressor_style.set_border_width_all(0)
			compressor.add_theme_stylebox_override("panel", preload("res://redesign/combat_pixel_skin.gd").box("button"))
			hand_controls.add_child(compressor)
			var compressor_view := FieldCompressorView.new()
			compressor_view.name = "CompressorGlyph"
			compressor_view.setup(int(model.s.field_compression_left), not field_ids.is_empty())
			compressor.add_child(compressor_view)
		var exchange_button := _button(hand_controls, "패 교환  %d" % model.s.exchange_left, "exchange", _exchange_dialog, model.s.phase != "plan" or model.s.exchange_left <= 0 or (model.s.draw.is_empty() and model.s.discard.is_empty()))
		exchange_button.custom_minimum_size = Vector2(116 if compact else 132, 36 if compact else 44)
		exchange_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		exchange_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		exchange_button.add_theme_font_size_override("font_size", _scaled(18))

	var hand_synergies: Dictionary = {}
	var bag_button := _button(hand_controls, "탄환 가방", "ammo_bag", _ammo_bag)
	bag_button.custom_minimum_size = Vector2(116 if compact else 132, 36 if compact else 44)
	bag_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	bag_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bag_button.add_theme_font_size_override("font_size", _scaled(18))
	bag_button.tooltip_text = "전체 보유 · 손패 · 장전 · 뽑을 탄 · 버린 탄 확인 (턴 소모 없음)"
	var field_ids: Array = model.field_compressible_ids()
	var compression_actions := layout.get_node("%CompressionActions") as HBoxContainer
	for compress_id_value in field_ids.slice(0, 2):
		var compress_id := str(compress_id_value)
		var compress_button := CompressionPairButton.new()
		compress_button.name = "compress_pair_" + compress_id
		compress_button.setup(compress_id)
		compress_button.pressed.connect(_field_compress_click.bind(compress_id))
		compression_actions.add_child(compress_button)
		compress_button.tooltip_text = "압축 코어 1개를 사용합니다. 드래그하지 않아도 같은 결과가 적용됩니다."
	if field_ids.size() > 2:
		var more := _button(compression_actions, "+%d종" % (field_ids.size() - 2), "compress_more", _field_compression_choices)
		more.custom_minimum_size = Vector2(70, 44)
	var grid := layout.get_node("%AmmoGrid") as GridContainer
	grid.columns = 10
	var ids: Array = [] if Content.uses_ammo_cards(model.s) else ["basic"]
	for hand_id in model.s.hand:
		if not ids.has(hand_id): ids.append(hand_id)
	var entries: Array = _hand_entries()
	grid.columns = 10
	var pages := maxi(1, ceili(float(entries.size()) / 10.0))
	hand_page = clampi(hand_page, 0, pages - 1)
	if pages > 1:
		var pager := HBoxContainer.new()
		pager.name = "HandPager"
		hand_controls.add_child(pager)
		for step in [-1, 1]:
			if step == 1:
				var page_label := _label(pager, "%d/%d" % [hand_page + 1, pages], 16, INK)
				page_label.name = "HandPageNumber"
				page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
				page_label.custom_minimum_size.x = 40
				page_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var page_button := _button(pager, "‹" if step < 0 else "›", "hand_previous" if step < 0 else "hand_next", _change_hand_page.bind(step), (hand_page == 0 if step < 0 else hand_page == pages - 1))
			page_button.custom_minimum_size = Vector2(40, 36)
			_compact_control(page_button, 36)
			page_button.tooltip_text = "이전 탄환" if step < 0 else "나머지 탄환 보기"
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var id := str(entry.id)
		if str(entry.get("zone", "")) in ["used", "compressed"]:
			var used := preload("res://redesign/ammo_hand_slot.tscn").instantiate()
			used.name = "hand_" + str(entry.zone) + "_%d" % entry_index
			used.slot_state = str(entry.zone)
			used.set_meta("hand_index",entry_index)
			grid.add_child(used)
			used.visible = entry_index / 10 == hand_page
			continue
		var count := int(entry.count)
		var held: bool = bool(entry.get("held", false))
		var disabled: bool = held or not model.can_load(id)
		var token := str(entry.token)
		var copy_number := int(entry.copy)
		var key := "load_" + id + ("" if copy_number == 1 else "_%d" % copy_number)
		var can_compress := not held and field_ids.has(id)
		var button := preload("res://redesign/combat_ammo_card.tscn").instantiate()
		button.name = key
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 132
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = disabled or busy
		button.setup(id, token, can_compress, model.s)
		button.pressed.connect(_activate_hand_card.bind(button, id, key))
		button.detail_requested.connect(_hand_ammo_details)
		button.pair_dropped.connect(_field_drop)
		grid.add_child(button)
		button.visible = entry_index / 10 == hand_page
		button.set_meta("synergy", hand_synergies.get(id, {}).duplicate(true) if not disabled else {})
		button.tooltip_text = _ammo_stats(id) + "\n" + Readability.description(id, model.s) + ("\n같은 표시 탄환 위로 끌어 압축" if can_compress else "")
		if not disabled and hand_synergies.has(id):
			button.tooltip_text += "\n" + AmmoSynergy.text(hand_synergies[id])
			button.tooltip_text += "\n장전 후 발사 레일 맨 뒤로 옮겨 연결합니다." if hand_synergies[id].move else "\n지금 장전하면 앞에서 연결됩니다."
		button.custom_minimum_size.y = 132
		button.mouse_entered.connect(_inspect_ammo.bind(id))
		button.focus_entered.connect(_inspect_ammo.bind(id))
		for preview_event in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited]:
			preview_event.connect(_preview_hand_insertion.call_deferred)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var base_color := Color("202e33").lerp(AmmoVisual.COLORS[id], 0.035)
			if state in ["hover", "focus"]: base_color = base_color.lightened(0.08)
			elif state == "pressed": base_color = base_color.darkened(0.08)
			elif state == "disabled": base_color = Color("101b22")
			var style := _style(Color(0,0,0,0))
			style.border_color = Color("a7bfb8") if state in ["hover", "focus"] else Color("526568")
			style.set_border_width_all(0)
			style.content_margin_left = 6
			style.content_margin_right = 6
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			button.add_theme_stylebox_override(state, style)
		var card_view: Control = button.get_node("CardInfo")
		card_view.compact_ui = true
		card_view.combat_skin = true
		card_view.synergy = hand_synergies.get(id, {}) if not disabled else {}
		card_view.setup(id, count, model.s, disabled, can_compress, "장전한 탄" if held else (model.load_block_reason(id) if disabled else ""))

	# Ten persistent positions make six-card and ten-card bags use the same card width.
	var visible_entries := mini(10,entries.size()-hand_page*10)
	for slot_index in range(visible_entries,10):
		var empty := preload("res://redesign/ammo_hand_slot.tscn").instantiate()
		empty.name = "hand_slot_%d" % slot_index
		empty.slot_state = "locked" if slot_index>=Content.hand_capacity(model.s) else "empty"
		empty.set_meta("hand_index",slot_index)
		grid.add_child(empty)
	var details_button := _button(hand_controls,"탄 상세","hand_details",func(): _hand_ammo_details(inspected_ammo))
	details_button.custom_minimum_size=Vector2(96,36)
	details_button.autowrap_mode=TextServer.AUTOWRAP_OFF
	details_button.add_theme_font_size_override("font_size",_scaled(18))
	details_button.tooltip_text="카드를 길게 눌러도 상세를 확인할 수 있습니다. 확인은 턴을 소모하지 않습니다."

	ammo_inspector = layout.get_node("%AmmoInspector") as Label
	ammo_inspector.add_theme_font_size_override("font_size", _scaled(17))
	ammo_inspector.add_theme_color_override("font_color", INK)
	ammo_inspector.custom_minimum_size.y = 0
	ammo_inspector.hide()
	calculation_label = ammo_inspector
	_inspect_ammo(inspected_ammo if ids.has(inspected_ammo) else "basic")
	layout.get_node("%ReserveHost").hide()

	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	queue_heading.text = "발사 순서 · %d/%d칸" % [Content.slots_used(stack), model.capacity()]
	if model.s.phase == "plan" and not stack.is_empty() and Content.anchor(str(stack[0])) == "first":
		queue_heading.text = "첫 발 고정 · 맨 앞 회수 후 추가 장전"
	if str(model.s.gun) == "amplifier": queue_heading.text += " · 처치 시 연속"
	var magazine_preview := layout.get_node("%MagazinePreview")
	magazine_preview.get_parent().remove_child(magazine_preview)
	magazine_preview.queue_free()
	magazine_view = MagazineView.new()
	magazine_view.name = "MagazineView"
	magazine_view.reduced_motion = str(preferences.data.motion) == "instant"
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
	magazine_view.slot_hovered.connect(_highlight_slot_targets)
	magazine_view.mouse_exited.connect(func(): _highlight_slot_targets(selected_slot))
	magazine_view.confirmed = model.s.phase == "ready"
	if not stack.is_empty() and not forecast_pending: magazine_view.forecast = full_forecast
	layout.get_node("%MagazineHost").add_child(magazine_view)

	var edits := layout.get_node("%EditActions") as HBoxContainer
	_button(edits, "← 앞으로", "slot_previous", func(): _move_slot(selected_slot, selected_slot - 1))
	_button(edits, "뒤로 →", "slot_next", func(): _move_slot(selected_slot, selected_slot + 1))
	_button(edits, "선택 회수", "remove_selected", func(): _remove_slot(selected_slot))
	_button(edits, "탄 상세", "inspect_slots", _slot_details, stack.is_empty())
	edits.visible = model.s.phase == "plan" and not stack.is_empty()
	for edit in edits.get_children():
		edit.custom_minimum_size = Vector2(112, 40)
		edit.autowrap_mode = TextServer.AUTOWRAP_OFF
		edit.add_theme_font_size_override("font_size", _scaled(18))
		_compact_control(edit, 40)
	_update_slot_actions()

	preview_label = layout.get_node("%ForecastLabel") as Label
	preview_label.add_theme_font_size_override("font_size", _scaled(18))
	preview_label.add_theme_color_override("font_color", INK)
	preview_label.custom_minimum_size.y = 24
	preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview_label.visible = not stack.is_empty()
	preview_label.text = ("전체 사격 · " if show_full_forecast else "이번 발사 · ") + Forecast.compact_summary(combat_forecast) if not stack.is_empty() else ""
	preview_label.tooltip_text = "무작위 표적은 범위와 확률로 표시합니다. 탄창의 탄을 눌러 상세를 확인할 수 있습니다."
	if not stack.is_empty(): _inspect_slot(clampi(selected_slot, 0, stack.size() - 1))
	var actions := layout.get_node("%CombatActions") as VBoxContainer
	var primary := _primary_button(_button(actions, "장전 확정" if model.s.phase == "plan" else "발사", "confirm" if model.s.phase == "plan" else "fire", _confirm if model.s.phase == "plan" else _fire, stack.is_empty() or forecast_pending))
	if model.s.phase == "ready" and not forecast_pending:
		var thermal_count: Dictionary = next_forecast.get("heat", {})
		var low := int(thermal_count.get("fired_min", 0))
		var high := int(thermal_count.get("fired_max", 0))
		primary.text = "발사 · %s발" % (str(high) if low == high else "%d~%d" % [low, high])
	# Match the visible magazine plate (82 high, inset by 3 on each edge).
	primary.custom_minimum_size.y = magazine_view.custom_minimum_size.y - 6
	if model.s.phase == "plan" and not stack.is_empty(): primary.text = "장전 확정 · %d발" % stack.size()
	primary.autowrap_mode = TextServer.AUTOWRAP_OFF
	primary.add_theme_font_size_override("font_size", _scaled(24))
	primary.tooltip_text = "확정은 시간 소모 없음 · 발사 1턴" if model.s.phase == "plan" else "발사 후 적이 행동합니다. 과열 시 사격이 끊깁니다."
	# The outcome strip keeps one stable line, including overheat consequences.
	# The warning claims width only when shown, never another row of height.
	var warning_host := VBoxContainer.new()
	warning_host.name = "OverheatWarningHost"
	actions.add_child(warning_host)
	var warning := _label(warning_host, "", 17, DANGER)
	warning.autowrap_mode = TextServer.AUTOWRAP_OFF
	warning.text = _heat_consequence(combat_forecast).replace("\n", " · ")
	warning.tooltip_text = _heat_consequence(combat_forecast)
	warning.name = "OverheatWarning"
	warning.visible = not warning.text.is_empty() and not stack.is_empty()
	if forecast_pending:
		warning.text = "예측 계산 중"
		warning.visible = true
		preview_label.text = "표적별 결과 계산 중"

	layout.arrange_combat()
	var outcome_parent := preview_label.get_parent()
	var strip := HBoxContainer.new()
	strip.name = "ThermalOutcome"
	strip.add_theme_constant_override("separation", 12)
	outcome_parent.add_child(strip)
	outcome_parent.move_child(strip, preview_label.get_index())
	var heat_view := preload("res://redesign/heat_gauge.gd").new()
	heat_view.name = "HeatGauge"
	heat_view.reduced_motion = str(preferences.data.motion) == "instant"
	heat_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(heat_view)
	heat_view.sync(model.s, combat_forecast)
	if model.s.phase == "ready" or Content.uses_ammo_cards(model.s):
		var reload_now := Forecast.reload_now(model.s, true)
		heat_view.reload_temperature = int(reload_now.temperature_after)
		var lethal := str(reload_now.phase) == "lost"
		var consequence := Forecast.reload_consequence(reload_now)
		var reload_title := "패 재장전" if model.s.phase == "plan" else "재장전"
		var reload_detail := consequence if not consequence.is_empty() else "냉각 %d" % Content.reload_cooling(model.s)
		var reload_button := _button(strip, "%s · %s\n열 %d → %d · 적 %d턴" % [reload_title, reload_detail, int(model.s.heat), int(reload_now.temperature_after), int(reload_now.cost)], "reload", _reload)
		reload_button.custom_minimum_size = Vector2(220, 68)
		reload_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		reload_button.set_meta("reload_warning", not consequence.is_empty())
		reload_button.set_meta("reload_lethal", lethal)
		reload_button.add_theme_font_size_override("font_size", _scaled(18 if not consequence.is_empty() else 20))
		reload_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		reload_button.add_theme_font_override("font", preload("res://redesign/combat_pixel_font.tres"))
		reload_button.tooltip_text = "지금 재장전 · 냉각 %d · 미발사 탄과 남은 패를 버리고 새 패를 뽑습니다. 강제 재장전은 추가 1턴과 열 0." % Content.reload_cooling(model.s)
		for preview_event in [reload_button.mouse_entered, reload_button.mouse_exited, reload_button.focus_entered, reload_button.focus_exited]:
			preview_event.connect(_preview_reload_heat.call_deferred)
		if not consequence.is_empty():
			reload_button.tooltip_text += "\n이번 재장전 결과: " + consequence
		if lethal: _primary_button(reload_button, DANGER)
	if battle_view.has_signal("feedback_changed"): battle_view.feedback_changed.connect(_heat_feedback)
	var result_row := HBoxContainer.new()
	result_row.name = "ForecastRow"
	# Reserve the result row even before loading: reveal content, not geometry.
	result_row.custom_minimum_size.y = 32
	result_row.add_theme_constant_override("separation", 12)
	result_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome_parent.add_child(result_row)
	preview_label.reparent(result_row)
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The shot outcome belongs to the firing rail. Its reserved line separates
	# that rail from the thermal instrument, which now sits beside the hand.
	outcome_parent.move_child(result_row, strip.get_index())
	# Keep the action itself centered on the cartridges. Its warning belongs
	# to the reserved outcome row, so hidden warning space cannot offset it.
	warning_host.reparent(result_row)
	warning_host.custom_minimum_size.x = 0
	warning_host.size_flags_horizontal = Control.SIZE_SHRINK_END
	warning_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if int(full_forecast.get("turns", 0)) > int(next_forecast.get("turns", 0)):
		var scope := _button(result_row, "이번 발사 보기" if show_full_forecast else "전체 %d턴 보기" % int(full_forecast.turns), "forecast_scope", func():
			show_full_forecast = not show_full_forecast
			redraw()
		)
		scope.custom_minimum_size = Vector2(176, 32)
		scope.autowrap_mode = TextServer.AUTOWRAP_OFF
		scope.size_flags_horizontal = Control.SIZE_SHRINK_END
		scope.add_theme_font_size_override("font_size", _scaled(18))
		_compact_control(scope, 32)
	result_row.move_child(warning_host, result_row.get_child_count()-1)

	# Skin functional controls without changing their layout or touch rectangles.
	for key in ["confirm", "fire", "reload", "slot_previous", "slot_next", "remove_selected", "inspect_slots", "exchange", "ammo_bag", "hand_details", "forecast_scope", "hand_previous", "hand_next"]:
		var control := layout.find_child(key, true, false) as Button
		if control != null:
			preload("res://redesign/combat_treatment.gd").finish_button(control, key in ["confirm", "fire"])
	for control in compression_actions.get_children():
		if control is Button:
			preload("res://redesign/combat_treatment.gd").finish_button(control)

func _compact_control(button: Button, height: int = 44) -> void:
	button.custom_minimum_size.y = height
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)

func _change_hand_page(step: int) -> void:
	if busy: return
	hand_page += step
	redraw()

func _hand_entries() -> Array:
	var key := JSON.stringify([model.s.get("ammo_cycle", 0), model.s.seed, model.s.gun, model.s.floor, model.s.reloads, model.s.exchange_left, model.s.get("course", false)])
	if hand_layout_key != key:
		hand_layout_key = key
		hand_page = 0
		used_hand_tokens.clear()
		hand_layout = [] if Content.uses_ammo_cards(model.s) else [{"id": "basic", "count": 0, "token": "basic", "copy": 1}]
		var pool: Array = model.s.hand.duplicate()
		if model.s.phase == "ready":
			for id in model.s.magazine:
				if (id != "basic" or Content.uses_ammo_cards(model.s)) and not Content.is_temporary(str(id)): pool.append(id)
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
	if not Content.uses_ammo_cards(model.s): entries[0].count = model.available("basic")
	var held_tokens: Array = []
	var ids: Array = []
	for entry in entries.slice(0 if Content.uses_ammo_cards(model.s) else 1):
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
	var loaded: Array = (model.s.plan if model.s.phase == "plan" else model.s.magazine).duplicate()
	var field: Dictionary = model.s.get("field_compression",{})
	var compressed_copies := 2 if not field.is_empty() else 0
	for entry in entries:
		entry.held = held_tokens.has(entry.token)
		entry.zone = "available"
		if not entry.held: continue
		if loaded.has(entry.id):
			loaded.erase(entry.id)
			entry.zone="loaded"
		elif compressed_copies>0 and str(entry.id)==str(field.get("source","")):
			entry.zone="compressed"
			compressed_copies-=1
		else: entry.zone="used"
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
	return Content.AMMO[id].name + " · " + Content.grade_detail(id) + "   " + Readability.stats(id, model.s, true)

func _candidate_outcome(id: String) -> Dictionary:
	if not model.can_load(id):
		return {"text": model.load_block_reason(id), "positive": false}
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
		var result := "%s %s" % [Forecast.tag(int(shot.target), model.s.enemies), Forecast.outcome(shot)]
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
		_label(enemy_card, str(e.name), 18)
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
	_heat_report(body, model.s)
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
	reserve.tooltip_text = "재장전 시 남은 패도 버린 더미로 이동합니다. 뽑을 덱이 비면 버린 더미를 섞습니다. 다음 두 발은 순서 공개 · 나머지는 구성만 공개합니다."
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
	_label(flow, "재장전 · 새 패", 14, MUTED)
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

func _preview_hand_insertion() -> void:
	if not is_instance_valid(magazine_view) or not magazine_view.is_inside_tree(): return
	var grid := find_child("AmmoGrid", true, false)
	var hovered := ""
	var focused := ""
	if grid != null and not busy and model.s.phase == "plan":
		for button in grid.get_children():
			if not button is AmmoHandButton or not button.is_visible_in_tree() or button.disabled: continue
			if button.is_hovered(): hovered = button.ammo_id
			if button.has_focus(): focused = button.ammo_id
	magazine_view.preview_insertion(hovered if not hovered.is_empty() else focused)

func _preview_reload_heat() -> void:
	var heat_view := find_child("HeatGauge", true, false)
	var button := find_child("reload", true, false) as Button
	if heat_view != null:
		heat_view.preview_reload(not busy and button != null and not button.disabled and (button.is_hovered() or button.has_focus()))

func _activate_hand_card(button: Button, id: String, key: String) -> void:
	if button.suppress_activation or is_instance_valid(workspace_overlay): return
	_load(id,key)

func _hand_ammo_details(id: String = "") -> void:
	if busy: return
	var choices: Array=[]
	for entry in _hand_entries():
		if not choices.has(entry.id): choices.append(entry.id)
	for value in model.s.plan + model.s.magazine:
		if not choices.has(value): choices.append(value)
	if choices.is_empty(): return
	if not choices.has(id): id=str(choices[0])
	var index:=choices.find(id)
	var column:=_workspace("탄환 상세","길게 누르기 · 확인은 턴을 소모하지 않습니다")
	var details:=preload("res://redesign/ammo_hand_details.tscn").instantiate()
	column.add_child(details)
	details.get_node("Heading/Title").text=Content.AMMO[id].name
	var card: Control=details.get_node("Overview/Card")
	card.setup(id,1,model.s)
	var primary: Dictionary=Content.primary_stat(id,model.s)
	details.get_node("Overview/Stats/Power").text=str(primary.label)+" "+str(primary.value)+(" · 관통 %d"%Content.penetration(id,model.s) if Content.penetration(id,model.s)>0 else "")
	details.get_node("Overview/Stats/Heat").text="발열 %s · 현재 열 %d / %d"%[Content.heat_label(id,model.s),model.s.heat,Content.heat_limit(model.s)]
	var traits:=Content.grade_name(id)+" · 탄창 %d칸"%Content.slot_cost(id)
	var tune:=str(Content.AMMO[id].get("tune",""))
	if not tune.is_empty(): traits+=" · 화력 개조" if tune=="power" else " · 방열 개조"
	var constraint:=Content.compression_cost_text(id,model.s) if Content.is_compressed(id) else ""
	if not constraint.is_empty(): traits+=" · "+constraint
	details.get_node("Overview/Stats/Traits").text=traits
	details.get_node("Description").text=Readability.description(id,model.s)
	details.get_node("Status").text="지금 장전 가능" if model.can_load(id) else model.load_block_reason(id)
	for pair in [["Previous",-1],["Next",1]]:
		var button: Button=details.get_node("Heading/"+str(pair[0]))
		button.name="hand_detail_"+str(pair[0]).to_lower()
		button.disabled=choices.size()<2
		button.pressed.connect(_hand_ammo_details.bind(str(choices[posmod(index+int(pair[1]),choices.size())])))
		preload("res://redesign/combat_treatment.gd").finish_button(button)
	_workspace_focus_chain.call_deferred()

func _load(id: String, source_key: String = "") -> void:
	if busy: return
	var source := find_child(source_key if not source_key.is_empty() else "load_" + id, true, false) as Button
	var from: Vector2 = source.get_global_rect().get_center() if source else Vector2(300, 500)
	var insertion_index := Content.insertion_index(model.s.plan, id)
	if model.load_round(id):
		feedback.play("load")
		if id != "basic" or Content.uses_ammo_cards(model.s): used_hand_tokens.append(str(source.name) if source else "load_" + id)
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
		feedback.play("confirm")
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

func _field_compression_choices() -> void:
	var panel := _workspace("임시 고급 압축", "코어 1개 · 발사/재장전 뒤 원본 두 장 복원 · 영구 덱은 바뀌지 않습니다.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
	for source in model.field_compressible_ids():
		var id := str(source)
		var cell := _panel(grid)
		var card := AmmoCardView.new()
		card.custom_minimum_size = Vector2(270, 154)
		card.setup(Content.field_id(id), 1, model.s)
		cell.add_child(card)
		_label(cell, Content.compression_cost_text(Content.field_id(id), model.s), 17, MUTED)
		_button(cell, "임시 압축 · 코어 1개", "field_choose_" + id, func():
			_close_workspace()
			_field_compress_click(id)
		)

func _undo() -> void:
	if busy: return
	_remove_slot(0)

func _confirm() -> void:
	if busy: return
	if model.confirm():
		feedback.play("confirm")
		_changed()

func _fire() -> void:
	if busy: return
	var before: Dictionary = model.s.duplicate(true)
	if model.fire():
		var detail: Dictionary = model.s.history.back().detail
		await _present(before, detail.results, detail.get("advance_events", []), false, detail.get("deployments", []), detail)

func _reload() -> void:
	if busy: return
	var before: Dictionary = model.s.duplicate(true)
	if model.reload_magazine():
		var detail: Dictionary = model.s.history.back().detail
		await _present(before, [], detail.get("advance_events", []), true, detail.get("deployments", []))

func _choose(id: String, remove_id: String) -> void:
	if busy: return
	if model.choose_reward(id, remove_id):
		feedback.play("confirm")
		_changed()

func _present(before: Dictionary, results: Array, advance_events: Array, reloading: bool, deployments: Array = [], fire_detail: Dictionary = {}) -> void:
	feedback.begin_action()
	busy = true
	_persist()
	find_child("skip_animation", true, false).show()
	magazine_view.forecast = {}
	magazine_view.queue_redraw()
	for button in find_children("*", "Button", true, false):
		button.disabled = button.name != "skip_animation"
	battle_view.speed_scale = presentation_speed
	var forced: Dictionary = fire_detail.get("forced_reload", {})
	var shown_events: Array = []
	if not forced.is_empty():
		var intermediate: Dictionary = before.duplicate(true)
		intermediate.enemies = fire_detail.firing_enemies.duplicate(true)
		intermediate.projectiles = fire_detail.firing_projectiles.duplicate(true)
		intermediate.reinforcements = fire_detail.firing_reinforcements.duplicate(true)
		intermediate.turns = int(before.turns) + 1
		intermediate.heat = int(results.back().heat_after)
		intermediate.phase = "ready"
		await battle_view.play_action(before, intermediate, results, advance_events, false, deployments)
		shown_events = battle_view.visual_events.duplicate(true)
		preview_label.text = "과열 · 강제 재장전 %d턴" % int(forced.cost)
		await battle_view.play_action(intermediate, model.s, [], forced.get("advance_events", []), true, forced.get("deployments", []))
	else:
		await battle_view.play_action(before, model.s, results, advance_events, reloading, deployments)
	shown_events.append_array(battle_view.visual_events)
	last_presentation = {"before": before, "after": model.s.duplicate(true), "shown_enemies": battle_view.enemies.duplicate(true), "events": shown_events}
	busy = false
	redraw()

func _visual_shot(result: Dictionary) -> void:
	feedback.shot(result)
	preload("res://redesign/ui_impulse.gd").flash(find_child("fire",true,false) as Button,Color("edc47a"))
	var action := find_child("fire", true, false) as Button
	if action: action.text = "연쇄 발사" if Content.chains(model.s) else "사격 중"
	magazine_view.consume()
	for view in combat_parts.values():
		view.activated = false
		view.queue_redraw()
	preview_label.text = "%s  →  %s" % [AmmoVisual.SHORT[str(result.id)], Forecast.tag(int(result.target), model.s.enemies)]
	preview_label.tooltip_text = str(result.text)

func _visual_impact(result: Dictionary) -> void:
	feedback.impact(result)
	magazine_view.show_impact()
	magazine_view.show_pending_boost(result.get("pending_boost", {}))
	var heat_view := find_child("HeatGauge", true, false)
	if heat_view: heat_view.show_value(int(result.get("heat_after", 0)))
	var effects: Array = result.get("part_effects", [])
	for effect in effects:
		if combat_parts.has(str(effect.id)):
			combat_parts[str(effect.id)].activated = true
			combat_parts[str(effect.id)].queue_redraw()
	magazine_view.impact_active = int(result.get("detonation", 0)) > 0 or int(result.get("chase_bonus", 0)) > 0 or not effects.is_empty() or int(result.get("focus_damage", 0)) > 0 or int(result.get("math", {}).get("boost", 0)) > 0 or int(result.get("math", {}).get("factor", 1)) > 1
	magazine_view.queue_redraw()
	preview_label.text = "%s → %s  −%d" % [AmmoVisual.SHORT[str(result.id)], Forecast.tag(int(result.target), model.s.enemies), int(result.damage)]
	if not Content.is_attack(str(result.id)):
		var readout := preload("res://redesign/damage_readout.gd").entry(result)
		preview_label.text = "%s · %s %s" % [Content.AMMO[str(result.id)].name, readout.number, readout.label]
	if int(result.get("math", {}).get("factor", 1)) > 1: preview_label.text += " · 배율 ×%d" % int(result.math.factor)
	if not effects.is_empty():
		preview_label.text += " · %s %s" % [Content.PARTS[str(effects[0].id)].name, effects[0].label]
	if int(result.get("focus_damage", 0)) > 0:
		preview_label.text += " · 집중 +%d" % int(result.focus_damage)
	elif int(result.get("math", {}).get("boost", 0)) > 0:
		preview_label.text += " · 증폭 +%d" % int(result.math.boost)

	if not result.get("prepared_rounds", []).is_empty(): preview_label.text += " · 다음 패 %d장 예약" % result.prepared_rounds.size()
	for entry in [["sequence_bonus", "탄종 연계 +%d"], ["interrupted", "차단 %d턴"], ["transferred", "화상 이동 %d"], ["armor_removed", "장갑 −%d"], ["detonation", "기폭 %d"], ["chase_bonus", "추격 +%d"], ["cooled", "냉각 −%d"]]:
		if int(result.get(entry[0], 0)) > 0: preview_label.text += " · " + str(entry[1]) % int(result[entry[0]])

func _heat_feedback(event: Dictionary) -> void:
	feedback.heat_event(event)
	var kind := str(event.get("kind", ""))
	# Follow firing/cooling events immediately, rather than waiting for impact.
	if kind in ["heat_added", "heat_removed", "kill_cooling"]:
		var gauge := find_child("HeatGauge", true, false)
		if gauge: gauge.show_value(int(event.heat))
		return
	var action := find_child("fire", true, false) as Button
	if action == null: action = find_child("confirm", true, false) as Button
	var warning := find_child("OverheatWarning", true, false) as Label
	var reload_action := find_child("reload", true, false) as Button
	if kind in ["reload_turn", "cooling_turn"]:
		preload("res://redesign/ui_impulse.gd").flash(reload_action,Color("9abdc8"))
		var turn := int(event.turn) + 1
		var total := int(event.total)
		preload("res://redesign/ui_impulse.gd").steps(reload_action,turn,total)
		if action: action.text = "%s %d/%d" % ["냉각 중" if kind == "cooling_turn" else "재장전", turn, total]
		if warning:
			warning.text = "적 행동 %d / %d턴" % [turn, total]
			warning.show()
		if reload_action:
			reload_action.text = "냉각 진행 중\n열 %d → %d" % [int(event.heat), int(model.s.heat)]
		preview_label.show()
		preview_label.text = "추가 냉각 · 적 접근" if kind == "cooling_turn" else "재장전 · 적 접근"
	elif kind == "overheat_lock":
		preload("res://redesign/ui_impulse.gd").flash(action,Color("ed9167"))
		if action: action.text = "과열 · 사격 중단"
	elif kind == "reload_complete":
		preload("res://redesign/ui_impulse.gd").flash(reload_action,Color("9abdc8"))
		var heat_view := find_child("HeatGauge", true, false)
		if heat_view: heat_view.show_value(int(event.get("heat", 0)))
		if action: action.text = "냉각 완료"
		if warning: warning.hide()
		if reload_action: reload_action.text = "재장전 완료\n남은 열 %d" % int(event.heat)
		preview_label.text = "냉각 완료 · 열 %d" % int(event.heat)

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
	if Model.Engines.IDS.has(id):
		_label(column, Model.Engines.value(model.s,id), 24, ACCENT)
		_label(column, Model.Engines.progress(model.s,id), 18, MUTED)
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
	var details := _button(row, "기록", "encounter_record", _encounter_record.bind(current))
	details.autowrap_mode = TextServer.AUTOWRAP_OFF
	details.size_flags_horizontal = Control.SIZE_SHRINK_END
	details.custom_minimum_size = Vector2(64, 40)
	for id in state.get("engine",{}).get("gains",[]):
		var growth := _label(parent, "%s 성장 · %s" % [Content.PARTS[id].name,Model.Engines.value(state,id)], 22, ACCENT)
		growth.name = "EngineGrowth"
	_heat_report(parent, current)
	var highlights := HFlowContainer.new()
	highlights.add_theme_constant_override("h_separation", 24)
	parent.add_child(highlights)
	for item in PartFeedback.highlights(current):
		var text := _label(highlights, str(item.text), 16, MUTED)
		text.name = "BuildHighlight_" + str(item.id)
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		text.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		text.tooltip_text = "한 탄환에 여러 타격이 있어도 발동은 1발로 기록합니다. 발동 횟수를 추가 HP 피해로 합산하지 않습니다."
	highlights.visible = highlights.get_child_count() > 0

func _heat_report(parent: Node, state: Dictionary) -> void:
	var report := RunInsight.combat_report(state)
	if int(report.shots) == 0: return
	var row := _row(parent)
	row.name = "HeatReport"
	row.tooltip_text = RunInsight.heat_report_tip(report)
	# Three open columns, no extra panels. Numbers lead; details live in the record.
	for item in [["최고 열", str(report.heat_peak), INK], ["탄·파츠 냉각", "−%d" % report.cooled if int(report.cooled) > 0 else "0", INK], ["강제 재장전", "%d회" % report.forced_reloads, DANGER if int(report.forced_reloads) > 0 else MUTED]]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		column.tooltip_text = row.tooltip_text
		row.add_child(column)
		_label(column, str(item[0]), 15, MUTED)
		_label(column, str(item[1]), 27, item[2])

func _encounter_record(state: Dictionary) -> void:
	var column := _workspace("교전 기록", "이번 전투에서 실제로 발생한 효과입니다.")
	_label(column, RunInsight.combat_report_line(state), 20, ACCENT)
	_heat_report(column, state)
	_label(column, RunInsight.heat_report_tip(RunInsight.combat_report(state)), 17, MUTED)
	for event in state.get("history", []):
		if str(event.get("action", "")) != "fire": continue
		for shot in event.get("detail", {}).get("results", []):
			_label(column, str(shot.get("text", "")), 18)

func _skip_animation() -> void:
	if busy and is_instance_valid(battle_view):
		feedback.skip_action()
		battle_view.fast_forward = true

func _dialog(title: String, compact: bool = false) -> VBoxContainer:
	var dialog = preload("res://redesign/console_dialog.tscn").instantiate()
	add_child(dialog)
	return dialog.setup(self, title, compact)

func _confirmation(title: String, message: String, key: String, accept_text: String, cancel_text: String, callback: Callable) -> Control:
	var column := _dialog(title, true)
	var dialog: Control = column.get_meta("dialog")
	dialog.name = key
	_label(column, message, 21, INK)
	dialog.ask(accept_text, cancel_text, callback)
	return dialog

var workspace_return_focus: WeakRef

func _workspace(title: String, subtitle: String = "") -> VBoxContainer:
	_close_workspace()
	var prior := get_viewport().gui_get_focus_owner()
	if prior != null: workspace_return_focus = weakref(prior)
	var overlay := PanelContainer.new()
	overlay.name = "WorkspaceOverlay"
	var battle_overlay: bool = page == "run" and model.s.get("phase", "") in ["plan", "ready"]
	if battle_overlay:
		var overlay_theme := ui_theme.duplicate() as Theme
		overlay_theme.default_font = preload("res://redesign/combat_pixel_font.tres")
		overlay.theme = overlay_theme
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
	if battle_overlay: preload("res://redesign/combat_surface.gd").finish_button(close)
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
	if forecast_refresh_waiting:
		forecast_refresh_waiting = false
		_forecast_completed.call_deferred()

func _apply_preferences() -> void:
	presentation_speed = preferences.motion_scale()
	feedback.configure(preferences.data)
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
		["2", "순서를 읽는다", "마지막에 넣은 탄이 맨 앞에서 발사됩니다. 증폭은 다음 공격탄, 화상은 전진 직전, 전이는 다른 생존 적에게 적용됩니다."],
		["3", "열과 시간을 확인한다", "열 한계에 닿으면 사격이 끊기고 강제 재장전합니다. 냉각탄은 그 전에 놓으세요. 예상 처치와 총 경과 턴을 확인한 뒤 확정하고 쏩니다."],
	]
	for entry in steps:
		var panel := _panel(column)
		var row := _row(panel)
		var badge := _label(row, str(entry[0]), 34, ACCENT)
		badge.custom_minimum_size.x = 48
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		_label(copy, str(entry[1]), 24, INK)
		_label(copy, str(entry[2]), 17, MUTED)
	var flow := _panel(column)
	_label(flow, "도시 흐름", 22, ACCENT)
	_label(flow, "경로 선택  →  전투/보급/무기고  →  구역 관문  →  정상 제어실", 19)
	_label(flow, "처음에는 7교전 기초 훈련으로 탄환 효과만 익힐 수 있습니다.", 17, MUTED)

func _settings() -> void:
	if busy:
		return
	var column := _dialog("설정 · 읽기와 소리", true)
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
	var audio_row := _row(column)
	_label(audio_row, "효과음", 20).custom_minimum_size.x = 170
	var audio_option := OptionButton.new()
	audio_option.name = "EffectsVolumeSetting"
	audio_option.custom_minimum_size = Vector2(260, 48)
	for percent in [0, 25, 50, 75, 100]:
		audio_option.add_item("끄기" if percent == 0 else "%d%%" % percent)
		if roundi(float(preferences.data.effects_volume) * 4) == audio_option.item_count - 1:
			audio_option.select(audio_option.item_count - 1)
	audio_row.add_child(audio_option)
	audio_option.item_selected.connect(func(index: int):
		preferences.set_value("effects_volume", index * 0.25)
		feedback.configure(preferences.data)
		feedback.play("load")
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
	var column := _dialog("파츠 아이콘 · %d종 미리보기" % (Content.PARTS.size() - 1))
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
	_label(column, "마지막 장전부터 발사 · 피해와 관통", 30, ACCENT)
	_label(column, "1. 피해는 타격당 기본 화력, 관통은 무시하는 장갑입니다. 마지막에 넣은 탄부터 발사합니다. 레일은 실제 발사 순서이며 확정 전에는 이동하거나 회수할 수 있습니다.")
	_label(column, "2. 보행자·쇄도·산개·압쇄는 한 탄창을 1턴에 연쇄 발사합니다. 증강은 1발을 쏘고, 주 표적을 처치하면 다음 탄도 이어 쏩니다. 한 번의 발사가 끝나면 1턴이 지나고 살아남은 적이 전진합니다.")
	_label(column, "발열 · 한계에 닿은 탄까지 효과를 처리한 뒤 사격을 중단합니다. 적이 남으면 기본 재장전 + 냉각 1턴이 자동 진행됩니다. 냉각탄은 과열 전에 놓으세요. 일반 재장전은 무기별 일정량만 냉각하고 남은 열은 다음 탄창에 이어집니다. 강제 재장전은 열을 0으로 낮춥니다.", 19, ACCENT)
	_label(column, "3. 보행자는 공격탄 피해 +1, 기본탄 피해 +1. 증폭·파쇄·냉각은 공격탄 보너스에서 제외합니다. 쇄도는 같은 적의 주 타격 3회마다 추가 피해 4. 연타탄의 두 타격은 각각 세며 화상/전이는 세지 않습니다.")
	_label(column, "4. 산개는 탄환마다 살아 있는 적 중 무작위 표적을 선택합니다. 확률과 HP 범위가 예상이며 확정 결과가 아닙니다. 나머지는 가장 가까운 적부터 조준합니다.")
	_label(column, "5. 압쇄는 화상 턴당 피해 2와 전이 피해 3. 증강은 탄환 기본 피해/관통과 증폭/넉백/화상 피해/전이 강도 2배입니다. 기본 연타탄은 2타, 증폭은 다음 공격탄에 적용하며, 화상 기간은 유지합니다.")
	_label(column, "6. 일반 증폭은 다음 공격 1발 +3, 고급 증폭은 공격 2발, 배율탄은 다음 공격 ×2입니다. 지원탄은 강화 효과를 소비하지 않습니다. 일반·잔열 증폭은 서로 교체하고 배율도 중첩하지 않습니다. 덧셈과 배율은 함께 쓸 수 있습니다. 배율 공격은 추가 열 +3, 잔열 증폭은 공격 직전 고열이 필요합니다. 증강의 배율탄은 ×3입니다. 화상은 전진 직전에 진행합니다. 실제 총기 수치와 효과는 탄환 카드에서 확인하세요.")
	_label(column, "7. 재장전마다 남은 패를 순환하고 복장 가방만큼 새 패를 뽑습니다. 작업복은 5장/교환1회, 운반복은 6장/0회, 정찰복은 4장/2회로 시작합니다. 정비소·관문에서 다른 보상 대신 가방을 +1장 확장하며 최대 10장입니다. 기본탄도 가방에 포함되는 개별 카드입니다. 사용한 탄은 버린 더미로 이동하고, 뽑을 더미가 비면 다시 섞습니다. 공격 없이 재장전해도 적은 재장전 턴만큼 전진합니다. 교환 횟수도 복구합니다. 예비 급탄기는 교환 +1회입니다. 기존 복장 미지정 등반은 이전 가방 규칙을 유지합니다. 넉백은 일반 탄창 총 2m, 증강은 4m까지입니다. 관문 용량 +2는 파츠와 독립적입니다.")
	_label(column, "8. 회색 한 줄은 일반, 파란 두 줄은 고급입니다. 같은 일반탄 2장을 고급 1장으로 압축합니다. 상점에서는 방문당 1회 18Cr, 정비소·관문에서는 기존 정비/보상을 사용합니다. 덱은 최소 8장, 고급 재압축은 아직 지원하지 않습니다.")
	_label(column, "9. 전투 압축은 코어 1개를 쓰는 임시 고급탄입니다. 작은 금색 점이 임시 상태입니다. 확정 전 회수하면 두 발과 코어 복구, 발사/재장전 뒤에는 원본 두 장만 돌아옵니다. 영구 등급은 바뀌지 않습니다. 코어는 상점에서 최대 2개까지 충전합니다.")
	_label(column, "10. 상층 부유체는 3턴마다 다른 적을 2m 당기고, 흡수 구체는 직접 타격으로 배리어를 먼저 소모하며, 태세 드론은 전진 뒤 장갑 4와 0을 교대합니다.")
	_label(column, "11. 탑의 여러 구역을 지나 정상으로 향합니다. 매 등반의 경로와 시설이 달라집니다. 파츠는 최대 5개를 함께 장착하고 금색 코어는 하나만 사용합니다. 청록 ▲는 이점, 적색 ▼는 패널티입니다.")

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
		_label(column, "탄환마다 생존 표적을 다시 무작위 선택합니다. 연타탄의 두 타격은 같은 표적입니다. 피해가 흩어지는 비용을 큰 탄창으로 보상하며, 예측은 HP 범위와 처치 확률을 보여 줍니다.", 18)
	elif id == "heavy":
		_label(column, "소이의 화상은 기간을 유지하며 턴당 2피해, 전격은 다른 생존 적에게 3피해를 전달합니다. 물리탄에는 별도 관통 보정이 없습니다.", 18)
	elif id == "burst":
		_label(column, "적별 주 타격을 셉니다. 3번째 타격 후 추가 피해 4, 다시 0부터 누적합니다. 재장전 후에도 진도 유지, 표적 처치 시 진도 종료. 전이와 화상은 집계하지 않습니다.", 18)
	elif id == "amplifier":
		_label(column, "기본 피해/관통 2배 · 증폭 +4 · 충격 4m · 화상 턴당 2 · 전이 4. 타격 수와 지속 기간은 유지합니다. 주 표적 처치 시 다음 탄도 이어 쏘며, 생존 표적에서 멈춘 뒤 적이 전진합니다.", 18)
	var loadout := selected_loadout_id if page == "loadout" else (str(campaign.s.loadout) if campaign != null else "balanced")
	var deck: Array = CampaignContent.Acquisition.start_deck()
	_label(column, "출발 탄환 · 기본탄 %d장" % deck.size(), 20, ACCENT)
	_label(column, RunInsight.deck_summary(deck), 18)
	_label(column, "기본탄으로 출발 · 첫 승리 후 코어와 특수탄 선택", 18, MUTED)
	_label(column, "첫 특수탄 보급 선호 · " + CampaignContent.LOADOUTS[loadout].name, 16, MUTED)
	_label(column, "기초 훈련에서는 무기와 관계없이 같은 순서로 탄환을 배웁니다.", 16, MUTED)

func _inspect_slot(index: int) -> void:
	if busy or not is_instance_valid(calculation_label): return
	selected_slot = index
	magazine_view.selected_index = index
	magazine_view.queue_redraw()
	_update_slot_actions()
	if forecast_pending:
		calculation_label.text = "예측 계산 중입니다. 완료되면 이 탄의 피해와 열 변화를 확인할 수 있습니다."
	elif full_forecast.shots.is_empty():
		calculation_label.text = Readability.explain({}) if model.s.phase == "plan" else "다음 탄창을 장전하세요."
	elif index >= full_forecast.shots.size() or float(full_forecast.shots[index].get("used_probability", 1.0)) == 0.0:
		var hot_chance := float(full_forecast.get("heat", {}).get("overheat_probability", 0))
		var reason := "앞선 탄에서 과열되어" if hot_chance >= 0.999999 else ("과열 또는 전투 종료로" if hot_chance > 0 else "전투가 먼저 끝나")
		calculation_label.text = "%d번 · %s 이 탄은 발사되지 않습니다." % [index + 1, reason]
	else:
		var shot: Dictionary = full_forecast.shots[index]
		calculation_label.add_theme_color_override("font_color", INK)
		calculation_label.text = "%d번 %s → " % [index + 1, Content.AMMO[shot.id].name] + Readability.explain(shot, model.s.enemies)
		calculation_label.text = ("이번 발사\n" if int(shot.get("action", 0)) == 0 else "%d번째 발사 시 · 중간 재장전 없음\n" % (int(shot.action) + 1)) + calculation_label.text
		var sequence_note := Forecast.note(full_forecast, index)
		if not sequence_note.is_empty(): calculation_label.text += "\n순서 효과 · " + sequence_note

func _slot_action(index: int) -> void:
	if busy: return
	_inspect_slot(index)
	_highlight_slot_targets(index)
	if model.s.phase == "ready": _slot_details()

func _highlight_slot_targets(index: int) -> void:
	if busy or not is_instance_valid(battle_view): return
	battle_view.preview_targets.clear()
	var shots: Array = full_forecast.get("shots", [])
	if index >= 0 and index < shots.size():
		var shot: Dictionary = shots[index]
		if shot.get("random", false):
			for candidate in shot.get("targets", []):
				if float(candidate.get("probability", 0)) > 0: battle_view.preview_targets.append(int(candidate.target))
		else:
			battle_view.preview_targets.append(int(shot.target))
			for other in shot.get("secondary", []):
				battle_view.preview_targets.append(int(other.target))
	battle_view.queue_redraw()

func _slot_details() -> void:
	if busy: return
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	if stack.is_empty(): return
	_inspect_slot(clampi(selected_slot, 0, stack.size() - 1))
	var column := _workspace("탄환 계산 · %d번" % (selected_slot + 1), "발사 순서의 선택한 탄 · 확인은 턴을 소모하지 않습니다")
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

func _ammo_synergy() -> void:
	if busy or model.s.phase != "plan": return
	var column := _workspace("탄환 연계", "효과가 맞물리는 후보 · 추가 보너스 규칙은 없습니다")
	column.name = "AmmoSynergyDetails"
	_label(column, "발사 순서 → 로 표시합니다. 장전은 반대로, 마지막에 넣은 탄이 먼저 나갑니다.", 18, MUTED)
	var links: Array = []
	if model.s.plan.is_empty(): links = AmmoSynergy.hand_pairs(model.s)
	else: links = AmmoSynergy.hand_hints(model.s).values()
	if links.is_empty():
		_label(column, "현재 패·표적·발열에서 확인되는 연결이 없습니다. 탄을 회수하거나 교환해 다른 구성을 살펴보세요.", 19)
	for link in links:
		var row := _row(column)
		for id in [link.first,link.second]:
			var icon := AmmoVisual.new()
			icon.ammo_id = str(id)
			icon.custom_minimum_size = Vector2(38,52)
			row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_label(info, AmmoSynergy.text(link), 19, Color("e4bd72"))
		var instruction := "장전: %s → %s" % [Content.AMMO[link.second].name, Content.AMMO[link.first].name]
		if link.has("move"): instruction = "장전 후 레일 맨 뒤로 이동" if link.move else "지금 장전하면 앞에서 연결"
		_label(info,instruction,17,MUTED)
	_label(column, "후보는 최적해를 뜻하지 않습니다. 발열·처치·발사 중단은 레일에서 확인하세요.",17,MUTED)

func _ammo_bag() -> void:
	if busy: return
	var column := _workspace("탄환 가방", "보유 탄과 순환 상태 · 확인은 턴을 소모하지 않습니다")
	var bag := preload("res://redesign/ammo_bag_view.tscn").instantiate()
	column.add_child(bag)
	bag.setup(self)

func _exchange_dialog() -> void:
	if busy or model.s.phase != "plan" or model.s.exchange_left <= 0: return
	var column := _dialog("탄환 1장 교환", true)
	column.name = "ExchangeDialog"
	_label(column, "다음 탄: " + (_ammo_names(model.s.draw.slice(0, 1)) if not model.s.draw.is_empty() else "버린 더미에서 무작위"), 20, ACCENT)
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
	_label(column, "진행 %d턴 · 현재 적 %d · 증원 %d" % [model.s.turns, model.alive_count(), model.reserve_count()], 18, MUTED)
	if campaign != null: _label(column, "크레딧 %d · 압축 코어 %d" % [campaign.s.credits, campaign.s.compressor_charges], 18, MUTED)
	_label(column, "적 정보", 22, ACCENT)
	for e in model.s.enemies:
		_label(column, "%s · HP %d/%d · 장갑 %d · 화상 %d\n거리 %dm · 접근 %dm\n%s" % [e.name, e.hp, e.max_hp, e.def, e.burn, e.distance, e.speed, Content.enemy_rule(e)], 18)
	_label(column, "탄환 · 현재 총기/파츠 반영", 22, ACCENT)
	var ids: Array = [] if Content.uses_ammo_cards(model.s) else ["basic"]
	for id in model.s.deck:
		if not ids.has(id): ids.append(id)
	for id in ids:
		_label(column, _ammo_stats(id), 19, AmmoVisual.COLORS[id])
		_label(column, "재장전 시 %d발 공급" % model.supply_capacity() if id == "basic" and not Content.uses_ammo_cards(model.s) else Readability.description(id, model.s), 17, MUTED)
	_label(column, "덱 %d장 · 남은 덱 %d · 사용탄 %d\n%s" % [model.s.deck.size(), model.s.draw.size(), model.s.discard.size(), _ammo_names(model.s.deck)], 18)
	_label(column, "최근 결과\n" + str(model.s.message), 18, MUTED)

func _enemy_details(index: int) -> void:
	if busy or index < 0 or index >= model.s.enemies.size(): return
	var e: Dictionary = model.s.enemies[index]
	var column := _workspace("적 정보", "현재 능력과 아이콘 · 자동 조준은 유지됩니다")
	column.name = "EnemyDetails"
	column.set_meta("enemy_index", index)
	_label(column, str(e.name), 26, ACCENT)
	_label(column, "HP %d/%d" % [e.hp, e.max_hp], 21)
	_label(column, "거리 %dm · 다음 접근 %dm" % [e.distance, e.speed], 19, MUTED)
	if model.s.gun == "burst":
		_label(column, "집중 %d/3 · 같은 적 3회 적중마다 추가 피해 4\n재장전 후에도 유지 · 보호에 막힌 타격은 누적되지만 추가 피해는 막힙니다." % int(e.get("focus_hits", 0)), 18, ACCENT)
	var icons = preload("res://redesign/enemy_status_icons.gd")
	for entry in icons.entries(e):
		var row := _row(column)
		var icon: Control = icons.new()
		icon.icon_id = entry.icon
		icon.custom_minimum_size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		_label(row, entry.text, 18, icons.COLORS[entry.icon])
	var rule := Content.enemy_rule(e)
	if not rule.is_empty():
		var rule_panel := _panel(column)
		_label(rule_panel, "행동 규칙", 17, ACCENT)
		_label(rule_panel, rule, 18)

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

func _developer_lab() -> void:
	_close_workspace()
	var prior := get_viewport().gui_get_focus_owner()
	if prior != null: workspace_return_focus = weakref(prior)
	var lab: Control = preload("res://redesign/developer_lab.tscn").instantiate()
	lab.z_index = 100
	lab.close_requested.connect(_close_workspace)
	workspace_overlay = lab
	add_child(lab)
	_workspace_focus_chain.call_deferred()

func _developer() -> void:
	campaign = null
	var column := _dialog("개발자 테스트 · 기존 저장 보존")
	_label(column, "화면과 규칙을 즉시 확인하는 연습", 26)
	_button(column, "복장 작업실 · 4종 동작 비교", "debug_outfits", func():
		column.get_meta("dialog").hide()
		column.get_meta("dialog").queue_free()
		var preview := preload("res://redesign/outfit_preview.tscn").instantiate()
		add_child(preview)
	)
	_button(column, "개발 작업대 · UI 점검 / 탄환·파츠 실험", "debug_lab", func():
		column.get_meta("dialog").hide()
		column.get_meta("dialog").queue_free()
		_developer_lab()
	)
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
	for sample in [["연속 타격", "volley_drive"], ["고열 화력", "thermal_drive"], ["단발 집중", "siege_drive"], ["탄종 집약", "ordinary"], ["압축 준비", "compressed"], ["화상 추격", "burn"]]:
		_button(column, "파츠 빌드 · " + sample[0], "debug_parts_" + sample[1], func():
			column.get_meta("dialog").queue_free()
			_debug_part_build(str(sample[1]))
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
	_button(column, "전투 비주얼 · 장전과 과열", "debug_combat_finish", func():
		column.get_meta("dialog").hide()
		_debug_combat_finish()
		column.get_meta("dialog").queue_free()
	)
	var background_row := _row(column)
	for stage in range(3):
		_button(background_row, "구역 배경 · " + ["초반", "중반", "상층"][stage], "debug_background_%d" % stage, func():
			column.get_meta("dialog").hide()
			_debug_ascent_background(stage)
			column.get_meta("dialog").queue_free()
		)
	_button(column, "몬스터 동작 · 처마등", "debug_eavesback", func():
		column.get_meta("dialog").hide()
		_debug_eavesback()
		column.get_meta("dialog").queue_free()
	)
	_button(column, "몬스터 시안 · 주거 통로", "debug_residential_creatures", func():
		column.get_meta("dialog").hide()
		_debug_eavesback(true)
		column.get_meta("dialog").queue_free()
	)
	var challenge_row := _row(column)
	for encounter_kind in ["elite","boss"]:
		_button(challenge_row,"정예 · 공명 처마등" if encounter_kind == "elite" else "보스 · 폐쇄 당직","debug_challenge_" + encounter_kind,func():
			column.get_meta("dialog").hide()
			_debug_challenge(encounter_kind)
			column.get_meta("dialog").queue_free()
		)
	var city_row := GridContainer.new()
	city_row.columns = 3
	column.add_child(city_row)
	for entry in [["출발 장면 · 밸브", "departure"], ["탑 탐사도", "map"], ["크레딧 무기고", "shop"], ["탄환 보급", "supply"], ["정비 작업대", "workshop"], ["선택 이벤트", "event"], ["관문 압축 선택", "gate"], ["정상 복구 · 귀환", "ending"], ["도시 패배 정산", "loss"], ["도시 전투 보상", "reward"], ["덱·장비", "deck"], ["기록실", "archive"]]:
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
		# Show all three physical constraints in one real magazine: first fitting,
		# a two-cell body, and the last fitting.
		model.load_round("pierce_c")
		model.load_round("precise_c")
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
		for id in Content.loading_order(["charge", "precise", "arc", "pierce"]): model.load_round(id)
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
		for id in Content.loading_order(["bore", "push", "charge", "precise", "arc"]): model.load_round(id)
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
		model.load_round("precise")
		model.load_round("charge")
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
		for id in Content.loading_order(["bore", "push", "precise", "charge"]): model.load_round(id)
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

func _campaign_action(command: String, value: Variant = "", extra: String = "", replacement: String = "") -> void:
	if busy or campaign == null: return
	var accepted := false
	match command:
		"departure_next": accepted = campaign.advance_departure()
		"departure_skip": accepted = campaign.advance_departure(true)
		"restore_supply": accepted = campaign.restore_supply()
		"enter": accepted = campaign.enter(int(value))
		"reward": accepted = campaign.reward(str(value), extra)
		"gate": accepted = campaign.gate(str(value), extra)
		"buy": accepted = campaign.buy(int(value), extra)
		"buy_compressor": accepted = campaign.buy_compressor_charge()
		"reroll": accepted = campaign.reroll()
		"shop_refine": accepted = campaign.shop_refine(str(value))
		"shop_compress": accepted = campaign.shop_compress(str(value))
		"tune": accepted = campaign.tune(int(value), extra)
		"equip": accepted = campaign.equip(str(value))
		"replace_part": accepted = campaign.replace_part(str(value), extra)
		"dismantle": accepted = campaign.dismantle(str(value))
		"resolve": accepted = campaign.resolve(str(value), extra, replacement)
		"leave": accepted = campaign.leave()
	if accepted:
		if command in ["reward", "buy", "buy_compressor", "shop_refine", "shop_compress", "tune", "equip", "replace_part"]:
			feedback.play("confirm")
		model = campaign.model
		selected_slot = 0
		inspect_slots = false
		previous_forecast = {}
		_changed()
		if command == "enter": _map_arrival_feedback.call_deferred(campaign, int(campaign.s.node))

func _ammo_acquired_notice(id: String, replaced: bool) -> void:
	if not is_inside_tree() or campaign == null: return
	var prior := get_node_or_null("AmmoAcquiredNotice")
	if prior != null:
		remove_child(prior)
		prior.queue_free()
	var notice := Label.new()
	notice.name = "AmmoAcquiredNotice"
	notice.text = "%s 확보 · %s · 덱 %d장" % [Content.AMMO[id].name,"기본탄과 교체" if replaced else "한 장 추가",model.s.deck.size()]
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.z_index = 190
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_override("font",preload("res://redesign/combat_pixel_font.tres"))
	notice.add_theme_font_size_override("font_size",_scaled(20))
	notice.add_theme_color_override("font_color",Color("e9dfc4"))
	notice.add_theme_stylebox_override("normal",_console_style("panel"))
	add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	notice.offset_left = -minf(310,size.x*0.45)
	notice.offset_right = minf(310,size.x*0.45)
	notice.offset_top = -86
	notice.offset_bottom = -26
	var motion: float = preferences.motion_scale()
	if str(preferences.data.motion) == "instant":
		var notice_ref: WeakRef = weakref(notice)
		get_tree().create_timer(1.8).timeout.connect(func():
			var live_notice = notice_ref.get_ref()
			if is_instance_valid(live_notice): live_notice.queue_free()
		)
		return
	var tween := notice.create_tween()
	notice.modulate.a = 0.0
	tween.tween_property(notice,"modulate:a",1.0,0.12*motion)
	tween.tween_interval(1.5)
	tween.tween_property(notice,"modulate:a",0.0,0.18*motion)
	tween.tween_callback(notice.queue_free)


func _map_arrival_feedback(expected_campaign, expected_node: int) -> void:
	if page != "run" or campaign != expected_campaign or int(campaign.s.node) != expected_node: return
	if str(preferences.data.motion) == "instant": return
	var old = get_node_or_null("MapArrivalFeedback")
	if old != null:
		remove_child(old)
		old.queue_free()
	var line := ColorRect.new()
	line.name = "MapArrivalFeedback"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Color("edc47a")
	add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_left = 10
	line.offset_right = -10
	line.offset_top = 2
	line.offset_bottom = 4
	var feedback := line.create_tween()
	feedback.tween_property(line, "modulate:a", 0.0, 0.18 * preferences.motion_scale()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	feedback.tween_callback(line.queue_free)

func _city_archive() -> void:
	var progress = Campaign.new()
	progress.restore()
	campaign = progress
	city_ui.ui = self
	city_ui.campaign = campaign
	city_ui.archive()

func _debug_part_build(kind: String) -> void:
	campaign = null
	debug_session = true
	model.start("single", 731042)
	var rounds: Array = ["charge", "precise", "pierce", "cool", "sequence", "bore"]
	var parts: Array = ["ordinary_chain", "chain_sink"]
	if Model.Engines.IDS.has(kind):
		rounds = ["basic","charge","precise","pierce","cool","charge_hot"]
		parts = [kind,"duplex" if kind=="volley_drive" else "supply","radiator"]
		model.s.outfit = "carrier"
	if kind == "compressed":
		rounds = ["shatter", "pierce_c", "cool", "bore_c", "charge", "push"]
		parts = ["compression_sink", "overbore", "lens"]
	elif kind == "burn":
		rounds = ["bore", "precise", "detonate", "chase", "cool", "spread"]
		parts = ["igniter", "reclaimer", "duplex"]
	model.s.deck = rounds + ["charge", "precise", "pierce", "cool"]
	model.s.equipped_parts = parts
	model.begin_encounter()
	model.s.hand = rounds.slice(0, Content.hand_capacity(model.s))
	model.s.draw = model.s.deck.duplicate()
	for id in model.s.hand: model.s.draw.erase(id)
	model.s.enemies = [CampaignContent._enemy(["wall", 22, 3, 1, 20]), CampaignContent._enemy(["runner", 16, 0, 2, 25]), CampaignContent._enemy(["runner", 14, 0, 2, 29])]
	model.assign_opening_lanes()
	model.s.encounter_total = 3
	model.s.deployed = 3
	model.s.floor = 6
	if kind == "compressed": model.s.heat = 5
	if kind == "thermal_drive": model.s.heat = Content.hot_threshold(model.s)
	hand_layout_key = ""
	show_full_forecast = false
	previous_forecast = {}
	page = "run"
	redraw()

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
	for round_id in Content.loading_order(["charge", "precise", "arc"]): model.load_round(round_id)
	debug_session = true
	selected_slot = 0
	inspect_slots = false
	previous_forecast = {}
	page = "run"
	redraw()

func _debug_combat_finish() -> void:
	_debug_eavesback(true)
	campaign.s.gun = "burst"
	model.s.gun = "burst"
	model.s.deck = ["basic", "precise", "charge_hot", "cool", "pierce", "arc", "bore", "push", "basic", "cool"]
	model.s.hand = model.s.deck.slice(0, 5)
	model.s.draw = model.s.deck.slice(5)
	model.s.discard = []
	model.s.heat = 5
	model.s.enemies[0].hp = 7
	model.s.enemies[0].max_hp = 7
	redraw()

func _debug_ascent_background(stage: int) -> void:
	_debug_eavesback(true)
	campaign.remove_meta("eavesback_preview")
	campaign.set_meta("background_preview", clampi(stage, 0, 2))
	var depth := ceili(float(clampi(stage, 0, 2) * int(campaign.region_info().floors)) / 3.0) + 1
	var rooms: Array = campaign.current_nodes().filter(func(room): return int(room.floor) == depth)
	campaign.s.floor = depth
	campaign.s.node = rooms[0].id
	redraw()

func _debug_eavesback(family: bool = false) -> void:
	hand_layout_key = ""
	show_full_forecast = false
	debug_session = true
	campaign = Campaign.new()
	campaign.start("single", 731042, 0, "balanced", 2)
	campaign.s.departure_step = 3
	campaign.enter(int(campaign.choices()[0].id))
	campaign.set_meta("eavesback_preview", true)
	if family: campaign.set_meta("creature_family_preview", true)
	model = campaign.model
	model.s.deck = ["pierce", "bore", "thermal", "charge", "arc", "cool", "pierce", "thermal", "bore", "arc"]
	model.begin_encounter()
	model.s.hand = model.s.deck.slice(0, Content.hand_capacity(model.s))
	model.s.draw = model.s.deck.slice(Content.hand_capacity(model.s))
	model.s.discard = []
	model.s.enemies = [CampaignContent._enemy(["wall", 24, 3, 1, 18]), CampaignContent._enemy(["spitter", 12, 0, 0, 26])]
	model.s.enemies[0].name = "처마등 · 시안"
	model.s.reinforcements = []
	model.s.encounter_total = 2
	model.s.deployed = 2
	if family:
		model.s.enemies = [
			CampaignContent._enemy(["runner", 12, 0, 2, 14]),
			CampaignContent._enemy(["wall", 24, 3, 1, 19]),
			CampaignContent._enemy(["evader", 18, 0, 1, 24]),
			CampaignContent._enemy(["spitter", 12, 0, 0, 29]),
		]
		for i in range(3): model.s.enemies[i].name = ["숨접이 · 시안", "처마등", "빗주머니 · 시안"][i]
		model.s.encounter_total = 4
		model.s.deployed = 4
	model.assign_opening_lanes()
	selected_slot = 0
	inspect_slots = false
	previous_forecast = {}
	page = "run"
	redraw()

func _debug_challenge(kind: String) -> void:
	debug_session = true
	campaign = preload("res://redesign/challenge_preview.gd").campaign(kind)
	model = campaign.model
	hand_layout_key = ""
	show_full_forecast = false
	previous_forecast = {}
	selected_slot = 0
	inspect_slots = false
	page = "run"
	redraw()

func _debug_city(kind: String) -> void:
	hand_layout_key = ""
	show_full_forecast = false
	debug_session = true
	campaign = Campaign.new()
	campaign.start("burst", 731042, 0, "balanced", 2 if kind in ["map", "departure", "workshop"] else 1)
	campaign.s.departure_step = 3
	campaign.s.credits = 75
	if kind == "departure": campaign.s.departure_step = 0
	if kind == "shop":
		campaign.s.floor = 3
		campaign.s.node = 301
		campaign.enter(401)
	elif kind == "supply":
		campaign.s.floor = 2
		campaign.s.node = 201
		campaign.enter(301)
	elif kind == "workshop":
		for room in campaign.current_nodes():
			if not room.get("workshop", false): continue
			campaign.s.node = room.id
			campaign.s.floor = room.floor
			campaign.s.phase = "supply"
			campaign.s.resolved = false
			break
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
