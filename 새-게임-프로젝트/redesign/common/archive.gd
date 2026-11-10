extends Control
## 기록실 (2026-11-08): the old teal workspace contents in the workshop/gate/depot theme.
## - 도시 기록: 20 records in five region rows (four per region). Found records open in
##   the reading panel on the right; missing ones say where they are found.
## - 보급 선호: the unlockable first-supply preferences, 30 data each. Hidden while
##   SUPPLY_PREFERENCE_VISIBLE is false (2026-11-08: they no longer change new runs).
## campaign_ui.archive() opens it and registers it as the screen's workspace overlay, so
## 닫기, Esc and focus return work like the other workspaces.
const Data = preload("res://redesign/campaign_content.gd")
const Lore = preload("res://redesign/city_story.gd")
const GOLD := Color("e9c27f")
const IVORY := Color("ebe2d1")
const MUTED := Color("a59c8b")
const REGIONS := ["승강장·주거 통로", "축열 주조장", "우수 정원", "귀족 거주구", "중앙 통제구"]
## Where each of a region's four records is found (campaign.gd collect_lore).
const SOURCES := ["빈 통로", "조우", "탄약고", "구역 관문"]

var ui
var presenter
var campaign
var tab := "records"
var selected := 0
var summary: Label
var records_tab: Button
var supply_tab: Button
var close_button: Button
var records_page: Control
var supply_page: Control
var record_title: Label
var record_meta: Label
var record_text: Label
var record_buttons: Dictionary = {}

func configure(screen, owner, initial_tab: String = "records") -> void:
	ui = screen
	presenter = owner
	campaign = screen.campaign
	tab = initial_tab
	var found: Array = campaign.profile.lore
	if not found.is_empty(): selected = int(found[found.size() - 1])

func _ready() -> void:
	build()
	open_tab(tab)
	close_button.grab_focus.call_deferred()

func compact() -> bool:
	return ui.ReadableUI.available(ui).size.x < 1000

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
	title.text = "기록실"
	title.theme_type_variation = &"SectionTitle"
	header.add_child(title)
	var profile: Dictionary = campaign.profile
	summary = Label.new()
	summary.name = "ArchiveSummary"
	summary.theme_type_variation = &"Caption"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.text = "완주 %d / 등반 %d · 최고 난도 %d" % [profile.wins, profile.runs, profile.ascension]
	if Data.SUPPLY_PREFERENCE_VISIBLE: summary.text += " · 전술 데이터 %d" % int(profile.cores)
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
	records_tab = tab_button(tabs, "RecordsTab", "도시 기록 %d / 20" % profile.lore.size(), group)
	records_tab.pressed.connect(open_tab.bind("records"))
	supply_tab = tab_button(tabs, "SupplyTab", "보급 선호", group)
	supply_tab.pressed.connect(open_tab.bind("supply"))
	# Hidden until the unlocks are redesigned (campaign_content.gd SUPPLY_PREFERENCE_VISIBLE).
	supply_tab.visible = Data.SUPPLY_PREFERENCE_VISIBLE
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Color(0.28, 0.25, 0.20, 1)
	frame.add_child(line)

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(pages)
	records_page = build_records()
	records_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(records_page)
	supply_page = build_supply()
	supply_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(supply_page)

