extends "res://tests/frontend_ui_runner.gd"

var touch_seen := 0
var drag_seen := 0

func finger(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = root.get_final_transform() * point
	event.pressed = down
	event.window_id = root.get_window_id()
	Input.parse_input_event(event)
	await process_frame

func swipe(point: Vector2, movement: Vector2) -> void:
	await finger(point, true)
	for i in range(1, 13):
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = root.get_final_transform() * (point + movement * i / 12.0)
		event.relative = root.get_final_transform().basis_xform(movement / 12.0)
		event.screen_relative = event.relative
		event.window_id = root.get_window_id()
		Input.parse_input_event(event)
		await create_timer(0.018).timeout
	await finger(point + movement, false)
	await create_timer(0.4).timeout
	await settle()

func touch_tap(point: Vector2) -> void:
	await finger(point, true)
	await finger(point, false)
	await settle()

func top_dialog() -> Control:
	for i in range(screen.get_child_count()-1, -1, -1):
		var child := screen.get_child(i)
		if child.has_meta("lob_modal") and child.visible: return child
	return null

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/modal_touch/ui"):
		quit(1); return
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = true
	root.size = Vector2i(1008,630)
	var preview: Control = load("res://redesign/console_dialog.tscn").instantiate()
	preview.set_script(null)
	root.add_child(preview)
	await settle()
	check(preview.find_child("Frame",true,false).get_theme_stylebox("panel") is StyleBoxTexture, "dialog composition and skin serialized before ready")
	check(root.get_texture().get_image().save_png(output.path_join("dialog_before_ready.png")) == OK, "authored dialog preview capture")
	preview.free()
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen.feedback.configure({"effects_volume":0.0})
	print("TOUCH HINT ", DisplayServer.is_touchscreen_available(), " size ", screen.size, " transform ", root.get_final_transform())
	await touch_tap(screen.find_child("settings",true,false).get_global_rect().get_center())
	check(top_dialog() != null, "real screen touch opens settings")
	if top_dialog() == null:
		print("MODAL TOUCH COMPLETE checks=%d failures=%d" % [checks, failures.size()])
		quit(1); return
	await capture("settings_1008")
	top_dialog().close()
	await settle()
	screen._rules()
	await settle()
	var dialog := top_dialog()
	var scroll := dialog.find_child("DialogScroll",true,false) as ScrollContainer
	print("GUIDE RANGE ", scroll.get_v_scroll_bar().max_value, " page ", scroll.get_v_scroll_bar().page)
	var header_rect: Rect2 = dialog.find_child("DialogClose",true,false).get_global_rect()
	await swipe(scroll.get_global_rect().get_center()+Vector2(0,80), Vector2(0,-180))
	print("GUIDE SCROLLED ", scroll.scroll_vertical)
	check(scroll.scroll_vertical > 5, "finger swipes detail text")
	check(dialog.find_child("DialogClose",true,false).get_global_rect() == header_rect, "header remains fixed while scrolling")
	await capture("guide_scrolled")
	dialog.close()
	await settle()
	screen._debug_city("map")
	await settle()
	var map_scroll := screen.find_child("MapScroll",true,false) as ScrollContainer
	var before := map_scroll.scroll_vertical
	print("MAP RANGE ", map_scroll.get_v_scroll_bar().max_value, " page ", map_scroll.get_v_scroll_bar().page, " before ", before)
	await swipe(map_scroll.get_global_rect().get_center(), Vector2(0,140))
	print("MAP SCROLLED ", map_scroll.scroll_vertical)
	check(map_scroll.scroll_vertical != before, "finger swipes map")
	await capture("map_scrolled")
	# Swiping over an interactive node must not select it on release.
	var chart = screen.find_child("CityMap",true,false)
	var selected: int = chart.selection
	var node_button: Button
	for item in chart.get_children():
		if item is Button and map_scroll.get_global_rect().grow(-20).encloses(item.get_global_rect()):
			node_button = item
			break
	check(node_button != null, "visible map node for swipe")
	if node_button != null:
		await swipe(node_button.get_global_rect().get_center(), Vector2(0,-100))
		check(chart.selection == selected, "map swipe does not select a node")
	# Nested inventory owns its scroll, instead of moving the outer workspace.
	screen._debug_city("deck")
	await settle()
	screen.campaign.s.parts = screen.Content.PARTS.keys().filter(func(id): return id != "none")
	screen.city_ui.deck("parts")
	await settle()
	var inventory := screen.find_child("InventoryScroll",true,false) as ScrollContainer
	var workspace_scroll := screen.workspace_overlay.find_child("WorkspaceScroll",true,false) as ScrollContainer
	var outer_before := workspace_scroll.scroll_vertical
	var selected_part: String = screen.city_ui.selected_part_id
	var campaign_before: Dictionary = screen.campaign.s.duplicate(true)
	var part_button: Button
	for item in screen.find_children("city_part_select_*", "Button",true,false):
		if inventory.get_global_rect().grow(-3).encloses(item.get_global_rect()):
			part_button = item
			break
	check(part_button != null, "visible inventory card for swipe")
	if part_button != null:
		await swipe(part_button.get_global_rect().get_center(), Vector2(0,-150))
		check(inventory.scroll_vertical > 40, "finger swipes over part cards")
		check(workspace_scroll.scroll_vertical == outer_before, "nested scroll leaves outer sheet still")
		check(screen.city_ui.selected_part_id == selected_part and screen.campaign.s == campaign_before, "swipe neither selects nor equips a part")
	await capture("parts_scrolled")
	screen._close_workspace()
	# Modal action safety, fixed buttons, and keyboard/back behavior.
	screen._debug_city("shop")
	await settle()
	screen.campaign.s.parts.append("lens")
	screen.city_ui.deck("parts")
	await settle()
	screen.city_ui._confirm_part_dismantle("lens")
	await settle()
	dialog = top_dialog()
	check(dialog != null and screen.campaign.s.parts.has("lens"), "dismantle opens confirmation without changing inventory")
	await capture("confirm_dismantle")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	check(top_dialog() == null and screen.campaign.s.parts.has("lens") and is_instance_valid(screen.workspace_overlay), "back cancels only the top dialog")
	screen.city_ui._confirm_part_dismantle("lens")
	await settle()
	var credits: int = screen.campaign.s.credits
	await touch_tap(top_dialog().get_ok_button().get_global_rect().get_center())
	check(not screen.campaign.s.parts.has("lens") and screen.campaign.s.credits == credits+10, "touch confirms exactly one dismantle")
	screen._close_workspace()
	# Settings and details remain within the screen at three shapes, including large text.
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1600,720)]:
		root.size = resolution
		screen.preferences.data.text_scale = 1.1
		screen._settings()
		await settle()
		dialog = top_dialog()
		check(Rect2(Vector2.ZERO,screen.size).encloses(dialog.find_child("Frame",true,false).get_global_rect()), "modal fits "+str(resolution))
		check(dialog.find_child("DialogClose",true,false).size.y >= 48, "close has touch-sized target")
		var action := dialog.find_child("EffectsVolumeSetting",true,false) as OptionButton
		await touch_tap(action.get_global_rect().get_center())
		check(action.get_popup().visible, "touch opens themed option popup")
		var popup_back := InputEventKey.new()
		popup_back.keycode = KEY_ESCAPE
		popup_back.pressed = true
		popup_back.window_id = action.get_popup().get_window_id()
		Input.parse_input_event(popup_back)
		await settle()
		check(is_instance_valid(dialog) and dialog.visible and not action.get_popup().visible, "back dismisses dropdown before dialog")
		await capture("settings_large_%d"%resolution.x)
		# Modal tab navigation cannot focus the battle/shop under it.
		for i in range(9):
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.pressed = true
			Input.parse_input_event(tab)
			await process_frame
			check(dialog.is_ancestor_of(root.gui_get_focus_owner()), "focus stays inside modal")
		dialog.close()
		await settle()
	# Short logical viewport / large text makes the main page overflow naturally.
	var original_scale := root.content_scale_size
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(960,540)
	screen._to_menu()
	await settle()
	screen._open_preparation(false)
	await settle()
	check(screen.main_scroll.get_v_scroll_bar().max_value > screen.main_scroll.get_v_scroll_bar().page, "short preparation page needs scrolling")
	await swipe(screen.main_scroll.get_global_rect().get_center(),Vector2(0,-130))
	check(screen.main_scroll.scroll_vertical > 10, "finger scrolls main page content")
	await capture("main_page_swipe")
	root.content_scale_size = original_scale
	# Touch ammunition drag remains owned by the card, not the page.
	root.size = Vector2i(1008,630)
	screen.preferences.data.text_scale = 1.0
	screen._debug_combat_finish()
	screen.presentation_speed = 0.02
	screen.model.s.hand = ["pierce","pierce","cool","basic","charge_hot"]
	screen.model.s.deck = screen.model.s.hand.duplicate()
	screen.model.s.draw = []
	screen.model.s.discard = []
	screen.hand_layout_key = ""
	screen.redraw()
	await settle()
	var source := screen.find_child("load_pierce",true,false) as Button
	var target := screen.find_child("load_pierce_2",true,false) as Button
	check(source != null and target != null and source.compression_ready, "compression pair available")
	if source != null and target != null:
		await swipe(source.get_global_rect().get_center(), target.get_global_rect().get_center()-source.get_global_rect().get_center())
		while screen.busy: await process_frame
		await settle()
		check(screen.model.s.plan.size() == 1 and screen.model.s.plan[0] == screen.Content.field_id("pierce"), "touch drag compresses rather than scrolling")
	await capture("touch_compression")
	await touch_tap(screen.find_child("load_basic",true,false).get_global_rect().get_center())
	while screen.busy: await process_frame
	await settle()
	check(screen.model.s.plan.has("basic"), "touch tap still loads a single round")
	screen.queue_free()
	await process_frame
	print("MODAL TOUCH COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
