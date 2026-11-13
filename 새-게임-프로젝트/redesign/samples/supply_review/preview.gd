extends Control
## 탄약고 시안 (2026-11-07). Review scene only: not linked to the main game yet.
##
## Reference principles (docs/art/references/2026-11-07-supply/):
## - Darkest Dungeon provisioning: offered stock and the player's pack, empty slots
##   included, on one screen.
## - Dredge: carrying capacity is visible at the moment of taking.
## - Resident Evil 4 case: the container is an object in the scene.
## - Signalis storeroom: dark room, few panels.
## Layouts (F3 toggles, LOB_SUPPLY_LAYOUT=column|shelf):
## - "shelf" (3rd draft, default): same structure as the approved workshop/gate.
##   Bottom shelf lists the offered rounds; choosing a swap switches the shelf to the
##   player's stacks to pick the outgoing round. Capacity cells stay above the shelf.
##   The right inspector only details and commits.
## - "column" (2nd draft): right column = round inspector with the three offered rounds right below
## it (user feedback 2026-11-07: rounds floating over the chest hid the character);
## the depot scene with the actor stays clear on the left. The bottom shelf is the
## player's carried ammunition (stacks + capacity cells).
## Rules are the live Campaign rules (`resolve("ammo", id, replace)`), on a staged run.
## F1 normal stock, F2 full bag. LOB_SUPPLY_CAPTURE=<dir> runs the capture check.
const Campaign = preload("res://redesign/campaign.gd")
const Ammo = preload("res://redesign/content.gd")
const Comparison = preload("res://redesign/ammo_comparison.gd")
const Readability = preload("res://redesign/readability.gd")
const UIReadability = preload("res://redesign/ui_readability.gd")
const Actors = preload("res://redesign/service_actor_catalog.gd")
const Item = preload("res://redesign/workbench/item.tscn")
const BACKDROP = preload("res://assets/art/service_background_grouped_20261025/supply.png")
const CHEST := Vector2(0.48, 0.47)
const ACTOR_FOOT := Vector2(0.37, 0.86)
const ACTOR_HEIGHT := 0.52
const GOLD := Color("e9c27f")
const IVORY := Color("ebe2d1")
const MUTED := Color("9b9586")
const RED := Color("d0806a")

enum Mode { PICK, REPLACE, DONE }

var run
var mode := Mode.PICK
var incoming := ""
var outgoing := ""
var receipt := ""
var offer_buttons: Dictionary = {}
var stack_buttons: Dictionary = {}
var offer_group := ButtonGroup.new()
var stack_group := ButtonGroup.new()
var checks := 0
var failures := 0

var stage: Control
var actor: Control
var offers_box: HBoxContainer
var right_column: VBoxContainer
var layout := "shelf"
var shelf_heading: Label
var offers_scroll: ScrollContainer
var stacks_scroll: ScrollContainer
var chest_label: Label
var inspector: PanelContainer
var title_label: Label
var tag_label: Label
var description_label: Label
var stats_label: Label
var before_label: Label
var before_value: Label
var after_label: Label
var after_value: Label
var explanation: Label
var secondary: Button
var primary: Button
var shelf: ColorRect
var pack_title: Label
var cells: Control
var stacks_box: HBoxContainer
var region_label: Label
var leave_button: Button
var menu_button: Button
## Main-game link (2026-11-08). configure() hands over the live campaign; take,
## swap and skip go through screen.gd::_campaign_action (autosave), "지도로 계속"
## leaves through it with a redraw. Without it the scene is the review fixture.
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
		apply_layout()
		enter_live()
		return
	get_window().size_changed.connect(fit_window)
	fit_window()
	Input.emulate_mouse_from_touch = true
	if OS.get_environment("LOB_SUPPLY_LAYOUT") == "column": layout = "column"
	apply_layout()
	load_supply(false)
	var output := OS.get_environment("LOB_SUPPLY_CAPTURE")
	if not output.is_empty():
		capture_review.call_deferred(output)

