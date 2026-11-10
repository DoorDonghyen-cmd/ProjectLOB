extends "res://redesign/samples/shop_counter_review/preview.gd"

const GARDEN := "shop_heavy_17_r3_n20402"
const CONTROL := "shop_heavy_17_r5_n40401"
const RECORD_TITLES := [
	"다시 닫힌 난방",
	"난방 코일 반려",
	"열린 격리문",
	"열한 개의 컵",
	"공급 복구 전 확인",
]

func _ready() -> void:
	bind_terminal_controls()
	%Survey.resized.connect(fit_graph)
	super._ready()
	var output := OS.get_environment("LOB_SHOP_TERMINAL_CAPTURE")
	if not output.is_empty():
		capture_terminal.call_deferred(output)

func bind_terminal_controls() -> void:
	%StockTab.pressed.connect(show_record.bind(false))
	%LogTab.pressed.connect(show_record.bind(true))
	%Leave.pressed.connect(return_to_map)

func fit() -> void:
	var window := get_window()
	var factor := Readability.scale_for(window.size)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = Vector2i.ZERO
	window.content_scale_factor = factor
	fit_area(Readability.available(self))

func fit_area(safe: Rect2) -> void:
	var compact := safe.size.y < 528.0
	var extent := Vector2(minf(1104, safe.size.x - 40), minf(604, safe.size.y - (16.0 if compact else 36.0))).floor()
	var center := (safe.get_center() - size * 0.5).round()
	%Composition.offset_left = center.x - extent.x * 0.5
	%Composition.offset_right = center.x + extent.x * 0.5
	%Composition.offset_top = center.y - extent.y * 0.5
	%Composition.offset_bottom = center.y + extent.y * 0.5
	%Display.offset_top = 18.0 if compact else 26.0
	%Display.offset_bottom = -76.0 if compact else -80.0
	%Display.add_theme_constant_override("separation", 6 if compact else 8)
	%ItemArt.custom_minimum_size = Vector2(84, 56) if compact else Vector2(100, 84)
	%RecordCopy.custom_minimum_size.x = minf(660.0, extent.x - 132.0)
	for index in range(3):
		offer_button(index).custom_minimum_size.y = 51.0 if compact else 67.0

func load_example(index: int) -> void:
	var target := index if index > 0 else scenario
	%Map.hide()
	%Terminal.show()
	if target < 5:
		super.load_example(target)
	else:
		scenario = target
		var filename := GARDEN if target == 5 else CONTROL
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + filename + ".json"))
		var fresh := Campaign.new()
		if not data is Dictionary or not fresh.restore_state(data) or fresh.s.phase != "shop":
			%Feedback.text = "상점 기록을 불러올 수 없습니다."
			return
		run = fresh
		selected = 2 if target == 6 else 1
		%Feedback.text = ""
		close_replacement()
		refresh()
	show_record(false)

func refresh_map() -> void:
	var region_name := str(run.region_info().name)
	var location := str(run.node().name)
	%Region.text = region_name
	%MapLocation.text = "현재 · " + location
	%Graph.feedback_scale = 0.0
	%Graph.setup(run)
	for marker: Button in %Graph.get_children():
		marker.focus_mode = Control.FOCUS_NONE
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.tooltip_text = ""
	fit_graph.call_deferred()

func fit_graph() -> void:
	if not %Map.visible:
		return
	var graph: Control = %Graph
	var survey: Control = %Survey
	var graph_width := minf(880.0, survey.size.x)
	graph.size = Vector2(graph_width, graph.custom_minimum_size.y)
	if graph.size.y < 1.0 or graph_width < 1.0:
		return
	var factor := minf(survey.size.x / graph.size.x, survey.size.y / graph.size.y)
	graph.scale = Vector2.ONE * factor
	graph.position = ((survey.size - graph.size * factor) * 0.5).floor()

func refresh() -> void:
	super.refresh()
	if run == null:
		return
	%Title.text = str(run.node().name)
	%Station.text = str(run.region_info().name) + " · 물자 거래"
	var region := int(run.s.region)
	var copy: Dictionary = Story.SHOPS[region]
	var paragraphs: PackedStringArray = str(copy.story).split("\n", true, 1)
	%RecordTitle.text = RECORD_TITLES[region]
	%Greeting.text = copy.greeting
	%Memo.text = paragraphs[0]
	%Transcript.text = paragraphs[1] if paragraphs.size() > 1 else ""

