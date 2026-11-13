extends Control
## Player-facing build workshop. Scene geometry is authored in workshop.tscn.
const Ammo = preload("res://redesign/content.gd")
const Comparison = preload("res://redesign/ammo_comparison.gd")
const Readability = preload("res://redesign/readability.gd")
const Gates = preload("res://redesign/gate_upgrades.gd")
const Item = preload("res://redesign/workbench/item.tscn")
const IVORY := Color("ebe2d1")

var ui
var presenter
var campaign
var tab := "parts"
var feedback_text := ""
var preferred_part := ""
var stack_buttons: Dictionary = {}
var stack_group := ButtonGroup.new()
var selected_ammo := ""

@onready var mount = %PartsPane
@onready var parts_tab: Button = %PartsTab
@onready var ammo_tab: Button = %AmmoTab
@onready var close_button: Button = %workspace_close
@onready var parts_page: Control = %PartsPage
@onready var ammo_page: Control = %AmmoPage
@onready var pack_label: Label = %PackTitle
@onready var cells: Control = %Capacity
@onready var stacks_grid: GridContainer = %Stacks
@onready var ammo_title: Label = %AmmoName
@onready var ammo_grade: Label = %AmmoGrade
@onready var ammo_text: Label = %AmmoText
@onready var ammo_stats: Label = %AmmoStats
@onready var ammo_hint: Label = %AmmoHint

func configure(screen, owner, initial_tab: String = "parts", feedback: String = "", preferred: String = "") -> void:
	ui = screen
	presenter = owner
	campaign = screen.campaign
	tab = "ammo" if initial_tab == "ammo" else "parts"
	feedback_text = feedback
	preferred_part = preferred if not preferred.is_empty() else str(owner.selected_part_id)

func _ready() -> void:
	mount.workshop = self
	mount.perform_action = perform
	var tabs := ButtonGroup.new()
	parts_tab.button_group = tabs
	ammo_tab.button_group = tabs
	parts_tab.pressed.connect(open_tab.bind("parts"))
	ammo_tab.pressed.connect(open_tab.bind("ammo"))
	close_button.pressed.connect(ui._close_workspace)
	cells.draw.connect(draw_cells.bind(cells))
	resized.connect(fit)
	fit()
	open_tab(tab)
	refresh_summary()
	close_button.grab_focus.call_deferred()
	ui._workspace_focus_chain.call_deferred()

func compact() -> bool:
	return size.y < 520.0

func fit() -> void:
	var safe: Rect2 = ui.ReadableUI.available(ui)
	var padding := 24 if size.x >= 1000 else 16
	%SafeArea.add_theme_constant_override("margin_left", padding + ceili(safe.position.x))
	%SafeArea.add_theme_constant_override("margin_right", padding + ceili(maxf(0.0, size.x - safe.end.x)))
	%SafeArea.add_theme_constant_override("margin_top", ceili(safe.position.y))
	%SafeArea.add_theme_constant_override("margin_bottom", padding + ceili(maxf(0.0, size.y - safe.end.y)))
	$HeaderBand.offset_bottom = safe.position.y + 60.0
	var detail_width := 300.0 if size.x < 1000.0 else 340.0
	%AmmoDetail.custom_minimum_size.x = detail_width
	var item_width := 132.0 if compact() else 144.0
	stacks_grid.columns = maxi(1, floori((safe.size.x - detail_width - 2 * padding - 26.0) / (item_width + 6.0)))
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
	if id == "parts" and mount.campaign == null:
		mount.open(campaign, preferred_part)
	elif id == "ammo":
		rebuild_stacks()
	ui._workspace_focus_chain.call_deferred()

func refresh_summary() -> void:
	var model = campaign.model
	var text := "%s · 탄창 %d칸 · 탄창 교체 적 %d행동 · 탄약 %d / %d발" % [Ammo.GUNS[campaign.s.gun].name, model.capacity(), model.reload_cost(), model.s.deck.size(), model.deck_limit()]
	if Ammo.Roles.enabled(model.s): text += " · 덱 최소 %d" % campaign.minimum_deck()
	if not campaign.magazine_enabled(): text += " · 손패 %d장 / 교환 %d" % [Ammo.hand_capacity(model.s), Ammo.exchange_capacity(model.s)]
	%DeckSummary.text = text
	var gate := Gates.active_summary(model.s)
	var run_details := text + "\n" + Ammo.outfit_name(model.s)
	if not gate.is_empty(): run_details += "\n관문 개조 · " + gate
	%DeckSummary.tooltip_text = run_details
	mount.get_node("%GunStats").tooltip_text = run_details
	var lines: PackedStringArray = []
	if not ui.save_error.is_empty(): lines.append(ui.save_error)
	elif not feedback_text.is_empty(): lines.append(feedback_text)
	elif not campaign.can_manage_parts(): lines.append("교전 중에는 열람만 가능")
	%BuildFeedback.text = "   ·   ".join(lines)
	%BuildFeedback.tooltip_text = %BuildFeedback.text

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
	return campaign.can_manage_parts() and campaign.s.parts.has(id) and not campaign.is_equipped(id) and str(campaign.s.phase) in ["shop", "supply"]

func dismantle(id: String) -> void:
	presenter._confirm_part_dismantle(id, _dismantle_confirmed.bind(id))

func _dismantle_confirmed(id: String) -> void:
	if not ui._campaign_action("dismantle", id, "", "", false): return
	presenter.selected_part_id = ""
	feedback_text = "%s 분해 · +10Cr" % Ammo.PARTS[id].name
	mount.open(campaign, "")
	mount.parts_changed.emit()
	refresh_summary()

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
	pack_label.text = "보유 탄약 %d / %d발" % [deck.size(), campaign.model.deck_limit()]
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
