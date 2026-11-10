extends "res://tests/supply_live_ui.gd"
## Story scenes, confirmation and part details (2026-11-08). Departure uses fresh runs;
## the ending uses the earned won state of the 2026-11-06 full climb (QA_BUILD_DIR/
## won_single_17.json, restoration pending); confirmation uses the region-5 shop state.
const CommonWindow = preload("res://redesign/common/window.gd")
const SceneView = preload("res://redesign/story/scene_view.gd")

func find(id: String) -> Control:
	for child in host.get_children():
		if child.get_script() == CommonWindow and not child.is_queued_for_deletion():
			var inside: Node = child.find_child(id, true, false)
			if inside != null: return inside as Control
	var overlay: Node = host.find_child("WorkspaceOverlay", true, false)
	if overlay != null and id != "WorkspaceOverlay":
		var in_overlay: Node = overlay.find_child(id, true, false)
		if in_overlay != null: return in_overlay as Control
	return host.find_child(id, true, false) as Control

func window() -> Control:
	for child in host.get_children():
		if child.get_script() == CommonWindow and not child.is_queued_for_deletion(): return child
	return null

func on_screen(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() and root.get_visible_rect().grow(1).encloses(control.get_global_rect())

func earned(file: String):
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))), "earned state restores " + file)
	return c

func fresh():
	var c = Campaign.new()
	c.start("single", SEED, 0, "balanced", Campaign.Content.RouteMap.VERSION, "work", true)
	return c

func escape() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"; event.pressed = true
	root.push_input(event)
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	for extent in [Vector2i(1280, 800), Vector2i(844, 390), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		# 출발: three beats, each autosaved, ending on the map.
		var c = fresh()
		await mount(c)
		var view := find("StoryScreen")
		check(view != null and view.get_script() == SceneView, "departure opens the story scene " + suffix)
		check(on_screen(find("StoryPanel")) and on_screen(find("story_next")) and on_screen(find("story_skip")) and on_screen(find("menu")), "panel and actions on screen " + suffix)
		check(find("StoryPlace").text.contains("1 / 3") and find("StoryTitle").text == "우리 동네의 열이 끊겼다.", "first beat " + suffix)
		check(find("SupplyScene").get_global_rect().size.x > 300 and not find("SupplyScene").get_global_rect().intersects(find("StoryPanel").get_global_rect()), "diagram beside the panel " + suffix)
		await capture("departure1_" + suffix)
		await tap("story_next")
		check(int(c.s.departure_step) == 1 and int(saved().s.departure_step) == 1 and find("StoryPlace").text.contains("2 / 3"), "next beat advances and saves")
		check(find("SupplyScene").supplied, "second beat shows warm supply")
		if extent == Vector2i(1280, 800): await capture("departure2_" + suffix)
		await tap("story_next")
		check(find("StoryPlace").text.contains("3 / 3"), "third beat")
		if extent == Vector2i(1280, 800): await capture("departure3_" + suffix)
		await tap("story_next")
		check(not c.departure_pending() and find("StoryScreen") == null and find("PipeMapScreen") != null, "last beat starts the climb on the map " + suffix)
		# Skip.
		c = fresh()
		await mount(c)
		await tap("story_skip")
		check(not c.departure_pending() and find("PipeMapScreen") != null and not saved().departure_pending(), "skip goes to the map and saves")
		# Ending: restoration then homecoming then results.
		var won = earned("won_single_17.json")
		check(won.restoration_pending(), "earned win waits for restoration")
		await mount(won)
		check(find("StoryTitle") != null and find("StoryTitle").text == "아직, 저 아래에 사람들이 산다." and on_screen(find("story_restore")), "restoration scene " + suffix)
		await capture("restoration_" + suffix)
		await tap("story_restore")
		check(not won.restoration_pending() and not saved().restoration_pending(), "restoring supply saves")
		check(find("StoryTitle") != null and find("StoryTitle").text == "돌아갈 곳에 불이 켜졌다." and find("SupplyScene").released, "homecoming scene " + suffix)
		await capture("homecoming_" + suffix)
		await tap("story_results")
		check(find("StoryScreen") == null and host.city_ui.shows_results(won), "results follow " + suffix)
	# Menu from the story returns to the title.
	root.size = Vector2i(1280, 800)
	await mount(fresh())
	await tap("menu")
	check(host.page == "menu" and find("StoryScreen") == null, "menu returns to the title")
	# Part details from the build workshop: common window over the workshop.
	var map = earned("entry_single_17_r5.json")
	await mount(map)
	await tap("city_deck")
	var stored: Array = map.s.parts.filter(func(id): return not map.is_equipped(id))
	if check(not stored.is_empty(), "a stored part to inspect"):
		await tap("Stored_" + str(stored[0]))
		await tap("PartRules")
		var details := window()
		check(details != null and find("PartDetails") != null and on_screen(details.get_node("%Frame")), "part details open in the common window")
		await capture("part_details_1280x800")
		await escape()
		check(window() == null and find("WorkspaceOverlay") != null, "Esc closes details and keeps the workshop")
	# Confirmation: dismantle in the shop, cancel then confirm.
	var shop = earned("shop_single_17_r5_n40401.json")
	await mount(shop)
	var spare: Array = shop.s.parts.filter(func(id): return not shop.is_equipped(id))
	if check(shop.s.phase == "shop" and not spare.is_empty(), "shop with a stored part"):
		var part := str(spare[0])
		var credits := int(shop.s.credits)
		host.city_ui.ui = host; host.city_ui.campaign = shop
		host.city_ui._confirm_part_dismantle(part)
		await settle()
		var ask := window()
		check(ask != null and ask.name == "PartDismantleConfirmation" and find("DialogConfirm").text == "분해 · +10Cr" and find("DialogCancel").text == "보관", "dismantle asks in the common window")
		check(ask != null and on_screen(ask.get_node("%Frame")), "confirmation on screen")
		await capture("confirm_dismantle_1280x800")
		await tap("DialogCancel")
		check(window() == null and shop.s.parts.has(part), "cancel keeps the part")
		host.city_ui._confirm_part_dismantle(part)
		await settle()
		await tap("DialogConfirm")
		check(not shop.s.parts.has(part) and int(shop.s.credits) == credits + 10 and not saved().s.parts.has(part), "confirm dismantles, pays 10Cr and saves")
	print("STORY SCENES UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
