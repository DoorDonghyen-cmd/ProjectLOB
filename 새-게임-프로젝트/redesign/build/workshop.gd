extends Control
## 빌드 작업실 (2026-11-08). Replaces the old teal workspace contents with the approved
## language instead of a new design:
## - 파츠 구성: the shop terminal's part mount (5 slots, storage list, gain/loss/stats,
##   equip / unequip / swap by choosing the slot), see build/part_mount_view.gd.
## - 탄환 덱: the depot's carried-ammo cells and round stacks, with one round's detail.
## - Workshop/gate/depot theme (redesign/workbench/theme.tres).
## campaign_ui.deck() opens it and registers it as the screen's workspace overlay, so
## 닫기, Esc and focus return work as before. Part changes go through
## screen.gd::_campaign_action (autosave) without closing the workshop.
const Ammo = preload("res://redesign/content.gd")
const Comparison = preload("res://redesign/ammo_comparison.gd")
const Readability = preload("res://redesign/readability.gd")
const Gates = preload("res://redesign/gate_upgrades.gd")
const PartMount = preload("res://redesign/samples/shop_terminal_review/part_mount.tscn")
const PartMountView = preload("res://redesign/build/part_mount_view.gd")
const Item = preload("res://redesign/workbench/item.tscn")
const GOLD := Color("e9c27f")
const IVORY := Color("ebe2d1")
const MUTED := Color("a59c8b")

var ui
var presenter
var campaign
var tab := "parts"
var feedback_text := ""
var summary: Label
var notice: Label
var parts_tab: Button
var ammo_tab: Button
var close_button: Button
var parts_page: Control
var ammo_page: Control
var mount
var pack_label: Label
var cells: Control
var stacks_grid: GridContainer
var stack_buttons: Dictionary = {}
var stack_group := ButtonGroup.new()
var selected_ammo := ""
var ammo_title: Label
var ammo_grade: Label
var ammo_text: Label
var ammo_stats: Label
var ammo_hint: Label

func configure(screen, owner, initial_tab: String = "parts", feedback: String = "") -> void:
	ui = screen
	presenter = owner
	campaign = screen.campaign
	tab = "ammo" if initial_tab == "ammo" else "parts"
	feedback_text = feedback

func _ready() -> void:
	build()
	open_tab(tab)
	refresh_summary()
	close_button.grab_focus.call_deferred()