## The live depot: real offers, the run's outfit, the workbench utility menu. A
## resumed save that already took (or skipped) its round opens on the result.
func enter_live() -> void:
	region_label.text = "%s · %s" % [run.region_info().name, str(run.node().name)]
	var offers: Array = run.reward_options()
	incoming = str(offers[0]) if not offers.is_empty() else ""
	outgoing = ""
	mode = Mode.DONE if run.s.resolved else Mode.PICK
	receipt = str(run.s.message) if run.s.resolved else ""
	menu_button.tooltip_text = ""
	add_live_menu()
	rebuild_offers()
	rebuild_stacks()
	refresh()

func add_live_menu() -> void:
	var panel := PanelContainer.new()
	panel.name = "UtilityMenu"
	panel.visible = false
	panel.theme_type_variation = &"Inspector"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -240.0
	panel.offset_top = 64.0
	panel.offset_right = -24.0
	add_child(panel)
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	panel.add_child(actions)
	for entry in [["Build", "빌드", live_presenter.deck], ["Archive", "기록실", live_presenter.archive], ["Settings", "설정", live_host._settings], ["ReturnTitle", "타이틀로 나가기", live_host._to_menu], ["CloseMenu", "닫기", Callable()]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.custom_minimum_size = Vector2(0, 44)
		actions.add_child(button)
		button.pressed.connect(use_utility.bind(panel, entry[2]))
	menu_button.pressed.connect(func(): panel.visible = not panel.visible)

func use_utility(panel: Control, target: Callable) -> void:
	panel.hide()
	if target.is_valid():
		target.call()

## Review fixture calls the rules directly; the live depot uses the main handler
## without a redraw so this scene stays until "지도로 계속".
func command(name: String, value: Variant = "", extra: String = "", replacement: String = "") -> bool:
	if live_host != null:
		return live_host._campaign_action(name, value, extra, replacement, false)
	if name == "resolve":
		return run.resolve(str(value), extra, replacement)
	return false

func fit_window() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = UIReadability.scale_for(window.size)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo: return
	if live_host != null:
		if event.keycode == KEY_ESCAPE: cancel()
		return
	match event.keycode:
		KEY_F1: load_supply(false)
		KEY_F2: load_supply(true)
		KEY_F3:
			layout = "column" if layout == "shelf" else "shelf"
			apply_layout()
			refresh()
		KEY_ESCAPE: cancel()

# --- staging -----------------------------------------------------------------------

## A real run standing in a depot of the first region. The deck gets the first offer
## (so one candidate is a refill of an owned round); F2 fills the bag to its limit.
func load_supply(full: bool) -> void:
	run = Campaign.new()
	run.start("single", 251107, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	run.s.departure_step = 3
	var nodes: Array = run.current_nodes()
	var depot: Dictionary = nodes.filter(func(node): return node.kind == "supply" and not node.get("workshop", false))[0]
	var prior: Array = nodes.filter(func(node): return node.next.has(depot.id))
	run.s.node = prior[0].id if not prior.is_empty() else 0
	run.s.floor = prior[0].floor if not prior.is_empty() else 0
	run.model.s.deck = run.Model.FocusBuild.replace_opening(run.model.s.deck, "precise")
	if not run.enter(int(depot.id)):
		push_error("Cannot stage the depot.")
		return
	var offers: Array = run.reward_options()
	if not offers.is_empty() and not run.model.s.deck.has(offers[0]):
		run.model.s.deck.append(offers[0])
	if full:
		while run.model.s.deck.size() < run.model.deck_limit(): run.model.s.deck.append("basic_p2")
	region_label.text = "%s · %s" % [run.region_info().name, str(run.node().name)]
	mode = Mode.PICK
	receipt = ""
	outgoing = ""
	incoming = str(offers[0]) if not offers.is_empty() else ""
	rebuild_offers()
	rebuild_stacks()
	refresh()

# --- layout --------------------------------------------------------------------------

func build() -> void:
	theme = preload("res://redesign/workbench/theme.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage = StageView.new()
	stage.name = "Stage"
	stage.host = self
	add_child(stage)
	actor = ActorView.new()
	actor.name = "Actor"
	actor.host = self
	add_child(actor)
	for node in [stage, actor]:
		node.set_anchors_preset(Control.PRESET_FULL_RECT)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := ColorRect.new()
	shade.name = "HeaderShade"
	shade.color = Color(0.036, 0.029, 0.022, 0.91)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 68
	add_child(shade)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24; header.offset_right = -24; header.offset_top = 12; header.offset_bottom = 56
	header.add_theme_constant_override("separation", 12)
	add_child(header)
	var title := Label.new()
	title.text = "탄약고"
	title.theme_type_variation = &"SectionTitle"
	header.add_child(title)
	region_label = Label.new()
	region_label.name = "Region"
	region_label.theme_type_variation = &"Caption"
	region_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(region_label)
	leave_button = Button.new()
	leave_button.name = "Leave"
	leave_button.text = "보급 없이 나가기"
	leave_button.custom_minimum_size = Vector2(0, 44)
	leave_button.pressed.connect(skip)
	header.add_child(leave_button)
	menu_button = Button.new()
	menu_button.name = "Menu"
	menu_button.text = "메뉴"
	menu_button.custom_minimum_size = Vector2(72, 44)
	menu_button.tooltip_text = "시안에서는 동작하지 않습니다 · 본편에서는 정비소와 같은 메뉴"
	header.add_child(menu_button)

	right_column = VBoxContainer.new()
	right_column.name = "RightColumn"
	right_column.add_theme_constant_override("separation", 6)
	right_column.anchor_left = 1.0
	right_column.anchor_right = 1.0
	right_column.anchor_bottom = 1.0
	add_child(right_column)
	chest_label = Label.new()
	chest_label.name = "ChestLabel"
	chest_label.theme_type_variation = &"Caption"
	chest_label.add_theme_color_override("font_color", GOLD)
	chest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	offers_box = HBoxContainer.new()
	offers_box.name = "Offers"
	offers_box.add_theme_constant_override("separation", 8)

	inspector = PanelContainer.new()
	inspector.name = "Inspector"
	inspector.theme_type_variation = &"Inspector"
	right_column.add_child(inspector)
	right_column.add_child(chest_label)
	right_column.add_child(offers_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	inspector.add_child(column)
	title_label = _label(column, "SelectionTitle", &"SectionTitle")
	tag_label = _label(column, "Tag", &"Caption")
	tag_label.add_theme_color_override("font_color", GOLD)
	description_label = _label(column, "Description", &"")
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label = _label(column, "Stats", &"Caption")
	column.add_child(HSeparator.new())
	var compare := HBoxContainer.new()
	compare.add_theme_constant_override("separation", 10)
	column.add_child(compare)
	var before := VBoxContainer.new()
	before.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare.add_child(before)
	before_label = _label(before, "BeforeLabel", &"Caption")
	before_value = _label(before, "BeforeValue", &"")
	var arrow := Label.new()
	arrow.text = "→"
	arrow.theme_type_variation = &"Caption"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compare.add_child(arrow)
	var after := VBoxContainer.new()
	after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare.add_child(after)
	after_label = _label(after, "AfterLabel", &"Caption")
	after_value = _label(after, "AfterValue", &"")
	after_value.add_theme_color_override("font_color", GOLD)
	explanation = _label(column, "Explanation", &"Caption")
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	secondary = Button.new()
	secondary.name = "Secondary"
	secondary.custom_minimum_size = Vector2(0, 44)
	secondary.pressed.connect(on_secondary)
	footer.add_child(secondary)
	primary = Button.new()
	primary.name = "Primary"
	primary.theme_type_variation = &"PrimaryButton"
	primary.custom_minimum_size = Vector2(0, 44)
	primary.pressed.connect(on_primary)
	footer.add_child(primary)

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
	var pack_row := HBoxContainer.new()
	pack_row.add_theme_constant_override("separation", 14)
	shelf_column.add_child(pack_row)
	pack_title = _label(pack_row, "PackTitle", &"Caption")
	cells = CapacityCells.new()
	cells.name = "Capacity"
	cells.host = self
	cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.custom_minimum_size = Vector2(0, 16)
	cells.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pack_row.add_child(cells)
	shelf_heading = _label(shelf_column, "ShelfHeading", &"Caption")
	shelf_heading.add_theme_color_override("font_color", GOLD)
	offers_scroll = ScrollContainer.new()
	offers_scroll.name = "OffersScroll"
	offers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	offers_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_column.add_child(offers_scroll)
	stacks_scroll = ScrollContainer.new()
	stacks_scroll.name = "StacksScroll"
	stacks_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stacks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_column.add_child(stacks_scroll)
	stacks_box = HBoxContainer.new()
	stacks_box.name = "Stacks"
	stacks_box.add_theme_constant_override("separation", 6)
	stacks_scroll.add_child(stacks_box)
	arrange.call_deferred()

## Move the inspector and the offer row between the two drafts.
func apply_layout() -> void:
	var shelf_mode := layout == "shelf"
	right_column.visible = not shelf_mode
	if shelf_mode:
		if inspector.get_parent() != self: inspector.reparent(self, false)
		if offers_box.get_parent() != offers_scroll: offers_box.reparent(offers_scroll, false)
		inspector.anchor_left = 1.0
		inspector.anchor_right = 1.0
		inspector.anchor_top = 0.0
		inspector.anchor_bottom = 0.0
	else:
		if inspector.get_parent() != right_column: inspector.reparent(right_column, false)
		if offers_box.get_parent() != right_column: offers_box.reparent(right_column, false)
		right_column.move_child(inspector, 0)
		right_column.move_child(chest_label, 1)
		right_column.move_child(offers_box, 2)
	arrange()

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

func inspector_width() -> float:
	if layout == "shelf": return 300.0 if narrow() else 364.0
	return 320.0 if narrow() else 420.0

## Cover the screen with the depot art, keeping the open chest in the free space
## left of the inspector.
func image_rect() -> Rect2:
	var source := BACKDROP.get_size()
	var factor := maxf(size.x / source.x, size.y / source.y)
	var extent := (source * factor).round()
	var target_x := (size.x - inspector_width() - 24.0) * 0.5
	var x := clampf(roundf(target_x - CHEST.x * extent.x), size.x - extent.x, 0.0)
	var y := roundf((size.y - extent.y) * 0.5)
	return Rect2(Vector2(x, y), extent)

func arrange() -> void:
	if inspector == null: return
	var shelf_height := 90.0 if compact() else 140.0
	if layout == "shelf": shelf_height = 96.0 if compact() else 168.0
	shelf.offset_top = -shelf_height
	if layout == "shelf":
		inspector.offset_right = -24.0
		inspector.offset_left = -24.0 - inspector_width()
		inspector.offset_top = 72.0 if compact() else 92.0
		inspector.offset_bottom = inspector.offset_top
	right_column.offset_right = -24.0
	right_column.offset_left = -24.0 - inspector_width()
	right_column.offset_top = 72.0 if compact() else 92.0
	right_column.offset_bottom = -shelf_height - 6.0
	chest_label.visible = not compact() and layout == "column"
	shelf_heading.visible = layout == "shelf" and not compact()
	var cell_width := floorf((inspector_width() - 16.0) / 3.0)
	if layout == "shelf": cell_width = 150.0 if compact() else 168.0
	for item in offers_box.get_children():
		item.custom_minimum_size = Vector2(cell_width, 52) if compact() else Vector2(cell_width, 92)
		if layout == "shelf" and not compact(): item.custom_minimum_size.y = 96
		item.get_node("Content/Icon").visible = not compact()
	for item in stacks_box.get_children():
		item.custom_minimum_size = Vector2(108, 50) if compact() else Vector2(136, 80)
		item.get_node("Content/Icon").visible = not compact()
	right_column.add_theme_constant_override("separation", 4 if compact() else 6)
	inspector.get_child(0).add_theme_constant_override("separation", 3 if compact() else 6)
	stage.queue_redraw()
	actor.queue_redraw()
	cells.queue_redraw()
	if run != null and description_label.visible == compact(): refresh()

# --- content -------------------------------------------------------------------------

func deck() -> Array:
	return run.model.s.deck

func limit() -> int:
	return run.model.deck_limit()

func bag_full() -> bool:
	return deck().size() >= limit()

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
		var owned: int = deck().count(id)
		# Same family can come in different power profiles: show the power first.
		item.get_node("Content/Count").text = "%s · %s" % [Comparison.power(str(id), run.model.s), ("보유 %d" % owned) if owned > 0 else "새 탄"]
		item.get_node("Content/Count").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item.tooltip_text = Readability.description(str(id), run.model.s)
		item.pressed.connect(pick_offer.bind(str(id)))
		offers_box.add_child(item)
		offer_buttons[str(id)] = item
	arrange.call_deferred()

func rebuild_stacks() -> void:
	for child in stacks_box.get_children():
		stacks_box.remove_child(child)
		child.queue_free()
	stack_buttons.clear()
	var counts: Dictionary = {}
	for id in deck(): counts[id] = int(counts.get(id, 0)) + 1
	var order: Array = counts.keys()
	order.sort_custom(func(a, b): return Ammo.source_id(str(a)) != "basic" and Ammo.source_id(str(b)) == "basic" or (Ammo.source_id(str(a)) == Ammo.source_id(str(b)) and str(a) < str(b)))
	for id in order:
		var item: Button = Item.instantiate()
		item.name = "Stack_" + str(id)
		item.button_group = stack_group
		item.get_node("Content/Icon").item_id = id
		item.get_node("Content/Name").text = Ammo.AMMO[id].name
		item.get_node("Content/Count").text = "%s · %d발" % [Comparison.power(str(id), run.model.s), int(counts[id])]
		item.get_node("Content/Count").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item.tooltip_text = item.get_node("Content/Count").text
		item.pressed.connect(pick_stack.bind(str(id)))
		stacks_box.add_child(item)
		stack_buttons[str(id)] = item
	arrange.call_deferred()

func pick_offer(id: String) -> void:
	if mode == Mode.DONE: return
	incoming = id
	if mode == Mode.REPLACE and not run.can_acquire_ammo(incoming, outgoing): outgoing = ""
	refresh()

func pick_stack(id: String) -> void:
	if mode != Mode.REPLACE: return
	outgoing = id
	refresh()

func on_primary() -> void:
	match mode:
		Mode.PICK:
			if not bag_full(): commit("")
		Mode.REPLACE:
			if not outgoing.is_empty(): commit(outgoing)
		Mode.DONE:
			if live_host != null: live_host._campaign_action("leave")
			else: load_supply(false)

func on_secondary() -> void:
	match mode:
		Mode.PICK:
			mode = Mode.REPLACE
			outgoing = ""
			refresh()
		Mode.REPLACE:
			cancel()

func cancel() -> void:
	if mode == Mode.REPLACE:
		mode = Mode.PICK
		outgoing = ""
		refresh()

func commit(replace: String) -> void:
	var before: int = deck().count(incoming)
	if not command("resolve", "ammo", incoming, replace):
		return
	receipt = "%s 1장 확보 · %s" % [Ammo.AMMO[incoming].name, ("%s 1장 내보냄" % Ammo.AMMO[replace].name) if not replace.is_empty() else "탄약 %d → %d발" % [deck().size() - 1, deck().size()]]
	mode = Mode.DONE
	outgoing = ""
	verify(deck().count(incoming) == before + 1, "incoming round counted once")
	rebuild_offers()
	rebuild_stacks()
	refresh()

func skip() -> void:
	if mode == Mode.DONE: return
	if command("resolve", "skip"):
		receipt = "보급 없이 출발"
		mode = Mode.DONE
		refresh()

func refresh() -> void:
	var state: Dictionary = run.model.s
	var count := deck().size()
	pack_title.text = "보유 탄약 %d / %d발" % [count, limit()]
	chest_label.text = "보급함 · %d종 중 1장" % offer_buttons.size()
	if layout == "shelf":
		offers_scroll.visible = mode != Mode.REPLACE
		stacks_scroll.visible = mode == Mode.REPLACE
		if mode == Mode.REPLACE: shelf_heading.text = "내보낼 탄 선택 · 받을 탄 %s" % (Ammo.AMMO[incoming].name if not incoming.is_empty() else "")
		elif mode == Mode.DONE: shelf_heading.text = "보급 완료"
		else: shelf_heading.text = "보급함 · %d종 중 1장" % offer_buttons.size()
	else:
		offers_scroll.visible = false
		stacks_scroll.visible = true
	leave_button.visible = mode != Mode.DONE
	for id in offer_buttons:
		var button: Button = offer_buttons[id]
		button.set_pressed_no_signal(id == incoming)
		button.disabled = mode == Mode.DONE
		button.modulate = Color.WHITE if mode != Mode.DONE or id == incoming else Color(1, 1, 1, 0.45)
	for id in stack_buttons:
		var button: Button = stack_buttons[id]
		button.toggle_mode = mode == Mode.REPLACE
		button.set_pressed_no_signal(mode == Mode.REPLACE and id == outgoing)
		button.disabled = mode == Mode.REPLACE and not run.can_acquire_ammo(incoming, id)
		button.modulate = RED.lightened(0.35) if mode == Mode.REPLACE and id == outgoing else (Color(1, 1, 1, 0.55) if button.disabled else Color.WHITE)
	if incoming.is_empty():
		title_label.text = "보급 없음"
		return
	var owned: int = deck().count(incoming)
	title_label.text = str(Ammo.AMMO[incoming].name)
	tag_label.text = ("보충 · 같은 탄 %d장 보유" % owned) if owned > 0 and mode != Mode.DONE else ("새 탄환 · 처음 확보" if mode != Mode.DONE else "확보 완료")
	# First paragraph only, without the grade line; the shared heat rules live in help.
	description_label.text = Readability.description(incoming, state)
	description_label.visible = not compact()
	tag_label.visible = not compact() or mode == Mode.DONE
	explanation.visible = not compact()
	before_label.visible = not compact()
	after_label.visible = not compact()
	stats_label.text = "%s · 열 %s%s" % [Comparison.power(incoming, state), Ammo.heat_label(incoming, state), " · 탄창 %d칸" % Ammo.slot_cost(incoming) if Ammo.slot_cost(incoming) > 1 else ""]
	secondary.visible = mode != Mode.DONE
	match mode:
		Mode.PICK:
			before_label.text = "현재"
			after_label.text = "추가 확보 후"
			before_value.text = "%s %d장\n탄약 %d / %d발" % [Ammo.AMMO[incoming].name, owned, count, limit()]
			if bag_full():
				after_value.text = "탄약 상한\n교체만 가능"
				explanation.text = "탄약이 가득 찼습니다. 교체로만 받을 수 있습니다."
				primary.text = "추가 불가"
				primary.disabled = true
				primary.theme_type_variation = &""
				secondary.text = "교체해서 확보"
				secondary.theme_type_variation = &"PrimaryButton"
			else:
				after_value.text = "%s %d장\n탄약 %d / %d발" % [Ammo.AMMO[incoming].name, owned + 1, count + 1, limit()]
				explanation.text = ""
				primary.text = "추가로 확보"
				primary.disabled = false
				primary.theme_type_variation = &"PrimaryButton"
				secondary.text = "교체해서 확보"
				secondary.theme_type_variation = &""
		Mode.REPLACE:
			before_label.text = "내보낼 탄"
			after_label.text = "교체 후"
			primary.theme_type_variation = &"PrimaryButton"
			secondary.theme_type_variation = &""
			secondary.text = "취소"
			if outgoing.is_empty():
				before_value.text = "아래 선반에서\n한 장 선택"
				after_value.text = "%s %d → %d장\n탄약 %d / %d발" % [Ammo.AMMO[incoming].name, owned, owned + 1, count, limit()]
				explanation.text = "내보낸 탄은 이번 등반에서 사라집니다."
				primary.text = "교체 확정"
				primary.disabled = true
			else:
				var leaving: int = deck().count(outgoing)
				before_value.text = "%s %d → %d장" % [Ammo.AMMO[outgoing].name, leaving, leaving - 1]
				after_value.text = "%s %d → %d장\n탄약 %d / %d발 그대로" % [Ammo.AMMO[incoming].name, owned, owned + 1, count, limit()]
				explanation.text = "%s 1장을 내보내고 %s 1장을 받습니다." % [Ammo.AMMO[outgoing].name, Ammo.AMMO[incoming].name]
				primary.text = "교체 확정"
				primary.disabled = false
		Mode.DONE:
			before_label.text = "보급 결과"
			after_label.text = "보유 탄약"
			before_value.text = receipt.get_slice(" · ", 0)
			after_value.text = "%d / %d발" % [count, limit()]
			# The result is already in the two cells; only what they do not say stays below.
			explanation.text = receipt.get_slice(" · ", 1) if receipt.get_slice_count(" · ") > 1 and receipt.contains("내보냄") else ""
			primary.text = "지도로 계속"
			primary.disabled = false
			primary.theme_type_variation = &"PrimaryButton"
	explanation.visible = not compact() and not explanation.text.is_empty()
	cells.queue_redraw()

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
	var scroll: Node = button.get_parent()
	while scroll != null:
		if scroll is ScrollContainer: scroll.ensure_control_visible(button)
		scroll = scroll.get_parent()
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
	var actor_clear := actor_rect().intersection(Rect2(0, 0, size.x, shelf.get_global_rect().position.y))
	if layout == "column":
		verify(offers_box.get_global_rect().position.y >= inspector.get_global_rect().end.y, "offers sit below the inspector " + name)
	elif offers_box.is_visible_in_tree():
		verify(shelf.get_global_rect().grow(1).encloses(offers_box.get_global_rect()), "offers sit in the shelf %s (%s in %s)" % [name, offers_box.get_global_rect(), shelf.get_global_rect()])
	if offers_box.is_visible_in_tree(): verify(not offers_box.get_global_rect().intersects(actor_clear), "offers leave the character clear " + name)
	verify(not inspector.get_global_rect().intersects(actor_clear), "inspector leaves the character clear " + name)
	for node in [inspector, offers_box, shelf, primary]:
		if node.is_visible_in_tree(): verify(bounds.encloses(node.get_global_rect()), "on screen %s %s" % [node.name, name])
	verify(not offers_box.get_global_rect().intersects(inspector.get_global_rect()), "offers clear the inspector " + name)
	if layout == "column": verify(not offers_box.get_global_rect().intersects(shelf.get_global_rect()), "offers clear the shelf " + name)
	verify(not inspector.get_global_rect().intersects(shelf.get_global_rect()), "inspector clears the shelf " + name)

func capture_review(output: String) -> void:
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454), Vector2i(844, 390)]:
		get_window().size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		load_supply(false)
		await settle()
		verify(run.s.phase == "supply" and not run.s.resolved and offer_buttons.size() == run.reward_options().size(), "real depot offers")
		await capture(output, "pick_" + suffix, extent)
		var count: int = deck().size()
		var target: String = str(offer_buttons.keys()[1]) if offer_buttons.size() > 1 else incoming
		await touch(offer_buttons[target])
		verify(incoming == target and deck().size() == count, "picking only previews")
		await touch(secondary)
		verify(mode == Mode.REPLACE and primary.disabled, "swap waits for an outgoing round")
		await touch(stack_buttons["basic_p2"])
		await capture(output, "replace_" + suffix, extent)
		await touch(primary)
		verify(mode == Mode.DONE and deck().size() == count and deck().count(target) >= 1, "swap keeps total ammunition")
		await capture(output, "done_" + suffix, extent)
		load_supply(true)
		await settle()
		verify(bag_full() and primary.disabled and secondary.text == "교체해서 확보", "full bag offers swap only")
		await capture(output, "full_" + suffix, extent)
	get_window().size = Vector2i(1280, 800)
	load_supply(false)
	await settle()
	var before: int = deck().size()
	await touch(primary)
	verify(mode == Mode.DONE and deck().size() == before + 1, "add grows the bag by one")
	load_supply(false)
	await settle()
	await touch(leave_button)
	verify(mode == Mode.DONE and run.s.resolved and deck().size() == before, "leaving without supply keeps the bag")
	print("SUPPLY REVIEW COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

# --- drawing (called from the small canvas classes below) --------------------------

func draw_stage(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("0b0907"))
	canvas.draw_texture_rect(BACKDROP, image_rect(), false)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.03, 0.02, 0.015, 0.18))

## Screen rect of the depot actor (for layout checks and drawing).
func actor_rect() -> Rect2:
	var profile = Actors.resolve(str(run.model.s.get("outfit", "work")), "supply").profile
	if profile == null: return Rect2()
	var image := image_rect()
	var source: Rect2 = profile.source_rect
	var figure: Vector2 = source.size * (image.size.y * ACTOR_HEIGHT / source.size.y)
	var foot: Vector2 = image.position + image.size * ACTOR_FOOT
	return Rect2((foot - figure * profile.foot_in_source).round(), figure.round())

func draw_actor(canvas: Control) -> void:
	if run == null: return
	var profile = Actors.resolve(str(run.model.s.get("outfit", "work")), "supply").profile
	if profile == null or profile.texture == null: return
	var image := image_rect()
	var source: Rect2 = profile.source_rect
	var figure: Vector2 = source.size * (image.size.y * ACTOR_HEIGHT / source.size.y)
	var foot: Vector2 = image.position + image.size * ACTOR_FOOT
	canvas.draw_texture_rect_region(profile.texture, Rect2((foot - figure * profile.foot_in_source).round(), figure.round()), source)

## One cell per carried round: filled, the round about to arrive (gold), the round
## about to leave (red), and the empty rest of the bag.
func draw_cells(canvas: Control) -> void:
	if run == null: return
	var total := limit()
	var used := deck().size()
	var gap := 2.0
	var cell := clampf((canvas.size.x - gap * (total - 1)) / total, 4.0, 14.0)
	var h := minf(canvas.size.y, 12.0)
	var y := roundf((canvas.size.y - h) * 0.5)
	var empty := Color("6c6457")
	for i in range(total):
		var r := Rect2(roundf(i * (cell + gap)), y, floorf(cell), h)
		var color := IVORY.darkened(0.15) if i < used else empty
		if mode == Mode.PICK and not bag_full() and i == used: color = GOLD
		if mode == Mode.REPLACE and not outgoing.is_empty() and i == used - 1: color = RED
		if color == empty: canvas.draw_rect(r, color, false, 1.0)
		else: canvas.draw_rect(r, color)

class StageView extends Control:
	var host
	func _draw() -> void: host.draw_stage(self)

class ActorView extends Control:
	var host
	func _ready() -> void:
		var cutout := ShaderMaterial.new()
		cutout.shader = preload("res://redesign/monster_alpha_cutout.gdshader")
		cutout.set_shader_parameter("shadow_lift", 0.65)
		material = cutout
	func _draw() -> void: host.draw_actor(self)

class CapacityCells extends Control:
	var host
	func _draw() -> void: host.draw_cells(self)
