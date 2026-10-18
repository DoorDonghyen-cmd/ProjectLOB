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
		var text_scale = screen.find_child("TextScaleSetting", true, false) as OptionButton
		var motion = screen.find_child("MotionSetting", true, false) as OptionButton
		var hints = screen.find_child("ContextHintsSetting", true, false) as CheckButton
		check(text_scale.get_theme_stylebox("normal") is StyleBoxTexture, "settings uses console option face")
		check(hints.get_theme_icon("checked").get_size() == Vector2(40,24), "settings uses pixel toggle")
		check(screen.main_scroll.get_v_scroll_bar().get_theme_stylebox("grabber") is StyleBoxFlat, "scrollbar uses console palette")
		await capture("settings_%d" % resolution.x)
		text_scale.show_popup()
		await capture("settings_options_%d" % resolution.x)
		text_scale.get_popup().hide()
		text_scale.select(2)
		text_scale.item_selected.emit(2)
		await settle()
		check(is_equal_approx(float(screen.preferences.data.text_scale), 1.1), "font scale setting remains bound")
		motion.select(2)
		motion.item_selected.emit(2)
		check(screen.preferences.data.motion == "instant", "motion setting remains bound")
		var was_enabled: bool = hints.button_pressed
		hints.button_pressed = not was_enabled
		check(bool(screen.preferences.data.hints) == not was_enabled, "toggle remains bound")
		screen.preferences.reset()
		settings.get_meta("dialog").queue_free()
		screen._apply_preferences()
		await settle()
		await click("new_run_setup")
		await capture("weapons_%d" % resolution.x)
		screen._debug_city("shop")
		await settle()
		await click("city_part_info_1")
		await capture("shop_%d" % resolution.x)
		var credits: int = screen.campaign.s.credits
		var price: int = screen.campaign.s.offers[1].price
		await click("city_compare_buy_1")
		check(screen.campaign.s.credits == credits-price,"purchase debits exactly displayed price")
		check(not screen.campaign.buy(1),"sold state rejects duplicate purchase")
		await capture("shop_bought_%d" % resolution.x)
		screen._debug_city("deck")
		await settle()
		await click("city_part_select_overbore")
		await capture("parts_%d" % resolution.x)
		await click("city_deck_equip_overbore")
		check(screen.campaign.is_equipped("overbore") and not screen.campaign.is_equipped("field_press"),"replacement action remains bound")
		screen._close_workspace()
		screen._debug_city("map")
		await settle()
		await capture("map_%d" % resolution.x)
		screen.free()
	print("CONSOLE VISUAL COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