func build() -> void:
	theme = preload("res://redesign/workbench/theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.035, 0.028, 0.022, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe: Rect2 = ui.ReadableUI.available(ui)
	var edges := {"left": safe.position.x, "top": safe.position.y, "right": maxf(0.0, ui.size.x - safe.end.x), "bottom": maxf(0.0, ui.size.y - safe.end.y)}
	for side in edges: margin.add_theme_constant_override("margin_" + side, 18 + ceili(edges[side]))
	add_child(margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	margin.add_child(frame)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	frame.add_child(header)
	var title := Label.new()
	title.text = "빌드 작업실"
	title.theme_type_variation = &"SectionTitle"
	header.add_child(title)
	summary = Label.new()
	summary.name = "DeckSummary"
	summary.theme_type_variation = &"Caption"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(summary)
	close_button = Button.new()
	close_button.name = "workspace_close"
	close_button.text = "닫기"
	close_button.custom_minimum_size = Vector2(96, 44)
	close_button.pressed.connect(func(): ui._close_workspace())
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 6)
	frame.add_child(tabs)
	var group := ButtonGroup.new()
	parts_tab = tab_button(tabs, "PartsTab", "파츠 구성", group)
	parts_tab.pressed.connect(open_tab.bind("parts"))
	ammo_tab = tab_button(tabs, "AmmoTab", "탄환 덱", group)
	ammo_tab.pressed.connect(open_tab.bind("ammo"))
	notice = Label.new()
	notice.name = "BuildFeedback"
	notice.theme_type_variation = &"Caption"
	notice.add_theme_color_override("font_color", GOLD)
	notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notice.clip_text = true
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tabs.add_child(notice)
	var rule := ColorRect.new()
	rule.color = Color(0.29, 0.252, 0.194, 1)
	rule.custom_minimum_size = Vector2(0, 1)
	frame.add_child(rule)

	parts_page = VBoxContainer.new()
	parts_page.name = "PartsPage"
	parts_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(parts_page)
	mount = PartMount.instantiate()
	mount.set_script(PartMountView)
	mount.name = "PartsPane"
	mount.workshop = self
	mount.read_only = not campaign.can_manage_parts()
	mount.perform_action = perform
	parts_page.add_child(mount)

	ammo_page = HBoxContainer.new()
	ammo_page.name = "AmmoPage"
	ammo_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ammo_page.add_theme_constant_override("separation", 20)
	frame.add_child(ammo_page)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	ammo_page.add_child(left)
	var pack_row := HBoxContainer.new()
	pack_row.add_theme_constant_override("separation", 14)
	left.add_child(pack_row)
	pack_label = Label.new()
	pack_label.name = "PackTitle"
	pack_label.theme_type_variation = &"Caption"
	pack_row.add_child(pack_label)
	cells = CapacityCells.new()
	cells.name = "Capacity"
	cells.host = self
	cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cells.custom_minimum_size = Vector2(0, 16)
	pack_row.add_child(cells)
	var scroll := ScrollContainer.new()
	scroll.name = "StacksScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	stacks_grid = GridContainer.new()
	stacks_grid.name = "Stacks"
	stacks_grid.add_theme_constant_override("h_separation", 6)
	stacks_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(stacks_grid)
	var detail := PanelContainer.new()
	detail.name = "AmmoDetail"
	detail.theme_type_variation = &"Inspector"
	detail.custom_minimum_size = Vector2(320, 0)
	detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ammo_page.add_child(detail)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	detail.add_child(column)
	ammo_title = label(column, "AmmoName", &"SectionTitle")
	ammo_grade = label(column, "AmmoGrade", &"Caption")
	ammo_grade.add_theme_color_override("font_color", GOLD)
	ammo_text = label(column, "AmmoText", &"")
	ammo_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ammo_stats = label(column, "AmmoStats", &"Caption")
	column.add_child(HSeparator.new())
	ammo_hint = label(column, "AmmoHint", &"Caption")
	ammo_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ammo_hint.add_theme_color_override("font_color", MUTED)
	ammo_hint.text = "새 탄은 탄약고·조우·보상에서, 교체와 강화는 정비소에서 합니다."
	resized.connect(fit)

func tab_button(parent: Node, id: String, text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = &"ModeTab"
	button.custom_minimum_size = Vector2(120, 44)
	parent.add_child(button)
	return button

func label(parent: Node, id: String, variation: StringName) -> Label:
	var item := Label.new()
	item.name = id
	if variation != &"": item.theme_type_variation = variation
	parent.add_child(item)
	return item

func compact() -> bool:
	return size.y < 520.0

func fit() -> void:
	if stacks_grid == null: return
	var detail_width := 300.0 if size.x < 1000.0 else 340.0
	(ammo_page.get_node("AmmoDetail") as Control).custom_minimum_size.x = detail_width
	var item_width := 132.0 if compact() else 144.0
	stacks_grid.columns = maxi(1, floori((size.x - detail_width - 80.0) / (item_width + 6.0)))
	for item in stacks_grid.get_children():
		item.custom_minimum_size = Vector2(item_width, 62) if compact() else Vector2(item_width, 92)
		item.get_node("Content/Icon").visible = not compact()
	ammo_text.visible = not compact()
	ammo_hint.visible = not compact()

func open_tab(id: String) -> void:
	tab = id
	parts_tab.set_pressed_no_signal(id == "parts")
	ammo_tab.set_pressed_no_signal(id == "ammo")
	parts_page.visible = id == "parts"
	ammo_page.visible = id == "ammo"
	if id == "parts":
		mount.open(campaign, presenter.selected_part_id if campaign.s.parts.has(presenter.selected_part_id) else "")
	else:
		rebuild_stacks()

func refresh_summary() -> void:
	var model = campaign.model
	var text := "%s · 탄창 %d칸 · 재장전 %d턴 · 휴대 %d / %d발" % [Ammo.GUNS[campaign.s.gun].name, model.capacity(), model.reload_cost(), model.s.deck.size(), model.deck_limit()]
	if Ammo.Roles.enabled(model.s): text += " · 덱 최소 %d" % campaign.minimum_deck()
	if not campaign.magazine_enabled(): text += " · 손패 %d장 / 교환 %d" % [Ammo.hand_capacity(model.s), Ammo.exchange_capacity(model.s)]
	summary.text = text
	summary.tooltip_text = text + "\n" + Ammo.outfit_name(model.s)
	var lines: PackedStringArray = []
	if not feedback_text.is_empty(): lines.append(feedback_text)
	elif not campaign.can_manage_parts(): lines.append("교전 중에는 열람만 가능")
	else: lines.append("파츠 교체 무료")
	var gate := Gates.active_summary(model.s)
	if not gate.is_empty(): lines.append("관문 개조 · " + gate)
	notice.text = "   ·   ".join(lines)
	notice.tooltip_text = notice.text

## Part change from the mount: the main handler (autosave), the workshop stays open.
func perform(command: String, value: String, extra: String) -> bool:
	var accepted: bool = ui._campaign_action(command, value, extra, "", false)
	if accepted:
		presenter.selected_part_id = extra if command == "replace_part" else value
		feedback_text = "구성을 적용했습니다."
		refresh_summary()
	return accepted

func show_rules(id: String) -> void:
	presenter.part_details(id)

func can_dismantle(id: String) -> bool:
	return campaign.can_manage_parts() and not campaign.is_equipped(id) and str(campaign.s.phase) in ["shop", "supply"]

func dismantle(id: String) -> void:
	presenter._confirm_part_dismantle(id)

func rebuild_stacks() -> void:
	for child in stacks_grid.get_children():
		stacks_grid.remove_child(child)
		child.queue_free()
	stack_buttons.clear()
	var deck: Array = campaign.model.s.deck
	var counts: Dictionary = {}
	for id in deck: counts[id] = int(counts.get(id, 0)) + 1
	var order: Array = counts.keys()
	order.sort_custom(func(a, b): return Ammo.source_id(str(a)) != "basic" and Ammo.source_id(str(b)) == "basic" or (Ammo.source_id(str(a)) == Ammo.source_id(str(b)) and str(a) < str(b)))
	for id in order:
		var item: Button = Item.instantiate()
		item.name = "Stack_" + str(id)
		item.button_group = stack_group
		item.get_node("Content/Icon").item_id = id
		item.get_node("Content/Name").text = Ammo.AMMO[id].name
		item.get_node("Content/Count").text = "%s · %d발" % [Comparison.power(str(id), campaign.model.s), int(counts[id])]
		item.get_node("Content/Count").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item.pressed.connect(select_ammo.bind(str(id)))
		stacks_grid.add_child(item)
		stack_buttons[str(id)] = item
	if not counts.has(selected_ammo): selected_ammo = str(order[0]) if not order.is_empty() else ""
	pack_label.text = "휴대 탄약 %d / %d발" % [deck.size(), campaign.model.deck_limit()]
	select_ammo(selected_ammo)
	fit()
	cells.queue_redraw()

func select_ammo(id: String) -> void:
	selected_ammo = id
	for key in stack_buttons: stack_buttons[key].set_pressed_no_signal(key == id)
	if id.is_empty():
		ammo_title.text = "탄환 없음"
		return
	var state: Dictionary = campaign.model.s
	var count: int = state.deck.count(id)
	ammo_title.text = str(Ammo.AMMO[id].name)
	ammo_grade.text = "%s · %d장 · 덱의 %d%%" % [Ammo.grade_name(id), count, roundi(float(count) / maxf(1.0, float(state.deck.size())) * 100.0)]
	var lines: PackedStringArray = Readability.description(id, state).get_slice("\n\n", 0).split("\n")
	if lines.size() > 1 and lines[0].length() <= 4: lines.remove_at(0)
	ammo_text.text = "\n".join(lines)
	ammo_stats.text = "%s · 발열 %s · 탄창 %d칸" % [Comparison.power(id, state), Ammo.heat_label(id, state), Ammo.slot_cost(id)]

func draw_cells(canvas: Control) -> void:
	var total: int = campaign.model.deck_limit()
	var used: int = campaign.model.s.deck.size()
	var gap := 2.0
	var cell := clampf((canvas.size.x - gap * (total - 1)) / total, 4.0, 14.0)
	var h := minf(canvas.size.y, 12.0)
	var y := roundf((canvas.size.y - h) * 0.5)
	for i in range(total):
		var r := Rect2(roundf(i * (cell + gap)), y, floorf(cell), h)
		if i < used: canvas.draw_rect(r, IVORY.darkened(0.15))
		else: canvas.draw_rect(r, Color("6c6457"), false, 1.0)

class CapacityCells extends Control:
	var host
	func _draw() -> void: host.draw_cells(self)
