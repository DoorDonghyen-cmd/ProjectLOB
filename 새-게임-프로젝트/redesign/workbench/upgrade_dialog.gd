extends Control
const Plan = preload("res://redesign/ammo_upgrade.gd")
const Ammo = preload("res://redesign/content.gd")
const Comparison = preload("res://redesign/ammo_comparison.gd")
const Readability = preload("res://redesign/readability.gd")
signal requested(source: String)
signal selection_changed(source: String)
signal closed
var campaign
var selected := "basic_p3"
var proposal: Dictionary = {}
var committing := false
var commit_action: Callable
var return_focus: Control
@onready var body: VBoxContainer = $Center/Panel/Body
@onready var sources: HBoxContainer = $Center/Panel/Body/Materials/Row/Scroll/Choices

func _ready() -> void:
	body.get_node("Header/Close").pressed.connect(dismiss)
	body.get_node("Actions/Cancel").pressed.connect(dismiss)
	body.get_node("Actions/Confirm").pressed.connect(confirm)
	body.get_node("Materials/Row/Previous").pressed.connect(_scroll_materials.bind(-1))
	body.get_node("Materials/Row/Next").pressed.connect(_scroll_materials.bind(1))
	var bar: HScrollBar = body.get_node("Materials/Row/Scroll").get_h_scroll_bar()
	bar.value_changed.connect(func(_value): _scroll_state())
	bar.changed.connect(_scroll_state)
	hide()

func _scroll_materials(direction: int) -> void:
	var scroll: ScrollContainer = body.get_node("Materials/Row/Scroll")
	scroll.scroll_horizontal += direction * 300

func _scroll_state() -> void:
	var scroll: ScrollContainer = body.get_node("Materials/Row/Scroll")
	var bar := scroll.get_h_scroll_bar()
	body.get_node("Materials/Row/Previous").disabled = bar.value <= bar.min_value
	body.get_node("Materials/Row/Next").disabled = bar.value >= bar.max_value - bar.page - 1

func open(owner, source: String, action: Callable, previous: Control = null) -> void:
	campaign = owner
	selected = source
	commit_action = action
	return_focus = previous
	for item in sources.get_children():
		sources.remove_child(item)
		item.queue_free()
	var counts: Dictionary = {}
	for id in campaign.model.s.deck: counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		var item := Button.new()
		item.custom_minimum_size = Vector2(0, 44)
		item.toggle_mode = true
		item.name = "Material_" + str(id)
		sources.add_child(item)
		item.set_meta("ammo", id)
		item.text = "%s · %d발" % [Plan.identity(id), counts[id]]
		item.pressed.connect(choose_source.bind(str(id)))
	show()
	refresh()
	body.get_node("Header/Close").grab_focus()

func choose_source(id: String) -> void:
	selected = id
	selection_changed.emit(id)
	refresh()

func _card(path: String, id: String, count: int, caption: String) -> void:
	var card: Control = body.get_node("Review/Rows/" + path)
	card.get_node("Frame").tier = 1 if Ammo.grade(id) == 1 else 0
	card.get_node("Content/Caption").text = caption
	card.get_node("Content/Icon").item_id = id
	card.get_node("Content/Name").text = Ammo.AMMO[id].name
	card.get_node("Content/Count").text = "%s · %d발" % ["고급" if Ammo.grade(id) == 1 else "일반", count]
	var profile := Plan.profile_mark(id)
	if not profile.is_empty(): card.get_node("Content/Count").text += "\n" + profile

func refresh() -> void:
	if campaign == null: return
	proposal = Plan.inspect(campaign, selected)
	for item in sources.get_children(): item.set_pressed_no_signal(item.get_meta("ammo") == selected)
	var target := str(proposal.target)
	var valid: bool = proposal.valid
	_card("Comparison/Before", selected, int(proposal.required), "소모 탄환")
	_card("Comparison/After", target if not target.is_empty() else selected, 1, "결과 탄환" if valid else "강화 불가")
	body.get_node("Review/Rows/Comparison/After").modulate = Color.WHITE if valid else Color(0.5, 0.48, 0.43)
	var stats := body.get_node("Review/Rows/Comparison/Stats")
	var values: Array = []
	if not target.is_empty():
		values = Plan.comparison(selected,target,campaign.model.s,campaign.model.s.deck.size(),int(proposal.after.deck.size()) if valid else -1)
	for i in range(4):
		for j in range(3):
			var label: Label = stats.get_node("Cell%d%d" % [i, j])
			label.text = (("→ " if j == 2 else "") + str(values[i][j])) if i < values.size() else "—"
	var detail := str(proposal.reason)
	var source_text: Label = body.get_node("Review/Rows/Details/SourceText")
	source_text.visible = valid and Ammo.source_id(selected) != "basic"
	source_text.text = "원본 / 발\n" + Readability._description(selected,campaign.model.s) if source_text.visible else ""
	if valid:
		detail = "탄 수 · 발사 횟수 2 → 1"
		if Ammo.source_id(target) != "basic": detail = "강화 / 발\n" + Readability._description(target, campaign.model.s)
		if Ammo.anchor(target) == "first": detail += "\n첫 발 고정"
		elif Ammo.anchor(target) == "last": detail += "\n마지막 발 고정"
	body.get_node("Review/Rows/Details/Text").text = detail
	body.get_node("Actions/Cost").text = "무료 정비 1회 사용" if not campaign.s.resolved else "정비 완료"
	body.get_node("Actions/Confirm").text = "강화 확정"
	body.get_node("Actions/Confirm").disabled = not valid or committing

func confirm() -> void:
	if committing: return
	# Recompute after selection and again at commit, never trust cached eligibility.
	proposal = Plan.inspect(campaign, selected)
	if not proposal.valid:
		refresh()
		return
	committing = true
	requested.emit(selected)
	if commit_action.is_valid() and bool(commit_action.call(selected)):
		dismiss()
	committing = false
	refresh()

func dismiss() -> void:
	hide()
	closed.emit()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree(): return_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var buttons: Array = body.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and not b.disabled)
		if not buttons.is_empty():
			var current := buttons.find(get_viewport().gui_get_focus_owner())
			var step := -1 if event.is_action_pressed("ui_focus_prev") else 1
			buttons[posmod(current + step, buttons.size())].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
