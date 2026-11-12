extends "res://tests/supply_live_ui.gd"
## Common windows rework (2026-11-08): 설정, 조작 안내, 게임 규칙 and 기록실, opened by
## touch from the title and from the map. The map part uses the earned region-5 entry
## state from the 2026-11-06 full climb (QA_BUILD_DIR/entry_single_17_r5.json).
const CommonWindow = preload("res://redesign/common/window.gd")
const ArchiveRoom = preload("res://redesign/common/archive.gd")
const Prefs = preload("res://redesign/preferences.gd")
const Lore = preload("res://redesign/city_story.gd")

func find(id: String) -> Control:
	for child in host.get_children():
		if child.get_script() == CommonWindow or child.get_script() == ArchiveRoom:
			var inside: Node = child.find_child(id, true, false)
			if inside != null: return inside as Control
	return host.find_child(id, true, false) as Control

func window() -> Control:
	for child in host.get_children():
		if child.get_script() == CommonWindow and not child.is_queued_for_deletion(): return child
	return null

func on_screen(control: Control) -> bool:
	return control != null and root.get_visible_rect().grow(1).encloses(control.get_global_rect())

func stored_prefs() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Prefs.SAVE))

func escape() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"; event.pressed = true
	root.push_input(event)
	await settle()

func mount_title() -> void:
	if is_instance_valid(host): host.free()
	host = load("res://redesign/main.tscn").instantiate()
	root.add_child(host)
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	for path in [Campaign.SAVE, Prefs.SAVE]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	for extent in [Vector2i(1280, 800), Vector2i(844, 390), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		await mount_title()
		# 설정
		await tap("settings")
		var shell := window()
		if shell == null:
			await capture("debug_settings_" + suffix)
			check(false, "settings opened " + suffix); continue
		check(shell != null and find("SettingsDialog") != null, "title settings opens the common window " + suffix)
		check(shell != null and shell.find_children("*", "OptionButton", true, false).is_empty(), "no drop-downs in settings")
		check(shell != null and on_screen(shell.get_node("%Frame")), "settings frame on screen " + suffix)
		check(find("MotionSetting_0").button_pressed and find("EffectsVolumeSetting_2").button_pressed and find("ContextHintsSetting_0").button_pressed, "current values are pressed")
		await capture("settings_" + suffix)
		await tap("MotionSetting_1")
		check(host.preferences.data.motion == "fast" and stored_prefs().motion == "fast" and not find("MotionSetting_0").button_pressed, "motion choice applies and saves")
		await tap("EffectsVolumeSetting_0")
		check(is_zero_approx(float(stored_prefs().effects_volume)), "volume off saves")
		await tap("ContextHintsSetting_1")
		check(stored_prefs().hints == false, "hints off saves")
		# 글자 크기 removed (2026-11-08 decision): no row, and a stored 110% reads as 100%.
		check(find("TextScaleSetting") == null and is_equal_approx(float(host.preferences.data.text_scale), 1.0), "no text size row, scale fixed at 100%")
		await tap("settings_reset")
		check(window() != null and find("MotionSetting_0").button_pressed and stored_prefs().motion == "normal" and stored_prefs().hints == true, "reset restores defaults and reopens")
		await escape()
		check(window() == null, "Esc closes settings " + suffix)
		# 조작 안내
		await tap("first_guide" if find("first_guide").is_visible_in_tree() else "guide")
		shell = window()
		check(find("FirstGuide") != null and find("GuideStep3") != null and find("GuideFlow") != null, "guide shows three steps and the climb flow " + suffix)
		check(shell != null and on_screen(shell.get_node("%Frame")), "guide frame on screen " + suffix)
		check(shell != null and shell.get_node("%Frame").size.y < extent.y - 40 or extent.y < 500, "guide window shrinks to its content " + suffix)
		await capture("guide_" + suffix)
		await tap("DialogClose")
		check(window() == null, "guide closes")
		# 게임 규칙
		await tap("rules")
		shell = window()
		check(find("RulesDialog") != null and find("RulesDialog").get_child_count() >= 10, "rules show the five headed rows " + suffix)
		check(shell != null and on_screen(shell.get_node("%Frame")), "rules frame on screen " + suffix)
		await capture("rules_" + suffix)
		await tap("DialogClose")
		# 기록실 (fresh profile)
		await tap("city_archive")
		var room := find("WorkspaceOverlay")
		check(room != null and room.get_script() == ArchiveRoom, "title archive opens the new archive room " + suffix)
		var locked := 0
		for id in range(1, 21):
			var cell := find("city_lore_locked_%d" % id) as Button
			if cell != null and cell.disabled: locked += 1
		check(locked == 20 and find("RecordTitle").text.contains("없습니다"), "fresh profile: 20 locked cells and an empty reader")
		check(on_screen(find("Region5")) or extent.y < 500, "all regions on screen " + suffix)
		await capture("archive_empty_" + suffix)
		# 보급 선호 hidden (2026-11-08 decision): no tab, no data in the header.
		check(not find("SupplyTab").visible and not find("ArchiveSummary").text.contains("데이터"), "supply preference tab and data are hidden " + suffix)
		await tap("workspace_close")
		check(find("WorkspaceOverlay") == null and find("settings") != null, "archive closes to the title " + suffix)
	# Map: settings over the run, archive with found records and an unlock.
	root.size = Vector2i(1280, 800)
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join("entry_single_17_r5.json")))), "earned map state restores")
	c.profile.lore = [1, 2, 3, 4, 6, 7, 10]
	c.profile.cores = 45
	await mount(c)
	await tap("settings")
	check(window() != null and find("PipeMapScreen") != null, "map settings opens the common window over the map")
	await escape()
	check(window() == null and find("PipeMapScreen") != null, "Esc returns to the map")
	await tap("city_archive")
	check(find("WorkspaceOverlay") != null and find("city_lore_10") != null and find("city_lore_locked_5") != null, "found and missing records")
	check(find("RecordTitle").text == str(Lore.entry(10).title), "reader opens on the latest found record")
	await tap("city_lore_2")
	check(find("StoryRecordText").text == str(Lore.entry(2).text) and find("RecordMeta").text.contains("1구역") and find("RecordMeta").text.contains("조우"), "tapping a record reads it with region and source")
	await capture("archive_records_1280x800")
	host.city_ui.archive("supply")
	await settle()
	check(find("RecordsPage").is_visible_in_tree() and not find("SupplyPage").is_visible_in_tree() and int(c.profile.cores) == 45, "asking for the supply tab opens records; data is kept")
	await tap("workspace_close")
	check(find("WorkspaceOverlay") == null and find("PipeMapScreen") != null, "archive closes to the map")
	# Title with a saved run on short screens: settings stays reachable above the footer.
	host._persist()
	check(FileAccess.file_exists(Campaign.SAVE), "run saved for the title checks")
	for extent in [Vector2i(844, 390), Vector2i(1008, 454), Vector2i(1280, 800)]:
		root.size = extent
		await mount_title()
		var footer_top: float = find("Footer").get_global_rect().position.y
		check(find("resume").is_visible_in_tree() and on_screen(find("settings")) and find("settings").get_global_rect().end.y <= footer_top, "title with a save keeps settings above the footer %dx%d" % [extent.x, extent.y])
		if extent.y < 500: await capture("title_saved_%dx%d" % [extent.x, extent.y])
		await tap("settings")
		check(window() != null and find("SettingsDialog") != null, "settings opens from the saved title %dx%d" % [extent.x, extent.y])
		await escape()
	# 등반 설정 (equipment): no preference row while hidden.
	root.size = Vector2i(1280, 800)
	await mount_title()
	host._open_preparation(false)
	await settle()
	var options: Node = host.find_child("PreparationOptions", true, false)
	if options == null:
		var opener := host.find_child("preparation_options", true, false) as Button
		if opener == null: opener = host.find_child("run_options", true, false) as Button
		if opener != null:
			opener.pressed.emit()
			await settle()
			options = host.find_child("PreparationOptions", true, false)
	check(options != null and host.find_child("LoadoutSelection", true, false) == null and host.find_child("CityDifficulty", true, false) != null, "run options keep difficulty and drop the supply preference")
	if options != null: await capture("run_options_1280x800")
	print("COMMON WINDOWS UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