func tab_button(parent: Control, id: String, label: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.name = id
	button.text = label
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = &"ModeTab"
	button.custom_minimum_size = Vector2(120, 44)
	parent.add_child(button)
	return button

func open_tab(id: String) -> void:
	tab = "supply" if id == "supply" and Data.SUPPLY_PREFERENCE_VISIBLE else "records"
	records_tab.set_pressed_no_signal(tab == "records")
	supply_tab.set_pressed_no_signal(tab == "supply")
	records_page.visible = tab == "records"
	supply_page.visible = tab == "supply"
	ui._workspace_focus_chain.call_deferred()

# ---------------------------------------------------------------- 도시 기록

func build_records() -> Control:
	var page := HBoxContainer.new()
	page.name = "RecordsPage"
	page.add_theme_constant_override("separation", 16)
	var scroll := ScrollContainer.new()
	scroll.name = "RecordScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.4
	page.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.name = "RecordRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	var small := compact()
	var group := ButtonGroup.new()
	var found: Array = campaign.profile.lore
	for region in range(5):
		var row := HBoxContainer.new()
		row.name = "Region%d" % (region + 1)
		row.add_theme_constant_override("separation", 6)
		rows.add_child(row)
		var name_label := Label.new()
		name_label.text = ("%d구역" % (region + 1)) if small else ("%d  %s" % [region + 1, REGIONS[region]])
		name_label.theme_type_variation = &"Caption"
		name_label.custom_minimum_size.x = 56.0 if small else 170.0
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		for k in range(4):
			var id := region * 4 + k + 1
			var known := found.any(func(value): return int(value) == id)
			row.add_child(record_cell(id, known, SOURCES[k], group, small))
	var reader := PanelContainer.new()
	reader.name = "RecordReader"
	reader.theme_type_variation = &"Inspector"
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(reader)
	var reader_scroll := ScrollContainer.new()
	reader_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reader.add_child(reader_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	reader_scroll.add_child(body)
	record_title = wrap_label(body, "RecordTitle", "")
	record_title.add_theme_font_size_override("font_size", 32)
	record_meta = wrap_label(body, "RecordMeta", "")
	record_meta.add_theme_color_override("font_color", GOLD)
	record_text = wrap_label(body, "StoryRecordText", "")
	show_record(selected)
	return page

func record_cell(id: int, known: bool, source: String, group: ButtonGroup, small: bool) -> Button:
	var cell := Button.new()
	cell.name = ("city_lore_%d" if known else "city_lore_locked_%d") % id
	cell.toggle_mode = true
	cell.button_group = group
	cell.disabled = not known
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(0, 48 if small else 58)
	cell.tooltip_text = Lore.entry(id).title if known else source + "에서 발견"
	var lines := VBoxContainer.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = 8
	lines.offset_right = -8
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(lines)
	var number := Label.new()
	number.text = "%02d" % id
	number.add_theme_color_override("font_color", GOLD if known else Color(0.43, 0.40, 0.34, 1))
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(number)
	var name_label := Label.new()
	name_label.text = str(Lore.entry(id).title) if known else source
	name_label.add_theme_color_override("font_color", IVORY if known else Color(0.43, 0.40, 0.34, 1))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.visible = not small or not known
	lines.add_child(name_label)
	if known:
		cell.pressed.connect(show_record.bind(id))
		record_buttons[id] = cell
	return cell

func show_record(id: int) -> void:
	selected = id
	if id <= 0 or not record_buttons.has(id):
		record_title.text = "아직 복원한 기록이 없습니다"
		record_meta.text = "구역마다 네 편 · 빈 통로, 조우, 탄약고, 구역 관문"
		record_text.text = "등반 중 발견한 도시 기록이 이곳에 쌓입니다. 발견한 기록은 다음 등반에서도 남습니다."
		return
	record_buttons[id].set_pressed_no_signal(true)
	var entry := Lore.entry(id)
	var region := int((id - 1) / 4)
	record_title.text = str(entry.title)
	record_meta.text = "%d구역 %s · %s · %02d / 20" % [region + 1, REGIONS[region], SOURCES[(id - 1) % 4], id]
	record_text.text = str(entry.text)

func wrap_label(parent: Control, id: String, value: String) -> Label:
	var label := Label.new()
	if not id.is_empty(): label.name = id
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

# ---------------------------------------------------------------- 보급 선호

func build_supply() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "SupplyPage"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	var profile: Dictionary = campaign.profile
	var lead := wrap_label(column, "SupplyLead", "첫 특수탄 보급 선호 · 첫 승리 후 선택 후보를 바꿉니다. 해금한 선호는 등반 설정에서 고릅니다.")
	lead.theme_type_variation = &"Caption"
	var data := wrap_label(column, "SupplyData", "전술 데이터 %d · 해금 30" % int(profile.cores))
	data.add_theme_color_override("font_color", GOLD)
	var grid := GridContainer.new()
	grid.name = "SupplyGrid"
	grid.columns = 1 if compact() else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for id in Data.LOADOUTS:
		var owned: bool = profile.unlocks.has(id)
		var card := PanelContainer.new()
		card.name = "Supply_" + id
		card.theme_type_variation = &"Inspector"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_theme_constant_override("separation", 2)
		row.add_child(copy)
		var name_label := wrap_label(copy, "", str(Data.LOADOUTS[id].name))
		name_label.add_theme_color_override("font_color", IVORY)
		var button := Button.new()
		button.name = "city_unlock_" + id
		button.text = "해금됨" if owned else "해금 · 30데이터"
		button.disabled = owned or int(profile.cores) < 30
		button.custom_minimum_size = Vector2(150, 44)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not button.disabled: button.theme_type_variation = &"PrimaryButton"
		button.pressed.connect(unlock.bind(id))
		row.add_child(button)
	return scroll

func unlock(id: String) -> void:
	ui.feedback.play("click")
	if campaign.unlock(id):
		ui._persist()
		presenter.archive.call_deferred("supply")
