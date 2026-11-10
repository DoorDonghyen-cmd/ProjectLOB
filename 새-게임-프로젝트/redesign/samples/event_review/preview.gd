extends Control
## 사건·조우 시안 (2026-11-08). Review scene only: not linked to the main game yet.
##
## Reference principles (docs/art/references/2026-11-08-event/):
## - Slay the Spire events: a short prose block with the choices and their costs right
##   under it, in one reading column.
## - Citizen Sleeper: a prose column beside the scene; the place stays visible.
## Layout: the region's own corridor art (the same place an ambush would be fought) with
## the hero on the left; the right column holds title, prose, clue-bearing choices with
## their credit cost, then the revealed result and its single next action. Found rounds
## use the depot's bottom shelf. Rules are live Campaign rules on a staged run.
## F1/F2/F3: door / sealed crate / stalled cart. F4 reloads the same scene with a seed
## whose risky choice leads to an ambush. LOB_EVENT_CAPTURE=<dir> runs the check.
const Campaign = preload("res://redesign/campaign.gd")
const Ammo = preload("res://redesign/content.gd")
const Comparison = preload("res://redesign/ammo_comparison.gd")
const UIReadability = preload("res://redesign/ui_readability.gd")
const Encounters = preload("res://redesign/encounter_scenes.gd")
const Backgrounds = preload("res://redesign/ascent_background.gd")
const Actor = preload("res://redesign/weapon_actor.gd")
const Item = preload("res://redesign/workbench/item.tscn")
const GOLD := Color("e9c27f")
const IVORY := Color("ebe2d1")
const MUTED := Color("a59c8b")
const RED := Color("d9846c")
const KINDS := ["siphon", "archive", "salvage"]
const RISKY := {"siphon": "open", "archive": "unlock", "salvage": "pull"}

var run
var kind := "siphon"
var picked := ""
var backdrop: Texture2D
var floor_ratio := 0.71
var offer_buttons: Dictionary = {}
var offer_group := ButtonGroup.new()
var checks := 0
var failures := 0

var stage: Control
var shade: ColorRect
var region_label: Label
var credits_label: Label
var pass_button: Button
var panel: PanelContainer
var title_label: Label
var prose_label: Label
var choices_box: VBoxContainer
var result_tag: Label
var result_detail: Label
var action_row: HBoxContainer
var secondary: Button
var primary: Button
var shelf: ColorRect
var shelf_heading: Label
var offers_box: HBoxContainer
var offers_scroll: ScrollContainer
var stacks_scroll: ScrollContainer
var stacks_box: HBoxContainer
var stack_buttons: Dictionary = {}
var stack_group := ButtonGroup.new()
var menu_button: Button
## Found rounds can be added, or swapped like the depot (shelf turns into owned stacks).
var swapping := false
var outgoing := ""
## Main-game link (2026-11-08). configure() hands over the live campaign; choices,
## found rounds and passing by go through screen.gd::_campaign_action (autosave,
## no redraw). "전투 준비" and "지도로 계속" go through it with a redraw.
var live_host = null
var live_presenter = null

func configure(screen, presenter) -> void:
	live_host = screen
	live_presenter = presenter
	run = screen.campaign

func _ready() -> void:
	build()
	resized.connect(arrange)
	if live_host != null:
		enter_live()
		return
	get_window().size_changed.connect(fit_window)
	fit_window()
	Input.emulate_mouse_from_touch = true
	load_event("siphon", "")
	var output := OS.get_environment("LOB_EVENT_CAPTURE")
	if not output.is_empty():
		capture_review.call_deferred(output)

func enter_live() -> void:
	kind = str(run.node().get("event", "siphon"))
	picked = ""
	setup_scene()
	menu_button.tooltip_text = ""
	add_live_menu()
	refresh()

