extends "res://tests/frontend_ui_runner.gd"
## Targeted visual/integration path for the shared console family.
## Kept separate from the older interaction runner's removed undo control.

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/console_visual/"):
		quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,800)
	var preview: Control = load("res://redesign/combat_workbench.tscn").instantiate()
	preview.set_script(null)
	preview.position = Vector2(16,16)
	preview.size = Vector2(1248,768)
	root.add_child(preview)
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join("scene_before_ready.png")) == OK,"serialize styled workbench preview")
	preview.free()
	for resolution in [Vector2i(1008,630),Vector2i(1280,800)]:
		root.size = resolution
		screen = load("res://redesign/main.tscn").instantiate()
		screen.save_enabled = false
		screen.presentation_speed = 0.01
		root.add_child(screen)
		await settle()
		await capture("title_%d" % resolution.x)
		await click("settings")
		var settings = screen.find_child("SettingsDialog", true, false)
		# Settings are choice buttons since 2026-11-08 (common window); 글자 크기 is fixed at 100%.
		check(settings != null and settings.get_meta("dialog").get_script() == preload("res://redesign/common/window.gd"), "settings uses the common window")
		check(screen.find_child("TextScaleSetting", true, false) == null and screen.find_child("MotionSetting_0", true, false) is Button, "settings shows choice buttons")
		check(screen.main_scroll.get_v_scroll_bar().get_theme_stylebox("grabber") is StyleBoxFlat, "scrollbar uses console palette")
		await capture("settings_%d" % resolution.x)
		(screen.find_child("MotionSetting_2", true, false) as Button).pressed.emit()
		check(screen.preferences.data.motion == "instant", "motion setting remains bound")
		var was_enabled: bool = screen.preferences.data.hints
		(screen.find_child("ContextHintsSetting_1" if was_enabled else "ContextHintsSetting_0", true, false) as Button).pressed.emit()
		check(bool(screen.preferences.data.hints) == not was_enabled, "toggle remains bound")
		screen.preferences.reset()
		settings.get_meta("dialog").queue_free()
		screen._apply_preferences()
		await settle()
		await click("new_run_setup")
		await capture("weapons_%d" % resolution.x)
		# Shop and build workshop checks retired 2026-11-08: those screens were replaced
		# (shop terminal 11-04, build workshop 11-08); see shop_terminal_live_runner.gd
		# and build_live_ui.gd.
		screen._debug_city("map")
		await settle()
		await capture("map_%d" % resolution.x)
		screen.free()
	print("CONSOLE VISUAL COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