func show_details(offer: Dictionary, state: Dictionary, credits: int) -> void:
	super.show_details(offer, state, credits)
	%ItemArt.item_id = str(offer.id)
	%ItemArt.is_part = offer.type != "ammo"
	%ItemArt.modulate.a = 0.45 if offer.sold else 1.0

func show_record(open: bool) -> void:
	%Chassis.record_active = open
	%Stock.visible = not open
	%Record.visible = open
	%Reroll.visible = not open
	%Feedback.visible = not open
	%RecordSpacer.visible = open
	%Charge.visible = not open and run != null and not run.magazine_enabled()
	%StockTab.set_pressed_no_signal(not open)
	%LogTab.set_pressed_no_signal(open)
	%StockTab.visible = open
	refresh()
	%Buy.disabled = %Buy.disabled or open
	if open:
		%RecordScroll.scroll_vertical = 0
		%LogTab.grab_focus()
	else:
		offer_button(selected).grab_focus()

func return_to_map() -> void:
	if run == null or not run.leave():
		return
	%Terminal.hide()
	%Map.show()
	refresh_map()
	%Reset.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F5: load_example(5)
		KEY_F6: load_example(6)
		KEY_ESCAPE:
			if %ReplaceOverlay.visible:
				close_replacement()
				%Replace.grab_focus()
			elif %Record.visible:
				show_record(false)
			elif %Terminal.visible:
				return_to_map()
		_: super._unhandled_key_input(event)

func capture_terminal(output: String) -> void:
	Input.emulate_mouse_from_touch = true
	for extent in [Vector2i(1008, 454), Vector2i(1280, 800), Vector2i(2340, 1080), Vector2i(2160, 1032)]:
		get_window().size = extent
		load_example(2)
		await rendered()
		var suffix := "_%dx%d" % [extent.x, extent.y]
		verify(not %Map.is_visible_in_tree(), "trade screen has no map pane")
		verify(%Terminal.size.x >= 960, "terminal fills the center")
		verify(not %Buy.get_global_rect().intersects(%Display.get_global_rect()) and %Display.get_global_rect().encloses(%LogTab.get_global_rect()), "purchase is physical and records stay on the screen footer")
		verify(not %Chassis.record_active, "cassette idles while browsing stock")
		await touch(offer_button(1))
		inspect_bounds("selected part" + suffix)
		var credits: int = run.s.credits
		var chosen := str(current_offer().id)
		var leave_position: Vector2 = %Leave.global_position
		await touch(%LogTab)
		verify(%Record.visible and not %Stock.visible and not %Reroll.visible, "terminal opens record without buying")
		verify(%Chassis.record_active, "record tab activates the cassette indicator")
		verify(%LogTab.button_pressed and not %StockTab.button_pressed, "record key stays latched")
		verify(%Leave.global_position.is_equal_approx(leave_position), "map exit stays fixed across tabs" + suffix)
		inspect_bounds("record" + suffix)
		await frame(output, "record" + suffix, extent)
		await touch(%StockTab)
		verify(%Stock.visible and not %Record.visible and chosen == str(current_offer().id) and credits == run.s.credits, "returning from record retains selected offer and credits")
		verify(not %Chassis.record_active, "returning to stock restores the cassette indicator")
		verify(%StockTab.button_pressed and not %LogTab.button_pressed, "stock key stays latched")
		await frame(output, "selected_part" + suffix, extent)
		await touch(%Leave)
		verify(run.s.phase == "map" and not %Terminal.visible and %Map.visible, "terminal exit reaches map")
		verify(%Graph.current == int(run.s.node) and %Graph.positions.has(int(run.s.node)), "returned map uses actual shop node")
		await touch(%Reset)
		verify(run.s.phase == "shop" and %Terminal.visible and %Stock.visible and not %Map.visible, "reopen restores shop scenario")

	for example in [1, 2, 5, 4, 6]:
		load_example(example)
		await rendered()
		await touch(%LogTab)
		var region := int(run.s.region)
		var source: Dictionary = Story.SHOPS[region]
		verify(%RecordTitle.text == RECORD_TITLES[region], "region %d has its own record title" % region)
		verify(%Greeting.text == source.greeting and %Memo.text + "\n" + %Transcript.text == source.story, "region %d preserves complete original text" % region)
		verify(%RecordScroll.get_v_scroll_bar().max_value <= %RecordScroll.get_v_scroll_bar().page + 1.0, "region %d record is fully visible in compact layout" % region)
		if example == 5:
			await frame(output, "garden_record_2160x1032", Vector2i(2160, 1032))

	print("SHOP TERMINAL RECORD checks=%d failures=%d" % [checks, failures])
	await super.capture_all(output)
