extends Control
## Story scenes (2026-11-08): 출발 3장면, 공급 복구, 귀환. Same language as the approved
## event and depot scenes: the residential art fills the screen, the existing supply
## diagram (story_scene.gd) sits over it, and a story panel on the right holds the beat,
## the prose and one action. Text is unchanged from story_ui.gd before the rework.
## Node names (menu, story_skip, story_next, story_restore, story_results, SupplyScene)
## are kept for the existing flow and tests.
const Art = preload("res://redesign/world_art.gd")
const Diagram = preload("res://redesign/story_scene.gd")
const BACKGROUND = preload("res://assets/art/tower_sample_20261003/residential_tower.png")
const GOLD := Color("e9c27f")
const IVORY := Color("ebe2d1")
const MUTED := Color("a59c8b")
const COLD := Color("9fb3bd")
const ALERT := Color("f2a38d")

var host
var place := ""
var step_text := ""
var title := ""
var prose := ""
var supplied := false
var released := false
var actions: Array = []
var diagram: Control
var panel: PanelContainer
var status_row: HBoxContainer
var primary: Button

## actions: [[node name, label, callable, primary?], ...]
func configure(screen, place_name: String, step: String, beat_title: String, beat_text: String, is_supplied: bool, is_released: bool, buttons: Array) -> void:
	host = screen
	place = place_name
	step_text = step
	title = beat_title
	prose = beat_text
	supplied = is_supplied
	released = is_released
	actions = buttons

func _ready() -> void:
	theme = preload("res://redesign/workbench/theme.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	build()
	resized.connect(layout)
	layout.call_deferred()
	if primary != null: host._focus_control.call_deferred(primary)

func _draw() -> void:
	Art.cover(self, BACKGROUND, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.02, 0.42))

func compact() -> bool:
	return size.y < 560

func build() -> void:
	diagram = Diagram.new()
	diagram.name = "SupplyScene"
	diagram.backdrop = false
	diagram.supplied = supplied
	diagram.released = released
	add_child(diagram)

	status_row = HBoxContainer.new()
	status_row.name = "SupplyStatus"
	add_child(status_row)
	status(status_row, "정상 · 중앙 제어", MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	status(status_row, "현장 제어 가능" if released else "수동 밸브", GOLD if released else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	status(status_row, "우리 동네 · 공급 중" if supplied else "우리 동네 · 공급 중단", GOLD if supplied else ALERT, HORIZONTAL_ALIGNMENT_RIGHT)

	var menu := Button.new()
	menu.name = "menu"
	menu.text = "메뉴"
	menu.custom_minimum_size = Vector2(88, 44)
	menu.position = Vector2(16, 14)
	menu.pressed.connect(press.bind(Callable(host, "_to_menu")))
	add_child(menu)

	panel = PanelContainer.new()
	panel.name = "StoryPanel"
	panel.theme_type_variation = &"Inspector"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.052, 0.043, 0.94)
	style.border_width_top = 2
	style.border_color = Color(0.36, 0.31, 0.23, 1)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var kicker := label(column, "StoryPlace", place + ("" if step_text.is_empty() else "  ·  " + step_text), GOLD)
	kicker.theme_type_variation = &"Caption"
	kicker.add_theme_color_override("font_color", GOLD)
	var heading := label(column, "StoryTitle", title, IVORY)
	heading.theme_type_variation = &"SectionTitle"
	label(column, "StoryText", prose, IVORY)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	for entry in actions:
		var button := Button.new()
		button.name = str(entry[0])
		button.text = str(entry[1])
		button.custom_minimum_size = Vector2(0, 52 if bool(entry[3]) else 44)
		if bool(entry[3]):
			button.theme_type_variation = &"PrimaryButton"
			primary = button
		button.pressed.connect(press.bind(entry[2]))
		column.add_child(button)

func press(callback: Callable) -> void:
	host.feedback.play("click")
	callback.call()

func status(parent: HBoxContainer, value: String, color: Color, align: HorizontalAlignment) -> void:
	var item := Label.new()
	item.text = value
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.horizontal_alignment = align
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_outline_color", Color(0.02, 0.016, 0.012, 1))
	item.add_theme_constant_override("outline_size", 4)
	parent.add_child(item)

func label(parent: Control, id: String, value: String, color: Color) -> Label:
	var item := Label.new()
	item.name = id
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

## Panel on the right (a third of the width, 340..480), the diagram fills the rest.
func layout() -> void:
	var margin := 12.0 if compact() else 20.0
	var panel_width := clampf(size.x * 0.36, 340.0, 480.0)
	panel.position = Vector2(size.x - panel_width - margin, margin)
	panel.size = Vector2(panel_width, size.y - margin * 2)
	var left := margin
	var right := panel.position.x - margin
	var top := 66.0 if compact() else 84.0
	var status_height := 28.0
	diagram.position = Vector2(left, top)
	diagram.size = Vector2(maxf(1.0, right - left), maxf(1.0, size.y - top - margin - status_height - 8.0))
	status_row.position = Vector2(left + 8.0, diagram.position.y + diagram.size.y + 4.0)
	status_row.size = Vector2(maxf(1.0, right - left - 16.0), status_height)
	queue_redraw()