func add_live_menu() -> void:
	var menu_panel := PanelContainer.new()
	menu_panel.name = "UtilityMenu"
	menu_panel.visible = false
	menu_panel.theme_type_variation = &"Inspector"
	menu_panel.anchor_left = 1.0
	menu_panel.anchor_right = 1.0
	menu_panel.offset_left = -240.0
	menu_panel.offset_top = 64.0
	menu_panel.offset_right = -24.0
	add_child(menu_panel)
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	menu_panel.add_child(actions)
	for entry in [["Build", "내 빌드", live_presenter.deck], ["Archive", "기록", live_presenter.archive], ["Settings", "설정", live_host._settings], ["ReturnTitle", "타이틀로", live_host._to_menu], ["CloseMenu", "닫기", Callable()]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.custom_minimum_size = Vector2(0, 44)
		actions.add_child(button)
		button.pressed.connect(use_utility.bind(menu_panel, entry[2]))
	menu_button.pressed.connect(func(): menu_panel.visible = not menu_panel.visible)

func use_utility(menu_panel: Control, target: Callable) -> void:
	menu_panel.hide()
	if target.is_valid():
		target.call()

## Review fixture calls the rules directly; the live event uses the main handler.
func command(value: String, extra: String = "", replacement: String = "", redraw: bool = false) -> bool:
	if live_host != null:
		return live_host._campaign_action("resolve", value, extra, replacement, redraw)
	return run.resolve(value, extra, replacement)

## Corridor art of this region and depth (the place an ambush is fought).
func setup_scene() -> void:
	var depth := int(run.node().get("floor", 1))
	var profile := Backgrounds.profile(int(run.s.region), depth, int(run.region_info().floors))
	backdrop = Backgrounds.texture(profile)
	floor_ratio = float(profile.floor_y) / float(backdrop.get_height())
	region_label.text = "%s · %s" % [run.region_info().name, str(run.node().name)]

func fit_window() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = UIReadability.scale_for(window.size)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and swapping:
		swapping = false
		refresh()
		return
	if live_host != null: return
	match event.keycode:
		KEY_F1: load_event("siphon", "")
		KEY_F2: load_event("archive", "")
		KEY_F3: load_event("salvage", "")
		KEY_F4: load_event(kind, "combat")

# --- staging -----------------------------------------------------------------------

## A real run standing at an event of region 1 whose scene is `wanted_kind`. With
## `risky_outcome`, the seed is chosen so the risky choice gives that outcome type.
func load_event(wanted_kind: String, risky_outcome: String) -> void:
	for seed_value in range(251107, 252107):
		var candidate = Campaign.new()
		candidate.start("single", seed_value, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
		candidate.s.departure_step = 3
		var nodes: Array = candidate.current_nodes()
		var events: Array = nodes.filter(func(n): return n.kind == "event" and str(n.get("event", "")) == wanted_kind)
		if events.is_empty(): continue
		var node: Dictionary = events[0]
		if not risky_outcome.is_empty() and str(Encounters.outcome(wanted_kind, RISKY[wanted_kind], seed_value, int(node.id)).get("type", "")) != risky_outcome: continue
		var prior: Array = nodes.filter(func(n): return n.next.has(node.id))
		candidate.s.node = prior[0].id if not prior.is_empty() else 0
		candidate.s.floor = prior[0].floor if not prior.is_empty() else 0
		candidate.s.credits = 20
		if not candidate.enter(int(node.id)): continue
		run = candidate
		break
	kind = wanted_kind
	picked = ""
	swapping = false
	outgoing = ""
	setup_scene()
	refresh()

# --- layout --------------------------------------------------------------------------

func build() -> void:
	theme = preload("res://redesign/workbench/theme.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage = StageView.new()
	stage.name = "Stage"
	stage.host = self
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	var header_shade := ColorRect.new()
	header_shade.color = Color(0.036, 0.029, 0.022, 0.91)
	header_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_shade.offset_bottom = 68
	add_child(header_shade)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24; header.offset_right = -24; header.offset_top = 12; header.offset_bottom = 56
	header.add_theme_constant_override("separation", 12)
	add_child(header)
	var title := Label.new()
	title.text = "조우"
	title.theme_type_variation = &"SectionTitle"
	header.add_child(title)
	region_label = Label.new()
	region_label.name = "Region"
	region_label.theme_type_variation = &"Caption"
	region_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	region_label.clip_text = true
	header.add_child(region_label)
	credits_label = Label.new()
	credits_label.name = "Credits"
	credits_label.theme_type_variation = &"Caption"
	credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(credits_label)
	pass_button = Button.new()
	pass_button.name = "Pass"
	pass_button.text = "관여하지 않고 지나간다"
	pass_button.custom_minimum_size = Vector2(0, 44)
	pass_button.pressed.connect(pass_by)
	header.add_child(pass_button)
	menu_button = Button.new()
	menu_button.name = "Menu"
	menu_button.text = "메뉴"
	menu_button.custom_minimum_size = Vector2(72, 44)
	menu_button.tooltip_text = "시안에서는 동작하지 않습니다 · 본편에서는 정비소와 같은 메뉴"
	header.add_child(menu_button)

	panel = PanelContainer.new()
	panel.name = "Story"
	panel.theme_type_variation = &"Inspector"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	title_label = _label(column, "SceneTitle", &"SectionTitle")
	prose_label = _label(column, "Prose", &"")
	prose_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(HSeparator.new())
	choices_box = VBoxContainer.new()
	choices_box.name = "Choices"
	choices_box.add_theme_constant_override("separation", 6)
	column.add_child(choices_box)
	result_tag = _label(column, "ResultTag", &"")
	result_detail = _label(column, "ResultDetail", &"Caption")
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 8)
	column.add_child(action_row)
	secondary = Button.new()
	secondary.name = "Secondary"
	secondary.custom_minimum_size = Vector2(0, 44)
	secondary.pressed.connect(on_secondary)
	action_row.add_child(secondary)
	primary = Button.new()
	primary.name = "Primary"
	primary.theme_type_variation = &"PrimaryButton"
	primary.custom_minimum_size = Vector2(0, 44)
	primary.pressed.connect(on_primary)
	action_row.add_child(primary)

	shelf = ColorRect.new()
	shelf.name = "Shelf"
	shelf.color = Color(0.045, 0.035, 0.027, 0.93)
	shelf.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(shelf)
	var shelf_column := VBoxContainer.new()
	shelf_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	shelf_column.offset_left = 24; shelf_column.offset_right = -24; shelf_column.offset_top = 8; shelf_column.offset_bottom = -8
	shelf_column.add_theme_constant_override("separation", 6)
	shelf.add_child(shelf_column)
	shelf_heading = _label(shelf_column, "ShelfHeading", &"Caption")
	shelf_heading.add_theme_color_override("font_color", GOLD)
	var scroll := ScrollContainer.new()
	scroll.name = "OffersScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_column.add_child(scroll)
	offers_scroll = scroll
	stacks_scroll = ScrollContainer.new()
	stacks_scroll.name = "StacksScroll"
	stacks_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stacks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_column.add_child(stacks_scroll)
	stacks_box = HBoxContainer.new()
	stacks_box.name = "Stacks"
	stacks_box.add_theme_constant_override("separation", 6)
	stacks_scroll.add_child(stacks_box)
	offers_box = HBoxContainer.new()
	offers_box.name = "Offers"
	offers_box.add_theme_constant_override("separation", 8)
	scroll.add_child(offers_box)
	arrange.call_deferred()

func _label(parent: Node, id: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = id
	if variation != &"": label.theme_type_variation = variation
	parent.add_child(label)
	return label

func compact() -> bool:
	return size.y < 500.0

func narrow() -> bool:
	return size.x < 1000.0

func panel_width() -> float:
	return 340.0 if narrow() else 460.0

func shelf_height() -> float:
	if not shelf.visible: return 0.0
	return 92.0 if compact() else 150.0

## Cover the screen with the corridor art; keep the hero's spot left of the panel.
func image_rect() -> Rect2:
	var source := backdrop.get_size()
	var factor := maxf(size.x / source.x, size.y / source.y)
	var extent := (source * factor).round()
	var x := clampf(roundf((size.x - panel_width()) * 0.5 - 0.42 * extent.x), size.x - extent.x, 0.0)
	var y := clampf(roundf(size.y * 0.80 - floor_ratio * extent.y), size.y - extent.y, 0.0)
	return Rect2(Vector2(x, y), extent)

func actor_rect() -> Rect2:
	if run == null: return Rect2()
	var texture := Actor.portrait(str(run.model.s.get("outfit", "work")))
	var image := image_rect()
	var height := clampf(size.y * 0.36, 120.0, 300.0)
	var figure := (texture.get_size() * (height / texture.get_height())).round()
	var foot := Vector2(roundf((size.x - panel_width() - 24.0) * 0.38), roundf(image.position.y + floor_ratio * image.size.y))
	return Rect2(foot - Vector2(figure.x * 0.5, figure.y), figure)

func arrange() -> void:
	if panel == null: return
	shelf.offset_top = -shelf_height()
	panel.offset_right = -24.0
	panel.offset_left = -24.0 - panel_width()
	panel.offset_top = 76.0 if compact() else 92.0
	panel.offset_bottom = panel.offset_top
	panel.get_node("Column").add_theme_constant_override("separation", 4 if compact() else 8)
	for item in offers_box.get_children():
		item.custom_minimum_size = Vector2(150, 56) if compact() else Vector2(168, 96)
		item.get_node("Content/Icon").visible = not compact()
	stage.queue_redraw()

# --- content -------------------------------------------------------------------------

func encounter_stage() -> String:
	return str(run.s.get("encounter", {}).get("stage", ""))

func refresh() -> void:
	var scene: Dictionary = run.encounter_scene()
	var current := encounter_stage()
	credits_label.text = "보유 %d Cr" % int(run.s.credits)
	title_label.text = str(scene.title)
	pass_button.visible = current.is_empty() or (current == "loot" and not swapping)
	pass_button.text = "탄환을 남기고 계속" if current == "loot" else "관여하지 않고 지나간다"
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	choices_box.visible = current.is_empty()
	result_tag.visible = not current.is_empty()
	result_detail.visible = not current.is_empty()
	secondary.visible = false
	primary.visible = not current.is_empty()
	shelf.visible = current == "loot"
	if current.is_empty():
		prose_label.text = str(scene.text)
		for option in scene.choices:
			choices_box.add_child(choice_button(option))
	else:
		prose_label.text = str(run.s.message)
		match current:
			"ambush":
				result_tag.text = "매복 · 전투"
				result_tag.add_theme_color_override("font_color", RED)
				var bonus := int(Encounters.outcome(kind, str(run.s.encounter.choice), int(run.s.seed), int(run.s.node)).get("bonus", 0))
				result_detail.text = "이 자리에서 바로 싸웁니다. 이기면 일반 보상과 현장 물자 +%d Cr." % bonus
				primary.text = "전투 준비"
				primary.disabled = false
			"loot":
				result_tag.text = "발견 · 탄환 1장"
				result_tag.add_theme_color_override("font_color", GOLD)
				rebuild_offers()
				rebuild_stacks()
				offers_scroll.visible = not swapping
				stacks_scroll.visible = swapping
				result_detail.text = loot_detail()
				secondary.visible = true
				if swapping:
					shelf_heading.text = "내보낼 탄 선택 · 받을 탄 %s" % Ammo.AMMO[picked].name
					secondary.text = "취소"
					secondary.disabled = false
					secondary.theme_type_variation = &""
					primary.text = "교체 확정"
					primary.disabled = outgoing.is_empty()
				else:
					shelf_heading.text = "발견한 탄환 · 1장 선택"
					var full: bool = not picked.is_empty() and not run.can_acquire_ammo(picked, "")
					secondary.text = "교체해서 확보"
					secondary.disabled = picked.is_empty()
					secondary.theme_type_variation = &"PrimaryButton" if full else &""
					primary.text = "추가 불가" if full else "추가로 확보"
					primary.disabled = picked.is_empty() or full
			"combat":
				result_tag.text = "전투 시작"
				result_detail.text = ""
				primary.text = "전장으로"
			_:
				var choice := str(run.s.encounter.get("choice", ""))
				result_tag.add_theme_color_override("font_color", GOLD if choice != "skip" else MUTED)
				result_tag.text = result_summary(choice)
				result_detail.text = ""
				primary.text = "지도로 계속"
				primary.disabled = false
	arrange()

## One choice: label and cost on the first line, the clue below. Unaffordable choices
## stay visible with the shortfall.
func choice_button(option: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Choice_" + str(option.id)
	button.custom_minimum_size = Vector2(0, 52 if compact() else 64)
	button.pressed.connect(choose.bind(str(option.id)))
	var cost := int(option.cost)
	button.disabled = int(run.s.credits) < cost
	var lines := VBoxContainer.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = 12; lines.offset_right = -12; lines.offset_top = 6; lines.offset_bottom = -6
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(lines)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(top)
	var label := Label.new()
	label.text = str(option.label)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(label)
	var price := Label.new()
	price.theme_type_variation = &"Caption"
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.text = ("%d Cr" % cost) if cost > 0 else "비용 없음"
	if button.disabled: price.text = "%d Cr 부족" % (cost - int(run.s.credits))
	price.add_theme_color_override("font_color", GOLD if cost > 0 else MUTED)
	top.add_child(price)
	var hint := Label.new()
	hint.theme_type_variation = &"Caption"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = str(option.hint)
	hint.visible = not compact()
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.add_theme_color_override("font_color", MUTED)
	lines.add_child(hint)
	button.tooltip_text = str(option.hint)
	return button

func result_summary(choice: String) -> String:
	if choice == "skip": return "지나침 · 변화 없음"
	var outcome := Encounters.outcome(kind, choice, int(run.s.seed), int(run.s.node))
	match str(outcome.get("type", "")):
		"credits": return "획득 · +%d Cr" % int(outcome.amount)
		"lore": return "기록 회수 · 기록실에 보관"
		"ammo": return "탄환 확보"
	return "결과"

func rebuild_offers() -> void:
	for child in offers_box.get_children():
		offers_box.remove_child(child)
		child.queue_free()
	offer_buttons.clear()
	for id in run.reward_options():
		var item: Button = Item.instantiate()
		item.name = "Offer_" + str(id)
		item.button_group = offer_group
		item.get_node("Content/Icon").item_id = id
		item.get_node("Content/Name").text = Ammo.AMMO[id].name
		var owned: int = run.model.s.deck.count(id)
		item.get_node("Content/Count").text = "%s · %s" % [Comparison.power(str(id), run.model.s), ("보유 %d" % owned) if owned > 0 else "새 탄"]
		item.get_node("Content/Count").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item.set_pressed_no_signal(str(id) == picked)
		item.pressed.connect(pick.bind(str(id)))
		offers_box.add_child(item)
		offer_buttons[str(id)] = item

func rebuild_stacks() -> void:
	for child in stacks_box.get_children():
		stacks_box.remove_child(child)
		child.queue_free()
	stack_buttons.clear()
	if not swapping: return
	var counts: Dictionary = {}
	for id in run.model.s.deck: counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		var item: Button = Item.instantiate()
		item.name = "Stack_" + str(id)
		item.button_group = stack_group
		item.get_node("Content/Icon").item_id = id
		item.get_node("Content/Name").text = Ammo.AMMO[id].name
		item.get_node("Content/Count").text = "%s · %d발" % [Comparison.power(str(id), run.model.s), int(counts[id])]
		item.get_node("Content/Count").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item.custom_minimum_size = Vector2(108, 50) if compact() else Vector2(136, 80)
		item.get_node("Content/Icon").visible = not compact()
		item.set_pressed_no_signal(str(id) == outgoing)
		item.disabled = not run.can_acquire_ammo(picked, str(id))
		item.pressed.connect(pick_stack.bind(str(id)))
		stacks_box.add_child(item)
		stack_buttons[str(id)] = item

func pick_stack(id: String) -> void:
	outgoing = id
	refresh()

func loot_detail() -> String:
	var count: int = run.model.s.deck.size()
	var limit: int = run.model.deck_limit()
	if swapping:
		if outgoing.is_empty(): return "아래에서 내보낼 탄을 고르세요. 휴대 %d / %d발 유지" % [count, limit]
		return "%s %d → %d장 · %s 받음 · 휴대 %d / %d발 유지" % [Ammo.AMMO[outgoing].name, run.model.s.deck.count(outgoing), run.model.s.deck.count(outgoing) - 1, Ammo.AMMO[picked].name, count, limit]
	if picked.is_empty(): return "아래에서 가져갈 탄을 고르세요. 휴대 %d / %d발" % [count, limit]
	if not run.can_acquire_ammo(picked, ""): return "가방이 가득 찼습니다. 휴대 %d / %d발" % [count, limit]
	return "%s %s · 휴대 %d → %d / %d발" % [Ammo.AMMO[picked].name, Comparison.power(picked, run.model.s), count, count + 1, limit]

func choose(id: String) -> void:
	if command("encounter", id): refresh()

func pick(id: String) -> void:
	picked = id
	refresh()

func pass_by() -> void:
	swapping = false
	if command("skip"): refresh()

func on_secondary() -> void:
	if encounter_stage() != "loot": return
	swapping = not swapping and not picked.is_empty()
	outgoing = ""
	refresh()

func on_primary() -> void:
	match encounter_stage():
		"ambush":
			# Live: the main handler starts the combat and redraws into the battle HUD.
			if command("fight", "", "", true) and live_host == null: refresh()
		"loot":
			if picked.is_empty(): return
			var replace := outgoing if swapping else ""
			if command("ammo", picked, replace):
				swapping = false
				outgoing = ""
				refresh()
		"combat":
			if live_host == null: load_event(kind, "")
		_:
			if live_host != null: live_host._campaign_action("leave")
			else: load_event(kind, "")

# --- verification --------------------------------------------------------------------

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func settle() -> void:
	for step in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw

func touch(button: Button) -> void:
	verify(button != null and button.is_visible_in_tree() and not button.disabled, "available " + (str(button.name) if button != null else "?"))
	if button == null: return
	await settle()
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await settle()

func capture(output: String, name: String, extent: Vector2i) -> void:
	await settle()
	var frame := get_viewport().get_texture().get_image()
	verify(frame.get_size() == extent and frame.save_png(output.path_join(name + ".png")) == OK, "capture " + name)
	var bounds := get_viewport_rect().grow(1)
	verify(bounds.encloses(panel.get_global_rect()), "story panel on screen " + name)
	var visible_actor := actor_rect().intersection(Rect2(0, 0, size.x, size.y - shelf_height()))
	verify(not panel.get_global_rect().intersects(visible_actor), "panel leaves the hero clear " + name)
	if shelf.visible:
		verify(not panel.get_global_rect().intersects(shelf.get_global_rect()), "panel clears the shelf " + name)
	for button in [primary, secondary]:
		if button.is_visible_in_tree(): verify(bounds.encloses(button.get_global_rect()), "action on screen %s %s" % [button.name, name])
	for button in choices_box.get_children():
		if button.is_visible_in_tree(): verify(bounds.encloses(button.get_global_rect()), "choice on screen %s %s" % [button.name, name])

func capture_review(output: String) -> void:
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454), Vector2i(844, 390)]:
		get_window().size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		# Choose: door scene, then the safe choice reveals credits.
		load_event("siphon", "combat")
		await settle()
		verify(encounter_stage().is_empty() and choices_box.get_child_count() == 2, "two clue choices")
		await capture(output, "choose_" + suffix, extent)
		var money: int = run.s.credits
		await touch(choices_box.get_node("Choice_knock"))
		verify(run.s.resolved and run.s.credits == money + 6 and primary.text == "지도로 계속", "safe choice pays and resolves")
		await capture(output, "result_" + suffix, extent)
		# Ambush: the risky choice of the same seed.
		load_event("siphon", "combat")
		await settle()
		await touch(choices_box.get_node("Choice_open"))
		verify(encounter_stage() == "ambush" and primary.text == "전투 준비", "risky choice reveals an ambush")
		await capture(output, "ambush_" + suffix, extent)
		await touch(primary)
		verify(run.s.phase == "combat", "ambush starts a real combat")
		# Loot: paid quiet choice on the cart.
		load_event("salvage", "")
		await settle()
		money = run.s.credits
		await touch(choices_box.get_node("Choice_power"))
		verify(encounter_stage() == "loot" and run.s.credits == money - 6 and shelf.visible and primary.disabled, "paid choice reveals found rounds")
		var first: String = str(offer_buttons.keys()[0])
		var count: int = run.model.s.deck.size()
		await touch(offer_buttons[first])
		await capture(output, "loot_" + suffix, extent)
		await touch(primary)
		verify(run.s.resolved and run.model.s.deck.size() == count + 1, "found round taken once")
	get_window().size = Vector2i(1280, 800)
	load_event("archive", "")
	await settle()
	run.s.credits = 4
	refresh()
	await settle()
	verify(choices_box.get_node("Choice_unlock").disabled, "unaffordable choice stays visible but locked")
	await capture(output, "locked_1280x800", Vector2i(1280, 800))
	await touch(choices_box.get_node("Choice_record"))
	verify(run.s.resolved and result_tag.text.begins_with("기록"), "record choice returns lore")
	load_event("siphon", "")
	await settle()
	await touch(pass_button)
	verify(run.s.resolved and result_tag.text.begins_with("지나침"), "passing by resolves without change")
	print("EVENT REVIEW COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

# --- drawing -------------------------------------------------------------------------

func draw_stage(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("0b0907"))
	if backdrop == null: return
	canvas.draw_texture_rect(backdrop, image_rect(), false)
	# The unknown: a cold dim over the corridor, lighter around the hero.
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.02, 0.03, 0.04, 0.42))
	if run == null: return
	var texture := Actor.portrait(str(run.model.s.get("outfit", "work")))
	var figure := actor_rect()
	canvas.draw_set_transform(Vector2(figure.get_center().x, figure.end.y), 0.0, Vector2(1.0, 0.16))
	canvas.draw_circle(Vector2.ZERO, figure.size.x * 0.55, Color(0.02, 0.015, 0.01, 0.6))
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_texture_rect(texture, figure, false)

class StageView extends Control:
	var host
	func _draw() -> void: host.draw_stage(self)
